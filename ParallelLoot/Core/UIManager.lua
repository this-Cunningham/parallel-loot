-- ParallelLoot UI Manager
-- Manages UI state and provides interface for showing/hiding frames

local UIManager = ParallelLoot.UIManager

-- Panel state management properties
UIManager.panelStates = {}  -- Tracks expand/collapse states by item ID
UIManager.layoutDirty = false  -- Flags when layout needs recalculation
UIManager.refreshInProgress = false  -- Prevents recursive refreshes
UIManager.layoutCalculating = false  -- Prevents recursive layout calculations
UIManager.lastLayoutUpdate = 0  -- Timestamp of last layout update

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

-- Initialize UI Manager
function UIManager:Initialize()
    ParallelLoot:DebugPrint("UIManager: Initialized")
    
    -- Initialize state management
    self.panelStates = {}
    self.layoutDirty = false
    self.refreshInProgress = false
    self.layoutCalculating = false
    self.lastLayoutUpdate = 0
    
    -- Initialize event-driven update system
    self.eventQueue = {}
    self.eventProcessing = false
    self.lastEventTime = 0
    self.eventThrottleDelay = 0.1 -- 100ms throttle
    
    -- Setup immediate UI refresh event handlers
    self:SetupEventHandlers()
    
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
        -- Use the state-preserving refresh logic
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

-- Panel State Management Methods

-- Capture current expand/collapse states before refresh
function UIManager:PreservePanelStates()
    if not self.activeItemPanels then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Preserving panel states for", #self.activeItemPanels, "panels")
    
    for _, panel in pairs(self.activeItemPanels) do
        if panel.lootItem and panel.lootItem.id then
            self.panelStates[panel.lootItem.id] = {
                isExpanded = panel.isExpanded or false,
                lastUpdate = time()
            }
            ParallelLoot:DebugPrint("UIManager: Preserved state for item", panel.lootItem.id, "expanded:", panel.isExpanded)
        end
    end
end

-- Restore expand/collapse states after panel recreation
function UIManager:RestorePanelStates()
    if not self.activeItemPanels then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Restoring panel states for", #self.activeItemPanels, "panels")
    
    for _, panel in pairs(self.activeItemPanels) do
        if panel.lootItem and panel.lootItem.id then
            local savedState = self.panelStates[panel.lootItem.id]
            if savedState and savedState.isExpanded then
                ParallelLoot:DebugPrint("UIManager: Restoring expanded state for item", panel.lootItem.id)
                -- Set the state without triggering a full refresh
                panel.isExpanded = false -- Start collapsed
                self:ToggleItemPanelExpandedInternal(panel, true) -- Expand without refresh
            end
        end
    end
end

-- Clean up stale panel states for items that no longer exist
function UIManager:CleanupPanelStates()
    if not self.panelStates then
        return
    end
    
    -- Get current active item IDs
    local currentItems = {}
    local items = {}
    if self.currentTab == self.TABS.ACTIVE then
        items = ParallelLoot.LootManager:GetActiveItems() or {}
    else
        items = ParallelLoot.LootManager:GetAwardedItems() or {}
    end
    
    for _, item in ipairs(items) do
        if item.id then
            currentItems[item.id] = true
        end
    end
    
    -- Remove states for items that no longer exist
    local removedCount = 0
    for itemId, _ in pairs(self.panelStates) do
        if not currentItems[itemId] then
            self.panelStates[itemId] = nil
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        ParallelLoot:DebugPrint("UIManager: Cleaned up", removedCount, "stale panel states")
    end
end

-- Detect and recover from panel state corruption
function UIManager:ValidateAndRecoverPanelStates()
    if not self.panelStates then
        ParallelLoot:DebugPrint("UIManager: Panel states corrupted, reinitializing")
        self.panelStates = {}
        return false
    end
    
    -- Check for invalid state entries
    local corruptedCount = 0
    for itemId, state in pairs(self.panelStates) do
        if type(state) ~= "table" or type(state.isExpanded) ~= "boolean" then
            ParallelLoot:DebugPrint("UIManager: Corrupted state detected for item", itemId)
            self.panelStates[itemId] = nil
            corruptedCount = corruptedCount + 1
        end
    end
    
    if corruptedCount > 0 then
        ParallelLoot:DebugPrint("UIManager: Recovered from", corruptedCount, "corrupted panel states")
        return false
    end
    
    return true
