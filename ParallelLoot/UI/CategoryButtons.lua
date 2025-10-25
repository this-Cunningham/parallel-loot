-- ParallelLoot Category Buttons
-- BIS/MS/OS/COZ category buttons for roll submission

local UIManager = ParallelLoot.UIManager

-- Category button configuration
UIManager.CATEGORIES = {
    {key = "bis", label = "BIS", color = {1, 0.8, 0}},      -- Gold
    {key = "ms", label = "MS", color = {0.5, 0.5, 1}},      -- Blue
    {key = "os", label = "OS", color = {0.5, 1, 0.5}},      -- Green
    {key = "coz", label = "COZ", color = {1, 0.5, 1}}       -- Pink
}

-- Create category buttons for an item panel
function UIManager:CreateCategoryButtons(panel)
    if not panel.categoryButtons then
        panel.categoryButtons = {}
        
        local buttonWidth = 60
        local buttonHeight = 24
        local spacing = 5
        
        for i, category in ipairs(self.CATEGORIES) do
            local button = CreateFrame("Button", nil, panel.categoryContainer)
            button:SetSize(buttonWidth, buttonHeight)
            
            -- Position buttons right to left
            local xOffset = -(i - 1) * (buttonWidth + spacing)
            button:SetPoint("TOPRIGHT", xOffset, 0)
            
            -- Button background
            button.bg = button:CreateTexture(nil, "BACKGROUND")
            button.bg:SetAllPoints()
            button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            
            -- Button border
            button.border = button:CreateTexture(nil, "BORDER")
            button.border:SetAllPoints()
            button.border:SetColorTexture(0.4, 0.4, 0.4, 1)
            
            -- Inner background
            button.innerBg = button:CreateTexture(nil, "ARTWORK")
            button.innerBg:SetPoint("TOPLEFT", 1, -1)
            button.innerBg:SetPoint("BOTTOMRIGHT", -1, 1)
            button.innerBg:SetColorTexture(0.3, 0.3, 0.3, 1)
            
            -- Button text
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            button.text:SetPoint("CENTER")
            button.text:SetText(category.label)
            
            -- Store category info
            button.category = category
            button.categoryKey = category.key
            
            -- Button states
            button.isSelected = false
            button.isDisabled = false
            
            -- Click handler
            button:SetScript("OnClick", function(self)
                UIManager:OnCategoryButtonClick(panel, self)
            end)
            
            -- Hover handlers
            button:SetScript("OnEnter", function(self)
                if not self.isDisabled then
                    UIManager:SetCategoryButtonState(self, "hover")
                    
                    -- Show tooltip
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    UIManager:ShowCategoryTooltip(panel, self.categoryKey)
                    GameTooltip:Show()
                end
            end)
            
            button:SetScript("OnLeave", function(self)
                if not self.isDisabled then
                    if self.isSelected then
                        UIManager:SetCategoryButtonState(self, "selected")
                    else
                        UIManager:SetCategoryButtonState(self, "default")
                    end
                end
                GameTooltip:Hide()
            end)
            
            -- Set initial state
            self:SetCategoryButtonState(button, "default")
            
            panel.categoryButtons[category.key] = button
        end
    end
end

-- Update category buttons for an item panel
function UIManager:UpdateCategoryButtons(panel)
    if not panel.lootItem then
        return
    end
    
    -- Create buttons if they don't exist
    if not panel.categoryButtons then
        self:CreateCategoryButtons(panel)
    end
    
    -- Check if item is awarded (read-only mode)
    local isAwarded = panel.lootItem.awardedTo ~= nil
    
    -- Check if player can use this item
    local canUse = panel.lootItem.canUse
    if canUse == nil then
        canUse = ParallelLoot.ClassFilter:CanCurrentPlayerUseItem(panel.lootItem)
    end
    
    -- Check if player has already rolled
    local playerName = UnitName("player")
    local playerRoll = self:GetPlayerRollForItem(panel.lootItem, playerName)
    
    -- Update each button
    for key, button in pairs(panel.categoryButtons) do
        if isAwarded then
            -- Disable all buttons for awarded items (read-only)
            self:SetCategoryButtonState(button, "disabled")
            button.isDisabled = true
            button.isSelected = false
        elseif not canUse then
            -- Disable all buttons if player can't use item
            self:SetCategoryButtonState(button, "disabled")
            button.isDisabled = true
        elseif playerRoll then
            -- Player has already rolled
            if playerRoll.category == key then
                -- This is the category they rolled on
                self:SetCategoryButtonState(button, "selected")
                button.isSelected = true
                button.isDisabled = true
            else
                -- Disable other categories
                self:SetCategoryButtonState(button, "disabled")
                button.isDisabled = true
            end
        else
            -- Enable button for rolling
            self:SetCategoryButtonState(button, "default")
            button.isDisabled = false
            button.isSelected = false
        end
    end
