-- ParallelLoot Data Manager
-- Handles data persistence using SavedVariables and data models

local DataManager = ParallelLoot.DataManager

-- ============================================================================
-- DATA MODELS
-- ============================================================================

-- LootSession data structure
DataManager.LootSession = {}
function DataManager.LootSession:New(masterId)
    local session = {
        id = self:GenerateId(),
        masterId = masterId or UnitName("player"),
        startTime = time(),
        activeItems = {},
        awardedItems = {},
        rollRanges = {
            available = {},
            nextBase = 1
        },
        categories = {
            bis = "BIS",
            ms = "MS",
            os = "OS",
            coz = "COZ"
        }
    }
    return session
end

function DataManager.LootSession:GenerateId()
    return string.format("%s-%d", UnitName("player"), time())
end

function DataManager.LootSession:Validate(session)
    if type(session) ~= "table" then
        return false, "Session must be a table"
    end
    
    if not session.id or type(session.id) ~= "string" then
        return false, "Session must have a valid id"
    end
    
    if not session.masterId or type(session.masterId) ~= "string" then
        return false, "Session must have a valid masterId"
    end
    
    if not session.startTime or type(session.startTime) ~= "number" then
        return false, "Session must have a valid startTime"
    end
    
    if not session.activeItems or type(session.activeItems) ~= "table" then
        return false, "Session must have activeItems table"
    end
    
    if not session.awardedItems or type(session.awardedItems) ~= "table" then
        return false, "Session must have awardedItems table"
    end
    
    if not session.rollRanges or type(session.rollRanges) ~= "table" then
        return false, "Session must have rollRanges table"
    end
    
    if not session.categories or type(session.categories) ~= "table" then
        return false, "Session must have categories table"
    end
    
    return true
end

-- LootItem data structure
DataManager.LootItem = {}
function DataManager.LootItem:New(itemLink, itemId, rollRange)
    local item = {
        id = self:GenerateId(itemId),
        itemLink = itemLink,
        itemId = itemId,
        rollRange = rollRange or {},
        rolls = {},
        dropTime = time(),
        expiryTime = time() + 7200, -- 2 hours default
        awardedTo = nil,
        awardTime = nil
    }
    return item
end

function DataManager.LootItem:GenerateId(itemId)
    return string.format("%d-%d", itemId, time())
end

function DataManager.LootItem:Validate(item)
    if type(item) ~= "table" then
        return false, "Item must be a table"
    end
    
    if not item.id or type(item.id) ~= "string" then
        return false, "Item must have a valid id"
    end
    
    if not item.itemLink or type(item.itemLink) ~= "string" then
        return false, "Item must have a valid itemLink"
    end
    
    if not item.itemId or type(item.itemId) ~= "number" then
        return false, "Item must have a valid itemId"
    end
    
    if not item.rollRange or type(item.rollRange) ~= "table" then
        return false, "Item must have rollRange table"
    end
    
    if not item.rolls or type(item.rolls) ~= "table" then
        return false, "Item must have rolls table"
    end
    
    if not item.dropTime or type(item.dropTime) ~= "number" then
        return false, "Item must have a valid dropTime"
    end
    
    if not item.expiryTime or type(item.expiryTime) ~= "number" then
        return false, "Item must have a valid expiryTime"
    end
    
    return true
end

function DataManager.LootItem:IsExpired(item)
    return time() >= item.expiryTime
end

function DataManager.LootItem:IsAwarded(item)
    return item.awardedTo ~= nil
end

function DataManager.LootItem:GetTimeRemaining(item)
    local remaining = item.expiryTime - time()
    return math.max(0, remaining)
end

-- PlayerRoll data structure
DataManager.PlayerRoll = {}
function DataManager.PlayerRoll:New(playerName, category, rollValue)
    local roll = {
        playerName = playerName,
        category = category,
        rollValue = rollValue,
        timestamp = time()
    }
    return roll
end

