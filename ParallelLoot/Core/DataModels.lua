-- ParallelLoot Data Models
-- Core data structures for loot sessions, items, and rolls
-- Task 2.1 Implementation

local ParallelLoot = _G.ParallelLoot
if not ParallelLoot then
    error("ParallelLoot addon not found!")
    return
end

-- Data Models Module
ParallelLoot.DataModels = {}
local DataModels = ParallelLoot.DataModels

-- Modern WoW API imports for data validation
local C_Item = C_Item
local C_CreatureInfo = C_CreatureInfo

-- Utility function to generate unique IDs
local function GenerateUniqueId()
    return "PLoot_" .. time() .. "_" .. math.random(1000, 9999)
end

-- Utility function to validate item links using modern APIs
local function ValidateItemLink(itemLink)
    if not itemLink or type(itemLink) ~= "string" then
        return false, "Invalid item link format"
    end
    
    -- Extract item ID from link
    local itemId = C_Item.GetItemIDForItemInfo(itemLink)
    if not itemId then
        return false, "Could not extract item ID from link"
    end
    
    -- Validate item exists using modern C_Item API
    if not C_Item.DoesItemExistByID(itemId) then
        return false, "Item does not exist in database"
    end
    
    return true, itemId
end

-- Utility function to get current timestamp
local function GetCurrentTimestamp()
    return time()
end

-- Utility function to validate player name
local function ValidatePlayerName(playerName)
    if not playerName or type(playerName) ~= "string" or playerName == "" then
        return false, "Invalid player name"
    end
    
    -- Basic name validation (WoW character names are 2-12 characters)
    if string.len(playerName) < 2 or string.len(playerName) > 12 then
        return false, "Player name length invalid"
    end
    
    -- Check for valid characters (letters only, WoW naming convention)
    if not string.match(playerName, "^[A-Za-z][A-Za-z]*$") then
        return false, "Player name contains invalid characters"
    end
    
    return true
end

-- Utility function to validate roll category
local function ValidateRollCategory(category)
    local validCategories = {"bis", "ms", "os", "coz"}
    
    if not category or type(category) ~= "string" then
        return false, "Invalid category format"
    end
    
    category = string.lower(category)
    for _, validCat in ipairs(validCategories) do
        if category == validCat then
            return true
        end
    end
    
    return false, "Invalid roll category: " .. category
end

-- Utility function to validate roll range
local function ValidateRollRange(rollRange)
    if not rollRange or type(rollRange) ~= "table" then
        return false, "Roll range must be a table"
    end
    
    -- Validate each category has min/max values
    local requiredCategories = {"bis", "ms", "os", "coz"}
    for _, category in ipairs(requiredCategories) do
        local range = rollRange[category]
        if not range or type(range) ~= "table" then
            return false, "Missing or invalid range for category: " .. category
        end
        
        if not range.min or not range.max or 
           type(range.min) ~= "number" or type(range.max) ~= "number" then
            return false, "Invalid min/max values for category: " .. category
        end
        
        if range.min >= range.max or range.min < 1 then
            return false, "Invalid range values for category: " .. category
        end
    end
    
    return true
end

-- ============================================================================
-- LootSession Data Structure
-- ============================================================================

DataModels.LootSession = {}
local LootSession = DataModels.LootSession

-- Create a new loot session
function LootSession:New(masterId, sessionId)
    -- Validate master ID
    local masterValid, masterError = ValidatePlayerName(masterId)
    if not masterValid then
        return nil, "Invalid loot master: " .. (masterError or "unknown error")
    end
    
    -- Generate session ID if not provided
    if not sessionId then
        sessionId = GenerateUniqueId()
    end
    
    local session = {
        -- Core identification
        id = sessionId,
        masterId = masterId,
        startTime = GetCurrentTimestamp(),
        endTime = nil,
        
        -- Session state
        status = "active", -- active, paused, ended
        
        -- Item collections
        activeItems = {},     -- Array of active loot items
        awardedItems = {},    -- Array of awarded items
        
        -- Roll range management
        rollRanges = {
            nextBaseRange = 1,  -- Next available base range (1-100, 101-200, etc.)
            usedRanges = {},    -- Track used ranges for recycling
            availableRanges = {} -- Recycled ranges available for reuse
        },
        
        -- Session configuration
        categories = {
            bis = "BIS",
            ms = "MS",
            os = "OS", 
            coz = "COZ"
        },
        
        -- Session metadata
        metadata = {
            raidSize = 0,
            totalItemsProcessed = 0,
            totalRollsReceived = 0,
            createdBy = masterId,
            lastModified = GetCurrentTimestamp()
        }
    }
    
    -- Set up metatable for methods
    setmetatable(session, {__index = LootSession})
    
    return session
