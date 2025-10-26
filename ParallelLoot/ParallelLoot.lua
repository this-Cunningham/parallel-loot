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

-- Database defaults structure for AceDB-3.0 - Task 1.3 Implementation
local dbDefaults = {
    profile = {
        -- Roll category configuration
        categories = {
            bis = "BIS",
            ms = "MS", 
            os = "OS",
            coz = "COZ"
        },
        categoryPriorities = {
            bis = 1,
            ms = 2,
            os = 3,
            coz = 4
        },
        
        -- Session management settings
        autoStart = false,
        autoAward = false,
        sessionTimeout = 3600, -- 1 hour in seconds
        
        -- Audio and notification settings
        soundEnabled = true,
        rollSounds = true,
        awardSounds = true,
        timerWarnings = {30, 10}, -- Warning times in seconds
        
        -- User interface preferences
        ui = {
            scale = 1.0,
            position = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = 0,
                yOfs = 0
            },
            showTooltips = true,
            useModernTooltips = true,
            darkTheme = true,
            compactMode = false,
            showClassColors = true,
            animationsEnabled = true
        },
        
        -- Communication settings
        communication = {
            useCompression = true,
            maxRetries = 3,
            timeout = 30,
            debugMode = false,
            logLevel = "INFO"
        },
        
        -- Roll range configuration
        rollRanges = {
            baseRange = 100,
            categoryOffsets = {
                bis = 0,  -- Full range (1-100)
                ms = -1,  -- 1-99
                os = -2,  -- 1-98
                coz = -3  -- 1-97
            }
        },
        
        -- Loot filtering preferences
        filtering = {
            showUnusableItems = false,
            classFiltering = true,
            armorTypeFiltering = true,
            weaponTypeFiltering = true
        }
    },
    
    -- Character-specific data
    char = {
        -- Personal roll preferences
        preferredCategories = {
            -- itemId = category mapping for quick rolling
        },
        lastUsedRanges = {},
        
        -- Personal statistics
        stats = {
            totalRolls = 0,
            itemsWon = 0,
            sessionsParticipated = 0,
            lastSessionDate = nil
        },
        
        -- Character-specific UI state
        uiState = {
            lastOpenedTab = "active",
            expandedItems = {},
            windowVisible = false
        }
    },
    
    -- Realm-specific data
    realm = {
        -- Guild and server-specific settings
        guildSettings = {
            -- guildName = { loot rules, DKP integration, etc. }
        },
        
        -- Known players and their preferences
        knownPlayers = {
            -- playerName = { class, lastSeen, preferences }
        },
        
        -- Realm-specific loot rules
        lootRules = {
            defaultSystem = "parallel",
            allowCrossRealm = true
        }
    },
    
    -- Global (account-wide) data
    global = {
        -- Version and compatibility tracking
        version = "2.0.0",
        apiVersion = "MoP-Classic-Modern",
        dbVersion = 1,
        
        -- Session data
        sessions = {
            current = {},
            history = {},
            maxHistoryEntries = 50
        },
        
        -- Global preferences
        preferences = {
            enableDebugMode = false,
            enableBetaFeatures = false,
            dataCollection = true
        },
        
        -- Migration tracking
        migration = {
            lastMigrationVersion = "2.0.0",
            migrationHistory = {}
        }
    }
}

-- AceAddon lifecycle methods - Task 1.2 & 1.3 Implementation
function ParallelLoot:OnInitialize()
    -- Track lifecycle method calls for validation
    self._lifecycleCalls = self._lifecycleCalls or {}
    table.insert(self._lifecycleCalls, "OnInitialize")
    
    -- Initialize database with AceDB-3.0 - Task 1.3 Implementation
    self.db = AceDB:New("ParallelLootDB", dbDefaults, true)
    
    -- Validate database initialization
    if not self.db then
        error("ParallelLoot: Failed to initialize AceDB database!")
        return
    end
    
    -- Register profile callbacks for configuration management
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileCopied") 
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
    self.db.RegisterCallback(self, "OnNewProfile", "OnNewProfile")
    self.db.RegisterCallback(self, "OnProfileDeleted", "OnProfileDeleted")
    
    -- Perform data migration if needed
    self:MigrateDatabase()
    
    -- Initialize database-dependent systems
    self:InitializeDatabaseSystems()
    
    -- Initialize core modules (placeholders for future tasks)
    self.LootManager = {}
    self.RollManager = {}
    self.UIManager = {}
    self.CommManager = {}
    self.DataManager = {}
    
    -- Initialize RollRangeManager - Task 2.2 Implementation
    if self.RollRangeManager then
        local success = self.RollRangeManager:Initialize()
        if success then
            -- Integrate with existing data models
            self.RollRangeManager:IntegrateWithLootSession()
        else
            print("|cffff0000ParallelLoot Error:|r Failed to initialize RollRangeManager")
        end
    end
    
    -- ThemeManager will be initialized after all files are loaded
    
    -- Set up communication
    self:RegisterComm(self.ADDON_PREFIX)
    
    -- Initialize addon namespace and version management
    self.namespace = "ParallelLoot"
    self.buildInfo = {
        version = self.VERSION,
        apiVersion = self.API_VERSION,
        buildDate = date("%Y-%m-%d %H:%M:%S"),
        aceVersion = AceAddon.version or "Unknown",
        dbVersion = self.db.global.dbVersion
    }
    
    print("|cff00ff00ParallelLoot|r v" .. self.VERSION .. " initialized successfully!")
    print("|cff888888ParallelLoot|r Build: " .. self.buildInfo.buildDate .. " | API: " .. self.API_VERSION)
    print("|cff888888ParallelLoot|r Database: Profile '" .. self.db:GetCurrentProfile() .. "' | Version " .. self.db.global.dbVersion)
