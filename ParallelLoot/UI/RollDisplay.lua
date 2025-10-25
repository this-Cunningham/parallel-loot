-- ParallelLoot Roll Display
-- Expandable category sections showing player rolls

local UIManager = ParallelLoot.UIManager

-- Class colors (WoW standard colors)
UIManager.CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45},
    ROGUE = {1.00, 0.96, 0.41},
    PRIEST = {1.00, 1.00, 1.00},
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    SHAMAN = {0.00, 0.44, 0.87},
    MAGE = {0.25, 0.78, 0.92},
    WARLOCK = {0.53, 0.53, 0.93},
    MONK = {0.00, 1.00, 0.59},
    DRUID = {1.00, 0.49, 0.04}
}

-- Get class color for a player
function UIManager:GetPlayerClassColor(playerName)
    -- Try to get class from raid/party
    local _, class = UnitClass(playerName)
    
    if not class then
        -- Try to find in raid
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitName(unit) == playerName then
                _, class = UnitClass(unit)
                break
            end
        end
    end
    
    if not class then
        -- Try to find in party
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitName(unit) == playerName then
                _, class = UnitClass(unit)
                break
            end
        end
    end
    
    -- Check if it's the player
    if not class and UnitName("player") == playerName then
        _, class = UnitClass("player")
    end
    
    -- Return class color or default white
    if class and self.CLASS_COLORS[class] then
        return unpack(self.CLASS_COLORS[class])
    end
    
    return 1, 1, 1 -- Default white
end

-- Create roll display sections in expanded content
function UIManager:CreateRollDisplay(panel)
    if panel.rollDisplay then
        return -- Already created
    end
    
    local content = panel.expandedContent
    panel.rollDisplay = {}
    
    -- Create four-column layout for categories
    local columnWidth = 150
    local columnSpacing = 5
    local totalWidth = (columnWidth * 4) + (columnSpacing * 3)
    
    -- Container for all columns
    local container = CreateFrame("Frame", nil, content)
    container:SetPoint("TOPLEFT", 0, 0)
    container:SetPoint("TOPRIGHT", 0, 0)
    container:SetHeight(180)
    panel.rollDisplay.container = container
    
    -- Create columns for each category
    local categories = {"bis", "ms", "os", "coz"}
    local categoryLabels = {
        bis = self:GetCategoryLabel("bis"),
        ms = self:GetCategoryLabel("ms"),
        os = self:GetCategoryLabel("os"),
        coz = self:GetCategoryLabel("coz")
    }
    
    for i, categoryKey in ipairs(categories) do
        local column = self:CreateRollColumn(container, categoryKey, categoryLabels[categoryKey])
        
        -- Position columns
        local xOffset = (i - 1) * (columnWidth + columnSpacing)
        column:SetPoint("TOPLEFT", xOffset, 0)
        column:SetSize(columnWidth, 180)
        
        panel.rollDisplay[categoryKey] = column
    end
end

-- Create a single roll column for a category
function UIManager:CreateRollColumn(parent, categoryKey, categoryLabel)
    local column = CreateFrame("Frame", nil, parent)
    
    -- Background
    column.bg = column:CreateTexture(nil, "BACKGROUND")
    column.bg:SetAllPoints()
    column.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    
    -- Border
    column.border = column:CreateTexture(nil, "BORDER")
    column.border:SetAllPoints()
    column.border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    
    -- Inner background
    column.innerBg = column:CreateTexture(nil, "ARTWORK")
    column.innerBg:SetPoint("TOPLEFT", 1, -1)
    column.innerBg:SetPoint("BOTTOMRIGHT", -1, 1)
    column.innerBg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
    
    -- Category header
    column.header = column:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    column.header:SetPoint("TOP", 0, -5)
    column.header:SetText(categoryLabel)
    
    -- Get category color
    local categoryColor = self:GetCategoryColor(categoryKey)
    column.header:SetTextColor(unpack(categoryColor))
    
    -- Scroll frame for roll entries
    column.scrollFrame = CreateFrame("ScrollFrame", nil, column)
    column.scrollFrame:SetPoint("TOPLEFT", 5, -25)
    column.scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    
    -- Scroll child
    column.scrollChild = CreateFrame("Frame", nil, column.scrollFrame)
    column.scrollFrame:SetScrollChild(column.scrollChild)
    column.scrollChild:SetWidth(140)
    column.scrollChild:SetHeight(1)
    
    -- Roll entries container
    column.rollEntries = {}
    column.categoryKey = categoryKey
    
    return column
end

