-- ParallelLoot Roll Manager
-- Handles roll detection, validation, and range management

local RollManager = ParallelLoot.RollManager

-- Event frame for chat events
local rollEventFrame = CreateFrame("Frame")



-- Initialize the roll manager
function RollManager:Initialize()
    ParallelLoot:DebugPrint("RollManager: Initializing")
    
    -- Register chat events for roll detection
    rollEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    
    -- Set event handler
    rollEventFrame:SetScript("OnEvent", function(self, event, ...)
        RollManager:OnEvent(event, ...)
    end)
    

    
    ParallelLoot:DebugPrint("RollManager: Initialized")
end

-- Event handler for roll events
function RollManager:OnEvent(event, ...)
    if event == "CHAT_MSG_SYSTEM" then
        local message = ...
        self:OnChatMessage(message)
    end
end

-- Handle chat messages to detect rolls
function RollManager:OnChatMessage(message)
    if not message then
        return
    end
    
    -- Parse roll message
    -- Format: "PlayerName rolls 42 (1-100)"
    local playerName, rollValue, minRoll, maxRoll = self:ParseRollMessage(message)
    
    if playerName and rollValue then
        ParallelLoot:DebugPrint("RollManager: Detected roll -", playerName, "rolled", rollValue, "("..minRoll.."-"..maxRoll..")")
        self:ProcessRoll(playerName, rollValue, minRoll, maxRoll)
    end
end

-- Parse roll message from chat
function RollManager:ParseRollMessage(message)
    -- Pattern for roll messages: "PlayerName rolls 42 (1-100)"
    local playerName, rollValue, minRoll, maxRoll = string.match(message, "(.+) rolls (%d+) %((%d+)%-(%d+)%)")
    
    if playerName and rollValue and minRoll and maxRoll then
        return playerName, tonumber(rollValue), tonumber(minRoll), tonumber(maxRoll)
    end
    
    return nil, nil, nil, nil
end

-- Process a detected roll
function RollManager:ProcessRoll(playerName, rollValue, minRoll, maxRoll)
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:DebugPrint("RollManager: No active session, ignoring roll")
        return
    end
    
    -- Find which item this roll is for based on range
    local targetItem, category = self:FindItemByRollRange(rollValue, minRoll, maxRoll)
    
    if not targetItem then
        ParallelLoot:DebugPrint("RollManager: Roll does not match any active item ranges")
        return
    end
    
    -- Validate the roll
    local isValid, reason = self:ValidateRoll(targetItem, playerName, rollValue, minRoll, maxRoll, category)
    
    if not isValid then
        ParallelLoot:DebugPrint("RollManager: Invalid roll -", reason)
        return
    end
    
    -- Add roll to item
    self:AddRollToItem(targetItem, playerName, rollValue, category)
    
    ParallelLoot:Print(playerName, "rolled", rollValue, "for", targetItem.itemLink, "("..category..")")
end

-- Find item by roll range
function RollManager:FindItemByRollRange(rollValue, minRoll, maxRoll)
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return nil, nil
    end
    
    -- Check all active items
    for _, item in ipairs(session.activeItems) do
        if item.rollRange then
            -- Check only the category fields (not 'base')
            local categories = {"bis", "ms", "os", "coz"}
            for _, category in ipairs(categories) do
                local range = item.rollRange[category]
                if range and range.min and range.max then
                    if minRoll == range.min and maxRoll == range.max then
                        -- Verify roll value is within range
                        if rollValue >= range.min and rollValue <= range.max then
                            return item, category
                        end
                    end
                end
            end
        end
    end
    
    return nil, nil
end

