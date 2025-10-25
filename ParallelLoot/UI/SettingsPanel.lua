-- ParallelLoot Settings Panel
-- Configuration interface for timer warnings and other settings

local UIManager = ParallelLoot.UIManager

-- Create settings panel with tabs
function UIManager:CreateSettingsPanel(parent)
    local panel = CreateFrame("Frame", "ParallelLootSettingsPanel", parent or UIParent)
    panel:SetSize(600, 500)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    
    -- Background
    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    panel.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    
    -- Border
    panel.border = CreateFrame("Frame", nil, panel, "DialogBorderTemplate")
    
    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOP", 0, -15)
    panel.title:SetText("ParallelLoot Settings")
    
    -- Close button
    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetPoint("TOPRIGHT", -5, -5)
    panel.closeButton:SetScript("OnClick", function()
        panel:Hide()
    end)
    
    -- Tab container
    panel.tabs = {}
    panel.tabButtons = {}
    
    -- Create tab buttons
    local tabNames = {"Categories", "General", "Timer"}
    local tabWidth = 120
    local startX = 20
    
    for i, tabName in ipairs(tabNames) do
        local tabButton = CreateFrame("Button", nil, panel)
        tabButton:SetSize(tabWidth, 30)
        tabButton:SetPoint("TOPLEFT", startX + (i-1) * (tabWidth + 5), -45)
        tabButton:SetNormalFontObject("GameFontNormal")
        tabButton:SetHighlightFontObject("GameFontHighlight")
        tabButton:SetText(tabName)
        
        -- Tab button background
        tabButton.bg = tabButton:CreateTexture(nil, "BACKGROUND")
        tabButton.bg:SetAllPoints()
        tabButton.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        
        -- Tab button selected background
        tabButton.selectedBg = tabButton:CreateTexture(nil, "BACKGROUND")
        tabButton.selectedBg:SetAllPoints()
        tabButton.selectedBg:SetColorTexture(0.3, 0.3, 0.3, 1)
        tabButton.selectedBg:Hide()
        
        tabButton:SetScript("OnClick", function()
            UIManager:ShowSettingsTab(panel, i)
        end)
        
        panel.tabButtons[i] = tabButton
    end
    
    -- Content container for all tabs
    local contentContainer = CreateFrame("Frame", nil, panel)
    contentContainer:SetPoint("TOPLEFT", 20, -80)
    contentContainer:SetPoint("BOTTOMRIGHT", -20, 60)
    panel.contentContainer = contentContainer
    
    -- Create tab content frames
    panel.tabs[1] = UIManager:CreateCategoryTab(contentContainer)
    panel.tabs[2] = UIManager:CreateGeneralTab(contentContainer)
    panel.tabs[3] = UIManager:CreateTimerTab(contentContainer)

    
    -- Show first tab by default
    UIManager:ShowSettingsTab(panel, 1)
    
    -- ========================================================================
    -- BUTTONS
    -- ========================================================================
    
    -- Save Button
    local saveButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 30)
    saveButton:SetPoint("BOTTOMRIGHT", -20, 20)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        UIManager:SaveSettings(panel)
    end)
    panel.saveButton = saveButton
    
    -- Cancel Button
    local cancelButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 30)
    cancelButton:SetPoint("RIGHT", saveButton, "LEFT", -10, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        panel:Hide()
    end)
    panel.cancelButton = cancelButton
    
    -- Reset to Defaults Button
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(120, 30)
    resetButton:SetPoint("BOTTOMLEFT", 20, 20)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        UIManager:ResetSettingsToDefaults(panel)
    end)
    panel.resetButton = resetButton
    
    -- Make panel draggable
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    
    -- Load current settings
    self:LoadSettingsIntoPanel(panel)
    
    return panel
end

-- Show specific settings tab
function UIManager:ShowSettingsTab(panel, tabIndex)
    if not panel or not panel.tabs then
        return
    end
    
    -- Hide all tabs
    for i, tab in ipairs(panel.tabs) do
        tab:Hide()
    end
    
    -- Update tab button states
    for i, button in ipairs(panel.tabButtons) do
        if i == tabIndex then
            button.selectedBg:Show()
            button.bg:Hide()
        else
            button.selectedBg:Hide()
            button.bg:Show()
        end
    end
    
    -- Show selected tab
    if panel.tabs[tabIndex] then
        panel.tabs[tabIndex]:Show()
    end
    
    panel.currentTab = tabIndex