-- Get category color
function UIManager:GetCategoryColor(categoryKey)
    for _, cat in ipairs(self.CATEGORIES) do
        if cat.key == categoryKey then
            return cat.color
        end
    end
    return {1, 1, 1} -- Default white
end

-- Update roll display with current roll data
function UIManager:UpdateRollDisplay(panel)
    if not panel.lootItem or not panel.rollDisplay then
        return
    end
    
    -- Get rolls organized by category
    local rollsByCategory = ParallelLoot.DataManager:GetRollsOrganized(panel.lootItem)
    
    -- Update each column
    for categoryKey, column in pairs(panel.rollDisplay) do
        if categoryKey ~= "container" then
            local rolls = rollsByCategory[categoryKey] or {}
            self:UpdateRollColumn(column, rolls)
        end
    end
end

-- Update a single roll column with roll data
function UIManager:UpdateRollColumn(column, rolls)
    -- Clear existing entries
    for _, entry in ipairs(column.rollEntries) do
        entry:Hide()
        entry:SetParent(nil)
    end
    column.rollEntries = {}
    
    -- Create entries for each roll
    local yOffset = 0
    for i, roll in ipairs(rolls) do
        local entry = self:CreateRollEntry(column.scrollChild, roll)
        entry:SetPoint("TOPLEFT", 0, -yOffset)
        entry:SetSize(140, 20)
        
        table.insert(column.rollEntries, entry)
        yOffset = yOffset + 22 -- 20px height + 2px spacing
    end
    
    -- Update scroll child height
    local totalHeight = math.max(1, yOffset)
    column.scrollChild:SetHeight(totalHeight)
    
    -- Show "No rolls" message if empty
    if #rolls == 0 then
        if not column.emptyText then
            column.emptyText = column.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            column.emptyText:SetPoint("TOP", 0, -10)
            column.emptyText:SetTextColor(0.5, 0.5, 0.5, 1)
            column.emptyText:SetText("No rolls")
        end
        column.emptyText:Show()
    else
        if column.emptyText then
            column.emptyText:Hide()
        end
    end
end

-- Create a single roll entry (player name + roll value)
function UIManager:CreateRollEntry(parent, roll)
    local entry = CreateFrame("Button", nil, parent)
    entry:SetSize(140, 20)
    
    -- Player name (left-aligned)
    entry.playerName = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.playerName:SetPoint("LEFT", 5, 0)
    entry.playerName:SetJustifyH("LEFT")
    entry.playerName:SetText(roll.playerName)
    
    -- Set class color
    local r, g, b = UIManager:GetPlayerClassColor(roll.playerName)
    entry.playerName:SetTextColor(r, g, b, 1)
    
    -- Roll value (right-aligned)
    entry.rollValue = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.rollValue:SetPoint("RIGHT", -5, 0)
    entry.rollValue:SetJustifyH("RIGHT")
    entry.rollValue:SetText(tostring(roll.rollValue))
    entry.rollValue:SetTextColor(1, 1, 1, 1)
    
    -- Highlight background on hover
    entry.highlight = entry:CreateTexture(nil, "BACKGROUND")
    entry.highlight:SetAllPoints()
    entry.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)
    entry.highlight:Hide()
    
    -- Selection background (for loot master)
    entry.selection = entry:CreateTexture(nil, "BACKGROUND")
    entry.selection:SetAllPoints()
    entry.selection:SetColorTexture(0, 0.8, 0, 0.4) -- Green selection
    entry.selection:Hide()
    
    entry:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.highlight:Show()
        end
    end)
    
    entry:SetScript("OnLeave", function(self)
        if not self.isSelected then
            self.highlight:Hide()
        end
    end)
    
    -- Click handler for loot master selection
    entry:SetScript("OnClick", function(self)
        if ParallelLoot.LootMasterManager:IsPlayerLootMaster() then
            UIManager:OnRollEntryClicked(self)
        end
    end)
    
    -- Store roll data
    entry.roll = roll
    entry.isSelected = false
    
    return entry
end

-- Update expanded content (override from ItemPanel.lua)
function UIManager:UpdateExpandedContent(panel)
    -- Create roll display if it doesn't exist
    if not panel.rollDisplay then
        self:CreateRollDisplay(panel)
    end
    
    -- Update with current roll data
    self:UpdateRollDisplay(panel)
    
    -- Disable interactions for awarded items (read-only)
    local isAwarded = panel.lootItem and panel.lootItem.awardedTo
    if isAwarded then
        self:SetRollDisplayReadOnly(panel, true)
    else
        self:SetRollDisplayReadOnly(panel, false)
    end
    
    -- Remove placeholder if it exists
    if panel.expandedContent.placeholder then
        panel.expandedContent.placeholder:Hide()
    end
