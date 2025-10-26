-- ParallelLoot Roll Range Management System
-- Task 2.2 Implementation - Automatic roll range assignment with AceDB persistence

local ParallelLoot = _G.ParallelLoot
if not ParallelLoot then
    error("ParallelLoot addon not found!")
    return
end

-- Roll Range Manager Module
ParallelLoot.RollRangeManager = {}
local RollRangeManager = ParallelLoot.RollRangeManager

-- Constants for roll range management
local RANGE_SIZE = 100
local CATEGORY_OFFSETS = {
    bis = 0,  -- Full range (e.g., 1-100)
    ms = -1,  -- One less (e.g., 1-99)
    os = -2,  -- Two less (e.g., 1-98)
    coz = -3  -- Three less (e.g., 1-97)
}

-- Initialize the roll range manager
function RollRangeManager:Initialize()
    if not ParallelLoot.db then
        error("RollRangeManager: Database not initialized!")
        return false
    end
    
    -- Initialize database structure for roll range management
    if not ParallelLoot.db.global.rollRangeManager then
        ParallelLoot.db.global.rollRangeManager = {
            nextBaseRange = 1,
            usedRanges = {},
            availableRanges = {},
            rangeHistory = {},
            conflictLog = {}
        }
    end
    
    -- Initialize profile-specific range settings
    if not ParallelLoot.db.profile.rollRanges then
        ParallelLoot.db.profile.rollRanges = {
            baseRange = RANGE_SIZE,
            categoryOffsets = CATEGORY_OFFSETS,
            enableRangeRecycling = true,
            maxRangeHistory = 100
        }
    else
        -- Ensure all required fields exist with defaults
        local profile = ParallelLoot.db.profile.rollRanges
        if profile.baseRange == nil then profile.baseRange = RANGE_SIZE end
        if profile.categoryOffsets == nil then profile.categoryOffsets = CATEGORY_OFFSETS end
        if profile.enableRangeRecycling == nil then profile.enableRangeRecycling = true end
        if profile.maxRangeHistory == nil then profile.maxRangeHistory = 100 end
    end
    
    print("|cff888888ParallelLoot:|r RollRangeManager initialized successfully")
    return true
end

-- Get the next available roll range for a new item
function RollRangeManager:GetNextRollRange()
    -- Ensure initialization
    if not ParallelLoot.db.global.rollRangeManager or not ParallelLoot.db.profile.rollRanges then
        self:Initialize()
    end
    
    local db = ParallelLoot.db.global.rollRangeManager
    local profile = ParallelLoot.db.profile.rollRanges
    local baseRange
    
    -- Check if we have recycled ranges available and recycling is enabled (default to true)
    local recyclingEnabled = profile.enableRangeRecycling
    if recyclingEnabled == nil then
        recyclingEnabled = true -- Default to enabled
        profile.enableRangeRecycling = true
    end
    
    if recyclingEnabled and #db.availableRanges > 0 then
        -- Use the lowest available recycled range
        table.sort(db.availableRanges)
        baseRange = table.remove(db.availableRanges, 1)
        
        print("|cff888888RollRangeManager:|r Recycling range starting at " .. baseRange)
    else
        -- Use next sequential range
        baseRange = db.nextBaseRange
        db.nextBaseRange = db.nextBaseRange + profile.baseRange
        
        print("|cff888888RollRangeManager:|r Assigning new range starting at " .. baseRange)
    end
    
    -- Create the roll range structure
    local rollRange = self:CreateRollRange(baseRange)
    
    -- Track the used range
    table.insert(db.usedRanges, baseRange)
    
    -- Add to range history for tracking
    table.insert(db.rangeHistory, {
        baseRange = baseRange,
        assignedAt = time(),
        recycled = #db.availableRanges > 0
    })
    
    -- Cleanup old history if needed
    self:CleanupRangeHistory()
    
    -- Validate the range for conflicts
    local conflicts = self:DetectRangeConflicts(rollRange)
    if #conflicts > 0 then
        self:LogRangeConflicts(baseRange, conflicts)
        print("|cffff8800RollRangeManager Warning:|r Range conflicts detected for base range " .. baseRange)
    end
    
    return rollRange
end

