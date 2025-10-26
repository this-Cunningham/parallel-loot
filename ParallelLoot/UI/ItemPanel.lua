-- ParallelLoot Item Panel
-- Individual collapsible panels for each loot item

local UIManager = ParallelLoot.UIManager

-- Item panel pool for reuse
UIManager.itemPanelPool = {}
UIManager.activeItemPanels = {}

-- Z-order management constants
UIManager.FRAME_LEVELS = {
    BASE_PANEL = 1,
    PANEL_BACKGROUND = 2,
    PANEL_CONTENT = 3,
    PANEL_OVERLAY = 4,
    EXPANDED_CONTENT = 5,
    BUTTONS = 6,
    TOOLTIPS = 7
}

-- Create a new item panel
function UIManager:CreateItemPanel(parent, lootItem)
    -- Try to reuse from pool
    local panel = table.remove(self.itemPanelPool)
    
    if not panel then
        -- Create new panel
        panel = CreateFrame("Frame", nil, parent)
        panel:SetSize(640, 80) -- Default collapsed height
        
        -- Set initial frame level for proper layering
        panel:SetFrameLevel(UIManager.FRAME_LEVELS.BASE_PANEL)
        
        -- Background with proper layering
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints()
        panel.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        panel.bg:SetDrawLayer("BACKGROUND", UIManager.FRAME_LEVELS.PANEL_BACKGROUND)
        
        -- Border with proper layering
        panel.border = panel:CreateTexture(nil, "BORDER")
        panel.border:SetAllPoints()
        panel.border:SetColorTexture(0.3, 0.3, 0.3, 1)
        panel.border:SetDrawLayer("BORDER", UIManager.FRAME_LEVELS.PANEL_BACKGROUND + 1)
        
        -- Inner background (inset from border) with proper layering
        panel.innerBg = panel:CreateTexture(nil, "BACKGROUND")
        panel.innerBg:SetPoint("TOPLEFT", 2, -2)
        panel.innerBg:SetPoint("BOTTOMRIGHT", -2, 2)
        panel.innerBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        panel.innerBg:SetDrawLayer("BACKGROUND", UIManager.FRAME_LEVELS.PANEL_BACKGROUND + 2)
        
        -- Item icon with proper layering
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(36, 36)
        panel.icon:SetPoint("TOPLEFT", 8, -8)
        panel.icon:SetDrawLayer("ARTWORK", UIManager.FRAME_LEVELS.PANEL_CONTENT)
        
        -- Icon border with proper layering
        panel.iconBorder = panel:CreateTexture(nil, "OVERLAY")
        panel.iconBorder:SetSize(40, 40)
        panel.iconBorder:SetPoint("CENTER", panel.icon, "CENTER")
        panel.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        panel.iconBorder:SetBlendMode("ADD")
        panel.iconBorder:SetDrawLayer("OVERLAY", UIManager.FRAME_LEVELS.PANEL_OVERLAY)
        
        -- Item name with proper layering
        panel.itemName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        panel.itemName:SetPoint("LEFT", panel.icon, "RIGHT", 8, 8)
        panel.itemName:SetJustifyH("LEFT")
        panel.itemName:SetDrawLayer("OVERLAY", UIManager.FRAME_LEVELS.PANEL_CONTENT)
        
        -- Subtitle text with proper layering
        panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.subtitle:SetPoint("TOPLEFT", panel.itemName, "BOTTOMLEFT", 0, -2)
        panel.subtitle:SetText("Loot Roll Details")
        panel.subtitle:SetTextColor(0.7, 0.7, 0.7, 1)
        panel.subtitle:SetDrawLayer("OVERLAY", UIManager.FRAME_LEVELS.PANEL_CONTENT)
        
        -- Progress bar background with proper layering
        panel.progressBg = panel:CreateTexture(nil, "BACKGROUND")
        panel.progressBg:SetSize(620, 12)
        panel.progressBg:SetPoint("TOPLEFT", 8, -52)
        panel.progressBg:SetColorTexture(0.2, 0.2, 0.2, 1)
        panel.progressBg:SetDrawLayer("BACKGROUND", UIManager.FRAME_LEVELS.PANEL_CONTENT)
        
        -- Progress bar with proper layering
        panel.progressBar = panel:CreateTexture(nil, "ARTWORK")
        panel.progressBar:SetSize(620, 12)
        panel.progressBar:SetPoint("TOPLEFT", panel.progressBg, "TOPLEFT")
        panel.progressBar:SetColorTexture(1, 0.5, 0, 1) -- Orange color
        panel.progressBar:SetGradient("HORIZONTAL", 
            CreateColor(1, 0.6, 0, 1), 
            CreateColor(1, 0.4, 0, 1))
        panel.progressBar:SetDrawLayer("ARTWORK", UIManager.FRAME_LEVELS.PANEL_CONTENT + 1)
        
        -- Timer text with proper layering
        panel.timerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel.timerText:SetPoint("TOPLEFT", panel.progressBg, "BOTTOMLEFT", 0, -2)
        panel.timerText:SetTextColor(1, 1, 1, 1)
        panel.timerText:SetDrawLayer("OVERLAY", UIManager.FRAME_LEVELS.PANEL_CONTENT)
        
        -- Expand/collapse button with proper layering
        panel.expandButton = CreateFrame("Button", nil, panel)
        panel.expandButton:SetSize(20, 20)
        panel.expandButton:SetPoint("TOPRIGHT", -8, -8)
        panel.expandButton:SetFrameLevel(UIManager.FRAME_LEVELS.BUTTONS)
        
        -- Expand button textures with proper layering
        panel.expandButton.arrow = panel.expandButton:CreateTexture(nil, "ARTWORK")
        panel.expandButton.arrow:SetAllPoints()
        panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        panel.expandButton.arrow:SetDrawLayer("ARTWORK", UIManager.FRAME_LEVELS.BUTTONS)
        
        panel.expandButton:SetScript("OnClick", function()
            UIManager:ToggleItemPanelExpanded(panel)
        end)
        
        panel.expandButton:SetScript("OnEnter", function(self)
            self.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        end)
        
        panel.expandButton:SetScript("OnLeave", function(self)
            if panel.isExpanded then
                self.arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            else
                self.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            end
        end)
        
        -- Award button (for loot master only) with proper layering
        panel.awardButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.awardButton:SetSize(80, 24)
        panel.awardButton:SetPoint("TOPRIGHT", panel.expandButton, "TOPLEFT", -10, -2)
        panel.awardButton:SetText("Award")
        panel.awardButton:SetFrameLevel(UIManager.FRAME_LEVELS.BUTTONS)
        panel.awardButton:Hide() -- Hidden by default, shown for loot master
        
        panel.awardButton:SetScript("OnClick", function()
            UIManager:OnAwardButtonClicked(panel)
        end)
        
        -- Revoke Award button (for loot master on awarded items) with proper layering
        panel.revokeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.revokeButton:SetSize(100, 24)
        panel.revokeButton:SetPoint("TOPRIGHT", panel.expandButton, "TOPLEFT", -10, -2)
        panel.revokeButton:SetText("Revoke Award")
        panel.revokeButton:SetFrameLevel(UIManager.FRAME_LEVELS.BUTTONS)
        panel.revokeButton:Hide() -- Hidden by default, shown for loot master on awarded items
        
        panel.revokeButton:SetScript("OnClick", function()
            UIManager:OnRevokeButtonClicked(panel)
        end)
        
        -- Category buttons container (will be populated in sub-task 5.3) with proper layering
        panel.categoryContainer = CreateFrame("Frame", nil, panel)
        panel.categoryContainer:SetSize(400, 30)
        panel.categoryContainer:SetPoint("TOPRIGHT", panel.awardButton, "TOPLEFT", -10, 0)
        panel.categoryContainer:SetFrameLevel(UIManager.FRAME_LEVELS.BUTTONS)
        
        -- Expanded content frame (hidden by default) with proper layering
        panel.expandedContent = CreateFrame("Frame", nil, panel)
        panel.expandedContent:SetPoint("TOPLEFT", 8, -75)
        panel.expandedContent:SetPoint("TOPRIGHT", -8, -75)
        panel.expandedContent:SetHeight(1)
        panel.expandedContent:SetFrameLevel(UIManager.FRAME_LEVELS.EXPANDED_CONTENT)
        panel.expandedContent:Hide()
        
        -- State
        panel.isExpanded = false
        panel.lootItem = nil
    end
    
    -- Reset panel state
    panel:SetParent(parent)
    panel:Show()
    panel.isExpanded = false
    panel.expandedContent:Hide()
    panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    
    -- Ensure proper frame level for reused panel
    panel:SetFrameLevel(UIManager.FRAME_LEVELS.BASE_PANEL)
    
    -- Update panel with loot item data
    self:UpdateItemPanel(panel, lootItem)
    
    return panel
