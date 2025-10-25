-- ParallelLoot Integration Layer
-- Wires together all components and ensures proper communication

local Integration = {}
ParallelLoot.Integration = Integration

-- ============================================================================
-- COMPONENT WIRING
-- ============================================================================

-- Wire LootManager to other components
function Integration:WireLootManager()
    local LootManager = ParallelLoot.LootManager
    
    -- Override OnItemAdded to notify all components
    local originalOnItemAdded = LootManager.OnItemAdded
    LootManager.OnItemAdded = function(self, lootItem)
        -- Call original
        if originalOnItemAdded then
            originalOnItemAdded(self, lootItem)
        end
        
        -- Notify UI
        if ParallelLoot.UIManager.OnItemAdded then
            ParallelLoot.UIManager:OnItemAdded(lootItem)
        end
        
        -- Notify TimerManager
        if ParallelLoot.TimerManager.StartTimer then
            ParallelLoot.TimerManager:StartTimer(lootItem)
        end
        
        -- Broadcast to raid (if loot master)
        if ParallelLoot.LootMasterManager:IsPlayerLootMaster() then
            if ParallelLoot.CommManager.BroadcastItemAdded then
                ParallelLoot.CommManager:BroadcastItemAdded(lootItem)
            end
        end
    end
    
    ParallelLoot:DebugPrint("Integration: LootManager wired")
end

-- Wire RollManager to other components
function Integration:WireRollManager()
    local RollManager = ParallelLoot.RollManager
    
    -- Ensure roll processing notifies UI
    local originalAddRollToItem = RollManager.AddRollToItem
    RollManager.AddRollToItem = function(self, item, playerName, rollValue, category)
        -- Call original
        originalAddRollToItem(self, item, playerName, rollValue, category)
        
        -- Notify UI to update roll display
        if ParallelLoot.UIManager.OnRollAdded then
            local roll = {
                playerName = playerName,
                category = category,
                rollValue = rollValue,
                timestamp = time()
            }
            ParallelLoot.UIManager:OnRollAdded(item, roll)
        end
    end
    
    ParallelLoot:DebugPrint("Integration: RollManager wired")
end

-- Wire UIManager to other components
function Integration:WireUIManager()
    local UIManager = ParallelLoot.UIManager
    
    -- Implement OnItemAdded callback
    if not UIManager.OnItemAdded then
        UIManager.OnItemAdded = function(self, lootItem)
            ParallelLoot:DebugPrint("UIManager: Item added, refreshing UI")
            self:Refresh()
        end
    end
    
    -- Implement OnRollAdded callback
    if not UIManager.OnRollAdded then
        UIManager.OnRollAdded = function(self, item, roll)
            ParallelLoot:DebugPrint("UIManager: Roll added for", item.itemName, "by", roll.playerName)
            self:Refresh()
        end
    end
    
    -- Implement OnItemAwarded callback
    if not UIManager.OnItemAwarded then
        UIManager.OnItemAwarded = function(self, item, playerName)
            ParallelLoot:DebugPrint("UIManager: Item awarded to", playerName)
            self:Refresh()
        end
    end
    
    -- Implement OnItemRevoked callback
    if not UIManager.OnItemRevoked then
        UIManager.OnItemRevoked = function(self, item)
            ParallelLoot:DebugPrint("UIManager: Item award revoked")
            self:Refresh()
        end
    end
    
    -- Implement OnSessionStart callback
    if not UIManager.OnSessionStart then
        UIManager.OnSessionStart = function(self, session)
            ParallelLoot:DebugPrint("UIManager: Session started")
            self:Refresh()
        end
    end
    
    -- Implement OnSessionEnd callback
    if not UIManager.OnSessionEnd then
        UIManager.OnSessionEnd = function(self)
            ParallelLoot:DebugPrint("UIManager: Session ended")
            self:Refresh()
        end
    end
    
    -- Implement OnSessionSync callback
    if not UIManager.OnSessionSync then
        UIManager.OnSessionSync = function(self, session)
            ParallelLoot:DebugPrint("UIManager: Session synced")
            self:Refresh()
        end
    end
    
    ParallelLoot:DebugPrint("Integration: UIManager wired")