end

-- Set roll display to read-only mode
function UIManager:SetRollDisplayReadOnly(panel, readOnly)
    if not panel.rollDisplay then
        return
    end
    
    -- Disable click handlers on roll entries for awarded items
    for categoryKey, column in pairs(panel.rollDisplay) do
        if categoryKey ~= "container" then
            for _, entry in ipairs(column.rollEntries) do
                if readOnly then
                    entry:SetScript("OnClick", nil)
                    entry:EnableMouse(false)
                    -- Dim the entries slightly
                    if entry.playerName then
                        local r, g, b = entry.playerName:GetTextColor()
                        entry.playerName:SetTextColor(r * 0.7, g * 0.7, b * 0.7, 1)
                    end
                    if entry.rollValue then
                        entry.rollValue:SetTextColor(0.7, 0.7, 0.7, 1)
                    end
                else
                    entry:EnableMouse(true)
                    if ParallelLoot.LootMasterManager:IsPlayerLootMaster() then
                        entry:SetScript("OnClick", function(self)
                            UIManager:OnRollEntryClicked(self)
                        end)
                    end
                end
            end
        end
    end
end

ParallelLoot:DebugPrint("RollDisplay.lua loaded")

-- Handle roll added event (called by RollManager)
function UIManager:OnRollAdded(item, roll)
    -- Find the panel for this item
    local panel = self:FindPanelForItem(item)
    
    if not panel then
        ParallelLoot:DebugPrint("RollDisplay: No panel found for item", item.id)
        return
    end
    
    -- Update the roll display if panel is expanded
    if panel.isExpanded and panel.rollDisplay then
        -- Get the column for this category
        local column = panel.rollDisplay[roll.category]
        if column then
            -- Add the new roll with animation
            self:AddRollEntryAnimated(column, roll)
        end
    end
    
    -- Update category buttons to reflect the new roll
    self:UpdateCategoryButtons(panel)
    
    ParallelLoot:DebugPrint("RollDisplay: Roll added to UI -", roll.playerName, roll.rollValue)
end

-- Find panel for a specific item
function UIManager:FindPanelForItem(item)
    for _, panel in pairs(self.activeItemPanels) do
        if panel.lootItem and panel.lootItem.id == item.id then
            return panel
        end
    end
    return nil
end

-- Add a roll entry with animation
function UIManager:AddRollEntryAnimated(column, roll)
    -- Get current rolls for this category
    local rolls = {}
    for _, entry in ipairs(column.rollEntries) do
        if entry.roll then
            table.insert(rolls, entry.roll)
        end
    end
    
    -- Add new roll
    table.insert(rolls, roll)
    
    -- Sort by roll value (highest first)
    table.sort(rolls, function(a, b)
        return a.rollValue > b.rollValue
    end)
    
    -- Find the position of the new roll
    local newRollIndex = nil
    for i, r in ipairs(rolls) do
        if r.playerName == roll.playerName and r.rollValue == roll.rollValue and r.timestamp == roll.timestamp then
            newRollIndex = i
            break
        end
    end
    
    -- Update the column with animation
    self:UpdateRollColumnAnimated(column, rolls, newRollIndex)
end

-- Update roll column with animation for new entry
function UIManager:UpdateRollColumnAnimated(column, rolls, highlightIndex)
    -- Clear existing entries
    for _, entry in ipairs(column.rollEntries) do
        entry:Hide()
        entry:SetParent(nil)
    end
    column.rollEntries = {}
    
    -- Create entries for each roll
    local yOffset = 0
    for i, roll in ipairs(rolls) do
        local entry = self:CreateRollEntry(column.scrollChild, roll)
        entry:SetPoint("TOPLEFT", 0, -yOffset)
        entry:SetSize(140, 20)
        
        -- Animate new entry
        if i == highlightIndex then
            entry:SetAlpha(0)
            
            -- Fade in animation
            local fadeIn = entry:CreateAnimationGroup()
            local alpha = fadeIn:CreateAnimation("Alpha")
            alpha:SetFromAlpha(0)
            alpha:SetToAlpha(1)
            alpha:SetDuration(0.5)
            alpha:SetSmoothing("IN")
            
            -- Flash highlight
            entry.highlight:Show()
            entry.highlight:SetColorTexture(0, 1, 0, 0.5) -- Green highlight
            
            fadeIn:Play()
            
            -- Remove highlight after animation
            C_Timer.After(1.5, function()
                if entry.highlight then
                    entry.highlight:Hide()
                    entry.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3) -- Reset to default
                end
            end)
        end
        
        table.insert(column.rollEntries, entry)
        yOffset = yOffset + 22 -- 20px height + 2px spacing
    end
    
    -- Update scroll child height
    local totalHeight = math.max(1, yOffset)
    column.scrollChild:SetHeight(totalHeight)
    
    -- Hide "No rolls" message
    if column.emptyText then
        column.emptyText:Hide()
    end