end

-- Reset all panel states (manual recovery function)
function UIManager:ResetPanelStates()
    ParallelLoot:DebugPrint("UIManager: Resetting all panel states")
    self.panelStates = {}
    self.layoutDirty = false
    self.refreshInProgress = false
    
    -- Collapse all currently visible panels
    if self.activeItemPanels then
        for _, panel in pairs(self.activeItemPanels) do
            if panel.isExpanded then
                self:ToggleItemPanelExpandedInternal(panel, true)
            end
        end
        self:RecalculateLayout()
    end
end

-- Incremental Panel Update Methods

-- Update a single panel without full recreation
function UIManager:UpdateSinglePanel(panel, lootItem)
    if not panel or not lootItem then
        ParallelLoot:DebugPrint("UIManager: UpdateSinglePanel called with invalid parameters")
        return false
    end
    
    ParallelLoot:DebugPrint("UIManager: Updating single panel for item", lootItem.id or "unknown")
    
    -- Preserve current expand state
    local wasExpanded = panel.isExpanded
    
    -- Update panel data while preserving visual state
    local oldLootItem = panel.lootItem
    panel.lootItem = lootItem
    
    -- Update visual elements without recreating the panel
    self:UpdateItemPanelData(panel, lootItem)
    
    -- Restore expand state if it was preserved
    if wasExpanded and not panel.isExpanded then
        self:ToggleItemPanelExpandedInternal(panel, true)
    elseif not wasExpanded and panel.isExpanded then
        self:ToggleItemPanelExpandedInternal(panel, true)
    end
    
    -- Update expanded content if panel is expanded
    if panel.isExpanded then
        self:UpdateExpandedContent(panel)
        
        -- Recalculate height in case roll data changed
        local expandedHeight = self:CalculateExpandedHeight(panel)
        local totalHeight = 80 + expandedHeight
        panel:SetHeight(totalHeight)
        panel.expandedContent:SetHeight(expandedHeight)
    end
    
    -- Update state tracking
    if lootItem.id then
        if not self.panelStates[lootItem.id] then
            self.panelStates[lootItem.id] = {}
        end
        self.panelStates[lootItem.id].isExpanded = panel.isExpanded
        self.panelStates[lootItem.id].lastUpdate = time()
        self.panelStates[lootItem.id].height = panel:GetHeight()
    end
    
    ParallelLoot:DebugPrint("UIManager: Single panel update completed for item", lootItem.id or "unknown")
    return true
end

-- Refresh specific panel data without affecting visual state
function UIManager:RefreshPanelData(itemId)
    if not itemId then
        ParallelLoot:DebugPrint("UIManager: RefreshPanelData called without itemId")
        return false
    end
    
    ParallelLoot:DebugPrint("UIManager: Refreshing panel data for item", itemId)
    
    -- Find the panel for this item
    local targetPanel = nil
    if self.activeItemPanels then
        for _, panel in pairs(self.activeItemPanels) do
            if panel.lootItem and panel.lootItem.id == itemId then
                targetPanel = panel
                break
            end
        end
    end
    
    if not targetPanel then
        ParallelLoot:DebugPrint("UIManager: No panel found for item", itemId)
        return false
    end
    
    -- Get updated item data
    local updatedItem = nil
    if self.currentTab == self.TABS.ACTIVE then
        local activeItems = ParallelLoot.LootManager:GetActiveItems() or {}
        for _, item in ipairs(activeItems) do
            if item.id == itemId then
                updatedItem = item
                break
            end
        end
    else
        local awardedItems = ParallelLoot.LootManager:GetAwardedItems() or {}
        for _, item in ipairs(awardedItems) do
            if item.id == itemId then
                updatedItem = item
                break
            end
        end
    end
    
    if not updatedItem then
        ParallelLoot:DebugPrint("UIManager: Updated item data not found for", itemId)
        return false
    end
    
    -- Update the panel with new data
    return self:UpdateSinglePanel(targetPanel, updatedItem)
end

