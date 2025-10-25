-- ParallelLoot Item Panel
-- Individual collapsible panels for each loot item

local UIManager = ParallelLoot.UIManager

-- Item panel pool for reuse
UIManager.itemPanelPool = {}
UIManager.activeItemPanels = {}

-- Create a new item panel
function UIManager:CreateItemPanel(parent, lootItem)
    -- Try to reuse from pool
    local panel = table.remove(self.itemPanelPool)
    
    if not panel then
        -- Create new panel
        panel = CreateFrame("Frame", nil, parent)
        panel:SetSize(640, 80) -- Default collapsed height
        
        -- Background
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints()
        panel.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        -- Border
        panel.border = panel:CreateTexture(nil, "BORDER")
        panel.border:SetAllPoints()
        panel.border:SetColorTexture(0.3, 0.3, 0.3, 1)
        panel.border:SetDrawLayer("BORDER", 1)
        
        -- Inner background (inset from border)
        panel.innerBg = panel:CreateTexture(nil, "BACKGROUND")
        panel.innerBg:SetPoint("TOPLEFT", 2, -2)
        panel.innerBg:SetPoint("BOTTOMRIGHT", -2, 2)
        panel.innerBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        
        -- Item icon
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(36, 36)
        panel.icon:SetPoint("TOPLEFT", 8, -8)
        
        -- Icon border
        panel.iconBorder = panel:CreateTexture(nil, "OVERLAY")
        panel.iconBorder:SetSize(40, 40)
        panel.iconBorder:SetPoint("CENTER", panel.icon, "CENTER")
        panel.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        panel.iconBorder:SetBlendMode("ADD")
        
        -- Item name
        panel.itemName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        panel.itemName:SetPoint("LEFT", panel.icon, "RIGHT", 8, 8)
        panel.itemName:SetJustifyH("LEFT")
        
        -- Subtitle text
        panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.subtitle:SetPoint("TOPLEFT", panel.itemName, "BOTTOMLEFT", 0, -2)
        panel.subtitle:SetText("Loot Roll Details")
        panel.subtitle:SetTextColor(0.7, 0.7, 0.7, 1)
        
        -- Progress bar background
        panel.progressBg = panel:CreateTexture(nil, "BACKGROUND")
        panel.progressBg:SetSize(620, 12)
        panel.progressBg:SetPoint("TOPLEFT", 8, -52)
        panel.progressBg:SetColorTexture(0.2, 0.2, 0.2, 1)
        
        -- Progress bar
        panel.progressBar = panel:CreateTexture(nil, "ARTWORK")
        panel.progressBar:SetSize(620, 12)
        panel.progressBar:SetPoint("TOPLEFT", panel.progressBg, "TOPLEFT")
        panel.progressBar:SetColorTexture(1, 0.5, 0, 1) -- Orange color
        panel.progressBar:SetGradient("HORIZONTAL", 
            CreateColor(1, 0.6, 0, 1), 
            CreateColor(1, 0.4, 0, 1))
        
        -- Timer text
        panel.timerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel.timerText:SetPoint("TOPLEFT", panel.progressBg, "BOTTOMLEFT", 0, -2)
        panel.timerText:SetTextColor(1, 1, 1, 1)
        
        -- Expand/collapse button
        panel.expandButton = CreateFrame("Button", nil, panel)
        panel.expandButton:SetSize(20, 20)
        panel.expandButton:SetPoint("TOPRIGHT", -8, -8)
        
        -- Expand button textures
        panel.expandButton.arrow = panel.expandButton:CreateTexture(nil, "ARTWORK")
        panel.expandButton.arrow:SetAllPoints()
        panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        
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
        
        -- Award button (for loot master only)
        panel.awardButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.awardButton:SetSize(80, 24)
        panel.awardButton:SetPoint("TOPRIGHT", panel.expandButton, "TOPLEFT", -10, -2)
        panel.awardButton:SetText("Award")
        panel.awardButton:Hide() -- Hidden by default, shown for loot master
        
        panel.awardButton:SetScript("OnClick", function()
            UIManager:OnAwardButtonClicked(panel)
        end)
        
        -- Revoke Award button (for loot master on awarded items)
        panel.revokeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.revokeButton:SetSize(100, 24)
        panel.revokeButton:SetPoint("TOPRIGHT", panel.expandButton, "TOPLEFT", -10, -2)
        panel.revokeButton:SetText("Revoke Award")
        panel.revokeButton:Hide() -- Hidden by default, shown for loot master on awarded items
        
        panel.revokeButton:SetScript("OnClick", function()
            UIManager:OnRevokeButtonClicked(panel)
        end)
        
        -- Category buttons container (will be populated in sub-task 5.3)
        panel.categoryContainer = CreateFrame("Frame", nil, panel)
        panel.categoryContainer:SetSize(400, 30)
        panel.categoryContainer:SetPoint("TOPRIGHT", panel.awardButton, "TOPLEFT", -10, 0)
        
        -- Expanded content frame (hidden by default)
        panel.expandedContent = CreateFrame("Frame", nil, panel)
        panel.expandedContent:SetPoint("TOPLEFT", 8, -75)
        panel.expandedContent:SetPoint("TOPRIGHT", -8, -75)
        panel.expandedContent:SetHeight(1)
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
    
    -- Update category buttons
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
    panel.isExpanded = not panel.isExpanded
    
    if panel.isExpanded then
        -- Expand
        panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
        panel.expandedContent:Show()
        
        -- Update expanded content with roll display
        self:UpdateExpandedContent(panel)
        
        -- Adjust panel height
        local expandedHeight = 200 -- Base height for expanded view
        panel:SetHeight(80 + expandedHeight)
        panel.expandedContent:SetHeight(expandedHeight)
    else
        -- Collapse
        panel.expandButton.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        panel.expandedContent:Hide()
        panel:SetHeight(80)
    end
    
    -- Refresh layout to adjust positions of other panels
    self:RefreshItemList()
end

-- Update expanded content (placeholder for task 6)
function UIManager:UpdateExpandedContent(panel)
    -- This will be implemented in task 6 (roll display and management)
    -- For now, just show a placeholder
    if not panel.expandedContent.placeholder then
        panel.expandedContent.placeholder = panel.expandedContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.expandedContent.placeholder:SetPoint("CENTER")
        panel.expandedContent.placeholder:SetText("Roll details will appear here")
        panel.expandedContent.placeholder:SetTextColor(0.5, 0.5, 0.5, 1)
    end
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
