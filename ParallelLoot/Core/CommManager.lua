-- ParallelLoot Communication Manager
-- Handles addon communication, message protocol, and synchronization

local CommManager = ParallelLoot.CommManager

-- ============================================================================
-- MESSAGE TYPES
-- ============================================================================

CommManager.MessageTypes = {
    SESSION_START = "SESSION_START",
    SESSION_END = "SESSION_END",
    ITEM_ADDED = "ITEM_ADDED",
    ITEM_AWARDED = "ITEM_AWARDED",
    ITEM_REVOKED = "ITEM_REVOKED",
    PLAYER_ROLL = "PLAYER_ROLL",
    SYNC_REQUEST = "SYNC_REQUEST",
    SYNC_DATA = "SYNC_DATA",
    HEARTBEAT = "HEARTBEAT",
    ACK = "ACK"
}

-- ============================================================================
-- MESSAGE PROTOCOL
-- ============================================================================

-- Create a message structure
function CommManager:CreateMessage(messageType, data)
    if not self.MessageTypes[messageType] then
        ParallelLoot:DebugPrint("CommManager: Invalid message type:", messageType)
        return nil
    end
    
    local message = {
        type = messageType,
        timestamp = time(),
        senderId = UnitName("player"),
        sessionId = self:GetCurrentSessionId(),
        data = data or {}
    }
    
    return message
end

-- Get current session ID
function CommManager:GetCurrentSessionId()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    return session and session.id or nil
end