end

-- Create Category Customization Tab
function UIManager:CreateCategoryTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()
    tab:Hide()
    
    local yOffset = -10
    
    -- Header
    local header = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("Category Customization")
    header:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 35
    
    -- Description
    local desc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 10, yOffset)
    desc:SetText("Customize category names and roll range offsets. Categories are prioritized from top to bottom.")
    desc:SetTextColor(0.7, 0.7, 0.7, 1)
    desc:SetWidth(540)
    desc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 40
    
    -- Category inputs
    tab.categoryInputs = {}
    tab.offsetInputs = {}
    
    local categories = {"bis", "ms", "os", "coz"}
    local categoryDefaults = {
        {key = "bis", name = "BIS", offset = 0, desc = "Best in Slot (Highest Priority)"},
        {key = "ms", name = "MS", offset = 1, desc = "Main Spec"},
        {key = "os", name = "OS", offset = 2, desc = "Off Spec"},
        {key = "coz", name = "COZ", offset = 3, desc = "Cosmetic (Lowest Priority)"}
    }
    
    for i, catData in ipairs(categoryDefaults) do
        -- Category label
        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20, yOffset)
        label:SetText(catData.desc .. ":")
        
        -- Name input
        local nameInput = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
        nameInput:SetSize(100, 30)
        nameInput:SetPoint("TOPLEFT", 250, yOffset + 5)
        nameInput:SetAutoFocus(false)
        nameInput:SetMaxLetters(10)
        tab.categoryInputs[catData.key] = nameInput
        
        -- Offset label
        local offsetLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        offsetLabel:SetPoint("LEFT", nameInput, "RIGHT", 15, 0)
        offsetLabel:SetText("Offset:")
        
        -- Offset input
        local offsetInput = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
        offsetInput:SetSize(50, 30)
        offsetInput:SetPoint("LEFT", offsetLabel, "RIGHT", 5, 0)
        offsetInput:SetAutoFocus(false)
        offsetInput:SetNumeric(true)
        offsetInput:SetMaxLetters(2)
        tab.offsetInputs[catData.key] = offsetInput
        
        yOffset = yOffset - 40
    end
    
    yOffset = yOffset - 10
    
    -- Offset explanation
    local offsetDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offsetDesc:SetPoint("TOPLEFT", 20, yOffset)
    offsetDesc:SetText("Offset: Number subtracted from max roll range (e.g., offset 0 = 1-100, offset 1 = 1-99)")
    offsetDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    offsetDesc:SetWidth(540)
    offsetDesc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 40
    
    -- Import/Export section
    local importExportHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importExportHeader:SetPoint("TOPLEFT", 10, yOffset)
    importExportHeader:SetText("Import/Export Presets")
    importExportHeader:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 30
    
    -- Export button
    local exportButton = CreateFrame("Button", nil, tab, "UIPanelButtonTemplate")
    exportButton:SetSize(120, 30)
    exportButton:SetPoint("TOPLEFT", 20, yOffset)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function()
        UIManager:ExportCategoryPreset()
    end)
    tab.exportButton = exportButton
    
    -- Import button
    local importButton = CreateFrame("Button", nil, tab, "UIPanelButtonTemplate")
    importButton:SetSize(120, 30)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 10, 0)
    importButton:SetText("Import")
    importButton:SetScript("OnClick", function()
        UIManager:ImportCategoryPreset()
    end)
    tab.importButton = importButton
    
    return tab
end

