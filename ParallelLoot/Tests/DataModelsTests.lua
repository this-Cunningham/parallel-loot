-- ParallelLoot Data Models Unit Tests
-- Task 2.1 Implementation - Unit Tests for data structure validation

local ParallelLoot = _G.ParallelLoot
if not ParallelLoot then
    error("ParallelLoot addon not found!")
    return
end

-- Test framework for data models
ParallelLoot.DataModelsTests = {}
local Tests = ParallelLoot.DataModelsTests

-- Test results tracking
Tests.results = {
    passed = 0,
    failed = 0,
    errors = {}
}

-- Helper function to run a test
local function RunTest(testName, testFunction)
    print("|cff00ff00DataModels Test:|r Running " .. testName .. "...")
    
    local success, result = pcall(testFunction)
    
    if success and result then
        Tests.results.passed = Tests.results.passed + 1
        print("  " .. testName .. ": |cff00ff00PASS|r")
        return true
    else
        Tests.results.failed = Tests.results.failed + 1
        local errorMsg = success and "Test returned false" or result
        table.insert(Tests.results.errors, testName .. ": " .. errorMsg)
        print("  " .. testName .. ": |cffff0000FAIL|r - " .. errorMsg)
        return false
    end
end

-- Helper function to create test item link
local function CreateTestItemLink(itemId)
    itemId = itemId or 71617 -- Zin'rokh, Destroyer of Worlds (MoP raid weapon)
    return "|cffa335ee|Hitem:" .. itemId .. ":0:0:0:0:0:0:0:85:0:0|h[Test Item]|h|r"
end

-- Helper function to create test roll range
local function CreateTestRollRange(baseRange)
    baseRange = baseRange or 1
    return {
        baseRange = baseRange,
        bis = {min = baseRange, max = baseRange + 99},
        ms = {min = baseRange, max = baseRange + 98},
        os = {min = baseRange, max = baseRange + 97},
        coz = {min = baseRange, max = baseRange + 96}
    }
end

-- ============================================================================
-- LootSession Tests
-- ============================================================================

function Tests.TestLootSessionCreation()
    local DataModels = ParallelLoot.DataModels
    if not DataModels or not DataModels.LootSession then
        return false, "DataModels.LootSession not found"
    end
    
    -- Test valid session creation
    local session = DataModels.LootSession:New("TestMaster")
    if not session then
        return false, "Failed to create valid session"
    end
    
    -- Validate session structure
    local valid, error = session:Validate()
    if not valid then
        return false, "Session validation failed: " .. (error or "unknown")
    end
    
    -- Test session properties
    if session.masterId ~= "TestMaster" then
        return false, "Master ID not set correctly"
    end
    
    if not session.id or type(session.id) ~= "string" then
        return false, "Session ID not generated"
    end
    
    if not session.startTime or type(session.startTime) ~= "number" then
        return false, "Start time not set"
    end
    
    if session.status ~= "active" then
        return false, "Initial status not set to active"
    end
    
    return true
end

function Tests.TestLootSessionInvalidCreation()
    local DataModels = ParallelLoot.DataModels
    
    -- Test invalid master ID
    local session = DataModels.LootSession:New("")
    if session then
        return false, "Should not create session with empty master ID"
    end
    
    session = DataModels.LootSession:New(nil)
    if session then
        return false, "Should not create session with nil master ID"
    end
    
    session = DataModels.LootSession:New("A") -- Too short
    if session then
        return false, "Should not create session with invalid master ID"
    end
    
    return true
end

function Tests.TestLootSessionRollRangeManagement()
    local DataModels = ParallelLoot.DataModels
    local session = DataModels.LootSession:New("TestMaster")
    
    if not session then
        return false, "Failed to create session"
    end
    
    -- Test getting first roll range
    local range1 = session:GetNextRollRange()
    if not range1 or range1.baseRange ~= 1 then
        return false, "First roll range should start at 1"
    end
    
    if range1.bis.min ~= 1 or range1.bis.max ~= 100 then
        return false, "BIS range incorrect for first item"
    end
    
    if range1.ms.min ~= 1 or range1.ms.max ~= 99 then
        return false, "MS range incorrect for first item"
    end
    
    -- Test getting second roll range
    local range2 = session:GetNextRollRange()
    if not range2 or range2.baseRange ~= 101 then
        return false, "Second roll range should start at 101"
    end
    
    if range2.bis.min ~= 101 or range2.bis.max ~= 200 then
        return false, "BIS range incorrect for second item"
    end
    
    return true