end

-- Update item panel with loot item data
function UIManager:UpdateItemPanel(panel, lootItem)
    panel.lootItem = lootItem
    
    -- Set item icon
    if lootItem.icon then
        panel.icon:SetTexture(lootItem.icon)
    end
    
    -- Set item name with quality color
    local r, g, b = ParallelLoot.LootManager:GetQualityColor(lootItem.quality)
    panel.itemName:SetText(lootItem.itemLink or lootItem.itemName)
    panel.itemName:SetTextColor(r, g, b, 1)
    
    -- Set icon border color
    panel.iconBorder:SetVertexColor(r, g, b, 1)
    
    -- Update timer
    self:UpdateItemPanelTimer(panel)
    
    -- Create and update category buttons
    self:CreateCategoryButtons(panel)
    self:UpdateCategoryButtons(panel)
    
    -- Update award button visibility
    self:UpdateAwardButton(panel)
end

-- Update award button visibility and state
function UIManager:UpdateAwardButton(panel)
    if not panel.awardButton or not panel.revokeButton then
        return
    end
    
    local isLootMaster = ParallelLoot.LootMasterManager:IsPlayerLootMaster()
    local isAwarded = panel.lootItem and panel.lootItem.awardedTo
    local isActiveTab = self.currentTab == self.TABS.ACTIVE
    local isAwardedTab = self.currentTab == self.TABS.AWARDED
    
    -- Show award button only for loot master on active items
    if isLootMaster and isActiveTab and not isAwarded then
        panel.awardButton:Show()
        panel.revokeButton:Hide()
        
        -- Enable/disable based on whether there are rolls
        local hasRolls = panel.lootItem and panel.lootItem.rolls and #panel.lootItem.rolls > 0
        if hasRolls then
            panel.awardButton:Enable()
        else
            panel.awardButton:Disable()
        end
    -- Show revoke button only for loot master on awarded items (if not expired)
    elseif isLootMaster and isAwardedTab and isAwarded then
        panel.awardButton:Hide()
        
        -- Check if item is expired
        local isExpired = ParallelLoot.DataManager.LootItem:IsExpired(panel.lootItem)
        if not isExpired then
            panel.revokeButton:Show()
            panel.revokeButton:Enable()
        else
            panel.revokeButton:Hide()
        end
    else
        panel.awardButton:Hide()
        panel.revokeButton:Hide()
    end
