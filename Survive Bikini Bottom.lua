if getgenv().executed then return end 
getgenv().executed = true

if not LPH_OBFUSCATED then
    LPH_JIT = function(...) return ... end
    LPH_JIT_MAX = function(...) return ... end
    LPH_NO_VIRTUALIZE = function(...) return ... end
    LPH_ENCSTR = function(...) return ... end
    LPH_OBFUSCATED = false
end

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local HttpService = cloneref(game:GetService("HttpService"))
local EncodingService = cloneref(game:GetService("EncodingService"))
local TweenService = cloneref(game:GetService("TweenService"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

if game.PlaceId ~= 87571927272049 then 
    LocalPlayer:Kick("Please execute inside of a game.")
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

repeat task.wait() until workspace:FindFirstChild("Map")

local Trove = {}
Trove.__index = Trove

do 
    local FN_MARKER = newproxy()
    local THREAD_MARKER = newproxy()
    local GENERIC_OBJECT_CLEANUP_METHODS = table.freeze({ "Destroy", "Disconnect", "destroy", "disconnect" })

    local function getObjectCleanupFunction(object, cleanupMethod)
        local t = typeof(object)

        if t == "function" then
            return FN_MARKER
        elseif t == "thread" then
            return THREAD_MARKER
        end

        if cleanupMethod then
            return cleanupMethod
        end

        if t == "Instance" then
            return "Destroy"
        elseif t == "RBXScriptConnection" then
            return "Disconnect"
        elseif t == "table" then
            for _, genericCleanupMethod in GENERIC_OBJECT_CLEANUP_METHODS do
                if typeof(object[genericCleanupMethod]) == "function" then
                    return genericCleanupMethod
                end
            end
        end

        error(`failed to get cleanup function for object {t}: {object}`, 3)
    end

    local function assertPromiseLike(object)
        if
            typeof(object) ~= "table"
            or typeof(object.getStatus) ~= "function"
            or typeof(object.finally) ~= "function"
            or typeof(object.cancel) ~= "function"
        then
            error("did not receive a promise as an argument", 3)
        end
    end

    local function assertSignalLike(object)
        if
            typeof(object) ~= "RBXScriptSignal"
            and (typeof(object) ~= "table" or typeof(object.Connect) ~= "function" or typeof(object.Once) ~= "function")
        then
            error("did not receive a signal as an argument", 3)
        end
    end

    function Trove.new()
        local self = setmetatable({}, Trove)
        self._objects = {}
        self._cleaning = false
        return self
    end

    function Trove.Add(self, object, cleanupMethod)
        if self._cleaning then
            error("cannot call trove:Add() while cleaning", 2)
        end

        local cleanup = getObjectCleanupFunction(object, cleanupMethod)
        table.insert(self._objects, { object, cleanup })

        return object
    end

    function Trove.Clone(self, instance)
        if self._cleaning then
            error("cannot call trove:Clone() while cleaning", 2)
        end

        return self:Add(instance:Clone())
    end

    function Trove.Construct(self, class, ...)
        if self._cleaning then
            error("Cannot call trove:Construct() while cleaning", 2)
        end

        local object = nil
        local t = type(class)
        if t == "table" then
            object = class.new(...)
        elseif t == "function" then
            object = class(...)
        end

        return self:Add(object)
    end

    function Trove.Connect(self, signal, fn)
        if self._cleaning then
            error("Cannot call trove:Connect() while cleaning", 2)
        end
        assertSignalLike(signal)

        return self:Add(signal:Connect(fn))
    end

    function Trove.Once(self, signal, fn)
        if self._cleaning then
            error("Cannot call trove:Connect() while cleaning", 2)
        end
        assertSignalLike(signal)

        local conn
        conn = signal:Once(function(...)
            fn(...)
            self:Pop(conn)
        end)

        return self:Add(conn)
    end

    function Trove.BindToRenderStep(self, name, priority, fn)
        if self._cleaning then
            error("cannot call trove:BindToRenderStep() while cleaning", 2)
        end

        RunService:BindToRenderStep(name, priority, fn)

        self:Add(function()
            RunService:UnbindFromRenderStep(name)
        end)
    end

    function Trove.AddPromise(self, promise)
        if self._cleaning then
            error("cannot call trove:AddPromise() while cleaning", 2)
        end
        assertPromiseLike(promise)

        if promise:getStatus() == "Started" then
            promise:finally(function()
                if self._cleaning then
                    return
                end
                self:_findAndRemoveFromObjects(promise, false)
            end)

            self:Add(promise, "cancel")
        end

        return promise
    end

    function Trove.Remove(self, object)
        if self._cleaning then
            error("cannot call trove:Remove() while cleaning", 2)
        end

        return self:_findAndRemoveFromObjects(object, true)
    end

    function Trove.Pop(self, object)
        if self._cleaning then
            error("cannot call trove:Pop() while cleaning", 2)
        end

        return self:_findAndRemoveFromObjects(object, false)
    end

    function Trove.Extend(self)
        if self._cleaning then
            error("cannot call trove:Extend() while cleaning", 2)
        end

        return self:Construct(Trove)
    end

    function Trove.Clean(self)
        if self._cleaning then
            return
        end

        self._cleaning = true

        for _, obj in self._objects do
            self:_cleanupObject(obj[1], obj[2])
        end

        table.clear(self._objects)
        self._cleaning = false
    end

    function Trove.WrapClean(self)
        return function()
            self:Clean()
        end
    end

    function Trove._findAndRemoveFromObjects(self, object, cleanup)
        local objects = self._objects

        for i, obj in objects do
            if obj[1] == object then
                local n = #objects
                objects[i] = objects[n]
                objects[n] = nil

                if cleanup then
                    self:_cleanupObject(obj[1], obj[2])
                end

                return true
            end
        end

        return false
    end

    function Trove._cleanupObject(self, object, cleanupMethod)
        if cleanupMethod == FN_MARKER then
            task.spawn(object)
        elseif cleanupMethod == THREAD_MARKER then
            pcall(task.cancel, object)
        else
            object[cleanupMethod](object)
        end
    end

    function Trove.AttachToInstance(self, instance)
        if self._cleaning then
            error("cannot call trove:AttachToInstance() while cleaning", 2)
        elseif not instance:IsDescendantOf(game) then
            error("instance is not a descendant of the game hierarchy", 2)
        end

        return self:Connect(instance.Destroying, function()
            self:Destroy()
        end)
    end

    function Trove.Destroy(self)
        self:Clean()
    end
end


local MapGenerationConfig = {
	["Seed"] = nil,
	["MaxChunks"] = Vector2.new(74, 74),
	["CircularMap"] = true,
	["ChunkSize"] = 40,
	["ChunkSpacing"] = 5,
	["MaxSecondaryBiomes"] = 2,
	["BiomeBlendNoiseFrequency"] = 0.35,
	["BiomeBlendThreshold"] = 0.5,
	["SecondaryBiomeHeightBlend"] = 0.5,
	["PropsEnabled"] = true,
	["DefaultPropDensity"] = 0.7,
	["PropSpawnSpeed"] = 1,
	["MaxPropAttemptsPerSecond"] = 150,
	["CenterFlattenRadiusChunks"] = 6,
	["CenterFlattenBlendChunks"] = 3,
	["CenterFlattenStrength"] = 0.5,
	["CenterFlattenBaselineKernelRadius"] = 2,
	["DefaultHeroChunkSpacing"] = 20,
	["DefaultOnlyOuterGap"] = 2,
	["ChunkBatchSize"] = 400,
	["DynamicChunkBatching"] = false,
	["TargetChunkStepSeconds"] = 0.0015,
	["MinChunkBatchSize"] = 50,
	["MaxChunkBatchSize"] = 200,
	["FogEnabled"] = true,
	["Levels"] = {
		8,
		20,
		28,
		40,
		56,
		72
	}
}

local CraftingData = {
    ["TreasureMap"] = {Tier = 1, Stock = 1, Materials = {JellyfishJam = 3}},
    ["MattressBed"] = {Tier = 1, Stock = 1, Materials = {JellyfishJam = 20}},
    ["JellyfishTrap"] = {Tier = 1, Stock = 10, Materials = {JellyfishJam = 5}},
    ["WorkbenchTier2"] = {Tier = 1, Stock = 1, Materials = {JellyfishJam = 5, ShipScrap = 1}},
    ["AlarmClock"] = {Tier = 2, Stock = 1, Materials = {ShipScrap = 5}},
    ["TripleMattressBed"] = {Tier = 2, Stock = 1, Materials = {ShipScrap = 5}},
    ["PirateCompass"] = {Tier = 2, Stock = 1, Materials = {ShipScrap = 3}},
    ["ChumCooler"] = {Tier = 2, Stock = 2, Materials = {ShipScrap = 4}},
    ["ItemShelf"] = {Tier = 2, Materials = {ShipScrap = 5}},
    ["FruitPatch"] = {Tier = 2, Stock = 20, Materials = {JellyfishJam = 10}},
    ["BambooWall"] = {Tier = 2, Materials = {JellyfishJam = 12}},
    ["SeaMine"] = {Tier = 2, Materials = {ShipScrap = 3}},
    ["WorkbenchTier3"] = {Tier = 2, Stock = 1, Materials = {ShipScrap = 15, JellyfishJam = 15}},
    ["CookingGrill"] = {Tier = 3, Stock = 1, Materials = {JellyfishJam = 15, ShipScrap = 10}},
    ["JellyRefiner"] = {Tier = 3, Stock = 1, Materials = {JellyfishJam = 12, ShipScrap = 12}},
    ["FancyBed"] = {Tier = 3, Stock = 1, Materials = {JellyfishJam = 10, ShipScrap = 10}},
    ["GloveLamppost"] = {Tier = 3, Materials = {JellyfishJam = 6, ShipScrap = 6}},
    ["BeachUmbrella"] = {Tier = 3, Materials = {ShipScrap = 8}},
    ["QuicksterPad"] = {Tier = 3, Stock = 1, Materials = {JellyfishJam = 15, ShipScrap = 10}},
    ["WorkbenchTier4"] = {Tier = 3, Stock = 1, Materials = {JellyfishJam = 30, ShipScrap = 20, BucketHelmet = 2}},
    ["PattyVault"] = {Tier = 4, Stock = 1, Materials = {JellyfishJam = 30, ShipScrap = 20, BucketHelmet = 1}},
    ["ImaginationAmmoBox"] = {Tier = 4, Materials = {JellyfishJam = 20, ShipScrap = 30, BucketHelmet = 1}},
    ["RoyalBed"] = {Tier = 4, Stock = 1, Materials = {JellyfishJam = 20, ShipScrap = 30, BucketHelmet = 1}},
    ["JellyfishHiveTree"] = {Tier = 4, Materials = {JellyfishJam = 25, ShipScrap = 35, BucketHelmet = 1}},
    ["WorkbenchTier5"] = {Tier = 4, Stock = 1, Materials = {JellyfishJam = 50, ShipScrap = 50, GemOfTheSea = 1}},
    ["KrustyClock"] = {Tier = 5, Materials = {JellyfishJam = 40, ShipScrap = 40, GemOfTheSea = 1}},
}

--[[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDataPath = ReplicatedStorage.src.Shared.Items.ItemData

local AllItems = {}

for _, categoryModule in pairs(ItemDataPath:GetChildren()) do
    if categoryModule:IsA("ModuleScript") or categoryModule:IsA("Folder") then
        local categoryName = categoryModule.Name
        
        if not AllItems[categoryName] then
            AllItems[categoryName] = {}
        end
        
        for _, itemModule in pairs(categoryModule:GetChildren()) do
            if itemModule:IsA("ModuleScript") then
                local success, itemData = pcall(function()
                    return require(itemModule)
                end)
                
                if success and itemData then
                    local itemName = itemModule.Name
                    
                    AllItems[categoryName][itemName] = {}
                    
                    for key, value in pairs(itemData) do
                        AllItems[categoryName][itemName][key] = value
                    end
                else
                    warn("Failed to require item:", itemModule:GetFullName())
                end
            end
        end
    end
end

local function formatTable(tbl, indent)
    indent = indent or 0
    local indentStr = string.rep("    ", indent)
    local result = "{\n"
    
    for key, value in pairs(tbl) do
        local keyStr = type(key) == "string" and '["' .. key .. '"]' or "[" .. tostring(key) .. "]"
        
        result = result .. indentStr .. "    " .. keyStr .. " = "
        
        if type(value) == "table" then
            result = result .. formatTable(value, indent + 1)
        elseif type(value) == "string" then
            result = result .. '"' .. value:gsub('"', '\\"') .. '"'
        elseif type(value) == "number" or type(value) == "boolean" then
            result = result .. tostring(value)
        else
            result = result .. "nil"
        end
        
        result = result .. ",\n"
    end
    
    result = result .. indentStr .. "}"
    return result
end

local formattedTable = "local AllItems = " .. formatTable(AllItems) .. "\n\nreturn AllItems"

setclipboard(formattedTable)
]]

local ItemData = {
    ["Gears"] = {
        ["GoodNet"] = {
            ["GearType"] = "Nets",
            ["GearMetadata"] = {
                ["StaminaCost"] = 15,
                ["Damage"] = 30,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GoodNet",
            ["DisplayName"] = "Good Net",
            ["Description"] = "A net used for catching jellyfish.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["Medkit"] = {
            ["GearType"] = "Healing",
            ["GearMetadata"] = {
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "Medkit",
            ["CanDrop"] = true,
            ["DisplayName"] = "Medkit",
            ["Model"] = nil,
            ["UsageCooldown"] = 1,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["Description"] = "A portable medical kit used for healing.",
        },
        ["Flashlight"] = {
            ["GearType"] = "Flashlights",
            ["GearMetadata"] = {
                ["MaxBatteryLevel"] = 100,
            },
            ["DisplayName"] = "Flashlight",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "Flashlight",
            ["CanDrop"] = true,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["UsageCooldown"] = 1,
            ["Model"] = nil,
            ["Description"] = "Light up the darkness",
            ["DropScale"] = 1.25,
            ["MaxCount"] = 1,
        },
        ["DoodlePencil"] = {
            ["GearType"] = "Pencils",
            ["GearMetadata"] = {
                ["StaminaCost"] = 20,
                ["Damage"] = 40,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "DoodlePencil",
            ["DisplayName"] = "Doodle Pencil",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["KetchupBlaster"] = {
            ["GearType"] = "RangedWeapons",
            ["GearMetadata"] = {
                ["MagazineSize"] = 6,
                ["StaminaCost"] = 20,
                ["AmmoType"] = "KetchupAmmo",
                ["ProjectileSpeed"] = 50,
                ["MaxProjectileDistance"] = 200,
                ["Damage"] = 20,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "KetchupBlaster",
            ["DisplayName"] = "Ketchup Blaster",
            ["Description"] = "A fun toy that shoots ketchup!",
            ["Model"] = nil,
            ["UsageCooldown"] = 1,
            ["ItemType"] = "Gear",
            ["DropModel"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["Rarity"] = "Common",
        },
        ["GiantNet"] = {
            ["GearType"] = "Nets",
            ["GearMetadata"] = {
                ["StaminaCost"] = 10,
                ["Damage"] = 50,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GiantNet",
            ["DisplayName"] = "Giant Net",
            ["Description"] = "A net used for catching jellyfish.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["GooberGuitar"] = {
            ["GearType"] = "Guitars",
            ["GearMetadata"] = {
                ["EnergyPerShot"] = 100,
                ["StaminaCost"] = 20,
                ["MagazineSize"] = 1,
                ["AmmoType"] = "GooberEnergy",
                ["IsEnergyBased"] = true,
                ["ProjectileSpeed"] = 80,
                ["MaxProjectileDistance"] = 200,
                ["Damage"] = 100,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GooberGuitar",
            ["DisplayName"] = "Goober Guitar",
            ["Description"] = "A Goober Guitar.",
            ["UsageCooldown"] = 1,
            ["ItemType"] = "Gear",
            ["Model"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["Rarity"] = "Common",
        },
        ["GoodBackpack"] = {
            ["GearType"] = "Backpacks",
            ["GearMetadata"] = {
                ["BaseCapacity"] = 7,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GoodBackpack",
            ["DisplayName"] = "Good Backpack",
            ["Description"] = "A good backpack for carrying items.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["DropModel"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["OlReliable"] = {
            ["GearType"] = "Nets",
            ["GearMetadata"] = {
                ["StaminaCost"] = 15,
                ["Damage"] = 25,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "OlReliable",
            ["DisplayName"] = "Ol' Reliable",
            ["Description"] = "A net used for catching jellyfish.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["MercenaryCutlass"] = {
            ["GearType"] = "Swords",
            ["GearMetadata"] = {
                ["StaminaCost"] = 20,
                ["Damage"] = 40,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "MercenaryCutlass",
            ["DisplayName"] = "Mercenary Cutlass",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["GiantBackpack"] = {
            ["GearType"] = "Backpacks",
            ["GearMetadata"] = {
                ["BaseCapacity"] = 10,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GiantBackpack",
            ["DisplayName"] = "Giant Backpack",
            ["Description"] = "A giant backpack for carrying items.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["DropModel"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["GhostlyLantern"] = {
            ["GearType"] = "Flashlights",
            ["GearMetadata"] = {
                ["MaxBatteryLevel"] = 100,
            },
            ["DisplayName"] = "Ghostly Lantern",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GhostlyLantern",
            ["CanDrop"] = true,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["UsageCooldown"] = 1,
            ["Model"] = nil,
            ["Description"] = "Light up the darkness",
            ["DropScale"] = 1.25,
            ["MaxCount"] = 1,
        },
        ["Bandages"] = {
            ["GearType"] = "Healing",
            ["GearMetadata"] = {
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "Bandages",
            ["CanDrop"] = true,
            ["DisplayName"] = "Bandages",
            ["Model"] = nil,
            ["UsageCooldown"] = 1,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["Description"] = "A roll of bandages used for healing.",
        },
        ["GloveLight"] = {
            ["GearType"] = "Flashlights",
            ["GearMetadata"] = {
                ["MaxBatteryLevel"] = 100,
            },
            ["DisplayName"] = "Glove Light",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GloveLight",
            ["CanDrop"] = true,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["UsageCooldown"] = 1,
            ["Model"] = nil,
            ["Description"] = "Light up the darkness",
            ["DropScale"] = 1.25,
            ["MaxCount"] = 1,
        },
        ["ReefBlower"] = {
            ["GearType"] = "ReefBlowers",
            ["GearMetadata"] = {
                ["MagazineSize"] = 1,
                ["StaminaCost"] = 20,
                ["AmmoType"] = "BlowCanister",
                ["ProjectileSpeed"] = 80,
                ["MaxProjectileDistance"] = 200,
                ["Damage"] = 20,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "ReefBlower",
            ["DisplayName"] = "Reef Blower",
            ["Description"] = "A powerful gear that shoots bursts of water to knock back enemies.",
            ["Model"] = nil,
            ["UsageCooldown"] = 1,
            ["ItemType"] = "Gear",
            ["DropModel"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["Rarity"] = "Common",
        },
        ["Clarinet"] = {
            ["GearType"] = "Clarinets",
            ["GearMetadata"] = {
                ["MagazineSize"] = 3,
                ["StaminaCost"] = 20,
                ["AmmoType"] = "ClarinetBarrel",
                ["ProjectileSpeed"] = 80,
                ["MaxProjectileDistance"] = 200,
                ["Damage"] = 20,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "Clarinet",
            ["DisplayName"] = "Clarinet",
            ["Description"] = "A musical instrument that shoots sound at enemies.",
            ["Model"] = nil,
            ["UsageCooldown"] = 1,
            ["ItemType"] = "Gear",
            ["DropModel"] = nil,
            ["Icon"] = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            ["Rarity"] = "Common",
        },
        ["QuicksterShoes"] = {
            ["GearType"] = "Special",
            ["GearMetadata"] = {
                ["SpeedMultiplier"] = 1.5,
            },
            ["MaxCount"] = 1,
            ["ReferenceName"] = "QuicksterShoes",
            ["DisplayName"] = "Quickster Shoes",
            ["Description"] = "Light up the darkness",
            ["ItemType"] = "Gear",
            ["UsageCooldown"] = 1,
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["GearSetupCallback"] = nil,
        },
        ["TornNet"] = {
            ["GearType"] = "Nets",
            ["GearMetadata"] = {
                ["StaminaCost"] = 20,
                ["Damage"] = 20,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "TornNet",
            ["DisplayName"] = "Torn Net",
            ["Description"] = "A net used for catching jellyfish.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["RippedBackpack"] = {
            ["GearType"] = "Backpacks",
            ["GearMetadata"] = {
                ["BaseCapacity"] = 5,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "RippedBackpack",
            ["DisplayName"] = "Ripped Backpack",
            ["Description"] = "A ripped backpack for carrying items.",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["DropModel"] = nil,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["GreasySpatula"] = {
            ["GearType"] = "MeleeWeapons",
            ["GearMetadata"] = {
                ["StaminaCost"] = 20,
                ["Damage"] = 40,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GreasySpatula",
            ["DisplayName"] = "Greasy Spatula",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
        ["Spatula"] = {
            ["GearType"] = "MeleeWeapons",
            ["GearMetadata"] = {
                ["StaminaCost"] = 20,
                ["Damage"] = 40,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "Spatula",
            ["DisplayName"] = "Spatula",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Gear",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://116264133959549",
            },
            ["UsageCooldown"] = 1,
        },
    },
    ["Collectables"] = {
        ["Doubloon_1"] = {
            ["ReferenceName"] = "Doubloon_1",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Doubloon",
            ["ItemType"] = "Collectable",
            ["Icon"] = "rbxassetid://86227407119319",
            ["Reward"] = {
                ["Value"] = "Doubloons",
                ["Type"] = "Currency",
                ["Amount"] = 1,
            },
        },
        ["Doubloon_3"] = {
            ["ReferenceName"] = "Doubloon_3",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "3 Doubloons",
            ["ItemType"] = "Collectable",
            ["Icon"] = "rbxassetid://86227407119319",
            ["Reward"] = {
                ["Value"] = "Doubloons",
                ["Type"] = "Currency",
                ["Amount"] = 3,
            },
        },
        ["Doubloon_5"] = {
            ["ReferenceName"] = "Doubloon_5",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "5 Doubloons",
            ["ItemType"] = "Collectable",
            ["Icon"] = "rbxassetid://86227407119319",
            ["Reward"] = {
                ["Value"] = "Doubloons",
                ["Type"] = "Currency",
                ["Amount"] = 5,
            },
        },
    },
    ["Ammo"] = {
        ["BlowCanister"] = {
            ["ReferenceName"] = "BlowCanister",
            ["Description"] = "Ammo for the Reef Blower.",
            ["Model"] = nil,
            ["ItemType"] = "Ammo",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Blow Canister",
        },
        ["KetchupAmmo"] = {
            ["ReferenceName"] = "KetchupAmmo",
            ["Description"] = "Ammo for the Ketchup Blaster.",
            ["Model"] = nil,
            ["ItemType"] = "Ammo",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Ketchup Ammo",
        },
        ["ClarinetBarrel"] = {
            ["ReferenceName"] = "ClarinetBarrel",
            ["Description"] = "Ammo for the Clarinet.",
            ["Model"] = nil,
            ["ItemType"] = "Ammo",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Clarinet Barrel",
        },
    },
    ["Miscellaneous"] = {
        ["JellyJar"] = {
            ["ReferenceName"] = "JellyJar",
            ["Description"] = "A jar filled with jelly.",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Jelly Jar",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["JellyfishJam"] = 2,
            },
        },
        ["Radio"] = {
            ["ReferenceName"] = "Radio",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Radio",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            ["Byproducts"] = {
                ["ShipScrap"] = 1,
            },
        },
        ["JellyBarrel"] = {
            ["ReferenceName"] = "JellyBarrel",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Jelly Barrel",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["JellyfishJam"] = 3,
            },
        },
        ["HelpfulSign"] = {
            ["ReferenceName"] = "HelpfulSign",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Helpful Sign",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 1,
            },
        },
        ["Muffler"] = {
            ["ReferenceName"] = "Muffler",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Muffler",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 1,
            },
        },
        ["ToxicBarrel"] = {
            ["ReferenceName"] = "ToxicBarrel",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Chum Barrel",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 2,
            },
        },
        ["KingJellyJar"] = {
            ["ReferenceName"] = "KingJellyJar",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "King Jelly Jar",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["JellyfishJam"] = 4,
            },
        },
        ["SodaHat"] = {
            ["ReferenceName"] = "SodaHat",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Soda Hat",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 3,
            },
        },
        ["RandomItem"] = {
            ["ReferenceName"] = "RandomItem",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Miscellaneous",
            ["Rarity"] = "Common",
            ["Icon"] = "rbxassetid://124892809718821",
            ["DisplayName"] = "Random Item",
        },
        ["RubberTire"] = {
            ["ReferenceName"] = "RubberTire",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Rubber Tire",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 2,
            },
        },
        ["BrokenMotorcycle"] = {
            ["ReferenceName"] = "BrokenMotorcycle",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Broken Motorcycle",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 4,
            },
        },
        ["CyclopsHelmet"] = {
            ["ReferenceName"] = "CyclopsHelmet",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Cyclops Helmet",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 3,
            },
        },
        ["JellyBlob"] = {
            ["ReferenceName"] = "JellyBlob",
            ["Description"] = "A blob of jelly",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Jelly Blob",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["JellyfishJam"] = 1,
            },
        },
        ["OpenCan"] = {
            ["ReferenceName"] = "OpenCan",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Open Can",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 1,
            },
        },
        ["BentBucket"] = {
            ["ReferenceName"] = "BentBucket",
            ["Description"] = "",
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["DisplayName"] = "Bent Bucket",
            ["ItemType"] = "Miscellaneous",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["ShipScrap"] = 1,
            },
        },
    },
    ["Armors"] = {
        ["KnightArmor"] = {
            ["GearType"] = "Armor",
            ["GearMetadata"] = {
                ["DamageReduction"] = 0.25,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "KnightArmor",
            ["DisplayName"] = "Knight Armor",
            ["Model"] = nil,
            ["Description"] = "Sturdy armor worn by valiant knights.",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["KrabShellArmor"] = {
            ["GearType"] = "Armor",
            ["GearMetadata"] = {
                ["DamageReduction"] = 0.35,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "KrabShellArmor",
            ["DisplayName"] = "Krab Shell Armor",
            ["Model"] = nil,
            ["Description"] = "Armor made from the tough shell of a krab.",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["DoodleArmor"] = {
            ["GearType"] = "Armor",
            ["GearMetadata"] = {
                ["EquippableAtWill"] = true,
                ["DamageReduction"] = 0.25,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "DoodleArmor",
            ["DisplayName"] = "Doodle Armor",
            ["Model"] = nil,
            ["Description"] = "Armor that is imbued with poisonous doodles.",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["BubbleWrapArmor"] = {
            ["GearType"] = "Armor",
            ["GearMetadata"] = {
                ["DamageReduction"] = 0.1,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "BubbleWrapArmor",
            ["DisplayName"] = "Bubble Wrap Armor",
            ["Model"] = nil,
            ["Description"] = "Protective bubble wrap armor to cushion your falls.",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["AntiGhostArmor"] = {
            ["GearType"] = "Armor",
            ["GearMetadata"] = {
                ["DamageReduction"] = 0.15,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "AntiGhostArmor",
            ["DisplayName"] = "Anti-Ghost Armor",
            ["Model"] = nil,
            ["Description"] = "Armor that protects against ghostly attacks.",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
        ["GGRockArmor"] = {
            ["GearType"] = "Armor",
            ["GearMetadata"] = {
                ["EquippableAtWill"] = true,
                ["DamageReduction"] = 0.2,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GGRockArmor",
            ["DisplayName"] = "GG Rockstar Armor",
            ["Model"] = nil,
            ["Description"] = "You can feel the energy!",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Rarity"] = "Common",
        },
    },
    ["Crafting"] = {
        ["WorkbenchTier4"] = {
            ["ReferenceName"] = "WorkbenchTier4",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://121506976536449",
            },
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["Description"] = "Unlocks access to Tier 4 recipes.",
            ["ItemType"] = "CraftingBench",
            ["GearSetupCallback"] = nil,
            ["DisplayName"] = "Workbench Tier 4",
        },
        ["CookingGrill"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["RequiredJellyJar"] = 1,
                ["RequiredKrabbyPatty"] = 1,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "CookingGrill",
            ["CanDrop"] = true,
            ["DisplayName"] = "Cooking Grill",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Throw in Krabby Patty and Jelly Jar to cook Blue Jelly Patties!",
        },
        ["AlarmClock"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "AlarmClock",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Foghorn Alarm Clock",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Shows how much time is left until day/night.",
        },
        ["QuicksterPad"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["BoostDuration"] = 10,
                ["WalkSpeedMultiplier"] = 2,
                ["PlaceOutsideCircle"] = true,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "QuicksterPad",
            ["CanDrop"] = true,
            ["DisplayName"] = "Quickster Pad",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://121506976536449",
            },
            ["Description"] = "Grants a temporary speed boost once activated and used.",
        },
        ["PattyVault"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["AvoidBlueprintOverlap"] = true,
                ["MaxDistanceFromCircle"] = 170,
                ["PlaceOutsideCircle"] = true,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "PattyVault",
            ["CanDrop"] = true,
            ["DisplayName"] = "Patty Vault",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Massive food storage to keep lots of food fresh.",
        },
        ["WorkbenchTier2"] = {
            ["ReferenceName"] = "WorkbenchTier2",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["Description"] = "Unlocks access to Tier 2 recipes.",
            ["ItemType"] = "CraftingBench",
            ["GearSetupCallback"] = nil,
            ["DisplayName"] = "Workbench Tier 2",
        },
        ["BeachUmbrella"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "BeachUmbrella",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Beach Umbrella",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Stay cool and shaded with this beach umbrella.",
        },
        ["ItemShelf"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "ItemShelf",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Item Shelf",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://121506976536449",
            },
            ["Description"] = "Store your items on this handy shelf.",
        },
        ["PirateCompass"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "PirateCompass",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Pirate Compass",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Shows directions and locations of residents on the map.",
        },
        ["TreasureMap"] = {
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "TreasureMap",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Treasure Map",
            ["Description"] = "Lets you open/view the map of Bikini Bottom anywhere.",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://121506976536449",
            },
            ["ItemType"] = "Gear",
        },
        ["JellyfishTrap"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["SpawnInterval"] = 60,
                ["GemChance"] = 0.025,
                ["PlaceOutsideCircle"] = true,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "JellyfishTrap",
            ["CanDrop"] = true,
            ["DisplayName"] = "Jellyfish Trap",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Can be placed to catch Jellyfish for jelly or food.",
        },
        ["ProtectiveJellyStorage"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "ProtectiveJellyStorage",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Protective Jelly Storage",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Keep your jelly safe and sound with this protective storage.",
        },
        ["JellyRefiner"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["Input"] = "JellyJar",
                ["JarsToRefine"] = 1,
                ["Output"] = "JellyBarrel",
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "JellyRefiner",
            ["CanDrop"] = true,
            ["DisplayName"] = "Jelly Refiner",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Throw in Jelly Jars to refine into Jelly Barrels.",
        },
        ["MattressBed"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["BonusDays"] = 1,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "MattressBed",
            ["CanDrop"] = true,
            ["DisplayName"] = "Mattress Bed",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://121506976536449",
            },
            ["Description"] = "Rest to pass the day (+1 Day Counter).",
        },
        ["FruitPatch"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["PotentialFruit"] = {
                    [1] = "Watermelon",
                    [2] = "Pineapple",
                },
                ["DaysToGrow"] = 2,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "FruitPatch",
            ["CanDrop"] = true,
            ["DisplayName"] = "Fruit Patch",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Bears fruit every 2 days.",
        },
        ["GloveLamppost"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "GloveLamppost",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Glove Lamppost",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Light up the night with this handy lamppost.",
        },
        ["SeaMine"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["ExplosionSize"] = 10,
                ["Damage"] = 60,
                ["IsDefensiveStructure"] = true,
                ["PlaceOutsideCircle"] = true,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "SeaMine",
            ["CanDrop"] = true,
            ["DisplayName"] = "Sea Mine",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Explodes when enemies get too close.",
        },
        ["BambooWall"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["IsDefensiveStructure"] = true,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "BambooWall",
            ["CanDrop"] = true,
            ["DisplayName"] = "Bamboo Wall",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "A sturdy wall to protect your base from enemies.",
        },
        ["ChumCooler"] = {
            ["GearType"] = "Other",
            ["Rarity"] = "Common",
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "ChumCooler",
            ["CanDrop"] = true,
            ["Model"] = nil,
            ["DisplayName"] = "Chum Cooler",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Keeps food fresh and prevents it from rotting over time.",
        },
        ["WorkbenchTier3"] = {
            ["ReferenceName"] = "WorkbenchTier3",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Rarity"] = "Common",
            ["Model"] = nil,
            ["Description"] = "Unlocks access to Tier 3 recipes.",
            ["ItemType"] = "CraftingBench",
            ["GearSetupCallback"] = nil,
            ["DisplayName"] = "Workbench Tier 3",
        },
        ["FancyBed"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["BonusDays"] = 1,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "FancyBed",
            ["CanDrop"] = true,
            ["DisplayName"] = "Fancy Bed",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://90647093229123",
            },
            ["Description"] = "Rest to pass the day (+1 Day Counter).",
        },
        ["TripleMattressBed"] = {
            ["GearType"] = "Other",
            ["GearMetadata"] = {
                ["BonusDays"] = 1,
            },
            ["GearSetupCallback"] = nil,
            ["ReferenceName"] = "TripleMattressBed",
            ["CanDrop"] = true,
            ["DisplayName"] = "Triple Mattress Bed",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Gear",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://121506976536449",
            },
            ["Description"] = "Rest to pass the day (+1 Day Counter).",
        },
    },
    ["Keys"] = {
        ["KrustyKey"] = {
            ["ReferenceName"] = "KrustyKey",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Key",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Krusty Key",
        },
        ["MasterChumKey"] = {
            ["ReferenceName"] = "MasterChumKey",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Key",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Master Chum Key",
        },
        ["ChumKey"] = {
            ["ReferenceName"] = "ChumKey",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Key",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Chum Key",
        },
        ["BoatKey"] = {
            ["ReferenceName"] = "BoatKey",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Key",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Boat Key",
        },
        ["WarehouseKey"] = {
            ["ReferenceName"] = "WarehouseKey",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Key",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Warehouse Key",
        },
        ["AcornKey"] = {
            ["ReferenceName"] = "AcornKey",
            ["Description"] = "",
            ["Model"] = nil,
            ["ItemType"] = "Key",
            ["Rarity"] = "Common",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["DisplayName"] = "Acorn Key",
        },
    },
    ["Resources"] = {
        ["JellyfishJam"] = {
            ["BackdropColor"] = nil,
            ["Description"] = "One of the basic resources in the game.",
            ["DisplayName"] = "Jellyfish Jam",
            ["Byproducts"] = {
            },
            ["ResourceVariant"] = "JellyfishJam",
            ["ResourceType"] = "JellyfishJam",
            ["ItemType"] = "Resource",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ResourceOrder"] = 1,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://130931439660564",
            },
            ["ReferenceName"] = "JellyfishJam",
        },
        ["GemOfTheSea"] = {
            ["BackdropColor"] = nil,
            ["Disabled"] = true,
            ["DisplayName"] = "Gem of the Sea",
            ["ResourceVariant"] = "GemOfTheSea",
            ["Byproducts"] = {
            },
            ["ItemType"] = "Resource",
            ["ResourceType"] = "GemOfTheSea",
            ["Rarity"] = "Common",
            ["ResourceOrder"] = 4,
            ["Model"] = nil,
            ["Description"] = "",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://130931439660564",
            },
            ["ReferenceName"] = "GemOfTheSea",
        },
        ["BucketHelmet"] = {
            ["BackdropColor"] = nil,
            ["Description"] = "",
            ["DisplayName"] = "Bucket Helmet",
            ["Byproducts"] = {
                ["BucketHelmet"] = 1,
            },
            ["ResourceVariant"] = "BucketHelmet",
            ["ResourceType"] = "BucketHelmet",
            ["ItemType"] = "Resource",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ResourceOrder"] = 3,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://130931439660564",
            },
            ["ReferenceName"] = "BucketHelmet",
        },
        ["ShipScrap"] = {
            ["BackdropColor"] = nil,
            ["Description"] = "One of the basic resources in the game.",
            ["DisplayName"] = "Ship Scrap",
            ["Byproducts"] = {
            },
            ["ResourceVariant"] = "ShipScrap",
            ["ResourceType"] = "ShipScrap",
            ["ItemType"] = "Resource",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ResourceOrder"] = 2,
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://130931439660564",
            },
            ["ReferenceName"] = "ShipScrap",
        },
    },
    ["Consumables"] = {
        ["RottenWatermelon"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenWatermelon",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Watermelon",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["RottenChocolateBar"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenChocolateBar",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Chocolate Bar",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["KelpShake"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "KelpShake",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 10,
            },
            ["DisplayName"] = "Kelp Shake",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 2,
            },
        },
        ["BlueJellyPatty"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "BlueJellyPatty",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 45,
            },
            ["DisplayName"] = "Blue Jelly Patty",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 4,
            },
        },
        ["CannedBread"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "CannedBread",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 10,
            },
            ["DisplayName"] = "Canned Bread",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 2,
            },
        },
        ["JellyPatty"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "JellyPatty",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 20,
            },
            ["DisplayName"] = "Jelly Patty",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 3,
            },
        },
        ["RottenClamChowder"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenClamChowder",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Clam Chowder",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["ClamChowder"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "ClamChowder",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 10,
            },
            ["DisplayName"] = "Clam Chowder",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 2,
            },
        },
        ["ChocolateBar"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "ChocolateBar",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 10,
            },
            ["DisplayName"] = "Chocolate Bar",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 2,
            },
        },
        ["Acorn"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "Acorn",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 20,
            },
            ["DisplayName"] = "Acorn",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 3,
            },
        },
        ["NastyPatty"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "NastyPatty",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Nasty Patty",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["KrabbyPatty"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "KrabbyPatty",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 20,
            },
            ["DisplayName"] = "Krabby Patty",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 3,
            },
        },
        ["Watermelon"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "Watermelon",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 5,
            },
            ["DisplayName"] = "Watermelon",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["RottenAcorn"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenAcorn",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Acorn",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["RottenCannedBread"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenCannedBread",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Canned Bread",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["RottenPineapple"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenPineapple",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Pineapple",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["RottenKelpShake"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "RottenKelpShake",
            ["ConsumableMetadata"] = {
                ["HungerIncrease"] = 10,
            },
            ["DisplayName"] = "Rotten Kelp Shake",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://122960579403193",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
        ["Pineapple"] = {
            ["Description"] = "",
            ["ConsumeCallback"] = nil,
            ["ConsumableType"] = "Food",
            ["ReferenceName"] = "Pineapple",
            ["ConsumableMetadata"] = {
                ["HungerRestore"] = 5,
            },
            ["DisplayName"] = "Pineapple",
            ["Model"] = nil,
            ["Rarity"] = "Common",
            ["ItemType"] = "Consumable",
            ["Icon"] = {
                ["ImageRectOffset"] = nil,
                ["ImageRectSize"] = nil,
                ["ImageURL"] = "rbxassetid://137368705587744",
            },
            ["Byproducts"] = {
                ["Hunger"] = 1,
            },
        },
    },
}

--[[
local ResidentDataFolder = game:GetService("ReplicatedStorage").src.Shared.Residents.ResidentData

local allResidents = {}

for _, residentModule in ipairs(ResidentDataFolder:GetChildren()) do
    if residentModule:IsA("ModuleScript") then
        local success, residentData = pcall(function()
            return require(residentModule)
        end)
        
        if success then
            allResidents[residentData.ReferenceName] = residentData
        else
            warn("Failed to require:", residentModule.Name, residentData)
        end
    end
end

local function tableToString(tbl, indent, seen)
    indent = indent or 0
    seen = seen or {}
    
    if seen[tbl] then
        return '"[Circular Reference]"'
    end
    seen[tbl] = true
    
    local spacing = string.rep("    ", indent)
    local result = "{\n"
    
    local numericKeys = {}
    local stringKeys = {}
    
    for key, _ in pairs(tbl) do
        if type(key) == "number" then
            table.insert(numericKeys, key)
        else
            table.insert(stringKeys, key)
        end
    end
    
    table.sort(numericKeys)
    table.sort(stringKeys)
    
    for _, key in ipairs(numericKeys) do
        local value = tbl[key]
        result = result .. spacing .. "    "
        
        if type(value) == "table" then
            result = result .. tableToString(value, indent + 1, seen)
        elseif type(value) == "string" then
            result = result .. '"' .. value:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
        elseif type(value) == "boolean" or type(value) == "number" then
            result = result .. tostring(value)
        elseif type(value) == "nil" then
            result = result .. "nil"
        elseif typeof(value) == "Instance" then
            result = result .. '"' .. value:GetFullName() .. '"'
        else
            result = result .. '"' .. tostring(value) .. '"'
        end
        
        result = result .. ",\n"
    end
    
    for _, key in ipairs(stringKeys) do
        local value = tbl[key]
        result = result .. spacing .. "    "
        
        if key:match("^[%a_][%w_]*$") then
            result = result .. key .. " = "
        else
            result = result .. '["' .. key:gsub('"', '\\"') .. '"] = '
        end
        
        if type(value) == "table" then
            result = result .. tableToString(value, indent + 1, seen)
        elseif type(value) == "string" then
            result = result .. '"' .. value:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
        elseif type(value) == "boolean" or type(value) == "number" then
            result = result .. tostring(value)
        elseif type(value) == "nil" then
            result = result .. "nil"
        elseif typeof(value) == "Instance" then
            result = result .. '"' .. value:GetFullName() .. '"'
        else
            result = result .. '"' .. tostring(value) .. '"'
        end
        
        result = result .. ",\n"
    end
    
    result = result .. spacing .. "}"
    return result
end

local formattedTable = "local ResidentData = " .. tableToString(allResidents) .. "\n\nreturn ResidentData"

setclipboard(formattedTable)
]]

local ResidentData = {
    MrKrabs = {
        BonusDays = 1,
        Description = "",
        DisplayName = "Mr. Krabs",
        Icon = {
            ImageRectOffset = "0, 0",
            ImageRectSize = "128, 128",
            ImageURL = "rbxassetid://118854012993348",
        },
        Model = "ReplicatedStorage.Assets.Residents.MrKrabs",
        ReferenceName = "MrKrabs",
        UnlockOrder = 1,
    },
    Patrick = {
        BonusDays = 1,
        Description = "",
        DisplayName = "Patrick",
        Icon = {
            ImageRectOffset = "128, 0",
            ImageRectSize = "128, 128",
            ImageURL = "rbxassetid://118854012993348",
        },
        Model = "ReplicatedStorage.Assets.Residents.Patrick",
        ReferenceName = "Patrick",
        UnlockOrder = 4,
    },
    Sandy = {
        BonusDays = 1,
        Description = "",
        DisplayName = "Sandy",
        Icon = {
            ImageRectOffset = "256, 0",
            ImageRectSize = "128, 128",
            ImageURL = "rbxassetid://118854012993348",
        },
        Model = "ReplicatedStorage.Assets.Residents.Sandy",
        ReferenceName = "Sandy",
        UnlockOrder = 3,
    },
    SpongeBob = {
        BonusDays = 3,
        Description = "",
        DisplayName = "SpongeBob",
        Icon = {
            ImageRectOffset = "384, 0",
            ImageRectSize = "128, 128",
            ImageURL = "rbxassetid://118854012993348",
        },
        Model = "ReplicatedStorage.Assets.Residents.SpongeBob",
        ReferenceName = "SpongeBob",
        UnlockOrder = 5,
    },
    Squidward = {
        BonusDays = 1,
        Description = "",
        DisplayName = "Squidward",
        Icon = {
            ImageRectOffset = "512, 0",
            ImageRectSize = "128, 128",
            ImageURL = "rbxassetid://118854012993348",
        },
        Model = "ReplicatedStorage.Assets.Residents.Squidward",
        ReferenceName = "Squidward",
        UnlockOrder = 2,
    },
}

local GetBackupData = LPH_JIT_MAX(function()
    local backupData = {}
    local backupFolder = ReplicatedStorage:FindFirstChild("__GAMEBEAST_BACKUP")
    for _, config in backupFolder:GetChildren() do
        if not config:IsA("Configuration") then continue end
        local compressed = config:GetAttribute("Data")
        if compressed then
            local decompressed= EncodingService:DecompressBuffer(
                buffer.fromstring(compressed), 
                Enum.CompressionAlgorithm.Zstd
            )
            local jsonString = buffer.tostring(decompressed)
            local parsedData = HttpService:JSONDecode(jsonString)
            backupData[config.Name] = parsedData
        end
    end
    return backupData
end)

local BackupData = GetBackupData()

local MainTrove = Trove.new()

local Remotes = ReplicatedStorage.src.Packages._Index["raild3x_netwire@0.3.4"].netwire.Remotes
local NetworkEvent = Remotes.TableReplicator.RE.NetworkEvent
local AttemptDrag = Remotes.ItemDragService.RF.AttemptDrag
local StopDrag = Remotes.ItemDragService.RF.StopDrag

local TeleportLocations = {
    MaterialProcessor = workspace.Map.Chunks.BikiniBottom.ConchStreet.LIGHT_SOURCE.MaterialProcessor._HITBOX,
    MaterialProcessorCraft = workspace.Map.Chunks.BikiniBottom.ConchStreet.CRAFTING_BENCH.MaterialProcessor._HITBOX,
}

local Settings = {
    AutoFarmEnabled = false,
    AutoFarmClosestEnabled = false,
    SelectedEntities = {"Jellyfish"},
    
    SelectedBring = {},
    SelectedResidents = {},
    AutoEatEnabled = false,
    AutoCraftEnabled = false,
    SelectedCraftItems = {},
    InstantOpenChests = false,

    WalkSpeed = {
        Enabled = false,
        Speed = 50,
    },
    Fly = {
        Enabled = false,
        Speed = 50,
    },
}

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local ItemsToolkit = {} 

ItemsToolkit.GetAllItems = LPH_JIT(function()
    local items = {} 
    for _, data in ItemData do 
        for _, item in data do 
            items[item.ReferenceName] = item
        end
    end
    return items 
end)

ItemsToolkit.GetItemData = LPH_JIT(function(refName)
    for _, data in ItemData do 
        for _, item in data do 
            if item.ReferenceName == refName then 
                return item
            end
        end
    end
end)

local Utils = {}

Utils.TweenPivot = LPH_JIT_MAX(function(model, targetCFrame, duration, easingStyle, easingDirection)
    easingStyle = easingStyle or Enum.EasingStyle.Linear 
    easingDirection = easingDirection or Enum.EasingDirection.Out
    duration = duration or 0.5
    local startCFrame = model:GetPivot() 
    local startTime = os.clock() 
    local connection; connection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime 
        local alpha = elapsed / duration 
        alpha = TweenService:GetValue(alpha, easingStyle, easingDirection)
        if alpha >= 1 then
            model:PivotTo(targetCFrame)
            connection:Disconnect() 
        else 
            model:PivotTo(startCFrame:Lerp(targetCFrame, alpha))
        end
    end) 
    return {
        Cancel = function()
            connection:Disconnect()
        end,
    }
end)

Utils.GetLightSourceLevel = LPH_JIT_MAX(function()
    local levelText = workspace.Map.Chunks.BikiniBottom.ConchStreet.LIGHT_SOURCE.Core.LightSourceBillboard.LightSourceDisplay.Level.Text
    local level = tonumber(levelText:match("%d+"))
    return level or 0
end)

Utils.IsInBounds = LPH_JIT(function(position)
    local chunkSize = MapGenerationConfig.ChunkSize + (MapGenerationConfig.ChunkSpacing or 0)
    local boundaryCenter = Vector3.new(-chunkSize / 2, 0, -chunkSize / 2)
    local distanceFromCenter = (Vector2.new(position.X, position.Z) - Vector2.new(boundaryCenter.X, boundaryCenter.Z)).Magnitude
    

    local level = Utils.GetLightSourceLevel()
    local maxLevel = level == 0 and 1 or level
    local maxRadius = (MapGenerationConfig.Levels[maxLevel] * MapGenerationConfig.ChunkSize + (MapGenerationConfig.Levels[maxLevel] - 1) * MapGenerationConfig.ChunkSpacing) / 2
    
    return distanceFromCenter <= maxRadius
end)

Utils.GetCharacter = LPH_JIT_MAX(function()
    return LocalPlayer.Character
end)

Utils.GetRootPart = LPH_JIT_MAX(function()
    local character = Utils.GetCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end)

Utils.GetItemsByName = LPH_JIT(function(itemName)
    local items = {}
    for _, item in CollectionService:GetTagged("Interactable") do
        local refName = item:GetAttribute("ReferenceName")
        if refName == itemName then
            table.insert(items, item)
        end
    end
    return items
end)

Utils.GetEntitiesByName = LPH_JIT(function(entityName)
    local entities = {}
    for _, entity in CollectionService:GetTagged("Entity") do
        if Utils.IsInBounds(entity:GetPivot().Position) then
            local refName = entity:GetAttribute("ReferenceName")
            if refName == entityName and entity:GetAttribute("IsAlive") then
                table.insert(entities, entity)
            end
        end
    end
    return entities
end)

Utils.EntityExistsInMap = LPH_JIT_MAX(function(entityName)
    return #Utils.GetEntitiesByName(entityName) > 0
end)

Utils.GetClosestEntity = LPH_JIT(function(position, filterFunc)
    local closestEntity = nil
    local lowestMagnitude = math.huge

    for _, entity in CollectionService:GetTagged("Entity") do 
        if not Utils.IsInBounds(entity:GetPivot().Position) then continue end
        if not entity:GetAttribute("IsAlive") then continue end
        
        local refName = entity:GetAttribute("ReferenceName")
        if ResidentData[refName] then continue end
        
        if filterFunc and not filterFunc(entity) then continue end

        local magnitude = (position - entity:GetPivot().Position).Magnitude 
        if magnitude < lowestMagnitude then 
            closestEntity = entity 
            lowestMagnitude = magnitude
        end
    end

    return closestEntity
end)

local ItemModule = {}

ItemModule.BringItem = LPH_NO_VIRTUALIZE(function(self, item, position)
    AttemptDrag:InvokeServer(item)
    if item.PrimaryPart then 
    item.PrimaryPart.Anchored = true 
    end
    item:PivotTo(CFrame.new(position))
    StopDrag:InvokeServer()

    local alignPosition = item:FindFirstChild("AlignPosition", true)
    local alignOrientation = item:FindFirstChild("AlignOrientation", true)
    if alignPosition then alignPosition:Destroy() end
    if alignOrientation then alignOrientation:Destroy() end
    if item.PrimaryPart then 
    item.PrimaryPart.Anchored = false
    end
end)

ItemModule.BringItems = LPH_JIT(function(self, itemNames, amount)
    local rootPart = Utils.GetRootPart()
    if not rootPart then return end

    local totalHeight = 0
    local forwardOffset = 5

    for itemName in itemNames do
        local items = Utils.GetItemsByName(itemName)

        for i = 1, amount or #items do
            local item = items[i]
            if not item then break end

            task.spawn(function()
                local height = item:GetExtentsSize().Y
                local position = (rootPart.Position + rootPart.CFrame.LookVector * forwardOffset) + Vector3.new(0, height/2 + totalHeight, 0)
                totalHeight += height
                self:BringItem(item, position)
            end)
        end
    end
end)

ItemModule.TeleportToProcessor = LPH_JIT(function(self, items, processorType)
    processorType = processorType or "MaterialProcessor"
    
    if not TeleportLocations[processorType] then return end

    local targetPosition = TeleportLocations[processorType].Position
    local totalHeight = 0
    local stackOffset = 5

    for _, item in items do
        task.spawn(function()
            local height = item:GetExtentsSize().Y
            local position = targetPosition + Vector3.new(0, height/2 + totalHeight + stackOffset, 0)
            totalHeight += height
            self:BringItem(item, position)
        end)
    end
end)

ItemModule.TeleportItemsByName = LPH_JIT(function(self, itemNames, processorType)
    local allItems = {}
    for itemName in itemNames do
        local items = Utils.GetItemsByName(itemName)
        for _, item in items do
            table.insert(allItems, item)
        end
    end
    self:TeleportToProcessor(allItems, processorType)
end)

local TeleportModule = {}

TeleportModule.TeleportPlayer = LPH_NO_VIRTUALIZE(function(self, location)
    local character = Utils.GetCharacter()
    local rootPart = Utils.GetRootPart()
    if not character or not rootPart then return end

    if TeleportLocations[location] then
        local targetPart = TeleportLocations[location]
        character:PivotTo(targetPart.CFrame + Vector3.new(0, 5, 0))
    end
end)


local FarmBase = {}
FarmBase.__index = FarmBase

function FarmBase.new(name)
    local self = setmetatable({}, FarmBase)
    self.name = name or "Farm"
    self._currentEntity = nil
    self._originalPosition = nil
    self._enabled = false
    self._teleportConnection = nil
    return self
end

FarmBase.IsEnabled = LPH_JIT_MAX(function(self)
    return self._enabled
end)

FarmBase.SetEnabled = LPH_JIT(function(self, enabled)
    self._enabled = enabled
    if not enabled then
        self:ResetPosition()
    end
end)

FarmBase.ResetPosition = LPH_NO_VIRTUALIZE(function(self)
    if self._originalPosition then
        local character = Utils.GetCharacter()
        if character then
            character:PivotTo(self._originalPosition)
        end
        self._originalPosition = nil
    end
end)

function FarmBase:GetTargetEntity(position)
    return nil
end

FarmBase.ShouldContinueFarming = LPH_JIT_MAX(function(self)
    return self._enabled
end)

FarmBase.GetMelee = LPH_NO_VIRTUALIZE(function(self)
    for _, melee in CollectionService:GetTagged("MeleeGear") do
        local ownerId = melee:GetAttribute("OwnerId")
        if ownerId ~= LocalPlayer.UserId then continue end 

        return ReplicatedStorage.GearIntermediaries[ownerId][melee:GetAttribute("ReferenceName")]
    end
end)

FarmBase.FarmLoop = LPH_JIT(function(self)
    while true do 
        task.wait()

        local rootPart = Utils.GetRootPart()
        if not rootPart then continue end

        if not self:ShouldContinueFarming() then 
            if rootPart then rootPart.Anchored = false end
            self:ResetPosition()
            continue 
        end

        if not self._originalPosition then
            self._originalPosition = Utils.GetCharacter():GetPivot()
        end

        local entity = self._currentEntity
        if not entity or not entity.Parent or not entity:GetAttribute("IsAlive") then 
            entity = self:GetTargetEntity(rootPart.Position)
            self._currentEntity = entity
        end

        if not entity then 
            task.wait(1)
            continue 
        end

        local shouldContinue = true
        local lastAttackTime = 0
        local attackDelay = 0.1

        self._teleportConnection = RunService.Heartbeat:Connect(LPH_JIT_MAX(function()
            if not shouldContinue then 
                self._teleportConnection:Disconnect()
                return 
            end
            
            if not self:ShouldContinueFarming() then
                shouldContinue = false
                return
            end
            
            if not entity or not entity.Parent or not entity:GetAttribute("IsAlive") then
                shouldContinue = false
                return
            end

            local character = Utils.GetCharacter()
            local root = Utils.GetRootPart()
            if not character or not root then return end

            local success, pivot = pcall(function() return entity:GetPivot() end)
            if not success then
                shouldContinue = false
                return
            end

            character:PivotTo(pivot * CFrame.Angles(-math.pi / 2, 0, 0) + (Vector3.yAxis * (entity:GetExtentsSize().Y + 15)))

            local lookDir = (pivot.Position - root.Position).Unit
            
            local currentTime = os.clock()
            if currentTime - lastAttackTime >= attackDelay then
                lastAttackTime = currentTime
                local melee = self:GetMelee()
                melee.MeleeGear_RemoteComponent.RF.TryDamageEntity:InvokeServer(entity, lookDir)
            end
        end))
        
        while shouldContinue and self:ShouldContinueFarming() do
            if not entity or not entity.Parent or not entity:GetAttribute("IsAlive") then
                break
            end
            task.wait()
        end
        
        shouldContinue = false

        if self._teleportConnection then
            self._teleportConnection:Disconnect()
            self._teleportConnection = nil
        end

        if entity and not entity:GetAttribute("IsAlive") then 
            self._currentEntity = nil
        end
    end
end)

function FarmBase:Init()
    MainTrove:Add(task.spawn(function()
        self:FarmLoop()
    end))
end

local AutoFarmModule = FarmBase.new("AutoFarm")

AutoFarmModule.GetTargetEntity = LPH_JIT(function(self, position)
    if Settings.AutoFarmClosestEnabled then
        return Utils.GetClosestEntity(position)
    else
        return Utils.GetClosestEntity(position, function(entity)
            local refName = entity:GetAttribute("ReferenceName")
            return refName and Settings.SelectedEntities[refName]
        end)
    end
end)

AutoFarmModule.ShouldContinueFarming = LPH_JIT_MAX(function(self)
    return Settings.AutoFarmEnabled or Settings.AutoFarmClosestEnabled
end)
local AutoEatModule = {
    _trove = Trove.new(),
    _isEating = false,
}
MainTrove:Add(AutoEatModule._trove)

AutoEatModule.GetConsumables = LPH_JIT(function(self)
    local consumables = {}
    for _, item in CollectionService:GetTagged("Consumable") do
        if item:GetAttribute("IsRotten") then continue end
        table.insert(consumables, item)
    end
    return consumables
end)

AutoEatModule.FindClosestConsumable = LPH_JIT(function(self)
    local rootPart = Utils.GetRootPart()
    if not rootPart then return nil end
    
    local consumables = self:GetConsumables()
    local closestConsumable = nil
    local closestDistance = math.huge
    
    for _, consumable in consumables do
        local distance = (consumable:GetPivot().Position - rootPart.Position).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestConsumable = consumable
        end
    end
    
    return closestConsumable
end)

AutoEatModule.ConsumeItem = LPH_NO_VIRTUALIZE(function(self, consumable)
    local remote = consumable.Consumable_RemoteComponent.RF.Consume
    remote:InvokeServer()
end)

AutoEatModule.TryEat = LPH_NO_VIRTUALIZE(function(self)
    if self._isEating then return end
    
    local hungerBar = PlayerGui.PlayerAttributesUI.PlayerAttributes.Bars.Hunger
    if not hungerBar.Visible then return end

    local consumable = self:FindClosestConsumable()
    if consumable then
        self._isEating = true
        task.delay(0.5, function()
            self._isEating = false
        end)
        self:ConsumeItem(consumable)
    end
end)

function AutoEatModule:Init()   
    local hungerBar = PlayerGui.PlayerAttributesUI.PlayerAttributes.Bars.Hunger

    self._trove:Connect(hungerBar:GetPropertyChangedSignal("Visible"), function()
        if Settings.AutoEatEnabled then 
            self:TryEat()
        end
    end)   

    self._trove:Connect(hungerBar:GetPropertyChangedSignal("Size"), function()
        if Settings.AutoEatEnabled and hungerBar.Size.Y.Scale > 0.04 then
            self:TryEat()
        end
    end)
end

local AutoCraftModule = {
    _trove = Trove.new(),
    _craftingInProgress = false,
    _farmModule = FarmBase.new("AutoCraft"),
}
MainTrove:Add(AutoCraftModule._trove)

function AutoCraftModule:UpdateStatus(text)
    if Library and Library.Labels and Library.Labels.AutoCraftStatus then
        Library.Labels.AutoCraftStatus:SetText(text)
    end
end

AutoCraftModule.GetRecipeMaterials = LPH_JIT_MAX(function(self, itemName)
    local recipe = CraftingData[itemName]
    return recipe and recipe.Materials
end)

AutoCraftModule.GetByproductValue = LPH_JIT_MAX(function(self, itemName, materialName)
    local itemData = ItemsToolkit.GetItemData(itemName)
    if itemData and itemData.Byproducts and itemData.Byproducts[materialName] then
        return itemData.Byproducts[materialName]
    end
    return 0
end)

AutoCraftModule.GetByproductItems = LPH_JIT(function(self, materialName)
    local byproductItems = {}
    
    for _, item in CollectionService:GetTagged("Interactable") do
        local refName = item:GetAttribute("ReferenceName")
        if refName then
            local byproductValue = self:GetByproductValue(refName, materialName)
            if byproductValue > 0 then
                table.insert(byproductItems, {
                    item = item,
                    value = byproductValue
                })
            end
        end
    end
    
    return byproductItems
end)

AutoCraftModule.GetAvailableMaterialCount = LPH_JIT(function(self, materialName)
    local directMaterials = Utils.GetItemsByName(materialName)
    local totalCount = #directMaterials
    
    local byproductItems = self:GetByproductItems(materialName)
    for _, byproductData in byproductItems do
        totalCount = totalCount + byproductData.value
    end
    
    return totalCount
end)

AutoCraftModule.GetEntityDrops = LPH_JIT(function(self, materialName, checkByproducts)
    local droppingEntities = {}
    
    for entityName, entityData in BackupData.Entities do
        if ResidentData[entityName] then continue end
   
        if entityData and entityData.LootPool then
            for lootName, loot in entityData.LootPool do                
                local matches = false
                
                if not checkByproducts then
                    matches = (lootName == materialName)
                else
                    matches = (self:GetByproductValue(lootName, materialName) > 0)
                end
                
                if matches then
                    table.insert(droppingEntities, entityName)
                    break
                end
            end
        end
    end
    
    return droppingEntities
end)

AutoCraftModule.FindAvailableEntity = LPH_JIT(function(self, materialName)
    local directDroppers = self:GetEntityDrops(materialName, false)
    for _, entityName in directDroppers do
        if Utils.EntityExistsInMap(entityName) then
            return entityName, false
        end
    end
    
    local byproductDroppers = self:GetEntityDrops(materialName, true)
    for _, entityName in byproductDroppers do
        if Utils.EntityExistsInMap(entityName) then
            return entityName, true
        end
    end
    
    return nil, false
end)

AutoCraftModule._farmModule.GetTargetEntity = LPH_JIT(function(self, position)
    if not self._targetEntityName then return nil end
    
    return Utils.GetClosestEntity(position, function(entity)
        local refName = entity:GetAttribute("ReferenceName")
        return refName == self._targetEntityName
    end)
end)

AutoCraftModule._farmModule.ShouldContinueFarming = LPH_JIT_MAX(function(self)
    return self._enabled
end)

function AutoCraftModule._farmModule:StartFarming(entityName)
    self._targetEntityName = entityName
    self:SetEnabled(true)
end

function AutoCraftModule._farmModule:StopFarming()
    self._targetEntityName = nil
    self:SetEnabled(false)
end

function AutoCraftModule:FarmUntilEnough(entityName, targetAmount, materialName)
    self._farmModule:StartFarming(entityName)
    
    self:UpdateStatus(
        "Status: Farming\n" ..
        "Entity: " .. entityName .. "\n" ..
        "Material: " .. materialName .. "\n" ..
        "Target: " .. targetAmount
    )
    
    while Settings.AutoCraftEnabled do
        task.wait(0.5)
        
        local currentAmount = self:GetAvailableMaterialCount(materialName)
        
        self:UpdateStatus(
            "Status: Farming\n" ..
            "Entity: " .. entityName .. "\n" ..
            "Material: " .. materialName .. "\n" ..
            "Progress: " .. currentAmount .. "/" .. targetAmount
        )
        
        if currentAmount >= targetAmount then
            break
        end
        
        if not Utils.EntityExistsInMap(entityName) then
            break
        end
    end
    
    self._farmModule:StopFarming()
    
    task.wait(0.3)

    local character = Utils.GetCharacter()
    local rootPart = Utils.GetRootPart()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    if rootPart then
        rootPart.Velocity = Vector3.zero
        rootPart.RotVelocity = Vector3.zero
        rootPart.Anchored = true
    end
    
    task.wait(0.1)
    
    local targetPart = TeleportLocations.MaterialProcessor
    local forwardOffset = targetPart.CFrame.LookVector * 10
    character:PivotTo(targetPart.CFrame * CFrame.new(forwardOffset) + Vector3.new(0, 5, 0))
    
    task.wait(0.2)
    
    if rootPart then
        rootPart.Anchored = false
    end
    
    if humanoid then
        humanoid.PlatformStand = false
    end
end

AutoCraftModule.BringMaterialsToProcessor = LPH_JIT(function(self, materialName, amount)
    local processorPosition = TeleportLocations.MaterialProcessorCraft.Position
    local brought = 0
    local materialValue = 0
    
    self:UpdateStatus(
        "Status: Collecting Materials\n" ..
        "Material: " .. materialName .. "\n" ..
        "Amount: " .. amount
    )
    
    local directMaterials = Utils.GetItemsByName(materialName)
    for _, item in directMaterials do
        if materialValue >= amount then break end
        
        task.spawn(function()
            local height = item:GetExtentsSize().Y
            local stackHeight = brought * height
            local position = processorPosition + Vector3.new(0, height/2 + stackHeight + 5, 0)
            ItemModule:BringItem(item, position)
        end)
        
        brought = brought + 1
        materialValue = materialValue + 1
    end
    
    if materialValue < amount then
        local byproductItems = self:GetByproductItems(materialName)
        for _, byproductData in byproductItems do
            if materialValue >= amount then break end
            
            task.spawn(function()
                local height = byproductData.item:GetExtentsSize().Y
                local stackHeight = brought * height
                local position = processorPosition + Vector3.new(0, height/2 + stackHeight + 5, 0)
                ItemModule:BringItem(byproductData.item, position)
            end)
            
            brought = brought + 1
            materialValue = materialValue + byproductData.value
        end
    end
    
    return materialValue
end)

AutoCraftModule.GetMaterials = LPH_JIT_MAX(function(self)
    local materials = {}
    for _, material in PlayerGui.CraftingMenu.Main.GenericBackground.Glow.Background.LeftPanel.Resources:GetChildren() do 
        if not material:IsA("Frame") then continue end
        materials[material.Name] = tonumber(material.Amount.Text)
    end
    return materials
end)

AutoCraftModule.GetStock = LPH_JIT_MAX(function(self)
    local stock = {}
    for _, tier in PlayerGui.CraftingMenu.Main.GenericBackground.Glow.Background.LeftPanel.Items:GetChildren() do 
        if not tier:IsA("Frame") then continue end
        for _, item in tier.Items:GetChildren() do 
		    if not item:IsA("ImageButton") then continue end
            stock[item.Name] = tonumber(item.Content.Stock.StockLabel.Text:match("%d+"))
        end
    end
    return stock
end)

AutoCraftModule.GetTier = LPH_JIT_MAX(function(self)
    local highestTier = 0
    for _, tierFrame in PlayerGui.CraftingMenu.Main.GenericBackground.Glow.Background.LeftPanel.Items:GetChildren() do 
        if not tierFrame:IsA("Frame") then continue end    
        local tierNum = tonumber(tierFrame.Name:match("%d+"))
        if not tierNum then continue end   
        for _, item in tierFrame.Items:GetChildren() do 
            if not item:IsA("ImageButton") then continue end       
            local hiddenFrame = item:FindFirstChild("Hidden")
            if hiddenFrame and hiddenFrame.Visible then
                continue
            end        
            local content = item:FindFirstChild("Content")
            if content and content:IsA("CanvasGroup") then
                if content.GroupTransparency == 0 then
                    highestTier = math.max(highestTier, tierNum)
                    break
                end
            end 
        end
    end
    return highestTier
end)

AutoCraftModule.GetCraftingBenchData = LPH_JIT_MAX(function(self)
    return {
        materials = self:GetMaterials(),
        stock = self:GetStock(),
        tier = self:GetTier(),
    }
end)

AutoCraftModule.CanCraftItem = LPH_JIT(function(self, itemName)
    local data = self:GetCraftingBenchData()
    if not data then return false, "No crafting bench data" end

    local recipe = CraftingData[itemName]
    if not recipe then return false, "No recipe found" end

    if data.tier < recipe.Tier then
        return false, "Locked (Requires Tier " .. data.tier .. " bench)"
    end
    
    local stockAmount = data.stock[itemName]
    if stockAmount == nil then
        return true, "∞"
    elseif stockAmount <= 0 then
        return false, "Out of stock"
    end
    
    return true, stockAmount
end)

AutoCraftModule.HasEnoughMaterialsAtBench = LPH_JIT(function(self, itemName)
    local data = self:GetCraftingBenchData()
    if not data then return false end
    
    local recipe = self:GetRecipeMaterials(itemName)
    if not recipe then return false end
    
    for materialName, requiredAmount in recipe do
        local availableAmount = data.materials[materialName] or 0
        if availableAmount < requiredAmount then
            return false, materialName, availableAmount, requiredAmount
        end
    end
    
    return true
end)

AutoCraftModule.CraftItem = LPH_NO_VIRTUALIZE(function(self, itemName)  
    self:UpdateStatus(
        "Status: Crafting\n" ..
        "Item: " .. itemName
    )

    for i = 1, 100 do 
        NetworkEvent:FireServer(
            i,
            "Craft",
            itemName
        )
    end
    
    return true    
end)

AutoCraftModule.CollectExistingItems = LPH_JIT(function(self, materialName)
    local jamItems = Utils.GetItemsByName(materialName)
    if #jamItems > 0 then
        ItemModule:TeleportToProcessor(jamItems, "MaterialProcessor")
        return true
    end
    
    local byproductItems = self:GetByproductItems(materialName)
    if #byproductItems > 0 then
        local items = {}
        for _, data in byproductItems do
            table.insert(items, data.item)
        end
        ItemModule:TeleportToProcessor(items, "MaterialProcessor")
        return true
    end
    
    return false
end)

function AutoCraftModule:HandleMapExpansion()
    self:UpdateStatus(
        "Status: Map Expansion\n" ..
        "Checking for JellyfishJam..."
    )
    
    if self:CollectExistingItems("JellyfishJam") then
        self:UpdateStatus(
            "Status: Map Expansion\n" ..
            "Found JellyfishJam\n" ..
            "Action: Collected"
        )
        task.wait(1)
        return true
    end
    
    local expandEntity, _ = self:FindAvailableEntity("JellyfishJam")
    
    if not expandEntity then
        self:UpdateStatus(
            "Status: Waiting\n" ..
            "Reason: No entities for expansion"
        )
        return false
    end
    
    self:UpdateStatus(
        "Status: Map Expansion\n" ..
        "Farming: " .. expandEntity .. "\n" ..
        "For: JellyfishJam"
    )
    
    self._farmModule:StartFarming(expandEntity)
    
    local farmStartTime = os.clock()
    local maxFarmTime = 30
    
    while Settings.AutoCraftEnabled and (os.clock() - farmStartTime) < maxFarmTime do
        task.wait(0.5)
        
        if self:CollectExistingItems("JellyfishJam") then
            self._farmModule:StopFarming()
            
            task.wait(0.3)

            local character = Utils.GetCharacter()
            local rootPart = Utils.GetRootPart()
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            
            if humanoid then
                humanoid.PlatformStand = true
            end
            
            if rootPart then
                rootPart.Velocity = Vector3.zero
                rootPart.RotVelocity = Vector3.zero
                rootPart.Anchored = true
            end
            
            task.wait(0.1)
            
            local targetPart = TeleportLocations.MaterialProcessor
            local forwardOffset = targetPart.CFrame.LookVector * 10
            character:PivotTo(targetPart.CFrame * CFrame.new(forwardOffset) + Vector3.new(0, 5, 0))
            
            task.wait(0.2)
            
            if rootPart then
                rootPart.Anchored = false
            end
            
            if humanoid then
                humanoid.PlatformStand = false
            end
            
            task.wait(1)
            return true
        end
        
        if not Utils.EntityExistsInMap(expandEntity) then
            break
        end
    end
    
    self._farmModule:StopFarming()
    
    task.wait(0.3)

    local character = Utils.GetCharacter()
    local rootPart = Utils.GetRootPart()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    if rootPart then
        rootPart.Velocity = Vector3.zero
        rootPart.RotVelocity = Vector3.zero
        rootPart.Anchored = true
    end
    
    task.wait(0.1)
    
    local targetPart = TeleportLocations.MaterialProcessor
    local forwardOffset = targetPart.CFrame.LookVector * 10
    character:PivotTo(targetPart.CFrame * CFrame.new(forwardOffset) + Vector3.new(0, 5, 0))
    
    task.wait(0.2)
    
    if rootPart then
        rootPart.Anchored = false
    end
    
    if humanoid then
        humanoid.PlatformStand = false
    end
    
    return false
end

function AutoCraftModule:GatherMissingMaterial(materialName, amountNeeded)
    local entityName, isByproduct = self:FindAvailableEntity(materialName)
    if entityName then
        local dropType = isByproduct and " (byproduct)" or " (direct)"
        self:UpdateStatus(
            "Status: Farming\n" ..
            "Entity: " .. entityName .. "\n" ..
            "Material: " .. materialName .. dropType .. "\n" ..
            "Amount Needed: " .. amountNeeded
        )
        
        self:FarmUntilEnough(entityName, amountNeeded, materialName)
        return true
    else
        self:UpdateStatus(
            "Status: Map Expansion Needed\n" ..
            "Material: " .. materialName .. "\n" ..
            "Reason: No entities available"
        )
        
        return self:HandleMapExpansion()
    end
end

function AutoCraftModule:ProcessCraftingQueue()
    if self._craftingInProgress then return end
    
    self._craftingInProgress = true
    
    for itemName, enabled in Settings.SelectedCraftItems do
        if not enabled or not Settings.AutoCraftEnabled then continue end
        
        local canCraft, stockInfo = self:CanCraftItem(itemName)
        if not canCraft then
            self:UpdateStatus(
                "Status: Skipping\n" ..
                "Item: " .. itemName .. "\n" ..
                "Reason: " .. stockInfo
            )
            continue
        end
        
        local materials = self:GetRecipeMaterials(itemName)
        if not materials then 
            self:UpdateStatus(
                "Status: Error\n" ..
                "Item: " .. itemName .. "\n" ..
                "Reason: No recipe found"
            )
            continue 
        end
        
        if self:HasEnoughMaterialsAtBench(itemName) then
            self:UpdateStatus(
                "Status: Ready to Craft\n" ..
                "Item: " .. itemName .. "\n" ..
                "Materials: At bench"
            )
            
            TeleportModule:TeleportPlayer("MaterialProcessor")
            task.wait(0.3)
            self:CraftItem(itemName)
            task.wait(0.3)
            continue
        end
        
        local benchData = self:GetCraftingBenchData()
        local missingMaterials = {}
        
        for materialName, requiredAmount in materials do
            local atBench = (benchData.materials[materialName] or 0)
            local inWorld = self:GetAvailableMaterialCount(materialName)
            local totalAvailable = atBench + inWorld
            if totalAvailable < requiredAmount then
                missingMaterials[materialName] = requiredAmount - totalAvailable
            end
        end
        
        if not next(missingMaterials) then
            self:UpdateStatus(
                "Status: Collecting Materials\n" ..
                "Item: " .. itemName .. "\n" ..
                "Action: Bringing to processor"
            )
            
            TeleportModule:TeleportPlayer("MaterialProcessor")
            task.wait(0.3)
            
            for materialName, requiredAmount in materials do
                self:BringMaterialsToProcessor(materialName, requiredAmount)
            end
            
            task.wait(0.5)
            self:CraftItem(itemName)
            task.wait(0.3)
        else
            for materialName, amountNeeded in missingMaterials do
                if not Settings.AutoCraftEnabled then break end
                
                self:GatherMissingMaterial(materialName, amountNeeded)
            end
        end
    end
    
    self._craftingInProgress = false
    self:UpdateStatus("Status: Idle\nWaiting for tasks...")
end

function AutoCraftModule:Init()
    self._farmModule:Init()
    
    self._trove:Add(task.spawn(function()
        while true do
            task.wait(0.1)
            if Settings.AutoCraftEnabled then
                self:ProcessCraftingQueue()
            else
                self:UpdateStatus("Status: Disabled")
            end
        end
    end))
end

local ChestModule = {
    _trove = Trove.new(),
    _connections = {},
}
MainTrove:Add(ChestModule._trove)

ChestModule.SetInstantOpen = LPH_NO_VIRTUALIZE(function(self, enabled)
    if enabled then
        for _, chest in CollectionService:GetTagged("Chest") do 
            self:SetChestInstant(chest, true)
        end
    else
        for _, chest in CollectionService:GetTagged("Chest") do 
            self:SetChestInstant(chest, false)
        end
    end
end)

ChestModule.SetChestInstant = LPH_NO_VIRTUALIZE(function(self, chest, enabled)
    local prompt = chest:FindFirstChild("ProximityPrompt", true)
    if not prompt then return end
    
    if enabled then
        if not prompt:GetAttribute("OriginalHoldDuration") then
            prompt:SetAttribute("OriginalHoldDuration", prompt.HoldDuration)
        end
        
        prompt.HoldDuration = 0
        
        if self._connections[chest] then
            self._connections[chest]:Disconnect()
        end
        
        self._connections[chest] = prompt:GetPropertyChangedSignal("HoldDuration"):Connect(function()
            if Settings.InstantOpenChests and prompt.HoldDuration ~= 0 then 
                prompt.HoldDuration = 0
            end
        end)
    else
        local originalDuration = prompt:GetAttribute("OriginalHoldDuration")
        if originalDuration then
            prompt.HoldDuration = originalDuration
            prompt:SetAttribute("OriginalHoldDuration", nil)
        end
        
        if self._connections[chest] then
            self._connections[chest]:Disconnect()
            self._connections[chest] = nil
        end
    end
end)

ChestModule.OpenAllChests = LPH_NO_VIRTUALIZE(function(self)
    for _, chest in CollectionService:GetTagged("Chest") do 
        local prompt = chest:FindFirstChild("ProximityPrompt", true) 
        if not prompt then continue end 

        local pivot = chest:GetPivot()

        local inBounds = Utils.IsInBounds(pivot.Position)
        if not inBounds then continue end 

        local rootPart = Utils.GetRootPart()
        if not rootPart then continue end 

        rootPart.CFrame = pivot + (Vector3.yAxis * (chest:GetExtentsSize().Y))

        task.wait(0.5)

        fireproximityprompt(prompt)

        task.wait(0.5)
    end
end)

function ChestModule:Init()
    for _, chest in CollectionService:GetTagged("Chest") do 
        if Settings.InstantOpenChests then
            self:SetChestInstant(chest, true)
        end
    end
    
    self._trove:Add(CollectionService:GetInstanceAddedSignal("Chest"):Connect(function(chest)
        if Settings.InstantOpenChests then
            self:SetChestInstant(chest, true)
        end
    end))
    
    self._trove:Add(CollectionService:GetInstanceRemovedSignal("Chest"):Connect(function(chest)
        if self._connections[chest] then
            self._connections[chest]:Disconnect()
            self._connections[chest] = nil
        end
    end))
end

local ResidentModule = {}

ResidentModule.GetAllResidents = LPH_JIT(function(self)
    local residents = {}
    for _, resident in CollectionService:GetTagged("Resident") do
        if resident:IsDescendantOf(workspace) then
            table.insert(residents, resident)
        end
    end
    return residents
end)

ResidentModule.GetResidentsByName = LPH_JIT(function(self, residentName)
    local residents = {}
    for _, resident in CollectionService:GetTagged("Resident") do
        if resident:IsDescendantOf(workspace) then
            local refName = resident:GetAttribute("ReferenceName")
            if refName == residentName then
                table.insert(residents, resident)
            end
        end
    end
    return residents
end)

ResidentModule.BringResident = LPH_NO_VIRTUALIZE(function(self, resident, position)    
    if resident.PrimaryPart then 
        resident.PrimaryPart.Anchored = true 
    end

    AttemptDrag:InvokeServer(resident)
    Utils.TweenPivot(resident, CFrame.new(position), 0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    task.wait(1)
    StopDrag:InvokeServer()

    local alignPosition = resident:FindFirstChild("AlignPosition", true)
    local alignOrientation = resident:FindFirstChild("AlignOrientation", true)
    if alignPosition then alignPosition:Destroy() end
    if alignOrientation then alignOrientation:Destroy() end
    
    if resident.PrimaryPart then 
        resident.PrimaryPart.Anchored = false
    end
end)

ResidentModule.BringResidents = LPH_JIT(function(self, residentNames, amount)
    local rootPart = Utils.GetRootPart()
    if not rootPart then return end

    local forwardOffset = 5
    local horizontalSpacing = 6
    local currentIndex = 0

    for residentName in residentNames do
        local residents = self:GetResidentsByName(residentName)

        for i = 1, amount or #residents do
            local resident = residents[i]
            if not resident then break end

            local capturedIndex = currentIndex
            local height = resident:GetExtentsSize().Y
            local position = rootPart.Position 
                + rootPart.CFrame.LookVector * forwardOffset
                + rootPart.CFrame.RightVector * (capturedIndex * horizontalSpacing)
                + Vector3.new(0, height/2, 0)
            
            self:BringResident(resident, position)
            
            currentIndex = currentIndex + 1
        end
    end
end)

ResidentModule.TeleportToProcessor = LPH_JIT(function(self, residents)
    if not TeleportLocations.MaterialProcessor then return end

    local targetPosition = TeleportLocations.MaterialProcessor.Position
    local horizontalSpacing = 6
    local stackOffset = 5

    for index, resident in residents do
        task.spawn(function()
            local height = resident:GetExtentsSize().Y
            local position = targetPosition 
                + Vector3.new(index * horizontalSpacing, height/2 + stackOffset, 0)
            
            self:BringResident(resident, position)
        end)
    end
end)

ResidentModule.TeleportResidentsByName = LPH_JIT(function(self, residentNames)
    local allResidents = {}
    for residentName in residentNames do
        local residents = self:GetResidentsByName(residentName)
        for _, resident in residents do
            table.insert(allResidents, resident)
        end
    end
    self:TeleportToProcessor(allResidents)
end)

local MovementModule = {}

function MovementModule:Init()
    local character = Utils.GetCharacter()
    local rootPart = Utils.GetRootPart()
    
    MainTrove:Add(RunService.Heartbeat:Connect(LPH_JIT_MAX(function()
        local Character = Utils.GetCharacter()
        if not Character then return end
        
        local HumanoidRootPart = Utils.GetRootPart()
        if not HumanoidRootPart then return end
        
        if Settings.Fly.Enabled then
            local LookVector = workspace.CurrentCamera.CFrame.LookVector
            local Direction = Vector3.new()
            
            local Directions = {
                [Enum.KeyCode.W] = LookVector,
                [Enum.KeyCode.A] = Vector3.new(LookVector.Z, 0, -LookVector.X),
                [Enum.KeyCode.S] = -LookVector,
                [Enum.KeyCode.D] = Vector3.new(-LookVector.Z, 0, LookVector.X),
                [Enum.KeyCode.LeftControl] = Vector3.new(0, -1, 0),
                [Enum.KeyCode.LeftShift] = Vector3.new(0, -1, 0),
                [Enum.KeyCode.Space] = Vector3.new(0, 1, 0)
            }
            
            for Key, Dir in Directions do
                if game:GetService("UserInputService"):IsKeyDown(Key) then
                    Direction = Direction + Dir
                end
            end
              
            if Direction.Magnitude > 0 then
                HumanoidRootPart.Velocity = Direction.Unit * Settings.Fly.Speed
                HumanoidRootPart.Anchored = false
            else
                HumanoidRootPart.Velocity = Vector3.new()
                HumanoidRootPart.Anchored = true
            end
        elseif HumanoidRootPart.Anchored then
            HumanoidRootPart.Anchored = false
        end
        
        if not Settings.Fly.Enabled and Settings.WalkSpeed.Enabled then
            local LookVector = workspace.CurrentCamera.CFrame.LookVector
            local Direction = Vector3.new()
        
            local Directions = {
                [Enum.KeyCode.W] = Vector3.new(LookVector.X, 0, LookVector.Z),
                [Enum.KeyCode.A] = Vector3.new(LookVector.Z, 0, -LookVector.X),
                [Enum.KeyCode.S] = -Vector3.new(LookVector.X, 0, LookVector.Z),
                [Enum.KeyCode.D] = Vector3.new(-LookVector.Z, 0, LookVector.X)
            }
        
            for Key, Dir in Directions do
                if game:GetService("UserInputService"):IsKeyDown(Key) then
                    Direction = Direction + Dir
                end
            end
        
            if Direction.Magnitude > 0 then
                HumanoidRootPart.Velocity = Direction.Unit * Settings.WalkSpeed.Speed + Vector3.new(0, HumanoidRootPart.Velocity.Y, 0)
            end 
        end
    end)))

    MainTrove:Add(function()
        local HumanoidRootPart = Utils.GetRootPart()
        if not HumanoidRootPart then return end

        HumanoidRootPart.Anchored = false
    end)
end

do 
    AutoFarmModule:Init()
    AutoEatModule:Init()
    AutoCraftModule:Init()
    MovementModule:Init()
    ChestModule:Init() 
end 

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "",
    Footer = "version: 1.0.0",
})