end

function Tests.TestLootSessionItemManagement()
    local DataModels = ParallelLoot.DataModels
    local session = DataModels.LootSession:New("TestMaster")
    
    if not session then
        return false, "Failed to create session"
    end
    
    -- Create test item
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    
    if not item then
        return false, "Failed to create test item"
    end
    
    -- Test adding item to session
    local success = session:AddItem(item)
    if not success then
        return false, "Failed to add item to session"
    end
    
    if #session.activeItems ~= 1 then
        return false, "Item not added to active items"
    end
    
    if session.metadata.totalItemsProcessed ~= 1 then
        return false, "Total items processed not updated"
    end
    
    -- Test awarding item
    success = session:AwardItem(item.id, "TestPlayer")
    if not success then
        return false, "Failed to award item"
    end
    
    if #session.activeItems ~= 0 then
        return false, "Item not removed from active items"
    end
    
    if #session.awardedItems ~= 1 then
        return false, "Item not added to awarded items"
    end
    
    if session.awardedItems[1].awardedTo ~= "TestPlayer" then
        return false, "Awarded player not set correctly"
    end
    
    return true
end

-- ============================================================================
-- LootItem Tests
-- ============================================================================

function Tests.TestLootItemCreation()
    local DataModels = ParallelLoot.DataModels
    if not DataModels or not DataModels.LootItem then
        return false, "DataModels.LootItem not found"
    end
    
    -- Test valid item creation
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    
    if not item then
        return false, "Failed to create valid item"
    end
    
    -- Validate item structure
    local valid, error = item:Validate()
    if not valid then
        return false, "Item validation failed: " .. (error or "unknown")
    end
    
    -- Test item properties
    if item.itemLink ~= itemLink then
        return false, "Item link not set correctly"
    end
    
    if item.itemId ~= 71617 then
        return false, "Item ID not set correctly"
    end
    
    if not item.id or type(item.id) ~= "string" then
        return false, "Item ID not generated"
    end
    
    if not item.dropTime or type(item.dropTime) ~= "number" then
        return false, "Drop time not set"
    end
    
    if item.status ~= "active" then
        return false, "Initial status not set to active"
    end
    
    return true
end

function Tests.TestLootItemInvalidCreation()
    local DataModels = ParallelLoot.DataModels
    
    -- Test invalid item link
    local item = DataModels.LootItem:New("")
    if item then
        return false, "Should not create item with empty link"
    end
    
    item = DataModels.LootItem:New(nil)
    if item then
        return false, "Should not create item with nil link"
    end
    
    item = DataModels.LootItem:New("invalid_link")
    if item then
        return false, "Should not create item with invalid link"
    end
    
    return true
end

function Tests.TestLootItemRollManagement()
    local DataModels = ParallelLoot.DataModels
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    
    if not item then
        return false, "Failed to create item"
    end
    
    -- Create test roll
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 95, item.id)
    if not roll then
        return false, "Failed to create test roll"
    end
    
    -- Test adding roll to item
    local success = item:AddRoll(roll)
    if not success then
        return false, "Failed to add roll to item"
    end
    
    if #item.rolls ~= 1 then
        return false, "Roll not added to item"
    end
    
    if item.rollStats.totalRolls ~= 1 then
        return false, "Roll stats not updated"
    end
    
    if item.rollStats.rollsByCategory.bis ~= 1 then
        return false, "Category roll count not updated"
    end
    
    if item.rollStats.highestRoll.value ~= 95 then
        return false, "Highest roll not tracked"
    end
    
    -- Test duplicate roll prevention
    local duplicateRoll = DataModels.PlayerRoll:New("TestPlayer", "ms", 80, item.id)
    success = item:AddRoll(duplicateRoll)
    if success then
        return false, "Should not allow duplicate rolls from same player"
    end
    
    return true
