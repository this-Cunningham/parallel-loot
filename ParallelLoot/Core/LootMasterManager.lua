-- ParallelLoot Loot Master Manager
-- Handles loot master detection, validation, and permissions

local LootMasterManager = ParallelLoot.LootMasterManager or {}
ParallelLoot.LootMasterManager = LootMasterManager

-- Event frame for group events
local lootMasterEventFrame = CreateFrame("Frame")

-- Current loot master state
LootMasterManager.currentLootMaster = nil
LootMasterManager.isPlayerLootMaster = false

-- Initialize the loot master manager
function LootMasterManager:Initialize()
    ParallelLoot:DebugPrint("LootMasterManager: Initializing")
    
    -- Register events for group changes
    lootMasterEventFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
    lootMasterEventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    lootMasterEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    lootMasterEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Set event handler
    lootMasterEventFrame:SetScript("OnEvent", function(self, event, ...)
        LootMasterManager:OnEvent(event, ...)
    end)
    
    -- Detect initial loot master
    self:DetectLootMaster()
    
    ParallelLoot:DebugPrint("LootMasterManager: Initialized")
end

-- Event handler
function LootMasterManager:OnEvent(event, ...)
    if event == "PARTY_LOOT_METHOD_CHANGED" or 
       event == "RAID_ROSTER_UPDATE" or 
       event == "GROUP_ROSTER_UPDATE" or
       event == "PLAYER_ENTERING_WORLD" then
        self:DetectLootMaster()
    end
end

-- Detect who the current loot master is
function LootMasterManager:DetectLootMaster()
    local lootMethod, masterLooterPartyID, masterLooterRaidID = C_PartyInfo.GetLootMethod()
    
    ParallelLoot:DebugPrint("LootMasterManager: Loot method:", lootMethod)
    
    local newLootMaster = nil
    
    if lootMethod == 2 then -- 2 = Enum.LootMethod.MasterLooter
        -- Master looter is active
        if masterLooterRaidID then
            -- In a raid
            newLootMaster = self:GetRaidMemberName(masterLooterRaidID)
            ParallelLoot:DebugPrint("LootMasterManager: Raid master looter:", newLootMaster)
        elseif masterLooterPartyID then
            -- In a party
            if masterLooterPartyID == 0 then
                newLootMaster = UnitName("player")
            else
                newLootMaster = UnitName("party" .. masterLooterPartyID)
            end
            ParallelLoot:DebugPrint("LootMasterManager: Party master looter:", newLootMaster)
        end
    else
        -- No master looter, default to player for solo or group leader
        if IsInRaid() then
            -- In raid, check if player is raid leader
            if UnitIsGroupLeader("player") then
                newLootMaster = UnitName("player")
                ParallelLoot:DebugPrint("LootMasterManager: Player is raid leader, acting as loot master")
            end
        elseif IsInGroup() then
            -- In party, check if player is party leader
            if UnitIsGroupLeader("player") then
                newLootMaster = UnitName("player")
                ParallelLoot:DebugPrint("LootMasterManager: Player is party leader, acting as loot master")
            end
        else
            -- Solo, player is loot master
            newLootMaster = UnitName("player")
            ParallelLoot:DebugPrint("LootMasterManager: Player is solo, acting as loot master")
        end
    end
    
    -- Update loot master if changed
    if newLootMaster ~= self.currentLootMaster then
        local oldLootMaster = self.currentLootMaster
        self.currentLootMaster = newLootMaster
        
        -- Check if player is the loot master
        local playerName = UnitName("player")
        self.isPlayerLootMaster = (newLootMaster == playerName)
        
        ParallelLoot:DebugPrint("LootMasterManager: Loot master changed from", 
            oldLootMaster or "none", "to", newLootMaster or "none")
        ParallelLoot:DebugPrint("LootMasterManager: Player is loot master:", self.isPlayerLootMaster)
        
        -- Notify other systems of loot master change
        self:OnLootMasterChanged(oldLootMaster, newLootMaster)
    end
    
    return newLootMaster
end

-- Get raid member name by raid index
function LootMasterManager:GetRaidMemberName(raidIndex)
    if not raidIndex or raidIndex < 1 then
        return nil
    end
    
    local name = UnitName("raid" .. raidIndex)
    return name
end

-- Callback when loot master changes
function LootMasterManager:OnLootMasterChanged(oldMaster, newMaster)
    -- Update session if one exists
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        session.masterId = newMaster or UnitName("player")
        ParallelLoot.DataManager:SaveCurrentSession(session)
    end
    
    -- Notify UI to update
    if ParallelLoot.UIManager and ParallelLoot.UIManager.OnLootMasterChanged then
        ParallelLoot.UIManager:OnLootMasterChanged(oldMaster, newMaster)
    end
    
    -- Print notification
    if self.isPlayerLootMaster then
        ParallelLoot:Print("You are now the loot master")
    elseif newMaster then
        ParallelLoot:Print(newMaster .. " is now the loot master")
    end
end

-- Check if current player is the loot master
function LootMasterManager:IsPlayerLootMaster()
    return self.isPlayerLootMaster
end

-- Get current loot master name
function LootMasterManager:GetLootMaster()
    return self.currentLootMaster
end

-- Check if a specific player is the loot master
function LootMasterManager:IsPlayerLootMasterByName(playerName)
    if not playerName then
        return false
    end
    return self.currentLootMaster == playerName
end

-- Validate if player has permission to perform loot master action
function LootMasterManager:ValidateLootMasterPermission(actionName)
    if not self:IsPlayerLootMaster() then
        ParallelLoot:Print("You do not have permission to " .. (actionName or "perform this action"))
        return false
    end
    return true
end

-- Check if player can award items
function LootMasterManager:CanAwardItems()
    return self:IsPlayerLootMaster()
end

-- Check if player can revoke awards
function LootMasterManager:CanRevokeAwards()
    return self:IsPlayerLootMaster()
end

-- Check if player can start/end sessions
function LootMasterManager:CanManageSessions()
    return self:IsPlayerLootMaster()
end

-- Check if player can modify loot items
function LootMasterManager:CanModifyLootItems()
    return self:IsPlayerLootMaster()
end

-- Get loot master status text for UI
function LootMasterManager:GetStatusText()
    if self.isPlayerLootMaster then
        return "You are the Loot Master"
    elseif self.currentLootMaster then
        return "Loot Master: " .. self.currentLootMaster
    else
        return "No Loot Master"
    end
end

-- Force refresh of loot master detection
function LootMasterManager:Refresh()
    self:DetectLootMaster()
end

ParallelLoot:DebugPrint("LootMasterManager.lua loaded")
