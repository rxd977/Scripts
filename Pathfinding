--[[
    Advanced Pathfinding Module for Roblox
    Implements multiple pathfinding algorithms with raycast-based traversal
]]

local PathfindingModule = {}

-- Services
local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Constants
local DEFAULT_STEP = 5
local DEFAULT_MAX_TRIALS = 500
local DEFAULT_MAX_TIME = 5
local DEFAULT_WEIGHTING = 1
local DEFAULT_MIN_DIST = 2.5

-- Physics ignore list
PathfindingModule.physicsIgnore = {
    workspace.Terrain,
    workspace:FindFirstChild("Players"),
    workspace:FindFirstChild("Ignore"),
    workspace.CurrentCamera
}

--[[
    UTILITY FUNCTIONS
]]

-- Min-heap implementation for A* pathfinding
local function createHeap(compareFunc)
    local heap = {}
    local data = {}
    local size = 0
    
    local function bubbleUp(index)
        while index > 1 do
            local parent = math.floor(index / 2)
            if not compareFunc(data[index], data[parent]) then
                break
            end
            data[index], data[parent] = data[parent], data[index]
            index = parent
        end
    end
    
    local function bubbleDown(index)
        while true do
            local smallest = index
            local left = 2 * index
            local right = 2 * index + 1
            
            if left <= size and compareFunc(data[left], data[smallest]) then
                smallest = left
            end
            if right <= size and compareFunc(data[right], data[smallest]) then
                smallest = right
            end
            
            if smallest == index then break end
            
            data[index], data[smallest] = data[smallest], data[index]
            index = smallest
        end
    end
    
    function heap:insert(value)
        size = size + 1
        data[size] = value
        bubbleUp(size)
    end
    
    function heap:pop()
        if size == 0 then return nil end
        
        local result = data[1]
        data[1] = data[size]
        data[size] = nil
        size = size - 1
        
        if size > 0 then
            bubbleDown(1)
        end
        
        return result
    end
    
    function heap:isEmpty()
        return size == 0
    end
    
    return heap
end

-- Distance calculation
local function distance(a, b)
    return (b - a).Magnitude
end

-- Reconstruct path from parent map
local function reconstructPath(parents, goal)
    local path = {goal}
    local current = goal
    
    while parents[current] do
        current = parents[current]
        table.insert(path, 1, current)
    end
    
    return path
end

--[[
    RAYCASTING FUNCTIONS
]]

function PathfindingModule.rayCast(origin, direction, ignoreList, filterFunc, keepIgnore, ignoreWater)
    local result
    local startIgnoreCount = #ignoreList
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = ignoreWater or false
    
    while true do
        local rayResult = workspace:Raycast(origin, direction, params)
        
        if filterFunc and rayResult and filterFunc(rayResult.Instance) then
            table.insert(ignoreList, rayResult.Instance)
            params.FilterDescendantsInstances = ignoreList
        else
            result = rayResult
            break
        end
    end
    
    -- Clean up ignore list if needed
    if not keepIgnore then
        for i = #ignoreList, startIgnoreCount + 1, -1 do
            ignoreList[i] = nil
        end
    end
    
    return result
end

function PathfindingModule.canTraverse(start, direction)
    local params = RaycastParams.new()
    params.IgnoreWater = true
    params.FilterDescendantsInstances = table.clone(PathfindingModule.physicsIgnore)
    
    local ignoreList = params.FilterDescendantsInstances
    local canPass = false
    
    while not canPass do
        local result = workspace:Raycast(start, direction, params)
        
        if not result then
            return nil -- Can traverse
        end
        
        local instance = result.Instance
        canPass = instance.CanCollide == true or instance.Transparency ~= 1
        
        if not canPass then
            return result -- Blocked by solid object
        end
        
        table.insert(ignoreList, instance)
        params.FilterDescendantsInstances = ignoreList
    end
    
    return nil
end

function PathfindingModule.bulletIgnored(part)
    return part.CanCollide == false or part.Transparency == 1
end

--[[
    PATH VISUALIZATION
]]