end

-- Validate loot session structure
function LootSession:Validate()
    -- Validate required fields
    if not self.id or type(self.id) ~= "string" then
        return false, "Invalid session ID"
    end
    
    if not self.masterId or type(self.masterId) ~= "string" then
        return false, "Invalid master ID"
    end
    
    if not self.startTime or type(self.startTime) ~= "number" then
        return false, "Invalid start time"
    end
    
    -- Validate arrays
    if not self.activeItems or type(self.activeItems) ~= "table" then
        return false, "Invalid active items array"
    end
    
    if not self.awardedItems or type(self.awardedItems) ~= "table" then
        return false, "Invalid awarded items array"
    end
    
    -- Validate roll ranges structure
    if not self.rollRanges or type(self.rollRanges) ~= "table" then
        return false, "Invalid roll ranges structure"
    end
    
    if not self.rollRanges.nextBaseRange or type(self.rollRanges.nextBaseRange) ~= "number" then
        return false, "Invalid next base range"
    end
    
    -- Validate categories
    if not self.categories or type(self.categories) ~= "table" then
        return false, "Invalid categories structure"
    end
    
    local requiredCategories = {"bis", "ms", "os", "coz"}
    for _, category in ipairs(requiredCategories) do
        if not self.categories[category] or type(self.categories[category]) ~= "string" then
            return false, "Missing or invalid category: " .. category
        end
    end
    
    return true
end

-- Add item to session
function LootSession:AddItem(lootItem)
    if not lootItem or not lootItem.Validate or not lootItem:Validate() then
        return false, "Invalid loot item"
    end
    
    -- Check if item already exists
    for _, existingItem in ipairs(self.activeItems) do
        if existingItem.id == lootItem.id then
            return false, "Item already exists in session"
        end
    end
    
    -- Add to active items
    table.insert(self.activeItems, lootItem)
    
    -- Update metadata
    self.metadata.totalItemsProcessed = self.metadata.totalItemsProcessed + 1
    self.metadata.lastModified = GetCurrentTimestamp()
    
    return true
end

-- Remove item from session (when awarded)
function LootSession:AwardItem(itemId, awardedTo)
    -- Find item in active items
    local itemIndex = nil
    local item = nil
    
    for i, activeItem in ipairs(self.activeItems) do
        if activeItem.id == itemId then
            itemIndex = i
            item = activeItem
            break
        end
    end
    
    if not item then
        return false, "Item not found in active items"
    end
    
    -- Validate awarded player
    local playerValid, playerError = ValidatePlayerName(awardedTo)
    if not playerValid then
        return false, "Invalid player name: " .. (playerError or "unknown error")
    end
    
    -- Mark item as awarded
    item.awardedTo = awardedTo
    item.awardTime = GetCurrentTimestamp()
    item.status = "awarded"
    
    -- Move from active to awarded
    table.remove(self.activeItems, itemIndex)
    table.insert(self.awardedItems, item)
    
    -- Free up roll range for recycling
    if item.rollRange then
        table.insert(self.rollRanges.availableRanges, item.rollRange.baseRange)
    end
    
    -- Update metadata
    self.metadata.lastModified = GetCurrentTimestamp()
    
    return true
end

-- Get next available roll range
function LootSession:GetNextRollRange()
    local baseRange
    
    -- Check if we have recycled ranges available
    if #self.rollRanges.availableRanges > 0 then
        baseRange = table.remove(self.rollRanges.availableRanges, 1)
    else
        -- Use next sequential range
        baseRange = self.rollRanges.nextBaseRange
        self.rollRanges.nextBaseRange = self.rollRanges.nextBaseRange + 100
    end
    
    -- Calculate category ranges with offsets
    local rollRange = {
        baseRange = baseRange,
        bis = {min = baseRange, max = baseRange + 99},
        ms = {min = baseRange, max = baseRange + 98},
        os = {min = baseRange, max = baseRange + 97},
        coz = {min = baseRange, max = baseRange + 96}
    }
    
    -- Track used range
    table.insert(self.rollRanges.usedRanges, baseRange)
    
    return rollRange
