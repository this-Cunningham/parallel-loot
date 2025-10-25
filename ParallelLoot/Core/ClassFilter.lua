-- ParallelLoot Class Filter
-- Handles class compatibility filtering for loot items

local ClassFilter = {}
ParallelLoot.ClassFilter = ClassFilter

-- Class to armor type compatibility matrix
-- Lists armor types each class can wear (in order of preference)
ClassFilter.ClassArmorMatrix = {
    ["WARRIOR"] = {"Plate", "Mail", "Leather", "Cloth"},
    ["PALADIN"] = {"Plate", "Mail", "Leather", "Cloth"},
    ["HUNTER"] = {"Mail", "Leather", "Cloth"},
    ["ROGUE"] = {"Leather", "Cloth"},
    ["PRIEST"] = {"Cloth"},
    ["DEATHKNIGHT"] = {"Plate", "Mail", "Leather", "Cloth"},
    ["SHAMAN"] = {"Mail", "Leather", "Cloth"},
    ["MAGE"] = {"Cloth"},
    ["WARLOCK"] = {"Cloth"},
    ["MONK"] = {"Leather", "Cloth"},
    ["DRUID"] = {"Leather", "Cloth"}
}

-- Class to weapon type compatibility matrix
-- Lists weapon types each class can use
ClassFilter.ClassWeaponMatrix = {
    ["WARRIOR"] = {
        ["Axes"] = true,
        ["Swords"] = true,
        ["Maces"] = true,
        ["Polearms"] = true,
        ["Daggers"] = true,
        ["Fist Weapons"] = true,
        ["Staves"] = true,
        ["Bows"] = true,
        ["Crossbows"] = true,
        ["Guns"] = true,
        ["Thrown"] = true,
        ["Shields"] = true
    },
    ["PALADIN"] = {
        ["Axes"] = true,
        ["Swords"] = true,
        ["Maces"] = true,
        ["Polearms"] = true,
        ["Shields"] = true
    },
    ["HUNTER"] = {
        ["Axes"] = true,
        ["Swords"] = true,
        ["Daggers"] = true,
        ["Fist Weapons"] = true,
        ["Polearms"] = true,
        ["Staves"] = true,
        ["Bows"] = true,
        ["Crossbows"] = true,
        ["Guns"] = true
    },
    ["ROGUE"] = {
        ["Daggers"] = true,
        ["Swords"] = true,
        ["Maces"] = true,
        ["Fist Weapons"] = true,
        ["Axes"] = true,
        ["Bows"] = true,
        ["Crossbows"] = true,
        ["Guns"] = true,
        ["Thrown"] = true
    },
    ["PRIEST"] = {
        ["Maces"] = true,
        ["Daggers"] = true,
        ["Staves"] = true,
        ["Wands"] = true
    },
    ["DEATHKNIGHT"] = {
        ["Axes"] = true,
        ["Swords"] = true,
        ["Maces"] = true,
        ["Polearms"] = true
    },
    ["SHAMAN"] = {
        ["Maces"] = true,
        ["Axes"] = true,
        ["Daggers"] = true,
        ["Fist Weapons"] = true,
        ["Staves"] = true,
        ["Shields"] = true
    },
    ["MAGE"] = {
        ["Swords"] = true,
        ["Daggers"] = true,
        ["Staves"] = true,
        ["Wands"] = true
    },
    ["WARLOCK"] = {
        ["Swords"] = true,
        ["Daggers"] = true,
        ["Staves"] = true,
        ["Wands"] = true
    },
    ["MONK"] = {
        ["Fist Weapons"] = true,
        ["Axes"] = true,
        ["Maces"] = true,
        ["Swords"] = true,
        ["Polearms"] = true,
        ["Staves"] = true
    },
    ["DRUID"] = {
        ["Maces"] = true,
        ["Daggers"] = true,
        ["Fist Weapons"] = true,
        ["Polearms"] = true,
        ["Staves"] = true
    }
}