function PathfindingModule.visualizePath(path, color)
    color = color or Color3.fromRGB(255, 0, 0)
    local parts = {}
    
    for i = 1, #path - 1 do
        local startPos = path[i]
        local endPos = path[i + 1]
        local midpoint = (startPos + endPos) / 2
        local length = (endPos - startPos).Magnitude
        
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.2, 0.2, length)
        part.CFrame = CFrame.lookAt(midpoint, endPos)
        part.Anchored = true
        part.CanCollide = false
        part.Color = color
        part.Material = Enum.Material.Neon
        part.Parent = workspace
        
        table.insert(parts, part)
    end
    
    -- Return cleanup function
    return function()
        for _, part in ipairs(parts) do
            part:Destroy()
        end
    end
end

--[[
    PATH INTERPOLATION
]]

function PathfindingModule.lerpPath(startPos, endPos, stepSize)
    local path = {}
    local direction = (endPos - startPos)
    local totalDistance = direction.Magnitude
    local unit = direction.Unit
    
    local steps = totalDistance / stepSize
    local wholeSteps = math.floor(steps)
    local remainder = steps % 1
    
    table.insert(path, startPos)
    
    for i = 1, wholeSteps do
        table.insert(path, startPos:Lerp(endPos, (i * stepSize) / totalDistance))
    end
    
    if remainder > 0 then
        table.insert(path, endPos)
    end
    
    return path
end

--[[
    VOXEL A* PATHFINDING (vadAStar - Voxel Advanced A*)
    Standard A* without floor checking - uses 3D grid navigation
]]

function PathfindingModule.vadAStar(config)
    local startPos = config.start
    local goalPos = config.goal
    local params = config.parameters or {}
    
    local step = params.step or DEFAULT_STEP
    local maxTrials = params.trials or DEFAULT_MAX_TRIALS
    local maxTime = params.maxtime or DEFAULT_MAX_TIME
    local weighting = params.weighting or DEFAULT_WEIGHTING
    local minDist = params.mindist or (step / 2)
    
    -- Direction vectors (6 directions: up, down, left, right, forward, back)
    local directions = {
        Vector3.new(0, 1, 0) * step,
        Vector3.new(0, -1, 0) * step,
        Vector3.new(1, 0, 0) * step,
        Vector3.new(-1, 0, 0) * step,
        Vector3.new(0, 0, 1) * step,
        Vector3.new(0, 0, -1) * step
    }
    
    -- A* data structures
    local openSet = createHeap(function(a, b)
        return a.fScore < b.fScore
    end)
    
    local parents = {}
    local gScore = {[startPos] = 0}
    local fScore = {[startPos] = distance(startPos, goalPos)}
    local closed = {}
    
    openSet:insert({pos = startPos, fScore = fScore[startPos]})
    
    local trials = 0
    local startTime = tick()
    
    while not openSet:isEmpty() do
        local current = openSet:pop()
        local currentPos = current.pos
        
        -- Check if we reached the goal
        if distance(currentPos, goalPos) <= minDist then
            local path = reconstructPath(parents, currentPos)
            return true, {
                waypoints = path,
                distance = gScore[currentPos],
                endpoint = currentPos,
                _tries = trials,
                _time = tick() - startTime
            }
        end
        
        -- Timeout checks
        if tick() - startTime > maxTime or trials > maxTrials then
            break
        end
        
        closed[currentPos] = true
        
        -- Check all neighbors
        for _, direction in ipairs(directions) do
            local neighbor = currentPos + direction
            
            if not closed[neighbor] then
                -- Check if we can traverse to this neighbor
                local result = PathfindingModule.canTraverse(currentPos, direction)
                
                if not result then -- No obstacle, can traverse
                    trials = trials + 1
                    
                    local tentativeG = gScore[currentPos] + step
                    
                    if not gScore[neighbor] or tentativeG < gScore[neighbor] then
                        parents[neighbor] = currentPos
                        gScore[neighbor] = tentativeG
                        fScore[neighbor] = tentativeG + distance(neighbor, goalPos) * weighting
                        
                        openSet:insert({pos = neighbor, fScore = fScore[neighbor]})
                    end
                end
            end
        end
    end
    
    return false, {
        _tries = trials,
        _time = tick() - startTime
    }
end

-- Alias for compatibility
PathfindingModule.aStar = PathfindingModule.vadAStar

--[[
    BEST FIRST SEARCH (Greedy)
]]

