-- ParallelLoot: Parallel loot rolling system for MoP Classic raids
-- Built on Ace3 framework for maximum compatibility and performance

-- Library imports using LibStub
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local AceComm = LibStub("AceComm-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local LibSharedMedia = LibStub("LibSharedMedia-3.0")
local LibDeflate = LibStub("LibDeflate")
local LibWindow = LibStub("LibWindow-1.1")

-- Create main addon using AceAddon framework
local ParallelLoot = AceAddon:NewAddon("ParallelLoot", "AceComm-3.0", "AceEvent-3.0")

-- Addon constants
ParallelLoot.VERSION = "2.0.0"
ParallelLoot.ADDON_PREFIX = "PLoot"
ParallelLoot.API_VERSION = "MoP-Classic-Modern"

-- Global addon reference for external access
_G.ParallelLoot = ParallelLoot

-- Helper function to display addon information (for /dump ParallelLoot validation)
function ParallelLoot:GetAddonInfo()
    return {
        name = self.namespace,
        version = self.VERSION,
        apiVersion = self.API_VERSION,
        addonPrefix = self.ADDON_PREFIX,
        buildInfo = self.buildInfo,
        isEnabled = self.isEnabled,
        database = self.db and "Initialized" or "Not Initialized",
        modules = {
            LootManager = type(self.LootManager),
            RollManager = type(self.RollManager),
            UIManager = type(self.UIManager),
            CommManager = type(self.CommManager),
            DataManager = type(self.DataManager)
        },
        lifecycleCalls = self._lifecycleCalls or {}
    }
end

-- Database defaults structure for AceDB-3.0
local dbDefaults = {
    profile = {
        categories = {
            bis = "BIS",
            ms = "MS", 
            os = "OS",
            coz = "COZ"
        },
        autoStart = false,
        soundEnabled = true,
        timerWarnings = {30, 10},
        ui = {
            scale = 1.0,
            position = {},
            showTooltips = true,
            useModernTooltips = true
        },
        communication = {
            useCompression = true,
            maxRetries = 3,
            timeout = 30
        }
    },
    char = {
        preferredCategories = {},
        lastUsedRanges = {}
    },
    realm = {
        guildSettings = {}
    },
    global = {
        version = "2.0.0",
        apiVersion = "MoP-Classic-Modern",
        sessions = {
            current = {},
            history = {}
        }
    }
}

-- AceAddon lifecycle methods - Task 1.2 Implementation
function ParallelLoot:OnInitialize()
    -- Track lifecycle method calls for validation
    self._lifecycleCalls = self._lifecycleCalls or {}
    table.insert(self._lifecycleCalls, "OnInitialize")
    
    -- Initialize database with AceDB-3.0
    self.db = AceDB:New("ParallelLootDB", dbDefaults, true)
    
    -- Register profile callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    
    -- Initialize core modules (placeholders for future tasks)
    self.LootManager = {}
    self.RollManager = {}
    self.UIManager = {}
    self.CommManager = {}
    self.DataManager = {}
    
    -- Set up communication
    self:RegisterComm(self.ADDON_PREFIX)
    
    -- Initialize addon namespace and version management
    self.namespace = "ParallelLoot"
    self.buildInfo = {
        version = self.VERSION,
        apiVersion = self.API_VERSION,
        buildDate = date("%Y-%m-%d %H:%M:%S"),
        aceVersion = AceAddon.version or "Unknown"
    }
    
    print("|cff00ff00ParallelLoot|r v" .. self.VERSION .. " initialized successfully!")
    print("|cff888888ParallelLoot|r Build: " .. self.buildInfo.buildDate .. " | API: " .. self.API_VERSION)
end

function ParallelLoot:OnEnable()
    -- Track lifecycle method calls for validation
    self._lifecycleCalls = self._lifecycleCalls or {}
    table.insert(self._lifecycleCalls, "OnEnable")
    
    -- Register essential events (will be expanded in future tasks)
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    
    -- Set addon as enabled
    self.isEnabled = true
    
    print("|cff00ff00ParallelLoot|r enabled and ready!")
end

function ParallelLoot:OnDisable()
    -- Track lifecycle method calls for validation
    self._lifecycleCalls = self._lifecycleCalls or {}
    table.insert(self._lifecycleCalls, "OnDisable")
    
    -- Cleanup when addon is disabled
    self:UnregisterAllEvents()
    self:UnregisterAllComm()
    
    -- Set addon as disabled
    self.isEnabled = false
    
    print("|cff00ff00ParallelLoot|r disabled.")
end

-- Profile change handler
function ParallelLoot:RefreshConfig()
    -- Refresh configuration when profile changes
    -- This will be expanded in future tasks
    print("|cff00ff00ParallelLoot|r configuration refreshed.")
end

-- Event handlers (basic structure for future expansion)
function ParallelLoot:ADDON_LOADED(event, addonName)
    if addonName == "ParallelLoot" then
        -- Addon fully loaded
    end
end

function ParallelLoot:PLAYER_LOGIN(event)
    -- Player has logged in
end

-- Communication handler (basic structure for future expansion)
function ParallelLoot:OnCommReceived(prefix, message, distribution, sender)
    if prefix == self.ADDON_PREFIX then
        -- Handle incoming addon communication
        -- This will be expanded in future tasks
    end
end

-- Utility function to verify all libraries are loaded
function ParallelLoot:ValidateLibraries()
    local libraries = {
        "AceAddon-3.0",
        "AceDB-3.0", 
        "AceEvent-3.0",
        "AceComm-3.0",
        "AceGUI-3.0",
        "AceConfig-3.0",
        "AceConfigDialog-3.0",
        "AceSerializer-3.0",
        "LibSharedMedia-3.0",
        "LibDeflate",
        "LibWindow-1.1"
    }
    
    local missing = {}
    for _, lib in ipairs(libraries) do
        if not LibStub:GetLibrary(lib, true) then
            table.insert(missing, lib)
        end
    end
    
    if #missing > 0 then
        print("|cffff0000ParallelLoot Error:|r Missing libraries: " .. table.concat(missing, ", "))
        return false
    else
        print("|cff00ff00ParallelLoot:|r All required libraries loaded successfully!")
        return true
    end
end

-- Test function for validation
function ParallelLoot:RunTests()
    print("|cff00ff00ParallelLoot Test Suite:|r Running comprehensive validation tests...")
    
    -- Test 1: Library validation
    local librariesOK = self:ValidateLibraries()
    print("Library validation: " .. (librariesOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 2: Database validation
    local dbOK = self.db and self.db.profile and self.db.profile.categories
    print("Database validation: " .. (dbOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 3: Addon object validation
    local addonOK = self.VERSION and self.ADDON_PREFIX and self.API_VERSION
    print("Addon object validation: " .. (addonOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 4: AceAddon framework validation (Task 1.2)
    local aceFrameworkOK = self.namespace and self.buildInfo and type(self.OnInitialize) == "function"
    print("AceAddon framework: " .. (aceFrameworkOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 5: Lifecycle method order validation (Task 1.2)
    local lifecycleOK = self:TestLifecycleOrder()
    print("Lifecycle order: " .. (lifecycleOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    local allTestsPass = librariesOK and dbOK and addonOK and aceFrameworkOK and lifecycleOK
    print("|cff00ff00ParallelLoot Test Suite:|r " .. (allTestsPass and "|cff00ff00ALL TESTS PASSED|r" or "|cffff0000SOME TESTS FAILED|r"))
    
    return allTestsPass
end

-- Unit test for lifecycle method order - Task 1.2 Implementation
function ParallelLoot:TestLifecycleOrder()
    print("|cff00ff00ParallelLoot Lifecycle Test:|r Verifying method call order...")
    
    local expectedOrder = {"OnInitialize", "OnEnable"}
    local actualCalls = self._lifecycleCalls or {}
    
    -- Check if we have the expected calls
    local orderCorrect = true
    local minLength = math.min(#expectedOrder, #actualCalls)
    
    for i = 1, minLength do
        if expectedOrder[i] ~= actualCalls[i] then
            orderCorrect = false
            break
        end
    end
    
    -- Check if OnInitialize was called before OnEnable
    local initializeIndex, enableIndex = nil, nil
    for i, call in ipairs(actualCalls) do
        if call == "OnInitialize" then initializeIndex = i end
        if call == "OnEnable" then enableIndex = i end
    end
    
    local correctSequence = initializeIndex and enableIndex and initializeIndex < enableIndex
    
    print("Lifecycle calls recorded: " .. table.concat(actualCalls, " -> "))
    print("Expected order: " .. table.concat(expectedOrder, " -> "))
    print("Correct sequence: " .. (correctSequence and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return correctSequence
end

-- Validation function for specific tasks
function ParallelLoot:ValidateTask(taskId)
    if taskId == "1.1" then
        print("|cff00ff00ParallelLoot Task 1.1 Validation:|r")
        
        -- Validate addon loads without errors
        local addonLoaded = self and self.VERSION
        print("Addon loaded: " .. (addonLoaded and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate all libraries accessible
        local librariesOK = self:ValidateLibraries()
        
        -- Validate database initialized
        local dbOK = self.db and self.db.profile
        print("Database initialized: " .. (dbOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        local taskComplete = addonLoaded and librariesOK and dbOK
        print("Task 1.1 Status: " .. (taskComplete and "|cff00ff00COMPLETE|r" or "|cffff0000INCOMPLETE|r"))
        
        return taskComplete
        
    elseif taskId == "1.2" then
        print("|cff00ff00ParallelLoot Task 1.2 Validation:|r")
        
        -- Validate AceAddon framework initialization
        local aceAddonOK = self.namespace and self.buildInfo
        print("AceAddon framework: " .. (aceAddonOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate lifecycle methods implemented
        local lifecycleOK = type(self.OnInitialize) == "function" and 
                           type(self.OnEnable) == "function" and 
                           type(self.OnDisable) == "function"
        print("Lifecycle methods: " .. (lifecycleOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate namespace and version management
        local namespaceOK = self.namespace == "ParallelLoot" and 
                           self.VERSION == "2.0.0" and
                           self.buildInfo.version == self.VERSION
        print("Namespace/Version: " .. (namespaceOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate lifecycle call order
        local orderOK = self:TestLifecycleOrder()
        
        -- Validate addon object structure
        local objectOK = _G.ParallelLoot == self and self.isEnabled ~= nil
        print("Addon object: " .. (objectOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        local taskComplete = aceAddonOK and lifecycleOK and namespaceOK and orderOK and objectOK
        print("Task 1.2 Status: " .. (taskComplete and "|cff00ff00COMPLETE|r" or "|cffff0000INCOMPLETE|r"))
        
        return taskComplete
    end
    
    print("|cffff0000ParallelLoot:|r Unknown task ID: " .. tostring(taskId))
    return false
end