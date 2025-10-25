-- ParallelLoot Error Handler
-- Comprehensive error handling and recovery mechanisms

local ErrorHandler = {}
ParallelLoot.ErrorHandler = ErrorHandler

-- Error log storage
ErrorHandler.errorLog = {}
ErrorHandler.maxLogSize = 100

-- Error categories
ErrorHandler.CATEGORIES = {
    NETWORK = "Network",
    DATA = "Data",
    UI = "UI",
    VALIDATION = "Validation",
    PERMISSION = "Permission",
    SYSTEM = "System"
}

-- Error severity levels
ErrorHandler.SEVERITY = {
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    CRITICAL = 4
}

-- ============================================================================
-- ERROR LOGGING
-- ============================================================================

-- Log an error
function ErrorHandler:LogError(category, severity, message, context)
    local error = {
        category = category or self.CATEGORIES.SYSTEM,
        severity = severity or self.SEVERITY.ERROR,
        message = message or "Unknown error",
        context = context or {},
        timestamp = time(),
        stackTrace = debugstack(2)
    }
    
    table.insert(self.errorLog, error)
    
    -- Trim log if too large
    while #self.errorLog > self.maxLogSize do
        table.remove(self.errorLog, 1)
    end
    
    -- Print to chat based on severity
    if severity >= self.SEVERITY.ERROR then
        ParallelLoot:Print("|cFFFF0000[ERROR]|r", message)
    elseif severity == self.SEVERITY.WARNING then
        ParallelLoot:DebugPrint("|cFFFFFF00[WARNING]|r", message)
    end
    
    -- Log to debug
    ParallelLoot:DebugPrint(string.format("[%s] %s: %s", category, self:GetSeverityName(severity), message))
    
    return error
end

-- Get severity name
function ErrorHandler:GetSeverityName(severity)
    for name, value in pairs(self.SEVERITY) do
        if value == severity then
            return name
        end
    end
    return "UNKNOWN"
end

-- Get error log
function ErrorHandler:GetErrorLog()
    return self.errorLog
end

-- Clear error log
function ErrorHandler:ClearErrorLog()
    self.errorLog = {}
    ParallelLoot:Print("Error log cleared")
end