function DataManager.PlayerRoll:Validate(roll)
    if type(roll) ~= "table" then
        return false, "Roll must be a table"
    end
    
    if not roll.playerName or type(roll.playerName) ~= "string" then
        return false, "Roll must have a valid playerName"
    end
    
    if not roll.category or type(roll.category) ~= "string" then
        return false, "Roll must have a valid category"
    end
    
    local validCategories = {bis = true, ms = true, os = true, coz = true}
    if not validCategories[roll.category] then
        return false, "Roll category must be one of: bis, ms, os, coz"
    end
    
    if not roll.rollValue or type(roll.rollValue) ~= "number" then
        return false, "Roll must have a valid rollValue"
    end
    
    if roll.rollValue < 1 or roll.rollValue > 1000 then
        return false, "Roll value must be between 1 and 1000"
    end
    
    if not roll.timestamp or type(roll.timestamp) ~= "number" then
        return false, "Roll must have a valid timestamp"
    end
    
    return true
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Find item by ID in a list
function DataManager:FindItemById(items, itemId)
    for i, item in ipairs(items) do
        if item.id == itemId then
            return item, i
        end
    end
    return nil, nil
end

-- Find roll by player name in an item's rolls
function DataManager:FindRollByPlayer(item, playerName)
    for i, roll in ipairs(item.rolls) do
        if roll.playerName == playerName then
            return roll, i
        end
    end
    return nil, nil
end

-- Get rolls by category for an item
function DataManager:GetRollsByCategory(item, category)
    local categoryRolls = {}
    for _, roll in ipairs(item.rolls) do
        if roll.category == category then
            table.insert(categoryRolls, roll)
        end
    end
    
    -- Sort by roll value descending
    table.sort(categoryRolls, function(a, b)
        return a.rollValue > b.rollValue
    end)
    
    return categoryRolls
end

-- Get all rolls organized by category
function DataManager:GetRollsOrganized(item)
    return {
        bis = self:GetRollsByCategory(item, "bis"),
        ms = self:GetRollsByCategory(item, "ms"),
        os = self:GetRollsByCategory(item, "os"),
        coz = self:GetRollsByCategory(item, "coz")
    }
end

-- Add roll to item
function DataManager:AddRollToItem(item, roll)
    -- Validate roll
    local valid, error = self.PlayerRoll:Validate(roll)
    if not valid then
        return false, error
    end
    
    -- Check for duplicate roll from same player
    local existingRoll = self:FindRollByPlayer(item, roll.playerName)
    if existingRoll then
        return false, "Player has already rolled on this item"
    end
    
    -- Add roll
    table.insert(item.rolls, roll)
    return true
end

-- Remove roll from item
function DataManager:RemoveRollFromItem(item, playerName)
    local roll, index = self:FindRollByPlayer(item, playerName)
    if roll then
        table.remove(item.rolls, index)
        return true
    end
    return false
end

-- Get highest roll for each category
function DataManager:GetHighestRolls(item)
    local highest = {}
    local organized = self:GetRollsOrganized(item)
    
    for category, rolls in pairs(organized) do
        if #rolls > 0 then
            highest[category] = rolls[1] -- First is highest due to sorting
        end
    end
    
    return highest
end

-- Count total rolls for an item
function DataManager:CountRolls(item)
    return #item.rolls
end

-- Count rolls by category
function DataManager:CountRollsByCategory(item)
    local counts = {
        bis = 0,
        ms = 0,
        os = 0,
        coz = 0
    }
    
    for _, roll in ipairs(item.rolls) do
        counts[roll.category] = counts[roll.category] + 1
    end
    
    return counts
end

-- ============================================================================
-- ROLL RANGE MANAGEMENT
-- ============================================================================

-- Assign roll range for a new item
function DataManager:AssignRollRange(session)
    local baseRange
    
    -- Check if there are available recycled ranges
    if #session.rollRanges.available > 0 then
        -- Use the lowest available recycled range
        table.sort(session.rollRanges.available)
        baseRange = table.remove(session.rollRanges.available, 1)
        ParallelLoot:DebugPrint("DataManager: Reusing recycled range base:", baseRange)
    else
        -- Use next sequential range
        baseRange = session.rollRanges.nextBase
        session.rollRanges.nextBase = session.rollRanges.nextBase + 100
        ParallelLoot:DebugPrint("DataManager: Assigning new range base:", baseRange)
    end
    
    -- Create roll ranges for all categories
    -- BIS: base to base+99
    -- MS: base to base+98
    -- OS: base to base+97
    -- COZ: base to base+96
    local rollRange = {
        base = baseRange,
        bis = {min = baseRange, max = baseRange + 99},
        ms = {min = baseRange, max = baseRange + 98},
        os = {min = baseRange, max = baseRange + 97},
        coz = {min = baseRange, max = baseRange + 96}
    }
    
    return rollRange