end

function Tests.TestLootItemSortedRolls()
    local DataModels = ParallelLoot.DataModels
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    
    if not item then
        return false, "Failed to create item"
    end
    
    -- Verify item has GetSortedRolls method
    if not item.GetSortedRolls or type(item.GetSortedRolls) ~= "function" then
        return false, "Item missing GetSortedRolls method"
    end
    
    -- Add multiple rolls with range validation
    local rolls = {
        {player = "Thorgrim", category = "bis", value = 95},
        {player = "Elaria", category = "bis", value = 88},
        {player = "Kazrak", category = "ms", value = 92},
        {player = "Sylvana", category = "bis", value = 99},
        {player = "Drakken", category = "os", value = 75}
    }
    
    for i, rollData in ipairs(rolls) do
        local roll = DataModels.PlayerRoll:New(rollData.player, rollData.category, rollData.value, item.id)
        if not roll then
            return false, "Failed to create roll " .. i .. " for " .. rollData.player
        end
        
        -- Validate roll before adding
        local rollValid, rollError = roll:Validate()
        if not rollValid then
            return false, "Roll " .. i .. " validation failed: " .. (rollError or "unknown")
        end
        
        local success = item:AddRoll(roll)
        if not success then
            return false, "Failed to add roll " .. i .. " for " .. rollData.player
        end
    end
    
    -- Verify all rolls were added
    if #item.rolls ~= 5 then
        return false, "Expected 5 rolls, got " .. #item.rolls
    end
    
    -- Test sorted rolls
    local sortedRolls = item:GetSortedRolls()
    
    if not sortedRolls then
        return false, "GetSortedRolls returned nil"
    end
    
    if type(sortedRolls) ~= "table" then
        return false, "GetSortedRolls returned non-table: " .. type(sortedRolls)
    end
    
    -- Check BIS category sorting (should be 99, 95, 88)
    if not sortedRolls.bis then
        return false, "BIS category missing from sorted rolls"
    end
    
    if type(sortedRolls.bis) ~= "table" then
        return false, "BIS category is not a table"
    end
    
    if #sortedRolls.bis ~= 3 then
        return false, "BIS category should have 3 rolls, got " .. #sortedRolls.bis
    end
    
    -- Verify BIS rolls are sorted correctly (highest first)
    local bisValues = {}
    for i, roll in ipairs(sortedRolls.bis) do
        if not roll or not roll.rollValue then
            return false, "BIS roll " .. i .. " is invalid"
        end
        table.insert(bisValues, roll.rollValue)
    end
    
    -- Check if sorted in descending order
    for i = 1, #bisValues - 1 do
        if bisValues[i] < bisValues[i + 1] then
            return false, "BIS rolls not sorted correctly: " .. table.concat(bisValues, ", ")
        end
    end
    
    -- Check specific values
    if bisValues[1] ~= 99 or bisValues[2] ~= 95 or bisValues[3] ~= 88 then
        return false, "BIS roll values incorrect: expected 99,95,88 got " .. table.concat(bisValues, ",")
    end
    
    -- Check MS category
    if not sortedRolls.ms or type(sortedRolls.ms) ~= "table" then
        return false, "MS category missing or invalid"
    end
    
    if #sortedRolls.ms ~= 1 then
        return false, "MS category should have 1 roll, got " .. #sortedRolls.ms
    end
    
    if not sortedRolls.ms[1] or sortedRolls.ms[1].rollValue ~= 92 then
        local actualValue = sortedRolls.ms[1] and sortedRolls.ms[1].rollValue or "nil"
        return false, "MS roll should be 92, got " .. tostring(actualValue)
    end
    
    -- Check OS category
    if not sortedRolls.os or type(sortedRolls.os) ~= "table" then
        return false, "OS category missing or invalid"
    end
    
    if #sortedRolls.os ~= 1 then
        return false, "OS category should have 1 roll, got " .. #sortedRolls.os
    end
    
    if not sortedRolls.os[1] or sortedRolls.os[1].rollValue ~= 75 then
        local actualValue = sortedRolls.os[1] and sortedRolls.os[1].rollValue or "nil"
        return false, "OS roll should be 75, got " .. tostring(actualValue)
    end
    
    -- Check COZ category (should be empty)
    if not sortedRolls.coz or type(sortedRolls.coz) ~= "table" then
        return false, "COZ category missing or invalid"
    end
    
    if #sortedRolls.coz ~= 0 then
        return false, "COZ category should be empty, got " .. #sortedRolls.coz
    end
    
    return true