end

function ParallelLoot:OnEnable()
    -- Track lifecycle method calls for validation
    self._lifecycleCalls = self._lifecycleCalls or {}
    table.insert(self._lifecycleCalls, "OnEnable")
    
    -- Register essential events (will be expanded in future tasks)
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    
    -- Initialize ThemeManager - Task 1.4 Implementation
    self:InitializeThemeManager()
    
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

-- AceDB Profile Callback Handlers - Task 1.3 Implementation

function ParallelLoot:OnProfileChanged(event, database, newProfileKey)
    print("|cff00ff00ParallelLoot|r Profile changed to: " .. newProfileKey)
    self:RefreshConfig()
    self:RefreshUI()
end

function ParallelLoot:OnProfileCopied(event, database, sourceProfileKey)
    print("|cff00ff00ParallelLoot|r Profile copied from: " .. sourceProfileKey)
    self:RefreshConfig()
    self:RefreshUI()
end

function ParallelLoot:OnProfileReset(event, database)
    print("|cff00ff00ParallelLoot|r Profile reset to defaults")
    self:RefreshConfig()
    self:RefreshUI()
end

function ParallelLoot:OnNewProfile(event, database, newProfileKey)
    print("|cff00ff00ParallelLoot|r New profile created: " .. newProfileKey)
    -- Initialize new profile with character-specific defaults
    self:InitializeNewProfile(newProfileKey)
end

function ParallelLoot:OnProfileDeleted(event, database, deletedProfileKey)
    print("|cff00ff00ParallelLoot|r Profile deleted: " .. deletedProfileKey)
    -- Cleanup any profile-specific data
    self:CleanupDeletedProfile(deletedProfileKey)
end

-- Configuration refresh handler
function ParallelLoot:RefreshConfig()
    -- Refresh configuration when profile changes
    -- Validate current profile settings
    self:ValidateProfileSettings()
    
    -- Update any cached configuration values
    self:UpdateCachedSettings()
    
    -- Notify other systems of configuration change
    self:FireConfigChangedEvent()
    
    print("|cff00ff00ParallelLoot|r Configuration refreshed for profile: " .. self.db:GetCurrentProfile())
end

-- UI refresh handler for profile changes
function ParallelLoot:RefreshUI()
    -- Refresh UI elements when profile changes
    -- This will be expanded in future UI tasks
    if self.UIManager and self.UIManager.RefreshAll then
        self.UIManager:RefreshAll()
    end
end

-- Initialize new profile with character-specific defaults
function ParallelLoot:InitializeNewProfile(profileKey)
    -- Set character-specific defaults for new profiles
    local playerClass = UnitClass("player")
    local playerName = UnitName("player")
    
    -- Apply class-specific default settings
    if playerClass then
        -- This will be expanded when class filtering is implemented
        self.db.profile.filtering.classFiltering = true
    end
    
    print("|cff888888ParallelLoot|r Initialized new profile '" .. profileKey .. "' for " .. (playerName or "Unknown") .. " (" .. (playerClass or "Unknown") .. ")")
end

-- Cleanup deleted profile data
function ParallelLoot:CleanupDeletedProfile(profileKey)
    -- Remove any profile-specific cached data
    -- This will be expanded as more systems are added
    print("|cff888888ParallelLoot|r Cleaned up data for deleted profile: " .. profileKey)
end

-- Validate profile settings for consistency
function ParallelLoot:ValidateProfileSettings()
    local profile = self.db.profile
    
    -- Validate category configuration
    if not profile.categories or not profile.categories.bis then
        print("|cffff8800ParallelLoot Warning:|r Invalid category configuration, resetting to defaults")
        profile.categories = dbDefaults.profile.categories
    end
    
    -- Validate UI settings
    if not profile.ui or type(profile.ui.scale) ~= "number" or profile.ui.scale <= 0 then
        print("|cffff8800ParallelLoot Warning:|r Invalid UI scale, resetting to default")
        profile.ui.scale = 1.0
    end
    
    -- Validate timer warnings
    if not profile.timerWarnings or #profile.timerWarnings == 0 then
        profile.timerWarnings = {30, 10}
    end
end

-- Update cached settings for performance
function ParallelLoot:UpdateCachedSettings()
    -- Cache frequently accessed settings for performance
    self._cachedSettings = {
        categories = self.db.profile.categories,
        uiScale = self.db.profile.ui.scale,
        soundEnabled = self.db.profile.soundEnabled,
        darkTheme = self.db.profile.ui.darkTheme,
        useCompression = self.db.profile.communication.useCompression
    }
end

