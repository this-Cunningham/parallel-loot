-- ThemeManager.lua - Dark theme system with LibSharedMedia integration
-- Task 1.4 Implementation: Create dark theme system with LibSharedMedia integration

local AceAddon = LibStub("AceAddon-3.0")
local LibSharedMedia = LibStub("LibSharedMedia-3.0")

-- Get addon reference
local ParallelLoot = AceAddon:GetAddon("ParallelLoot")

-- Create ThemeManager module
local ThemeManager = {}
ParallelLoot.ThemeManager = ThemeManager

-- Theme constants and configuration
ThemeManager.THEME_VERSION = "1.0.0"

-- Dark theme color palette - modern, minimal, polished aesthetic
ThemeManager.Colors = {
    -- Background colors (deep dark grays/blacks with subtle gradients)
    Background = {
        Primary = {0.08, 0.08, 0.08, 0.95},      -- Main panel background
        Secondary = {0.12, 0.12, 0.12, 0.90},    -- Secondary panels, headers
        Tertiary = {0.16, 0.16, 0.16, 0.85},     -- Elevated elements, buttons
        Overlay = {0.04, 0.04, 0.04, 0.98},      -- Modal overlays, dropdowns
        Transparent = {0.0, 0.0, 0.0, 0.0}       -- Fully transparent
    },
    
    -- Text colors (light gray/white for high contrast)
    Text = {
        Primary = {0.95, 0.95, 0.95, 1.0},       -- Main text, headers
        Secondary = {0.75, 0.75, 0.75, 1.0},     -- Secondary text, descriptions
        Muted = {0.55, 0.55, 0.55, 1.0},         -- Disabled text, placeholders
        Accent = {0.85, 0.85, 0.95, 1.0},        -- Highlighted text
        White = {1.0, 1.0, 1.0, 1.0}             -- Pure white for emphasis
    },
    
    -- Accent colors (subtle blue/purple accents for interactive elements)
    Accent = {
        Primary = {0.4, 0.6, 0.9, 1.0},          -- Primary accent (blue)
        Secondary = {0.6, 0.4, 0.9, 1.0},        -- Secondary accent (purple)
        Success = {0.3, 0.8, 0.4, 1.0},          -- Success states (green)
        Warning = {0.9, 0.7, 0.2, 1.0},          -- Warning states (orange)
        Error = {0.9, 0.3, 0.3, 1.0},            -- Error states (red)
        Info = {0.2, 0.7, 0.9, 1.0}              -- Info states (cyan)
    },
    
    -- Border colors (thin, subtle borders in darker tones)
    Border = {
        Default = {0.25, 0.25, 0.25, 0.8},       -- Standard borders
        Subtle = {0.18, 0.18, 0.18, 0.6},        -- Very subtle borders
        Accent = {0.4, 0.6, 0.9, 0.7},           -- Accent borders (blue)
        Focus = {0.6, 0.4, 0.9, 0.9},            -- Focus indicators (purple)
        Disabled = {0.15, 0.15, 0.15, 0.4}       -- Disabled element borders
    },
    
    -- Interactive element colors
    Interactive = {
        -- Button states
        Button = {
            Normal = {0.2, 0.2, 0.2, 0.9},       -- Default button background
            Hover = {0.3, 0.3, 0.3, 0.95},       -- Hover state
            Pressed = {0.15, 0.15, 0.15, 1.0},   -- Pressed state
            Disabled = {0.1, 0.1, 0.1, 0.5}      -- Disabled state
        },
        
        -- Progress bar colors
        Progress = {
            Background = {0.1, 0.1, 0.1, 0.8},   -- Progress bar background
            Fill = {0.9, 0.7, 0.2, 0.9},         -- Progress fill (orange/yellow)
            Critical = {0.9, 0.3, 0.3, 0.9},     -- Critical state (red)
            Complete = {0.3, 0.8, 0.4, 0.9}      -- Complete state (green)
        },
        
        -- Input field colors
        Input = {
            Background = {0.08, 0.08, 0.08, 0.95},
            Border = {0.3, 0.3, 0.3, 0.8},
            Focus = {0.4, 0.6, 0.9, 0.8},
            Text = {0.95, 0.95, 0.95, 1.0}
        }
    },
    
    -- WoW item quality colors (standard WoW colors for consistency)
    Quality = {
        Poor = {0.62, 0.62, 0.62, 1.0},          -- Gray
        Common = {1.0, 1.0, 1.0, 1.0},           -- White  
        Uncommon = {0.12, 1.0, 0.0, 1.0},        -- Green
        Rare = {0.0, 0.44, 0.87, 1.0},           -- Blue
        Epic = {0.64, 0.21, 0.93, 1.0},          -- Purple
        Legendary = {1.0, 0.5, 0.0, 1.0},        -- Orange
        Artifact = {0.9, 0.8, 0.5, 1.0},         -- Golden
        Heirloom = {0.9, 0.8, 0.5, 1.0}          -- Golden (same as artifact)
    },
    
    -- Class colors (standard WoW class colors)
    Class = {
        WARRIOR = {0.78, 0.61, 0.43, 1.0},
        PALADIN = {0.96, 0.55, 0.73, 1.0},
        HUNTER = {0.67, 0.83, 0.45, 1.0},
        ROGUE = {1.0, 0.96, 0.41, 1.0},
        PRIEST = {1.0, 1.0, 1.0, 1.0},
        DEATHKNIGHT = {0.77, 0.12, 0.23, 1.0},
        SHAMAN = {0.0, 0.44, 0.87, 1.0},
        MAGE = {0.25, 0.78, 0.92, 1.0},
        WARLOCK = {0.53, 0.53, 0.93, 1.0},
        MONK = {0.0, 1.0, 0.59, 1.0},
        DRUID = {1.0, 0.49, 0.04, 1.0}
    }
}