end

-- ============================================================================
-- PlayerRoll Tests
-- ============================================================================

function Tests.TestPlayerRollCreation()
    local DataModels = ParallelLoot.DataModels
    if not DataModels or not DataModels.PlayerRoll then
        return false, "DataModels.PlayerRoll not found"
    end
    
    -- Test valid roll creation
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 95, "test_item_id")
    
    if not roll then
        return false, "Failed to create valid roll"
    end
    
    -- Validate roll structure
    local valid, error = roll:Validate()
    if not valid then
        return false, "Roll validation failed: " .. (error or "unknown")
    end
    
    -- Test roll properties
    if roll.playerName ~= "TestPlayer" then
        return false, "Player name not set correctly"
    end
    
    if roll.category ~= "bis" then
        return false, "Category not set correctly"
    end
    
    if roll.rollValue ~= 95 then
        return false, "Roll value not set correctly"
    end
    
    if not roll.id or type(roll.id) ~= "string" then
        return false, "Roll ID not generated"
    end
    
    if not roll.timestamp or type(roll.timestamp) ~= "number" then
        return false, "Timestamp not set"
    end
    
    return true
end

function Tests.TestPlayerRollInvalidCreation()
    local DataModels = ParallelLoot.DataModels
    
    -- Test invalid player name
    local roll = DataModels.PlayerRoll:New("", "bis", 95)
    if roll then
        return false, "Should not create roll with empty player name"
    end
    
    roll = DataModels.PlayerRoll:New("A", "bis", 95) -- Too short
    if roll then
        return false, "Should not create roll with invalid player name"
    end
    
    -- Test invalid category
    roll = DataModels.PlayerRoll:New("TestPlayer", "invalid", 95)
    if roll then
        return false, "Should not create roll with invalid category"
    end
    
    roll = DataModels.PlayerRoll:New("TestPlayer", "", 95)
    if roll then
        return false, "Should not create roll with empty category"
    end
    
    -- Test invalid roll value
    roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 0)
    if roll then
        return false, "Should not create roll with value 0"
    end
    
    roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 1001)
    if roll then
        return false, "Should not create roll with value > 1000"
    end
    
    roll = DataModels.PlayerRoll:New("TestPlayer", "bis", "invalid")
    if roll then
        return false, "Should not create roll with non-numeric value"
    end
    
    return true
end