end

-- Get session statistics
function LootSession:GetStatistics()
    return {
        sessionId = self.id,
        masterId = self.masterId,
        startTime = self.startTime,
        duration = GetCurrentTimestamp() - self.startTime,
        status = self.status,
        activeItemCount = #self.activeItems,
        awardedItemCount = #self.awardedItems,
        totalItemsProcessed = self.metadata.totalItemsProcessed,
        totalRollsReceived = self.metadata.totalRollsReceived,
        raidSize = self.metadata.raidSize
    }
end

-- ============================================================================
-- LootItem Data Structure  
-- ============================================================================

DataModels.LootItem = {}
local LootItem = DataModels.LootItem

-- Create a new loot item
function LootItem:New(itemLink, rollRange, itemId)
    -- Validate item link
    local linkValid, itemIdOrError = ValidateItemLink(itemLink)
    if not linkValid then
        return nil, "Invalid item link: " .. (itemIdOrError or "unknown error")
    end
    
    -- Use extracted item ID if not provided
    if not itemId then
        itemId = itemIdOrError
    end
    
    -- Validate roll range if provided
    if rollRange then
        local rangeValid, rangeError = ValidateRollRange(rollRange)
        if not rangeValid then
            return nil, "Invalid roll range: " .. (rangeError or "unknown error")
        end
    end
    
    local item = {
        -- Core identification
        id = GenerateUniqueId(),
        itemLink = itemLink,
        itemId = itemId,
        
        -- Roll management
        rollRange = rollRange,
        rolls = {},  -- Array of PlayerRoll objects
        
        -- Timing information
        dropTime = GetCurrentTimestamp(),
        expiryTime = nil, -- Will be calculated based on tradeable window
        
        -- Award information
        awardedTo = nil,
        awardTime = nil,
        status = "active", -- active, awarded, expired
        
        -- Item metadata (will be populated from WoW APIs)
        itemInfo = {
            name = nil,
            quality = nil,
            itemLevel = nil,
            itemType = nil,
            itemSubType = nil,
            stackCount = nil,
            equipLoc = nil,
            texture = nil
        },
        
        -- Roll statistics
        rollStats = {
            totalRolls = 0,
            rollsByCategory = {
                bis = 0,
                ms = 0,
                os = 0,
                coz = 0
            },
            highestRoll = {
                value = 0,
                player = nil,
                category = nil
            }
        }
    }
    
    -- Set up metatable for methods
    setmetatable(item, {__index = LootItem})
    
    -- Populate item information from WoW APIs
    item:PopulateItemInfo()
    
    -- Calculate expiry time (2 hours for tradeable items in MoP)
    item:CalculateExpiryTime()
    
    return item
end

-- Validate loot item structure
function LootItem:Validate()
    -- Validate required fields
    if not self.id or type(self.id) ~= "string" then
        return false, "Invalid item ID"
    end
    
    if not self.itemLink or type(self.itemLink) ~= "string" then
        return false, "Invalid item link"
    end
    
    if not self.itemId or type(self.itemId) ~= "number" then
        return false, "Invalid WoW item ID"
    end
    
    if not self.dropTime or type(self.dropTime) ~= "number" then
        return false, "Invalid drop time"
    end
    
    -- Validate rolls array
    if not self.rolls or type(self.rolls) ~= "table" then
        return false, "Invalid rolls array"
    end
    
    -- Validate roll range if present
    if self.rollRange then
        local rangeValid, rangeError = ValidateRollRange(self.rollRange)
        if not rangeValid then
            return false, "Invalid roll range: " .. (rangeError or "unknown error")
        end
    end
    
    -- Validate item info structure
    if not self.itemInfo or type(self.itemInfo) ~= "table" then
        return false, "Invalid item info structure"
    end
    
    -- Validate roll stats structure
    if not self.rollStats or type(self.rollStats) ~= "table" then
        return false, "Invalid roll stats structure"
    end
    
    return true
end