-- Armor type mappings for item subtypes
ClassFilter.ArmorTypeMap = {
    ["Plate"] = "Plate",
    ["Mail"] = "Mail",
    ["Leather"] = "Leather",
    ["Cloth"] = "Cloth",
    ["Shield"] = "Shield",
    ["Libram"] = "Libram",
    ["Idol"] = "Idol",
    ["Totem"] = "Totem",
    ["Sigil"] = "Sigil",
    ["Relic"] = "Relic"
}

-- Check if a player can use an item
function ClassFilter:CanPlayerUseItem(playerClass, lootItem)
    if not playerClass or not lootItem then
        return false
    end
    
    -- Get item type and subtype
    local itemType = lootItem.itemType
    local itemSubType = lootItem.itemSubType
    
    if not itemType then
        -- If we don't have type info, assume it's usable (trinkets, rings, etc.)
        return true
    end
    
    -- Check based on item type
    if itemType == "Armor" then
        return self:CanPlayerUseArmor(playerClass, itemSubType)
    elseif itemType == "Weapon" then
        return self:CanPlayerUseWeapon(playerClass, itemSubType)
    else
        -- Other items (trinkets, rings, necks, cloaks, etc.) are generally usable by all
        return true
    end
end

-- Check if a player can use armor
function ClassFilter:CanPlayerUseArmor(playerClass, armorSubType)
    if not armorSubType then
        return true
    end
    
    -- Get armor types this class can wear
    local allowedArmor = self.ClassArmorMatrix[playerClass]
    if not allowedArmor then
        return false
    end
    
    -- Check if the armor subtype is in the allowed list
    for _, armorType in ipairs(allowedArmor) do
        if armorSubType == armorType then
            return true
        end
    end
    
    -- Special handling for class-specific items (Librams, Idols, Totems, Sigils)
    if armorSubType == "Libram" and playerClass == "PALADIN" then
        return true
    elseif armorSubType == "Idol" and playerClass == "DRUID" then
        return true
    elseif armorSubType == "Totem" and playerClass == "SHAMAN" then
        return true
    elseif armorSubType == "Sigil" and playerClass == "DEATHKNIGHT" then
        return true
    end
    
    -- Shields are special - check weapon matrix
    if armorSubType == "Shield" then
        local weaponMatrix = self.ClassWeaponMatrix[playerClass]
        return weaponMatrix and weaponMatrix["Shields"] == true
    end
    
    return false
end

-- Check if a player can use weapon
function ClassFilter:CanPlayerUseWeapon(playerClass, weaponSubType)
    if not weaponSubType then
        return false
    end
    
    -- Get weapons this class can use
    local allowedWeapons = self.ClassWeaponMatrix[playerClass]
    if not allowedWeapons then
        return false
    end
    
    -- Check if the weapon subtype is in the allowed list
    return allowedWeapons[weaponSubType] == true
end

-- Filter items for a specific player
function ClassFilter:FilterItemsForPlayer(items, playerClass)
    if not items or not playerClass then
        return {}
    end
    
    local filteredItems = {}
    
    for _, item in ipairs(items) do
        if self:CanPlayerUseItem(playerClass, item) then
            table.insert(filteredItems, item)
        end
    end
    
    return filteredItems
end

-- Get player's current class
function ClassFilter:GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- Check if current player can use item
function ClassFilter:CanCurrentPlayerUseItem(lootItem)
    local playerClass = self:GetPlayerClass()
    return self:CanPlayerUseItem(playerClass, lootItem)
end

-- Get usability status for UI display
function ClassFilter:GetItemUsabilityStatus(lootItem, playerClass)
    playerClass = playerClass or self:GetPlayerClass()
    
    local canUse = self:CanPlayerUseItem(playerClass, lootItem)
    
    return {
        canUse = canUse,
        reason = canUse and "Usable" or "Cannot use this item type"
    }
end