-- Update panel data elements without affecting expand/collapse state
function UIManager:UpdateItemPanelData(panel, lootItem)
    if not panel or not lootItem then
        return
    end
    
    -- Update item icon
    if lootItem.icon then
        panel.icon:SetTexture(lootItem.icon)
    end
    
    -- Update item name with quality color
    local r, g, b = ParallelLoot.LootManager:GetQualityColor(lootItem.quality)
    panel.itemName:SetText(lootItem.itemLink or lootItem.itemName)
    panel.itemName:SetTextColor(r, g, b, 1)
    
    -- Update icon border color
    panel.iconBorder:SetVertexColor(r, g, b, 1)
    
    -- Update timer display
    self:UpdateItemPanelTimer(panel)
    
    -- Update category buttons
    self:UpdateCategoryButtons(panel)
    
    -- Update award button visibility
    self:UpdateAwardButton(panel)
    
    ParallelLoot:DebugPrint("UIManager: Panel data updated for item", lootItem.id or "unknown")
end

-- Placeholder for category buttons update (will be implemented in future tasks)
function UIManager:UpdateCategoryButtons(panel)
    -- This method will be implemented when category buttons are added
    -- For now, this is a placeholder to prevent errors
end

-- Z-Order Management Methods

-- Ensure proper frame levels for all panels to prevent overlap issues
function UIManager:EnsureProperFrameLevels()
    if not self.activeItemPanels then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Ensuring proper frame levels for", #self.activeItemPanels, "panels")
    
    -- Set consistent frame levels for all panels
    for i, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            -- Base panel level increases with index to prevent overlap
            local baseLevel = self.FRAME_LEVELS.BASE_PANEL + (i - 1)
            panel:SetFrameLevel(baseLevel)
            
            -- Ensure all child elements maintain proper relative levels
            self:UpdatePanelChildFrameLevels(panel, baseLevel)
            
            ParallelLoot:DebugPrint("UIManager: Set panel", i, "frame level to", baseLevel)
        end
    end
end

-- Update frame levels for all child elements of a panel
function UIManager:UpdatePanelChildFrameLevels(panel, baseLevel)
    if not panel then
        return
    end
    
    -- Update button frame levels
    if panel.expandButton then
        panel.expandButton:SetFrameLevel(baseLevel + self.FRAME_LEVELS.BUTTONS)
    end
    if panel.awardButton then
        panel.awardButton:SetFrameLevel(baseLevel + self.FRAME_LEVELS.BUTTONS)
    end
    if panel.revokeButton then
        panel.revokeButton:SetFrameLevel(baseLevel + self.FRAME_LEVELS.BUTTONS)
    end
    if panel.categoryContainer then
        panel.categoryContainer:SetFrameLevel(baseLevel + self.FRAME_LEVELS.BUTTONS)
    end
    
    -- Update expanded content frame level
    if panel.expandedContent then
        panel.expandedContent:SetFrameLevel(baseLevel + self.FRAME_LEVELS.EXPANDED_CONTENT)
    end
    
    -- Update texture draw layers (these are relative to their parent frame)
    self:UpdatePanelTextureDrawLayers(panel)
end

-- Update texture draw layers for proper visual layering
function UIManager:UpdatePanelTextureDrawLayers(panel)
    if not panel then
        return
    end
    
    -- Background textures
    if panel.bg then
        panel.bg:SetDrawLayer("BACKGROUND", self.FRAME_LEVELS.PANEL_BACKGROUND)
    end
    if panel.border then
        panel.border:SetDrawLayer("BORDER", self.FRAME_LEVELS.PANEL_BACKGROUND + 1)
    end
    if panel.innerBg then
        panel.innerBg:SetDrawLayer("BACKGROUND", self.FRAME_LEVELS.PANEL_BACKGROUND + 2)
    end
    
    -- Content textures
    if panel.icon then
        panel.icon:SetDrawLayer("ARTWORK", self.FRAME_LEVELS.PANEL_CONTENT)
    end
    if panel.progressBg then
        panel.progressBg:SetDrawLayer("BACKGROUND", self.FRAME_LEVELS.PANEL_CONTENT)
    end
    if panel.progressBar then
        panel.progressBar:SetDrawLayer("ARTWORK", self.FRAME_LEVELS.PANEL_CONTENT + 1)
    end
    
    -- Overlay elements
    if panel.iconBorder then
        panel.iconBorder:SetDrawLayer("OVERLAY", self.FRAME_LEVELS.PANEL_OVERLAY)
    end
    
    -- Font strings
    if panel.itemName then
        panel.itemName:SetDrawLayer("OVERLAY", self.FRAME_LEVELS.PANEL_CONTENT)
    end
    if panel.subtitle then
        panel.subtitle:SetDrawLayer("OVERLAY", self.FRAME_LEVELS.PANEL_CONTENT)
    end
    if panel.timerText then
        panel.timerText:SetDrawLayer("OVERLAY", self.FRAME_LEVELS.PANEL_CONTENT)
    end