-- Populate item information using modern WoW APIs
function LootItem:PopulateItemInfo()
    if not self.itemLink then
        return false, "No item link available"
    end
    
    -- Use modern C_Item API to get item information
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, 
          itemSubType, itemStackCount, itemEquipLoc, itemTexture = C_Item.GetItemInfo(self.itemLink)
    
    if itemName then
        self.itemInfo.name = itemName
        self.itemInfo.quality = itemQuality
        self.itemInfo.itemLevel = itemLevel
        self.itemInfo.itemType = itemType
        self.itemInfo.itemSubType = itemSubType
        self.itemInfo.stackCount = itemStackCount
        self.itemInfo.equipLoc = itemEquipLoc
        self.itemInfo.texture = itemTexture
        
        return true
    else
        -- Item info not cached, will need to be populated later
        return false, "Item information not cached"
    end
end

-- Calculate expiry time for tradeable items
function LootItem:CalculateExpiryTime()
    -- In MoP Classic, items are tradeable for 2 hours after looting
    local tradeableWindow = 2 * 60 * 60 -- 2 hours in seconds
    self.expiryTime = self.dropTime + tradeableWindow
end

-- Add a roll to this item
function LootItem:AddRoll(playerRoll)
    if not playerRoll or not playerRoll.Validate or not playerRoll:Validate() then
        return false, "Invalid player roll"
    end
    
    -- Check if player already rolled on this item
    for _, existingRoll in ipairs(self.rolls) do
        if existingRoll.playerName == playerRoll.playerName then
            return false, "Player already rolled on this item"
        end
    end
    
    -- Validate roll is within assigned range for the category
    if self.rollRange then
        local categoryRange = self.rollRange[playerRoll.category]
        if not categoryRange then
            return false, "Invalid category for this item"
        end
        
        if playerRoll.rollValue < categoryRange.min or playerRoll.rollValue > categoryRange.max then
            return false, "Roll value outside valid range for category"
        end
    end
    
    -- Add roll to item
    table.insert(self.rolls, playerRoll)
    
    -- Update statistics
    self.rollStats.totalRolls = self.rollStats.totalRolls + 1
    self.rollStats.rollsByCategory[playerRoll.category] = self.rollStats.rollsByCategory[playerRoll.category] + 1
    
    -- Update highest roll if this is higher
    if playerRoll.rollValue > self.rollStats.highestRoll.value then
        self.rollStats.highestRoll.value = playerRoll.rollValue
        self.rollStats.highestRoll.player = playerRoll.playerName
        self.rollStats.highestRoll.category = playerRoll.category
    end
    
    return true
end

-- Get rolls sorted by category and value
function LootItem:GetSortedRolls()
    local sortedRolls = {
        bis = {},
        ms = {},
        os = {},
        coz = {}
    }
    
    -- Group rolls by category
    for _, roll in ipairs(self.rolls) do
        if sortedRolls[roll.category] then
            table.insert(sortedRolls[roll.category], roll)
        end
    end
    
    -- Sort each category by roll value (highest first)
    for category, rolls in pairs(sortedRolls) do
        table.sort(rolls, function(a, b)
            return a.rollValue > b.rollValue
        end)
    end
    
    return sortedRolls
end

-- Check if item has expired
function LootItem:IsExpired()
    if not self.expiryTime then
        return false
    end
    
    return GetCurrentTimestamp() >= self.expiryTime
end

-- Get time remaining until expiry
function LootItem:GetTimeRemaining()
    if not self.expiryTime then
        return nil
    end
    
    local remaining = self.expiryTime - GetCurrentTimestamp()
    return math.max(0, remaining)
end

-- ============================================================================
-- PlayerRoll Data Structure
-- ============================================================================

DataModels.PlayerRoll = {}
local PlayerRoll = DataModels.PlayerRoll

-- Create a new player roll
function PlayerRoll:New(playerName, category, rollValue, itemId)
    -- Validate player name
    local playerValid, playerError = ValidatePlayerName(playerName)
    if not playerValid then
        return nil, "Invalid player name: " .. (playerError or "unknown error")
    end
    
    -- Validate category
    local categoryValid, categoryError = ValidateRollCategory(category)
    if not categoryValid then
        return nil, "Invalid category: " .. (categoryError or "unknown error")
    end
    
    -- Validate roll value
    if not rollValue or type(rollValue) ~= "number" or rollValue < 1 or rollValue > 1000 then
        return nil, "Invalid roll value: must be between 1 and 1000"
    end
    
    local roll = {
        -- Core identification
        id = GenerateUniqueId(),
        playerName = playerName,
        itemId = itemId, -- Reference to the item being rolled on
        
        -- Roll information
        category = string.lower(category),
        rollValue = rollValue,
        timestamp = GetCurrentTimestamp(),
        
        -- Player information (will be populated from game APIs)
        playerInfo = {
            class = nil,
            level = nil,
            guild = nil,
            realm = nil
        },
        
        -- Roll metadata
        metadata = {
            rollSource = "addon", -- addon, manual, chat
            validated = false,
            rollRange = nil -- Will store the valid range for this roll
        }
    }
    
    -- Set up metatable for methods
    setmetatable(roll, {__index = PlayerRoll})
    
    -- Populate player information from game APIs
    roll:PopulatePlayerInfo()
    
    return roll