-- Create a roll range structure with category offsets
function RollRangeManager:CreateRollRange(baseRange)
    -- Ensure initialization
    if not ParallelLoot.db.profile.rollRanges then
        self:Initialize()
    end
    
    local profile = ParallelLoot.db.profile.rollRanges
    local rollRange = {
        baseRange = baseRange,
        bis = {
            min = baseRange,
            max = baseRange + profile.baseRange + profile.categoryOffsets.bis - 1
        },
        ms = {
            min = baseRange,
            max = baseRange + profile.baseRange + profile.categoryOffsets.ms - 1
        },
        os = {
            min = baseRange,
            max = baseRange + profile.baseRange + profile.categoryOffsets.os - 1
        },
        coz = {
            min = baseRange,
            max = baseRange + profile.baseRange + profile.categoryOffsets.coz - 1
        }
    }
    
    return rollRange
end

-- Free up a roll range when an item is awarded (for recycling)
function RollRangeManager:FreeRollRange(baseRange)
    if not baseRange or type(baseRange) ~= "number" then
        print("|cffff0000RollRangeManager Error:|r Invalid base range for freeing: " .. tostring(baseRange))
        return false
    end
    
    -- Ensure initialization
    if not ParallelLoot.db.global.rollRangeManager or not ParallelLoot.db.profile.rollRanges then
        self:Initialize()
    end
    
    local db = ParallelLoot.db.global.rollRangeManager
    local profile = ParallelLoot.db.profile.rollRanges
    
    -- Only recycle if recycling is enabled (default to true if not set)
    local recyclingEnabled = profile.enableRangeRecycling
    if recyclingEnabled == nil then
        recyclingEnabled = true -- Default to enabled
        profile.enableRangeRecycling = true
    end
    
    if not recyclingEnabled then
        print("|cff888888RollRangeManager:|r Range recycling disabled, not freeing range " .. baseRange)
        return true
    end
    
    -- Check if range is already available
    for _, availableRange in ipairs(db.availableRanges) do
        if availableRange == baseRange then
            print("|cffff8800RollRangeManager Warning:|r Range " .. baseRange .. " already in available ranges")
            return true
        end
    end
    
    -- Add to available ranges for recycling
    table.insert(db.availableRanges, baseRange)
    
    -- Remove from used ranges
    for i, usedRange in ipairs(db.usedRanges) do
        if usedRange == baseRange then
            table.remove(db.usedRanges, i)
            break
        end
    end
    
    print("|cff888888RollRangeManager:|r Freed range " .. baseRange .. " for recycling")
    return true
end

-- Detect conflicts between roll ranges
function RollRangeManager:DetectRangeConflicts(rollRange)
    local conflicts = {}
    local db = ParallelLoot.db.global.rollRangeManager
    
    -- Check against all currently used ranges
    for _, usedBaseRange in ipairs(db.usedRanges) do
        if usedBaseRange ~= rollRange.baseRange then
            local usedRange = self:CreateRollRange(usedBaseRange)
            
            -- Check each category for overlaps
            for category, range in pairs(rollRange) do
                if category ~= "baseRange" and usedRange[category] then
                    local overlap = self:CheckRangeOverlap(range, usedRange[category])
                    if overlap then
                        table.insert(conflicts, {
                            conflictingBaseRange = usedBaseRange,
                            category = category,
                            currentRange = range,
                            conflictingRange = usedRange[category],
                            overlapStart = overlap.startPos,
                            overlapEnd = overlap.endPos
                        })
                    end
                end
            end
        end
    end
    
    return conflicts
end

-- Check if two ranges overlap
function RollRangeManager:CheckRangeOverlap(range1, range2)
    if not range1 or not range2 or not range1.min or not range1.max or not range2.min or not range2.max then
        return nil
    end
    
    -- Check for overlap
    local overlapStart = math.max(range1.min, range2.min)
    local overlapEnd = math.min(range1.max, range2.max)
    
    if overlapStart <= overlapEnd then
        return {
            startPos = overlapStart,
            endPos = overlapEnd
        }
    end
    
    return nil
end