-- Create General Settings Tab
function UIManager:CreateGeneralTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()
    tab:Hide()
    
    local yOffset = -10
    
    -- Header
    local header = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("General Settings")
    header:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 40
    
    -- Session Settings
    local sessionHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionHeader:SetPoint("TOPLEFT", 10, yOffset)
    sessionHeader:SetText("Session Settings")
    sessionHeader:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 30
    
    -- Auto-start session checkbox
    local autoStartCheckbox = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    autoStartCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    autoStartCheckbox:SetSize(24, 24)
    tab.autoStartCheckbox = autoStartCheckbox
    
    local autoStartLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoStartLabel:SetPoint("LEFT", autoStartCheckbox, "RIGHT", 5, 0)
    autoStartLabel:SetText("Auto-start loot session when entering raid")
    
    local autoStartDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoStartDesc:SetPoint("TOPLEFT", autoStartCheckbox, "BOTTOMLEFT", 30, -5)
    autoStartDesc:SetText("Automatically create a new loot session when you join a raid instance")
    autoStartDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    autoStartDesc:SetWidth(500)
    autoStartDesc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 70
    
    -- UI Preferences
    local uiHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    uiHeader:SetPoint("TOPLEFT", 10, yOffset)
    uiHeader:SetText("UI Preferences")
    uiHeader:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 30
    
    -- Show item quality colors checkbox
    local qualityColorsCheckbox = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    qualityColorsCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    qualityColorsCheckbox:SetSize(24, 24)
    qualityColorsCheckbox:SetChecked(true)
    tab.qualityColorsCheckbox = qualityColorsCheckbox
    
    local qualityColorsLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityColorsLabel:SetPoint("LEFT", qualityColorsCheckbox, "RIGHT", 5, 0)
    qualityColorsLabel:SetText("Show item quality colors")
    
    local qualityColorsDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qualityColorsDesc:SetPoint("TOPLEFT", qualityColorsCheckbox, "BOTTOMLEFT", 30, -5)
    qualityColorsDesc:SetText("Display item names and borders with quality colors (epic, rare, etc.)")
    qualityColorsDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    qualityColorsDesc:SetWidth(500)
    qualityColorsDesc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 70
    
    -- Show class colors checkbox
    local classColorsCheckbox = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    classColorsCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    classColorsCheckbox:SetSize(24, 24)
    classColorsCheckbox:SetChecked(true)
    tab.classColorsCheckbox = classColorsCheckbox
    
    local classColorsLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorsLabel:SetPoint("LEFT", classColorsCheckbox, "RIGHT", 5, 0)
    classColorsLabel:SetText("Show class colors for player names")
    
    local classColorsDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classColorsDesc:SetPoint("TOPLEFT", classColorsCheckbox, "BOTTOMLEFT", 30, -5)
    classColorsDesc:SetText("Display player names in their class colors in roll lists")
    classColorsDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    classColorsDesc:SetWidth(500)
    classColorsDesc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 70
    
    -- Sound and Notifications
    local soundHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundHeader:SetPoint("TOPLEFT", 10, yOffset)
    soundHeader:SetText("Sound and Notifications")
    soundHeader:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 30
    
    -- Enable sounds checkbox
    local soundCheckbox = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    soundCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    soundCheckbox:SetSize(24, 24)
    tab.soundCheckbox = soundCheckbox
    
    local soundLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
    soundLabel:SetText("Enable notification sounds")
    
    local soundDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundDesc:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 30, -5)
    soundDesc:SetText("Play sound alerts for important events (item expiration, awards, etc.)")
    soundDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    soundDesc:SetWidth(500)
    soundDesc:SetJustifyH("LEFT")
    
    return tab
end

-- Create Timer Settings Tab
function UIManager:CreateTimerTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()
    tab:Hide()
    
    local yOffset = -10
    
    -- Header
    local header = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("Timer Settings")
    header:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 40
    
    -- Warning Thresholds
    local thresholdHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thresholdHeader:SetPoint("TOPLEFT", 10, yOffset)
    thresholdHeader:SetText("Warning Thresholds")
    thresholdHeader:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 30
    
    -- Warning Threshold Label
    local warningLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningLabel:SetPoint("TOPLEFT", 20, yOffset)
    warningLabel:SetText("Warning Threshold (seconds):")
    
    -- Warning Threshold Input
    local warningInput = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
    warningInput:SetSize(100, 30)
    warningInput:SetPoint("LEFT", warningLabel, "RIGHT", 10, 0)
    warningInput:SetAutoFocus(false)
    warningInput:SetNumeric(true)
    warningInput:SetMaxLetters(4)
    tab.warningInput = warningInput
    
    -- Warning Threshold Description
    local warningDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warningDesc:SetPoint("TOPLEFT", warningLabel, "BOTTOMLEFT", 0, -5)
    warningDesc:SetText("Show warning when item has this many seconds remaining (default: 300)")
    warningDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    warningDesc:SetWidth(500)
    warningDesc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 60
    
    -- Critical Threshold Label
    local criticalLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    criticalLabel:SetPoint("TOPLEFT", 20, yOffset)
    criticalLabel:SetText("Critical Threshold (seconds):")
    
    -- Critical Threshold Input
    local criticalInput = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
    criticalInput:SetSize(100, 30)
    criticalInput:SetPoint("LEFT", criticalLabel, "RIGHT", 10, 0)
    criticalInput:SetAutoFocus(false)
    criticalInput:SetNumeric(true)
    criticalInput:SetMaxLetters(4)
    tab.criticalInput = criticalInput
    
    -- Critical Threshold Description
    local criticalDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    criticalDesc:SetPoint("TOPLEFT", criticalLabel, "BOTTOMLEFT", 0, -5)
    criticalDesc:SetText("Show critical warning when item has this many seconds remaining (default: 60)")
    criticalDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    criticalDesc:SetWidth(500)
    criticalDesc:SetJustifyH("LEFT")
    
    yOffset = yOffset - 70
    
    -- Display Format
    local displayHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 10, yOffset)
    displayHeader:SetText("Display Format")
    displayHeader:SetTextColor(1, 0.82, 0, 1)
    
    yOffset = yOffset - 30
    
    -- Show Hours Checkbox
    local showHoursCheckbox = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    showHoursCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    showHoursCheckbox:SetSize(24, 24)
    showHoursCheckbox:SetChecked(true)
    tab.showHoursCheckbox = showHoursCheckbox
    
    local showHoursLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showHoursLabel:SetPoint("LEFT", showHoursCheckbox, "RIGHT", 5, 0)
    showHoursLabel:SetText("Show Hours in Timer Display")
    
    -- Display Format Description
    local displayDesc = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    displayDesc:SetPoint("TOPLEFT", showHoursCheckbox, "BOTTOMLEFT", 30, -5)
    displayDesc:SetText("Display timer as HH:MM:SS instead of MM:SS")
    displayDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    displayDesc:SetWidth(500)
    displayDesc:SetJustifyH("LEFT")
    
    return tab
