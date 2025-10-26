-- ParallelLoot Roll Range Manager Unit Tests
-- Task 2.2 Implementation - Unit Tests for roll range management system

local ParallelLoot = _G.ParallelLoot
if not ParallelLoot then
    error("ParallelLoot addon not found!")
    return
end

-- Test framework for roll range manager
ParallelLoot.RollRangeManagerTests = {}
local Tests = ParallelLoot.RollRangeManagerTests

-- Test results tracking
Tests.results = {
    passed = 0,
    failed = 0,
    errors = {}
}

-- Helper function to run a test
local function RunTest(testName, testFunction)
    print("|cff00ff00RollRangeManager Test:|r Running " .. testName .. "...")
    
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

-- ============================================================================
-- Range Assignment Algorithm Tests
-- ============================================================================

function Tests.TestRangeAssignmentAlgorithm()
    local RollRangeManager = ParallelLoot.RollRangeManager
    if not RollRangeManager then
        return false, "RollRangeManager not found"
    end
    
    -- Reset ranges for clean test
    RollRangeManager:ResetAllRanges()
    
    -- Test first range assignment (Requirements 9.1, 9.2)
    local range1 = RollRangeManager:GetNextRollRange()
    if not range1 then
        return false, "Failed to get first roll range"
    end
    
    if range1.baseRange ~= 1 then
        return false, "First range should start at 1, got " .. range1.baseRange
    end
    
    -- Verify BIS range (1-100)
    if range1.bis.min ~= 1 or range1.bis.max ~= 100 then
        return false, "BIS range should be 1-100, got " .. range1.bis.min .. "-" .. range1.bis.max
    end
    
    -- Verify MS range (1-99) - Requirement 9.1
    if range1.ms.min ~= 1 or range1.ms.max ~= 99 then
        return false, "MS range should be 1-99, got " .. range1.ms.min .. "-" .. range1.ms.max
    end
    
    -- Verify OS range (1-98) - Requirement 9.1
    if range1.os.min ~= 1 or range1.os.max ~= 98 then
        return false, "OS range should be 1-98, got " .. range1.os.min .. "-" .. range1.os.max
    end
    
    -- Verify COZ range (1-97) - Requirement 9.1
    if range1.coz.min ~= 1 or range1.coz.max ~= 97 then
        return false, "COZ range should be 1-97, got " .. range1.coz.min .. "-" .. range1.coz.max
    end
    
    -- Test second range assignment (Requirements 9.2, 9.3)
    local range2 = RollRangeManager:GetNextRollRange()
    if not range2 then
        return false, "Failed to get second roll range"
    end
    
    if range2.baseRange ~= 101 then
        return false, "Second range should start at 101, got " .. range2.baseRange
    end
    
    -- Verify BIS range (101-200)
    if range2.bis.min ~= 101 or range2.bis.max ~= 200 then
        return false, "Second BIS range should be 101-200, got " .. range2.bis.min .. "-" .. range2.bis.max
    end
    
    -- Test third range assignment
    local range3 = RollRangeManager:GetNextRollRange()
    if not range3 then
        return false, "Failed to get third roll range"
    end
    
    if range3.baseRange ~= 201 then
        return false, "Third range should start at 201, got " .. range3.baseRange
    end
    
    return true
end

function Tests.TestRangeRecyclingSystem()
    local RollRangeManager = ParallelLoot.RollRangeManager
    
    -- Reset ranges for clean test
    RollRangeManager:ResetAllRanges()
    
    -- Get initial ranges
    local range1 = RollRangeManager:GetNextRollRange()
    local range2 = RollRangeManager:GetNextRollRange()
    
    if not range1 or not range2 then
        return false, "Failed to get initial ranges"
    end
    
    -- Free the first range (Requirement 9.6)
    local success = RollRangeManager:FreeRollRange(range1.baseRange)
    if not success then
        return false, "Failed to free range " .. range1.baseRange
    end
    
    -- Get next range - should recycle the freed range
    local range3 = RollRangeManager:GetNextRollRange()
    if not range3 then
        return false, "Failed to get recycled range"
    end
    
    if range3.baseRange ~= range1.baseRange then
        return false, "Should recycle range " .. range1.baseRange .. ", got " .. range3.baseRange
    end
    
    -- Verify recycled range has correct structure
    if range3.bis.min ~= 1 or range3.bis.max ~= 100 then
        return false, "Recycled BIS range should be 1-100, got " .. range3.bis.min .. "-" .. range3.bis.max
    end
    
    return true