function Tests.TestPlayerRollRangeValidation()
    local DataModels = ParallelLoot.DataModels
    
    -- Test valid range validation
    local rollRange = CreateTestRollRange()
    if not rollRange then
        return false, "Failed to create test roll range"
    end
    
    if not rollRange.bis then
        return false, "Roll range missing BIS category"
    end
    
    -- Test BIS roll (should be valid)
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 95)
    if not roll then
        return false, "Failed to create BIS roll"
    end
    
    -- Verify roll has ValidateAgainstRange method
    if not roll.ValidateAgainstRange or type(roll.ValidateAgainstRange) ~= "function" then
        return false, "Roll missing ValidateAgainstRange method"
    end
    
    local valid = roll:ValidateAgainstRange(rollRange)
    if not valid then
        return false, "Roll 95 should be valid against BIS range " .. rollRange.bis.min .. "-" .. rollRange.bis.max
    end
    
    if not roll.metadata then
        return false, "Roll metadata missing"
    end
    
    if not roll.metadata.validated then
        return false, "Roll should be marked as validated"
    end
    
    -- Test MS roll (edge case that might be failing)
    local msRoll = DataModels.PlayerRoll:New("Kazrak", "ms", 92)
    if not msRoll then
        return false, "Failed to create MS roll"
    end
    
    local msValid = msRoll:ValidateAgainstRange(rollRange)
    if not msValid then
        return false, "Roll 92 should be valid against MS range " .. rollRange.ms.min .. "-" .. rollRange.ms.max
    end
    
    -- Test invalid range validation (roll too high)
    local roll2 = DataModels.PlayerRoll:New("Morgrim", "bis", 150)
    if not roll2 then
        return false, "Failed to create invalid roll"
    end
    
    valid = roll2:ValidateAgainstRange(rollRange)
    if valid then
        return false, "Roll 150 should not be valid against BIS range " .. rollRange.bis.min .. "-" .. rollRange.bis.max
    end
    
    -- Test edge case: MS roll at max value
    local msEdgeRoll = DataModels.PlayerRoll:New("Valdris", "ms", 99)
    if not msEdgeRoll then
        return false, "Failed to create MS edge roll"
    end
    
    local msEdgeValid = msEdgeRoll:ValidateAgainstRange(rollRange)
    if not msEdgeValid then
        return false, "Roll 99 should be valid against MS range " .. rollRange.ms.min .. "-" .. rollRange.ms.max
    end
    
    -- Test edge case: MS roll just over max value
    local msOverRoll = DataModels.PlayerRoll:New("Grimjaw", "ms", 100)
    if not msOverRoll then
        return false, "Failed to create MS over roll"
    end
    
    local msOverValid = msOverRoll:ValidateAgainstRange(rollRange)
    if msOverValid then
        return false, "Roll 100 should not be valid against MS range " .. rollRange.ms.min .. "-" .. rollRange.ms.max
    end
    
    return true
end

-- ============================================================================
-- Utility Function Tests
-- ============================================================================

function Tests.TestUtilityFunctions()
    local DataModels = ParallelLoot.DataModels
    local Utils = DataModels.Utils
    
    if not Utils then
        return false, "Utils module not found"
    end
    
    -- Create test session with items
    local session = DataModels.LootSession:New("TestMaster")
    if not session then
        return false, "Failed to create test session"
    end
    
    -- Create and add test item
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    if not item then
        return false, "Failed to create test item"
    end
    
    session:AddItem(item)
    
    -- Test FindItemById
    local foundItem, status = Utils.FindItemById(session, item.id)
    if not foundItem or status ~= "active" then
        return false, "FindItemById failed to find active item"
    end
    
    -- Test with non-existent item
    foundItem, status = Utils.FindItemById(session, "non_existent")
    if foundItem or status ~= "not_found" then
        return false, "FindItemById should return not_found for non-existent item"
    end
    
    -- Add roll and test FindPlayerRoll
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 95, item.id)
    if not roll then
        return false, "Failed to create test roll"
    end
    
    item:AddRoll(roll)
    
    local foundRoll = Utils.FindPlayerRoll(item, "TestPlayer")
    if not foundRoll or foundRoll.rollValue ~= 95 then
        return false, "FindPlayerRoll failed"
    end
    
    -- Test GetPlayerRolls
    local playerRolls = Utils.GetPlayerRolls(session, "TestPlayer")
    if #playerRolls ~= 1 or playerRolls[1].roll.rollValue ~= 95 then
        return false, "GetPlayerRolls failed"
    end
    
    -- Test GetSessionSummary
    local summary = Utils.GetSessionSummary(session)
    if not summary or summary.totalRolls ~= 1 or summary.playerCount ~= 1 then
        return false, "GetSessionSummary failed"
    end
    
    return true
end

function Tests.TestDataIntegrityValidation()
    local DataModels = ParallelLoot.DataModels
    local Utils = DataModels.Utils
    
    -- Create valid session with data
    local session = DataModels.LootSession:New("TestMaster")
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 95, item.id)
    
    if not session or not item or not roll then
        return false, "Failed to create test objects"
    end
    
    item:AddRoll(roll)
    session:AddItem(item)
    
    -- Test valid session integrity
    local valid, errors = Utils.ValidateSessionIntegrity(session)
    if not valid then
        return false, "Session integrity validation failed: " .. table.concat(errors, ", ")
    end
    
    -- Test with corrupted data
    local corruptedSession = DataModels.LootSession:New("TestMaster")
    corruptedSession.id = nil -- Corrupt the session
    
    valid, errors = Utils.ValidateSessionIntegrity(corruptedSession)
    if valid then
        return false, "Should detect corrupted session data"
    end
    
    return true