end

-- Refresh all visible roll displays (called when switching tabs or refreshing)
function UIManager:RefreshAllRollDisplays()
    for _, panel in pairs(self.activeItemPanels) do
        if panel.isExpanded and panel.rollDisplay then
            self:UpdateRollDisplay(panel)
        end
    end
end

-- Handle roll removed event (for future use)
function UIManager:OnRollRemoved(item, playerName)
    local panel = self:FindPanelForItem(item)
    
    if not panel then
        return
    end
    
    -- Update the roll display if panel is expanded
    if panel.isExpanded and panel.rollDisplay then
        self:UpdateRollDisplay(panel)
    end
    
    -- Update category buttons
    self:UpdateCategoryButtons(panel)
end

-- Handle roll entry click (for loot master selection)
function UIManager:OnRollEntryClicked(entry)
    if not entry or not entry.roll then
        return
    end
    
    -- Find the panel this entry belongs to
    local panel = self:FindPanelForRollEntry(entry)
    if not panel then
        return
    end
    
    -- Clear previous selection in this panel
    if panel.selectedRollEntry and panel.selectedRollEntry ~= entry then
        panel.selectedRollEntry.isSelected = false
        panel.selectedRollEntry.selection:Hide()
        panel.selectedRollEntry.highlight:Hide()
    end
    
    -- Toggle selection
    entry.isSelected = not entry.isSelected
    
    if entry.isSelected then
        entry.selection:Show()
        entry.highlight:Hide()
        panel.selectedRollEntry = entry
        ParallelLoot:DebugPrint("RollDisplay: Selected", entry.roll.playerName, "for award")
    else
        entry.selection:Hide()
        panel.selectedRollEntry = nil
        ParallelLoot:DebugPrint("RollDisplay: Deselected", entry.roll.playerName)
    end
end

-- Find panel for a roll entry
function UIManager:FindPanelForRollEntry(entry)
    for _, panel in pairs(self.activeItemPanels) do
        if panel.rollDisplay then
            for categoryKey, column in pairs(panel.rollDisplay) do
                if categoryKey ~= "container" then
                    for _, rollEntry in ipairs(column.rollEntries) do
                        if rollEntry == entry then
                            return panel
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Handle award button click
function UIManager:OnAwardButtonClicked(panel)
    if not panel or not panel.lootItem then
        return
    end
    
    -- Check if player is loot master
    if not ParallelLoot.LootMasterManager:ValidateLootMasterPermission("award items") then
        return
    end
    
    -- Check if a player is selected
    local selectedEntry = panel.selectedRollEntry
    if not selectedEntry or not selectedEntry.roll then
        ParallelLoot:Print("Please select a player to award the item to")
        return
    end
    
    local playerName = selectedEntry.roll.playerName
    local itemLink = panel.lootItem.itemLink or panel.lootItem.itemName
    
    -- Show confirmation dialog
    self:ShowAwardConfirmation(panel.lootItem, playerName, function()
        -- Award the item
        self:AwardItem(panel.lootItem, playerName)
    end)
end