end

-- Load current settings into the panel
function UIManager:LoadSettingsIntoPanel(panel)
    if not panel or not panel.tabs then
        return
    end
    
    -- Get current settings
    local categories = ParallelLoot.DataManager:GetSetting("categories") or {
        bis = "BIS", ms = "MS", os = "OS", coz = "COZ"
    }
    local categoryOffsets = ParallelLoot.DataManager:GetSetting("categoryOffsets") or {
        bis = 0, ms = 1, os = 2, coz = 3
    }
    local timerWarnings = ParallelLoot.DataManager:GetSetting("timerWarnings") or {300, 60}
    local soundEnabled = ParallelLoot.DataManager:GetSetting("soundEnabled")
    local showHours = ParallelLoot.DataManager:GetSetting("showHoursInTimer")
    local autoStart = ParallelLoot.DataManager:GetSetting("autoStart")
    local showQualityColors = ParallelLoot.DataManager:GetSetting("showQualityColors")
    local showClassColors = ParallelLoot.DataManager:GetSetting("showClassColors")
    
    -- Set defaults if nil
    if soundEnabled == nil then soundEnabled = true end
    if showHours == nil then showHours = true end
    if autoStart == nil then autoStart = false end
    if showQualityColors == nil then showQualityColors = true end
    if showClassColors == nil then showClassColors = true end
    
    -- Load Category Tab
    local categoryTab = panel.tabs[1]
    if categoryTab then
        for key, input in pairs(categoryTab.categoryInputs) do
            input:SetText(categories[key] or key:upper())
        end
        for key, input in pairs(categoryTab.offsetInputs) do
            input:SetText(tostring(categoryOffsets[key] or 0))
        end
    end
    
    -- Load General Tab
    local generalTab = panel.tabs[2]
    if generalTab then
        generalTab.autoStartCheckbox:SetChecked(autoStart)
        generalTab.qualityColorsCheckbox:SetChecked(showQualityColors)
        generalTab.classColorsCheckbox:SetChecked(showClassColors)
        generalTab.soundCheckbox:SetChecked(soundEnabled)
    end
    
    -- Load Timer Tab
    local timerTab = panel.tabs[3]
    if timerTab then
        timerTab.warningInput:SetText(tostring(timerWarnings[1] or 300))
        timerTab.criticalInput:SetText(tostring(timerWarnings[2] or 60))
        timerTab.showHoursCheckbox:SetChecked(showHours)
    end
end

