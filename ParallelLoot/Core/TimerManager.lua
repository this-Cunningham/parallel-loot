-- ParallelLoot Timer Manager
-- Handles countdown timers for tradeable item expiration

local TimerManager = ParallelLoot.TimerManager or {}
ParallelLoot.TimerManager = TimerManager

-- Timer update frame
local timerUpdateFrame = CreateFrame("Frame")
local timeSinceLastUpdate = 0
local UPDATE_INTERVAL = 0.5 -- Update every 0.5 seconds
local timeSinceLastCleanup = 0
local CLEANUP_INTERVAL = 5 -- Check for expired items every 5 seconds

-- Active timers table
TimerManager.activeTimers = {}

-- Initialize the timer manager
function TimerManager:Initialize()
    ParallelLoot:DebugPrint("TimerManager: Initializing")
    
    -- Set up timer update loop
    timerUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
        TimerManager:OnUpdate(elapsed)
    end)
    
    ParallelLoot:DebugPrint("TimerManager: Initialized")
end

-- Main update loop
function TimerManager:OnUpdate(elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    timeSinceLastCleanup = timeSinceLastCleanup + elapsed
    
    -- Update timers at specified interval
    if timeSinceLastUpdate >= UPDATE_INTERVAL then
        timeSinceLastUpdate = 0
        self:UpdateAllTimers()
    end
    
    -- Perform cleanup and warning checks at specified interval
    if timeSinceLastCleanup >= CLEANUP_INTERVAL then
        timeSinceLastCleanup = 0
        self:PerformAutoCleanup()
    end
end

-- Update all active timers
function TimerManager:UpdateAllTimers()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return
    end
    
    local currentTime = time()
    
    -- Update timers for active items
    for _, item in ipairs(session.activeItems) do
        self:UpdateItemTimer(item, currentTime)
    end
    
    -- Notify UI to refresh timer displays
    if ParallelLoot.UIManager.RefreshTimerDisplays then
        ParallelLoot.UIManager:RefreshTimerDisplays()
    end
end

-- Update timer for a specific item
function TimerManager:UpdateItemTimer(item, currentTime)
    if not item or not item.expiryTime then
        return
    end
    
    currentTime = currentTime or time()
    local timeRemaining = item.expiryTime - currentTime
    
    -- Store timer info
    if not self.activeTimers[item.id] then
        self.activeTimers[item.id] = {}
    end
    
    local timer = self.activeTimers[item.id]
    timer.timeRemaining = math.max(0, timeRemaining)
    timer.isExpired = timeRemaining <= 0
    timer.lastUpdate = currentTime
    
    return timer
end

-- Get time remaining for an item
function TimerManager:GetTimeRemaining(item)
    if not item or not item.expiryTime then
        return 0
    end
    
    local currentTime = time()
    local timeRemaining = item.expiryTime - currentTime
    return math.max(0, timeRemaining)
end

-- Check if item is expired
function TimerManager:IsItemExpired(item)
    if not item or not item.expiryTime then
        return true
    end
    
    return time() >= item.expiryTime
end

-- Get progress percentage (0.0 to 1.0)
function TimerManager:GetProgressPercentage(item)
    if not item or not item.expiryTime or not item.dropTime then
        return 0
    end
    
    local currentTime = time()
    local totalTime = item.expiryTime - item.dropTime
    local elapsed = currentTime - item.dropTime
    
    if totalTime <= 0 then
        return 0
    end
    
    local progress = 1.0 - (elapsed / totalTime)
    return math.max(0, math.min(1.0, progress))
end

-- Format time remaining as HH:MM:SS or MM:SS
function TimerManager:FormatTimeRemaining(seconds)
    if seconds <= 0 then
        return "0:00"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    -- Check user preference for showing hours
    local showHours = ParallelLoot.DataManager:GetSetting("showHoursInTimer")
    if showHours == nil then
        showHours = true -- Default to showing hours
    end
    
    if hours > 0 and showHours then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        -- If not showing hours, add hours to minutes
        if hours > 0 and not showHours then
            minutes = minutes + (hours * 60)
        end
        return string.format("%d:%02d", minutes, secs)
    end
end

-- Format time ago (for awarded items)
function TimerManager:FormatTimeAgo(seconds)
    if seconds < 60 then
        return "just now"
    end
    
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local days = math.floor(hours / 24)
    
    if days > 0 then
        return string.format("%d day%s ago", days, days > 1 and "s" or "")
    elseif hours > 0 then
        return string.format("%d hour%s ago", hours, hours > 1 and "s" or "")
    else
        return string.format("%d minute%s ago", minutes, minutes > 1 and "s" or "")
    end
end

-- Get timer color based on time remaining
function TimerManager:GetTimerColor(timeRemaining)
    local settings = ParallelLoot.DataManager:GetSetting("timerWarnings") or {300, 60}
    local warningThreshold = settings[1] or 300 -- 5 minutes default
    local criticalThreshold = settings[2] or 60 -- 1 minute default
    
    if timeRemaining <= criticalThreshold then
        return 1, 0, 0, 1 -- Red (critical)
    elseif timeRemaining <= warningThreshold then
        return 1, 0.5, 0, 1 -- Orange (warning)
    else
        return 1, 1, 1, 1 -- White (normal)
    end
end

-- Get progress bar color based on time remaining
function TimerManager:GetProgressBarColor(timeRemaining)
    local settings = ParallelLoot.DataManager:GetSetting("timerWarnings") or {300, 60}
    local warningThreshold = settings[1] or 300
    local criticalThreshold = settings[2] or 60
    
    if timeRemaining <= criticalThreshold then
        -- Red gradient for critical
        return CreateColor(1, 0, 0, 1), CreateColor(0.8, 0, 0, 1)
    elseif timeRemaining <= warningThreshold then
        -- Orange gradient for warning
        return CreateColor(1, 0.5, 0, 1), CreateColor(1, 0.3, 0, 1)
    else
        -- Green/yellow gradient for normal
        return CreateColor(0.2, 1, 0.2, 1), CreateColor(1, 0.8, 0, 1)
    end
end

-- Start timer for an item
function TimerManager:StartTimer(item)
    if not item or not item.id then
        return false
    end
    
    ParallelLoot:DebugPrint("TimerManager: Starting timer for item:", item.itemName or item.id)
    
    -- Initialize timer data
    self.activeTimers[item.id] = {
        itemId = item.id,
        startTime = time(),
        expiryTime = item.expiryTime,
        timeRemaining = self:GetTimeRemaining(item),
        isExpired = false,
        lastUpdate = time()
    }
    
    return true
end

-- Stop timer for an item
function TimerManager:StopTimer(itemId)
    if not itemId then
        return false
    end
    
    ParallelLoot:DebugPrint("TimerManager: Stopping timer for item:", itemId)
    
    self.activeTimers[itemId] = nil
    return true
end

-- Clear all timers
function TimerManager:ClearAllTimers()
    ParallelLoot:DebugPrint("TimerManager: Clearing all timers")
    self.activeTimers = {}
end

-- Get timer info for an item
function TimerManager:GetTimerInfo(itemId)
    return self.activeTimers[itemId]
end

-- Get all active timer info
function TimerManager:GetAllTimerInfo()
    return self.activeTimers
end

-- Check if timer warnings should be shown
function TimerManager:ShouldShowWarning(item)
    local timeRemaining = self:GetTimeRemaining(item)
    local settings = ParallelLoot.DataManager:GetSetting("timerWarnings") or {300, 60}
    local warningThreshold = settings[1] or 300
    
    return timeRemaining > 0 and timeRemaining <= warningThreshold
end

-- Check if timer is in critical state
function TimerManager:IsTimerCritical(item)
    local timeRemaining = self:GetTimeRemaining(item)
    local settings = ParallelLoot.DataManager:GetSetting("timerWarnings") or {300, 60}
    local criticalThreshold = settings[2] or 60
    
    return timeRemaining > 0 and timeRemaining <= criticalThreshold
end

-- Get formatted timer display text
function TimerManager:GetTimerDisplayText(item)
    if not item then
        return ""
    end
    
    -- Check if item is awarded
    if item.awardedTo then
        local timeSinceAward = time() - (item.awardTime or time())
        return string.format("Awarded %s", self:FormatTimeAgo(timeSinceAward))
    end
    
    -- Check if expired
    if self:IsItemExpired(item) then
        return "Expired"
    end
    
    -- Show time remaining
    local timeRemaining = self:GetTimeRemaining(item)
    return string.format("Tradeable for %s", self:FormatTimeRemaining(timeRemaining))
end

-- Sync timers with session data
function TimerManager:SyncWithSession()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        self:ClearAllTimers()
        return
    end
    
    -- Remove timers for items no longer in session
    local validItemIds = {}
    for _, item in ipairs(session.activeItems) do
        validItemIds[item.id] = true
    end
    
    for itemId in pairs(self.activeTimers) do
        if not validItemIds[itemId] then
            self:StopTimer(itemId)
        end
    end
    
    -- Start timers for new items
    for _, item in ipairs(session.activeItems) do
        if not self.activeTimers[item.id] then
            self:StartTimer(item)
        end
    end
end

-- ============================================================================
-- EXPIRATION HANDLING
-- ============================================================================

-- Check for expired items and handle them
function TimerManager:CheckExpiredItems()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return 0
    end
    
    local currentTime = time()
    local expiredItems = {}
    
    -- Find expired items
    for i, item in ipairs(session.activeItems) do
        if self:IsItemExpired(item) and not item.awardedTo then
            table.insert(expiredItems, {item = item, index = i})
        end
    end
    
    -- Remove expired items (in reverse order to maintain indices)
    for i = #expiredItems, 1, -1 do
        local expiredData = expiredItems[i]
        self:HandleExpiredItem(expiredData.item, expiredData.index)
    end
    
    return #expiredItems
end

-- Handle a single expired item
function TimerManager:HandleExpiredItem(item, index)
    ParallelLoot:DebugPrint("TimerManager: Item expired:", item.itemName or item.id)
    
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return false
    end
    
    -- Show expiration notification
    self:ShowExpirationNotification(item)
    
    -- Play expiration sound if enabled
    self:PlayExpirationSound()
    
    -- Recycle the roll range
    if item.rollRange then
        ParallelLoot.DataManager:RecycleRollRange(session, item.rollRange)
    end
    
    -- Stop the timer
    self:StopTimer(item.id)
    
    -- Remove from active items
    if index then
        table.remove(session.activeItems, index)
    else
        -- Find and remove if index not provided
        for i, sessionItem in ipairs(session.activeItems) do
            if sessionItem.id == item.id then
                table.remove(session.activeItems, i)
                break
            end
        end
    end
    
    -- Save session
    ParallelLoot.DataManager:SaveCurrentSession(session)
    
    -- Notify UI to refresh
    if ParallelLoot.UIManager.OnItemExpired then
        ParallelLoot.UIManager:OnItemExpired(item)
    elseif ParallelLoot.UIManager.Refresh then
        ParallelLoot.UIManager:Refresh()
    end
    
    return true
end

-- Show expiration notification
function TimerManager:ShowExpirationNotification(item)
    if not item then
        return
    end
    
    local itemName = item.itemLink or item.itemName or "Unknown Item"
    ParallelLoot:Print(string.format("Item expired and removed: %s", itemName))
    
    -- Show UI notification if available
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(string.format("Loot Expired: %s", itemName), 1.0, 0.5, 0.0, 1.0, 5)
    end
end

-- Play expiration sound
function TimerManager:PlayExpirationSound()
    local soundEnabled = ParallelLoot.DataManager:GetSetting("soundEnabled")
    if soundEnabled == false then
        return
    end
    
    -- Play a warning sound (using WoW's built-in sounds)
    PlaySound(SOUNDKIT.RAID_WARNING, "Master")
end

-- Check for items approaching expiration and show warnings
function TimerManager:CheckExpirationWarnings()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return
    end
    
    local currentTime = time()
    local settings = ParallelLoot.DataManager:GetSetting("timerWarnings") or {300, 60}
    local warningThreshold = settings[1] or 300 -- 5 minutes
    local criticalThreshold = settings[2] or 60 -- 1 minute
    
    for _, item in ipairs(session.activeItems) do
        if not item.awardedTo then
            local timeRemaining = self:GetTimeRemaining(item)
            local timer = self.activeTimers[item.id]
            
            if timer then
                -- Check for warning threshold
                if timeRemaining <= warningThreshold and timeRemaining > criticalThreshold then
                    if not timer.warningShown then
                        self:ShowWarningNotification(item, timeRemaining, "warning")
                        timer.warningShown = true
                    end
                end
                
                -- Check for critical threshold
                if timeRemaining <= criticalThreshold and timeRemaining > 0 then
                    if not timer.criticalShown then
                        self:ShowWarningNotification(item, timeRemaining, "critical")
                        timer.criticalShown = true
                    end
                end
            end
        end
    end
end

-- Show warning notification
function TimerManager:ShowWarningNotification(item, timeRemaining, level)
    if not item then
        return
    end
    
    local itemName = item.itemLink or item.itemName or "Unknown Item"
    local timeText = self:FormatTimeRemaining(timeRemaining)
    
    if level == "critical" then
        ParallelLoot:Print(string.format("|cFFFF0000WARNING:|r Item expiring soon: %s (%s remaining)", itemName, timeText))
        
        -- Play warning sound
        if ParallelLoot.DataManager:GetSetting("soundEnabled") ~= false then
            PlaySound(SOUNDKIT.RAID_WARNING, "Master")
        end
        
        -- Show UI warning
        if RaidWarningFrame then
            RaidWarningFrame:Show()
            RaidWarningFrame.slot1:SetText(string.format("Loot Expiring: %s", timeText))
        end
    elseif level == "warning" then
        ParallelLoot:Print(string.format("|cFFFF8800Notice:|r Item expiring: %s (%s remaining)", itemName, timeText))
        
        -- Play softer warning sound
        if ParallelLoot.DataManager:GetSetting("soundEnabled") ~= false then
            PlaySound(SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING, "Master")
        end
    end
end

-- Cleanup expired items from session
function TimerManager:CleanupExpiredItems()
    local removed = self:CheckExpiredItems() or 0
    
    if removed > 0 then
        ParallelLoot:DebugPrint("TimerManager: Cleaned up", removed, "expired items")
    end
    
    return removed
end

-- Auto-cleanup task (called periodically)
function TimerManager:PerformAutoCleanup()
    -- Check for expired items
    self:CleanupExpiredItems()
    
    -- Check for expiration warnings
    self:CheckExpirationWarnings()
end

ParallelLoot:DebugPrint("TimerManager.lua loaded")