-- LibSharedMedia integration - register custom media
ThemeManager.Media = {
    -- Font registrations
    Fonts = {
        Primary = "ParallelLoot_Primary",
        Secondary = "ParallelLoot_Secondary", 
        Monospace = "ParallelLoot_Monospace"
    },
    
    -- Texture registrations
    Textures = {
        Background = "ParallelLoot_Background",
        Button = "ParallelLoot_Button",
        Border = "ParallelLoot_Border",
        Gradient = "ParallelLoot_Gradient"
    },
    
    -- Sound registrations
    Sounds = {
        Roll = "ParallelLoot_Roll",
        Award = "ParallelLoot_Award",
        Warning = "ParallelLoot_Warning"
    }
}

-- Initialize theme system
function ThemeManager:Initialize()
    print("|cff888888ParallelLoot ThemeManager:|r Initializing dark theme system...")
    
    -- Register custom media with LibSharedMedia
    self:RegisterCustomMedia()
    
    -- Initialize theme cache
    self:InitializeThemeCache()
    
    -- Set up theme change callbacks
    self:RegisterMediaCallbacks()
    
    print("|cff888888ParallelLoot ThemeManager:|r Dark theme system initialized")
end

-- Register custom media with LibSharedMedia-3.0
function ThemeManager:RegisterCustomMedia()
    -- Register fonts (using built-in WoW fonts as base)
    LibSharedMedia:Register("font", self.Media.Fonts.Primary, "Fonts\\FRIZQT__.TTF")
    LibSharedMedia:Register("font", self.Media.Fonts.Secondary, "Fonts\\ARIALN.TTF") 
    LibSharedMedia:Register("font", self.Media.Fonts.Monospace, "Fonts\\MORPHEUS.TTF")
    
    -- Register textures (using built-in WoW textures as base)
    LibSharedMedia:Register("background", self.Media.Textures.Background, "Interface\\Tooltips\\UI-Tooltip-Background")
    LibSharedMedia:Register("border", self.Media.Textures.Border, "Interface\\Tooltips\\UI-Tooltip-Border")
    LibSharedMedia:Register("statusbar", self.Media.Textures.Button, "Interface\\TargetingFrame\\UI-StatusBar")
    
    -- Register sounds (using built-in WoW sounds)
    LibSharedMedia:Register("sound", self.Media.Sounds.Roll, "Sound\\Interface\\RollDice.ogg")
    LibSharedMedia:Register("sound", self.Media.Sounds.Award, "Sound\\Interface\\LootWinUnique.ogg")
    LibSharedMedia:Register("sound", self.Media.Sounds.Warning, "Sound\\Interface\\RaidWarning.ogg")
    
    print("|cff888888ParallelLoot ThemeManager:|r Custom media registered with LibSharedMedia")
end