-- Validate message structure
function CommManager:ValidateMessage(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    
    if not message.type or type(message.type) ~= "string" then
        return false, "Message must have a valid type"
    end
    
    if not self.MessageTypes[message.type] then
        return false, "Unknown message type: " .. tostring(message.type)
    end
    
    if not message.timestamp or type(message.timestamp) ~= "number" then
        return false, "Message must have a valid timestamp"
    end
    
    if not message.senderId or type(message.senderId) ~= "string" then
        return false, "Message must have a valid senderId"
    end
    
    if not message.data or type(message.data) ~= "table" then
        return false, "Message must have a data table"
    end
    
    -- Validate message is not too old (reject messages older than 5 minutes)
    local age = time() - message.timestamp
    if age > 300 then
        return false, "Message is too old: " .. age .. " seconds"
    end
    
    -- Validate message is not from the future (allow 10 second clock skew)
    if age < -10 then
        return false, "Message timestamp is in the future"
    end
    
    return true
end

-- Validate message data based on type
function CommManager:ValidateMessageData(message)
    local messageType = message.type
    local data = message.data
    
    if messageType == "SESSION_START" then
        if not data.session or type(data.session) ~= "table" then
            return false, "SESSION_START requires session data"
        end
        return ParallelLoot.DataManager.LootSession:Validate(data.session)
        
    elseif messageType == "SESSION_END" then
        if not data.sessionId or type(data.sessionId) ~= "string" then
            return false, "SESSION_END requires sessionId"
        end
        return true
        
    elseif messageType == "ITEM_ADDED" then
        if not data.item or type(data.item) ~= "table" then
            return false, "ITEM_ADDED requires item data"
        end
        return ParallelLoot.DataManager.LootItem:Validate(data.item)
        
    elseif messageType == "ITEM_AWARDED" then
        if not data.itemId or type(data.itemId) ~= "string" then
            return false, "ITEM_AWARDED requires itemId"
        end
        if not data.playerName or type(data.playerName) ~= "string" then
            return false, "ITEM_AWARDED requires playerName"
        end
        return true
        
    elseif messageType == "ITEM_REVOKED" then
        if not data.itemId or type(data.itemId) ~= "string" then
            return false, "ITEM_REVOKED requires itemId"
        end
        return true
        
    elseif messageType == "PLAYER_ROLL" then
        if not data.roll or type(data.roll) ~= "table" then
            return false, "PLAYER_ROLL requires roll data"
        end
        if not data.itemId or type(data.itemId) ~= "string" then
            return false, "PLAYER_ROLL requires itemId"
        end
        return ParallelLoot.DataManager.PlayerRoll:Validate(data.roll)
        
    elseif messageType == "SYNC_REQUEST" then
        -- No specific data required
        return true
        
    elseif messageType == "SYNC_DATA" then
        if not data.session or type(data.session) ~= "table" then
            return false, "SYNC_DATA requires session data"
        end
        return ParallelLoot.DataManager.LootSession:Validate(data.session)
        
    elseif messageType == "HEARTBEAT" then
        -- No specific data required
        return true
        
    elseif messageType == "ACK" then
        if not data.messageType or type(data.messageType) ~= "string" then
            return false, "ACK requires messageType"
        end
        return true
    end
    
    return false, "Unknown message type for validation"
end

-- ============================================================================
-- MESSAGE SERIALIZATION
-- ============================================================================

-- Serialize a message to string format
function CommManager:SerializeMessage(message)
    if not message then
        return nil, "No message to serialize"
    end
    
    -- Validate message before serialization
    local valid, error = self:ValidateMessage(message)
    if not valid then
        return nil, "Invalid message: " .. error
    end
    
    -- Validate message data
    local dataValid, dataError = self:ValidateMessageData(message)
    if not dataValid then
        return nil, "Invalid message data: " .. dataError
    end
    
    -- Use WoW's built-in serialization
    local success, serialized = pcall(function()
        return self:TableToString(message)
    end)
    
    if not success then
        return nil, "Serialization failed: " .. tostring(serialized)
    end
    
    return serialized
end

-- Deserialize a message from string format
function CommManager:DeserializeMessage(serialized)
    if not serialized or type(serialized) ~= "string" then
        return nil, "Invalid serialized data"
    end
    
    -- Use WoW's built-in deserialization
    local success, message = pcall(function()
        return self:StringToTable(serialized)
    end)
    
    if not success then
        return nil, "Deserialization failed: " .. tostring(message)
    end
    
    -- Validate deserialized message
    local valid, error = self:ValidateMessage(message)
    if not valid then
        return nil, "Deserialized message invalid: " .. error
    end
    
    -- Validate message data
    local dataValid, dataError = self:ValidateMessageData(message)
    if not dataValid then
        return nil, "Deserialized message data invalid: " .. dataError
    end
    
    return message
end

-- Convert table to string (simple serialization)
function CommManager:TableToString(tbl)
    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return string.format("%q", tbl)
        else
            return tostring(tbl)
        end
    end
    
    local result = "{"
    local first = true
    
    for k, v in pairs(tbl) do
        if not first then
            result = result .. ","
        end
        first = false
        
        -- Serialize key
        if type(k) == "number" then
            result = result .. "[" .. k .. "]="
        else
            result = result .. "[" .. string.format("%q", k) .. "]="
        end
        
        -- Serialize value
        result = result .. self:TableToString(v)
    end
    
    result = result .. "}"
    return result
end

-- Convert string to table (simple deserialization)
function CommManager:StringToTable(str)
    if not str or type(str) ~= "string" then
        return nil
    end
    
    -- Use loadstring to evaluate the serialized table
    local func = loadstring("return " .. str)
    if not func then
        return nil
    end
    
    local success, result = pcall(func)
    if not success then
        return nil
    end
    
    return result
end

-- ============================================================================
-- ERROR HANDLING
-- ============================================================================

-- Handle message errors
function CommManager:HandleMessageError(error, context)
    ParallelLoot:DebugPrint("CommManager: Message error in", context, ":", error)
    
    -- Log error for debugging
    if not self.errorLog then
        self.errorLog = {}
    end
    
    table.insert(self.errorLog, {
        timestamp = time(),
        context = context,
        error = error
    })
    
    -- Keep only last 50 errors
    while #self.errorLog > 50 do
        table.remove(self.errorLog, 1)
    end
end

-- Get error log
function CommManager:GetErrorLog()
    return self.errorLog or {}
end

-- Clear error log
function CommManager:ClearErrorLog()
    self.errorLog = {}
end

-- ============================================================================
-- MESSAGE VALIDATION HELPERS
-- ============================================================================

-- Check if sender is valid
function CommManager:IsValidSender(senderId)
    if not senderId or type(senderId) ~= "string" then
        return false
    end
    
    -- Check if sender is in raid
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name == senderId then
                return true
            end
        end
    end
    
    -- Check if sender is in party
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name == senderId then
                return true
            end
        end
    end
    
    -- Check if sender is player
    if senderId == UnitName("player") then
        return true
    end
    
    return false
end

-- Check if message is from loot master
function CommManager:IsFromLootMaster(message)
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return false
    end
    
    return message.senderId == session.masterId
end

-- Check if player is loot master
function CommManager:IsPlayerLootMaster()
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if not session then
        return false
    end
    
    return session.masterId == UnitName("player")
end

-- ============================================================================
-- ANTI-SPAM AND RATE LIMITING
-- ============================================================================

-- Initialize rate limiting
CommManager.rateLimits = {
    PLAYER_ROLL = {maxPerMinute = 10, window = 60},
    SYNC_REQUEST = {maxPerMinute = 5, window = 60},
    HEARTBEAT = {maxPerMinute = 6, window = 60}
}

CommManager.messageHistory = {}

-- Check if message should be rate limited
function CommManager:CheckRateLimit(messageType, senderId)
    local limit = self.rateLimits[messageType]
    if not limit then
        return true -- No rate limit for this message type
    end
    
    local key = messageType .. ":" .. senderId
    local now = time()
    
    -- Initialize history for this key
    if not self.messageHistory[key] then
        self.messageHistory[key] = {}
    end
    
    local history = self.messageHistory[key]
    
    -- Remove old entries outside the window
    local i = 1
    while i <= #history do
        if now - history[i] > limit.window then
            table.remove(history, i)
        else
            i = i + 1
        end
    end
    
    -- Check if limit exceeded
    if #history >= limit.maxPerMinute then
        ParallelLoot:DebugPrint("CommManager: Rate limit exceeded for", messageType, "from", senderId)
        return false
    end
    
    -- Add current message to history
    table.insert(history, now)
    
    return true
end

-- Clear rate limit history
function CommManager:ClearRateLimitHistory()
    self.messageHistory = {}
end

-- ============================================================================
-- NETWORK SYNCHRONIZATION
-- ============================================================================

-- Event frame for addon messages
local commEventFrame = CreateFrame("Frame")

-- Register addon communication prefix
function CommManager:RegisterAddonPrefix()
    if not self.prefixRegistered then
        local result = C_ChatInfo.RegisterAddonMessagePrefix(ParallelLoot.ADDON_PREFIX)
        if result == 0 then -- Success
            self.prefixRegistered = true
            ParallelLoot:DebugPrint("CommManager: Registered addon prefix:", ParallelLoot.ADDON_PREFIX)
        else
            ParallelLoot:DebugPrint("CommManager: Failed to register addon prefix. Result:", result)
        end
    end
end

-- Send message to raid/party
function CommManager:SendMessage(message, target)
    if not message then
        return false, "No message to send"
    end
    
    -- Serialize message
    local serialized, error = self:SerializeMessage(message)
    if not serialized then
        self:HandleMessageError(error, "SendMessage")
        return false, error
    end
    
    -- Check rate limit
    if not self:CheckRateLimit(message.type, UnitName("player")) then
        return false, "Rate limit exceeded"
    end
    
    -- Determine distribution channel
    local channel = "RAID"
    if not IsInRaid() and IsInGroup() then
        channel = "PARTY"
    elseif not IsInRaid() and not IsInGroup() then
        ParallelLoot:DebugPrint("CommManager: Not in raid or party, cannot send message")
        return false, "Not in raid or party"
    end
    
    -- Send message
    local success = ChatThrottleLib and 
        ChatThrottleLib:SendAddonMessage("NORMAL", ParallelLoot.ADDON_PREFIX, serialized, channel, target) or
        C_ChatInfo.SendAddonMessage(ParallelLoot.ADDON_PREFIX, serialized, channel, target)
    
    if success == false then
        self:HandleMessageError("Failed to send message", "SendMessage")
        return false, "Failed to send message"
    end
    
    ParallelLoot:DebugPrint("CommManager: Sent message type:", message.type, "to", channel)
    
    return true
end

-- Broadcast message to all raid/party members
function CommManager:BroadcastMessage(message)
    return self:SendMessage(message, nil)
end

-- Send message to specific player
function CommManager:SendMessageToPlayer(message, playerName)
    return self:SendMessage(message, playerName)
end

-- Handle received addon message
function CommManager:OnAddonMessage(prefix, serialized, channel, sender)
    -- Ignore messages from self
    if sender == UnitName("player") then
        return
    end
    
    -- Check prefix
    if prefix ~= ParallelLoot.ADDON_PREFIX then
        return
    end
    
    ParallelLoot:DebugPrint("CommManager: Received message from", sender, "on", channel)
    
    -- Deserialize message
    local message, error = self:DeserializeMessage(serialized)
    if not message then
        self:HandleMessageError(error, "OnAddonMessage")
        return
    end
    
    -- Validate sender
    if not self:IsValidSender(sender) then
        self:HandleMessageError("Invalid sender: " .. sender, "OnAddonMessage")
        return
    end
    
    -- Check rate limit
    if not self:CheckRateLimit(message.type, sender) then
        self:HandleMessageError("Rate limit exceeded for " .. sender, "OnAddonMessage")
        return
    end
    
    -- Process message based on type
    self:ProcessMessage(message, sender, channel)
end

-- Process received message
function CommManager:ProcessMessage(message, sender, channel)
    local messageType = message.type
    
    ParallelLoot:DebugPrint("CommManager: Processing message type:", messageType, "from", sender)
    
    if messageType == "SESSION_START" then
        self:HandleSessionStart(message, sender)
        
    elseif messageType == "SESSION_END" then
        self:HandleSessionEnd(message, sender)
        
    elseif messageType == "ITEM_ADDED" then
        self:HandleItemAdded(message, sender)
        
    elseif messageType == "ITEM_AWARDED" then
        self:HandleItemAwarded(message, sender)
        
    elseif messageType == "ITEM_REVOKED" then
        self:HandleItemRevoked(message, sender)
        
    elseif messageType == "PLAYER_ROLL" then
        self:HandlePlayerRoll(message, sender)
        
    elseif messageType == "SYNC_REQUEST" then
        self:HandleSyncRequest(message, sender)
        
    elseif messageType == "SYNC_DATA" then
        self:HandleSyncData(message, sender)
        
    elseif messageType == "HEARTBEAT" then
        self:HandleHeartbeat(message, sender)
        
    elseif messageType == "ACK" then
        self:HandleAck(message, sender)
        
    else
        self:HandleMessageError("Unknown message type: " .. messageType, "ProcessMessage")
    end
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Handle SESSION_START message
function CommManager:HandleSessionStart(message, sender)
    -- Only accept from loot master
    if not self:IsFromLootMaster(message) then
        ParallelLoot:DebugPrint("CommManager: Ignoring SESSION_START from non-loot-master:", sender)
        return
    end
    
    local session = message.data.session
    
    -- Set as current session
    ParallelLoot.DataManager:SetCurrentSession(session)
    
    -- Notify UI
    if ParallelLoot.UIManager.OnSessionStart then
        ParallelLoot.UIManager:OnSessionStart(session)
    end
    
    ParallelLoot:Print("Loot session started by", sender)
end

-- Handle SESSION_END message
function CommManager:HandleSessionEnd(message, sender)
    -- Only accept from loot master
    if not self:IsFromLootMaster(message) then
        ParallelLoot:DebugPrint("CommManager: Ignoring SESSION_END from non-loot-master:", sender)
        return
    end
    
    -- End current session
    ParallelLoot.DataManager:EndSession()
    
    -- Notify UI
    if ParallelLoot.UIManager.OnSessionEnd then
        ParallelLoot.UIManager:OnSessionEnd()
    end
    
    ParallelLoot:Print("Loot session ended by", sender)
end

-- Handle ITEM_ADDED message
function CommManager:HandleItemAdded(message, sender)
    -- Only accept from loot master
    if not self:IsFromLootMaster(message) then
        ParallelLoot:DebugPrint("CommManager: Ignoring ITEM_ADDED from non-loot-master:", sender)
        return
    end
    
    local item = message.data.item
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:DebugPrint("CommManager: No active session for ITEM_ADDED")
        return
    end
    
    -- Check if item already exists
    local existingItem = ParallelLoot.DataManager:FindItemById(session.activeItems, item.id)
    if existingItem then
        ParallelLoot:DebugPrint("CommManager: Item already exists, skipping")
        return
    end
    
    -- Add item to session
    table.insert(session.activeItems, item)
    ParallelLoot.DataManager:SaveSession(session)
    
    -- Notify UI
    if ParallelLoot.UIManager.OnItemAdded then
        ParallelLoot.UIManager:OnItemAdded(item)
    end
    
    ParallelLoot:DebugPrint("CommManager: Item added:", item.itemLink)
end

-- Handle ITEM_AWARDED message
function CommManager:HandleItemAwarded(message, sender)
    -- Only accept from loot master
    if not self:IsFromLootMaster(message) then
        ParallelLoot:DebugPrint("CommManager: Ignoring ITEM_AWARDED from non-loot-master:", sender)
        return
    end
    
    local itemId = message.data.itemId
    local playerName = message.data.playerName
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:DebugPrint("CommManager: No active session for ITEM_AWARDED")
        return
    end
    
    -- Find item in active items
    local item, index = ParallelLoot.DataManager:FindItemById(session.activeItems, itemId)
    if not item then
        ParallelLoot:DebugPrint("CommManager: Item not found for award:", itemId)
        return
    end
    
    -- Mark as awarded
    item.awardedTo = playerName
    item.awardTime = time()
    
    -- Move to awarded items
    table.remove(session.activeItems, index)
    table.insert(session.awardedItems, item)
    
    -- Recycle roll range
    ParallelLoot.DataManager:RecycleRollRange(session, item.rollRange)
    
    -- Save session
    ParallelLoot.DataManager:SaveSession(session)
    
    -- Notify UI
    if ParallelLoot.UIManager.OnItemAwarded then
        ParallelLoot.UIManager:OnItemAwarded(item, playerName)
    end
    
    ParallelLoot:Print("Item awarded to", playerName, ":", item.itemLink)
end

-- Handle ITEM_REVOKED message
function CommManager:HandleItemRevoked(message, sender)
    -- Only accept from loot master
    if not self:IsFromLootMaster(message) then
        ParallelLoot:DebugPrint("CommManager: Ignoring ITEM_REVOKED from non-loot-master:", sender)
        return
    end
    
    local itemId = message.data.itemId
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:DebugPrint("CommManager: No active session for ITEM_REVOKED")
        return
    end
    
    -- Find item in awarded items
    local item, index = ParallelLoot.DataManager:FindItemById(session.awardedItems, itemId)
    if not item then
        ParallelLoot:DebugPrint("CommManager: Item not found for revoke:", itemId)
        return
    end
    
    -- Check if item is expired
    if ParallelLoot.DataManager.LootItem:IsExpired(item) then
        ParallelLoot:Print("Cannot revoke expired item")
        return
    end
    
    -- Clear award info
    item.awardedTo = nil
    item.awardTime = nil
    
    -- Assign new roll range
    local newRange = ParallelLoot.DataManager:AssignRollRange(session)
    item.rollRange = newRange
    
    -- Move back to active items
    table.remove(session.awardedItems, index)
    table.insert(session.activeItems, item)
    
    -- Save session
    ParallelLoot.DataManager:SaveSession(session)
    
    -- Notify UI
    if ParallelLoot.UIManager.OnItemRevoked then
        ParallelLoot.UIManager:OnItemRevoked(item)
    end
    
    ParallelLoot:Print("Item award revoked:", item.itemLink)
end

-- Handle PLAYER_ROLL message
function CommManager:HandlePlayerRoll(message, sender)
    local roll = message.data.roll
    local itemId = message.data.itemId
    local session = ParallelLoot.DataManager:GetCurrentSession()
    
    if not session then
        ParallelLoot:DebugPrint("CommManager: No active session for PLAYER_ROLL")
        return
    end
    
    -- Find item
    local item = ParallelLoot.DataManager:FindItemById(session.activeItems, itemId)
    if not item then
        ParallelLoot:DebugPrint("CommManager: Item not found for roll:", itemId)
        return
    end
    
    -- Validate roll is from the sender
    if roll.playerName ~= sender then
        self:HandleMessageError("Roll player name mismatch", "HandlePlayerRoll")
        return
    end
    
    -- Add roll to item
    local success, error = ParallelLoot.DataManager:AddRollToItem(item, roll)
    if not success then
        ParallelLoot:DebugPrint("CommManager: Failed to add roll:", error)
        return
    end
    
    -- Save session
    ParallelLoot.DataManager:SaveSession(session)
    
    -- Notify UI
    if ParallelLoot.UIManager.OnRollAdded then
        ParallelLoot.UIManager:OnRollAdded(item, roll)
    end
    
    ParallelLoot:DebugPrint("CommManager: Roll added for", sender, ":", roll.rollValue, roll.category)
end

-- Handle SYNC_REQUEST message
function CommManager:HandleSyncRequest(message, sender)
    -- Only loot master responds to sync requests
    if not self:IsPlayerLootMaster() then
        return
    end
    
    ParallelLoot:DebugPrint("CommManager: Sync request from", sender)
    
    -- Send current session data
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session then
        local syncMessage = self:CreateMessage("SYNC_DATA", {session = session})
        self:SendMessageToPlayer(syncMessage, sender)
    end
end

-- Handle SYNC_DATA message
function CommManager:HandleSyncData(message, sender)
    -- Only accept from loot master
    if not self:IsFromLootMaster(message) then
        ParallelLoot:DebugPrint("CommManager: Ignoring SYNC_DATA from non-loot-master:", sender)
        return
    end
    
    local session = message.data.session
    
    -- Resolve conflicts with local session
    local resolvedSession = self:ResolveSessionConflicts(session)
    
    -- Update current session
    ParallelLoot.DataManager:SetCurrentSession(resolvedSession)
    
    -- Notify UI to refresh
    if ParallelLoot.UIManager.OnSessionSync then
        ParallelLoot.UIManager:OnSessionSync(resolvedSession)
    end
    
    ParallelLoot:DebugPrint("CommManager: Session synced from", sender)
end

-- Handle HEARTBEAT message
function CommManager:HandleHeartbeat(message, sender)
    -- Track active players
    if not self.activePlayers then
        self.activePlayers = {}
    end
    
    self.activePlayers[sender] = time()
    
    ParallelLoot:DebugPrint("CommManager: Heartbeat from", sender)
end

-- Handle ACK message
function CommManager:HandleAck(message, sender)
    ParallelLoot:DebugPrint("CommManager: ACK from", sender, "for", message.data.messageType)
end

-- ============================================================================
-- CONFLICT RESOLUTION
-- ============================================================================

-- Resolve conflicts between local and remote session
function CommManager:ResolveSessionConflicts(remoteSession)
    local localSession = ParallelLoot.DataManager:GetCurrentSession()
    
    -- If no local session, use remote
    if not localSession then
        return remoteSession
    end
    
    -- If sessions have different IDs, prefer loot master's session
    if localSession.id ~= remoteSession.id then
        ParallelLoot:DebugPrint("CommManager: Session ID mismatch, using remote session")
        return remoteSession
    end
    
    -- Merge items from both sessions
    local mergedSession = self:DeepCopy(remoteSession)
    
    -- Merge active items
    mergedSession.activeItems = self:MergeItems(localSession.activeItems, remoteSession.activeItems)
    
    -- Merge awarded items
    mergedSession.awardedItems = self:MergeItems(localSession.awardedItems, remoteSession.awardedItems)
    
    -- Use remote roll ranges (loot master is authoritative)
    mergedSession.rollRanges = remoteSession.rollRanges
    
    return mergedSession
end

-- Merge two item lists, preferring newer items
function CommManager:MergeItems(localItems, remoteItems)
    local merged = {}
    local itemMap = {}
    
    -- Add all remote items (authoritative)
    for _, item in ipairs(remoteItems) do
        itemMap[item.id] = item
        table.insert(merged, item)
    end
    
    -- Add local items that don't exist in remote
    for _, item in ipairs(localItems) do
        if not itemMap[item.id] then
            table.insert(merged, item)
        end
    end
    
    return merged
end

-- Deep copy a table
function CommManager:DeepCopy(obj)
    if type(obj) ~= "table" then
        return obj
    end
    
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = self:DeepCopy(v)
    end
    
    return copy
end

-- ============================================================================
-- BROADCAST HELPERS
-- ============================================================================

-- Broadcast session start
function CommManager:BroadcastSessionStart(session)
    local message = self:CreateMessage("SESSION_START", {session = session})
    return self:BroadcastMessage(message)
end

-- Broadcast session end
function CommManager:BroadcastSessionEnd(sessionId)
    local message = self:CreateMessage("SESSION_END", {sessionId = sessionId})
    return self:BroadcastMessage(message)
end

-- Broadcast item added
function CommManager:BroadcastItemAdded(item)
    local message = self:CreateMessage("ITEM_ADDED", {item = item})
    return self:BroadcastMessage(message)
end

-- Broadcast item awarded
function CommManager:BroadcastItemAwarded(itemId, playerName)
    local message = self:CreateMessage("ITEM_AWARDED", {
        itemId = itemId,
        playerName = playerName
    })
    return self:BroadcastMessage(message)
end

-- Broadcast item revoked
function CommManager:BroadcastItemRevoked(itemId)
    local message = self:CreateMessage("ITEM_REVOKED", {itemId = itemId})
    return self:BroadcastMessage(message)
end

-- Broadcast player roll
function CommManager:BroadcastPlayerRoll(itemId, roll)
    local message = self:CreateMessage("PLAYER_ROLL", {
        itemId = itemId,
        roll = roll
    })
    return self:BroadcastMessage(message)
end

-- Request sync from loot master
function CommManager:RequestSync()
    local message = self:CreateMessage("SYNC_REQUEST", {})
    return self:BroadcastMessage(message)
end

-- Send heartbeat
function CommManager:SendHeartbeat()
    local message = self:CreateMessage("HEARTBEAT", {})
    return self:BroadcastMessage(message)
end

-- ============================================================================
-- OFFLINE PLAYER SUPPORT
-- ============================================================================

-- Message queue for offline/disconnected players
CommManager.messageQueue = {}

-- Track player online status
CommManager.playerStatus = {}

-- Queue message for offline player
function CommManager:QueueMessageForPlayer(playerName, message)
    if not self.messageQueue[playerName] then
        self.messageQueue[playerName] = {}
    end
    
    table.insert(self.messageQueue[playerName], {
        message = message,
        timestamp = time()
    })
    
    ParallelLoot:DebugPrint("CommManager: Queued message for", playerName, "type:", message.type)
    
    -- Limit queue size per player (keep last 50 messages)
    while #self.messageQueue[playerName] > 50 do
        table.remove(self.messageQueue[playerName], 1)
    end
end

-- Send queued messages to player
function CommManager:SendQueuedMessages(playerName)
    local queue = self.messageQueue[playerName]
    if not queue or #queue == 0 then
        return
    end
    
    ParallelLoot:DebugPrint("CommManager: Sending", #queue, "queued messages to", playerName)
    
    -- Send all queued messages
    for _, queuedItem in ipairs(queue) do
        -- Check if message is not too old (discard messages older than 1 hour)
        local age = time() - queuedItem.timestamp
        if age < 3600 then
            self:SendMessageToPlayer(queuedItem.message, playerName)
        else
            ParallelLoot:DebugPrint("CommManager: Discarding old queued message, age:", age)
        end
    end
    
    -- Clear queue
    self.messageQueue[playerName] = {}
end

-- Check if player is online
function CommManager:IsPlayerOnline(playerName)
    -- Check in raid
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name == playerName then
                return online
            end
        end
    end
    
    -- Check in party
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name == playerName then
                return UnitIsConnected(unit)
            end
        end
    end
    
    -- Check if it's the player
    if playerName == UnitName("player") then
        return true
    end
    
    return false
end

-- Update player online status
function CommManager:UpdatePlayerStatus(playerName, isOnline)
    local wasOnline = self.playerStatus[playerName]
    self.playerStatus[playerName] = isOnline
    
    -- If player just came online, send queued messages
    if isOnline and not wasOnline then
        ParallelLoot:DebugPrint("CommManager: Player came online:", playerName)
        self:OnPlayerReconnected(playerName)
    elseif not isOnline and wasOnline then
        ParallelLoot:DebugPrint("CommManager: Player went offline:", playerName)
        self:OnPlayerDisconnected(playerName)
    end
end

-- Handle player reconnection
function CommManager:OnPlayerReconnected(playerName)
    ParallelLoot:Print(playerName, "reconnected")
    
    -- Send queued messages
    self:SendQueuedMessages(playerName)
    
    -- If we're the loot master, send full sync
    if self:IsPlayerLootMaster() then
        local session = ParallelLoot.DataManager:GetCurrentSession()
        if session then
            local syncMessage = self:CreateMessage("SYNC_DATA", {session = session})
            self:SendMessageToPlayer(syncMessage, playerName)
        end
    end
end

-- Handle player disconnection
function CommManager:OnPlayerDisconnected(playerName)
    ParallelLoot:DebugPrint("CommManager: Player disconnected:", playerName)
end

-- Monitor raid roster for online status changes
function CommManager:MonitorRaidRoster()
    if not IsInRaid() and not IsInGroup() then
        return
    end
    
    -- Check raid members
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name then
                self:UpdatePlayerStatus(name, online)
            end
        end
    end
    
    -- Check party members
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                local online = UnitIsConnected(unit)
                self:UpdatePlayerStatus(name, online)
            end
        end
    end
end

-- Send message with offline player handling
function CommManager:SendMessageWithQueueing(message, target)
    -- If target specified, check if they're online
    if target then
        if not self:IsPlayerOnline(target) then
            ParallelLoot:DebugPrint("CommManager: Target offline, queueing message for", target)
            self:QueueMessageForPlayer(target, message)
            return true -- Message queued successfully
        end
    end
    
    -- Send message normally
    return self:SendMessage(message, target)
end

-- Broadcast with offline player queueing
function CommManager:BroadcastWithQueueing(message)
    local onlineCount = 0
    local offlineCount = 0
    
    -- Send to online players, queue for offline
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name and name ~= UnitName("player") then
                if online then
                    onlineCount = onlineCount + 1
                else
                    self:QueueMessageForPlayer(name, message)
                    offlineCount = offlineCount + 1
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                if UnitIsConnected(unit) then
                    onlineCount = onlineCount + 1
                else
                    self:QueueMessageForPlayer(name, message)
                    offlineCount = offlineCount + 1
                end
            end
        end
    end
    
    -- Broadcast to all online players
    local success = self:BroadcastMessage(message)
    
    if offlineCount > 0 then
        ParallelLoot:DebugPrint("CommManager: Queued message for", offlineCount, "offline players")
    end
    
    return success
end

-- Get queued message count for player
function CommManager:GetQueuedMessageCount(playerName)
    local queue = self.messageQueue[playerName]
    return queue and #queue or 0
end

-- Clear message queue for player
function CommManager:ClearMessageQueue(playerName)
    self.messageQueue[playerName] = {}
end

-- Clear all message queues
function CommManager:ClearAllMessageQueues()
    self.messageQueue = {}
end

-- Get all offline players with queued messages
function CommManager:GetOfflinePlayersWithQueue()
    local players = {}
    
    for playerName, queue in pairs(self.messageQueue) do
        if #queue > 0 and not self:IsPlayerOnline(playerName) then
            table.insert(players, {
                name = playerName,
                queuedMessages = #queue
            })
        end
    end
    
    return players
end

-- ============================================================================
-- FALLBACK FOR PLAYERS WITHOUT ADDON
-- ============================================================================

-- Detect if player has addon installed
CommManager.playersWithAddon = {}

-- Mark player as having addon (when we receive a message from them)
function CommManager:MarkPlayerHasAddon(playerName)
    self.playersWithAddon[playerName] = time()
    ParallelLoot:DebugPrint("CommManager: Player has addon:", playerName)
end

-- Check if player has addon
function CommManager:PlayerHasAddon(playerName)
    return self.playersWithAddon[playerName] ~= nil
end

-- Get list of players without addon
function CommManager:GetPlayersWithoutAddon()
    local playersWithout = {}
    
    -- Check raid members
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name and name ~= UnitName("player") and not self:PlayerHasAddon(name) then
                table.insert(playersWithout, name)
            end
        end
    end
    
    -- Check party members
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name and not self:PlayerHasAddon(name) then
                table.insert(playersWithout, name)
            end
        end
    end
    
    return playersWithout
end

-- Send whisper instructions to players without addon
function CommManager:SendManualRollInstructions(playerName, item)
    if self:PlayerHasAddon(playerName) then
        return -- Player has addon, no need for manual instructions
    end
    
    local ranges = ParallelLoot.DataManager:FormatAllRanges(item.rollRange)
    
    local instructions = string.format(
        "Roll on %s: BIS(%s) MS(%s) OS(%s) COZ(%s)",
        item.itemLink,
        ranges.bis,
        ranges.ms,
        ranges.os,
        ranges.coz
    )
    
    SendChatMessage(instructions, "WHISPER", nil, playerName)
    ParallelLoot:DebugPrint("CommManager: Sent manual roll instructions to", playerName)
end

-- Broadcast manual roll instructions to raid
function CommManager:BroadcastManualRollInstructions(item)
    local playersWithout = self:GetPlayersWithoutAddon()
    
    if #playersWithout == 0 then
        return
    end
    
    local ranges = ParallelLoot.DataManager:FormatAllRanges(item.rollRange)
    
    local instructions = string.format(
        "[ParallelLoot] Roll on %s: BIS(%s) MS(%s) OS(%s) COZ(%s)",
        item.itemLink,
        ranges.bis,
        ranges.ms,
        ranges.os,
        ranges.coz
    )
    
    -- Send to raid chat
    if IsInRaid() then
        SendChatMessage(instructions, "RAID")
    elseif IsInGroup() then
        SendChatMessage(instructions, "PARTY")
    end
    
    ParallelLoot:DebugPrint("CommManager: Broadcast manual roll instructions")
end

-- Detect manual rolls from chat (for players without addon)
function CommManager:DetectManualRoll(message, sender)
    -- This will be integrated with RollManager
    -- For now, just log it
    ParallelLoot:DebugPrint("CommManager: Manual roll detected from", sender, ":", message)
end

-- ============================================================================
-- PERIODIC TASKS
-- ============================================================================

-- Ticker for periodic tasks
CommManager.ticker = nil

-- Start periodic tasks
function CommManager:StartPeriodicTasks()
    if self.ticker then
        return -- Already running
    end
    
    -- Run every 5 seconds
    self.ticker = C_Timer.NewTicker(5, function()
        self:PeriodicUpdate()
    end)
    
    ParallelLoot:DebugPrint("CommManager: Started periodic tasks")
end

-- Stop periodic tasks
function CommManager:StopPeriodicTasks()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
        ParallelLoot:DebugPrint("CommManager: Stopped periodic tasks")
    end
end

-- Periodic update function
function CommManager:PeriodicUpdate()
    -- Monitor raid roster for online status changes
    self:MonitorRaidRoster()
    
    -- Clean up old player status entries
    self:CleanupPlayerStatus()
    
    -- Send heartbeat if we're in a session
    local session = ParallelLoot.DataManager:GetCurrentSession()
    if session and self:IsPlayerLootMaster() then
        self:SendHeartbeat()
    end
end

-- Clean up old player status entries
function CommManager:CleanupPlayerStatus()
    local now = time()
    
    -- Clean up players with addon tracking (remove entries older than 1 hour)
    for playerName, timestamp in pairs(self.playersWithAddon) do
        if now - timestamp > 3600 then
            self.playersWithAddon[playerName] = nil
        end
    end
    
    -- Clean up message queues for players no longer in group
    for playerName, _ in pairs(self.messageQueue) do
        if not self:IsValidSender(playerName) then
            self.messageQueue[playerName] = nil
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CommManager:Initialize()
    ParallelLoot:DebugPrint("CommManager: Initializing")
    
    -- Initialize error log
    self.errorLog = {}
    
    -- Initialize message history for rate limiting
    self.messageHistory = {}
    
    -- Initialize active players tracking
    self.activePlayers = {}
    
    -- Initialize message queue
    self.messageQueue = {}
    
    -- Initialize player status tracking
    self.playerStatus = {}
    
    -- Initialize players with addon tracking
    self.playersWithAddon = {}
    
    -- Register addon prefix
    self:RegisterAddonPrefix()
    
    -- Register event handler for addon messages
    commEventFrame:RegisterEvent("CHAT_MSG_ADDON")
    commEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    commEventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            CommManager:OnAddonMessage(prefix, message, channel, sender)
            -- Mark sender as having addon
            if prefix == ParallelLoot.ADDON_PREFIX then
                CommManager:MarkPlayerHasAddon(sender)
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            CommManager:MonitorRaidRoster()
        end
    end)
    
    -- Start periodic tasks
    self:StartPeriodicTasks()
    
    ParallelLoot:DebugPrint("CommManager: Initialized")
end