end

-- Wire TimerManager to other components
function Integration:WireTimerManager()
    local TimerManager = ParallelLoot.TimerManager
    
    -- Ensure timer expiration notifies all components
    local originalOnItemExpired = TimerManager.OnItemExpired
    TimerManager.OnItemExpired = function(self, item)
        -- Call original
        if originalOnItemExpired then
            originalOnItemExpired(self, item)
        end
        
        -- Notify UI
        if ParallelLoot.UIManager.OnItemExpired then
            ParallelLoot.UIManager:OnItemExpired(item)
        end
        
        -- Clean up expired items from session
        local session = ParallelLoot.DataManager:GetCurrentSession()
        if session then
            ParallelLoot.DataManager:CleanupExpiredItems(session)
        end
    end
    
    ParallelLoot:DebugPrint("Integration: TimerManager wired")
end

-- Wire CommManager to other components
function Integration:WireCommManager()
    -- CommManager is already well-integrated through its message handlers
    -- Just ensure it's initialized
    ParallelLoot:DebugPrint("Integration: CommManager wired")
end

-- ============================================================================
-- SESSION MANAGEMENT INTEGRATION
-- ============================================================================

-- Start a new loot session
function Integration:StartSession()
    -- Validate permission
    if not ParallelLoot.LootMasterManager:ValidateLootMasterPermission("start a session") then
        return false
    end
    
    -- Check if session already exists
    local existingSession = ParallelLoot.DataManager:GetCurrentSession()
    if existingSession then
        ParallelLoot:Print("A session is already active. End it first before starting a new one.")
        return false
    end
    
    -- Create new session
    local session = ParallelLoot.DataManager:CreateNewSession(UnitName("player"))
    
    -- Broadcast session start
    if ParallelLoot.CommManager.BroadcastSessionStart then
        ParallelLoot.CommManager:BroadcastSessionStart(session)
    end
    
    -- Notify UI
    if ParallelLoot.UIManager.OnSessionStart then
        ParallelLoot.UIManager:OnSessionStart(session)
    end
    
    ParallelLoot:Print("Loot session started")
    return true
end

-- End the current loot session
function Integration:EndSession()
    -- Validate permission
    if not ParallelLoot.LootMasterManager:ValidateLootMasterPermission("end the session") then
        return false
    end
    
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:Print("No active session to end")
        return false
    end
    
    -- Broadcast session end
    if ParallelLoot.CommManager.BroadcastSessionEnd then
        ParallelLoot.CommManager:BroadcastSessionEnd(session.id)
    end
    
    -- End session
    ParallelLoot.DataManager:EndSession()
    
    -- Notify UI
    if ParallelLoot.UIManager.OnSessionEnd then
        ParallelLoot.UIManager:OnSessionEnd()
    end
    
    ParallelLoot:Print("Loot session ended")
    return true
end

-- ============================================================================
-- AWARD MANAGEMENT INTEGRATION
-- ============================================================================