-- Initialize theme cache for performance
function ThemeManager:InitializeThemeCache()
    self._themeCache = {
        fonts = {},
        textures = {},
        colors = {},
        lastUpdate = time()
    }
    
    -- Cache frequently used fonts
    self._themeCache.fonts.primary = LibSharedMedia:Fetch("font", self.Media.Fonts.Primary)
    self._themeCache.fonts.secondary = LibSharedMedia:Fetch("font", self.Media.Fonts.Secondary)
    self._themeCache.fonts.monospace = LibSharedMedia:Fetch("font", self.Media.Fonts.Monospace)
    
    -- Cache frequently used textures
    self._themeCache.textures.background = LibSharedMedia:Fetch("background", self.Media.Textures.Background)
    self._themeCache.textures.border = LibSharedMedia:Fetch("border", self.Media.Textures.Border)
    self._themeCache.textures.button = LibSharedMedia:Fetch("statusbar", self.Media.Textures.Button)
    
    print("|cff888888ParallelLoot ThemeManager:|r Theme cache initialized")
end

-- Register callbacks for LibSharedMedia changes
function ThemeManager:RegisterMediaCallbacks()
    -- Register for font changes
    LibSharedMedia.RegisterCallback(self, "LibSharedMedia_Registered", "OnMediaRegistered")
    LibSharedMedia.RegisterCallback(self, "LibSharedMedia_SetGlobal", "OnMediaChanged")
    
    print("|cff888888ParallelLoot ThemeManager:|r Media change callbacks registered")
end

-- Handle media registration/changes
function ThemeManager:OnMediaRegistered(event, mediaType, key)
    if mediaType == "font" or mediaType == "background" or mediaType == "border" or mediaType == "statusbar" then
        -- Refresh cache when relevant media changes
        self:RefreshThemeCache()
    end
end

function ThemeManager:OnMediaChanged(event, mediaType)
    if mediaType == "font" or mediaType == "background" or mediaType == "border" or mediaType == "statusbar" then
        -- Refresh cache and notify UI components
        self:RefreshThemeCache()
        self:NotifyThemeChanged()
    end
end

-- Refresh theme cache
function ThemeManager:RefreshThemeCache()
    self._themeCache.lastUpdate = time()
    
    -- Update cached fonts
    self._themeCache.fonts.primary = LibSharedMedia:Fetch("font", self.Media.Fonts.Primary)
    self._themeCache.fonts.secondary = LibSharedMedia:Fetch("font", self.Media.Fonts.Secondary)
    self._themeCache.fonts.monospace = LibSharedMedia:Fetch("font", self.Media.Fonts.Monospace)
    
    -- Update cached textures
    self._themeCache.textures.background = LibSharedMedia:Fetch("background", self.Media.Textures.Background)
    self._themeCache.textures.border = LibSharedMedia:Fetch("border", self.Media.Textures.Border)
    self._themeCache.textures.button = LibSharedMedia:Fetch("statusbar", self.Media.Textures.Button)
    
    print("|cff888888ParallelLoot ThemeManager:|r Theme cache refreshed")
end

-- Notify other systems of theme changes
function ThemeManager:NotifyThemeChanged()
    -- Fire theme changed event for UI components to refresh
    if ParallelLoot.callbacks then
        ParallelLoot.callbacks:Fire("ThemeChanged", self:GetCurrentTheme())
    end
    
    -- Refresh UI if UIManager exists
    if ParallelLoot.UIManager and ParallelLoot.UIManager.RefreshTheme then
        ParallelLoot.UIManager:RefreshTheme()
    end
end

-- Get current theme configuration
function ThemeManager:GetCurrentTheme()
    return {
        colors = self.Colors,
        fonts = self._themeCache.fonts,
        textures = self._themeCache.textures,
        version = self.THEME_VERSION,
        lastUpdate = self._themeCache.lastUpdate
    }
end

-- Theme application functions for consistent styling

-- Apply theme to AceGUI Frame widget
function ThemeManager:ApplyFrameTheme(frame, options)
    options = options or {}
    
    if not frame then return end
    
    -- Apply background
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = self._themeCache.textures.background,
            edgeFile = self._themeCache.textures.border,
            tile = false,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        
        -- Apply colors
        local bgColor = options.background or self.Colors.Background.Primary
        local borderColor = options.border or self.Colors.Border.Default
        
        frame:SetBackdropColor(unpack(bgColor))
        frame:SetBackdropBorderColor(unpack(borderColor))
    end
    
    -- Apply modern styling
    if options.modern ~= false then
        self:ApplyModernStyling(frame, options)
    end
end