-- Fire configuration changed event for other systems
function ParallelLoot:FireConfigChangedEvent()
    -- This will be used by other systems to respond to config changes
    -- Will be expanded when event system is implemented
    if self.callbacks then
        self.callbacks:Fire("ConfigChanged", self.db.profile)
    end
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
    
    -- Test 2: Database validation (Task 1.3)
    local dbOK = self.db and self.db.profile and self.db.profile.categories and 
                 self.db.char and self.db.realm and self.db.global
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
    
    -- Test 6: AceDB profile system validation (Task 1.3)
    local profileSystemOK = self:TestProfileSystem()
    print("Profile system: " .. (profileSystemOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 7: Database persistence validation (Task 1.3)
    local persistenceOK = self:TestDatabaseStructure()
    print("Database structure: " .. (persistenceOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 8: Theme system validation (Task 1.4)
    local themeSystemOK = self:TestThemeSystem()
    print("Theme system: " .. (themeSystemOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    local allTestsPass = librariesOK and dbOK and addonOK and aceFrameworkOK and 
                        lifecycleOK and profileSystemOK and persistenceOK and themeSystemOK
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

-- Unit test for profile system - Task 1.3 Implementation
function ParallelLoot:TestProfileSystem()
    print("|cff00ff00ParallelLoot Profile System Test:|r Testing AceDB profile functionality...")
    
    -- Test profile management functions exist
    local functionsExist = type(self.db.GetCurrentProfile) == "function" and
                          type(self.db.GetProfiles) == "function" and
                          type(self.db.SetProfile) == "function"
    
    if not functionsExist then
        print("Profile management functions missing")
        return false
    end
    
    -- Test current profile access
    local currentProfile = self.db:GetCurrentProfile()
    local profileValid = currentProfile and type(currentProfile) == "string"
    
    print("Current profile: " .. (currentProfile or "nil"))
    print("Profile valid: " .. (profileValid and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test profile list access
    local profiles = self.db:GetProfiles()
    local profileListValid = profiles and type(profiles) == "table"
    
    print("Profile list valid: " .. (profileListValid and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return functionsExist and profileValid and profileListValid
end

-- Unit test for profile switching - Task 1.3 Implementation
function ParallelLoot:TestProfileSwitching()
    print("|cff00ff00ParallelLoot Profile Switch Test:|r Testing profile switching functionality...")
    
    -- Get current profile
    local originalProfile = self.db:GetCurrentProfile()
    
    -- Test creating a temporary test profile
    local testProfileName = "PLootTest_" .. time()
    
    -- Store original callback count
    local originalCallbackCount = #(self._profileCallbacks or {})
    
    -- Create test profile by setting it (AceDB creates it automatically)
    local success, err = pcall(function()
        self.db:SetProfile(testProfileName)
    end)
    
    if not success then
        print("Profile creation failed: " .. (err or "unknown error"))
        return false
    end
    
    -- Verify we're on the test profile
    local currentProfile = self.db:GetCurrentProfile()
    local switchedCorrectly = currentProfile == testProfileName
    
    print("Switched to test profile: " .. (switchedCorrectly and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test profile data isolation
    local testValue = "test_" .. math.random(1000, 9999)
    self.db.profile.testSwitchValue = testValue
    
    -- Switch back to original profile
    success, err = pcall(function()
        self.db:SetProfile(originalProfile)
    end)
    
    if not success then
        print("Profile restoration failed: " .. (err or "unknown error"))
        return false
    end
    
    -- Verify we're back on original profile
    local restoredCorrectly = self.db:GetCurrentProfile() == originalProfile
    print("Restored original profile: " .. (restoredCorrectly and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Verify data isolation (test value should not exist in original profile)
    local dataIsolated = self.db.profile.testSwitchValue ~= testValue
    print("Profile data isolation: " .. (dataIsolated and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Clean up test profile
    success, err = pcall(function()
        self.db:DeleteProfile(testProfileName)
    end)
    
    if not success then
        print("Test profile cleanup failed: " .. (err or "unknown error"))
    end
    
    return switchedCorrectly and restoredCorrectly and dataIsolated
end

-- Unit test for database structure - Task 1.3 Implementation
function ParallelLoot:TestDatabaseStructure()
    print("|cff00ff00ParallelLoot Database Structure Test:|r Validating database organization...")
    
    -- Test profile structure
    local profileOK = self.db.profile and
                     self.db.profile.categories and
                     self.db.profile.ui and
                     self.db.profile.communication and
                     self.db.profile.rollRanges and
                     self.db.profile.filtering
    
    print("Profile structure: " .. (profileOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test character structure
    local charOK = self.db.char and
                  self.db.char.stats and
                  self.db.char.uiState and
                  type(self.db.char.preferredCategories) == "table"
    
    print("Character structure: " .. (charOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test realm structure
    local realmOK = self.db.realm and
                   self.db.realm.guildSettings and
                   self.db.realm.knownPlayers and
                   self.db.realm.lootRules
    
    print("Realm structure: " .. (realmOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test global structure
    local globalOK = self.db.global and
                    self.db.global.version and
                    self.db.global.sessions and
                    self.db.global.migration and
                    self.db.global.dbVersion
    
    print("Global structure: " .. (globalOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test migration system
    local migrationOK = type(self.MigrateDatabase) == "function" and
                       self.db.global.migration.lastMigrationVersion and
                       type(self.db.global.migration.migrationHistory) == "table"
    
    print("Migration system: " .. (migrationOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return profileOK and charOK and realmOK and globalOK and migrationOK
end

-- Data Migration System - Task 1.3 Implementation

function ParallelLoot:MigrateDatabase()
    local global = self.db.global
    local currentVersion = global.dbVersion or 0
    local targetVersion = 1
    
    if currentVersion < targetVersion then
        print("|cff00ff00ParallelLoot|r Migrating database from version " .. currentVersion .. " to " .. targetVersion)
        
        -- Perform migration steps
        if currentVersion < 1 then
            self:MigrateToVersion1()
        end
        
        -- Update version tracking
        global.dbVersion = targetVersion
        global.migration.lastMigrationVersion = self.VERSION
        table.insert(global.migration.migrationHistory, {
            fromVersion = currentVersion,
            toVersion = targetVersion,
            timestamp = time(),
            addonVersion = self.VERSION
        })
        
        print("|cff00ff00ParallelLoot|r Database migration completed successfully")
    end
    
    -- Check for legacy data migration
    self:MigrateLegacyData()
end

function ParallelLoot:MigrateToVersion1()
    -- Migration to database version 1
    print("|cff888888ParallelLoot|r Applying database migration to version 1...")
    
    -- Initialize new fields that didn't exist in version 0
    local profile = self.db.profile
    
    -- Ensure all new profile fields exist
    if not profile.categoryPriorities then
        profile.categoryPriorities = dbDefaults.profile.categoryPriorities
    end
    
    if not profile.rollRanges then
        profile.rollRanges = dbDefaults.profile.rollRanges
    end
    
    if not profile.filtering then
        profile.filtering = dbDefaults.profile.filtering
    end
    
    -- Migrate character data structure
    local char = self.db.char
    if not char.stats then
        char.stats = dbDefaults.char.stats
    end
    
    if not char.uiState then
        char.uiState = dbDefaults.char.uiState
    end
    
    print("|cff888888ParallelLoot|r Database migration to version 1 completed")
end

function ParallelLoot:MigrateLegacyData()
    -- Check for old ParallelLootDB format and migrate if needed
    if _G.ParallelLootDB and not _G.ParallelLootDB.migrated then
        print("|cff00ff00ParallelLoot|r Migrating legacy database format...")
        
        local legacyDB = _G.ParallelLootDB
        
        -- Migrate settings to new profile structure
        if legacyDB.settings then
            local profile = self.db.profile
            
            -- Migrate category names
            if legacyDB.settings.categories then
                profile.categories = legacyDB.settings.categories
            end
            
            -- Migrate UI settings
            if legacyDB.settings.ui then
                for key, value in pairs(legacyDB.settings.ui) do
                    if profile.ui[key] ~= nil then
                        profile.ui[key] = value
                    end
                end
            end
            
            -- Migrate other settings
            profile.autoStart = legacyDB.settings.autoStart or false
            profile.soundEnabled = legacyDB.settings.soundEnabled or true
        end
        
        -- Migrate session data to global structure
        if legacyDB.sessions then
            self.db.global.sessions = legacyDB.sessions
        end
        
        -- Mark legacy data as migrated
        legacyDB.migrated = true
        
        print("|cff00ff00ParallelLoot|r Legacy database migration completed")
    end
end

-- Initialize database-dependent systems
function ParallelLoot:InitializeDatabaseSystems()
    -- Initialize cached settings for performance
    self:UpdateCachedSettings()
    
    -- Validate current profile
    self:ValidateProfileSettings()
    
    -- Initialize character-specific data
    self:InitializeCharacterData()
    
    -- Clean up old session data if needed
    self:CleanupOldSessions()
    
    print("|cff888888ParallelLoot|r Database systems initialized")
end

-- Initialize character-specific data
function ParallelLoot:InitializeCharacterData()
    local char = self.db.char
    local playerName = UnitName("player")
    local playerClass = UnitClass("player")
    
    -- Update character info if available
    if playerName and playerClass then
        -- Store character info for reference
        char.characterInfo = {
            name = playerName,
            class = playerClass,
            lastLogin = time()
        }
    end
    
    -- Initialize stats if this is first login
    if not char.stats.lastSessionDate then
        char.stats.lastSessionDate = time()
    end
end

-- Cleanup old session data
function ParallelLoot:CleanupOldSessions()
    local global = self.db.global
    local maxHistory = global.sessions.maxHistoryEntries or 50
    
    -- Clean up old session history
    if global.sessions.history and #global.sessions.history > maxHistory then
        local excess = #global.sessions.history - maxHistory
        for i = 1, excess do
            table.remove(global.sessions.history, 1)
        end
        print("|cff888888ParallelLoot|r Cleaned up " .. excess .. " old session records")
    end
end

-- ThemeManager initialization - Task 1.4 Implementation
function ParallelLoot:InitializeThemeManager()
    -- Initialize ThemeManager if available
    if self.ThemeManager then
        self.ThemeManager:Initialize()
        print("|cff888888ParallelLoot:|r ThemeManager initialized successfully")
    else
        print("|cffff8800ParallelLoot Warning:|r ThemeManager not found, theme system unavailable")
    end
end

-- Create test widgets for theme validation - Task 1.4 Implementation
function ParallelLoot:CreateThemeTestWidgets()
    if not self.ThemeManager then
        print("|cffff0000ParallelLoot:|r ThemeManager not available for testing")
        return false
    end
    
    return self.ThemeManager:CreateTestWidgets()
end

-- Clean up theme test widgets
function ParallelLoot:CleanupThemeTestWidgets()
    if self.ThemeManager and self.ThemeManager.CleanupTestWidgets then
        self.ThemeManager:CleanupTestWidgets()
    end
end

-- Database utility functions
function ParallelLoot:GetProfileList()
    return self.db:GetProfiles()
end

function ParallelLoot:GetCurrentProfile()
    return self.db:GetCurrentProfile()
end

function ParallelLoot:SetProfile(profileName)
    self.db:SetProfile(profileName)
end

function ParallelLoot:DeleteProfile(profileName)
    self.db:DeleteProfile(profileName)
end

function ParallelLoot:ResetProfile()
    self.db:ResetProfile()
end

function ParallelLoot:CopyProfile(sourceProfile)
    self.db:CopyProfile(sourceProfile)
end

-- Theme system testing function - Task 1.4 Implementation
function ParallelLoot:TestThemeSystem()
    print("|cff00ff00ParallelLoot Theme System Test:|r Testing dark theme system...")
    
    -- Test ThemeManager existence and initialization
    local themeManagerExists = self.ThemeManager and type(self.ThemeManager) == "table"
    if not themeManagerExists then
        print("ThemeManager not loaded")
        return false
    end
    
    -- Test theme system components
    local componentsOK = self.ThemeManager.Colors and 
                        self.ThemeManager.Media and
                        type(self.ThemeManager.Initialize) == "function"
    print("Theme components: " .. (componentsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test LibSharedMedia integration
    local mediaOK = LibSharedMedia and 
                   type(self.ThemeManager.RegisterCustomMedia) == "function"
    print("LibSharedMedia integration: " .. (mediaOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test theme application functions
    local functionsOK = type(self.ThemeManager.ApplyFrameTheme) == "function" and
                       type(self.ThemeManager.ApplyButtonTheme) == "function" and
                       type(self.ThemeManager.ApplyTextTheme) == "function"
    print("Theme functions: " .. (functionsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test color palette completeness
    local colorsOK = self.ThemeManager.Colors.Background and
                    self.ThemeManager.Colors.Text and
                    self.ThemeManager.Colors.Accent and
                    self.ThemeManager.Colors.Interactive
    print("Color palette: " .. (colorsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return componentsOK and mediaOK and functionsOK and colorsOK
end

-- Basic theme system validation - Task 1.4 Implementation
function ParallelLoot:ValidateThemeSystemBasic()
    print("|cff888888ParallelLoot:|r Running basic theme system validation...")
    
    -- Test color palette structure
    local colorTests = {
        "Background.Primary", "Background.Secondary", "Background.Tertiary",
        "Text.Primary", "Text.Secondary", "Text.Muted",
        "Accent.Primary", "Accent.Secondary", "Accent.Success",
        "Border.Default", "Border.Subtle",
        "Interactive.Button.Normal", "Interactive.Progress.Fill"
    }
    
    local colorsPassed = 0
    for _, colorPath in ipairs(colorTests) do
        local parts = {}
        for part in string.gmatch(colorPath, "[^%.]+") do
            table.insert(parts, part)
        end
        
        local current = self.ThemeManager.Colors
        local valid = true
        for _, part in ipairs(parts) do
            if current and current[part] then
                current = current[part]
            else
                valid = false
                break
            end
        end
        
        if valid and type(current) == "table" and #current >= 3 then
            colorsPassed = colorsPassed + 1
        end
    end
    
    print("|cff888888ParallelLoot:|r Color palette validation: " .. colorsPassed .. "/" .. #colorTests .. " colors defined")
    
    -- Test media registration
    local mediaTests = {
        {type = "font", key = self.ThemeManager.Media.Fonts.Primary},
        {type = "font", key = self.ThemeManager.Media.Fonts.Secondary},
        {type = "background", key = self.ThemeManager.Media.Textures.Background}
    }
    
    local mediaPassed = 0
    for _, media in ipairs(mediaTests) do
        if LibSharedMedia:IsValid(media.type, media.key) then
            mediaPassed = mediaPassed + 1
        end
    end
    
    print("|cff888888ParallelLoot:|r Media registration validation: " .. mediaPassed .. "/" .. #mediaTests .. " media registered")
    
    -- Test utility functions
    local utilityTests = {
        {name = "GetCategoryColor", func = self.ThemeManager.GetCategoryColor, arg = "bis"},
        {name = "GetClassColor", func = self.ThemeManager.GetClassColor, arg = "WARRIOR"},
        {name = "ColorToHex", func = self.ThemeManager.ColorToHex, arg = {1.0, 0.5, 0.0, 1.0}},
        {name = "CreateColoredText", func = self.ThemeManager.CreateColoredText, arg = "Test"}
    }
    
    local utilityPassed = 0
    for _, test in ipairs(utilityTests) do
        if type(test.func) == "function" then
            local success, result = pcall(test.func, self.ThemeManager, test.arg)
            if success and result then
                utilityPassed = utilityPassed + 1
            end
        end
    end
    
    print("|cff888888ParallelLoot:|r Utility functions validation: " .. utilityPassed .. "/" .. #utilityTests .. " functions working")
    
    local totalTests = #colorTests + #mediaTests + #utilityTests
    local totalPassed = colorsPassed + mediaPassed + utilityPassed
    local success = totalPassed >= (totalTests * 0.8) -- 80% pass rate required
    
    print("|cff888888ParallelLoot:|r Basic validation result: " .. totalPassed .. "/" .. totalTests .. " (" .. 
          math.floor((totalPassed/totalTests)*100) .. "%) - " .. (success and "PASS" or "FAIL"))
    
    return success
end

-- Database validation and testing functions
function ParallelLoot:TestDatabasePersistence()
    print("|cff00ff00ParallelLoot Database Test:|r Testing data persistence...")
    
    -- Test profile data persistence
    local testKey = "testPersistence_" .. time()
    local testValue = "test_" .. math.random(1000, 9999)
    
    -- Store test data
    self.db.profile.testData = {
        key = testKey,
        value = testValue,
        timestamp = time()
    }
    
    -- Test character data persistence
    self.db.char.testData = {
        characterTest = testValue,
        timestamp = time()
    }
    
    -- Test global data persistence
    self.db.global.testData = {
        globalTest = testValue,
        timestamp = time()
    }
    
    print("Test data stored - Profile: " .. testKey .. " = " .. testValue)
    print("Use /reload and then /script ParallelLoot:ValidatePersistence() to verify")
    
    return true
end

function ParallelLoot:ValidatePersistence()
    print("|cff00ff00ParallelLoot Persistence Test:|r Validating stored data...")
    
    local profileOK = self.db.profile.testData and self.db.profile.testData.key and self.db.profile.testData.value
    local charOK = self.db.char.testData and self.db.char.testData.characterTest
    local globalOK = self.db.global.testData and self.db.global.testData.globalTest
    
    print("Profile data persistence: " .. (profileOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    print("Character data persistence: " .. (charOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    print("Global data persistence: " .. (globalOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Clean up test data
    self.db.profile.testData = nil
    self.db.char.testData = nil
    self.db.global.testData = nil
    
    return profileOK and charOK and globalOK
end

-- Create test session for in-game validation - Task 2.1 Implementation
function ParallelLoot:CreateTestSession()
    print("|cff00ff00ParallelLoot Test Session:|r Creating test loot session with sample data...")
    
    if not self.DataModels then
        print("|cffff0000Error:|r DataModels module not loaded")
        return false
    end
    
    -- Create test session
    local session = self.DataModels.LootSession:New("TestMaster")
    if not session then
        print("|cffff0000Error:|r Failed to create test session")
        return false
    end
    
    print("Created session: " .. session.id .. " (Master: " .. session.masterId .. ")")
    
    -- Create test item with MoP raid item
    local itemLink = "|cffa335ee|Hitem:71617:0:0:0:0:0:0:0:85:0:0|h[Zin'rokh, Destroyer of Worlds]|h|r"
    local rollRange = session:GetNextRollRange()
    local item = self.DataModels.LootItem:New(itemLink, rollRange, 71617)
    
    if not item then
        print("|cffff0000Error:|r Failed to create test item")
        return false
    end
    
    print("Created item: " .. item.id .. " (Roll range: " .. rollRange.baseRange .. "-" .. (rollRange.baseRange + 99) .. ")")
    
    -- Add item to session
    local success = session:AddItem(item)
    if not success then
        print("|cffff0000Error:|r Failed to add item to session")
        return false
    end
    
    -- Create test rolls
    local testRolls = {
        {player = "Thorgrim", category = "bis", value = 95},
        {player = "Elaria", category = "ms", value = 88},
        {player = "Kazrak", category = "os", value = 76},
        {player = "Drakken", category = "coz", value = 42}
    }
    
    for _, rollData in ipairs(testRolls) do
        local roll = self.DataModels.PlayerRoll:New(rollData.player, rollData.category, rollData.value, item.id)
        if roll then
            local rollSuccess = item:AddRoll(roll)
            if rollSuccess then
                print("Added roll: " .. rollData.player .. " rolled " .. rollData.value .. " for " .. rollData.category)
            else
                print("|cffff8800Warning:|r Failed to add roll for " .. rollData.player)
            end
        else
            print("|cffff8800Warning:|r Failed to create roll for " .. rollData.player)
        end
    end
    
    -- Validate session integrity
    local valid, errors = self.DataModels.Utils.ValidateSessionIntegrity(session)
    if not valid then
        print("|cffff0000Error:|r Session integrity validation failed:")
        for _, error in ipairs(errors) do
            print("  " .. error)
        end
        return false
    end
    
    -- Store test session for inspection
    self._testSession = session
    
    -- Display session statistics
    local stats = session:GetStatistics()
    print("|cff00ff00Test Session Statistics:|r")
    print("  Session ID: " .. stats.sessionId)
    print("  Master: " .. stats.masterId)
    print("  Active Items: " .. stats.activeItemCount)
    print("  Total Rolls: " .. item.rollStats.totalRolls)
    print("  Highest Roll: " .. item.rollStats.highestRoll.value .. " by " .. (item.rollStats.highestRoll.player or "Unknown"))
    
    -- Display sorted rolls
    local sortedRolls = item:GetSortedRolls()
    print("|cff00ff00Roll Results:|r")
    for category, rolls in pairs(sortedRolls) do
        if #rolls > 0 then
            print("  " .. string.upper(category) .. ":")
            for _, roll in ipairs(rolls) do
                print("    " .. roll.playerName .. ": " .. roll.rollValue)
            end
        end
    end
    
    print("|cff00ff00Test Session Created Successfully!|r")
    print("Use |cff888888/script ParallelLoot:InspectTestSession()|r to inspect the session data")
    print("Use |cff888888/dump ParallelLoot._testSession|r to view raw session data")
    
    return true
end

-- Inspect test session data
function ParallelLoot:InspectTestSession()
    if not self._testSession then
        print("|cffff0000Error:|r No test session available. Run /script ParallelLoot:CreateTestSession() first")
        return
    end
    
    local session = self._testSession
    print("|cff00ff00Test Session Inspection:|r")
    
    -- Validate session structure
    local valid, error = session:Validate()
    print("Session Valid: " .. (valid and "|cff00ff00YES|r" or "|cffff0000NO|r - " .. (error or "unknown error")))
    
    -- Display session details
    print("Session ID: " .. session.id)
    print("Master: " .. session.masterId)
    print("Status: " .. session.status)
    print("Start Time: " .. date("%Y-%m-%d %H:%M:%S", session.startTime))
    print("Active Items: " .. #session.activeItems)
    print("Awarded Items: " .. #session.awardedItems)
    
    -- Display roll range management
    print("Next Base Range: " .. session.rollRanges.nextBaseRange)
    print("Used Ranges: " .. #session.rollRanges.usedRanges)
    print("Available Ranges: " .. #session.rollRanges.availableRanges)
    
    -- Display items and rolls
    for i, item in ipairs(session.activeItems) do
        print("Item " .. i .. ": " .. (item.itemInfo.name or "Unknown Item"))
        print("  Item ID: " .. item.id)
        print("  WoW Item ID: " .. item.itemId)
        print("  Roll Range: " .. item.rollRange.baseRange .. "-" .. (item.rollRange.baseRange + 99))
        print("  Total Rolls: " .. #item.rolls)
        print("  Status: " .. item.status)
        
        if #item.rolls > 0 then
            print("  Rolls:")
            for _, roll in ipairs(item.rolls) do
                print("    " .. roll.playerName .. " (" .. roll.category .. "): " .. roll.rollValue)
            end
        end
    end
    
    return session
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
        
    elseif taskId == "1.3" then
        print("|cff00ff00ParallelLoot Task 1.3 Validation:|r")
        
        -- Validate AceDB database initialization
        local dbInitialized = self.db and type(self.db) == "table"
        print("Database initialized: " .. (dbInitialized and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate database structure
        local dbStructure = self.db and self.db.profile and self.db.char and self.db.realm and self.db.global
        print("Database structure: " .. (dbStructure and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate profile system
        local profileSystem = self.db and type(self.db.GetCurrentProfile) == "function" and 
                             type(self.db.GetProfiles) == "function"
        print("Profile system: " .. (profileSystem and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate profile callbacks registered
        local callbacksOK = type(self.OnProfileChanged) == "function" and
                           type(self.OnProfileCopied) == "function" and
                           type(self.OnProfileReset) == "function"
        print("Profile callbacks: " .. (callbacksOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate data migration system
        local migrationOK = type(self.MigrateDatabase) == "function" and
                           self.db.global.dbVersion and
                           self.db.global.migration
        print("Migration system: " .. (migrationOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate default settings structure
        local defaultsOK = self.db.profile.categories and
                          self.db.profile.ui and
                          self.db.profile.communication and
                          self.db.char.stats and
                          self.db.global.sessions
        print("Default settings: " .. (defaultsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Test profile switching functionality
        local profileSwitchOK = self:TestProfileSwitching()
        print("Profile switching: " .. (profileSwitchOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        local taskComplete = dbInitialized and dbStructure and profileSystem and 
                           callbacksOK and migrationOK and defaultsOK and profileSwitchOK
        print("Task 1.3 Status: " .. (taskComplete and "|cff00ff00COMPLETE|r" or "|cffff0000INCOMPLETE|r"))
        
        return taskComplete
        
    elseif taskId == "1.4" then
        print("|cff00ff00ParallelLoot Task 1.4 Validation:|r")
        
        -- Validate ThemeManager exists and is initialized
        local themeManagerOK = self.ThemeManager and type(self.ThemeManager) == "table"
        print("ThemeManager loaded: " .. (themeManagerOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate dark theme color palette
        local colorPaletteOK = themeManagerOK and self.ThemeManager.Colors and
                              self.ThemeManager.Colors.Background and
                              self.ThemeManager.Colors.Text and
                              self.ThemeManager.Colors.Accent and
                              self.ThemeManager.Colors.Border and
                              self.ThemeManager.Colors.Interactive
        print("Color palette defined: " .. (colorPaletteOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate LibSharedMedia integration
        local mediaIntegrationOK = themeManagerOK and self.ThemeManager.Media and
                                  self.ThemeManager.Media.Fonts and
                                  self.ThemeManager.Media.Textures and
                                  type(self.ThemeManager.RegisterCustomMedia) == "function"
        print("LibSharedMedia integration: " .. (mediaIntegrationOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate theme application functions
        local themeFunctionsOK = themeManagerOK and
                                type(self.ThemeManager.ApplyFrameTheme) == "function" and
                                type(self.ThemeManager.ApplyButtonTheme) == "function" and
                                type(self.ThemeManager.ApplyProgressBarTheme) == "function" and
                                type(self.ThemeManager.ApplyTextTheme) == "function"
        print("Theme application functions: " .. (themeFunctionsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate modern styling patterns
        local modernStylingOK = themeManagerOK and
                               type(self.ThemeManager.ApplyModernStyling) == "function" and
                               type(self.ThemeManager.SetupButtonHoverEffects) == "function" and
                               type(self.ThemeManager.GetCategoryColor) == "function"
        print("Modern styling patterns: " .. (modernStylingOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Run comprehensive theme tests if ThemeManager is available
        local themeTestsOK = false
        if themeManagerOK and self.ThemeManager.RunThemeTests then
            themeTestsOK = self.ThemeManager:RunThemeTests()
        elseif themeManagerOK then
            -- Run basic validation if full tests aren't available
            themeTestsOK = self:ValidateThemeSystemBasic()
        end
        print("Theme system tests: " .. (themeTestsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        local taskComplete = themeManagerOK and colorPaletteOK and mediaIntegrationOK and 
                           themeFunctionsOK and modernStylingOK and themeTestsOK
        print("Task 1.4 Status: " .. (taskComplete and "|cff00ff00COMPLETE|r" or "|cffff0000INCOMPLETE|r"))
        
        return taskComplete
        
    elseif taskId == "2.1" then
        print("|cff00ff00ParallelLoot Task 2.1 Validation:|r")
        
        -- Validate DataModels module exists and is loaded
        local dataModelsOK = self.DataModels and type(self.DataModels) == "table"
        print("DataModels module loaded: " .. (dataModelsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate LootSession data structure
        local lootSessionOK = dataModelsOK and self.DataModels.LootSession and
                             type(self.DataModels.LootSession.New) == "function" and
                             type(self.DataModels.LootSession.Validate) == "function"
        print("LootSession structure: " .. (lootSessionOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate LootItem data structure
        local lootItemOK = dataModelsOK and self.DataModels.LootItem and
                          type(self.DataModels.LootItem.New) == "function" and
                          type(self.DataModels.LootItem.Validate) == "function"
        print("LootItem structure: " .. (lootItemOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate PlayerRoll data structure
        local playerRollOK = dataModelsOK and self.DataModels.PlayerRoll and
                            type(self.DataModels.PlayerRoll.New) == "function" and
                            type(self.DataModels.PlayerRoll.Validate) == "function"
        print("PlayerRoll structure: " .. (playerRollOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate utility functions
        local utilsOK = dataModelsOK and self.DataModels.Utils and
                       type(self.DataModels.Utils.FindItemById) == "function" and
                       type(self.DataModels.Utils.ValidateSessionIntegrity) == "function"
        print("Utility functions: " .. (utilsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate modern WoW API usage
        local modernAPIUsage = C_Item and type(C_Item.GetItemInfo) == "function" and
                              type(C_Item.DoesItemExistByID) == "function"
        print("Modern WoW API usage: " .. (modernAPIUsage and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Run comprehensive unit tests if available
        local unitTestsOK = false
        if self.DataModelsTests and type(self.DataModelsTests.RunAllTests) == "function" then
            print("Running comprehensive unit tests...")
            unitTestsOK = self.DataModelsTests:RunAllTests()
        else
            print("Unit tests not available")
        end
        print("Unit tests: " .. (unitTestsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        local taskComplete = dataModelsOK and lootSessionOK and lootItemOK and 
                           playerRollOK and utilsOK and modernAPIUsage and unitTestsOK
        print("Task 2.1 Status: " .. (taskComplete and "|cff00ff00COMPLETE|r" or "|cffff0000INCOMPLETE|r"))
        
        return taskComplete
        
    elseif taskId == "2.2" then
        print("|cff00ff00ParallelLoot Task 2.2 Validation:|r")
        
        -- Validate RollRangeManager exists and is initialized
        local rangeManagerOK = self.RollRangeManager and type(self.RollRangeManager) == "table"
        print("RollRangeManager loaded: " .. (rangeManagerOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate AceDB persistence structure
        local persistenceOK = rangeManagerOK and self.db and self.db.global and 
                             self.db.global.rollRangeManager and self.db.profile.rollRanges
        print("AceDB persistence: " .. (persistenceOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate range assignment algorithm
        local algorithmOK = rangeManagerOK and 
                           type(self.RollRangeManager.GetNextRollRange) == "function" and
                           type(self.RollRangeManager.CreateRollRange) == "function"
        print("Range assignment algorithm: " .. (algorithmOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate range recycling system
        local recyclingOK = rangeManagerOK and 
                           type(self.RollRangeManager.FreeRollRange) == "function" and
                           type(self.RollRangeManager.GetAvailableRanges) == "function"
        print("Range recycling system: " .. (recyclingOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate conflict detection
        local conflictDetectionOK = rangeManagerOK and 
                                   type(self.RollRangeManager.DetectRangeConflicts) == "function" and
                                   type(self.RollRangeManager.CheckRangeOverlap) == "function"
        print("Conflict detection: " .. (conflictDetectionOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Validate LootSession integration
        local integrationOK = rangeManagerOK and 
                             type(self.RollRangeManager.IntegrateWithLootSession) == "function"
        print("LootSession integration: " .. (integrationOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Run comprehensive unit tests if available
        local unitTestsOK = false
        if self.RollRangeManagerTests and type(self.RollRangeManagerTests.RunAllTests) == "function" then
            print("Running comprehensive unit tests...")
            unitTestsOK = self.RollRangeManagerTests:RunAllTests()
        else
            print("Unit tests not available")
        end
        print("Unit tests: " .. (unitTestsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        -- Run built-in range assignment test
        local rangeTestOK = false
        if rangeManagerOK and type(self.RollRangeManager.TestRangeAssignment) == "function" then
            rangeTestOK = self.RollRangeManager:TestRangeAssignment()
        end
        print("Range assignment test: " .. (rangeTestOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
        
        local taskComplete = rangeManagerOK and persistenceOK and algorithmOK and 
                           recyclingOK and conflictDetectionOK and integrationOK and 
                           unitTestsOK and rangeTestOK
        print("Task 2.2 Status: " .. (taskComplete and "|cff00ff00COMPLETE|r" or "|cffff0000INCOMPLETE|r"))
        
        return taskComplete
    end
    
    print("|cffff0000ParallelLoot:|r Unknown task ID: " .. tostring(taskId))
    return false
end