end

-- ============================================================================
-- Edge Case Tests
-- ============================================================================

function Tests.TestEdgeCases()
    local DataModels = ParallelLoot.DataModels
    
    -- Test maximum roll values
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 1000)
    if not roll then
        return false, "Should allow maximum roll value 1000"
    end
    
    -- Test minimum roll values
    roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 1)
    if not roll then
        return false, "Should allow minimum roll value 1"
    end
    
    -- Test maximum player name length
    local longName = string.rep("A", 12) -- 12 characters (WoW max)
    roll = DataModels.PlayerRoll:New(longName, "bis", 50)
    if not roll then
        return false, "Should allow 12-character player names"
    end
    
    -- Test minimum player name length
    roll = DataModels.PlayerRoll:New("AB", "bis", 50) -- 2 characters (WoW min)
    if not roll then
        return false, "Should allow 2-character player names"
    end
    
    -- Test case insensitive categories
    roll = DataModels.PlayerRoll:New("TestPlayer", "BIS", 50)
    if not roll or roll.category ~= "bis" then
        return false, "Should handle case insensitive categories"
    end
    
    return true
end

-- ============================================================================
-- Main Test Runner
-- ============================================================================

function Tests.RunAllTests()
    print("|cff00ff00ParallelLoot DataModels Tests:|r Starting comprehensive test suite...")
    
    -- Reset results
    Tests.results = {
        passed = 0,
        failed = 0,
        errors = {}
    }
    
    -- Run all test categories
    print("\n|cff00ff00Testing LootSession:|r")
    RunTest("LootSession Creation", Tests.TestLootSessionCreation)
    RunTest("LootSession Invalid Creation", Tests.TestLootSessionInvalidCreation)
    RunTest("LootSession Roll Range Management", Tests.TestLootSessionRollRangeManagement)
    RunTest("LootSession Item Management", Tests.TestLootSessionItemManagement)
    
    print("\n|cff00ff00Testing LootItem:|r")
    RunTest("LootItem Creation", Tests.TestLootItemCreation)
    RunTest("LootItem Invalid Creation", Tests.TestLootItemInvalidCreation)
    RunTest("LootItem Roll Management", Tests.TestLootItemRollManagement)
    RunTest("LootItem Sorted Rolls", Tests.TestLootItemSortedRolls)
    
    print("\n|cff00ff00Testing PlayerRoll:|r")
    RunTest("PlayerRoll Creation", Tests.TestPlayerRollCreation)
    RunTest("PlayerRoll Invalid Creation", Tests.TestPlayerRollInvalidCreation)
    RunTest("PlayerRoll Range Validation", Tests.TestPlayerRollRangeValidation)
    
    print("\n|cff00ff00Testing Utilities:|r")
    RunTest("Utility Functions", Tests.TestUtilityFunctions)
    RunTest("Data Integrity Validation", Tests.TestDataIntegrityValidation)
    
    print("\n|cff00ff00Testing Edge Cases:|r")
    RunTest("Edge Cases", Tests.TestEdgeCases)
    
    -- Print final results
    local total = Tests.results.passed + Tests.results.failed
    local passRate = total > 0 and math.floor((Tests.results.passed / total) * 100) or 0
    
    print("\n|cff00ff00DataModels Test Results:|r")
    print("Total Tests: " .. total)
    print("Passed: |cff00ff00" .. Tests.results.passed .. "|r")
    print("Failed: |cffff0000" .. Tests.results.failed .. "|r")
    print("Pass Rate: " .. passRate .. "%")
    
    if Tests.results.failed > 0 then
        print("\n|cffff0000Failed Tests:|r")
        for _, error in ipairs(Tests.results.errors) do
            print("  " .. error)
        end
    end
    
    local success = Tests.results.failed == 0
    print("\n|cff00ff00Overall Result:|r " .. (success and "|cff00ff00ALL TESTS PASSED|r" or "|cffff0000SOME TESTS FAILED|r"))
    
    return success
end