local Tabs = {
	Main = Window:AddTab("Main", "user"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local CreditsGroupBox = Tabs.Main:AddLeftGroupbox("Credits", "info")

CreditsGroupBox:AddLabel("Developer: Killa0731", false)

local EntityGroupBox = Tabs.Main:AddLeftGroupbox("Entity", "boxes")

EntityGroupBox:AddToggle("AutoFarmEnabled", {
    Text = "Auto Kill Selected",
    Tooltip = "Automatically kill selected entities",
    Default = false,
    
    Callback = function(Value)
        Settings.AutoFarmEnabled = Value
        if Value then
            Settings.AutoFarmClosestEnabled = false
            Toggles.AutoFarmClosestEnabled:SetValue(false)
        end
    end,
})

EntityGroupBox:AddToggle("AutoFarmClosestEnabled", {
    Text = "Auto Kill Closest",
    Tooltip = "Automatically kill closest entity (any type)",
    Default = false,
    
    Callback = function(Value)
        Settings.AutoFarmClosestEnabled = Value
        if Value then
            Settings.AutoFarmEnabled = false
            Toggles.AutoFarmEnabled:SetValue(false)
        end
    end,
})

local GetEntities = LPH_JIT_MAX(function()
    local entities = {}
    
    for entityName in BackupData.Entities do
        table.insert(entities, entityName)
    end
    
    table.sort(entities)
    return entities
end)

EntityGroupBox:AddDropdown("EntityDropdown", {
    Values = GetEntities(),
    Default = 1,
    Multi = true,
    Text = "Select Entities to Farm",
    Tooltip = "Choose which entities to auto farm",
    Searchable = true,
    
    Callback = function(Value)
        Settings.SelectedEntities = {}
        for entityName, isSelected in Value do
            if isSelected then
                Settings.SelectedEntities[entityName] = true
            end
        end
    end,
})

local list = {}
for _, v in Settings.SelectedEntities do
    list[v] = true 
end
Options.EntityDropdown:SetValue(list)

local ItemsGroupBox = Tabs.Main:AddRightGroupbox("Items", "boxes")

local GetItems = LPH_JIT_MAX(function()
    local items = {}
    
    for _, itemData in ItemsToolkit.GetAllItems() do
        table.insert(items, itemData.ReferenceName)
    end
    
    table.sort(items)
    return items
end)

ItemsGroupBox:AddDropdown("ItemDropdown", {
    Values = GetItems(),
    Default = 1,
    Multi = true,
    Text = "Select Items to Bring",
    Tooltip = "Choose which items to bring",
    Searchable = true,
    
    Callback = function(Value)
        Settings.SelectedBring = Value
    end,
})

Options.ItemDropdown:SetValue(Settings.SelectedBring)

ItemsGroupBox:AddButton({
	Text = "Select All",
	Func = function()
        local allItems = {}
        for _, itemName in GetItems() do
            allItems[itemName] = true
        end
        Options.ItemDropdown:SetValue(allItems)
    end,
	Tooltip = "Select all items in dropdown",
})

ItemsGroupBox:AddButton({
	Text = "Reset",
	Func = function()
        Options.ItemDropdown:SetValue({})
    end,
	Tooltip = "Deselect all items",
})

ItemsGroupBox:AddButton({
	Text = "Bring All Selected",
	Func = function()
        ItemModule:BringItems(Settings.SelectedBring)
    end,
	Tooltip = "Bring the selected items",
})

ItemsGroupBox:AddButton({
	Text = "TP Items to Processor",
	Func = function()
        local selectedItems = Options.ItemDropdown.Value
        if selectedItems and next(selectedItems) then
            ItemModule:TeleportItemsByName(selectedItems, "MaterialProcessor")
        end
    end,
	Tooltip = "Teleport selected items to Material Processor",
})

local ResidentGroupBox = Tabs.Main:AddRightGroupbox("Residents", "users")

local GetResidents = LPH_JIT_MAX(function()
    local residents = {}
    
    for _, residentData in ResidentData do
        table.insert(residents, residentData.ReferenceName)
    end
    
    table.sort(residents)
    return residents
end)

ResidentGroupBox:AddDropdown("ResidentDropdown", {
    Values = GetResidents(),
    Default = 1,
    Multi = true,
    Text = "Select Residents",
    Tooltip = "Choose which residents to bring",
    Searchable = true,
    
    Callback = function(Value)
        Settings.SelectedResidents = Value
    end,
})

Settings.SelectedResidents = Settings.SelectedResidents or {}
Options.ResidentDropdown:SetValue(Settings.SelectedResidents)

ResidentGroupBox:AddButton({
    Text = "Select All",
    Func = function()
        local allResidents = {}
        for _, residentName in GetResidents() do
            allResidents[residentName] = true
        end
        Options.ResidentDropdown:SetValue(allResidents)
    end,
    Tooltip = "Select all residents in dropdown",
})

ResidentGroupBox:AddButton({
    Text = "Reset",
    Func = function()
        Options.ResidentDropdown:SetValue({})
    end,
    Tooltip = "Deselect all residents",
})

ResidentGroupBox:AddButton({
    Text = "Bring All Selected",
    Func = function()
        ResidentModule:BringResidents(Settings.SelectedResidents)
    end,
    Tooltip = "Bring the selected residents",
})

ResidentGroupBox:AddButton({
    Text = "TP Residents to Processor",
    Func = function()
        local selectedResidents = Options.ResidentDropdown.Value
        if selectedResidents and next(selectedResidents) then
            ResidentModule:TeleportResidentsByName(selectedResidents)
        end
    end,
    Tooltip = "Teleport selected residents to Material Processor",
})

ResidentGroupBox:AddLabel("SecondTestLabel", {
	Text = "To bring sandy you need to kill hibernation sandy first",
	DoesWrap = true,
})

local TeleportGroupBox = Tabs.Main:AddLeftGroupbox("Teleport", "locate-fixed")

TeleportGroupBox:AddButton({
	Text = "TP Material Processor",
	Func = function()
        TeleportModule:TeleportPlayer("MaterialProcessor")
    end,
	Tooltip = "Teleport to Material Processor",
})

local MiscGroupBox = Tabs.Main:AddRightGroupbox("Misc", "settings")

MiscGroupBox:AddToggle("AutoEatEnabled", {
    Text = "Auto Eat",
    Tooltip = "Automatically eat consumables when health is low",
    Default = false,
    
    Callback = function(Value)
        Settings.AutoEatEnabled = Value
        
        if Value and PlayerGui.PlayerAttributesUI.PlayerAttributes.Bars.Hunger.Visible then
            AutoEatModule:TryEat()
        end
    end,
})

MiscGroupBox:AddToggle("InstantOpenChests", {
    Text = "Instant Open Chests",
    Tooltip = "Remove hold duration from all chests",
    Default = false,
    
    Callback = function(Value)
        Settings.InstantOpenChests = Value
        ChestModule:SetInstantOpen(Value)
    end,
})

--[[
local StatisticsGroupBox = Tabs.Main:AddRightGroupbox("Statistics", "chart-column")

StatisticsGroupBox:AddLabel("Loading...", true, "StatsDisplay")

local UpdateStatistics = LPH_NO_VIRTUALIZE(function()
    local statsManager = PlayerDataController:GetManager("Statistics")
    if not statsManager then 
        if Library.Labels.StatsDisplay then
            Library.Labels.StatsDisplay:SetText("Statistics unavailable")
        end
        return 
    end
    
    local stats = {
        DaysSurvived = statsManager:Get("DaysSurvived") or 0,
        BestDaysSurvived = statsManager:Get("BestDaysSurvived") or 0,
        StrongholdsCleared = statsManager:Get("StrongholdsCleared") or 0,
        DutchmanBargains = statsManager:Get("DutchmanBargainsAccepted") or 0,
        FoodCrafted = statsManager:Get("FoodCrafted") or 0,
        FastestRescue = statsManager:Get("FastestRescueTime") or -1,
    }
    
    local entitiesKilled = statsManager:Get("EntitiesKilled") or {}
    local totalKills = 0
    for _, count in pairs(entitiesKilled) do
        totalKills = totalKills + count
    end
    
    local fastestRescueText = stats.FastestRescue == -1 and "N/A" or string.format("%.1fs", stats.FastestRescue)
    
    local statsText = string.format(
        "Days Survived: %d\n" ..
        "Best Run: %d days\n" ..
        "Total Kills: %d\n" ..
        "Strongholds Cleared: %d\n" ..
        "Dutchman Bargains: %d\n" ..
        "Food Crafted: %d\n" ..
        "Fastest Rescue: %s",
        stats.DaysSurvived,
        stats.BestDaysSurvived,
        totalKills,
        stats.StrongholdsCleared,
        stats.DutchmanBargains,
        stats.FoodCrafted,
        fastestRescueText
    )
    
    if Library.Labels.StatsDisplay then
        Library.Labels.StatsDisplay:SetText(statsText)
    end
end)

StatisticsGroupBox:AddButton({
    Text = "Refresh Stats",
    Func = function()
        UpdateStatistics()
    end,
    Tooltip = "Refresh statistics display",
})

MainTrove:Add(task.spawn(function()
    task.wait(1)
    
    local statsManager = PlayerDataController:GetManager("Statistics")
    if statsManager then
        UpdateStatistics()
        
        local statsToObserve = {
            "DaysSurvived",
            "BestDaysSurvived",
            "StrongholdsCleared",
            "DutchmanBargainsAccepted",
            "FoodCrafted",
            "FastestRescueTime",
            "EntitiesKilled"
        }
        
        for _, statName in statsToObserve do
            MainTrove:Add(statsManager:Observe(statName, function()
                setthreadidentity(8)
                UpdateStatistics()
            end))
        end
    end
end))
--]]

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})