end

-- Fix visual overlap issues during expand/collapse operations
function UIManager:FixVisualOverlapIssues()
    if not self.activeItemPanels then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Fixing visual overlap issues")
    
    -- Ensure proper frame levels
    self:EnsureProperFrameLevels()
    
    -- Force a layout recalculation to fix positioning
    self:RecalculateLayout()
    
    -- Validate that no overlaps remain
    local hasOverlaps = not self:ValidatePanelPositioning()
    if hasOverlaps then
        ParallelLoot:DebugPrint("UIManager: Overlaps detected after fix attempt, forcing full refresh")
        -- If overlaps persist, force a full refresh as last resort
        self:RefreshItemList()
    end
end

-- Ensure consistent layering for all panel elements
function UIManager:EnsureConsistentLayering()
    if not self.activeItemPanels then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Ensuring consistent layering for all panels")
    
    for i, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            -- Calculate base frame level for this panel
            local baseLevel = self.FRAME_LEVELS.BASE_PANEL + (i - 1)
            
            -- Update all frame levels for this panel
            self:UpdatePanelChildFrameLevels(panel, baseLevel)
            
            -- Ensure expanded content is properly layered when visible
            if panel.isExpanded and panel.expandedContent and panel.expandedContent:IsShown() then
                panel.expandedContent:SetFrameLevel(baseLevel + self.FRAME_LEVELS.EXPANDED_CONTENT)
                
                -- Update any child elements in expanded content
                self:UpdateExpandedContentLayering(panel.expandedContent, baseLevel)
            end
        end
    end
end

-- Update layering for expanded content child elements
function UIManager:UpdateExpandedContentLayering(expandedContent, baseLevel)
    if not expandedContent then
        return
    end
    
    -- This will be expanded when roll display elements are implemented
    -- For now, ensure any existing child elements have proper levels
    local children = { expandedContent:GetChildren() }
    for _, child in pairs(children) do
        if child.SetFrameLevel then
            child:SetFrameLevel(baseLevel + self.FRAME_LEVELS.EXPANDED_CONTENT + 1)
        end
    end
end

-- Panel Dimension Management Methods

-- Validate and fix panel dimensions for all active panels
function UIManager:ValidateAndFixPanelDimensions()
    if not self.activeItemPanels then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Validating and fixing panel dimensions for", #self.activeItemPanels, "panels")
    
    local fixedCount = 0
    for i, panel in pairs(self.activeItemPanels) do
        if panel:IsShown() then
            local needsFix = false
            
            -- Check width
            local width = panel:GetWidth()
            if not width or width <= 0 or width ~= width then
                needsFix = true
            end
            
            -- Check height
            local height = panel:GetHeight()
            if not height or height <= 0 or height ~= height then
                needsFix = true
            end
            
            -- Fix dimensions if needed
            if needsFix then
                local correctHeight = panel.isExpanded and (80 + self:CalculateExpandedHeight(panel)) or 80
                self:SetPanelDimensions(panel, 640, correctHeight)
                
                -- Update visual boundaries
                self:UpdatePanelVisualBoundaries(panel)
                
                fixedCount = fixedCount + 1
                ParallelLoot:DebugPrint("UIManager: Fixed dimensions for panel", i)
            end
        end
    end
    
    if fixedCount > 0 then
        ParallelLoot:DebugPrint("UIManager: Fixed dimensions for", fixedCount, "panels")
        -- Trigger layout recalculation after fixing dimensions
        self:RecalculateLayout()
    end
end