end

-- Validate player roll structure
function PlayerRoll:Validate()
    -- Validate required fields
    if not self.id or type(self.id) ~= "string" then
        return false, "Invalid roll ID"
    end
    
    if not self.playerName or type(self.playerName) ~= "string" then
        return false, "Invalid player name"
    end
    
    -- Validate category
    local categoryValid = ValidateRollCategory(self.category)
    if not categoryValid then
        return false, "Invalid roll category"
    end
    
    -- Validate roll value
    if not self.rollValue or type(self.rollValue) ~= "number" or 
       self.rollValue < 1 or self.rollValue > 1000 then
        return false, "Invalid roll value"
    end
    
    if not self.timestamp or type(self.timestamp) ~= "number" then
        return false, "Invalid timestamp"
    end
    
    -- Validate structures
    if not self.playerInfo or type(self.playerInfo) ~= "table" then
        return false, "Invalid player info structure"
    end
    
    if not self.metadata or type(self.metadata) ~= "table" then
        return false, "Invalid metadata structure"
    end
    
    return true
end

-- Populate player information using modern WoW APIs
function PlayerRoll:PopulatePlayerInfo()
    -- Try to get player information if they're in our group/raid
    local playerClass, playerLevel, playerGuild, playerRealm
    
    -- Check if player is in our group/raid
    local numGroupMembers = GetNumGroupMembers()
    if numGroupMembers > 0 then
        for i = 1, numGroupMembers do
            local name, realm = UnitName("raid" .. i)
            if name == self.playerName then
                playerClass = UnitClass("raid" .. i)
                playerLevel = UnitLevel("raid" .. i)
                playerGuild = GetGuildInfo("raid" .. i)
                playerRealm = realm or GetRealmName()
                break
            end
        end
    end
    
    -- If not found in raid, check party
    if not playerClass then
        local numPartyMembers = GetNumSubgroupMembers()
        for i = 1, numPartyMembers do
            local name, realm = UnitName("party" .. i)
            if name == self.playerName then
                playerClass = UnitClass("party" .. i)
                playerLevel = UnitLevel("party" .. i)
                playerGuild = GetGuildInfo("party" .. i)
                playerRealm = realm or GetRealmName()
                break
            end
        end
    end
    
    -- Check if it's the player themselves
    if not playerClass and UnitName("player") == self.playerName then
        playerClass = UnitClass("player")
        playerLevel = UnitLevel("player")
        playerGuild = GetGuildInfo("player")
        playerRealm = GetRealmName()
    end
    
    -- Store the information we found
    self.playerInfo.class = playerClass
    self.playerInfo.level = playerLevel
    self.playerInfo.guild = playerGuild
    self.playerInfo.realm = playerRealm
    
    return playerClass ~= nil
end

-- Validate roll against a specific range
function PlayerRoll:ValidateAgainstRange(rollRange)
    if not rollRange or not rollRange[self.category] then
        return false, "No valid range for category: " .. self.category
    end
    
    local categoryRange = rollRange[self.category]
    local valid = self.rollValue >= categoryRange.min and self.rollValue <= categoryRange.max
    
    if valid then
        self.metadata.validated = true
        self.metadata.rollRange = categoryRange
    end
    
    return valid
end

-- Get formatted roll display string
function PlayerRoll:GetDisplayString()
    local classColor = ""
    if self.playerInfo.class then
        -- Get class color (will be implemented in theme system)
        classColor = "|c" .. (RAID_CLASS_COLORS[self.playerInfo.class] and 
                              RAID_CLASS_COLORS[self.playerInfo.class].colorStr or "ffffffff")
    end
    
    return string.format("%s%s|r %d", classColor, self.playerName, self.rollValue)
end

-- ============================================================================
-- Data Manipulation and Query Utilities
-- ============================================================================

DataModels.Utils = {}
local Utils = DataModels.Utils