-- Apply theme to AceGUI Button widget
function ThemeManager:ApplyButtonTheme(button, category)
    if not button then return end
    
    -- Get button-specific colors
    local normalColor = self.Colors.Interactive.Button.Normal
    local hoverColor = self.Colors.Interactive.Button.Hover
    local pressedColor = self.Colors.Interactive.Button.Pressed
    local disabledColor = self.Colors.Interactive.Button.Disabled
    
    -- Apply category-specific accent if provided
    if category then
        local accentColor = self:GetCategoryColor(category)
        if accentColor then
            hoverColor = {accentColor[1] * 0.8, accentColor[2] * 0.8, accentColor[3] * 0.8, 0.95}
        end
    end
    
    -- Apply button styling
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = self._themeCache.textures.button,
            edgeFile = self._themeCache.textures.border,
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        
        button:SetBackdropColor(unpack(normalColor))
        button:SetBackdropBorderColor(unpack(self.Colors.Border.Subtle))
    end
    
    -- Set up hover effects
    self:SetupButtonHoverEffects(button, normalColor, hoverColor, pressedColor, disabledColor)
    
    -- Apply text styling
    self:ApplyButtonTextTheme(button)
end

-- Apply theme to progress bars (for timers)
function ThemeManager:ApplyProgressBarTheme(progressBar, options)
    options = options or {}
    
    if not progressBar then return end
    
    -- Apply background
    if progressBar.SetBackdrop then
        progressBar:SetBackdrop({
            bgFile = self._themeCache.textures.background,
            edgeFile = self._themeCache.textures.border,
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        
        progressBar:SetBackdropColor(unpack(self.Colors.Interactive.Progress.Background))
        progressBar:SetBackdropBorderColor(unpack(self.Colors.Border.Subtle))
    end
    
    -- Apply progress bar texture and colors
    if progressBar.SetStatusBarTexture then
        progressBar:SetStatusBarTexture(self._themeCache.textures.button)
        
        -- Choose color based on progress type
        local fillColor = self.Colors.Interactive.Progress.Fill
        if options.critical then
            fillColor = self.Colors.Interactive.Progress.Critical
        elseif options.complete then
            fillColor = self.Colors.Interactive.Progress.Complete
        end
        
        progressBar:SetStatusBarColor(unpack(fillColor))
    end
    
    -- Apply modern gradient effect
    self:ApplyProgressGradient(progressBar, options)
end

-- Apply theme to text elements
function ThemeManager:ApplyTextTheme(fontString, textType, options)
    options = options or {}
    
    if not fontString then return end
    
    -- Choose font based on text type
    local font = self._themeCache.fonts.primary
    local size = options.size or 12
    local flags = options.flags or "OUTLINE"
    
    if textType == "header" then
        font = self._themeCache.fonts.primary
        size = options.size or 14
        flags = "OUTLINE"
    elseif textType == "secondary" then
        font = self._themeCache.fonts.secondary
        size = options.size or 11
    elseif textType == "monospace" then
        font = self._themeCache.fonts.monospace
        size = options.size or 10
    end
    
    -- Apply font
    fontString:SetFont(font, size, flags)
    
    -- Choose color based on text type
    local textColor = self.Colors.Text.Primary
    if textType == "secondary" then
        textColor = self.Colors.Text.Secondary
    elseif textType == "muted" then
        textColor = self.Colors.Text.Muted
    elseif textType == "accent" then
        textColor = self.Colors.Text.Accent
    elseif options.color then
        textColor = options.color
    end
    
    fontString:SetTextColor(unpack(textColor))
    
    -- Apply shadow for better readability
    if options.shadow ~= false then
        fontString:SetShadowColor(0, 0, 0, 0.8)
        fontString:SetShadowOffset(1, -1)
    end
end

-- Apply modern styling patterns
function ThemeManager:ApplyModernStyling(frame, options)
    options = options or {}
    
    -- Add subtle drop shadow for depth
    if options.shadow ~= false and frame.CreateTexture then
        local shadow = frame:CreateTexture(nil, "BACKGROUND")
        shadow:SetTexture(0, 0, 0, 0.3)
        shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        frame._plootShadow = shadow
    end
    
    -- Add subtle transparency for layered look
    if options.transparency and frame.SetAlpha then
        frame:SetAlpha(options.transparency)
    end
    
    -- Add smooth animations if requested
    if options.animations ~= false then
        self:SetupFrameAnimations(frame)
    end
end

-- Set up button hover effects with smooth transitions
function ThemeManager:SetupButtonHoverEffects(button, normalColor, hoverColor, pressedColor, disabledColor)
    -- Store colors for state changes
    button._plootColors = {
        normal = normalColor,
        hover = hoverColor,
        pressed = pressedColor,
        disabled = disabledColor
    }
    
    -- Set up hover scripts
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() and self.SetBackdropColor then
            self:SetBackdropColor(unpack(self._plootColors.hover))
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        if self:IsEnabled() and self.SetBackdropColor then
            self:SetBackdropColor(unpack(self._plootColors.normal))
        end
    end)
    
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() and self.SetBackdropColor then
            self:SetBackdropColor(unpack(self._plootColors.pressed))
        end
    end)
    
    button:SetScript("OnMouseUp", function(self)
        if self:IsEnabled() and self.SetBackdropColor then
            if self:IsMouseOver() then
                self:SetBackdropColor(unpack(self._plootColors.hover))
            else
                self:SetBackdropColor(unpack(self._plootColors.normal))
            end
        end
    end)