-- Ensure panels properly resize when expanding or collapsing
function UIManager:EnsurePanelResize(panel, newState)
    if not panel then
        return false
    end
    
    local targetHeight
    if newState == "expanded" then
        local expandedHeight = self:CalculateExpandedHeight(panel)
        targetHeight = 80 + expandedHeight
        
        -- Show and configure expanded content
        if panel.expandedContent then
            panel.expandedContent:Show()
            panel.expandedContent:SetHeight(expandedHeight)
        end
    else
        targetHeight = 80
        
        -- Hide expanded content properly
        if panel.expandedContent then
            self:EnsureExpandedContentHidden(panel)
        end
    end
    
    -- Apply new dimensions
    self:SetPanelDimensions(panel, 640, targetHeight)
    
    -- Update visual boundaries immediately
    self:UpdatePanelVisualBoundaries(panel)
    
    -- Verify the resize was successful
    local actualHeight = panel:GetHeight()
    if math.abs(actualHeight - targetHeight) > 1 then -- Allow 1px tolerance
        ParallelLoot:DebugPrint("UIManager: Panel resize verification failed - expected:", targetHeight, "actual:", actualHeight)
        return false
    end
    
    ParallelLoot:DebugPrint("UIManager: Panel resize successful to", targetHeight, "pixels")
    return true
end

-- Fix issue where roll lists disappear but panel dimensions don't change
function UIManager:FixRollListDisplayIssues(panel)
    if not panel or not panel.lootItem then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Fixing roll list display issues for panel")
    
    -- If panel is expanded, ensure expanded content is properly configured
    if panel.isExpanded then
        -- Recalculate expanded height based on current roll data
        local expandedHeight = self:CalculateExpandedHeight(panel)
        local totalHeight = 80 + expandedHeight
        
        -- Ensure expanded content is visible and properly sized
        if panel.expandedContent then
            panel.expandedContent:Show()
            panel.expandedContent:SetHeight(expandedHeight)
        end
        
        -- Update panel dimensions
        self:SetPanelDimensions(panel, 640, totalHeight)
        
        -- Update expanded content with current data
        self:UpdateExpandedContent(panel)
        
        -- Update visual boundaries
        self:UpdatePanelVisualBoundaries(panel)
        
        ParallelLoot:DebugPrint("UIManager: Fixed expanded panel dimensions and content")
    else
        -- If collapsed, ensure no remnant expanded content is visible
        self:EnsureExpandedContentHidden(panel)
        self:SetPanelDimensions(panel, 640, 80)
        
        ParallelLoot:DebugPrint("UIManager: Fixed collapsed panel dimensions")
    end
end

-- Immediate Roll Display Update Methods

-- Handle immediate roll addition to update affected panel
function UIManager:OnRollAdded(item, roll)
    if not item or not roll then
        ParallelLoot:DebugPrint("UIManager: OnRollAdded called with invalid parameters")
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Processing immediate roll update for item", item.id or "unknown", 
        "player:", roll.playerName, "value:", roll.rollValue, "category:", roll.category)
    
    -- Only update if main frame is visible
    if not self.mainFrame or not self.mainFrame:IsShown() then
        ParallelLoot:DebugPrint("UIManager: Main frame not visible, skipping immediate update")
        return
    end
    
    -- Only update if we're on the active items tab
    if self.currentTab ~= self.TABS.ACTIVE then
        ParallelLoot:DebugPrint("UIManager: Not on active tab, skipping immediate update")
        return
    end
    
    -- Ensure UI responsiveness
    self:EnsureUIResponsiveness()
    
    -- Find the panel for this item
    local targetPanel = self:FindPanelByItemId(item.id)
    if not targetPanel then
        ParallelLoot:DebugPrint("UIManager: No panel found for item", item.id or "unknown")
        return
    end
    
    -- Update the panel with new roll data immediately
    self:UpdateSinglePanel(targetPanel, item)
    
    -- If panel is expanded, update the expanded content immediately
    if targetPanel.isExpanded then
        self:UpdateExpandedContent(targetPanel)
        
        -- Recalculate height in case new roll data affects display
        local expandedHeight = self:CalculateExpandedHeight(targetPanel)
        local totalHeight = 80 + expandedHeight
        targetPanel:SetHeight(totalHeight)
        targetPanel.expandedContent:SetHeight(expandedHeight)
        
        -- Trigger layout recalculation since height may have changed
        self:TriggerLayoutUpdate()
    end
    
    -- Update category buttons to reflect new roll state
    self:UpdateCategoryButtons(targetPanel)
    
    -- Provide visual feedback for the new roll
    self:HighlightNewRoll(targetPanel, roll)
    
    ParallelLoot:DebugPrint("UIManager: Immediate roll update completed for item", item.id or "unknown")
end