end

function Tests.TestRangeConflictDetection()
    local RollRangeManager = ParallelLoot.RollRangeManager
    
    -- Reset ranges for clean test
    RollRangeManager:ResetAllRanges()
    
    -- Get two ranges
    local range1 = RollRangeManager:GetNextRollRange()
    local range2 = RollRangeManager:GetNextRollRange()
    
    if not range1 or not range2 then
        return false, "Failed to get test ranges"
    end
    
    -- Test conflict detection for range1 (should have no conflicts initially)
    local conflicts1 = RollRangeManager:DetectRangeConflicts(range1)
    if #conflicts1 > 0 then
        return false, "Range1 should have no conflicts, found " .. #conflicts1
    end
    
    -- Test conflict detection for range2 (should have no conflicts with range1)
    local conflicts2 = RollRangeManager:DetectRangeConflicts(range2)
    if #conflicts2 > 0 then
        return false, "Range2 should have no conflicts with range1, found " .. #conflicts2
    end
    
    -- Create an artificial overlapping range to test conflict detection
    local overlappingRange = {
        baseRange = 50, -- Overlaps with range1 (1-100)
        bis = {min = 50, max = 150},
        ms = {min = 50, max = 149},
        os = {min = 50, max = 148},
        coz = {min = 50, max = 147}
    }
    
    -- Manually add to used ranges to simulate conflict
    table.insert(ParallelLoot.db.global.rollRangeManager.usedRanges, 50)
    
    local conflicts3 = RollRangeManager:DetectRangeConflicts(range1)
    if #conflicts3 == 0 then
        return false, "Should detect conflicts with overlapping range"
    end
    
    -- Clean up the artificial range
    for i, usedRange in ipairs(ParallelLoot.db.global.rollRangeManager.usedRanges) do
        if usedRange == 50 then
            table.remove(ParallelLoot.db.global.rollRangeManager.usedRanges, i)
            break
        end
    end
    
    return true
end

-- ============================================================================
-- Roll Validation Tests
-- ============================================================================

function Tests.TestRollValidation()
    local RollRangeManager = ParallelLoot.RollRangeManager
    
    -- Create test range
    local rollRange = RollRangeManager:CreateRollRange(1)
    if not rollRange then
        return false, "Failed to create test roll range"
    end
    
    -- Test valid BIS roll
    local valid, error = RollRangeManager:ValidateRoll(95, "bis", rollRange)
    if not valid then
        return false, "Roll 95 should be valid for BIS: " .. (error or "unknown error")
    end
    
    -- Test valid MS roll
    valid, error = RollRangeManager:ValidateRoll(99, "ms", rollRange)
    if not valid then
        return false, "Roll 99 should be valid for MS: " .. (error or "unknown error")
    end
    
    -- Test invalid BIS roll (too high)
    valid, error = RollRangeManager:ValidateRoll(101, "bis", rollRange)
    if valid then
        return false, "Roll 101 should not be valid for BIS range 1-100"
    end
    
    -- Test invalid MS roll (too high)
    valid, error = RollRangeManager:ValidateRoll(100, "ms", rollRange)
    if valid then
        return false, "Roll 100 should not be valid for MS range 1-99"
    end
    
    -- Test edge cases
    valid, error = RollRangeManager:ValidateRoll(1, "bis", rollRange)
    if not valid then
        return false, "Roll 1 should be valid for BIS: " .. (error or "unknown error")
    end
    
    valid, error = RollRangeManager:ValidateRoll(100, "bis", rollRange)
    if not valid then
        return false, "Roll 100 should be valid for BIS: " .. (error or "unknown error")
    end
    
    -- Test invalid inputs
    valid, error = RollRangeManager:ValidateRoll(nil, "bis", rollRange)
    if valid then
        return false, "Should not validate nil roll value"
    end
    
    valid, error = RollRangeManager:ValidateRoll(95, "invalid", rollRange)
    if valid then
        return false, "Should not validate invalid category"
    end
    
    return true
end

-- ============================================================================
-- AceDB Persistence Tests
-- ============================================================================