local CraftingGroupBox = Tabs.Main:AddLeftGroupbox("Crafting", "hammer")

CraftingGroupBox:AddLabel("Status: Idle", true, "AutoCraftStatus")

CraftingGroupBox:AddToggle("AutoCraftEnabled", {
    Text = "Auto Craft",
    Tooltip = "Automatically gather materials and craft items",
    Default = false,
    
    Callback = function(Value)
        Settings.AutoCraftEnabled = Value
    end,
})

local GetCraftableItems = LPH_JIT_MAX(function()
    local items = {}
    
    for itemName in CraftingData do
        table.insert(items, itemName)
    end
    
    table.sort(items)
    return items
end)

CraftingGroupBox:AddDropdown("CraftItemDropdown", {
    Values = GetCraftableItems(),
    Multi = true,
    Text = "Select Items to Craft",
    Tooltip = "Choose which items to auto craft",
    Searchable = true,
    
    Callback = function(Value)
        Settings.SelectedCraftItems = Value
    end,
})

local MovementGroupBox = Tabs.Main:AddLeftGroupbox("Movement", "move")

MovementGroupBox:AddToggle("FlyEnabled", {
    Text = "Fly",
    Tooltip = "Enables fly mode with WASD controls",
    Default = false,
    
    Callback = function(Value)
        Settings.Fly.Enabled = Value
        if Value then
            Settings.WalkSpeed.Enabled = false
            Toggles.WalkSpeedEnabled:SetValue(false)
        end
    end,
})

MovementGroupBox:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Compact = false,
    
    Callback = function(Value)
        Settings.Fly.Speed = Value
    end,
})

MovementGroupBox:AddToggle("WalkSpeedEnabled", {
    Text = "Walk Speed",
    Tooltip = "Modifies walk speed",
    Default = false,
    
    Callback = function(Value)
        Settings.WalkSpeed.Enabled = Value
        if Value then
            Settings.Fly.Enabled = false
            Toggles.FlyEnabled:SetValue(false)
        end
    end,
})

MovementGroupBox:AddSlider("WalkSpeedValue", {
    Text = "Walk Speed",
    Default = 50,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Compact = false,
    
    Callback = function(Value)
        Settings.WalkSpeed.Speed = Value
    end,
})

MenuGroup:AddDivider()

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { 
    Default = "RightShift", 
    NoUI = true, 
    Text = "Menu keybind" 
})

MenuGroup:AddButton("Unload", function()
    getgenv().executed = false
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    MainTrove:Clean()
end)

Library:Notify({
    Title = "Script loaded!",
    Description = "Sucessfully loaded script",
    Time = 5,
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("AutoFarmScript")
SaveManager:SetFolder("AutoFarmScript/configs")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()
