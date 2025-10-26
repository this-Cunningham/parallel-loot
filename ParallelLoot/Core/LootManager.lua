-- ParallelLoot Loot Manager
-- Handles loot detection and item management

local LootManager = ParallelLoot.LootManager

-- Event frame for loot events
local lootEventFrame = CreateFrame("Frame")

-- Initialize the loot manager
function LootManager:Initialize()
    ParallelLoot:DebugPrint("LootManager: Initializing")
    
    -- Register loot events
    lootEventFrame:RegisterEvent("LOOT_OPENED")
    lootEventFrame:RegisterEvent("LOOT_SLOT_CHANGED")
    lootEventFrame:RegisterEvent("LOOT_CLOSED")
    
    -- Set event handler
    lootEventFrame:SetScript("OnEvent", function(self, event, ...)
        LootManager:OnEvent(event, ...)
    end)
    
    ParallelLoot:DebugPrint("LootManager: Initialized")
end

-- Event handler for loot events
function LootManager:OnEvent(event, ...)
    if event == "LOOT_OPENED" then
        self:OnLootOpened(...)
    elseif event == "LOOT_SLOT_CHANGED" then
        self:OnLootSlotChanged(...)
    elseif event == "LOOT_CLOSED" then
        self:OnLootClosed(...)
    end
end

-- Handle LOOT_OPENED event
function LootManager:OnLootOpened(...)
    ParallelLoot:DebugPrint("LootManager: Loot window opened")
    
    -- Check if we have an active session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:DebugPrint("LootManager: No active session, skipping loot detection")
        return
    end
    
    -- Parse loot from the loot window
    self:ParseLootWindow()
end

-- Handle LOOT_SLOT_CHANGED event
function LootManager:OnLootSlotChanged(slot)
    ParallelLoot:DebugPrint("LootManager: Loot slot changed:", slot)
    
    -- Check if we have an active session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return
    end
    
    -- Re-parse the specific slot
    self:ParseLootSlot(slot)
end

-- Handle LOOT_CLOSED event
function LootManager:OnLootClosed()
    ParallelLoot:DebugPrint("LootManager: Loot window closed")
end

-- Parse all items in the loot window
function LootManager:ParseLootWindow()
    local numLootItems = GetNumLootItems()
    ParallelLoot:DebugPrint("LootManager: Found", numLootItems, "loot items")
    
    for slot = 1, numLootItems do
        self:ParseLootSlot(slot)
    end
end

-- Parse a specific loot slot and create LootItem
function LootManager:ParseLootSlot(slot)
    -- Get item link first (this works in MoP Classic)
    local itemLink = GetLootSlotLink(slot)
    if not itemLink or itemLink == "" then
        ParallelLoot:DebugPrint("LootManager: No item link for slot", slot)
        return
    end
    
    -- Extract item ID from link
    local itemId = self:ExtractItemIdFromLink(itemLink)
    if not itemId then
        ParallelLoot:DebugPrint("LootManager: Could not extract item ID from link:", itemLink)
        return
    end
    
    -- Get item info from the item ID (since GetLootSlotInfo doesn't work)
    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemId)
    
    -- Use defaults if item info not available yet
    local name = itemName or "Unknown Item"
    local quality = itemQuality or 1
    local icon = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
    local quantity = 1 -- Default quantity since we can't get it from GetLootSlotInfo
    
    -- Create LootItem object
    local lootItem = self:CreateLootItem(itemLink, itemId, quality, icon, name, quantity)
    
    -- Add to session
    self:AddItemToSession(lootItem)
end

-- Extract item ID from item link
function LootManager:ExtractItemIdFromLink(itemLink)
    if not itemLink then
        return nil
    end
    
    -- Item link format: |cffffffff|Hitem:itemId:...|h[Item Name]|h|r
    local itemId = string.match(itemLink, "item:(%d+)")
    return tonumber(itemId)
end

-- Create a LootItem object
function LootManager:CreateLootItem(itemLink, itemId, quality, icon, name, quantity)
    -- Generate unique item ID
    local uniqueId = self:GenerateUniqueItemId(itemId)
    
    -- Get current time
    local currentTime = time()
    
    -- Calculate expiry time (2 hours from now)
    local expiryTime = currentTime + (2 * 60 * 60)
    
    -- Get item metadata
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture = C_Item.GetItemInfo(itemId)
    
    -- Create LootItem structure
    local lootItem = {
        id = uniqueId,
        itemLink = itemLink,
        itemId = itemId,
        itemName = itemName or name,
        quality = quality,
        icon = icon,
        quantity = quantity or 1,
        itemType = itemType,
        itemSubType = itemSubType,
        itemEquipLoc = itemEquipLoc,
        itemLevel = itemLevel,
        rollRange = nil,  -- Will be assigned by RollManager
        rolls = {},
        dropTime = currentTime,
        expiryTime = expiryTime,
        awardedTo = nil,
        awardTime = nil
    }
    
    ParallelLoot:DebugPrint("LootManager: Created LootItem:", lootItem.itemName, "ID:", lootItem.id)
    
    return lootItem