end

-- Apply button text theme
function ThemeManager:ApplyButtonTextTheme(button)
    if button.SetText and button.GetFontString then
        local fontString = button:GetFontString()
        if fontString then
            self:ApplyTextTheme(fontString, "primary", {size = 11, shadow = true})
        end
    end
end

-- Apply gradient effect to progress bars
function ThemeManager:ApplyProgressGradient(progressBar, options)
    -- This would create a subtle gradient effect for modern appearance
    -- Implementation depends on specific progress bar widget structure
    if progressBar.CreateTexture then
        local gradient = progressBar:CreateTexture(nil, "OVERLAY")
        gradient:SetTexture("Interface\\AddOns\\ParallelLoot\\Textures\\Gradient")
        gradient:SetAllPoints(progressBar)
        gradient:SetAlpha(0.3)
        progressBar._plootGradient = gradient
    end
end

-- Set up frame animations for smooth transitions
function ThemeManager:SetupFrameAnimations(frame)
    -- Create animation group for smooth show/hide
    if frame.CreateAnimationGroup then
        local animGroup = frame:CreateAnimationGroup()
        
        -- Fade in animation
        local fadeIn = animGroup:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.2)
        fadeIn:SetSmoothing("IN")
        
        -- Store animation for later use
        frame._plootAnimations = {
            group = animGroup,
            fadeIn = fadeIn
        }
    end
end

-- Utility functions for color management

-- Get category-specific color
function ThemeManager:GetCategoryColor(category)
    local categoryColors = {
        bis = self.Colors.Quality.Legendary,    -- Orange for BIS
        ms = self.Colors.Quality.Epic,          -- Purple for MS
        os = self.Colors.Quality.Rare,          -- Blue for OS
        coz = self.Colors.Quality.Uncommon      -- Green for COZ
    }
    
    return categoryColors[string.lower(category)] or self.Colors.Accent.Primary
end

-- Get class color for player names
function ThemeManager:GetClassColor(class)
    return self.Colors.Class[string.upper(class)] or self.Colors.Text.Primary
end

-- Get quality color for items
function ThemeManager:GetQualityColor(quality)
    local qualityMap = {
        [0] = self.Colors.Quality.Poor,
        [1] = self.Colors.Quality.Common,
        [2] = self.Colors.Quality.Uncommon,
        [3] = self.Colors.Quality.Rare,
        [4] = self.Colors.Quality.Epic,
        [5] = self.Colors.Quality.Legendary,
        [6] = self.Colors.Quality.Artifact,
        [7] = self.Colors.Quality.Heirloom
    }
    
    return qualityMap[quality] or self.Colors.Quality.Common
end

-- Convert color table to hex string for text coloring
function ThemeManager:ColorToHex(color)
    if not color or type(color) ~= "table" or #color < 3 then
        return "|cffffffff"  -- Default to white
    end
    
    -- Ensure values are numbers and clamp to 0-1 range
    local r = math.max(0, math.min(1, tonumber(color[1]) or 0))
    local g = math.max(0, math.min(1, tonumber(color[2]) or 0))
    local b = math.max(0, math.min(1, tonumber(color[3]) or 0))
    
    -- Convert to 0-255 range
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    
    return string.format("|cff%02x%02x%02x", r, g, b)
end

-- Create colored text string
function ThemeManager:CreateColoredText(text, color)
    local hexColor = self:ColorToHex(color)
    return hexColor .. text .. "|r"
end

-- Theme validation and testing functions