end

-- Set category button visual state
function UIManager:SetCategoryButtonState(button, state)
    local category = button.category
    
    if state == "default" then
        -- Default state - gray
        button.innerBg:SetColorTexture(0.3, 0.3, 0.3, 1)
        button.text:SetTextColor(0.9, 0.9, 0.9, 1)
        
    elseif state == "hover" then
        -- Hover state - slightly brighter
        button.innerBg:SetColorTexture(0.4, 0.4, 0.4, 1)
        button.text:SetTextColor(1, 1, 1, 1)
        
    elseif state == "selected" then
        -- Selected state - category color
        local r, g, b = unpack(category.color)
        button.innerBg:SetColorTexture(r, g, b, 1)
        button.text:SetTextColor(0, 0, 0, 1)
        
    elseif state == "disabled" then
        -- Disabled state - dark gray
        button.innerBg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        button.text:SetTextColor(0.5, 0.5, 0.5, 0.5)
    end
end

-- Handle category button click
function UIManager:OnCategoryButtonClick(panel, button)
    if button.isDisabled then
        return
    end
    
    local lootItem = panel.lootItem
    if not lootItem then
        return
    end
    
    -- Check if player can roll
    local playerName = UnitName("player")
    local existingRoll = self:GetPlayerRollForItem(lootItem, playerName)
    
    if existingRoll then
        ParallelLoot:Print("You have already rolled on this item!")
        self:ShowRollFeedback(button, "error", "Already rolled!")
        return
    end
    
    -- Get roll range for this category
    local rollRange = lootItem.rollRange
    if not rollRange or not rollRange[button.categoryKey] then
        ParallelLoot:Print("Error: No roll range assigned for this category")
        self:ShowRollFeedback(button, "error", "Invalid range")
        return
    end
    
    local range = rollRange[button.categoryKey]
    local minRoll = range.min
    local maxRoll = range.max
    
    -- Validate range
    if not minRoll or not maxRoll or minRoll > maxRoll then
        ParallelLoot:Print("Error: Invalid roll range")
        self:ShowRollFeedback(button, "error", "Invalid range")
        return
    end
    
    -- Perform the roll
    ParallelLoot:DebugPrint("Rolling", minRoll, "-", maxRoll, "for category", button.categoryKey)
    
    -- Show feedback that roll is being submitted
    self:ShowRollFeedback(button, "pending", "Rolling...")
    
    -- Execute the /roll command
    RandomRoll(minRoll, maxRoll)
    
    -- The actual roll will be detected by RollManager via CHAT_MSG_SYSTEM event
    -- Update the UI to show the button as selected
    button.isSelected = true
    self:SetCategoryButtonState(button, "selected")
    
    -- Disable all other buttons
    for key, otherButton in pairs(panel.categoryButtons) do
        if key ~= button.categoryKey then
            otherButton.isDisabled = true
            self:SetCategoryButtonState(otherButton, "disabled")
        end
    end
    
    ParallelLoot:Print(string.format("Rolling for %s on %s", 
        button.category.label, 
        lootItem.itemLink or lootItem.itemName))
    
    -- Show success feedback after a short delay
    C_Timer.After(0.5, function()
        self:ShowRollFeedback(button, "success", "Rolled!")
    end)
end