end

-- Recycle roll range when item is awarded
function DataManager:RecycleRollRange(session, rollRange)
    if not rollRange or not rollRange.base then
        return false
    end
    
    -- Add base range back to available pool
    table.insert(session.rollRanges.available, rollRange.base)
    ParallelLoot:DebugPrint("DataManager: Recycled range base:", rollRange.base)
    
    return true
end

-- Check if a roll value is within the assigned range for a category
function DataManager:ValidateRollInRange(rollValue, rollRange, category)
    if not rollRange or not rollRange[category] then
        return false, "Invalid roll range or category"
    end
    
    local range = rollRange[category]
    if rollValue < range.min or rollValue > range.max then
        return false, string.format(
            "Roll value %d is outside the valid range for %s (%d-%d)",
            rollValue, category, range.min, range.max
        )
    end
    
    return true
end

-- Detect if there are any range conflicts in the session
function DataManager:DetectRangeConflicts(session)
    local conflicts = {}
    local usedRanges = {}
    
    -- Check active items
    for _, item in ipairs(session.activeItems) do
        if item.rollRange and item.rollRange.base then
            local base = item.rollRange.base
            if usedRanges[base] then
                table.insert(conflicts, {
                    type = "duplicate_base",
                    base = base,
                    items = {usedRanges[base], item.id}
                })
            else
                usedRanges[base] = item.id
            end
        end
    end
    
    return conflicts
end

-- Get all active roll ranges in the session
function DataManager:GetActiveRanges(session)
    local ranges = {}
    
    for _, item in ipairs(session.activeItems) do
        if item.rollRange then
            table.insert(ranges, {
                itemId = item.id,
                itemLink = item.itemLink,
                rollRange = item.rollRange
            })
        end
    end
    
    return ranges
end

-- Get formatted range string for display
function DataManager:FormatRollRange(rollRange, category)
    if not rollRange or not rollRange[category] then
        return "N/A"
    end
    
    local range = rollRange[category]
    return string.format("%d-%d", range.min, range.max)
end

-- Get all formatted ranges for an item
function DataManager:FormatAllRanges(rollRange)
    return {
        bis = self:FormatRollRange(rollRange, "bis"),
        ms = self:FormatRollRange(rollRange, "ms"),
        os = self:FormatRollRange(rollRange, "os"),
        coz = self:FormatRollRange(rollRange, "coz")
    }
end

-- Check if a roll range overlaps with any active ranges
function DataManager:CheckRangeOverlap(session, newRange)
    for _, item in ipairs(session.activeItems) do
        if item.rollRange and item.rollRange.base == newRange.base then
            return true, item.id
        end
    end
    return false
end

-- Get next available range base (for preview/display)
function DataManager:GetNextRangeBase(session)
    if #session.rollRanges.available > 0 then
        local sorted = {}
        for _, base in ipairs(session.rollRanges.available) do
            table.insert(sorted, base)
        end
        table.sort(sorted)
        return sorted[1], true -- true indicates recycled
    else
        return session.rollRanges.nextBase, false -- false indicates new
    end
end

-- Reset roll ranges (for testing or session reset)
function DataManager:ResetRollRanges(session)
    session.rollRanges = {
        available = {},
        nextBase = 1
    }
    ParallelLoot:DebugPrint("DataManager: Roll ranges reset")
end

-- ============================================================================
-- SESSION PERSISTENCE
-- ============================================================================

-- Save current session to SavedVariables
function DataManager:SaveSession(session)
    if not session then
        ParallelLoot:DebugPrint("DataManager: No session to save")
        return false
    end
    
    -- Validate session before saving
    local valid, error = self.LootSession:Validate(session)
    if not valid then
        ParallelLoot:DebugPrint("DataManager: Cannot save invalid session:", error)
        return false, error
    end
    
    -- Save to database
    ParallelLootDB.sessions.current = session
    ParallelLoot:DebugPrint("DataManager: Session saved successfully")
    
    return true