-- Save settings from the panel
function UIManager:SaveSettings(panel)
    if not panel or not panel.tabs then
        return
    end
    
    -- Get Category Tab values
    local categoryTab = panel.tabs[1]
    local categories = {}
    local categoryOffsets = {}
    
    if categoryTab then
        for key, input in pairs(categoryTab.categoryInputs) do
            local value = input:GetText()
            if value and value ~= "" then
                categories[key] = value
            else
                categories[key] = key:upper()
            end
        end
        
        for key, input in pairs(categoryTab.offsetInputs) do
            local value = tonumber(input:GetText())
            if value and value >= 0 then
                categoryOffsets[key] = value
            else
                categoryOffsets[key] = 0
            end
        end
    end
    
    -- Get General Tab values
    local generalTab = panel.tabs[2]
    local autoStart = false
    local showQualityColors = true
    local showClassColors = true
    local soundEnabled = true
    
    if generalTab then
        autoStart = generalTab.autoStartCheckbox:GetChecked()
        showQualityColors = generalTab.qualityColorsCheckbox:GetChecked()
        showClassColors = generalTab.classColorsCheckbox:GetChecked()
        soundEnabled = generalTab.soundCheckbox:GetChecked()
    end
    
    -- Get Timer Tab values
    local timerTab = panel.tabs[3]
    local warningThreshold = 300
    local criticalThreshold = 60
    local showHours = true
    
    if timerTab then
        warningThreshold = tonumber(timerTab.warningInput:GetText()) or 300
        criticalThreshold = tonumber(timerTab.criticalInput:GetText()) or 60
        showHours = timerTab.showHoursCheckbox:GetChecked()
    end
    
    -- Validate thresholds
    if warningThreshold < 1 then
        warningThreshold = 300
    end
    if criticalThreshold < 1 then
        criticalThreshold = 60
    end
    
    -- Ensure warning threshold is greater than critical threshold
    if warningThreshold <= criticalThreshold then
        ParallelLoot:Print("Warning: Warning threshold must be greater than critical threshold. Adjusting values.")
        warningThreshold = criticalThreshold + 60
    end
    
    -- Save all settings
    ParallelLoot.DataManager:SetSetting("categories", categories)
    ParallelLoot.DataManager:SetSetting("categoryOffsets", categoryOffsets)
    ParallelLoot.DataManager:SetSetting("timerWarnings", {warningThreshold, criticalThreshold})
    ParallelLoot.DataManager:SetSetting("soundEnabled", soundEnabled)
    ParallelLoot.DataManager:SetSetting("showHoursInTimer", showHours)
    ParallelLoot.DataManager:SetSetting("autoStart", autoStart)
    ParallelLoot.DataManager:SetSetting("showQualityColors", showQualityColors)
    ParallelLoot.DataManager:SetSetting("showClassColors", showClassColors)
    
    ParallelLoot:Print("Settings saved successfully")
    
    -- Hide panel
    panel:Hide()
    
    -- Refresh UI to apply new settings
    if self.Refresh then
        self:Refresh()
    end
end

-- Reset settings to defaults
function UIManager:ResetSettingsToDefaults(panel)
    if not panel or not panel.tabs then
        return
    end
    
    -- Reset Category Tab
    local categoryTab = panel.tabs[1]
    if categoryTab then
        categoryTab.categoryInputs.bis:SetText("BIS")
        categoryTab.categoryInputs.ms:SetText("MS")
        categoryTab.categoryInputs.os:SetText("OS")
        categoryTab.categoryInputs.coz:SetText("COZ")
        
        categoryTab.offsetInputs.bis:SetText("0")
        categoryTab.offsetInputs.ms:SetText("1")
        categoryTab.offsetInputs.os:SetText("2")
        categoryTab.offsetInputs.coz:SetText("3")
    end
    
    -- Reset General Tab
    local generalTab = panel.tabs[2]
    if generalTab then
        generalTab.autoStartCheckbox:SetChecked(false)
        generalTab.qualityColorsCheckbox:SetChecked(true)
        generalTab.classColorsCheckbox:SetChecked(true)
        generalTab.soundCheckbox:SetChecked(true)
    end
    
    -- Reset Timer Tab
    local timerTab = panel.tabs[3]
    if timerTab then
        timerTab.warningInput:SetText("300")
        timerTab.criticalInput:SetText("60")
        timerTab.showHoursCheckbox:SetChecked(true)
    end
    
    ParallelLoot:Print("Settings reset to defaults (not saved yet)")
end

-- Show settings panel
function UIManager:ShowSettingsPanel()
    if not self.settingsPanel then
        self.settingsPanel = self:CreateSettingsPanel()
    end
    
    -- Load current settings
    self:LoadSettingsIntoPanel(self.settingsPanel)
    
    self.settingsPanel:Show()
end