-- Show roll submission feedback
function UIManager:ShowRollFeedback(button, feedbackType, message)
    -- Create feedback frame if it doesn't exist
    if not button.feedbackFrame then
        button.feedbackFrame = CreateFrame("Frame", nil, button)
        button.feedbackFrame:SetAllPoints()
        button.feedbackFrame:SetFrameLevel(button:GetFrameLevel() + 10)
        
        -- Feedback text
        button.feedbackFrame.text = button.feedbackFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.feedbackFrame.text:SetPoint("CENTER")
        
        -- Background overlay
        button.feedbackFrame.overlay = button.feedbackFrame:CreateTexture(nil, "OVERLAY")
        button.feedbackFrame.overlay:SetAllPoints()
        button.feedbackFrame.overlay:SetColorTexture(0, 0, 0, 0.7)
        
        button.feedbackFrame:Hide()
    end
    
    -- Set feedback appearance based on type
    if feedbackType == "success" then
        button.feedbackFrame.text:SetTextColor(0, 1, 0, 1) -- Green
        button.feedbackFrame.text:SetText(message)
    elseif feedbackType == "error" then
        button.feedbackFrame.text:SetTextColor(1, 0, 0, 1) -- Red
        button.feedbackFrame.text:SetText(message)
    elseif feedbackType == "pending" then
        button.feedbackFrame.text:SetTextColor(1, 1, 0, 1) -- Yellow
        button.feedbackFrame.text:SetText(message)
    end
    
    -- Show feedback
    button.feedbackFrame:Show()
    
    -- Hide after delay (except for pending state)
    if feedbackType ~= "pending" then
        C_Timer.After(2, function()
            if button.feedbackFrame then
                button.feedbackFrame:Hide()
            end
        end)
    end
end

-- Hide roll feedback
function UIManager:HideRollFeedback(button)
    if button.feedbackFrame then
        button.feedbackFrame:Hide()
    end
end

-- Get player's roll for an item
function UIManager:GetPlayerRollForItem(lootItem, playerName)
    if not lootItem or not lootItem.rolls then
        return nil
    end
    
    for _, roll in ipairs(lootItem.rolls) do
        if roll.playerName == playerName then
            return roll
        end
    end
    
    return nil
end

-- Show category tooltip
function UIManager:ShowCategoryTooltip(panel, categoryKey)
    local lootItem = panel.lootItem
    if not lootItem or not lootItem.rollRange then
        return
    end
    
    local range = lootItem.rollRange[categoryKey]
    if not range then
        return
    end
    
    -- Get category info
    local categoryInfo = nil
    for _, cat in ipairs(self.CATEGORIES) do
        if cat.key == categoryKey then
            categoryInfo = cat
            break
        end
    end
    
    if not categoryInfo then
        return
    end
    
    -- Build tooltip
    GameTooltip:AddLine(categoryInfo.label, 1, 1, 1)
    GameTooltip:AddLine(string.format("Roll Range: %d - %d", range.min, range.max), 0.7, 0.7, 0.7)
    
    -- Add category description
    local descriptions = {
        bis = "Best in Slot - Highest priority",
        ms = "Main Spec - High priority",
        os = "Off Spec - Medium priority",
        coz = "Cosmetic - Low priority"
    }
    
    if descriptions[categoryKey] then
        GameTooltip:AddLine(descriptions[categoryKey], 0.5, 0.5, 1)
    end
    
    -- Show roll count for this category
    local rollCount = 0
    if lootItem.rolls then
        for _, roll in ipairs(lootItem.rolls) do
            if roll.category == categoryKey then
                rollCount = rollCount + 1
            end
        end
    end
    
    if rollCount > 0 then
        GameTooltip:AddLine(string.format("%d player%s rolled", rollCount, rollCount > 1 and "s" or ""), 1, 0.8, 0)
    end
end

-- Get category label from session settings
function UIManager:GetCategoryLabel(categoryKey)
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session and session.categories and session.categories[categoryKey] then
        return session.categories[categoryKey]
    end
    
    -- Return default label
    for _, cat in ipairs(self.CATEGORIES) do
        if cat.key == categoryKey then
            return cat.label
        end
    end
    
    return categoryKey:upper()
end

-- Update category labels from session settings
function UIManager:UpdateCategoryLabels()
    -- Update all visible item panels
    for _, panel in pairs(self.activeItemPanels) do
        if panel.categoryButtons then
            for key, button in pairs(panel.categoryButtons) do
                local label = self:GetCategoryLabel(key)
                button.text:SetText(label)
            end
        end
    end
end

ParallelLoot:DebugPrint("CategoryButtons.lua loaded")