-- Show award confirmation dialog
function UIManager:ShowAwardConfirmation(lootItem, playerName, callback)
    local itemLink = lootItem.itemLink or lootItem.itemName
    
    StaticPopupDialogs["PARALLELLOOT_AWARD_CONFIRM"] = {
        text = string.format("Award %s to %s?", itemLink, playerName),
        button1 = "Award",
        button2 = "Cancel",
        OnAccept = function()
            if callback then
                callback()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
    
    StaticPopup_Show("PARALLELLOOT_AWARD_CONFIRM")
end

-- Award item to player
function UIManager:AwardItem(lootItem, playerName)
    if not lootItem or not playerName then
        return
    end
    
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:Print("No active session")
        return
    end
    
    -- Find the item in active items
    local itemIndex = nil
    for i, item in ipairs(session.activeItems) do
        if item.id == lootItem.id then
            itemIndex = i
            break
        end
    end
    
    if not itemIndex then
        ParallelLoot:Print("Item not found in active items")
        return
    end
    
    -- Mark item as awarded
    lootItem.awardedTo = playerName
    lootItem.awardTime = time()
    
    -- Move from active to awarded
    table.remove(session.activeItems, itemIndex)
    table.insert(session.awardedItems, lootItem)
    
    -- Recycle roll range
    if lootItem.rollRange then
        ParallelLoot.DataManager:RecycleRollRange(session, lootItem.rollRange)
    end
    
    -- Save session
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Broadcast award to raid
    if ParallelLoot.CommManager.BroadcastItemAwarded then
        ParallelLoot.CommManager:BroadcastItemAwarded(lootItem.id, playerName)
    end
    
    -- Notify
    ParallelLoot:Print(string.format("Awarded %s to %s", lootItem.itemLink or lootItem.itemName, playerName))
    
    -- Refresh UI
    self:RefreshItemList()
    
    ParallelLoot:DebugPrint("UIManager: Item awarded -", lootItem.id, "to", playerName)
end

-- Handle revoke button click
function UIManager:OnRevokeButtonClicked(panel)
    if not panel or not panel.lootItem then
        return
    end
    
    -- Check if player is loot master
    if not ParallelLoot.LootMasterManager:ValidateLootMasterPermission("revoke awards") then
        return
    end
    
    -- Check if item is awarded
    if not panel.lootItem.awardedTo then
        ParallelLoot:Print("Item is not awarded")
        return
    end
    
    -- Check if item is expired
    if ParallelLoot.DataManager.LootItem:IsExpired(panel.lootItem) then
        ParallelLoot:Print("Cannot revoke award for expired item")
        return
    end
    
    local playerName = panel.lootItem.awardedTo
    local itemLink = panel.lootItem.itemLink or panel.lootItem.itemName
    
    -- Show confirmation dialog
    self:ShowRevokeConfirmation(panel.lootItem, playerName, function()
        -- Revoke the award
        self:RevokeAward(panel.lootItem)
    end)
end

-- Show revoke confirmation dialog
function UIManager:ShowRevokeConfirmation(lootItem, playerName, callback)
    local itemLink = lootItem.itemLink or lootItem.itemName
    
    StaticPopupDialogs["PARALLELLOOT_REVOKE_CONFIRM"] = {
        text = string.format("Revoke award of %s from %s?\n\nThe item will return to active items with all previous rolls preserved.", itemLink, playerName),
        button1 = "Revoke",
        button2 = "Cancel",
        OnAccept = function()
            if callback then
                callback()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
    
    StaticPopup_Show("PARALLELLOOT_REVOKE_CONFIRM")
end

-- Revoke award and return item to active items
function UIManager:RevokeAward(lootItem)
    if not lootItem then
        return
    end
    
    -- Get current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        ParallelLoot:Print("No active session")
        return
    end
    
    -- Find the item in awarded items
    local itemIndex = nil
    for i, item in ipairs(session.awardedItems) do
        if item.id == lootItem.id then
            itemIndex = i
            break
        end
    end
    
    if not itemIndex then
        ParallelLoot:Print("Item not found in awarded items")
        return
    end
    
    local previousAwardee = lootItem.awardedTo
    
    -- Clear award information
    lootItem.awardedTo = nil
    lootItem.awardTime = nil
    
    -- Assign new roll range (old one was recycled)
    local newRollRange = ParallelLoot.DataManager:AssignRollRange(session)
    if newRollRange then
        lootItem.rollRange = newRollRange
        ParallelLoot:DebugPrint("UIManager: Assigned new roll range for revoked item:", newRollRange.bis.min, "-", newRollRange.bis.max)
    else
        ParallelLoot:Print("Error: Could not assign roll range for revoked item")
        return
    end
    
    -- Move from awarded back to active
    table.remove(session.awardedItems, itemIndex)
    table.insert(session.activeItems, lootItem)
    
    -- Save session
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Broadcast revoke to raid
    if ParallelLoot.CommManager.BroadcastItemRevoked then
        ParallelLoot.CommManager:BroadcastItemRevoked(lootItem.id, previousAwardee)
    end
    
    -- Notify
    ParallelLoot:Print(string.format("Revoked award of %s from %s. Item returned to active items with preserved rolls.", 
        lootItem.itemLink or lootItem.itemName, previousAwardee))
    
    -- Refresh UI
    self:RefreshItemList()
    
    ParallelLoot:DebugPrint("UIManager: Award revoked -", lootItem.id, "from", previousAwardee)
end