end

-- Load current session from SavedVariables
function DataManager:LoadSession()
    if not ParallelLootDB or not ParallelLootDB.sessions then
        ParallelLoot:DebugPrint("DataManager: No database found")
        return nil
    end
    
    local session = ParallelLootDB.sessions.current
    
    if not session then
        ParallelLoot:DebugPrint("DataManager: No current session found")
        return nil
    end
    
    -- Validate loaded session
    local valid, error = self:ValidateSessionState(session)
    if not valid then
        ParallelLoot:DebugPrint("DataManager: Loaded session is invalid:", error)
        -- Attempt recovery
        local recovered = self:RecoverSession(session)
        if recovered then
            ParallelLoot:Print("Session recovered from corrupted state")
            return recovered
        else
            ParallelLoot:Print("Warning: Could not recover session, starting fresh")
            return nil
        end
    end
    
    ParallelLoot:DebugPrint("DataManager: Session loaded successfully")
    return session
end

-- Validate session state (more comprehensive than basic validation)
function DataManager:ValidateSessionState(session)
    -- Basic structure validation
    local valid, error = self.LootSession:Validate(session)
    if not valid then
        return false, error
    end
    
    -- Validate all active items
    for i, item in ipairs(session.activeItems) do
        local itemValid, itemError = self.LootItem:Validate(item)
        if not itemValid then
            return false, string.format("Active item %d invalid: %s", i, itemError)
        end
        
        -- Validate all rolls in the item
        for j, roll in ipairs(item.rolls) do
            local rollValid, rollError = self.PlayerRoll:Validate(roll)
            if not rollValid then
                return false, string.format("Roll %d in item %d invalid: %s", j, i, rollError)
            end
        end
    end
    
    -- Validate all awarded items
    for i, item in ipairs(session.awardedItems) do
        local itemValid, itemError = self.LootItem:Validate(item)
        if not itemValid then
            return false, string.format("Awarded item %d invalid: %s", i, itemError)
        end
    end
    
    -- Check for range conflicts
    local conflicts = self:DetectRangeConflicts(session)
    if #conflicts > 0 then
        return false, string.format("Found %d range conflicts", #conflicts)
    end
    
    return true
end

-- Attempt to recover a corrupted session
function DataManager:RecoverSession(session)
    ParallelLoot:DebugPrint("DataManager: Attempting session recovery")
    
    -- Create a new valid session structure
    local recovered = self.LootSession:New(session.masterId or UnitName("player"))
    
    -- Try to preserve session ID and start time
    if session.id and type(session.id) == "string" then
        recovered.id = session.id
    end
    if session.startTime and type(session.startTime) == "number" then
        recovered.startTime = session.startTime
    end
    
    -- Try to recover categories
    if session.categories and type(session.categories) == "table" then
        recovered.categories = session.categories
    end
    
    -- Try to recover active items
    if session.activeItems and type(session.activeItems) == "table" then
        for _, item in ipairs(session.activeItems) do
            local itemValid, _ = self.LootItem:Validate(item)
            if itemValid then
                -- Validate rolls
                local validRolls = {}
                if item.rolls and type(item.rolls) == "table" then
                    for _, roll in ipairs(item.rolls) do
                        local rollValid, _ = self.PlayerRoll:Validate(roll)
                        if rollValid then
                            table.insert(validRolls, roll)
                        end
                    end
                end
                item.rolls = validRolls
                table.insert(recovered.activeItems, item)
            end
        end
    end
    
    -- Try to recover awarded items
    if session.awardedItems and type(session.awardedItems) == "table" then
        for _, item in ipairs(session.awardedItems) do
            local itemValid, _ = self.LootItem:Validate(item)
            if itemValid then
                table.insert(recovered.awardedItems, item)
            end
        end
    end
    
    -- Try to recover roll ranges
    if session.rollRanges and type(session.rollRanges) == "table" then
        if session.rollRanges.available and type(session.rollRanges.available) == "table" then
            recovered.rollRanges.available = session.rollRanges.available
        end
        if session.rollRanges.nextBase and type(session.rollRanges.nextBase) == "number" then
            recovered.rollRanges.nextBase = session.rollRanges.nextBase
        end
    end
    
    -- Validate recovered session
    local valid, _ = self:ValidateSessionState(recovered)
    if valid then
        ParallelLoot:DebugPrint("DataManager: Session recovery successful")
        return recovered
    else
        ParallelLoot:DebugPrint("DataManager: Session recovery failed")
        return nil
    end
end

-- Archive current session to history
function DataManager:ArchiveSession(session)
    if not session then
        return false
    end
    
    -- Add end time
    session.endTime = time()
    
    -- Move to history
    if not ParallelLootDB.sessions.history then
        ParallelLootDB.sessions.history = {}
    end
    
    table.insert(ParallelLootDB.sessions.history, 1, session)
    
    -- Keep only last 10 sessions
    while #ParallelLootDB.sessions.history > 10 do
        table.remove(ParallelLootDB.sessions.history)
    end
    
    ParallelLoot:DebugPrint("DataManager: Session archived to history")
    return true
end

-- Create a new session
function DataManager:CreateNewSession(masterId)
    local session = self.LootSession:New(masterId)
    self:SaveSession(session)
    ParallelLoot:DebugPrint("DataManager: New session created:", session.id)
    return session
end

-- End current session
function DataManager:EndSession()
    local session = self:LoadSession()
    if session then
        self:ArchiveSession(session)
        self:ClearCurrentSession()
        ParallelLoot:Print("Session ended and archived")
        return true
    end
    return false
end

-- Get session statistics
function DataManager:GetSessionStats(session)
    if not session then
        return nil
    end
    
    local stats = {
        duration = time() - session.startTime,
        activeItemCount = #session.activeItems,
        awardedItemCount = #session.awardedItems,
        totalRolls = 0,
        uniquePlayers = {}
    }
    
    -- Count rolls and unique players
    for _, item in ipairs(session.activeItems) do
        stats.totalRolls = stats.totalRolls + #item.rolls
        for _, roll in ipairs(item.rolls) do
            stats.uniquePlayers[roll.playerName] = true
        end
    end
    
    for _, item in ipairs(session.awardedItems) do
        for _, roll in ipairs(item.rolls) do
            stats.uniquePlayers[roll.playerName] = true
        end
    end
    
    -- Convert unique players to count
    local playerCount = 0
    for _ in pairs(stats.uniquePlayers) do
        playerCount = playerCount + 1
    end
    stats.uniquePlayerCount = playerCount
    stats.uniquePlayers = nil -- Remove the table, just keep count
    
    return stats
end

-- Clean up expired items from session
function DataManager:CleanupExpiredItems(session)
    if not session then
        return 0
    end
    
    local removed = 0
    local i = 1
    
    while i <= #session.activeItems do
        local item = session.activeItems[i]
        if self.LootItem:IsExpired(item) and not self.LootItem:IsAwarded(item) then
            -- Recycle the roll range
            self:RecycleRollRange(session, item.rollRange)
            -- Remove the item
            table.remove(session.activeItems, i)
            removed = removed + 1
            ParallelLoot:DebugPrint("DataManager: Removed expired item:", item.itemLink)
        else
            i = i + 1
        end
    end
    
    if removed > 0 then
        self:SaveSession(session)
        ParallelLoot:DebugPrint("DataManager: Cleaned up", removed, "expired items")
    end
    
    return removed
end

-- Default database structure
local defaultDB = {
    version = "1.0.0",
    settings = {
        categories = {
            bis = "BIS",
            ms = "MS",
            os = "OS",
            coz = "COZ"
        },
        categoryOffsets = {
            bis = 0,
            ms = 1,
            os = 2,
            coz = 3
        },
        autoStart = false,
        soundEnabled = true,
        showHoursInTimer = true,
        showQualityColors = true,
        showClassColors = true,
        timerWarnings = {300, 60}
    },
    sessions = {
        current = nil,
        history = {}
    }
}

-- Initialize data manager
function DataManager:Initialize()
    ParallelLoot:DebugPrint("DataManager: Initializing")
    
    -- Initialize SavedVariables if it doesn't exist
    if not ParallelLootDB then
        ParallelLoot:DebugPrint("DataManager: Creating new database")
        ParallelLootDB = self:CopyTable(defaultDB)
    else
        ParallelLoot:DebugPrint("DataManager: Loading existing database")
        -- Validate and migrate if needed
        self:ValidateDatabase()
    end
    
    ParallelLoot:DebugPrint("DataManager: Initialized successfully")
end

-- Deep copy table
function DataManager:CopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    
    local copy = {}
    for key, value in pairs(src) do
        copy[key] = self:CopyTable(value)
    end
    
    return copy
end

-- Validate database structure
function DataManager:ValidateDatabase()
    -- Check version and migrate if needed
    if not ParallelLootDB.version or ParallelLootDB.version ~= ParallelLoot.VERSION then
        ParallelLoot:DebugPrint("DataManager: Database version mismatch, migrating")
        self:MigrateDatabase()
    end
    
    -- Ensure all required fields exist
    if not ParallelLootDB.settings then
        ParallelLootDB.settings = self:CopyTable(defaultDB.settings)
    end
    
    if not ParallelLootDB.sessions then
        ParallelLootDB.sessions = self:CopyTable(defaultDB.sessions)
    end
    
    -- Validate settings structure
    if not ParallelLootDB.settings.categories then
        ParallelLootDB.settings.categories = self:CopyTable(defaultDB.settings.categories)
    end
    
    if not ParallelLootDB.settings.timerWarnings then
        ParallelLootDB.settings.timerWarnings = self:CopyTable(defaultDB.settings.timerWarnings)
    end
end

-- Migrate database to current version
function DataManager:MigrateDatabase()
    local oldVersion = ParallelLootDB.version or "0.0.0"
    ParallelLoot:Print("Migrating database from version", oldVersion, "to", ParallelLoot.VERSION)
    
    -- Future migration logic goes here
    -- For now, just update version
    ParallelLootDB.version = ParallelLoot.VERSION
end

-- Save data (called on logout)
function DataManager:SaveData()
    ParallelLoot:DebugPrint("DataManager: Saving data")
    -- Data is automatically saved by WoW's SavedVariables system
    -- This function is here for any pre-save processing if needed
end

-- Get setting value
function DataManager:GetSetting(key)
    if not ParallelLootDB or not ParallelLootDB.settings then
        return nil
    end
    return ParallelLootDB.settings[key]
end

-- Set setting value
function DataManager:SetSetting(key, value)
    if not ParallelLootDB or not ParallelLootDB.settings then
        return false
    end
    ParallelLootDB.settings[key] = value
    return true
end

-- Get current session
function DataManager:GetCurrentSession()
    if not ParallelLootDB or not ParallelLootDB.sessions then
        return nil
    end
    return ParallelLootDB.sessions.current
end

-- Set current session
function DataManager:SetCurrentSession(session)
    if not ParallelLootDB or not ParallelLootDB.sessions then
        return false
    end
    ParallelLootDB.sessions.current = session
    return true
end

-- Save current session (alias for SaveSession with current session)
function DataManager:SaveCurrentSession(session)
    return self:SaveSession(session)
end

-- Clear current session
function DataManager:ClearCurrentSession()
    if not ParallelLootDB or not ParallelLootDB.sessions then
        return false
    end
    
    -- Move to history if it exists
    if ParallelLootDB.sessions.current then
        table.insert(ParallelLootDB.sessions.history, 1, ParallelLootDB.sessions.current)
        
        -- Keep only last 10 sessions in history
        while #ParallelLootDB.sessions.history > 10 do
            table.remove(ParallelLootDB.sessions.history)
        end
    end
    
    ParallelLootDB.sessions.current = nil
    return true
end

-- Get session history
function DataManager:GetSessionHistory()
    if not ParallelLootDB or not ParallelLootDB.sessions then
        return {}
    end
    return ParallelLootDB.sessions.history or {}
end

-- Reset database to defaults
function DataManager:ResetDatabase()
    ParallelLoot:Print("Resetting database to defaults")
    ParallelLootDB = self:CopyTable(defaultDB)
    self:Initialize()
end