-- Validate a roll
function RollManager:ValidateRoll(item, playerName, rollValue, minRoll, maxRoll, category)
    ParallelLoot:DebugPrint("RollManager: Validating roll for", playerName, "value:", rollValue, "range:", minRoll, "-", maxRoll, "category:", category)
    
    -- Check if player already rolled for this item
    if self:HasPlayerRolled(item, playerName) then
        ParallelLoot:Print(playerName .. " has already rolled on this item")
        return false, "Player has already rolled for this item"
    end
    
    -- Check if roll value is within the specified range
    local range = item.rollRange[category]
    if not range then
        ParallelLoot:DebugPrint("RollManager: Invalid category", category)
        return false, "Invalid category"
    end
    
    ParallelLoot:DebugPrint("RollManager: Item range for", category, "is", range.min, "-", range.max)
    
    if rollValue < range.min or rollValue > range.max then
        ParallelLoot:DebugPrint("RollManager: Roll value", rollValue, "outside range", range.min, "-", range.max)
        return false, "Roll value outside of valid range"
    end
    
    if minRoll ~= range.min or maxRoll ~= range.max then
        ParallelLoot:DebugPrint("RollManager: Roll range mismatch. Expected", range.min, "-", range.max, "got", minRoll, "-", maxRoll)
        return false, "Roll range does not match item range"
    end
    
    ParallelLoot:DebugPrint("RollManager: Roll validation passed")
    return true
end

-- Check if player has already rolled for an item
function RollManager:HasPlayerRolled(item, playerName)
    if not item.rolls then
        return false
    end
    
    for _, roll in ipairs(item.rolls) do
        if roll.playerName == playerName then
            return true
        end
    end
    
    return false
end

-- Add roll to item
function RollManager:AddRollToItem(item, playerName, rollValue, category)
    -- Create roll object
    local roll = {
        playerName = playerName,
        category = category,
        rollValue = rollValue,
        timestamp = time()
    }
    
    -- Add to item's rolls
    if not item.rolls then
        item.rolls = {}
    end
    
    table.insert(item.rolls, roll)
    
    -- Save session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        ParallelLoot.DataManager:SaveCurrentSession(session)
    end
    
    -- Notify UI with animation
    if ParallelLoot.UIManager.OnRollAdded then
        ParallelLoot.UIManager:OnRollAdded(item, roll)
    end
    
    -- Broadcast to raid
    if ParallelLoot.CommManager.BroadcastRoll then
        ParallelLoot.CommManager:BroadcastRoll(item.id, roll)
    end
    
    ParallelLoot:DebugPrint("RollManager: Roll added -", playerName, rollValue, "for", category)
end





-- Get rolls for an item by category
function RollManager:GetRollsByCategory(item)
    if not item or not item.rolls then
        return { bis = {}, ms = {}, os = {}, coz = {} }
    end
    
    local categorized = {
        bis = {},
        ms = {},
        os = {},
        coz = {}
    }
    
    for _, roll in ipairs(item.rolls) do
        local category = roll.category
        if categorized[category] then
            table.insert(categorized[category], roll)
        end
    end
    
    -- Sort each category by roll value (highest first)
    for category, rolls in pairs(categorized) do
        table.sort(rolls, function(a, b)
            return a.rollValue > b.rollValue
        end)
    end
    
    return categorized
end

-- Get highest roll for an item
function RollManager:GetHighestRoll(item)
    if not item or not item.rolls or #item.rolls == 0 then
        return nil
    end
    
    local highest = nil
    
    for _, roll in ipairs(item.rolls) do
        if not highest or roll.rollValue > highest.rollValue then
            highest = roll
        end
    end
    
    return highest
end

-- Get category priority order
function RollManager:GetCategoryPriority()
    return { "bis", "ms", "os", "coz" }
end

-- Get winner for an item (highest roll in highest priority category)
function RollManager:GetItemWinner(item)
    local categorized = self:GetRollsByCategory(item)
    local priorities = self:GetCategoryPriority()
    
    -- Check each category in priority order
    for _, category in ipairs(priorities) do
        local rolls = categorized[category]
        if rolls and #rolls > 0 then
            -- Return highest roll in this category
            return rolls[1]
        end
    end
    
    return nil
end
