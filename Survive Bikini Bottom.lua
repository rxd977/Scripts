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

repeat
    task.wait()
until not PlayerGui:FindFirstChild("TeleportScreen")

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

--[=[
--[[ FULL DATA DUMPER | UPDATED WITH ENTITY DATA ]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncodingService = game:FindService("EncodingService")

local DumperModule = {}

----------------------------------------------------------------
-- ULTRA COMPACT SERIALIZER
----------------------------------------------------------------
local function tableToUltraCompactString(tbl, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if seen[tbl] then
        return '"[Circular]"'
    end
    seen[tbl] = true

    local result = "{"
    local items = {}
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

    local function serializeValue(value, seenCopy)
        local t = type(value)
        local tv = typeof(value)

        if t == "table" then
            return tableToUltraCompactString(value, depth + 1, table.clone(seenCopy))
        elseif t == "string" then
            return '"' .. value:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
        elseif t == "boolean" or t == "number" then
            return tostring(value)
        elseif t == "nil" then
            return "nil"
        elseif tv == "Instance" then
            return '"' .. value:GetFullName() .. '"'
        elseif tv == "Vector2" then
            return "Vector2.new(" .. value.X .. "," .. value.Y .. ")"
        elseif tv == "Vector3" then
            return "Vector3.new(" .. value.X .. "," .. value.Y .. "," .. value.Z .. ")"
        elseif tv == "NumberRange" then
            return "NumberRange.new(" .. value.Min .. "," .. value.Max .. ")"
        else
            return '"' .. tostring(value) .. '"'
        end
    end

    for _, key in ipairs(numericKeys) do
        local value = tbl[key]
        table.insert(items, "[" .. key .. "]=" .. serializeValue(value, seen))
    end

    for _, key in ipairs(stringKeys) do
        local value = tbl[key]
        local prefix =
            key:match("^[%a_][%w_]*$") and (key .. "=")
            or ('["' .. key:gsub('"', '\\"') .. '"]=')

        table.insert(items, prefix .. serializeValue(value, seen))
    end

    result = result .. table.concat(items, ",") .. "}"
    return result
end

----------------------------------------------------------------
-- ITEM DATA
----------------------------------------------------------------
function DumperModule.DumpItemData()
    local possiblePaths = {
        "src.Shared.Items.ItemData",
        "src.Shared.ItemData",
        "Shared.Items.ItemData"
    }

    local ItemDataPath

    for _, path in ipairs(possiblePaths) do
        local current = ReplicatedStorage
        local success = true
        for segment in path:gmatch("[^.]+") do
            current = current:FindFirstChild(segment)
            if not current then success = false break end
        end
        if success and current then
            ItemDataPath = current
            break
        end
    end

    if not ItemDataPath then
        warn("ItemData not found")
        return nil
    end

    local AllItems = {}

    for _, category in ipairs(ItemDataPath:GetChildren()) do
        if category:IsA("ModuleScript") or category:IsA("Folder") then
            AllItems[category.Name] = {}

            for _, itemModule in ipairs(category:GetChildren()) do
                if itemModule:IsA("ModuleScript") then
                    local ok, itemData = pcall(require, itemModule)
                    if ok and type(itemData) == "table" then
                        AllItems[category.Name][itemModule.Name] = table.clone(itemData)
                    end
                end
            end
        end
    end

    return AllItems
end

----------------------------------------------------------------
-- RESIDENT DATA
----------------------------------------------------------------
function DumperModule.DumpResidentData()
    local possiblePaths = {
        "src.Shared.Residents.ResidentData",
        "src.Shared.ResidentData",
        "Shared.Residents.ResidentData"
    }

    local folder

    for _, path in ipairs(possiblePaths) do
        local current = ReplicatedStorage
        local success = true
        for segment in path:gmatch("[^.]+") do
            current = current:FindFirstChild(segment)
            if not current then success = false break end
        end
        if success and current then
            folder = current
            break
        end
    end

    if not folder then
        warn("ResidentData not found")
        return nil
    end

    local all = {}

    for _, module in ipairs(folder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, data = pcall(require, module)
            if ok and data.ReferenceName then
                all[data.ReferenceName] = table.clone(data)
            end
        end
    end

    return all
end

----------------------------------------------------------------
-- ENTITY DATA (NEW)
----------------------------------------------------------------
function DumperModule.DumpEntityData()
    local possiblePaths = {
        "src.Shared.Entities.EntityData",
        "src.Shared.EntityData",
        "Shared.Entities.EntityData"
    }

    local folder

    for _, path in ipairs(possiblePaths) do
        local current = ReplicatedStorage
        local success = true
        for segment in path:gmatch("[^.]+") do
            current = current:FindFirstChild(segment)
            if not current then success = false break end
        end
        if success and current then
            folder = current
            break
        end
    end

    if not folder then
        warn("EntityData not found")
        return nil
    end

    local all = {}

    for _, module in ipairs(folder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, data = pcall(require, module)
            if ok and type(data) == "table" then
                local ref =
                    data.ReferenceName
                    or string.split(module.Name, "_")[2]
                    or module.Name

                all[ref] = table.clone(data)
            end
        end
    end

    return all
end

----------------------------------------------------------------
-- MAP GENERATION CONFIG
----------------------------------------------------------------
function DumperModule.DumpMapGenerationConfig()
    local possiblePaths = {
        "src.Shared.MapGeneration.MapGenerationConfig",
        "src.Shared.Map.MapGenerationConfig",
        "src.Shared.MapGenerationConfig",
        "Shared.MapGeneration.MapGenerationConfig",
        "Shared.Map.MapGenerationConfig"
    }

    for _, path in ipairs(possiblePaths) do
        local current = ReplicatedStorage
        local success = true
        for segment in path:gmatch("[^.]+") do
            current = current:FindFirstChild(segment)
            if not current then success = false break end
        end
        if success and current and current:IsA("ModuleScript") then
            local ok, data = pcall(require, current)
            if ok then return data end
        end
    end

    warn("MapGenerationConfig not found")
    return nil
end

----------------------------------------------------------------
-- CRAFTING DATA (FIXED)
----------------------------------------------------------------
function DumperModule.DumpCraftingData()
    local possiblePaths = {
        "src.Shared.Crafting.CraftingRecipes",
        "src.Shared.Crafting.CraftingData",
        "src.Shared.CraftingRecipes",
        "src.Shared.CraftingData",
        "Shared.Crafting.CraftingRecipes",
        "Shared.Crafting.CraftingData"
    }

    for _, path in ipairs(possiblePaths) do
        local current = ReplicatedStorage
        local success = true
        for segment in path:gmatch("[^.]+") do
            current = current:FindFirstChild(segment)
            if not current then success = false break end
        end

        if success and current and current:IsA("ModuleScript") then
            local ok, rawData = pcall(require, current)
            if ok and type(rawData) == "table" then
                local craftingData = {}

                for tier, recipes in pairs(rawData) do
                    if type(recipes) == "table" then
                        for _, recipe in ipairs(recipes) do
                            if recipe.ReferenceName then
                                craftingData[recipe.ReferenceName] = {
                                    Tier = tier,
                                    Stock = recipe.Stock,
                                    Materials = recipe.Materials
                                }
                            end
                        end
                    end
                end

                return craftingData
            end
        end
    end

    warn("CraftingData not found")
    return nil
end

----------------------------------------------------------------
-- MASTER DUMP
----------------------------------------------------------------
function DumperModule.DumpAllData()
    print("=== Dumping Data ===")

    local allData = {
        ItemData = DumperModule.DumpItemData(),
        ResidentData = DumperModule.DumpResidentData(),
        EntityData = DumperModule.DumpEntityData(),
        MapGenerationConfig = DumperModule.DumpMapGenerationConfig(),
        CraftingData = DumperModule.DumpCraftingData()
    }

    local output =
        "-- Auto-generated | " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"

    if allData.MapGenerationConfig then
        output ..= "local MapGenerationConfig=" ..
            tableToUltraCompactString(allData.MapGenerationConfig) .. "\n"
    end
    if allData.CraftingData then
        output ..= "local CraftingData=" ..
            tableToUltraCompactString(allData.CraftingData) .. "\n"
    end
    if allData.ItemData then
        output ..= "local ItemData=" ..
            tableToUltraCompactString(allData.ItemData) .. "\n"
    end
    if allData.ResidentData then
        output ..= "local ResidentData=" ..
            tableToUltraCompactString(allData.ResidentData) .. "\n"
    end
    if allData.EntityData then
        output ..= "local EntityData=" ..
            tableToUltraCompactString(allData.EntityData) .. "\n"
    end

    if setclipboard then
        setclipboard(output)
        print("=== Complete - Copied to clipboard ===")
    else
        warn("Clipboard unavailable")
    end

    return output
end

----------------------------------------------------------------
-- RUN
----------------------------------------------------------------
DumperModule.DumpAllData()
--]=]

local Data = loadstring(game:HttpGet("https://raw.githubusercontent.com/de4323/Scripts/refs/heads/main/BikiniBottom/Data.lua"))()

local MapGenerationConfig = Data.MapGenerationConfig
local CraftingData = Data.CraftingData
local ItemData = Data.ItemData
local ResidentData = Data.ResidentData
local EntityData = Data.EntityData

local BackupData = LPH_JIT_MAX(function()
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
end)()

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
    SelectedEntities = {},
    YOffset = 50,
    XOffset = 10,
    
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
        
        local entityData = BackupData.Entities[refName]
        if not entityData then continue end

        if Utils.IsEntityImmune(refName) then continue end

        if filterFunc and not filterFunc(entity) then continue end

        local magnitude = (position - entity:GetPivot().Position).Magnitude 
        if magnitude < lowestMagnitude then 
            closestEntity = entity 
            lowestMagnitude = magnitude
        end
    end

    return closestEntity
end)

Utils.IsEntityImmune = LPH_JIT_MAX(function(refName)
    local entityData = EntityData[refName]
    if entityData and entityData.Metadata and entityData.Metadata.ImmuneToDamage ~= nil then
        return entityData.Metadata.ImmuneToDamage
    end
    return false
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

ItemModule.TeleportToProcessor = LPH_JIT(function(self, items, processorType, dontStack)
    processorType = processorType or "MaterialProcessor"
    
    if not TeleportLocations[processorType] then return end

    local targetPosition = TeleportLocations[processorType].Position
    local totalHeight = 0
    local stackOffset = 5

    for _, item in items do
        task.spawn(function()
            local height = item:GetExtentsSize().Y
            local position = targetPosition + Vector3.new(0, height/2 + totalHeight + stackOffset, 0)
            if not dontStack then 
            totalHeight += height
            end
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

        return ReplicatedStorage.GearIntermediaries[tostring(ownerId)][melee:GetAttribute("ReferenceName")]
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

            character:PivotTo(pivot * CFrame.Angles(-math.pi / 2, 0, 0) + (Vector3.new(Settings.XOffset, entity:GetExtentsSize().Y + Settings.YOffset, 0)))

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
        print(text)
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
        if Utils.IsEntityImmune(entityName) then continue end
   
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
            task.spawn(function()
                local resident = residents[i]
                if not resident then return end

                local capturedIndex = currentIndex
                local height = resident:GetExtentsSize().Y
                local position = rootPart.Position 
                    + rootPart.CFrame.LookVector * forwardOffset
                    + rootPart.CFrame.RightVector * (capturedIndex * horizontalSpacing)
                    + Vector3.new(0, height/2, 0)
                
                self:BringResident(resident, position)
                
                currentIndex = currentIndex + 1
            end)
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

local KillAuraModule = {
    _trove = Trove.new(),
    _enabled = false,
}
MainTrove:Add(KillAuraModule._trove)

KillAuraModule.GetMelee = LPH_NO_VIRTUALIZE(function(self)
    for _, melee in CollectionService:GetTagged("MeleeGear") do
        local ownerId = melee:GetAttribute("OwnerId")
        if ownerId ~= LocalPlayer.UserId then continue end 

        return ReplicatedStorage.GearIntermediaries[tostring(ownerId)][melee:GetAttribute("ReferenceName")]
    end
end)

KillAuraModule.GetEntitiesInRange = LPH_JIT(function(self, character, range)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then
        return {}
    end
    
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.CollisionGroup = "Default"
    overlapParams:AddToFilter(character)
    
    local parts = workspace:GetPartBoundsInRadius(rootPart.Position, range, overlapParams)
    
    local entities = {}
    local seenEntities = {}
    
    for _, part in parts do
        local current = part.Parent
        local entity = nil
        
        for i = 1, 3 do
            if not current then break end
            
            if CollectionService:HasTag(current, "Entity") then
                entity = current
                break
            end
            
            current = current.Parent
        end
        
        if entity and not seenEntities[entity] then
            seenEntities[entity] = true
            
            if not Utils.IsInBounds(entity:GetPivot().Position) then continue end
            if not entity:GetAttribute("IsAlive") then continue end

            local refName = entity:GetAttribute("ReferenceName")
            local entityData = EntityData[refName]       
            if not entityData then continue end

            if Utils.IsEntityImmune(refName) then continue end

            table.insert(entities, entity)
        end
    end
    
    return entities
end)

KillAuraModule.KillAuraLoop = LPH_JIT(function(self)
    local lastAttackTime = 0
    local attackDelay = 0
    
    while true do 
        task.wait()

        if not self._enabled then 
            task.wait(0.5)
            continue 
        end

        local character = Utils.GetCharacter()
        local rootPart = Utils.GetRootPart()
        if not (character and rootPart) then continue end

        local melee = self:GetMelee()
        if not melee then continue end

        local range = melee:GetAttribute("MeleeRange") or 12
        local entities = self:GetEntitiesInRange(character, range)

        if #entities == 0 then continue end

        local currentTime = os.clock()
        if currentTime - lastAttackTime < attackDelay then continue end
        
        lastAttackTime = currentTime

        for _, entity in entities do
            if not entity or not entity.Parent or not entity:GetAttribute("IsAlive") then continue end
            
            local success, pivot = pcall(function() return entity:GetPivot() end)
            if not success then continue end

            local lookDir = (pivot.Position - rootPart.Position).Unit
            
            melee.MeleeGear_RemoteComponent.RF.TryDamageEntity:InvokeServer(entity, lookDir)
        end
    end
end)

function KillAuraModule:Init()
    self._trove:Add(task.spawn(function()
        self:KillAuraLoop()
    end))
end

local HiveModule = {
    _enabled = false,
    _currentEntity = nil,
    _originalPosition = nil,
    _teleportConnection = nil,
    _targetEntityNames = {},
}

HiveModule.GetCurrentLevel = LPH_JIT_MAX(function(self)
    return Utils.GetLightSourceLevel()
end)

HiveModule.GetMaxLevel = LPH_JIT_MAX(function(self)
    return #MapGenerationConfig.Levels
end)

HiveModule._targetLevel = HiveModule.GetMaxLevel(HiveModule)

HiveModule.GetMelee = LPH_NO_VIRTUALIZE(function(self)
    for _, melee in CollectionService:GetTagged("MeleeGear") do
        local ownerId = melee:GetAttribute("OwnerId")
        if ownerId ~= LocalPlayer.UserId then continue end 

        return ReplicatedStorage.GearIntermediaries[tostring(ownerId)][melee:GetAttribute("ReferenceName")]
    end
end)

HiveModule.ResetPosition = LPH_NO_VIRTUALIZE(function(self)
    if self._originalPosition then
        local character = Utils.GetCharacter()
        if character then
            character:PivotTo(self._originalPosition)
        end
        self._originalPosition = nil
    end
end)

HiveModule.GetByproductValue = LPH_JIT_MAX(function(self, itemName, materialName)
    local itemData = ItemsToolkit.GetItemData(itemName)
    if itemData and itemData.Byproducts and itemData.Byproducts[materialName] then
        return itemData.Byproducts[materialName]
    end
    return 0
end)

HiveModule.ParseAmount = LPH_JIT_MAX(function(self, amount)
    local amountType = typeof(amount)
    
    if amountType == "number" then
        return amount
    elseif amountType == "string" then
        local min, max = amount:match("(%d+)%-(%d+)")
        if min and max then
            return (tonumber(min) + tonumber(max)) / 2
        end

        local num = tonumber(amount)
        if num then
            return num
        end
    end
    
    return 0
end)

HiveModule.CalculateEntityYield = LPH_JIT(function(self, entityName)
    local entityData = BackupData.Entities[entityName]
    if not entityData or not entityData.LootPool then
        return 0
    end
    
    local totalYield = 0
    
    for lootName, lootData in entityData.LootPool do
        local amount = self:ParseAmount(lootData.Amount)
        local chance = lootData.Chance or 1
        
        if lootName == "JellyfishJam" then
            totalYield = totalYield + (amount * chance)
        else
            local byproductValue = self:GetByproductValue(lootName, "JellyfishJam")
            if byproductValue > 0 then
                totalYield = totalYield + (amount * chance * byproductValue)
            end
        end
    end
    
    return totalYield
end)

HiveModule.FindTargetEntities = LPH_JIT(function(self)
    local entityYields = {}
    
    for entityName, entityData in BackupData.Entities do
        if Utils.IsEntityImmune(entityName) then continue end
        
        local yield = self:CalculateEntityYield(entityName)
        if yield > 0 then
            table.insert(entityYields, {
                name = entityName,
                yield = yield
            })
        end
    end
    
    table.sort(entityYields, function(a, b)
        return a.yield > b.yield
    end)
    
    local sortedNames = {}
    for _, data in entityYields do
        table.insert(sortedNames, data.name)
    end
    
    return sortedNames, entityYields
end)

HiveModule.GetClosestTargetEntity = LPH_JIT(function(self, position)
    local targetEntityNames, entityYields = self:FindTargetEntities()
    
    local yieldMap = {}
    for _, data in entityYields do
        yieldMap[data.name] = data.yield
    end
    
    local bestEntity = nil
    local highestYield = -1
    local closestDistance = math.huge
    
    for _, entity in CollectionService:GetTagged("Entity") do 
        if not Utils.IsInBounds(entity:GetPivot().Position) then continue end
        if not entity:GetAttribute("IsAlive") then continue end

        local refName = entity:GetAttribute("ReferenceName")
        
        if not table.find(targetEntityNames, refName) then continue end
        
        local entityData = BackupData.Entities[refName]
        if not entityData then continue end

        if Utils.IsEntityImmune(refName) then continue end

        local distance = (position - entity:GetPivot().Position).Magnitude
        local yield = yieldMap[refName] or 0
        
        if yield > highestYield or (yield == highestYield and distance < closestDistance) then
            bestEntity = entity
            highestYield = yield
            closestDistance = distance
        end
    end

    return bestEntity
end)

HiveModule.CollectAndBringJam = LPH_JIT(function(self)
    local jamItems = Utils.GetItemsByName("JellyfishJam")
    
    for _, item in CollectionService:GetTagged("Interactable") do
        local refName = item:GetAttribute("ReferenceName")
        if refName and self:GetByproductValue(refName, "JellyfishJam") > 0 then
            table.insert(jamItems, item)
        end
    end
    
    if #jamItems > 0 then
        ItemModule:TeleportToProcessor(jamItems, "MaterialProcessor", true)
        return true
    end
    return false
end)

HiveModule.FarmLoop = LPH_JIT(function(self)
    while true do 
        task.wait()

        local rootPart = Utils.GetRootPart()
        if not rootPart then continue end

        local currentLevel = self:GetCurrentLevel()
        if currentLevel >= self:GetMaxLevel() then
            continue
        end

        if not self._enabled then 
            self:ResetPosition()
            continue 
        end

        if not self._originalPosition then
            self._originalPosition = Utils.GetCharacter():GetPivot()
        end

        local entity = self:GetClosestTargetEntity(rootPart.Position)
        self._currentEntity = entity

        if not entity then 
            task.wait(2)
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
            
            if not self._enabled then
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

            character:PivotTo(pivot * CFrame.Angles(-math.pi / 2, 0, 0) + (Vector3.new(Settings.XOffset, entity:GetExtentsSize().Y + Settings.YOffset, 0)))

            local lookDir = (pivot.Position - root.Position).Unit
            
            local currentTime = os.clock()
            if currentTime - lastAttackTime >= attackDelay then
                lastAttackTime = currentTime
                local melee = self:GetMelee()
                if melee then
                    melee.MeleeGear_RemoteComponent.RF.TryDamageEntity:InvokeServer(entity, lookDir)
                end
            end
        end))
        
        while shouldContinue and self._enabled do
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
            TeleportModule:TeleportPlayer("MaterialProcessor")
            self:CollectAndBringJam()
            
            self._currentEntity = nil
            
            task.wait(0.5)
        end
    end
end)

function HiveModule:Init()
    MainTrove:Add(task.spawn(function()
        self:FarmLoop()
    end))
end
do 
    AutoFarmModule:Init()
    AutoEatModule:Init()
    AutoCraftModule:Init()
    MovementModule:Init()
    ChestModule:Init() 
    KillAuraModule:Init()
    HiveModule:Init()
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

local EntityGroupBox = Tabs.Main:AddLeftGroupbox("Entity", "boxes")

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

EntityGroupBox:AddToggle("KillAuraEnabled", {
    Text = "Kill Aura",
    Tooltip = "Automatically attack all entities within weapon range",
    Default = false,
    
    Callback = function(Value)
        KillAuraModule._enabled = Value
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

EntityGroupBox:AddSlider("YOffsetSlider", {
    Text = "YOffset",
    Default = Settings.YOffset,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.YOffset = Value
    end,
})

EntityGroupBox:AddSlider("XOffsetSlider", {
    Text = "XOffset",
    Default = Settings.XOffset,
    Min = 0,
    Max = 10,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.XOffset = Value
    end,
})

local HiveGroupBox = Tabs.Main:AddLeftGroupbox("Hive", "zap")

HiveGroupBox:AddLabel("Current Level: 0", true, "CurrentHiveLevel")

HiveGroupBox:AddToggle("AutoHiveFarmEnabled", {
    Text = "Farm Enabled",
    Tooltip = "Auto-farm closest entities and expand map until Light Source reaches target level",
    Default = false,
    
    Callback = function(Value)
        HiveModule._enabled = Value
    end,
})

do
    local levelLabel = workspace.Map.Chunks.BikiniBottom.ConchStreet.LIGHT_SOURCE.Core.LightSourceBillboard.LightSourceDisplay.Level
    
    local function updateDisplay()
        if Library.Labels.CurrentHiveLevel then
            local currentLevel = HiveModule:GetCurrentLevel()
            local maxLevel = HiveModule:GetMaxLevel()
            
            if HiveModule._enabled then
                Library.Labels.CurrentHiveLevel:SetText("Current Level: " .. currentLevel .. " / " .. maxLevel .. " (Farming)")
            else
                Library.Labels.CurrentHiveLevel:SetText("Current Level: " .. currentLevel .. " / " .. maxLevel)
            end
        end
    end
    
    updateDisplay()
    
    MainTrove:Connect(levelLabel:GetPropertyChangedSignal("Text"), function()
        updateDisplay()
    end)
end

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


CraftingGroupBox:AddLabel("AutoCraftStatus", {
    Text = "Status: Idle",
    DoesWrap = true,
})

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

CraftingGroupBox:AddButton({
	Text = "Reset",
	Func = function()
        Options.CraftItemDropdown:SetValue({})
    end,
	Tooltip = "Deselect all items",
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

local CreditsGroupBox = Tabs.Main:AddRightGroupbox("Credits", "info")

CreditsGroupBox:AddLabel("Developer: de324234", false)

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