end

-- Update item panel timer display
function UIManager:UpdateItemPanelTimer(panel)
    if not panel.lootItem then
        return
    end
    
    local item = panel.lootItem
    
    -- Check if item is awarded
    if item.awardedTo then
        -- Show awarded info instead of timer
        local currentTime = time()
        local timeSinceAward = currentTime - (item.awardTime or currentTime)
        
        -- Update subtitle to show awarded status
        panel.subtitle:SetText(string.format("Awarded to %s", item.awardedTo))
        panel.subtitle:SetTextColor(0, 1, 0, 1) -- Green for awarded
        
        panel.timerText:SetText(ParallelLoot.TimerManager:GetTimerDisplayText(item))
        panel.timerText:SetTextColor(0.7, 0.7, 0.7, 1) -- Gray
        
        -- Hide progress bar for awarded items
        panel.progressBar:Hide()
        panel.progressBg:Hide()
        
        return
    end
    
    -- Reset subtitle for active items
    panel.subtitle:SetText("Loot Roll Details")
    panel.subtitle:SetTextColor(0.7, 0.7, 0.7, 1)
    
    -- Show progress bar
    panel.progressBar:Show()
    panel.progressBg:Show()
    
    -- Get time remaining from TimerManager
    local timeRemaining = ParallelLoot.TimerManager:GetTimeRemaining(item)
    
    if timeRemaining <= 0 then
        panel.timerText:SetText("Expired")
        panel.progressBar:SetWidth(0)
        panel.timerText:SetTextColor(1, 0, 0, 1) -- Red
        return
    end
    
    -- Get progress percentage from TimerManager
    local progress = ParallelLoot.TimerManager:GetProgressPercentage(item)
    
    -- Update progress bar width
    local maxWidth = 620
    panel.progressBar:SetWidth(maxWidth * progress)
    
    -- Update progress bar color based on time remaining
    local color1, color2 = ParallelLoot.TimerManager:GetProgressBarColor(timeRemaining)
    panel.progressBar:SetGradient("HORIZONTAL", color1, color2)
    
    -- Get timer display text
    panel.timerText:SetText(ParallelLoot.TimerManager:GetTimerDisplayText(item))
    
    -- Get timer color based on time remaining
    local r, g, b, a = ParallelLoot.TimerManager:GetTimerColor(timeRemaining)
    panel.timerText:SetTextColor(r, g, b, a)