function Tests.TestAceDBPersistence()
    local RollRangeManager = ParallelLoot.RollRangeManager
    
    if not ParallelLoot.db or not ParallelLoot.db.global then
        return false, "AceDB not initialized"
    end
    
    -- Test database structure initialization
    if not ParallelLoot.db.global.rollRangeManager then
        return false, "RollRangeManager database structure not initialized"
    end
    
    local db = ParallelLoot.db.global.rollRangeManager
    
    -- Test required fields exist
    if not db.nextBaseRange or not db.usedRanges or not db.availableRanges then
        return false, "Required database fields missing"
    end
    
    if not db.rangeHistory or not db.conflictLog then
        return false, "History and conflict log fields missing"
    end
    
    -- Test profile settings
    if not ParallelLoot.db.profile.rollRanges then
        return false, "Profile roll range settings not initialized"
    end
    
    local profile = ParallelLoot.db.profile.rollRanges
    
    if not profile.baseRange or not profile.categoryOffsets then
        return false, "Profile range configuration missing"
    end
    
    -- Test data persistence by modifying values
    local originalNextRange = db.nextBaseRange
    db.nextBaseRange = 999
    
    if db.nextBaseRange ~= 999 then
        return false, "Database value not persisted"
    end
    
    -- Restore original value
    db.nextBaseRange = originalNextRange
    
    return true
end

function Tests.TestRangeStatistics()
    local RollRangeManager = ParallelLoot.RollRangeManager
    
    -- Reset for clean test
    RollRangeManager:ResetAllRanges()
    
    -- Get initial statistics
    local stats = RollRangeManager:GetRangeStatistics()
    if not stats then
        return false, "Failed to get range statistics"
    end
    
    -- Verify initial state
    if stats.nextBaseRange ~= 1 then
        return false, "Initial next base range should be 1, got " .. stats.nextBaseRange
    end
    
    if stats.usedRangesCount ~= 0 then
        return false, "Initial used ranges count should be 0, got " .. stats.usedRangesCount
    end
    
    if stats.availableRangesCount ~= 0 then
        return false, "Initial available ranges count should be 0, got " .. stats.availableRangesCount
    end
    
    -- Assign a range and check statistics
    local range1 = RollRangeManager:GetNextRollRange()
    if not range1 then
        return false, "Failed to assign range"
    end
    
    stats = RollRangeManager:GetRangeStatistics()
    
    if stats.nextBaseRange ~= 101 then
        return false, "Next base range should be 101 after first assignment, got " .. stats.nextBaseRange
    end
    
    if stats.usedRangesCount ~= 1 then
        return false, "Used ranges count should be 1 after assignment, got " .. stats.usedRangesCount
    end
    
    if stats.totalRangesAssigned ~= 1 then
        return false, "Total ranges assigned should be 1, got " .. stats.totalRangesAssigned
    end
    
    return true
end

-- ============================================================================
-- Integration Tests
-- ============================================================================

function Tests.TestLootSessionIntegration()
    local RollRangeManager = ParallelLoot.RollRangeManager
    local DataModels = ParallelLoot.DataModels
    
    if not DataModels or not DataModels.LootSession then
        return false, "DataModels.LootSession not available for integration test"
    end
    
    -- Reset ranges for clean test
    RollRangeManager:ResetAllRanges()
    
    -- Create test session
    local session = DataModels.LootSession:New("TestMaster")
    if not session then
        return false, "Failed to create test session"
    end
    
    -- Test that session uses RollRangeManager for range assignment
    local range1 = session:GetNextRollRange()
    if not range1 then
        return false, "Session failed to get roll range"
    end
    
    if range1.baseRange ~= 1 then
        return false, "Session should get range starting at 1, got " .. range1.baseRange
    end
    
    -- Test second range from session
    local range2 = session:GetNextRollRange()
    if not range2 then
        return false, "Session failed to get second roll range"
    end
    
    if range2.baseRange ~= 101 then
        return false, "Session should get second range starting at 101, got " .. range2.baseRange
    end
    
    -- Test range recycling through session award system
    -- Create test item with first range
    local itemLink = "|cffa335ee|Hitem:71617:0:0:0:0:0:0:0:85:0:0|h[Test Item]|h|r"
    local item = DataModels.LootItem:New(itemLink, range1, 71617)
    if not item then
        return false, "Failed to create test item"
    end
    
    -- Add item to session
    local success = session:AddItem(item)
    if not success then
        return false, "Failed to add item to session"
    end
    
    -- Award the item (should free the range)
    success = session:AwardItem(item.id, "TestPlayer")
    if not success then
        return false, "Failed to award item"
    end
    
    -- Get next range - should recycle the freed range
    local range3 = session:GetNextRollRange()
    if not range3 then
        return false, "Failed to get recycled range from session"
    end
    
    if range3.baseRange ~= 1 then
        return false, "Session should recycle range 1, got " .. range3.baseRange
    end
    
    return true
