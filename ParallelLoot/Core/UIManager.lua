-- ParallelLoot UI Manager
-- Manages UI state and provides interface for showing/hiding frames

local UIManager = ParallelLoot.UIManager

-- Initialize UI Manager
function UIManager:Initialize()
    ParallelLoot:DebugPrint("UIManager: Initialized")
    
    -- UI will be fully initialized when MainFrame.xml loads
    -- This happens after ADDON_LOADED event
end

-- Toggle main frame visibility
function UIManager:ToggleMainFrame()
    if not self.mainFrame then
        ParallelLoot:Print("UI not yet loaded. Please wait a moment and try again.")
        return
    end
    
    if self.mainFrame:IsShown() then
        self:HideMainFrame()
    else
        self:ShowMainFrame()
    end
end

-- Show main frame
function UIManager:ShowMainFrame()
    if not self.mainFrame then
        ParallelLoot:Print("UI not yet loaded.")
        return
    end
    
    self.mainFrame:Show()
    ParallelLoot:DebugPrint("Main frame shown")
end

-- Hide main frame
function UIManager:HideMainFrame()
    if not self.mainFrame then
        return
    end
    
    self.mainFrame:Hide()
    ParallelLoot:DebugPrint("Main frame hidden")
end

-- Check if main frame is visible
function UIManager:IsMainFrameVisible()
    return self.mainFrame and self.mainFrame:IsShown()
end

-- Get current tab
function UIManager:GetCurrentTab()
    return self.currentTab
end

-- Public method to refresh UI
function UIManager:Refresh()
    if self.mainFrame and self.mainFrame:IsShown() then
        self:RefreshItemList()
    end
end

-- Refresh timer displays for all visible item panels
function UIManager:RefreshTimerDisplays()
    if not self.mainFrame or not self.mainFrame:IsShown() then
        return
    end
    
    -- Update all visible item panels
    if self.activeItemPanels then
        for _, panel in pairs(self.activeItemPanels) do
            if panel:IsShown() and panel.lootItem then
                self:UpdateItemPanelTimer(panel)
            end
        end
    end
end

-- Callback when item expires
function UIManager:OnItemExpired(item)
    ParallelLoot:DebugPrint("UIManager: Item expired, refreshing UI")
    self:Refresh()
end