end

-- Toggle item panel expanded state
function UIManager:ToggleItemPanelExpanded(panel)
    if not panel or not panel.lootItem then
        ParallelLoot:DebugPrint("UIManager: Cannot toggle panel - invalid panel or missing loot item")
        return
    end
    
    -- Prevent toggle during refresh operations
    if self.refreshInProgress then
        ParallelLoot:DebugPrint("UIManager: Skipping toggle during refresh")
        return
    end
    
    local wasExpanded = panel.isExpanded
    
    -- Perform the toggle with immediate visual updates
    self:ToggleItemPanelExpandedInternal(panel, false)
    
    -- Ensure proper resize occurred
    local newState = panel.isExpanded and "expanded" or "collapsed"
    local resizeSuccess = self:EnsurePanelResize(panel, newState)
    
    if not resizeSuccess then
        ParallelLoot:DebugPrint("UIManager: Panel resize failed, attempting recovery")
        self:FixRollListDisplayIssues(panel)
    end
    
    -- Ensure visual state is consistent
    self:EnsurePanelVisualState(panel)
    
    -- Update panel state tracking with validation
    if panel.lootItem.id then
        if not self.panelStates then
            self.panelStates = {}
        end
        if not self.panelStates[panel.lootItem.id] then
            self.panelStates[panel.lootItem.id] = {}
        end
        
        self.panelStates[panel.lootItem.id].isExpanded = panel.isExpanded
        self.panelStates[panel.lootItem.id].lastUpdate = time()
        self.panelStates[panel.lootItem.id].height = panel:GetHeight()
        
        ParallelLoot:DebugPrint("UIManager: Updated panel state for item", panel.lootItem.id, 
            "expanded:", panel.isExpanded, "height:", panel:GetHeight())
    end
    
    -- Trigger immediate layout recalculation
    self:RecalculateLayout()
    
    -- Fix any visual overlap issues that may have occurred
    self:FixVisualOverlapIssues()
    
    -- Log the state change
    local stateChange = wasExpanded and "collapsed" or "expanded"
    ParallelLoot:DebugPrint("UIManager: Panel", stateChange, "for item", panel.lootItem.id or "unknown")
end

-- Internal toggle method that doesn't trigger full refresh (used during state restoration)
function UIManager:ToggleItemPanelExpandedInternal(panel, skipStateUpdate)
    if not panel then
        return
    end
    
    local wasExpanded = panel.isExpanded
    panel.isExpanded = not panel.isExpanded
    
    if panel.isExpanded then
        -- Expand panel
        self:ExpandPanel(panel)
    else
        -- Collapse panel
        self:CollapsePanel(panel)
    end
    
    -- Update state tracking if not skipping
    if not skipStateUpdate and panel.lootItem and panel.lootItem.id then
        if not self.panelStates then
            self.panelStates = {}
        end
        if not self.panelStates[panel.lootItem.id] then
            self.panelStates[panel.lootItem.id] = {}
        end
        
        self.panelStates[panel.lootItem.id].isExpanded = panel.isExpanded
        self.panelStates[panel.lootItem.id].lastUpdate = time()
        self.panelStates[panel.lootItem.id].height = panel:GetHeight()
    end
end

-- Expand a panel with proper height calculation
function UIManager:ExpandPanel(panel)
    if not panel or not panel.expandButton or not panel.expandedContent then
        return
    end
    
    -- Update expand button visual immediately
    panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
    
    -- Show expanded content immediately
    panel.expandedContent:Show()
    
    -- Update expanded content with current data
    self:UpdateExpandedContent(panel)
    
    -- Calculate proper expanded height based on content
    local expandedHeight = self:CalculateExpandedHeight(panel)
    local totalHeight = 80 + expandedHeight -- Base height + expanded content
    
    -- Apply height changes immediately with validation
    self:SetPanelDimensions(panel, 640, totalHeight)
    panel.expandedContent:SetHeight(expandedHeight)
    
    -- Update visual boundaries immediately
    self:UpdatePanelVisualBoundaries(panel)
    
    -- Ensure proper frame levels for expanded state
    self:UpdatePanelChildFrameLevels(panel, panel:GetFrameLevel())
    
    ParallelLoot:DebugPrint("UIManager: Panel expanded for item", 
        panel.lootItem and panel.lootItem.id or "unknown", "height:", totalHeight)