-- Find panel by item ID
function UIManager:FindPanelByItemId(itemId)
    if not itemId or not self.activeItemPanels then
        return nil
    end
    
    for _, panel in pairs(self.activeItemPanels) do
        if panel.lootItem and panel.lootItem.id == itemId then
            return panel
        end
    end
    
    return nil
end

-- Highlight new roll with visual feedback
function UIManager:HighlightNewRoll(panel, roll)
    if not panel or not roll then
        return
    end
    
    -- Create a temporary highlight effect
    if not panel.rollHighlight then
        panel.rollHighlight = panel:CreateTexture(nil, "OVERLAY")
        panel.rollHighlight:SetAllPoints()
        panel.rollHighlight:SetColorTexture(0, 1, 0, 0.2) -- Green highlight
        panel.rollHighlight:Hide()
    end
    
    -- Show highlight briefly
    panel.rollHighlight:Show()
    
    -- Fade out the highlight after 2 seconds
    C_Timer.After(2, function()
        if panel.rollHighlight then
            panel.rollHighlight:Hide()
        end
    end)
    
    ParallelLoot:DebugPrint("UIManager: Applied roll highlight for", roll.playerName, "on item", 
        panel.lootItem and panel.lootItem.id or "unknown")
end

-- Event-Driven UI Update System

-- Setup event handlers for immediate UI updates
function UIManager:SetupEventHandlers()
    -- Create event frame for UI updates
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnUpdate", function(frame, elapsed)
            self:ProcessEventQueue(elapsed)
        end)
    end
    
    ParallelLoot:DebugPrint("UIManager: Event handlers initialized")
end

-- Queue an event for processing with throttling
function UIManager:QueueUIEvent(eventType, data, priority)
    local currentTime = GetTime()
    
    -- Create event entry
    local event = {
        type = eventType,
        data = data,
        priority = priority or 1,
        timestamp = currentTime
    }
    
    -- Add to queue
    table.insert(self.eventQueue, event)
    
    -- Sort by priority (higher priority first)
    table.sort(self.eventQueue, function(a, b)
        if a.priority == b.priority then
            return a.timestamp < b.timestamp
        end
        return a.priority > b.priority
    end)
    
    ParallelLoot:DebugPrint("UIManager: Queued UI event:", eventType, "priority:", priority)
end

-- Process queued events with throttling
function UIManager:ProcessEventQueue(elapsed)
    if not self.eventQueue or #self.eventQueue == 0 then
        return
    end
    
    local currentTime = GetTime()
    
    -- Throttle event processing
    if currentTime - self.lastEventTime < self.eventThrottleDelay then
        return
    end
    
    -- Prevent recursive processing
    if self.eventProcessing then
        return
    end
    
    self.eventProcessing = true
    
    -- Process one event per frame to maintain responsiveness
    local event = table.remove(self.eventQueue, 1)
    if event then
        self:ProcessUIEvent(event)
        self.lastEventTime = currentTime
    end
    
    self.eventProcessing = false
end

-- Process individual UI events
function UIManager:ProcessUIEvent(event)
    if not event or not event.type then
        return
    end
    
    ParallelLoot:DebugPrint("UIManager: Processing UI event:", event.type)
    
    -- Wrap in pcall for error protection
    local success, err = pcall(function()
        if event.type == "ROLL_ADDED" then
            self:HandleRollAddedEvent(event.data)
        elseif event.type == "ITEM_UPDATED" then
            self:HandleItemUpdatedEvent(event.data)
        elseif event.type == "PANEL_STATE_CHANGED" then
            self:HandlePanelStateChangedEvent(event.data)
        elseif event.type == "LAYOUT_RECALC" then
            self:HandleLayoutRecalcEvent(event.data)
        elseif event.type == "TIMER_UPDATE" then
            self:HandleTimerUpdateEvent(event.data)
        else
            ParallelLoot:DebugPrint("UIManager: Unknown event type:", event.type)
        end
    end)
    
    if not success then
        ParallelLoot:DebugPrint("UIManager: Error processing event", event.type, ":", err)
        -- Continue processing other events despite errors
    end
end

-- Handle roll added events
function UIManager:HandleRollAddedEvent(data)
    if not data or not data.item or not data.roll then
        return
    end
    
    -- Trigger immediate roll display update
    self:OnRollAdded(data.item, data.roll)
end

-- Handle item updated events
function UIManager:HandleItemUpdatedEvent(data)
    if not data or not data.itemId then
        return
    end
    
    -- Refresh specific panel data
    self:RefreshPanelData(data.itemId)
