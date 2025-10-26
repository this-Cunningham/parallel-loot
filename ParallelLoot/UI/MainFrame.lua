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

-- Refresh the item list based on current tab
function UIManager:RefreshItemList()
    -- Safety check for scroll child
    if not self.scrollChild then
        ParallelLoot:DebugPrint("RefreshItemList: scrollChild is nil, skipping refresh")
        return
    end
    
    -- Store expanded state of panels before refresh
    local expandedStates = {}
    for _, panel in pairs(self.activeItemPanels) do
        if panel.lootItem then
            expandedStates[panel.lootItem.id] = panel.isExpanded
        end
    end
    
    -- Release existing panels back to pool
    for _, panel in pairs(self.activeItemPanels) do
        self:ReleaseItemPanel(panel)
    end
    self.activeItemPanels = {}
    
    -- Get items based on current tab
    local items = {}
    if self.currentTab == self.TABS.ACTIVE then
        items = ParallelLoot.LootManager:GetActiveItems() or {}
    else
        items = ParallelLoot.LootManager:GetAwardedItems() or {}
    end
    
    -- Create item panels
    local yOffset = -10
    for i, item in ipairs(items) do
        -- Safety check for CreateItemPanel
        local success, panel = pcall(function()
            return self:CreateItemPanel(self.scrollChild, item)
        end)
        
        if success and panel then
            panel:SetPoint("TOPLEFT", 0, yOffset)
            
            -- Restore expanded state if it was expanded before
            if expandedStates[item.id] then
                pcall(function()
                    self:ToggleItemPanelExpanded(panel)
                end)
            end
            
            table.insert(self.activeItemPanels, panel)
            
            -- Adjust offset based on panel height
            local panelHeight = panel:GetHeight() or 50 -- Default height if GetHeight fails
            yOffset = yOffset - panelHeight - 10 -- 10px spacing between panels
        else
            ParallelLoot:DebugPrint("Failed to create item panel for item:", item.id or "unknown")
        end
    end
    
    -- Update scroll child height
    local totalHeight = math.max(1, math.abs(yOffset) + 10)
    if self.scrollChild then
        self.scrollChild:SetHeight(totalHeight)
    end
    
    ParallelLoot:DebugPrint("Refreshed item list with", #items, "items")
end

ParallelLoot:DebugPrint("MainFrame.lua loaded")