function PathfindingModule.bestFirstSearch(start, goal, options)
    options = options or {}
    
    local maxDist = options.max_dist or math.huge
    local minDist = options.min_dist or 1
    local step = options.step_dist or 1
    local maxFails = options.max_fails or math.huge
    
    if (goal - start).Magnitude >= maxDist then
        return nil
    end
    
    local mainDirection = (goal - start).Unit
    local failures = 0
    local parents = {}
    
    local openSet = createHeap(function(a, b)
        return distance(a, goal) < distance(b, goal)
    end)
    
    local visited = {[start] = true}
    
    -- Direction priority (sorted by alignment with goal)
    local directions = {
        Vector3.new(0, 1, 0),
        Vector3.new(0, -1, 0),
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, -1),
        Vector3.new(0, 0, 1)
    }
    
    table.sort(directions, function(a, b)
        return a:Dot(mainDirection) > b:Dot(mainDirection)
    end)
    
    openSet:insert(start)
    
    while not openSet:isEmpty() do
        local current = openSet:pop()
        local foundNeighbor = false
        
        for _, dir in ipairs(directions) do
            local direction = dir * step
            local result = PathfindingModule.canTraverse(current, direction)
            
            if not result then
                local neighbor = current + direction
                
                if not visited[neighbor] then
                    foundNeighbor = true
                    parents[neighbor] = current
                    
                    if distance(goal, neighbor) <= minDist then
                        return reconstructPath(parents, neighbor)
                    else
                        visited[neighbor] = true
                        openSet:insert(neighbor)
                    end
                end
            end
        end
        
        if not foundNeighbor then
            failures = failures + 1
        end
        
        if failures >= maxFails then
            break
        end
    end
    
    return nil
end

--[[
    PATH OPTIMIZATION
]]