end

-- Collapse a panel with immediate visual updates
function UIManager:CollapsePanel(panel)
    if not panel or not panel.expandButton or not panel.expandedContent then
        return
    end
    
    -- Update expand button visual immediately
    panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    
    -- Hide expanded content immediately and ensure it's properly hidden
    panel.expandedContent:Hide()
    self:EnsureExpandedContentHidden(panel)
    
    -- Reset to collapsed height with validation
    self:SetPanelDimensions(panel, 640, 80)
    
    -- Update visual boundaries immediately
    self:UpdatePanelVisualBoundaries(panel)
    
    -- Ensure proper frame levels for collapsed state
    self:UpdatePanelChildFrameLevels(panel, panel:GetFrameLevel())
    
    ParallelLoot:DebugPrint("UIManager: Panel collapsed for item", 
        panel.lootItem and panel.lootItem.id or "unknown")
end

-- Calculate the proper height for expanded content
function UIManager:CalculateExpandedHeight(panel)
    if not panel or not panel.lootItem then
        return 200 -- Default fallback
    end
    
    -- Base height for expanded content (category buttons, spacing)
    local baseHeight = 60 -- Space for category buttons and padding
    
    -- Add height for roll lists if they exist
    local rollHeight = 0
    if panel.lootItem.rolls and #panel.lootItem.rolls > 0 then
        -- Calculate height based on number of rolls and categories
        local rollCount = #panel.lootItem.rolls
        
        -- Group rolls by category to calculate category sections
        local categories = {}
        for _, roll in ipairs(panel.lootItem.rolls) do
            if not categories[roll.category] then
                categories[roll.category] = 0
            end
            categories[roll.category] = categories[roll.category] + 1
        end
        
        -- Calculate height: category header (20px) + rolls (16px each) + spacing (4px)
        for category, count in pairs(categories) do
            rollHeight = rollHeight + 20 + (count * 16) + 4
        end
        
        -- Cap at reasonable maximum to prevent excessive height
        rollHeight = math.min(rollHeight, 200)
    else
        -- Add some height for "No rolls yet" message
        rollHeight = 30
    end
    
    local totalHeight = baseHeight + rollHeight
    
    -- Ensure minimum and maximum bounds with better validation
    totalHeight = math.max(totalHeight, 120) -- Minimum expanded height
    totalHeight = math.min(totalHeight, 350) -- Maximum expanded height
    
    -- Validate the calculated height
    if totalHeight <= 0 or totalHeight ~= totalHeight then -- NaN check
        ParallelLoot:DebugPrint("UIManager: Invalid height calculated, using fallback")
        totalHeight = 200
    end
    
    ParallelLoot:DebugPrint("UIManager: Calculated expanded height:", totalHeight, 
        "for", panel.lootItem.rolls and #panel.lootItem.rolls or 0, "rolls in", 
        panel.lootItem.rolls and self:CountRollCategories(panel.lootItem.rolls) or 0, "categories")
    
    return totalHeight
end

-- Count unique roll categories for height calculation
function UIManager:CountRollCategories(rolls)
    if not rolls then
        return 0
    end
    
    local categories = {}
    for _, roll in ipairs(rolls) do
        categories[roll.category] = true
    end
    
    local count = 0
    for _ in pairs(categories) do
        count = count + 1
    end
    
    return count
end

-- Ensure panel visual state is consistent with internal state
function UIManager:EnsurePanelVisualState(panel)
    if not panel or not panel.expandButton then
        return
    end
    
    -- Ensure button texture matches state
    if panel.isExpanded then
        panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
        if panel.expandedContent then
            panel.expandedContent:Show()
        end
    else
        panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        if panel.expandedContent then
            panel.expandedContent:Hide()
            self:EnsureExpandedContentHidden(panel)
        end
    end
    
    -- Ensure height matches state with proper dimension validation
    if panel.isExpanded then
        local expandedHeight = self:CalculateExpandedHeight(panel)
        local totalHeight = 80 + expandedHeight
        self:SetPanelDimensions(panel, 640, totalHeight)
        if panel.expandedContent then
            panel.expandedContent:SetHeight(expandedHeight)
        end
    else
        self:SetPanelDimensions(panel, 640, 80)
    end
    
    -- Update visual boundaries
    self:UpdatePanelVisualBoundaries(panel)