-- Hide settings panel
function UIManager:HideSettingsPanel()
    if self.settingsPanel then
        self.settingsPanel:Hide()
    end
end

-- Toggle settings panel
function UIManager:ToggleSettingsPanel()
    if not self.settingsPanel then
        self:ShowSettingsPanel()
    elseif self.settingsPanel:IsShown() then
        self:HideSettingsPanel()
    else
        self:ShowSettingsPanel()
    end
end

-- Export category preset to chat
function UIManager:ExportCategoryPreset()
    local categories = ParallelLoot.DataManager:GetSetting("categories") or {
        bis = "BIS", ms = "MS", os = "OS", coz = "COZ"
    }
    local categoryOffsets = ParallelLoot.DataManager:GetSetting("categoryOffsets") or {
        bis = 0, ms = 1, os = 2, coz = 3
    }
    
    -- Create export string
    local exportData = {
        categories = categories,
        offsets = categoryOffsets
    }
    
    -- Serialize to string (simple format)
    local exportString = string.format(
        "PLootPreset:%s,%s,%s,%s:%d,%d,%d,%d",
        categories.bis, categories.ms, categories.os, categories.coz,
        categoryOffsets.bis, categoryOffsets.ms, categoryOffsets.os, categoryOffsets.coz
    )
    
    -- Create popup to show export string
    StaticPopupDialogs["PLOOT_EXPORT_PRESET"] = {
        text = "Copy this preset string:",
        button1 = "Close",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        hasEditBox = true,
        editBoxWidth = 350,
        OnShow = function(self)
            self.editBox:SetText(exportString)
            self.editBox:HighlightText()
            self.editBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }
    
    StaticPopup_Show("PLOOT_EXPORT_PRESET")
    ParallelLoot:Print("Category preset exported to popup")
end

-- Import category preset from string
function UIManager:ImportCategoryPreset()
    -- Create popup to input import string
    StaticPopupDialogs["PLOOT_IMPORT_PRESET"] = {
        text = "Paste preset string:",
        button1 = "Import",
        button2 = "Cancel",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        hasEditBox = true,
        editBoxWidth = 350,
        OnAccept = function(self)
            local importString = self.editBox:GetText()
            UIManager:ProcessImportPreset(importString)
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }
    
    StaticPopup_Show("PLOOT_IMPORT_PRESET")
end

-- Process imported preset string
function UIManager:ProcessImportPreset(importString)
    if not importString or importString == "" then
        ParallelLoot:Print("Error: Empty import string")
        return
    end
    
    -- Parse import string
    -- Format: PLootPreset:BIS,MS,OS,COZ:0,1,2,3
    local prefix, catString, offsetString = string.match(importString, "^(%w+):([^:]+):([^:]+)$")
    
    if prefix ~= "PLootPreset" then
        ParallelLoot:Print("Error: Invalid preset format")
        return
    end
    
    -- Parse categories
    local catNames = {}
    local i = 1
    for name in string.gmatch(catString, "([^,]+)") do
        catNames[i] = name
        i = i + 1
    end
    
    if #catNames ~= 4 then
        ParallelLoot:Print("Error: Invalid category count (expected 4)")
        return
    end
    
    -- Parse offsets
    local offsets = {}
    i = 1
    for offset in string.gmatch(offsetString, "([^,]+)") do
        offsets[i] = tonumber(offset)
        if not offsets[i] then
            ParallelLoot:Print("Error: Invalid offset value")
            return
        end
        i = i + 1
    end
    
    if #offsets ~= 4 then
        ParallelLoot:Print("Error: Invalid offset count (expected 4)")
        return
    end
    
    -- Create category and offset tables
    local categories = {
        bis = catNames[1],
        ms = catNames[2],
        os = catNames[3],
        coz = catNames[4]
    }
    
    local categoryOffsets = {
        bis = offsets[1],
        ms = offsets[2],
        os = offsets[3],
        coz = offsets[4]
    }
    
    -- Save imported settings
    ParallelLoot.DataManager:SetSetting("categories", categories)
    ParallelLoot.DataManager:SetSetting("categoryOffsets", categoryOffsets)
    
    -- Reload settings panel if open
    if self.settingsPanel and self.settingsPanel:IsShown() then
        self:LoadSettingsIntoPanel(self.settingsPanel)
    end
    
    ParallelLoot:Print("Category preset imported successfully")
end

ParallelLoot:DebugPrint("SettingsPanel.lua loaded")