-- Test theme color application
function ThemeManager:TestColorApplication()
    print("|cff00ff00ParallelLoot Theme Test:|r Testing color application...")
    
    -- Test color table structure
    local colorsOK = self.Colors and self.Colors.Background and self.Colors.Text and 
                    self.Colors.Accent and self.Colors.Border and self.Colors.Interactive
    print("Color structure: " .. (colorsOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test color conversion
    local testColor = {0.5, 0.7, 0.9, 1.0}
    local hexColor = self:ColorToHex(testColor)
    local hexOK = hexColor and string.match(hexColor, "|cff%x%x%x%x%x%x")
    print("Color conversion: " .. (hexOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test colored text creation
    local coloredText = self:CreateColoredText("Test", testColor)
    local textOK = coloredText and string.find(coloredText, "|cff") and string.find(coloredText, "|r")
    print("Colored text: " .. (textOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return colorsOK and hexOK and textOK
end

-- Test LibSharedMedia integration
function ThemeManager:TestLibSharedMediaIntegration()
    print("|cff00ff00ParallelLoot Theme Test:|r Testing LibSharedMedia integration...")
    
    -- Test media registration
    local fontsRegistered = LibSharedMedia:IsValid("font", self.Media.Fonts.Primary) and
                           LibSharedMedia:IsValid("font", self.Media.Fonts.Secondary)
    print("Font registration: " .. (fontsRegistered and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    local texturesRegistered = LibSharedMedia:IsValid("background", self.Media.Textures.Background) and
                              LibSharedMedia:IsValid("border", self.Media.Textures.Border)
    print("Texture registration: " .. (texturesRegistered and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test media fetching
    local fontFetch = pcall(function() 
        return LibSharedMedia:Fetch("font", self.Media.Fonts.Primary)
    end)
    print("Font fetching: " .. (fontFetch and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test cache functionality
    local cacheOK = self._themeCache and self._themeCache.fonts and self._themeCache.textures
    print("Theme cache: " .. (cacheOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return fontsRegistered and texturesRegistered and fontFetch and cacheOK
end

-- Test style consistency
function ThemeManager:TestStyleConsistency()
    print("|cff00ff00ParallelLoot Theme Test:|r Testing style consistency...")
    
    -- Test that all color categories have required entries
    local bgComplete = self.Colors.Background.Primary and self.Colors.Background.Secondary and
                      self.Colors.Background.Tertiary and self.Colors.Background.Overlay
    print("Background colors complete: " .. (bgComplete and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    local textComplete = self.Colors.Text.Primary and self.Colors.Text.Secondary and
                        self.Colors.Text.Muted and self.Colors.Text.Accent
    print("Text colors complete: " .. (textComplete and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    local accentComplete = self.Colors.Accent.Primary and self.Colors.Accent.Secondary and
                          self.Colors.Accent.Success and self.Colors.Accent.Warning and
                          self.Colors.Accent.Error
    print("Accent colors complete: " .. (accentComplete and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test category color mapping
    local categoryColors = {"bis", "ms", "os", "coz"}
    local categoryOK = true
    for _, category in ipairs(categoryColors) do
        if not self:GetCategoryColor(category) then
            categoryOK = false
            break
        end
    end
    print("Category colors: " .. (categoryOK and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    return bgComplete and textComplete and accentComplete and categoryOK
end

-- Create test widgets to validate theme application
function ThemeManager:CreateTestWidgets()
    print("|cff00ff00ParallelLoot Theme Test:|r Creating test widgets for visual validation...")
    
    -- Clean up any existing test frame first
    self:CleanupTestWidgets()
    
    print("|cff888888Debug:|r Starting widget creation...")
    
    -- Create main test frame with proper backdrop
    local testFrame = CreateFrame("Frame", "ParallelLootThemeTestFrame", UIParent, "BackdropTemplate")
    testFrame:SetSize(400, 300)
    testFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    testFrame:SetFrameStrata("DIALOG")
    testFrame:SetFrameLevel(100)
    
    -- Apply dark theme backdrop
    testFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Apply dark colors
    testFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)  -- Dark background
    testFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)  -- Subtle border
    
    -- Create title text
    local titleText = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", testFrame, "TOP", 0, -15)
    titleText:SetText("ParallelLoot Dark Theme Test")
    titleText:SetTextColor(0.95, 0.95, 0.95, 1.0)  -- Light text
    
    -- Create test button with custom dark styling
    local testButton = CreateFrame("Button", nil, testFrame, "BackdropTemplate")
    testButton:SetSize(140, 32)
    testButton:SetPoint("TOP", testFrame, "TOP", 0, -50)
    
    -- Apply dark button backdrop
    testButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Dark button colors
    testButton:SetBackdropColor(0.15, 0.15, 0.15, 0.9)        -- Dark gray background
    testButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)     -- Subtle border
    
    -- Create button text
    local buttonText = testButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonText:SetPoint("CENTER", testButton, "CENTER", 0, 0)
    buttonText:SetText("BIS Roll Button")
    buttonText:SetTextColor(0.95, 0.95, 0.95, 1.0)  -- Light text
    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    
    -- Add hover effects
    testButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 0.95)  -- Lighter on hover
        self:SetBackdropBorderColor(0.4, 0.6, 0.9, 0.9)  -- Blue border on hover
    end)
    
    testButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)   -- Back to normal
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)  -- Normal border
    end)
    
    testButton:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 1.0)  -- Darker when pressed
    end)
    
    testButton:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(0.25, 0.25, 0.25, 0.95)  -- Hover state
        else
            self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)   -- Normal state
        end
    end)
    
    -- Make button clickable
    testButton:EnableMouse(true)
    testButton:SetScript("OnClick", function()
        print("BIS Roll Button clicked! (Dark theme test)")
    end)
    
    -- Create enhanced progress bar with modern styling
    local progressFrame = CreateFrame("Frame", nil, testFrame, "BackdropTemplate")
    progressFrame:SetSize(280, 28)
    progressFrame:SetPoint("CENTER", testFrame, "CENTER", 0, -20)
    
    -- Modern progress bar container with subtle styling
    progressFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    progressFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)  -- Very dark background
    progressFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.7)  -- Subtle border
    
    -- Inner progress bar with rounded appearance
    local progressBar = CreateFrame("StatusBar", nil, progressFrame)
    progressBar:SetPoint("TOPLEFT", progressFrame, "TOPLEFT", 2, -2)
    progressBar:SetPoint("BOTTOMRIGHT", progressFrame, "BOTTOMRIGHT", -2, 2)
    progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    
    -- Enhanced orange color with more vibrancy
    progressBar:SetStatusBarColor(1.0, 0.65, 0.1, 0.95)  -- More vibrant orange
    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(75)
    
    -- Add gradient overlay for modern look (Modern API)
    local gradient = progressBar:CreateTexture(nil, "OVERLAY")
    gradient:SetTexture("Interface\\Buttons\\WHITE8X8")
    gradient:SetAllPoints(progressBar:GetStatusBarTexture())
    gradient:SetGradient("VERTICAL", CreateColor(1.0, 0.8, 0.2, 0.3), CreateColor(1.0, 0.5, 0.0, 0.1))
    
    -- Add subtle glow effect
    local glow = progressFrame:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetPoint("TOPLEFT", progressBar, "TOPLEFT", -1, 1)
    glow:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 1, -1)
    glow:SetVertexColor(1.0, 0.6, 0.1, 0.2)  -- Subtle orange glow
    
    -- Enhanced progress text with better styling
    local progressText = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("CENTER", progressFrame, "CENTER", 0, 0)
    progressText:SetText("Timer: 75%")
    progressText:SetTextColor(0.95, 0.95, 0.95, 1.0)
    progressText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    progressText:SetShadowColor(0, 0, 0, 0.8)
    progressText:SetShadowOffset(1, -1)
    
    -- Add modern animation for demonstration (Modern API)
    local animGroup = progressBar:CreateAnimationGroup()
    animGroup:SetLooping("BOUNCE")
    
    local anim = animGroup:CreateAnimation("Alpha")  -- Try Alpha animation instead
    anim:SetDuration(2)
    anim:SetFromAlpha(0.8)
    anim:SetToAlpha(1.0)
    anim:SetSmoothing("IN_OUT")
    
    -- Start the animation
    print("|cff888888Debug:|r Starting modern progress bar animation...")
    animGroup:Play()
    
    print("|cff888888Debug:|r Progress bar created successfully, now creating category examples...")
    
    -- Create category color examples (with debug output)
    print("|cff888888Debug:|r Creating category color examples...")
    local categories = {"BIS", "MS", "OS", "COZ"}
    local categoryColors = {
        {1.0, 0.5, 0.0, 1.0},    -- Orange for BIS
        {0.64, 0.21, 0.93, 1.0}, -- Purple for MS
        {0.0, 0.44, 0.87, 1.0},  -- Blue for OS
        {0.12, 1.0, 0.0, 1.0}    -- Green for COZ
    }
    
    for i, category in ipairs(categories) do
        local categoryText = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if categoryText then
            categoryText:SetPoint("LEFT", testFrame, "LEFT", 20, 50 - (i * 25))  -- Changed positioning
            categoryText:SetText(category .. " Category")
            categoryText:SetTextColor(unpack(categoryColors[i]))
            categoryText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            categoryText:Show()  -- Explicitly show
            print("|cff888888Debug:|r Created " .. category .. " text at position " .. i)
        else
            print("|cffff0000Error:|r Failed to create " .. category .. " text")
        end
    end
    
    -- Create description text (with debug output)
    print("|cff888888Debug:|r Creating description text...")
    local descText = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if descText then
        descText:SetPoint("BOTTOM", testFrame, "BOTTOM", 0, 15)
        descText:SetText("Dark Theme: Modern • Minimal • Polished")
        descText:SetTextColor(0.75, 0.75, 0.75, 1.0)
        descText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        descText:Show()  -- Explicitly show
        print("|cff888888Debug:|r Created description text")
    else
        print("|cffff0000Error:|r Failed to create description text")
    end
    
    -- Create close button
    local closeButton = CreateFrame("Button", nil, testFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", testFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        self:CleanupTestWidgets()
    end)
    
    -- Make frame movable
    testFrame:SetMovable(true)
    testFrame:EnableMouse(true)
    testFrame:RegisterForDrag("LeftButton")
    testFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    testFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    -- Show the frame
    testFrame:Show()
    
    -- Store reference for cleanup
    self._testFrame = testFrame
    
    print("|cff00ff00ParallelLoot Theme Test:|r Dark theme test frame created!")
    print("|cff888888Instructions:|r")
    print("  • Check dark background with light text")
    print("  • Hover over button for highlight effect")
    print("  • Drag frame to move it around")
    print("  • Click X or use cleanup command to close")
    
    return testFrame
end

-- Clean up test widgets
function ThemeManager:CleanupTestWidgets()
    -- Clean up stored reference
    if self._testFrame then
        self._testFrame:Hide()
        self._testFrame:SetParent(nil)
        self._testFrame = nil
    end
    
    -- Also clean up by name in case reference was lost
    local namedFrame = _G["ParallelLootThemeTestFrame"]
    if namedFrame then
        namedFrame:Hide()
        namedFrame:SetParent(nil)
        _G["ParallelLootThemeTestFrame"] = nil
    end
    
    print("|cff888888ParallelLoot Theme Test:|r Test widgets cleaned up")
end

-- Main theme test function
function ThemeManager:RunThemeTests()
    print("|cff00ff00ParallelLoot Theme System Test:|r Running comprehensive theme validation...")
    
    -- Test 1: Color application
    local colorTest = self:TestColorApplication()
    
    -- Test 2: LibSharedMedia integration  
    local mediaTest = self:TestLibSharedMediaIntegration()
    
    -- Test 3: Style consistency
    local styleTest = self:TestStyleConsistency()
    
    -- Test 4: Create visual test widgets
    local testFrame = self:CreateTestWidgets()
    local visualTest = testFrame ~= nil
    print("Visual test widgets: " .. (visualTest and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"))
    
    -- Test 5: Debug ColorToHex function
    print("|cff888888Debug ColorToHex:|r")
    local testColors = {
        {name = "Red", color = {1.0, 0.0, 0.0, 1.0}},
        {name = "Green", color = {0.0, 1.0, 0.0, 1.0}},
        {name = "Blue", color = {0.0, 0.0, 1.0, 1.0}}
    }
    
    for _, test in ipairs(testColors) do
        local result = self:ColorToHex(test.color)
        -- Escape the hex code so it displays as text instead of being interpreted as color
        local escaped = result and string.gsub(result, "|", "||") or "nil"
        print("  " .. test.name .. " -> '" .. escaped .. "'")
        
        -- Also test the colored text function
        local coloredText = self:CreateColoredText("TEST", test.color)
        print("    Colored text: " .. coloredText)
    end
    
    local allTestsPass = colorTest and mediaTest and styleTest and visualTest
    print("|cff00ff00ParallelLoot Theme System:|r " .. (allTestsPass and "|cff00ff00ALL TESTS PASSED|r" or "|cffff0000SOME TESTS FAILED|r"))
    
    if allTestsPass then
        print("|cff00ff00ParallelLoot Theme System:|r Dark theme system is ready for use!")
        print("|cff888888Instructions:|r Use ThemeManager:CleanupTestWidgets() to remove test frame")
    end
    
    return allTestsPass
end

-- Export ThemeManager for external access
return ThemeManager