-- ParallelLoot Test Workflows
-- Comprehensive testing of core workflows

local TestWorkflows = {}
ParallelLoot.TestWorkflows = TestWorkflows

-- Test results storage
TestWorkflows.results = {}
TestWorkflows.currentTest = nil

-- ============================================================================
-- TEST UTILITIES
-- ============================================================================

-- Log test result
function TestWorkflows:LogResult(testName, success, message)
    table.insert(self.results, {
        test = testName,
        success = success,
        message = message or "",
        timestamp = time()
    })
    
    if success then
        ParallelLoot:Print("|cFF00FF00[PASS]|r", testName)
    else
        ParallelLoot:Print("|cFFFF0000[FAIL]|r", testName, "-", message or "")
    end
end

-- Assert condition
function TestWorkflows:Assert(condition, testName, failMessage)
    if condition then
        self:LogResult(testName, true)
        return true
    else
        self:LogResult(testName, false, failMessage)
        return false
    end
end

-- Clear test results
function TestWorkflows:ClearResults()
    self.results = {}
    ParallelLoot:Print("Test results cleared")
end

-- Print test summary
function TestWorkflows:PrintSummary()
    local passed = 0
    local failed = 0
    
    for _, result in ipairs(self.results) do
        if result.success then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
    
    local total = passed + failed
    ParallelLoot:Print("=== Test Summary ===")
    ParallelLoot:Print(string.format("Total: %d | Passed: %d | Failed: %d", total, passed, failed))
    
    if failed > 0 then
        ParallelLoot:Print("Failed tests:")
        for _, result in ipairs(self.results) do
            if not result.success then
                print("  -", result.test, ":", result.message)
            end
        end
    end
end

-- ============================================================================
-- WORKFLOW 1: SESSION MANAGEMENT
-- ============================================================================

function TestWorkflows:TestSessionManagement()
    ParallelLoot:Print("=== Testing Session Management Workflow ===")
    
    -- Debug: Check loot master status before starting session
    local isLootMaster = ParallelLoot.LootMasterManager:IsPlayerLootMaster()
    ParallelLoot:Print("Debug: Player is loot master:", isLootMaster)
    ParallelLoot:Print("Debug: Current loot master:", ParallelLoot.LootMasterManager.currentLootMaster)
    
    -- Force loot master detection for testing
    ParallelLoot.LootMasterManager:DetectLootMaster()
    
    -- Check if there's already an existing session and end it
    local existingSession = ParallelLoot.DataManager:GetCurrentSession()
    if existingSession then
        ParallelLoot:Print("Debug: Found existing session, ending it first")
        ParallelLoot.Integration:EndSession()
    end
    
    -- Test 1: Start session
    local success = ParallelLoot.Integration:StartSession()
    ParallelLoot:Print("Debug: StartSession returned:", success)
    self:Assert(success, "Start Session", "Failed to start session")
    
    -- Test 2: Verify session exists
    local session = ParallelLoot.DataManager:GetCurrentSession()
    self:Assert(session ~= nil, "Session Created", "Session not found after creation")
    
    -- Test 3: Verify session structure
    if session then
        self:Assert(session.id ~= nil, "Session has ID", "Session missing ID")
        self:Assert(session.masterId == UnitName("player"), "Session Master ID", "Master ID mismatch")
        self:Assert(type(session.activeItems) == "table", "Session has activeItems", "activeItems not a table")
        self:Assert(type(session.awardedItems) == "table", "Session has awardedItems", "awardedItems not a table")
    end
    
    -- Test 4: End session
    success = ParallelLoot.Integration:EndSession()
    self:Assert(success, "End Session", "Failed to end session")
    
    -- Test 5: Verify session ended
    session = ParallelLoot.DataManager:GetCurrentSession()
    self:Assert(session == nil, "Session Ended", "Session still exists after ending")
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 2: LOOT DETECTION AND ITEM MANAGEMENT
-- ============================================================================

