-- ParallelLoot Main UI Frame
-- Main loot session panel with tabbed interface

local UIManager = ParallelLoot.UIManager

-- Tab definitions
UIManager.TABS = {
    ACTIVE = 1,
    AWARDED = 2
}

UIManager.currentTab = UIManager.TABS.ACTIVE
UIManager.mainFrame = nil
UIManager.tabs = {}
UIManager.itemPanels = {}

-- Initialize main frame on load
function UIManager:OnMainFrameLoad(frame)
    self.mainFrame = frame
    
    -- Set backdrop using BackdropTemplate
    if frame.SetBackdrop then
        local backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        }
        frame:SetBackdrop(backdrop)
        ParallelLoot:DebugPrint("Backdrop set successfully")
    else
        ParallelLoot:DebugPrint("SetBackdrop method not available")
    end
    
    -- Store loot master status indicator
    self.lootMasterIndicator = nil
    
    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    -- Setup resize functionality
    local resizeButton = frame.ParallelLootMainFrameResizeButton
    if resizeButton then
        resizeButton:SetScript("OnMouseDown", function()
            frame:StartSizing("BOTTOMRIGHT")
        end)
        resizeButton:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            UIManager:OnFrameResized()
        end)
    end
    
    -- Set resize bounds (SetMinResize/SetMaxResize don't exist in MoP Classic)
    -- frame:SetMinResize(500, 400)
    -- frame:SetMaxResize(1200, 900)
    ParallelLoot:DebugPrint("Resize bounds disabled - not available in MoP Classic")
    
    -- Create tabs
    self:CreateTabs()
    
    -- Initialize scroll frame
    self.scrollFrame = frame:GetChildren() and frame.ParallelLootMainFrameScrollFrame or _G["ParallelLootMainFrameScrollFrame"]
    if self.scrollFrame then
        self.scrollChild = self.scrollFrame:GetScrollChild() or _G["ParallelLootMainFrameScrollFrameScrollChild"]
    end
    
    -- Debug scroll frame references
    ParallelLoot:DebugPrint("ScrollFrame:", self.scrollFrame and "found" or "nil")
    ParallelLoot:DebugPrint("ScrollChild:", self.scrollChild and "found" or "nil")
    
    -- Create loot master indicator
    self:CreateLootMasterIndicator()
    
    ParallelLoot:DebugPrint("MainFrame loaded and initialized")
end

-- Create tab buttons
function UIManager:CreateTabs()
    local tabContainer = self.mainFrame.ParallelLootMainFrameTabContainer
    
    -- Active Items Tab
    local activeTab = CreateFrame("Button", "ParallelLootActiveTab", tabContainer)
    activeTab:SetSize(150, 30)
    activeTab:SetPoint("TOPLEFT", 0, 0)
    activeTab:SetNormalFontObject("GameFontNormal")
    activeTab:SetHighlightFontObject("GameFontHighlight")
    activeTab:SetText("Active Items")
    
    -- Tab background textures
    activeTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
    activeTab:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
    
    activeTab:SetScript("OnClick", function()
        pcall(function()
            UIManager:SwitchTab(UIManager.TABS.ACTIVE)
        end)
    end)
    
    -- Awarded Items Tab
    local awardedTab = CreateFrame("Button", "ParallelLootAwardedTab", tabContainer)
    awardedTab:SetSize(150, 30)
    awardedTab:SetPoint("LEFT", activeTab, "RIGHT", -15, 0)
    awardedTab:SetNormalFontObject("GameFontNormal")
    awardedTab:SetHighlightFontObject("GameFontHighlight")
    awardedTab:SetText("Awarded Items")
    
    awardedTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    awardedTab:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
    
    awardedTab:SetScript("OnClick", function()
        pcall(function()
            UIManager:SwitchTab(UIManager.TABS.AWARDED)
        end)
    end)
    
    self.tabs[self.TABS.ACTIVE] = activeTab
    self.tabs[self.TABS.AWARDED] = awardedTab
    
    -- Set initial tab state
    self:UpdateTabAppearance()
end

-- Switch between tabs
function UIManager:SwitchTab(tabIndex)
    if self.currentTab == tabIndex then
        return
    end
    
    self.currentTab = tabIndex
    self:UpdateTabAppearance()
    self:RefreshItemList()
    
    ParallelLoot:DebugPrint("Switched to tab:", tabIndex == self.TABS.ACTIVE and "Active" or "Awarded")
end

-- Update tab visual appearance
function UIManager:UpdateTabAppearance()
    for index, tab in pairs(self.tabs) do
        if index == self.currentTab then
            -- Active tab
            tab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
            tab:Disable()
        else
            -- Inactive tab
            tab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
            tab:Enable()
        end
    end
end

-- Handle frame resize
function UIManager:OnFrameResized()
    local width, height = self.mainFrame:GetSize()
    
    -- Adjust scroll frame size
    self.scrollFrame:SetSize(width - 40, height - 110)
    
    -- Adjust scroll child width
    self.scrollChild:SetWidth(width - 60)
    
    -- Refresh item panels to fit new width
    self:RefreshItemList()
    
    ParallelLoot:DebugPrint("Frame resized to:", width, "x", height)
end

-- Create loot master indicator
function UIManager:CreateLootMasterIndicator()
    if not self.mainFrame then
        return
    end
    
    -- Create indicator text
    local indicator = self.mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    indicator:SetPoint("TOP", self.mainFrame, "TOP", 0, -30)
    indicator:SetJustifyH("CENTER")
    
    self.lootMasterIndicator = indicator
    
    -- Update initial state
    self:UpdateLootMasterIndicator()
    
    -- Create settings button
    self:CreateSettingsButton()
end

-- Create settings button
function UIManager:CreateSettingsButton()
    if not self.mainFrame then
        return
    end
    
    local settingsButton = CreateFrame("Button", nil, self.mainFrame, "UIPanelButtonTemplate")
    settingsButton:SetSize(80, 24)
    settingsButton:SetPoint("TOPRIGHT", self.mainFrame.ParallelLootMainFrameCloseButton, "TOPLEFT", -5, 0)
    settingsButton:SetText("Settings")
    
    settingsButton:SetScript("OnClick", function()
        local success, err = pcall(function()
            UIManager:ToggleSettingsPanel()
        end)
        if not success then
            ParallelLoot:DebugPrint("Error opening settings:", err)
            ParallelLoot:Print("Settings panel temporarily unavailable")
        end
    end)
    
    self.settingsButton = settingsButton
    
    ParallelLoot:DebugPrint("Settings button created")
end

-- Update loot master indicator
function UIManager:UpdateLootMasterIndicator()
    if not self.lootMasterIndicator then
        return
    end
    
    local statusText = ParallelLoot.LootMasterManager:GetStatusText()
    self.lootMasterIndicator:SetText(statusText)
    
    -- Color based on loot master status
    if ParallelLoot.LootMasterManager:IsPlayerLootMaster() then
        self.lootMasterIndicator:SetTextColor(1, 0.82, 0, 1) -- Gold
    else
        self.lootMasterIndicator:SetTextColor(0.7, 0.7, 0.7, 1) -- Gray
    end
end

-- Callback when loot master changes
function UIManager:OnLootMasterChanged(oldMaster, newMaster)
    self:UpdateLootMasterIndicator()
    self:RefreshItemList()
    ParallelLoot:DebugPrint("UIManager: Loot master changed, UI updated")
end

-- Show main frame
function UIManager:OnMainFrameShow(frame)
    self:UpdateLootMasterIndicator()
    self:RefreshItemList()
    ParallelLoot:DebugPrint("MainFrame shown")
end

-- Hide main frame
function UIManager:OnMainFrameHide(frame)
    ParallelLoot:DebugPrint("MainFrame hidden")
end

-- Refresh the item list based on current tab (non-destructive)
function UIManager:RefreshItemList()
    -- Safety check for scroll child
    if not self.scrollChild then
        ParallelLoot:DebugPrint("RefreshItemList: scrollChild is nil, skipping refresh")
        return
    end
    
    -- Prevent recursive refreshes
    if self.refreshInProgress then
        ParallelLoot:DebugPrint("RefreshItemList: Refresh already in progress, skipping")
        return
    end
    
    self.refreshInProgress = true
    
    -- Validate panel states and recover if corrupted
    self:ValidateAndRecoverPanelStates()
    
    -- Get items based on current tab
    local items = {}
    if self.currentTab == self.TABS.ACTIVE then
        items = ParallelLoot.LootManager:GetActiveItems() or {}
    else
        items = ParallelLoot.LootManager:GetAwardedItems() or {}
    end
    
    -- Use non-destructive update approach
    local success = self:UpdateExistingPanels(items)
    
    if not success then
        ParallelLoot:DebugPrint("RefreshItemList: Non-destructive update failed, falling back to full refresh")
        self:PerformFullRefresh(items)
    end
    
    -- Clean up stale states after update
    self:CleanupPanelStates()
    
    -- Recalculate layout to ensure proper positioning
    self:RecalculateLayout()
    
    -- Validate positioning to ensure no overlaps
    self:ValidatePanelPositioning()
    
    -- Validate and fix panel dimensions
    self:ValidateAndFixPanelDimensions()
    
    self.refreshInProgress = false
    
    ParallelLoot:DebugPrint("Refreshed item list with", #items, "items (non-destructive)")
end

-- Non-destructive panel update method
function UIManager:UpdateExistingPanels(items)
    if not items then
        return false
    end
    
    -- Initialize active panels if not exists
    if not self.activeItemPanels then
        self.activeItemPanels = {}
    end
    
    -- Create lookup maps for efficient comparison
    local currentPanelMap = {}
    local newItemMap = {}
    
    -- Map current panels by item ID
    for i, panel in pairs(self.activeItemPanels) do
        if panel.lootItem and panel.lootItem.id then
            currentPanelMap[panel.lootItem.id] = {
                panel = panel,
                index = i
            }
        end
    end
    
    -- Map new items by ID
    for i, item in ipairs(items) do
        if item.id then
            newItemMap[item.id] = {
                item = item,
                index = i
            }
        end
    end
    
    -- Track panels to keep, update, add, and remove
    local panelsToKeep = {}
    local panelsToUpdate = {}
    local itemsToAdd = {}
    local panelsToRemove = {}
    
    -- Identify panels to keep and update
    for itemId, panelInfo in pairs(currentPanelMap) do
        if newItemMap[itemId] then
            -- Item still exists, keep panel and update data
            table.insert(panelsToKeep, panelInfo.panel)
            table.insert(panelsToUpdate, {
                panel = panelInfo.panel,
                item = newItemMap[itemId].item
            })
        else
            -- Item no longer exists, mark for removal
            table.insert(panelsToRemove, panelInfo.panel)
        end
    end
    
    -- Identify new items to add
    for itemId, itemInfo in pairs(newItemMap) do
        if not currentPanelMap[itemId] then
            table.insert(itemsToAdd, itemInfo.item)
        end
    end
    
    ParallelLoot:DebugPrint("RefreshItemList: Non-destructive update - Keep:", #panelsToKeep, 
        "Update:", #panelsToUpdate, "Add:", #itemsToAdd, "Remove:", #panelsToRemove)
    
    -- Preserve states for panels being updated
    self:PreservePanelStatesForUpdate(panelsToUpdate)
    
    -- Remove panels for items that no longer exist
    for _, panel in pairs(panelsToRemove) do
        self:RemovePanelSafely(panel)
    end
    
    -- Update existing panels with new data
    for _, updateInfo in pairs(panelsToUpdate) do
        local success = self:UpdateSinglePanel(updateInfo.panel, updateInfo.item)
        if not success then
            ParallelLoot:DebugPrint("RefreshItemList: Failed to update panel for item", updateInfo.item.id)
            return false
        end
    end
    
    -- Add new panels for new items
    local newPanels = {}
    for _, item in pairs(itemsToAdd) do
        local success, panel = pcall(function()
            return self:CreateItemPanel(self.scrollChild, item)
        end)
        
        if success and panel then
            table.insert(newPanels, panel)
        else
            ParallelLoot:DebugPrint("RefreshItemList: Failed to create panel for new item", item.id)
            return false
        end
    end
    
    -- Rebuild active panels list in correct order
    self:RebuildActivePanelsList(items, panelsToKeep, newPanels)
    
    -- Restore states for updated panels
    self:RestorePanelStatesAfterUpdate()
    
    return true
end

-- Preserve panel states specifically for panels being updated
function UIManager:PreservePanelStatesForUpdate(panelsToUpdate)
    if not panelsToUpdate then
        return
    end
    
    for _, updateInfo in pairs(panelsToUpdate) do
        local panel = updateInfo.panel
        local item = updateInfo.item
        
        if panel and item and item.id then
            if not self.panelStates[item.id] then
                self.panelStates[item.id] = {}
            end
            
            self.panelStates[item.id].isExpanded = panel.isExpanded or false
            self.panelStates[item.id].lastUpdate = time()
            
            ParallelLoot:DebugPrint("UIManager: Preserved state for updating panel", item.id, 
                "expanded:", panel.isExpanded)
        end
    end
end

-- Restore panel states after non-destructive update
function UIManager:RestorePanelStatesAfterUpdate()
    if not self.activeItemPanels then
        return
    end
    
    for _, panel in pairs(self.activeItemPanels) do
        if panel.lootItem and panel.lootItem.id then
            local savedState = self.panelStates[panel.lootItem.id]
            if savedState then
                -- Only restore if state differs from current
                if savedState.isExpanded ~= panel.isExpanded then
                    if savedState.isExpanded then
                        -- Expand panel without triggering full refresh
                        self:ToggleItemPanelExpandedInternal(panel, true)
                    else
                        -- Collapse panel without triggering full refresh
                        self:ToggleItemPanelExpandedInternal(panel, true)
                    end
                    
                    ParallelLoot:DebugPrint("UIManager: Restored state for panel", panel.lootItem.id, 
                        "expanded:", savedState.isExpanded)
                end
            end
        end
    end
end

-- Safely remove a panel from the UI
function UIManager:RemovePanelSafely(panel)
    if not panel then
        return
    end
    
    -- Clear panel state if it exists
    if panel.lootItem and panel.lootItem.id then
        self.panelStates[panel.lootItem.id] = nil
    end
    
    -- Remove from active panels list
    for i, activePanel in pairs(self.activeItemPanels) do
        if activePanel == panel then
            table.remove(self.activeItemPanels, i)
            break
        end
    end
    
    -- Release panel back to pool
    self:ReleaseItemPanel(panel)
    
    ParallelLoot:DebugPrint("UIManager: Safely removed panel")
end

-- Rebuild the active panels list in the correct order
function UIManager:RebuildActivePanelsList(items, existingPanels, newPanels)
    if not items then
        return
    end
    
    -- Create new active panels list
    local newActivePanels = {}
    local existingPanelMap = {}
    local newPanelIndex = 1
    
    -- Map existing panels by item ID
    for _, panel in pairs(existingPanels) do
        if panel.lootItem and panel.lootItem.id then
            existingPanelMap[panel.lootItem.id] = panel
        end
    end
    
    -- Build new list in item order
    for _, item in ipairs(items) do
        if item.id then
            local panel = existingPanelMap[item.id]
            if panel then
                -- Use existing panel
                table.insert(newActivePanels, panel)
            else
                -- Use new panel
                if newPanels[newPanelIndex] then
                    table.insert(newActivePanels, newPanels[newPanelIndex])
                    newPanelIndex = newPanelIndex + 1
                end
            end
        end
    end
    
    -- Update active panels list
    self.activeItemPanels = newActivePanels
    
    ParallelLoot:DebugPrint("UIManager: Rebuilt active panels list with", #newActivePanels, "panels")
end

-- Fallback to full refresh if non-destructive update fails
function UIManager:PerformFullRefresh(items)
    ParallelLoot:DebugPrint("UIManager: Performing full refresh fallback")
    
    -- Preserve panel states before destruction
    self:PreservePanelStates()
    
    -- Release existing panels back to pool
    if self.activeItemPanels then
        for _, panel in pairs(self.activeItemPanels) do
            self:ReleaseItemPanel(panel)
        end
    end
    self.activeItemPanels = {}
    
    -- Create item panels
    for i, item in ipairs(items) do
        local success, panel = pcall(function()
            return self:CreateItemPanel(self.scrollChild, item)
        end)
        
        if success and panel then
            table.insert(self.activeItemPanels, panel)
        else
            ParallelLoot:DebugPrint("Failed to create item panel for item:", item.id or "unknown")
        end
    end
    
    -- Restore panel states after creation
    self:RestorePanelStates()
    
    ParallelLoot:DebugPrint("UIManager: Full refresh completed with", #items, "items")
end

-- Recalculate panel positions and scroll child height
function UIManager:RecalculateLayout()
    if not self.activeItemPanels or not self.scrollChild then
        ParallelLoot:DebugPrint("UIManager: Cannot recalculate layout - missing panels or scroll child")
        return
    end
    
    -- Prevent recursive layout calculations
    if self.layoutCalculating then
        ParallelLoot:DebugPrint("UIManager: Layout calculation already in progress, skipping")
        return
    end
    
    self.layoutCalculating = true
    
    ParallelLoot:DebugPrint("UIManager: Recalculating layout for", #self.activeItemPanels, "panels")
    
    -- Clear all existing points to prevent conflicts
    for _, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            panel:ClearAllPoints()
        end
    end
    
    -- Recalculate positions with proper spacing and overlap prevention
    local yOffset = -10 -- Start with 10px margin from top
    local panelSpacing = 10 -- Space between panels
    local positions = {} -- Track positions for debugging
    
    for i, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            -- Set position
            panel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, yOffset)
            
            -- Get actual panel height with validation and dimension fixing
            local panelHeight = panel:GetHeight()
            if not panelHeight or panelHeight <= 0 or panelHeight ~= panelHeight then -- NaN check
                -- Calculate proper height based on panel state
                if panel.isExpanded then
                    local expandedHeight = self:CalculateExpandedHeight(panel)
                    panelHeight = 80 + expandedHeight
                else
                    panelHeight = 80
                end
                
                -- Apply corrected dimensions
                self:SetPanelDimensions(panel, 640, panelHeight)
                ParallelLoot:DebugPrint("UIManager: Fixed invalid height for panel", i, "set to", panelHeight)
            end
            
            -- Ensure panel width is correct
            local panelWidth = panel:GetWidth()
            if not panelWidth or panelWidth <= 0 or panelWidth ~= panelWidth then
                self:SetPanelDimensions(panel, 640, panelHeight)
                ParallelLoot:DebugPrint("UIManager: Fixed invalid width for panel", i)
            end
            
            -- Store position info for debugging
            positions[i] = {
                yOffset = yOffset,
                height = panelHeight,
                expanded = panel.isExpanded or false,
                itemId = panel.lootItem and panel.lootItem.id or "unknown"
            }
            
            -- Calculate next position
            yOffset = yOffset - panelHeight - panelSpacing
        end
    end
    
    -- Update scroll child height with proper bounds
    local totalContentHeight = math.abs(yOffset) + 10 -- Add bottom margin
    totalContentHeight = math.max(totalContentHeight, 100) -- Minimum height
    
    -- Get scroll frame height to determine if scrolling is needed
    local scrollFrameHeight = self.scrollFrame:GetHeight() or 400
    local finalHeight = math.max(totalContentHeight, scrollFrameHeight)
    
    self.scrollChild:SetHeight(finalHeight)
    
    -- Ensure proper frame levels after layout changes
    self:EnsureProperFrameLevels()
    
    -- Update layout state tracking
    self.layoutDirty = false
    self.lastLayoutUpdate = time()
    
    self.layoutCalculating = false
    
    ParallelLoot:DebugPrint("UIManager: Layout recalculated - Total height:", finalHeight, 
        "Content height:", totalContentHeight, "Panels positioned:", #positions)
    
    -- Debug position information
    for i, pos in pairs(positions) do
        ParallelLoot:DebugPrint("  Panel", i, "- Item:", pos.itemId, "Y:", pos.yOffset, 
            "Height:", pos.height, "Expanded:", pos.expanded)
    end
end

-- Update panel positions when heights change (called after expand/collapse)
function UIManager:UpdatePanelPositions()
    -- Mark layout as dirty and trigger recalculation
    self.layoutDirty = true
    
    -- Use event system for responsive updates
    if self.TriggerLayoutUpdate then
        self:TriggerLayoutUpdate()
    else
        -- Fallback for immediate execution
        self:RecalculateLayout()
    end
end

-- Validate panel positioning and fix overlaps
function UIManager:ValidatePanelPositioning()
    if not self.activeItemPanels or #self.activeItemPanels == 0 then
        return true
    end
    
    local hasOverlap = false
    local positions = {}
    
    -- Collect current positions
    for i, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            local _, _, _, _, yPos = panel:GetPoint(1)
            local height = panel:GetHeight() or 80
            positions[i] = {
                panel = panel,
                yPos = yPos or 0,
                height = height,
                bottom = (yPos or 0) - height
            }
        end
    end
    
    -- Check for overlaps
    for i = 1, #positions - 1 do
        local current = positions[i]
        local next = positions[i + 1]
        
        if current and next then
            -- Check if current panel's bottom overlaps with next panel's top
            if current.bottom > next.yPos then
                hasOverlap = true
                ParallelLoot:DebugPrint("UIManager: Overlap detected between panels", i, "and", i + 1)
                break
            end
        end
    end
    
    -- Fix overlaps by triggering layout recalculation
    if hasOverlap then
        ParallelLoot:DebugPrint("UIManager: Fixing panel overlaps")
        self:RecalculateLayout()
        return false
    end
    
    return true
end

-- Get the total height needed for all panels
function UIManager:CalculateTotalPanelHeight()
    if not self.activeItemPanels then
        return 100
    end
    
    local totalHeight = 20 -- Top and bottom margins
    local panelSpacing = 10
    
    for _, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            local panelHeight = panel:GetHeight() or 80
            totalHeight = totalHeight + panelHeight + panelSpacing
        end
    end
    
    return totalHeight
end

ParallelLoot:DebugPrint("MainFrame.lua loaded")