function PathfindingModule.optimizePath(path, stepSize)
    if not path or #path < 2 then return path end
    
    local optimized = {}
    local currentIndex = 1
    local pathLength = #path
    
    while currentIndex <= pathLength - 1 do
        local current = path[currentIndex]
        table.insert(optimized, current)
        
        -- Try to skip as many waypoints as possible
        for i = pathLength, currentIndex + 1, -1 do
            local target = path[i]
            
            if not PathfindingModule.canTraverse(current, target - current) then
                -- Can skip to this point
                local interpolated = PathfindingModule.lerpPath(current, target, stepSize)
                
                -- Add interpolated points (except first, already added)
                for j = 2, #interpolated do
                    table.insert(optimized, interpolated[j])
                end
                
                currentIndex = i
                break
            end
        end
        
        currentIndex = currentIndex + 1
    end
    
    -- Ensure goal is included
    if optimized[#optimized] ~= path[pathLength] then
        table.insert(optimized, path[pathLength])
    end
    
    return optimized
end

--[[
    FLOOR-BASED A* (Main implementation used by knife bot)
    This variant checks for ground beneath positions
]]

function PathfindingModule.floorAStar(config)
    local startPos = config.start
    local goalPos = config.goal
    local params = config.parameters or {}
    
    local step = params.step or DEFAULT_STEP
    local maxTrials = params.trials or DEFAULT_MAX_TRIALS
    local maxTime = params.maxtime or DEFAULT_MAX_TIME
    local weighting = params.weighting or DEFAULT_WEIGHTING
    local minDist = params.mindist or (step / 2)
    
    -- Direction vectors (6 directions)
    local directions = {
        Vector3.new(0, 1, 0) * step,
        Vector3.new(0, -1, 0) * step,
        Vector3.new(1, 0, 0) * step,
        Vector3.new(-1, 0, 0) * step,
        Vector3.new(0, 0, 1) * step,
        Vector3.new(0, 0, -1) * step
    }
    
    -- Helper function to check if position has ground
    local function hasGround(position)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {workspace:FindFirstChild("Map")}
        params.FilterType = Enum.RaycastFilterType.Whitelist
        
        -- Check directly below
        local result = workspace:Raycast(position, Vector3.new(0, -4, 0), params)
        if result then return true end
        
        -- Check nearby if no direct ground
        local offsets = {
            Vector3.new(2, 0, 0),
            Vector3.new(-2, 0, 0),
            Vector3.new(0, 0, 2),
            Vector3.new(0, 0, -2)
        }
        
        for _, offset in ipairs(offsets) do
            result = workspace:Raycast(position, offset, params)
            if result then return true end
        end
        
        return false
    end
    
    -- A* data structures
    local openSet = createHeap(function(a, b)
        return a.fScore < b.fScore
    end)
    
    local parents = {}
    local gScore = {[startPos] = 0}
    local fScore = {[startPos] = distance(startPos, goalPos)}
    local closed = {}
    
    openSet:insert({pos = startPos, fScore = fScore[startPos]})
    
    local trials = 0
    local startTime = tick()
    
    while not openSet:isEmpty() do
        local current = openSet:pop()
        local currentPos = current.pos
        
        -- Check if we reached the goal
        if distance(currentPos, goalPos) <= minDist then
            local path = reconstructPath(parents, currentPos)
            return true, {
                waypoints = path,
                distance = gScore[currentPos],
                endpoint = currentPos,
                _tries = trials,
                _time = tick() - startTime
            }
        end
        
        -- Timeout checks
        if tick() - startTime > maxTime or trials > maxTrials then
            break
        end
        
        closed[currentPos] = true
        
        -- Check all neighbors
        for _, direction in ipairs(directions) do
            local neighbor = currentPos + direction
            
            -- Must have ground support
            if not closed[neighbor] and hasGround(neighbor) then
                -- Check if we can traverse to this neighbor
                local result = PathfindingModule.canTraverse(currentPos, direction)
                
                if not result then -- Can traverse (no obstacle)
                    trials = trials + 1
                    
                    local tentativeG = gScore[currentPos] + step
                    
                    if not gScore[neighbor] or tentativeG < gScore[neighbor] then
                        parents[neighbor] = currentPos
                        gScore[neighbor] = tentativeG
                        fScore[neighbor] = tentativeG + distance(neighbor, goalPos) * weighting
                        
                        openSet:insert({pos = neighbor, fScore = fScore[neighbor]})
                    end
                end
            end
        end
    end
    
    return false, {
        _tries = trials,
        _time = tick() - startTime
    }
end

--[[
    PATH OPTIMIZATION (Exact implementation from obfuscated code)
]]

function PathfindingModule.optimizePath(waypoints, stepSize)
    if not waypoints or #waypoints < 2 then return waypoints end
    
    local optimized = {}
    local currentIndex = 1
    local pathLength = #waypoints
    local lastYDiff = nil
    local consecutiveYDiff = 0
    
    while currentIndex <= pathLength - 1 do
        local currentPos = waypoints[currentIndex]
        
        -- Try to find furthest visible waypoint
        for targetIndex = pathLength, currentIndex + 1, -1 do
            local targetPos = waypoints[targetIndex]
            local direction = targetPos - currentPos
            
            -- Check if path is clear
            if not PathfindingModule.canTraverse(currentPos, direction) then
                -- Calculate Y difference
                local yDiff = math.floor(targetPos.Y - currentPos.Y + 0.5) -- Round
                
                -- Check for ground (anti-fall protection)
                if yDiff == lastYDiff then
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {workspace:FindFirstChild("Map")}
                    params.FilterType = Enum.RaycastFilterType.Whitelist
                    
                    local hasGround = workspace:Raycast(targetPos, Vector3.new(0, -4, 0), params)
                    
                    if not hasGround then
                        consecutiveYDiff = consecutiveYDiff + yDiff
                        
                        -- Abort if falling too far (>15 studs)
                        if consecutiveYDiff > 15 then
                            return false
                        end
                    end
                else
                    lastYDiff = yDiff
                    consecutiveYDiff = 0
                end
                
                -- Interpolate between points
                local interpolated = PathfindingModule.lerpPath(currentPos, targetPos, stepSize)
                
                for i = 1, #interpolated do
                    table.insert(optimized, interpolated[i])
                end
                
                currentIndex = targetIndex
                break
            end
        end
        
        currentIndex = currentIndex + 1
    end
    
    return optimized
end

--[[
    MAIN API
]]

function PathfindingModule.findPath(start, goal, options)
    options = options or {}
    
    local success, result = PathfindingModule.aStar({
        start = start,
        goal = goal,
        parameters = options
    })
    
    if success and options.optimize then
        result.waypoints = PathfindingModule.optimizePath(
            result.waypoints, 
            options.optimize_step or 1
        )
    end
    
    return success, result
end

return PathfindingModule
