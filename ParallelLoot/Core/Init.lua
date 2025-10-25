-- ParallelLoot Core Initialization
-- Main addon namespace and version management

-- Create main addon namespace
ParallelLoot = {}

-- Version information
ParallelLoot.VERSION = "1.0.0"
ParallelLoot.ADDON_PREFIX = "PLoot"
ParallelLoot.ADDON_NAME = "ParallelLoot"

-- Core module namespaces
ParallelLoot.ErrorHandler = {}
ParallelLoot.LootManager = {}
ParallelLoot.LootMasterManager = {}
ParallelLoot.RollManager = {}
ParallelLoot.UIManager = {}
ParallelLoot.CommManager = {}
ParallelLoot.DataManager = {}
ParallelLoot.TimerManager = {}
ParallelLoot.Integration = {}

-- Debug flag
ParallelLoot.DEBUG = false

-- Addon state
ParallelLoot.isInitialized = false
ParallelLoot.isEnabled = false

-- Event frame for addon lifecycle
local eventFrame = CreateFrame("Frame")
ParallelLoot.eventFrame = eventFrame

-- Debug print function
function ParallelLoot:DebugPrint(...)
    if self.DEBUG then
        print("|cFF00FF00[ParallelLoot]|r", ...)
    end
end

-- Print function for user messages
function ParallelLoot:Print(...)
    print("|cFF00FF00[ParallelLoot]|r", ...)
end

-- Initialize addon
function ParallelLoot:Initialize()
    if self.isInitialized then
        return
    end
    
    self:DebugPrint("Initializing addon version", self.VERSION)
    
    -- Initialize error handler first
    if self.ErrorHandler.Initialize then
        self.ErrorHandler:Initialize()
    end
    
    -- Initialize data manager (handles SavedVariables)
    if self.DataManager.Initialize then
        self.DataManager:Initialize()
    end
    
    -- Initialize loot master manager (needs to be early for permissions)
    if self.LootMasterManager.Initialize then
        self.LootMasterManager:Initialize()
    end
    
    -- Initialize other managers
    if self.CommManager.Initialize then
        self.CommManager:Initialize()
    end
    
    if self.TimerManager.Initialize then
        self.TimerManager:Initialize()
    end
    
    if self.LootManager.Initialize then
        self.LootManager:Initialize()
    end
    
    if self.RollManager.Initialize then
        self.RollManager:Initialize()
    end
    
    if self.UIManager.Initialize then
        self.UIManager:Initialize()
    end
    
    -- Initialize integration layer (wires all components together)
    if self.Integration.Initialize then
        self.Integration:Initialize()
    end
    
    -- Register extended slash commands
    if self.Integration.RegisterSlashCommands then
        self.Integration:RegisterSlashCommands()
    end
    
    self.isInitialized = true
    self.isEnabled = true
    
    self:Print("Addon loaded successfully. Version:", self.VERSION)
end

-- Shutdown addon
function ParallelLoot:Shutdown()
    self:DebugPrint("Shutting down addon")
    
    -- Save data before shutdown
    if self.DataManager.SaveData then
        self.DataManager:SaveData()
    end
    
    self.isEnabled = false
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ParallelLoot.ADDON_NAME then
            ParallelLoot:Initialize()
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGOUT" then
        ParallelLoot:Shutdown()
    end
end

-- Register events
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", OnEvent)

-- Slash command registration
SLASH_PARALLELLOOT1 = "/ploot"
SLASH_PARALLELLOOT2 = "/parallelloot"

SlashCmdList["PARALLELLOOT"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "debug" then
        ParallelLoot.DEBUG = not ParallelLoot.DEBUG
        ParallelLoot:Print("Debug mode:", ParallelLoot.DEBUG and "ON" or "OFF")
    elseif command == "version" then
        ParallelLoot:Print("Version:", ParallelLoot.VERSION)
    elseif command == "settings" or command == "config" then
        if ParallelLoot.UIManager.ToggleSettingsPanel then
            ParallelLoot.UIManager:ToggleSettingsPanel()
        else
            ParallelLoot:Print("Settings panel not yet loaded")
        end
    elseif command == "help" then
        ParallelLoot:Print("Available commands:")
        print("  /ploot - Show/hide main loot panel")
        print("  /ploot settings - Open settings panel")
        print("  /ploot debug - Toggle debug mode")
        print("  /ploot version - Show addon version")
        print("  /ploot help - Show this help message")
    else
        -- Default: show/hide UI
        if ParallelLoot.UIManager.ToggleMainFrame then
            ParallelLoot.UIManager:ToggleMainFrame()
        else
            ParallelLoot:Print("UI not yet implemented")
        end
    end
end