end

-- Set panel dimensions with validation and immediate visual updates
function UIManager:SetPanelDimensions(panel, width, height)
    if not panel then
        return
    end
    
    -- Validate dimensions
    width = math.max(width or 640, 100) -- Minimum width
    height = math.max(height or 80, 80) -- Minimum height
    
    -- Apply dimensions immediately
    panel:SetSize(width, height)
    
    -- Force immediate visual update
    panel:SetScript("OnSizeChanged", function(self, width, height)
        -- Trigger visual boundary update when size changes
        UIManager:UpdatePanelVisualBoundaries(self)
    end)
    
    ParallelLoot:DebugPrint("UIManager: Set panel dimensions to", width, "x", height)
end

-- Update visual boundaries immediately when panel state changes
function UIManager:UpdatePanelVisualBoundaries(panel)
    if not panel then
        return
    end
    
    -- Update background textures to match new dimensions
    if panel.bg then
        panel.bg:SetAllPoints(panel)
    end
    if panel.border then
        panel.border:SetAllPoints(panel)
    end
    if panel.innerBg then
        panel.innerBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
        panel.innerBg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    end
    
    -- Update expanded content positioning if visible
    if panel.expandedContent and panel.expandedContent:IsShown() then
        panel.expandedContent:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -75)
        panel.expandedContent:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -75)
    end
    
    ParallelLoot:DebugPrint("UIManager: Updated visual boundaries for panel")
end

-- Ensure expanded content is properly hidden and doesn't display remnant elements
function UIManager:EnsureExpandedContentHidden(panel)
    if not panel or not panel.expandedContent then
        return
    end
    
    -- Hide the expanded content frame
    panel.expandedContent:Hide()
    
    -- Only hide placeholder elements, not the roll display components
    if panel.expandedContent.placeholder then
        panel.expandedContent.placeholder:Hide()
    end
    
    -- Reset expanded content height to prevent visual artifacts
    panel.expandedContent:SetHeight(1)
    
    ParallelLoot:DebugPrint("UIManager: Ensured expanded content is properly hidden")
end

-- Update expanded content with roll display
function UIManager:UpdateExpandedContent(panel)
    -- Create roll display if it doesn't exist
    if not panel.rollDisplay then
        self:CreateRollDisplay(panel)
    end
    
    -- Ensure roll display is visible when expanding
    self:EnsureRollDisplayVisible(panel)
    
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

-- Ensure roll display elements are visible when panel is expanded
function UIManager:EnsureRollDisplayVisible(panel)
    if not panel or not panel.rollDisplay then
        return
    end
    
    -- Show the container
    if panel.rollDisplay.container then
        panel.rollDisplay.container:Show()
    end
    
    -- Show all category columns
    for categoryKey, column in pairs(panel.rollDisplay) do
        if categoryKey ~= "container" and column.Show then
            column:Show()
            
            -- Show column elements
            if column.header then column.header:Show() end
            if column.bg then column.bg:Show() end
            if column.border then column.border:Show() end
            if column.innerBg then column.innerBg:Show() end
            if column.scrollFrame then column.scrollFrame:Show() end
            if column.scrollChild then column.scrollChild:Show() end
            
            -- Show roll entries
            if column.rollEntries then
                for _, entry in ipairs(column.rollEntries) do
                    if entry.Show then
                        entry:Show()
                    end
                end
            end
        end
    end
    
    ParallelLoot:DebugPrint("UIManager: Ensured roll display is visible")
end

-- Return panel to pool
function UIManager:ReleaseItemPanel(panel)
    panel:Hide()
    panel:SetParent(nil)
    panel:ClearAllPoints()
    panel.lootItem = nil
    table.insert(self.itemPanelPool, panel)
end

-- Timer update loop
local timerFrame = CreateFrame("Frame")
local timeSinceLastUpdate = 0
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    
    -- Update every 0.5 seconds
    if timeSinceLastUpdate >= 0.5 then
        timeSinceLastUpdate = 0
        
        -- Update all visible item panels
        if UIManager.mainFrame and UIManager.mainFrame:IsShown() then
            for _, panel in pairs(UIManager.activeItemPanels) do
                if panel:IsShown() then
                    UIManager:UpdateItemPanelTimer(panel)
                end
            end
        end
    end
end)

ParallelLoot:DebugPrint("ItemPanel.lua loaded")