-- Get recent errors
function ErrorHandler:GetRecentErrors(count)
    count = count or 10
    local recent = {}
    local startIndex = math.max(1, #self.errorLog - count + 1)
    
    for i = startIndex, #self.errorLog do
        table.insert(recent, self.errorLog[i])
    end
    
    return recent
end

-- ============================================================================
-- SAFE FUNCTION EXECUTION
-- ============================================================================

-- Execute function with error handling
function ErrorHandler:SafeCall(func, category, context, ...)
    if type(func) ~= "function" then
        self:LogError(category or self.CATEGORIES.SYSTEM, self.SEVERITY.ERROR, 
            "SafeCall: Not a function", context)
        return false, "Not a function"
    end
    
    local success, result = pcall(func, ...)
    
    if not success then
        self:LogError(category or self.CATEGORIES.SYSTEM, self.SEVERITY.ERROR, 
            "Function execution failed: " .. tostring(result), context)
        return false, result
    end
    
    return true, result
end

-- Execute function with retry logic
function ErrorHandler:SafeCallWithRetry(func, maxRetries, delay, category, context, ...)
    maxRetries = maxRetries or 3
    delay = delay or 1
    
    local attempts = 0
    local success, result
    
    while attempts < maxRetries do
        attempts = attempts + 1
        success, result = self:SafeCall(func, category, context, ...)
        
        if success then
            return true, result
        end
        
        if attempts < maxRetries then
            ParallelLoot:DebugPrint(string.format("Retry attempt %d/%d after %ds", 
                attempts, maxRetries, delay))
            C_Timer.After(delay, function() end)
        end
    end
    
    self:LogError(category or self.CATEGORIES.SYSTEM, self.SEVERITY.ERROR, 
        string.format("Function failed after %d attempts", maxRetries), context)
    
    return false, result
end

-- ============================================================================
-- NETWORK ERROR HANDLING
-- ============================================================================

-- Handle network communication failure
function ErrorHandler:HandleNetworkError(operation, error, context)
    self:LogError(self.CATEGORIES.NETWORK, self.SEVERITY.WARNING, 
        string.format("Network error during %s: %s", operation, error), context)
    
    -- Attempt recovery based on operation
    if operation == "sync" then
        self:RecoverFromSyncFailure(context)
    elseif operation == "broadcast" then
        self:RecoverFromBroadcastFailure(context)
    end
end

-- Recover from sync failure
function ErrorHandler:RecoverFromSyncFailure(context)
    ParallelLoot:DebugPrint("ErrorHandler: Attempting sync recovery")
    
    -- Queue a retry after delay
    C_Timer.After(5, function()
        if ParallelLoot.CommManager and ParallelLoot.CommManager.RequestSync then
            ParallelLoot.CommManager:RequestSync()
        end
    end)
end

-- Recover from broadcast failure
function ErrorHandler:RecoverFromBroadcastFailure(context)
    ParallelLoot:DebugPrint("ErrorHandler: Broadcast failed, message may be queued")
    
    -- Message will be queued by CommManager for offline players
    -- No additional action needed
end

-- Check network connectivity
function ErrorHandler:CheckNetworkConnectivity()
    if not IsInRaid() and not IsInGroup() then
        return false, "Not in a raid or party"
    end
    
    -- Check if we can communicate
    local canCommunicate = true
    local reason = nil
    
    -- Additional checks can be added here
    
    return canCommunicate, reason
end

-- ============================================================================
-- DATA ERROR HANDLING
-- ============================================================================

-- Handle data corruption
function ErrorHandler:HandleDataCorruption(dataType, error, context)
    self:LogError(self.CATEGORIES.DATA, self.SEVERITY.CRITICAL, 
        string.format("Data corruption detected in %s: %s", dataType, error), context)
    
    -- Attempt recovery
    if dataType == "session" then
        return self:RecoverCorruptedSession(context)
    elseif dataType == "settings" then
        return self:RecoverCorruptedSettings(context)
    end
    
    return false
end

-- Recover corrupted session
function ErrorHandler:RecoverCorruptedSession(context)
    ParallelLoot:Print("Attempting to recover corrupted session data...")
    
    local session = context.session
    if not session then
        ParallelLoot:Print("Cannot recover: No session data provided")
        return false
    end
    
    -- Use DataManager's recovery function
    local recovered = ParallelLoot.DataManager:RecoverSession(session)
    
    if recovered then
        ParallelLoot.DataManager:SetCurrentSession(recovered)
        ParallelLoot:Print("Session data recovered successfully")
        return true
    else
        ParallelLoot:Print("Failed to recover session data. Starting fresh session.")
        ParallelLoot.DataManager:ClearCurrentSession()
        return false
    end
end

-- Recover corrupted settings
function ErrorHandler:RecoverCorruptedSettings(context)
    ParallelLoot:Print("Resetting corrupted settings to defaults...")
    
    -- Reset to defaults
    if ParallelLoot.DataManager and ParallelLoot.DataManager.ResetDatabase then
        ParallelLoot.DataManager:ResetDatabase()
        ParallelLoot:Print("Settings reset to defaults")
        return true
    end
    
    return false
end

-- Validate data integrity
function ErrorHandler:ValidateDataIntegrity(data, dataType)
    if not data then
        return false, "Data is nil"
    end
    
    if type(data) ~= "table" then
        return false, "Data is not a table"
    end
    
    -- Type-specific validation
    if dataType == "session" then
        return ParallelLoot.DataManager.LootSession:Validate(data)
    elseif dataType == "item" then
        return ParallelLoot.DataManager.LootItem:Validate(data)
    elseif dataType == "roll" then
        return ParallelLoot.DataManager.PlayerRoll:Validate(data)
    end
    
    return true
end

-- ============================================================================
-- UI ERROR HANDLING
-- ============================================================================

-- Handle UI error
function ErrorHandler:HandleUIError(component, error, context)
    self:LogError(self.CATEGORIES.UI, self.SEVERITY.WARNING, 
        string.format("UI error in %s: %s", component, error), context)
    
    -- Attempt to refresh UI
    if ParallelLoot.UIManager and ParallelLoot.UIManager.Refresh then
        self:SafeCall(function()
            ParallelLoot.UIManager:Refresh()
        end, self.CATEGORIES.UI, {component = component})
    end
end

-- Safe UI update
function ErrorHandler:SafeUIUpdate(updateFunc, component)
    return self:SafeCall(updateFunc, self.CATEGORIES.UI, {component = component})
end

-- Recover from UI freeze
function ErrorHandler:RecoverFromUIFreeze()
    ParallelLoot:DebugPrint("ErrorHandler: Attempting UI recovery")
    
    -- Hide and show main frame
    if ParallelLoot.UIManager and ParallelLoot.UIManager.mainFrame then
        local wasShown = ParallelLoot.UIManager.mainFrame:IsShown()
        
        ParallelLoot.UIManager:HideMainFrame()
        
        C_Timer.After(0.5, function()
            if wasShown then
                ParallelLoot.UIManager:ShowMainFrame()
            end
        end)
    end
end

-- ============================================================================
-- VALIDATION ERROR HANDLING
-- ============================================================================

-- Handle validation error
function ErrorHandler:HandleValidationError(field, value, expectedType, context)
    local message = string.format("Validation failed for %s: expected %s, got %s", 
        field, expectedType, type(value))
    
    self:LogError(self.CATEGORIES.VALIDATION, self.SEVERITY.WARNING, message, context)
    
    return false, message
end

-- Validate required fields
function ErrorHandler:ValidateRequiredFields(data, requiredFields, dataType)
    if not data or type(data) ~= "table" then
        return false, "Data is not a table"
    end
    
    for _, field in ipairs(requiredFields) do
        if data[field] == nil then
            return self:HandleValidationError(field, nil, "required", {dataType = dataType})
        end
    end
    
    return true
end

-- Validate field type
function ErrorHandler:ValidateFieldType(data, field, expectedType)
    if data[field] == nil then
        return false, field .. " is nil"
    end
    
    if type(data[field]) ~= expectedType then
        return self:HandleValidationError(field, data[field], expectedType, {})
    end
    
    return true
end

-- ============================================================================
-- PERMISSION ERROR HANDLING
-- ============================================================================

-- Handle permission error
function ErrorHandler:HandlePermissionError(action, player, context)
    local message = string.format("Permission denied: %s cannot %s", player or "Player", action)
    
    self:LogError(self.CATEGORIES.PERMISSION, self.SEVERITY.WARNING, message, context)
    
    ParallelLoot:Print(message)
    return false, message
end

-- Validate permission
function ErrorHandler:ValidatePermission(action, requireLootMaster)
    if requireLootMaster == nil then
        requireLootMaster = true
    end
    
    if requireLootMaster and not ParallelLoot.LootMasterManager:IsPlayerLootMaster() then
        return self:HandlePermissionError(action, UnitName("player"), {})
    end
    
    return true
end

-- ============================================================================
-- SYSTEM ERROR HANDLING
-- ============================================================================

-- Handle critical system error
function ErrorHandler:HandleCriticalError(error, context)
    self:LogError(self.CATEGORIES.SYSTEM, self.SEVERITY.CRITICAL, 
        "Critical error: " .. tostring(error), context)
    
    ParallelLoot:Print("|cFFFF0000CRITICAL ERROR:|r", error)
    ParallelLoot:Print("Please reload your UI (/reload) or restart the game")
    
    -- Attempt to save current state
    if ParallelLoot.DataManager and ParallelLoot.DataManager.SaveData then
        self:SafeCall(function()
            ParallelLoot.DataManager:SaveData()
        end, self.CATEGORIES.SYSTEM, {operation = "emergency_save"})
    end
end

-- Handle addon initialization error
function ErrorHandler:HandleInitializationError(component, error)
    self:LogError(self.CATEGORIES.SYSTEM, self.SEVERITY.CRITICAL, 
        string.format("Failed to initialize %s: %s", component, error), {})
    
    ParallelLoot:Print(string.format("Failed to initialize %s. Addon may not function correctly.", component))
end

-- Check addon health
function ErrorHandler:CheckAddonHealth()
    local issues = {}
    
    -- Check if core components are initialized
    if not ParallelLoot.isInitialized then
        table.insert(issues, "Addon not initialized")
    end
    
    if not ParallelLoot.DataManager then
        table.insert(issues, "DataManager missing")
    end
    
    if not ParallelLoot.UIManager then
        table.insert(issues, "UIManager missing")
    end
    
    if not ParallelLoot.CommManager then
        table.insert(issues, "CommManager missing")
    end
    
    -- Check database
    if not ParallelLootDB then
        table.insert(issues, "Database not initialized")
    end
    
    if #issues > 0 then
        self:LogError(self.CATEGORIES.SYSTEM, self.SEVERITY.ERROR, 
            "Addon health check failed", {issues = issues})
        return false, issues
    end
    
    return true, {}
end

-- ============================================================================
-- EDGE CASE HANDLING
-- ============================================================================

-- Handle empty session
function ErrorHandler:HandleEmptySession()
    ParallelLoot:DebugPrint("ErrorHandler: Handling empty session")
    
    -- Check if we should auto-start a session
    local settings = ParallelLoot.DataManager:GetSetting("autoStart")
    
    if settings and ParallelLoot.LootMasterManager:IsPlayerLootMaster() then
        ParallelLoot:Print("Auto-starting loot session...")
        ParallelLoot.Integration:StartSession()
    else
        ParallelLoot:Print("No active session. Use /ploot start to begin.")
    end
end

-- Handle disconnected player
function ErrorHandler:HandleDisconnectedPlayer(playerName)
    ParallelLoot:DebugPrint("ErrorHandler: Player disconnected:", playerName)
    
    -- Messages will be queued by CommManager
    -- No additional action needed
end

-- Handle expired item
function ErrorHandler:HandleExpiredItem(item)
    ParallelLoot:DebugPrint("ErrorHandler: Item expired:", item.itemName)
    
    -- Clean up from session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        ParallelLoot.DataManager:CleanupExpiredItems(session)
    end
    
    -- Notify UI
    if ParallelLoot.UIManager and ParallelLoot.UIManager.OnItemExpired then
        ParallelLoot.UIManager:OnItemExpired(item)
    end
end

-- Handle duplicate roll
function ErrorHandler:HandleDuplicateRoll(playerName, item)
    ParallelLoot:DebugPrint("ErrorHandler: Duplicate roll detected from", playerName)
    
    -- Already handled by RollManager, just log
    self:LogError(self.CATEGORIES.VALIDATION, self.SEVERITY.INFO, 
        string.format("%s attempted duplicate roll on %s", playerName, item.itemName), 
        {player = playerName, item = item.id})
end

-- Handle invalid roll range
function ErrorHandler:HandleInvalidRollRange(rollValue, expectedRange)
    ParallelLoot:DebugPrint("ErrorHandler: Invalid roll range detected")
    
    self:LogError(self.CATEGORIES.VALIDATION, self.SEVERITY.WARNING, 
        string.format("Roll value %d outside expected range %d-%d", 
            rollValue, expectedRange.min, expectedRange.max), 
        {rollValue = rollValue, range = expectedRange})
end

-- Handle loot master change
function ErrorHandler:HandleLootMasterChange(oldMaster, newMaster)
    ParallelLoot:DebugPrint("ErrorHandler: Loot master changed from", oldMaster, "to", newMaster)
    
    -- Update session if exists
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        session.masterId = newMaster
        ParallelLoot.DataManager:SaveCurrentSession(session)
    end
    
    -- Request sync if we're not the new master
    if newMaster ~= UnitName("player") then
        C_Timer.After(2, function()
            if ParallelLoot.CommManager and ParallelLoot.CommManager.RequestSync then
                ParallelLoot.CommManager:RequestSync()
            end
        end)
    end
end

-- Handle raid disbanding
function ErrorHandler:HandleRaidDisband()
    ParallelLoot:DebugPrint("ErrorHandler: Raid disbanded")
    
    -- Save current session state
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        ParallelLoot.DataManager:SaveCurrentSession(session)
        ParallelLoot:Print("Session saved. Data will be available when you rejoin a raid.")
    end
end

-- ============================================================================
-- RECOVERY MECHANISMS
-- ============================================================================

-- Attempt full recovery
function ErrorHandler:AttemptFullRecovery()
    ParallelLoot:Print("Attempting full addon recovery...")
    
    local success = true
    
    -- Check addon health
    local healthy, issues = self:CheckAddonHealth()
    if not healthy then
        ParallelLoot:Print("Health check failed:", table.concat(issues, ", "))
        success = false
    end
    
    -- Validate database
    if ParallelLootDB then
        ParallelLoot.DataManager:ValidateDatabase()
    else
        ParallelLoot:Print("Database missing, cannot recover")
        success = false
    end
    
    -- Validate current session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        local valid, error = ParallelLoot.DataManager:ValidateSessionState(session)
        if not valid then
            ParallelLoot:Print("Session validation failed:", error)
            self:RecoverCorruptedSession({session = session})
        end
    end
    
    -- Refresh UI
    if ParallelLoot.UIManager and ParallelLoot.UIManager.Refresh then
        self:SafeCall(function()
            ParallelLoot.UIManager:Refresh()
        end, self.CATEGORIES.UI, {operation = "recovery"})
    end
    
    if success then
        ParallelLoot:Print("Recovery successful")
    else
        ParallelLoot:Print("Recovery completed with issues. Consider /reload")
    end
    
    return success
end

-- Emergency shutdown
function ErrorHandler:EmergencyShutdown(reason)
    self:LogError(self.CATEGORIES.SYSTEM, self.SEVERITY.CRITICAL, 
        "Emergency shutdown: " .. reason, {})
    
    ParallelLoot:Print("|cFFFF0000EMERGENCY SHUTDOWN:|r", reason)
    
    -- Save all data
    if ParallelLoot.DataManager and ParallelLoot.DataManager.SaveData then
        self:SafeCall(function()
            ParallelLoot.DataManager:SaveData()
        end, self.CATEGORIES.SYSTEM, {operation = "emergency_shutdown"})
    end
    
    -- Disable addon
    ParallelLoot.isEnabled = false
    
    -- Hide UI
    if ParallelLoot.UIManager and ParallelLoot.UIManager.HideMainFrame then
        ParallelLoot.UIManager:HideMainFrame()
    end
    
    ParallelLoot:Print("Addon disabled. Please /reload to restart.")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ErrorHandler:Initialize()
    ParallelLoot:DebugPrint("ErrorHandler: Initialized")
    
    -- Set up global error handler
    self:SetupGlobalErrorHandler()
end

-- Setup global error handler
function ErrorHandler:SetupGlobalErrorHandler()
    -- Wrap critical functions with error handling
    -- This is done in the Integration layer
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

SLASH_PLERROR1 = "/plerror"
SlashCmdList["PLERROR"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "log" then
        local errors = ErrorHandler:GetRecentErrors(20)
        ParallelLoot:Print("Recent errors:")
        for i, error in ipairs(errors) do
            print(string.format("%d. [%s] %s: %s", i, error.category, 
                ErrorHandler:GetSeverityName(error.severity), error.message))
        end
    elseif command == "clear" then
        ErrorHandler:ClearErrorLog()
    elseif command == "health" then
        local healthy, issues = ErrorHandler:CheckAddonHealth()
        if healthy then
            ParallelLoot:Print("Addon health: OK")
        else
            ParallelLoot:Print("Addon health: ISSUES DETECTED")
            for _, issue in ipairs(issues) do
                print("  -", issue)
            end
        end
    elseif command == "recover" then
        ErrorHandler:AttemptFullRecovery()
    else
        ParallelLoot:Print("Error Handler Commands:")
        print("  /plerror log - Show recent errors")
        print("  /plerror clear - Clear error log")
        print("  /plerror health - Check addon health")
        print("  /plerror recover - Attempt full recovery")
    end
end

ParallelLoot:DebugPrint("ErrorHandler.lua loaded")