end

-- Handle panel state changed events
function UIManager:HandlePanelStateChangedEvent(data)
    if not data or not data.panel then
        return
    end
    
    -- Trigger layout recalculation
    self:UpdatePanelPositions()
end

-- Handle layout recalculation events
function UIManager:HandleLayoutRecalcEvent(data)
    -- Force layout recalculation
    self:RecalculateLayout()
end

-- Handle timer update events
function UIManager:HandleTimerUpdateEvent(data)
    if not data or not data.itemId then
        -- Update all timer displays
        self:RefreshTimerDisplays()
    else
        -- Update specific item timer
        local panel = self:FindPanelByItemId(data.itemId)
        if panel then
            self:UpdateItemPanelTimer(panel)
        end
    end
end

-- Public methods to trigger immediate UI updates

-- Trigger immediate UI update for roll addition
function UIManager:TriggerRollUpdate(item, roll)
    self:QueueUIEvent("ROLL_ADDED", {
        item = item,
        roll = roll
    }, 3) -- High priority
end

-- Trigger immediate UI update for item changes
function UIManager:TriggerItemUpdate(itemId)
    self:QueueUIEvent("ITEM_UPDATED", {
        itemId = itemId
    }, 2) -- Medium priority
end

-- Trigger immediate UI update for panel state changes
function UIManager:TriggerPanelStateUpdate(panel)
    self:QueueUIEvent("PANEL_STATE_CHANGED", {
        panel = panel
    }, 2) -- Medium priority
end

-- Trigger layout recalculation
function UIManager:TriggerLayoutUpdate()
    self:QueueUIEvent("LAYOUT_RECALC", {}, 1) -- Normal priority
end

-- Trigger timer display updates
function UIManager:TriggerTimerUpdate(itemId)
    self:QueueUIEvent("TIMER_UPDATE", {
        itemId = itemId
    }, 1) -- Normal priority
end

-- Event sequencing and race condition prevention

-- Ensure proper event sequencing for complex operations
function UIManager:SequenceEvents(events)
    if not events or #events == 0 then
        return
    end
    
    -- Add events with decreasing priority to ensure proper order
    for i, event in ipairs(events) do
        local priority = 10 - i -- Higher index = lower priority
        self:QueueUIEvent(event.type, event.data, priority)
    end
    
    ParallelLoot:DebugPrint("UIManager: Sequenced", #events, "events")
end

-- Prevent race conditions by clearing conflicting events
function UIManager:ClearConflictingEvents(eventType)
    if not self.eventQueue then
        return
    end
    
    local removedCount = 0
    for i = #self.eventQueue, 1, -1 do
        if self.eventQueue[i].type == eventType then
            table.remove(self.eventQueue, i)
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        ParallelLoot:DebugPrint("UIManager: Cleared", removedCount, "conflicting events of type:", eventType)
    end
end

-- Ensure UI responsiveness during data changes
function UIManager:EnsureUIResponsiveness()
    -- Limit queue size to prevent UI lag
    local maxQueueSize = 50
    if #self.eventQueue > maxQueueSize then
        -- Remove oldest low-priority events
        local removed = 0
        for i = #self.eventQueue, 1, -1 do
            if self.eventQueue[i].priority <= 1 then
                table.remove(self.eventQueue, i)
                removed = removed + 1
                if #self.eventQueue <= maxQueueSize then
                    break
                end
            end
        end
        
        if removed > 0 then
            ParallelLoot:DebugPrint("UIManager: Removed", removed, "low-priority events to maintain responsiveness")
        end
    end
    
    -- Adjust throttle delay based on queue size
    if #self.eventQueue > 20 then
        self.eventThrottleDelay = 0.05 -- Faster processing when queue is large
    elseif #self.eventQueue > 10 then
        self.eventThrottleDelay = 0.075
    else
        self.eventThrottleDelay = 0.1 -- Normal processing
    end
end

-- Update category buttons immediately when rolls are added
function UIManager:UpdateCategoryButtonsForRoll(panel, roll)
    if not panel or not roll then
        return
    end
    
    -- This will be expanded when category buttons are implemented
    -- For now, just update the general category buttons
    self:UpdateCategoryButtons(panel)
    
    ParallelLoot:DebugPrint("UIManager: Updated category buttons for new roll:", roll.category)
end