-- Award item to player
function Integration:AwardItem(itemId, playerName)
    -- Validate permission
    if not ParallelLoot.LootMasterManager:ValidateLootMasterPermission("award items") then
        return false
    end
    
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:Print("No active session")
        return false
    end
    
    -- Find item in active items
    local item, index = ParallelLoot.DataManager:FindItemById(session.activeItems, itemId)
    if not item then
        ParallelLoot:Print("Item not found")
        return false
    end
    
    -- Validate player name
    if not playerName or playerName == "" then
        ParallelLoot:Print("Invalid player name")
        return false
    end
    
    -- Mark as awarded
    item.awardedTo = playerName
    item.awardTime = time()
    
    -- Move to awarded items
    table.remove(session.activeItems, index)
    table.insert(session.awardedItems, item)
    
    -- Recycle roll range
    if item.rollRange then
        ParallelLoot.RollManager:FreeRollRange(item.rollRange)
    end
    
    -- Save session
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Stop timer for this item
    if ParallelLoot.TimerManager.StopTimer then
        ParallelLoot.TimerManager:StopTimer(item)
    end
    
    -- Broadcast award
    if ParallelLoot.CommManager.BroadcastItemAwarded then
        ParallelLoot.CommManager:BroadcastItemAwarded(itemId, playerName)
    end
    
    -- Notify UI
    if ParallelLoot.UIManager.OnItemAwarded then
        ParallelLoot.UIManager:OnItemAwarded(item, playerName)
    end
    
    ParallelLoot:Print("Awarded", item.itemLink, "to", playerName)
    return true
end

-- Revoke item award
function Integration:RevokeAward(itemId)
    -- Validate permission
    if not ParallelLoot.LootMasterManager:ValidateLootMasterPermission("revoke awards") then
        return false
    end
    
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:Print("No active session")
        return false
    end
    
    -- Find item in awarded items
    local item, index = ParallelLoot.DataManager:FindItemById(session.awardedItems, itemId)
    if not item then
        ParallelLoot:Print("Item not found in awarded items")
        return false
    end
    
    -- Check if item is expired
    if ParallelLoot.DataManager.LootItem:IsExpired(item) then
        ParallelLoot:Print("Cannot revoke award for expired item")
        return false
    end
    
    -- Clear award info
    local previousWinner = item.awardedTo
    item.awardedTo = nil
    item.awardTime = nil
    
    -- Assign new roll range
    local newRange = ParallelLoot.RollManager:AssignRollRange()
    item.rollRange = newRange
    
    -- Move back to active items
    table.remove(session.awardedItems, index)
    table.insert(session.activeItems, item)
    
    -- Save session
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Restart timer for this item
    if ParallelLoot.TimerManager.StartTimer then
        ParallelLoot.TimerManager:StartTimer(item)
    end
    
    -- Broadcast revoke
    if ParallelLoot.CommManager.BroadcastItemRevoked then
        ParallelLoot.CommManager:BroadcastItemRevoked(itemId)
    end
    
    -- Notify UI
    if ParallelLoot.UIManager.OnItemRevoked then
        ParallelLoot.UIManager:OnItemRevoked(item)
    end
    
    ParallelLoot:Print("Revoked award of", item.itemLink, "from", previousWinner)
    return true
end

-- ============================================================================
-- ROLL SUBMISSION INTEGRATION
-- ============================================================================

-- Submit a roll for an item
function Integration:SubmitRoll(itemId, category)
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:Print("No active session")
        return false
    end
    
    -- Find item
    local item = ParallelLoot.DataManager:FindItemById(session.activeItems, itemId)
    if not item then
        ParallelLoot:Print("Item not found")
        return false
    end
    
    -- Check if player already rolled
    local playerName = UnitName("player")
    if ParallelLoot.RollManager:HasPlayerRolled(item, playerName) then
        ParallelLoot:Print("You have already rolled on this item")
        return false
    end
    
    -- Validate category
    if not item.rollRange or not item.rollRange[category] then
        ParallelLoot:Print("Invalid category")
        return false
    end
    
    -- Get roll range for category
    local range = item.rollRange[category]
    
    -- Perform the roll using WoW's RandomRoll function
    RandomRoll(range.min, range.max)
    
    ParallelLoot:DebugPrint("Integration: Submitted roll for", item.itemName, "category:", category)
    
    -- The roll will be detected by RollManager's chat event handler
    return true
end

-- ============================================================================
-- UI ACTION HANDLERS
-- ============================================================================