function TestWorkflows:TestLootManagement()
    ParallelLoot:Print("=== Testing Loot Management Workflow ===")
    
    -- Reset roll manager state for consistent testing
    ParallelLoot.RollManager.nextRangeBase = 1
    ParallelLoot.RollManager.availableRanges = {}
    
    -- Start a session first
    ParallelLoot.Integration:StartSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:Print("Cannot test loot management without active session")
        return
    end
    
    -- Test 1: Create mock loot item
    local mockItem = {
        id = "test_item_1",
        itemLink = "|cff0070dd|Hitem:12345:0:0:0:0:0:0:0|h[Test Epic Item]|h|r",
        itemId = 12345,
        itemName = "Test Epic Item",
        quality = 4, -- Epic
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        quantity = 1,
        dropTime = time(),
        expiryTime = time() + 7200,
        rolls = {},
        awardedTo = nil,
        awardTime = nil
    }
    
    -- Test 2: Assign roll range
    local rollRange = ParallelLoot.RollManager:AssignRollRange()
    self:Assert(rollRange ~= nil, "Assign Roll Range", "Failed to assign roll range")
    
    if rollRange then
        mockItem.rollRange = rollRange
        
        -- Test 3: Verify roll range structure
        self:Assert(rollRange.bis ~= nil, "Roll Range has BIS", "BIS range missing")
        self:Assert(rollRange.ms ~= nil, "Roll Range has MS", "MS range missing")
        self:Assert(rollRange.os ~= nil, "Roll Range has OS", "OS range missing")
        self:Assert(rollRange.coz ~= nil, "Roll Range has COZ", "COZ range missing")
        
        -- Test 4: Verify range values
        self:Assert(rollRange.bis.min == 1, "BIS min is 1", "BIS min incorrect")
        self:Assert(rollRange.bis.max == 100, "BIS max is 100", "BIS max incorrect")
    end
    
    -- Test 5: Add item to session
    table.insert(session.activeItems, mockItem)
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    local updatedSession = ParallelLoot.DataManager:GetCurrentSession()
    self:Assert(#updatedSession.activeItems == 1, "Item Added to Session", "Item not added")
    
    -- Test 6: Find item by ID
    local foundItem = ParallelLoot.DataManager:FindItemById(updatedSession.activeItems, mockItem.id)
    self:Assert(foundItem ~= nil, "Find Item by ID", "Item not found")
    
    -- Clean up
    ParallelLoot.Integration:EndSession()
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 3: ROLL SUBMISSION AND VALIDATION
-- ============================================================================

function TestWorkflows:TestRollWorkflow()
    ParallelLoot:Print("=== Testing Roll Workflow ===")
    
    -- Start session and create mock item
    ParallelLoot.Integration:StartSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:Print("Cannot test roll workflow without active session")
        return
    end
    
    -- Create mock item with roll range
    local mockItem = {
        id = "test_item_roll",
        itemLink = "|cff0070dd|Hitem:12346:0:0:0:0:0:0:0|h[Test Roll Item]|h|r",
        itemId = 12346,
        itemName = "Test Roll Item",
        quality = 4,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        rollRange = ParallelLoot.RollManager:AssignRollRange(),
        rolls = {},
        dropTime = time(),
        expiryTime = time() + 7200
    }
    
    table.insert(session.activeItems, mockItem)
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Test 1: Create mock roll
    local mockRoll = {
        playerName = "TestPlayer",
        category = "bis",
        rollValue = 95,
        timestamp = time()
    }
    
    -- Test 2: Validate roll
    local valid, error = ParallelLoot.DataManager.PlayerRoll:Validate(mockRoll)
    self:Assert(valid, "Roll Validation", error)
    
    -- Test 3: Add roll to item
    local success, addError = ParallelLoot.DataManager:AddRollToItem(mockItem, mockRoll)
    self:Assert(success, "Add Roll to Item", addError)
    
    -- Test 4: Verify roll was added
    self:Assert(#mockItem.rolls == 1, "Roll Count", "Roll not added to item")
    
    -- Test 5: Check for duplicate roll
    local dupSuccess, dupError = ParallelLoot.DataManager:AddRollToItem(mockItem, mockRoll)
    self:Assert(not dupSuccess, "Duplicate Roll Prevention", "Duplicate roll was allowed")
    
    -- Test 6: Get rolls by category
    local rollsByCategory = ParallelLoot.DataManager:GetRollsOrganized(mockItem)
    self:Assert(#rollsByCategory.bis == 1, "Rolls by Category", "Roll not in correct category")
    
    -- Test 7: Add rolls in different categories
    local msRoll = {
        playerName = "TestPlayer2",
        category = "ms",
        rollValue = 88,
        timestamp = time()
    }
    
    ParallelLoot.DataManager:AddRollToItem(mockItem, msRoll)
    rollsByCategory = ParallelLoot.DataManager:GetRollsOrganized(mockItem)
    self:Assert(#rollsByCategory.ms == 1, "Multiple Category Rolls", "MS roll not added")
    
    -- Test 8: Get highest rolls
    local highestRolls = ParallelLoot.DataManager:GetHighestRolls(mockItem)
    self:Assert(highestRolls.bis ~= nil, "Highest BIS Roll", "No highest BIS roll")
    self:Assert(highestRolls.bis.rollValue == 95, "Highest BIS Value", "Incorrect highest roll value")
    
    -- Clean up
    ParallelLoot.Integration:EndSession()
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 4: AWARD AND REVOKE
-- ============================================================================

function TestWorkflows:TestAwardWorkflow()
    ParallelLoot:Print("=== Testing Award Workflow ===")
    
    -- Start session
    ParallelLoot.Integration:StartSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:Print("Cannot test award workflow without active session")
        return
    end
    
    -- Create mock item with rolls
    local mockItem = {
        id = "test_item_award",
        itemLink = "|cff0070dd|Hitem:12347:0:0:0:0:0:0:0|h[Test Award Item]|h|r",
        itemId = 12347,
        itemName = "Test Award Item",
        quality = 4,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        rollRange = ParallelLoot.RollManager:AssignRollRange(),
        rolls = {},
        dropTime = time(),
        expiryTime = time() + 7200
    }
    
    -- Add some rolls
    local roll1 = {playerName = "Winner", category = "bis", rollValue = 99, timestamp = time()}
    local roll2 = {playerName = "SecondPlace", category = "bis", rollValue = 85, timestamp = time()}
    
    ParallelLoot.DataManager:AddRollToItem(mockItem, roll1)
    ParallelLoot.DataManager:AddRollToItem(mockItem, roll2)
    
    table.insert(session.activeItems, mockItem)
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Test 1: Get winner
    local winner = ParallelLoot.RollManager:GetItemWinner(mockItem)
    self:Assert(winner ~= nil, "Get Winner", "No winner found")
    self:Assert(winner.playerName == "Winner", "Correct Winner", "Wrong winner selected")
    
    -- Test 2: Award item
    local success = ParallelLoot.Integration:AwardItem(mockItem.id, "Winner")
    self:Assert(success, "Award Item", "Failed to award item")
    
    -- Test 3: Verify item moved to awarded
    session = ParallelLoot.DataManager:GetCurrentSession()
    self:Assert(#session.activeItems == 0, "Item Removed from Active", "Item still in active items")
    self:Assert(#session.awardedItems == 1, "Item Added to Awarded", "Item not in awarded items")
    
    -- Test 4: Verify award details
    local awardedItem = session.awardedItems[1]
    self:Assert(awardedItem.awardedTo == "Winner", "Award Player Name", "Incorrect awardee")
    self:Assert(awardedItem.awardTime ~= nil, "Award Time Set", "Award time not set")
    
    -- Test 5: Revoke award
    success = ParallelLoot.Integration:RevokeAward(awardedItem.id)
    self:Assert(success, "Revoke Award", "Failed to revoke award")
    
    -- Test 6: Verify item moved back to active
    session = ParallelLoot.DataManager:GetCurrentSession()
    self:Assert(#session.activeItems == 1, "Item Returned to Active", "Item not returned to active")
    self:Assert(#session.awardedItems == 0, "Item Removed from Awarded", "Item still in awarded")
    
    -- Test 7: Verify rolls preserved
    local revokedItem = session.activeItems[1]
    self:Assert(#revokedItem.rolls == 2, "Rolls Preserved", "Rolls not preserved after revoke")
    self:Assert(revokedItem.awardedTo == nil, "Award Info Cleared", "Award info not cleared")
    
    -- Test 8: Verify new roll range assigned
    self:Assert(revokedItem.rollRange ~= nil, "New Roll Range", "No roll range after revoke")
    
    -- Clean up
    ParallelLoot.Integration:EndSession()
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 5: DATA PERSISTENCE
-- ============================================================================

function TestWorkflows:TestDataPersistence()
    ParallelLoot:Print("=== Testing Data Persistence Workflow ===")
    
    -- Test 1: Create session
    ParallelLoot.Integration:StartSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    self:Assert(session ~= nil, "Session Created", "Failed to create session")
    
    if not session then
        return
    end
    
    local sessionId = session.id
    
    -- Test 2: Add mock data
    local mockItem = {
        id = "test_persist",
        itemLink = "|cff0070dd|Hitem:12348:0:0:0:0:0:0:0|h[Test Persist Item]|h|r",
        itemId = 12348,
        itemName = "Test Persist Item",
        quality = 4,
        rollRange = ParallelLoot.RollManager:AssignRollRange(),
        rolls = {},
        dropTime = time(),
        expiryTime = time() + 7200
    }
    
    table.insert(session.activeItems, mockItem)
    
    -- Test 3: Save session
    local saveSuccess = ParallelLoot.DataManager:SaveCurrentSession(session)
    self:Assert(saveSuccess, "Save Session", "Failed to save session")
    
    -- Test 4: Load session
    local loadedSession = ParallelLoot.DataManager:LoadSession()
    self:Assert(loadedSession ~= nil, "Load Session", "Failed to load session")
    
    -- Test 5: Verify loaded data
    if loadedSession then
        self:Assert(loadedSession.id == sessionId, "Session ID Persisted", "Session ID mismatch")
        self:Assert(#loadedSession.activeItems == 1, "Items Persisted", "Items not persisted")
        
        local loadedItem = loadedSession.activeItems[1]
        self:Assert(loadedItem.id == mockItem.id, "Item ID Persisted", "Item ID mismatch")
    end
    
    -- Test 6: Validate session state
    local valid, error = ParallelLoot.DataManager:ValidateSessionState(loadedSession)
    self:Assert(valid, "Session State Valid", error)
    
    -- Test 7: Get session stats
    local stats = ParallelLoot.DataManager:GetSessionStats(loadedSession)
    self:Assert(stats ~= nil, "Session Stats", "Failed to get stats")
    self:Assert(stats.activeItemCount == 1, "Stats Active Count", "Incorrect active count")
    
    -- Clean up
    ParallelLoot.Integration:EndSession()
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 6: TIMER MANAGEMENT
-- ============================================================================

function TestWorkflows:TestTimerWorkflow()
    ParallelLoot:Print("=== Testing Timer Workflow ===")
    
    -- Test 1: Create mock item
    local mockItem = {
        id = "test_timer",
        itemName = "Test Timer Item",
        dropTime = time(),
        expiryTime = time() + 3600 -- 1 hour
    }
    
    -- Test 2: Get time remaining
    local timeRemaining = ParallelLoot.TimerManager:GetTimeRemaining(mockItem)
    self:Assert(timeRemaining > 0, "Time Remaining Positive", "Time remaining not positive")
    self:Assert(timeRemaining <= 3600, "Time Remaining Valid", "Time remaining exceeds expiry")
    
    -- Test 3: Check if expired
    local isExpired = ParallelLoot.DataManager.LootItem:IsExpired(mockItem)
    self:Assert(not isExpired, "Item Not Expired", "Item incorrectly marked as expired")
    
    -- Test 4: Get progress percentage
    local progress = ParallelLoot.TimerManager:GetProgressPercentage(mockItem)
    self:Assert(progress >= 0 and progress <= 1, "Progress Percentage Valid", "Invalid progress percentage")
    
    -- Test 5: Get timer display text
    local displayText = ParallelLoot.TimerManager:GetTimerDisplayText(mockItem)
    self:Assert(displayText ~= nil and displayText ~= "", "Timer Display Text", "No display text")
    
    -- Test 6: Test expired item
    local expiredItem = {
        id = "test_expired",
        itemName = "Test Expired Item",
        dropTime = time() - 7200,
        expiryTime = time() - 1
    }
    
    isExpired = ParallelLoot.DataManager.LootItem:IsExpired(expiredItem)
    self:Assert(isExpired, "Expired Item Detection", "Expired item not detected")
    
    timeRemaining = ParallelLoot.TimerManager:GetTimeRemaining(expiredItem)
    self:Assert(timeRemaining == 0, "Expired Time Remaining", "Expired item has time remaining")
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 7: ROLL RANGE MANAGEMENT
-- ============================================================================

function TestWorkflows:TestRollRangeManagement()
    ParallelLoot:Print("=== Testing Roll Range Management Workflow ===")
    
    -- Start session
    ParallelLoot.Integration:StartSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:Print("Cannot test roll range management without active session")
        return
    end
    
    -- Test 1: Assign first range
    local range1 = ParallelLoot.DataManager:AssignRollRange(session)
    self:Assert(range1 ~= nil, "Assign First Range", "Failed to assign first range")
    self:Assert(range1.bis.min == 1, "First Range Base", "First range base incorrect")
    
    -- Test 2: Assign second range
    local range2 = ParallelLoot.DataManager:AssignRollRange(session)
    self:Assert(range2 ~= nil, "Assign Second Range", "Failed to assign second range")
    self:Assert(range2.bis.min == 101, "Second Range Base", "Second range base incorrect")
    
    -- Test 3: Recycle first range
    ParallelLoot.DataManager:RecycleRollRange(session, range1)
    self:Assert(#session.rollRanges.available == 1, "Range Recycled", "Range not recycled")
    
    -- Test 4: Reuse recycled range
    local range3 = ParallelLoot.DataManager:AssignRollRange(session)
    self:Assert(range3.bis.min == 1, "Recycled Range Reused", "Recycled range not reused")
    
    -- Test 5: Check for conflicts
    local mockItem1 = {id = "item1", rollRange = range2}
    local mockItem2 = {id = "item2", rollRange = range3}
    
    session.activeItems = {mockItem1, mockItem2}
    
    local conflicts = ParallelLoot.DataManager:DetectRangeConflicts(session)
    self:Assert(#conflicts == 0, "No Range Conflicts", "Range conflicts detected")
    
    -- Test 6: Format range display
    local formatted = ParallelLoot.DataManager:FormatRollRange(range2, "bis")
    self:Assert(formatted == "101-200", "Format Range Display", "Incorrect range format")
    
    -- Clean up
    ParallelLoot.Integration:EndSession()
    
    self:PrintSummary()
end

-- ============================================================================
-- WORKFLOW 8: UNIQUE ROLL RANGE TESTS
-- ============================================================================

function TestWorkflows:TestUniqueRollRanges()
    ParallelLoot:Print("=== Testing Unique Roll Ranges ===")
    
    -- Reset roll manager state for clean testing
    ParallelLoot.RollManager.nextRangeBase = 1
    ParallelLoot.RollManager.availableRanges = {}
    
    -- Start session
    ParallelLoot.Integration:StartSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:Print("Cannot test unique roll ranges without active session")
        return
    end
    
    -- Test 1: Create multiple items with unique ranges
    local items = {}
    local ranges = {}
    
    for i = 1, 5 do
        local item = {
            id = "unique_test_item_" .. i,
            itemLink = "|cff0070dd|Hitem:" .. (12000 + i) .. ":0:0:0:0:0:0:0|h[Unique Test Item " .. i .. "]|h|r",
            itemId = 12000 + i,
            itemName = "Unique Test Item " .. i,
            quality = 4,
            icon = "Interface\\Icons\\INV_Misc_QuestionMark",
            quantity = 1,
            dropTime = time(),
            expiryTime = time() + 7200,
            rolls = {},
            awardedTo = nil,
            awardTime = nil
        }
        
        -- Assign roll range
        local rollRange = ParallelLoot.RollManager:AssignRollRange()
        item.rollRange = rollRange
        
        table.insert(items, item)
        table.insert(ranges, rollRange)
        table.insert(session.activeItems, item)
    end
    
    -- Test 2: Verify all ranges are unique
    for i = 1, #ranges do
        for j = i + 1, #ranges do
            local range1 = ranges[i]
            local range2 = ranges[j]
            
            -- Check BIS ranges don't overlap
            local overlap = not (range1.bis.max < range2.bis.min or range2.bis.max < range1.bis.min)
            self:Assert(not overlap, "BIS Range " .. i .. " vs " .. j .. " Unique", "BIS ranges overlap")
            
            -- Check MS ranges don't overlap
            overlap = not (range1.ms.max < range2.ms.min or range2.ms.max < range1.ms.min)
            self:Assert(not overlap, "MS Range " .. i .. " vs " .. j .. " Unique", "MS ranges overlap")
            
            -- Check OS ranges don't overlap
            overlap = not (range1.os.max < range2.os.min or range2.os.max < range1.os.min)
            self:Assert(not overlap, "OS Range " .. i .. " vs " .. j .. " Unique", "OS ranges overlap")
            
            -- Check COZ ranges don't overlap
            overlap = not (range1.coz.max < range2.coz.min or range2.coz.max < range1.coz.min)
            self:Assert(not overlap, "COZ Range " .. i .. " vs " .. j .. " Unique", "COZ ranges overlap")
        end
    end
    
    -- Test 3: Verify expected range values
    self:Assert(ranges[1].bis.min == 1, "First Item BIS Min", "First item BIS min incorrect")
    self:Assert(ranges[1].bis.max == 100, "First Item BIS Max", "First item BIS max incorrect")
    self:Assert(ranges[2].bis.min == 101, "Second Item BIS Min", "Second item BIS min incorrect")
    self:Assert(ranges[2].bis.max == 200, "Second Item BIS Max", "Second item BIS max incorrect")
    self:Assert(ranges[5].bis.min == 401, "Fifth Item BIS Min", "Fifth item BIS min incorrect")
    self:Assert(ranges[5].bis.max == 500, "Fifth Item BIS Max", "Fifth item BIS max incorrect")
    
    -- Test 4: Verify category offsets within each range
    for i, range in ipairs(ranges) do
        local baseMin = range.bis.min
        
        self:Assert(range.bis.min == baseMin, "Item " .. i .. " BIS Offset", "BIS offset incorrect")
        self:Assert(range.ms.min == baseMin and range.ms.max == baseMin + 98, "Item " .. i .. " MS Offset", "MS offset incorrect")
        self:Assert(range.os.min == baseMin and range.os.max == baseMin + 97, "Item " .. i .. " OS Offset", "OS offset incorrect")
        self:Assert(range.coz.min == baseMin and range.coz.max == baseMin + 96, "Item " .. i .. " COZ Offset", "COZ offset incorrect")
    end
    
    -- Test 5: Test range recycling maintains uniqueness
    local originalRange = ranges[3]
    
    -- Award item 3 to free its range
    ParallelLoot.Integration:AwardItem(items[3].id, "TestPlayer")
    
    -- Create new item - should reuse the freed range
    local newItem = {
        id = "recycled_test_item",
        itemLink = "|cff0070dd|Hitem:13000:0:0:0:0:0:0:0|h[Recycled Test Item]|h|r",
        itemId = 13000,
        itemName = "Recycled Test Item",
        quality = 4,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        quantity = 1,
        dropTime = time(),
        expiryTime = time() + 7200,
        rolls = {},
        awardedTo = nil,
        awardTime = nil
    }
    
    local recycledRange = ParallelLoot.RollManager:AssignRollRange()
    newItem.rollRange = recycledRange
    
    self:Assert(recycledRange.bis.min == originalRange.bis.min, "Recycled Range Reused", "Recycled range not reused correctly")
    
    -- Test 6: Verify no conflicts after recycling
    session = ParallelLoot.DataManager:GetCurrentSession()
    local conflicts = ParallelLoot.DataManager:DetectRangeConflicts(session)
    self:Assert(#conflicts == 0, "No Conflicts After Recycling", "Range conflicts after recycling")
    
    -- Clean up
    ParallelLoot.Integration:EndSession()
    
    self:PrintSummary()
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================

function TestWorkflows:RunAllTests()
    ParallelLoot:Print("=== Running All Test Workflows ===")
    self:ClearResults()
    
    self:TestSessionManagement()
    self:TestLootManagement()
    self:TestRollWorkflow()
    self:TestAwardWorkflow()
    self:TestDataPersistence()
    self:TestTimerWorkflow()
    self:TestRollRangeManagement()
    self:TestUniqueRollRanges()
    
    ParallelLoot:Print("=== All Tests Complete ===")
    self:PrintSummary()
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_PLTEST1 = "/pltest"
SlashCmdList["PLTEST"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "all" then
        TestWorkflows:RunAllTests()
    elseif command == "session" then
        TestWorkflows:TestSessionManagement()
    elseif command == "loot" then
        TestWorkflows:TestLootManagement()
    elseif command == "roll" then
        TestWorkflows:TestRollWorkflow()
    elseif command == "award" then
        TestWorkflows:TestAwardWorkflow()
    elseif command == "persist" then
        TestWorkflows:TestDataPersistence()
    elseif command == "timer" then
        TestWorkflows:TestTimerWorkflow()
    elseif command == "range" then
        TestWorkflows:TestRollRangeManagement()
    elseif command == "unique" then
        TestWorkflows:TestUniqueRollRanges()
    elseif command == "clear" then
        TestWorkflows:ClearResults()
    elseif command == "summary" then
        TestWorkflows:PrintSummary()
    else
        ParallelLoot:Print("ParallelLoot Test Commands:")
        print("  /pltest all - Run all tests")
        print("  /pltest session - Test session management")
        print("  /pltest loot - Test loot management")
        print("  /pltest roll - Test roll workflow")
        print("  /pltest award - Test award workflow")
        print("  /pltest persist - Test data persistence")
        print("  /pltest timer - Test timer management")
        print("  /pltest range - Test roll range management")
        print("  /pltest unique - Test unique roll ranges")
        print("  /pltest clear - Clear test results")
        print("  /pltest summary - Show test summary")
    end
end

ParallelLoot:Print("TestWorkflows loaded. Use /pltest for testing commands.")