-- Log range conflicts for debugging
function RollRangeManager:LogRangeConflicts(baseRange, conflicts)
    local db = ParallelLoot.db.global.rollRangeManager
    
    local conflictEntry = {
        baseRange = baseRange,
        timestamp = time(),
        conflicts = conflicts
    }
    
    table.insert(db.conflictLog, conflictEntry)
    
    -- Keep only recent conflicts (last 50)
    if #db.conflictLog > 50 then
        table.remove(db.conflictLog, 1)
    end
    
    -- Print detailed conflict information
    print("|cffff8800RollRangeManager Conflict:|r Base range " .. baseRange .. " has " .. #conflicts .. " conflicts:")
    for _, conflict in ipairs(conflicts) do
        print("  Category " .. conflict.category .. " overlaps with range " .. conflict.conflictingBaseRange .. 
              " (" .. conflict.overlapStart .. "-" .. conflict.overlapEnd .. ")")
    end
end

-- Cleanup old range history
function RollRangeManager:CleanupRangeHistory()
    local db = ParallelLoot.db.global.rollRangeManager
    local profile = ParallelLoot.db.profile.rollRanges
    
    -- Safety check for maxRangeHistory
    local maxHistory = profile.maxRangeHistory or 100
    
    if #db.rangeHistory > maxHistory then
        local excess = #db.rangeHistory - maxHistory
        for i = 1, excess do
            table.remove(db.rangeHistory, 1)
        end
        print("|cff888888RollRangeManager:|r Cleaned up " .. excess .. " old range history entries")
    end
end

-- Get statistics about range usage
function RollRangeManager:GetRangeStatistics()
    local db = ParallelLoot.db.global.rollRangeManager
    local profile = ParallelLoot.db.profile.rollRanges
    
    return {
        nextBaseRange = db.nextBaseRange,
        usedRangesCount = #db.usedRanges,
        availableRangesCount = #db.availableRanges,
        totalRangesAssigned = #db.rangeHistory,
        recyclingEnabled = profile.enableRangeRecycling,
        conflictsLogged = #db.conflictLog,
        rangeSize = profile.baseRange,
        categoryOffsets = profile.categoryOffsets
    }
end

-- Validate a roll against a specific range
function RollRangeManager:ValidateRoll(rollValue, category, rollRange)
    if not rollValue or type(rollValue) ~= "number" then
        return false, "Invalid roll value"
    end
    
    if not category or type(category) ~= "string" then
        return false, "Invalid category"
    end
    
    if not rollRange or not rollRange[category] then
        return false, "Invalid roll range or category not found"
    end
    
    local categoryRange = rollRange[category]
    if not categoryRange.min or not categoryRange.max then
        return false, "Invalid category range structure"
    end
    
    local valid = rollValue >= categoryRange.min and rollValue <= categoryRange.max
    
    if not valid then
        return false, "Roll " .. rollValue .. " outside valid range " .. categoryRange.min .. "-" .. categoryRange.max .. " for category " .. category
    end
    
    return true
end

-- Reset all range data (for testing or emergency cleanup)
function RollRangeManager:ResetAllRanges()
    local db = ParallelLoot.db.global.rollRangeManager
    
    db.nextBaseRange = 1
    db.usedRanges = {}
    db.availableRanges = {}
    db.rangeHistory = {}
    db.conflictLog = {}
    
    print("|cff00ff00RollRangeManager:|r All range data reset to defaults")
    return true
end

-- Get all currently used ranges (for debugging)
function RollRangeManager:GetUsedRanges()
    local db = ParallelLoot.db.global.rollRangeManager
    local usedRanges = {}
    
    for _, baseRange in ipairs(db.usedRanges) do
        table.insert(usedRanges, self:CreateRollRange(baseRange))
    end
    
    return usedRanges
end

-- Get all available ranges for recycling
function RollRangeManager:GetAvailableRanges()
    local db = ParallelLoot.db.global.rollRangeManager
    return db.availableRanges
end

-- Test function to validate range assignment algorithm
function RollRangeManager:TestRangeAssignment()
    print("|cff00ff00RollRangeManager Test:|r Testing range assignment algorithm...")
    
    -- Reset ranges for clean test
    self:ResetAllRanges()
    
    -- Test first range assignment
    local range1 = self:GetNextRollRange()
    if not range1 or range1.baseRange ~= 1 then
        print("|cffff0000FAIL:|r First range should start at 1, got " .. (range1 and range1.baseRange or "nil"))
        return false
    end
    
    if range1.bis.min ~= 1 or range1.bis.max ~= 100 then
        print("|cffff0000FAIL:|r First BIS range should be 1-100, got " .. range1.bis.min .. "-" .. range1.bis.max)
        return false
    end
    
    if range1.ms.min ~= 1 or range1.ms.max ~= 99 then
        print("|cffff0000FAIL:|r First MS range should be 1-99, got " .. range1.ms.min .. "-" .. range1.ms.max)
        return false
    end
    
    print("|cff00ff00PASS:|r First range assignment correct")
    
    -- Test second range assignment
    local range2 = self:GetNextRollRange()
    if not range2 or range2.baseRange ~= 101 then
        print("|cffff0000FAIL:|r Second range should start at 101, got " .. (range2 and range2.baseRange or "nil"))
        return false
    end
    
    if range2.bis.min ~= 101 or range2.bis.max ~= 200 then
        print("|cffff0000FAIL:|r Second BIS range should be 101-200, got " .. range2.bis.min .. "-" .. range2.bis.max)
        return false
    end
    
    print("|cff00ff00PASS:|r Second range assignment correct")
    
    -- Test range recycling
    self:FreeRollRange(range1.baseRange)
    local range3 = self:GetNextRollRange()
    
    if not range3 or range3.baseRange ~= 1 then
        print("|cffff0000FAIL:|r Recycled range should start at 1, got " .. (range3 and range3.baseRange or "nil"))
        return false
    end
    
    print("|cff00ff00PASS:|r Range recycling works correctly")
    
    -- Test conflict detection
    local conflicts = self:DetectRangeConflicts(range3)
    if #conflicts > 0 then
        print("|cffff8800WARNING:|r Conflicts detected during recycling test")
        for _, conflict in ipairs(conflicts) do
            print("  Conflict in category " .. conflict.category .. " with range " .. conflict.conflictingBaseRange)
        end
    else
        print("|cff00ff00PASS:|r No conflicts detected")
    end
    
    -- Test roll validation
    local validRoll = self:ValidateRoll(95, "bis", range3)
    if not validRoll then
        print("|cffff0000FAIL:|r Roll 95 should be valid for BIS category")
        return false
    end
    
    local invalidRoll = self:ValidateRoll(150, "bis", range3)
    if invalidRoll then
        print("|cffff0000FAIL:|r Roll 150 should not be valid for BIS category")
        return false
    end
    
    print("|cff00ff00PASS:|r Roll validation works correctly")
    
    -- Display statistics
    local stats = self:GetRangeStatistics()
    print("|cff888888Statistics:|r")
    print("  Next base range: " .. stats.nextBaseRange)
    print("  Used ranges: " .. stats.usedRangesCount)
    print("  Available ranges: " .. stats.availableRangesCount)
    print("  Total assigned: " .. stats.totalRangesAssigned)
    
    print("|cff00ff00RollRangeManager Test:|r All tests passed!")
    return true
end

-- Integration with LootSession for automatic range management
function RollRangeManager:IntegrateWithLootSession()
    local DataModels = ParallelLoot.DataModels
    if not DataModels or not DataModels.LootSession then
        print("|cffff0000RollRangeManager Error:|r DataModels.LootSession not found for integration")
        return false
    end
    
    -- Override the GetNextRollRange method in LootSession to use our manager
    local originalGetNextRollRange = DataModels.LootSession.GetNextRollRange
    
    function DataModels.LootSession:GetNextRollRange()
        return RollRangeManager:GetNextRollRange()
    end
    
    -- Override the AwardItem method to free ranges
    local originalAwardItem = DataModels.LootSession.AwardItem
    
    function DataModels.LootSession:AwardItem(itemId, awardedTo)
        -- Find the item to get its base range
        local item = nil
        for _, activeItem in ipairs(self.activeItems) do
            if activeItem.id == itemId then
                item = activeItem
                break
            end
        end
        
        -- Call original award method
        local success = originalAwardItem(self, itemId, awardedTo)
        
        -- Free the range if award was successful and item had a range
        if success and item and item.rollRange and item.rollRange.baseRange then
            RollRangeManager:FreeRollRange(item.rollRange.baseRange)
        end
        
        return success
    end
    
    print("|cff888888RollRangeManager:|r Integrated with LootSession successfully")
    return true
end

-- Export the manager
ParallelLoot.RollRangeManager = RollRangeManager

print("|cff888888ParallelLoot:|r RollRangeManager module loaded successfully")