end

-- Generate unique item ID
function LootManager:GenerateUniqueItemId(itemId)
    -- Combine item ID with timestamp and random number for uniqueness
    local timestamp = time()
    local random = math.random(1000, 9999)
    return string.format("%d_%d_%d", itemId, timestamp, random)
end

-- Add item to current session
function LootManager:AddItemToSession(lootItem)
    -- Check if item already exists in session (avoid duplicates)
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:DebugPrint("LootManager: No active session to add item to")
        return false
    end
    
    -- Check for duplicate based on itemId and recent drop time (within 5 seconds)
    for _, existingItem in ipairs(session.activeItems) do
        if existingItem.itemId == lootItem.itemId and 
           math.abs(existingItem.dropTime - lootItem.dropTime) < 5 then
            ParallelLoot:DebugPrint("LootManager: Item already exists in session, skipping")
            return false
        end
    end
    
    -- Check if current player can use this item
    local canUse = ParallelLoot.ClassFilter:CanCurrentPlayerUseItem(lootItem)
    lootItem.canUse = canUse
    
    if not canUse then
        ParallelLoot:DebugPrint("LootManager: Item cannot be used by player class, marking as unusable")
    end
    
    -- Assign roll range
    local rollRange = ParallelLoot.DataManager:AssignRollRange(session)
    if rollRange then
        lootItem.rollRange = rollRange
        ParallelLoot:DebugPrint("LootManager: Assigned roll range:", rollRange.bis.min, "-", rollRange.bis.max)
    else
        ParallelLoot:DebugPrint("LootManager: Failed to assign roll range")
        return false
    end
    
    -- Add to session
    table.insert(session.activeItems, lootItem)
    
    -- Save session
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Start timer for the item
    if ParallelLoot.TimerManager.StartTimer then
        ParallelLoot.TimerManager:StartTimer(lootItem)
    end
    
    -- Notify UI to update
    if ParallelLoot.UIManager.OnItemAdded then
        ParallelLoot.UIManager:OnItemAdded(lootItem)
    end
    
    -- Broadcast to raid if we're the loot master
    if ParallelLoot.CommManager.BroadcastItemAdded then
        ParallelLoot.CommManager:BroadcastItemAdded(lootItem)
    end
    
    ParallelLoot:Print("New loot added:", lootItem.itemLink)
    
    return true
end

-- Get filtered items for current player
function LootManager:GetFilteredItemsForPlayer()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return {}
    end
    
    local playerClass = ParallelLoot.ClassFilter:GetPlayerClass()
    return ParallelLoot.ClassFilter:FilterItemsForPlayer(session.activeItems, playerClass)
end

-- Check if item should be shown to player
function LootManager:ShouldShowItemToPlayer(lootItem)
    -- Always show to loot master
    if self:IsPlayerLootMaster() then
        return true
    end
    
    -- Show if player can use it
    return ParallelLoot.ClassFilter:CanCurrentPlayerUseItem(lootItem)
end

-- Check if player is loot master
function LootManager:IsPlayerLootMaster()
    return ParallelLoot.LootMasterManager:IsPlayerLootMaster()
end

-- Get item quality name
function LootManager:GetQualityName(quality)
    local qualityNames = {
        [0] = "Poor",
        [1] = "Common",
        [2] = "Uncommon",
        [3] = "Rare",
        [4] = "Epic",
        [5] = "Legendary",
        [6] = "Artifact",
        [7] = "Heirloom"
    }
    return qualityNames[quality] or "Unknown"
end

-- Get item quality color
function LootManager:GetQualityColor(quality)
    local r, g, b, hex = GetItemQualityColor(quality or 1)
    return r, g, b, hex
end

-- Get active items from current session
function LootManager:GetActiveItems()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return {}
    end
    
    return session.activeItems or {}
end

-- Get awarded items from current session
function LootManager:GetAwardedItems()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return {}
    end
    
    return session.awardedItems or {}
end

-- Callback when item is added (for UI updates)
function LootManager:OnItemAdded(lootItem)
    -- Refresh UI if it's visible
    if ParallelLoot.UIManager.Refresh then
        ParallelLoot.UIManager:Refresh()
    end
end