end

-- ============================================================================
-- Edge Case Tests
-- ============================================================================

function Tests.TestEdgeCases()
    local RollRangeManager = ParallelLoot.RollRangeManager
    
    -- Test invalid range freeing
    local success = RollRangeManager:FreeRollRange(nil)
    if success then
        return false, "Should not succeed freeing nil range"
    end
    
    success = RollRangeManager:FreeRollRange("invalid")
    if success then
        return false, "Should not succeed freeing invalid range"
    end
    
    -- Test double freeing same range
    RollRangeManager:ResetAllRanges()
    local range1 = RollRangeManager:GetNextRollRange()
    
    success = RollRangeManager:FreeRollRange(range1.baseRange)
    if not success then
        return false, "Should succeed freeing valid range"
    end
    
    success = RollRangeManager:FreeRollRange(range1.baseRange)
    if not success then
        return false, "Should handle double freeing gracefully (return true even if already freed)"
    end
    
    -- Test realistic high range numbers (40-person raid scenario)
    -- In a 40-person raid, we might have up to 40 items in a single session
    -- So test range 4001-4100 (40th item)
    -- Clear available ranges so it uses sequential assignment
    ParallelLoot.db.global.rollRangeManager.availableRanges = {}
    ParallelLoot.db.global.rollRangeManager.nextBaseRange = 4001
    
    local highRange = RollRangeManager:GetNextRollRange()
    
    if not highRange then
        return false, "Failed to get realistic high range"
    end
    
    if highRange.baseRange ~= 4001 then
        return false, "Should handle realistic high range numbers, expected 4001, got " .. tostring(highRange.baseRange)
    end
    
    -- Calculate expected BIS max: baseRange + baseRange + categoryOffset - 1
    -- 4001 + 100 + 0 - 1 = 4100
    local expectedBisMax = 4001 + 100 + 0 - 1
    if highRange.bis.max ~= expectedBisMax then
        return false, "High range BIS should be calculated correctly, expected " .. expectedBisMax .. ", got " .. tostring(highRange.bis.max)
    end
    
    return true
end

-- ============================================================================
-- Main Test Runner
-- ============================================================================

function Tests.RunAllTests()
    print("|cff00ff00ParallelLoot RollRangeManager Tests:|r Starting comprehensive test suite...")
    
    -- Reset results
    Tests.results = {
        passed = 0,
        failed = 0,
        errors = {}
    }
    
    -- Run all test categories
    print("\n|cff00ff00Testing Range Assignment Algorithm:|r")
    RunTest("Range Assignment Algorithm", Tests.TestRangeAssignmentAlgorithm)
    RunTest("Range Recycling System", Tests.TestRangeRecyclingSystem)
    RunTest("Range Conflict Detection", Tests.TestRangeConflictDetection)
    
    print("\n|cff00ff00Testing Roll Validation:|r")
    RunTest("Roll Validation", Tests.TestRollValidation)
    
    print("\n|cff00ff00Testing AceDB Persistence:|r")
    RunTest("AceDB Persistence", Tests.TestAceDBPersistence)
    RunTest("Range Statistics", Tests.TestRangeStatistics)
    
    print("\n|cff00ff00Testing Integration:|r")
    RunTest("LootSession Integration", Tests.TestLootSessionIntegration)
    
    print("\n|cff00ff00Testing Edge Cases:|r")
    RunTest("Edge Cases", Tests.TestEdgeCases)
    
    -- Print final results
    local total = Tests.results.passed + Tests.results.failed
    local passRate = total > 0 and math.floor((Tests.results.passed / total) * 100) or 0
    
    print("\n|cff00ff00RollRangeManager Test Results:|r")
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

-- Export test functions for external access
ParallelLoot.RollRangeManagerTests = Tests

print("|cff888888ParallelLoot:|r RollRangeManagerTests module loaded successfully")