-- Handle award button click from UI
function Integration:HandleAwardButtonClick(panel)
    if not panel or not panel.lootItem then
        return
    end
    
    local item = panel.lootItem
    
    -- Get highest priority roll
    local winner = ParallelLoot.RollManager:GetItemWinner(item)
    
    if not winner then
        ParallelLoot:Print("No rolls found for this item")
        return
    end
    
    -- Show confirmation dialog
    StaticPopupDialogs["PARALLELLOOT_CONFIRM_AWARD"] = {
        text = string.format("Award %s to %s?", item.itemLink, winner.playerName),
        button1 = "Award",
        button2 = "Cancel",
        OnAccept = function()
            Integration:AwardItem(item.id, winner.playerName)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("PARALLELLOOT_CONFIRM_AWARD")
end

-- Handle revoke button click from UI
function Integration:HandleRevokeButtonClick(panel)
    if not panel or not panel.lootItem then
        return
    end
    
    local item = panel.lootItem
    
    -- Show confirmation dialog
    StaticPopupDialogs["PARALLELLOOT_CONFIRM_REVOKE"] = {
        text = string.format("Revoke award of %s from %s?", item.itemLink, item.awardedTo),
        button1 = "Revoke",
        button2 = "Cancel",
        OnAccept = function()
            Integration:RevokeAward(item.id)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("PARALLELLOOT_CONFIRM_REVOKE")
end

-- Handle category button click from UI
function Integration:HandleCategoryButtonClick(panel, category)
    if not panel or not panel.lootItem then
        return
    end
    
    local item = panel.lootItem
    
    -- Submit roll
    self:SubmitRoll(item.id, category)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Integration:Initialize()
    ParallelLoot:DebugPrint("Integration: Initializing component wiring")
    
    -- Wire all components together
    self:WireLootManager()
    self:WireRollManager()
    self:WireUIManager()
    self:WireTimerManager()
    self:WireCommManager()
    
    -- Wire UI action handlers
    if ParallelLoot.UIManager then
        ParallelLoot.UIManager.OnAwardButtonClicked = function(uiManager, panel)
            Integration:HandleAwardButtonClick(panel)
        end
        
        ParallelLoot.UIManager.OnRevokeButtonClicked = function(uiManager, panel)
            Integration:HandleRevokeButtonClick(panel)
        end
        
        ParallelLoot.UIManager.OnCategoryButtonClicked = function(uiManager, panel, category)
            Integration:HandleCategoryButtonClick(panel, category)
        end
    end
    
    ParallelLoot:DebugPrint("Integration: Component wiring complete")
end

-- ============================================================================
-- SLASH COMMAND EXTENSIONS
-- ============================================================================

-- Add session management commands
function Integration:RegisterSlashCommands()
    -- Extend existing slash command handler
    local originalHandler = SlashCmdList["PARALLELLOOT"]
    
    SlashCmdList["PARALLELLOOT"] = function(msg)
        local command = string.lower(msg or "")
        
        if command == "start" then
            Integration:StartSession()
        elseif command == "end" then
            Integration:EndSession()
        elseif command == "sync" then
            if ParallelLoot.CommManager.RequestSync then
                ParallelLoot.CommManager:RequestSync()
                ParallelLoot:Print("Requesting session sync...")
            end
        elseif command == "status" then
            local session = ParallelLoot.DataManager:GetCurrentSession()
            if session then
                local stats = ParallelLoot.DataManager:GetSessionStats(session)
                ParallelLoot:Print("Session Status:")
                print("  Active Items:", stats.activeItemCount)
                print("  Awarded Items:", stats.awardedItemCount)
                print("  Total Rolls:", stats.totalRolls)
                print("  Unique Players:", stats.uniquePlayerCount)
            else
                ParallelLoot:Print("No active session")
            end
        else
            -- Call original handler for other commands
            if originalHandler then
                originalHandler(msg)
            end
        end
    end
end

ParallelLoot:DebugPrint("Integration.lua loaded")