-- Debug function to test individual components
function Tests.DebugSortedRolls()
    print("|cff00ff00Debug:|r Testing sorted rolls step by step...")
    
    local DataModels = ParallelLoot.DataModels
    if not DataModels then
        print("DataModels not found")
        return false
    end
    
    -- Create item
    local itemLink = CreateTestItemLink()
    local rollRange = CreateTestRollRange()
    local item = DataModels.LootItem:New(itemLink, rollRange, 71617)
    
    if not item then
        print("Failed to create item")
        return false
    end
    
    print("Item created successfully")
    
    -- Create and add one roll at a time
    local roll1 = DataModels.PlayerRoll:New("Thorgrim", "bis", 95, item.id)
    if not roll1 then
        print("Failed to create roll1")
        return false
    end
    
    print("Roll1 created: " .. roll1.playerName .. " " .. roll1.category .. " " .. roll1.rollValue)
    
    local success = item:AddRoll(roll1)
    if not success then
        print("Failed to add roll1")
        return false
    end
    
    print("Roll1 added successfully. Total rolls: " .. #item.rolls)
    
    -- Test GetSortedRolls with just one roll
    local sortedRolls = item:GetSortedRolls()
    if not sortedRolls then
        print("GetSortedRolls returned nil")
        return false
    end
    
    print("GetSortedRolls returned successfully")
    print("BIS rolls: " .. #sortedRolls.bis)
    
    if #sortedRolls.bis ~= 1 then
        print("Expected 1 BIS roll, got " .. #sortedRolls.bis)
        return false
    end
    
    if sortedRolls.bis[1].rollValue ~= 95 then
        print("Expected roll value 95, got " .. sortedRolls.bis[1].rollValue)
        return false
    end
    
    print("Single roll test passed!")
    return true
end

function Tests.DebugRangeValidation()
    print("|cff00ff00Debug:|r Testing range validation step by step...")
    
    local DataModels = ParallelLoot.DataModels
    if not DataModels then
        print("DataModels not found")
        return false
    end
    
    -- Create range first
    local rollRange = CreateTestRollRange()
    if not rollRange then
        print("Failed to create roll range")
        return false
    end
    
    print("Roll range created")
    print("BIS range: " .. rollRange.bis.min .. "-" .. rollRange.bis.max)
    print("MS range: " .. rollRange.ms.min .. "-" .. rollRange.ms.max)
    print("OS range: " .. rollRange.os.min .. "-" .. rollRange.os.max)
    print("COZ range: " .. rollRange.coz.min .. "-" .. rollRange.coz.max)
    
    -- Test BIS roll
    local roll = DataModels.PlayerRoll:New("TestPlayer", "bis", 95)
    if not roll then
        print("Failed to create BIS roll")
        return false
    end
    
    print("BIS Roll created: " .. roll.playerName .. " " .. roll.category .. " " .. roll.rollValue)
    
    local valid = roll:ValidateAgainstRange(rollRange)
    print("BIS Validation result: " .. tostring(valid))
    
    if not valid then
        print("BIS Validation failed unexpectedly")
        return false
    end
    
    -- Test MS roll (this might be the problematic one)
    local msRoll = DataModels.PlayerRoll:New("Kazrak", "ms", 92)
    if not msRoll then
        print("Failed to create MS roll")
        return false
    end
    
    print("MS Roll created: " .. msRoll.playerName .. " " .. msRoll.category .. " " .. msRoll.rollValue)
    
    local msValid = msRoll:ValidateAgainstRange(rollRange)
    print("MS Validation result: " .. tostring(msValid))
    
    if not msValid then
        print("MS Validation failed - this might be the issue!")
        print("MS roll value: " .. msRoll.rollValue)
        print("MS range: " .. rollRange.ms.min .. "-" .. rollRange.ms.max)
        print("Should be valid: " .. tostring(msRoll.rollValue >= rollRange.ms.min and msRoll.rollValue <= rollRange.ms.max))
        return false
    end
    
    print("Range validation test passed!")
    return true
end

-- Export test functions for external access
ParallelLoot.DataModelsTests = Tests

print("|cff888888ParallelLoot:|r DataModelsTests module loaded successfully")