-- Find loot item by ID in a session
function Utils.FindItemById(session, itemId)
    -- Search active items
    for _, item in ipairs(session.activeItems) do
        if item.id == itemId then
            return item, "active"
        end
    end
    
    -- Search awarded items
    for _, item in ipairs(session.awardedItems) do
        if item.id == itemId then
            return item, "awarded"
        end
    end
    
    return nil, "not_found"
end

-- Find player roll for specific item
function Utils.FindPlayerRoll(item, playerName)
    for _, roll in ipairs(item.rolls) do
        if roll.playerName == playerName then
            return roll
        end
    end
    return nil
end

-- Get all rolls for a specific player across all items in session
function Utils.GetPlayerRolls(session, playerName)
    local playerRolls = {}
    
    -- Check active items
    for _, item in ipairs(session.activeItems) do
        local roll = Utils.FindPlayerRoll(item, playerName)
        if roll then
            table.insert(playerRolls, {
                item = item,
                roll = roll,
                status = "active"
            })
        end
    end
    
    -- Check awarded items
    for _, item in ipairs(session.awardedItems) do
        local roll = Utils.FindPlayerRoll(item, playerName)
        if roll then
            table.insert(playerRolls, {
                item = item,
                roll = roll,
                status = "awarded"
            })
        end
    end
    
    return playerRolls
end

-- Get session summary statistics
function Utils.GetSessionSummary(session)
    local summary = {
        sessionId = session.id,
        masterId = session.masterId,
        status = session.status,
        duration = GetCurrentTimestamp() - session.startTime,
        
        -- Item counts
        activeItems = #session.activeItems,
        awardedItems = #session.awardedItems,
        totalItems = #session.activeItems + #session.awardedItems,
        
        -- Roll statistics
        totalRolls = 0,
        rollsByCategory = {bis = 0, ms = 0, os = 0, coz = 0},
        
        -- Player participation
        uniquePlayers = {},
        playerCount = 0
    }
    
    -- Calculate roll statistics
    local allItems = {}
    for _, item in ipairs(session.activeItems) do
        table.insert(allItems, item)
    end
    for _, item in ipairs(session.awardedItems) do
        table.insert(allItems, item)
    end
    
    for _, item in ipairs(allItems) do
        for _, roll in ipairs(item.rolls) do
            summary.totalRolls = summary.totalRolls + 1
            summary.rollsByCategory[roll.category] = summary.rollsByCategory[roll.category] + 1
            
            -- Track unique players
            if not summary.uniquePlayers[roll.playerName] then
                summary.uniquePlayers[roll.playerName] = true
                summary.playerCount = summary.playerCount + 1
            end
        end
    end
    
    return summary
end

-- Validate entire session data integrity
function Utils.ValidateSessionIntegrity(session)
    local errors = {}
    
    -- Validate session structure
    local sessionValid, sessionError = session:Validate()
    if not sessionValid then
        table.insert(errors, "Session validation failed: " .. sessionError)
    end
    
    -- Validate all active items
    for i, item in ipairs(session.activeItems) do
        local itemValid, itemError = item:Validate()
        if not itemValid then
            table.insert(errors, "Active item " .. i .. " validation failed: " .. itemError)
        end
        
        -- Validate all rolls in item
        for j, roll in ipairs(item.rolls) do
            local rollValid, rollError = roll:Validate()
            if not rollValid then
                table.insert(errors, "Roll " .. j .. " in active item " .. i .. " validation failed: " .. rollError)
            end
        end
    end
    
    -- Validate all awarded items
    for i, item in ipairs(session.awardedItems) do
        local itemValid, itemError = item:Validate()
        if not itemValid then
            table.insert(errors, "Awarded item " .. i .. " validation failed: " .. itemError)
        end
        
        -- Validate all rolls in item
        for j, roll in ipairs(item.rolls) do
            local rollValid, rollError = roll:Validate()
            if not rollValid then
                table.insert(errors, "Roll " .. j .. " in awarded item " .. i .. " validation failed: " .. rollError)
            end
        end
    end
    
    return #errors == 0, errors
end

-- Export data models for external access
ParallelLoot.DataModels.LootSession = LootSession
ParallelLoot.DataModels.LootItem = LootItem
ParallelLoot.DataModels.PlayerRoll = PlayerRoll
ParallelLoot.DataModels.Utils = Utils

print("|cff888888ParallelLoot:|r DataModels module loaded successfully")