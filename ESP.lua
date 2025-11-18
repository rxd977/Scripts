-- services
local runService = game:GetService("RunService");
local players = game:GetService("Players");
local workspace = game:GetService("Workspace");

-- variables
local localPlayer = players.LocalPlayer;
local camera = workspace.CurrentCamera;
local viewportSize = camera.ViewportSize;
local container = Instance.new("Folder",
	gethui and gethui() or game:GetService("CoreGui"));

-- locals
local floor = math.floor;
local round = math.round;
local sin = math.sin;
local cos = math.cos;
local clear = table.clear;
local unpack = table.unpack;
local find = table.find;
local create = table.create;
local fromMatrix = CFrame.fromMatrix;

-- methods
local wtvp = camera.WorldToViewportPoint;
local isA = workspace.IsA;
local getPivot = workspace.GetPivot;
local findFirstChild = workspace.FindFirstChild;
local findFirstChildOfClass = workspace.FindFirstChildOfClass;
local getChildren = workspace.GetChildren;
local toOrientation = CFrame.identity.ToOrientation;
local pointToObjectSpace = CFrame.identity.PointToObjectSpace;
local lerpColor = Color3.new().Lerp;
local min2 = Vector2.zero.Min;
local max2 = Vector2.zero.Max;
local lerp2 = Vector2.zero.Lerp;
local min3 = Vector3.zero.Min;
local max3 = Vector3.zero.Max;

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0);
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0);
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1);
local NAME_OFFSET = Vector2.new(0, 2);
local DISTANCE_OFFSET = Vector2.new(0, 2);
local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
};
local BODY_PARTS = {
	Torso = {"UpperTorso", "LowerTorso"},
	LeftArm = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
	RightArm = {"RightUpperArm", "RightLowerArm", "RightHand"},
	LeftLeg = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
	RightLeg = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
	Head = {"Head"},
};

-- functions
local function isBodyPart(name)
	return name == "Head" or name:find("Torso") or name:find("Leg") or name:find("Arm");
end

local function getBoundingBox(parts)
	local min, max;
	for i = 1, #parts do
		local part = parts[i];
		local cframe, size = part.CFrame, part.Size;

		min = min3(min or cframe.Position, (cframe - size*0.5).Position);
		max = max3(max or cframe.Position, (cframe + size*0.5).Position);
	end

	local center = (min + max)*0.5;
	local front = Vector3.new(center.X, center.Y, max.Z);
	return CFrame.new(center, front), max - min;
end

local function worldToScreen(world)
	local screen, inBounds = wtvp(camera, world);
	return Vector2.new(screen.X, screen.Y), inBounds, screen.Z;
end

local function calculateCorners(cframe, size)
	local corners = create(#VERTICES);
	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe + size*0.5*VERTICES[i]).Position);
	end

	local min = min2(viewportSize, unpack(corners));
	local max = max2(Vector2.zero, unpack(corners));
	return {
		corners = corners,
		topLeft = Vector2.new(floor(min.X), floor(min.Y)),
		topRight = Vector2.new(floor(max.X), floor(min.Y)),
		bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
		bottomRight = Vector2.new(floor(max.X), floor(max.Y))
	};
end

local function rotateVector(vector, radians)
	-- https://stackoverflow.com/questions/28112315/how-do-i-rotate-a-vector
	local x, y = vector.X, vector.Y;
	local c, s = cos(radians), sin(radians);
	return Vector2.new(x*c - y*s, x*s + y*c);
end

local function parseColor(self, color, isOutline)
	if color == "Team Color" or (self.interface.sharedSettings.useTeamColor) then -- or not isOutline
		return self.interface.getTeamColor(self.player) or Color3.new(1,1,1);
	end
	return color;
end

local function getSkeletonPoints(character)
	local points = {};
	if not character then return points end;
	
	for partName, subParts in next, BODY_PARTS do
		if type(subParts) == "table" then
			points[partName] = {};
			for i, subPartName in next, subParts do
				local part = findFirstChild(character, subPartName);
				if part then
					local screen, visible = worldToScreen(part.Position);
					points[partName][i] = screen;
				end
			end
		end
	end
	
	return points;
end

local function createLineCircle(segments, thickness)
	local lines = {};
	for i = 1, segments do
		local line = Drawing.new("Line");
		line.Thickness = thickness;
		line.Visible = false;
		lines[i] = line;
	end
	return lines;
end

local function updateLineCircle(lines, position, radius, color, transparency, thickness, visible)
	local segments = #lines;
	for i = 1, segments do
		local angle = ((i - 1) / segments) * math.pi * 2;
		local point = Vector2.new(
			position.X + math.cos(angle) * radius,
			position.Y + math.sin(angle) * radius
		);
		
		local next_angle = (i / segments) * math.pi * 2;
		local next_point = Vector2.new(
			position.X + math.cos(next_angle) * radius,
			position.Y + math.sin(next_angle) * radius
		);
		
		local line = lines[i];
		line.From = point;
		line.To = next_point;
		line.Color = color;
		line.Transparency = transparency;
		line.Thickness = thickness;
		line.Visible = visible;
	end
end

-- esp object
local EspObject = {};
EspObject.__index = EspObject;

function EspObject.new(player, interface)
	local self = setmetatable({}, EspObject);
	self.player = assert(player, "Missing argument #1 (Player expected)");
	self.interface = assert(interface, "Missing argument #2 (table expected)");
	self:Construct();
	return self;
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class);
	for property, value in next, properties do
		pcall(function() drawing[property] = value; end);
	end
	self.bin[#self.bin + 1] = drawing;
	return drawing;
end

function EspObject:Construct()
	self.charCache = {};
	self.childCount = 0;
	self.bin = {};
	
	-- Create face circle lines (12 segments - reduced from 36)
	self.faceCircleLines = createLineCircle(12, 1);
	for i = 1, #self.faceCircleLines do
		self.bin[#self.bin + 1] = self.faceCircleLines[i];
	end
	
	self.drawings = {
		box3d = {
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			}
		},
		visible = {
			tracerOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			tracer = self:_create("Line", { Thickness = 1, Visible = false }),
			boxFill = self:_create("Square", { Filled = true, Visible = false }),
			boxOutline = self:_create("Square", { Thickness = 3, Visible = false }),
			box = self:_create("Square", { Thickness = 1, Visible = false }),
			healthBarOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			healthBar = self:_create("Line", { Thickness = 1, Visible = false }),
			healthText = self:_create("Text", { Center = true, Visible = false }),
			name = self:_create("Text", { Text = self.player.DisplayName or self.player.Name, Center = true, Visible = false }),
			distance = self:_create("Text", { Center = true, Visible = false }),
			weapon = self:_create("Text", { Center = true, Visible = false }),
			
			skeletonHead = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonTorso = self:_create("Line", { Thickness = 1, Visible = false }),
			
			-- Left Arm (3 segments: shoulder → elbow → wrist → hand)
			skeletonLeftArm1 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonLeftArm2 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonLeftArm3 = self:_create("Line", { Thickness = 1, Visible = false }),
			
			-- Right Arm (3 segments)
			skeletonRightArm1 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonRightArm2 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonRightArm3 = self:_create("Line", { Thickness = 1, Visible = false }),
			
			-- Left Leg (3 segments: hip → knee → ankle → foot)
			skeletonLeftLeg1 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonLeftLeg2 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonLeftLeg3 = self:_create("Line", { Thickness = 1, Visible = false }),
			
			-- Right Leg (3 segments)
			skeletonRightLeg1 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonRightLeg2 = self:_create("Line", { Thickness = 1, Visible = false }),
			skeletonRightLeg3 = self:_create("Line", { Thickness = 1, Visible = false }),
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false }),
			arrow = self:_create("Triangle", { Filled = true, Visible = false })
		}
	};

	-- NO LONGER CREATE CONNECTION HERE - will be handled by shared connection
end

function EspObject:Destruct()
	-- NO LONGER DISCONNECT CONNECTION HERE - handled by shared connection

	for i = 1, #self.bin do
		self.bin[i]:Remove();
	end

	clear(self);
end

function EspObject:Update()
	local interface = self.interface;

	self.options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"];
	
	-- CHECK ENABLED FIRST - before getting character
	self.enabled = self.options.enabled and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId));
	
	if not self.enabled then
		self.onScreen = false;
		return; -- SKIP EVERYTHING IF DISABLED
	end
	
	self.character = interface.getCharacter(self.player);
	
	-- CRITICAL: Early exit if no character OR if character is not in workspace
	if not self.character or self.character.Parent ~= workspace then
		self.charCache = {};
		self.onScreen = false;
		return; -- SKIP ALL EXPENSIVE CALCULATIONS
	end
	
	self.health, self.maxHealth = interface.getHealth(self.player);
	self.weapon = interface.getWeapon(self.player);

	-- Check if we have a rendered character with head
	local head = findFirstChild(self.character, "Head");
	
	if not head then
		self.charCache = {};
		self.onScreen = false;
		return;
	end

	-- NORMAL MODE: Character is rendered
	local _, onScreen, depth = worldToScreen(head.Position);
	self.onScreen = onScreen;
	self.distance = depth;

	if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
		self.onScreen = false;
	end

	if self.onScreen then
		local cache = self.charCache;
		local children = getChildren(self.character);
		if not cache[1] or self.childCount ~= #children then
			clear(cache);

			for i = 1, #children do
				local part = children[i];
				if isA(part, "BasePart") and isBodyPart(part.Name) then
					cache[#cache + 1] = part;
				end
			end

			self.childCount = #children;
		end

		self.corners = calculateCorners(getBoundingBox(cache));
		self.skeletonPoints = getSkeletonPoints(self.character);
	elseif self.options.offScreenArrow then
		local cframe = camera.CFrame;
		local flat = fromMatrix(cframe.Position, cframe.RightVector, Vector3.yAxis);
		local objectSpace = pointToObjectSpace(flat, head.Position);
		self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit;
	end
end

function EspObject:Render()
	local onScreen = self.onScreen or false;
	local enabled = self.enabled or false;
	local visible = self.drawings.visible;
	local hidden = self.drawings.hidden;
	local box3d = self.drawings.box3d;
	local interface = self.interface;
	local options = self.options;
	local corners = self.corners;

	visible.box.Visible = enabled and onScreen and options.box;
	visible.boxOutline.Visible = visible.box.Visible and options.boxOutline;
	if visible.box.Visible then
		local box = visible.box;
		box.Position = corners.topLeft;
		box.Size = corners.bottomRight - corners.topLeft;
		box.Color = parseColor(self, options.boxColor[1]);
		box.Transparency = options.boxColor[2];

		local boxOutline = visible.boxOutline;
		boxOutline.Position = box.Position;
		boxOutline.Size = box.Size;
		boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true);
		boxOutline.Transparency = options.boxOutlineColor[2];
	end

	visible.boxFill.Visible = enabled and onScreen and options.boxFill;
	if visible.boxFill.Visible then
		local boxFill = visible.boxFill;
		boxFill.Position = corners.topLeft;
		boxFill.Size = corners.bottomRight - corners.topLeft;
		boxFill.Color = parseColor(self, options.boxFillColor[1]);
		boxFill.Transparency = options.boxFillColor[2];
	end

	visible.healthBar.Visible = enabled and onScreen and options.healthBar;
	visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline;
	if visible.healthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET;
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

		local healthBar = visible.healthBar;
		healthBar.To = barTo;
		healthBar.From = lerp2(barTo, barFrom, self.health/self.maxHealth);
		healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, self.health/self.maxHealth);

		local healthBarOutline = visible.healthBarOutline;
		healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET;
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET;
		healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true);
		healthBarOutline.Transparency = options.healthBarOutlineColor[2];
	end

	visible.healthText.Visible = enabled and onScreen and options.healthText;
	if visible.healthText.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET;
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

		local healthText = visible.healthText;
		healthText.Text = round(self.health) .. "hp";
		healthText.Size = interface.sharedSettings.textSize;
		healthText.Font = interface.sharedSettings.textFont;
		healthText.Color = parseColor(self, options.healthTextColor[1]);
		healthText.Transparency = options.healthTextColor[2];
		healthText.Outline = options.healthTextOutline;
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true);
		healthText.Position = lerp2(barTo, barFrom, self.health/self.maxHealth) - healthText.TextBounds*0.5 - HEALTH_TEXT_OFFSET;
	end

	visible.name.Visible = enabled and onScreen and options.name;
	if visible.name.Visible then
		local name = visible.name;
		name.Size = interface.sharedSettings.textSize;
		name.Font = interface.sharedSettings.textFont;
		name.Color = parseColor(self, options.nameColor[1]);
		name.Transparency = options.nameColor[2];
		name.Outline = options.nameOutline;
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true);
		name.Position = (corners.topLeft + corners.topRight)*0.5 - Vector2.yAxis*name.TextBounds.Y - NAME_OFFSET;
	end

	visible.distance.Visible = enabled and onScreen and self.distance and options.distance;
	if visible.distance.Visible then
		local distance = visible.distance;
		distance.Text = round(self.distance) .. " studs";
		distance.Size = interface.sharedSettings.textSize;
		distance.Font = interface.sharedSettings.textFont;
		distance.Color = parseColor(self, options.distanceColor[1]);
		distance.Transparency = options.distanceColor[2];
		distance.Outline = options.distanceOutline;
		distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true);
		distance.Position = (corners.bottomLeft + corners.bottomRight)*0.5 + DISTANCE_OFFSET;
	end

	visible.weapon.Visible = enabled and onScreen and options.weapon;
	if visible.weapon.Visible then
		local weapon = visible.weapon;
		weapon.Text = self.weapon;
		weapon.Size = interface.sharedSettings.textSize;
		weapon.Font = interface.sharedSettings.textFont;
		weapon.Color = parseColor(self, options.weaponColor[1]);
		weapon.Transparency = options.weaponColor[2];
		weapon.Outline = options.weaponOutline;
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true);
		weapon.Position =
			(corners.bottomLeft + corners.bottomRight)*0.5 +
			(visible.distance.Visible and DISTANCE_OFFSET + Vector2.yAxis*visible.distance.TextBounds.Y or Vector2.zero);
	end

	visible.tracer.Visible = enabled and onScreen and options.tracer;
	visible.tracerOutline.Visible = visible.tracer.Visible and options.tracerOutline;
	if visible.tracer.Visible then
		local tracer = visible.tracer;
		tracer.Color = parseColor(self, options.tracerColor[1]);
		tracer.Transparency = options.tracerColor[2];
		tracer.To = (corners.bottomLeft + corners.bottomRight)*0.5;
		tracer.From =
			options.tracerOrigin == "Middle" and viewportSize*0.5 or
			options.tracerOrigin == "Top" and viewportSize*Vector2.new(0.5, 0) or
			options.tracerOrigin == "Bottom" and viewportSize*Vector2.new(0.5, 1);

		local tracerOutline = visible.tracerOutline;
		tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true);
		tracerOutline.Transparency = options.tracerOutlineColor[2];
		tracerOutline.To = tracer.To;
		tracerOutline.From = tracer.From;
	end

	hidden.arrow.Visible = enabled and (not onScreen) and options.offScreenArrow;
	hidden.arrowOutline.Visible = hidden.arrow.Visible and options.offScreenArrowOutline;
	if hidden.arrow.Visible and self.direction then
		local arrow = hidden.arrow;
		arrow.PointA = min2(max2(viewportSize*0.5 + self.direction*options.offScreenArrowRadius, Vector2.one*25), viewportSize - Vector2.one*25);
		arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45)*options.offScreenArrowSize;
		arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45)*options.offScreenArrowSize;
		arrow.Color = parseColor(self, options.offScreenArrowColor[1]);
		arrow.Transparency = options.offScreenArrowColor[2];

		local arrowOutline = hidden.arrowOutline;
		arrowOutline.PointA = arrow.PointA;
		arrowOutline.PointB = arrow.PointB;
		arrowOutline.PointC = arrow.PointC;
		arrowOutline.Color = parseColor(self, options.offScreenArrowOutlineColor[1], true);
		arrowOutline.Transparency = options.offScreenArrowOutlineColor[2];
	end

	local box3dEnabled = enabled and onScreen and options.box3d;
	for i = 1, #box3d do
		local face = box3d[i];
		for i2 = 1, #face do
			local line = face[i2];
			line.Visible = box3dEnabled;
			line.Color = parseColor(self, options.box3dColor[1]);
			line.Transparency = options.box3dColor[2];
		end

		if box3dEnabled then
			local line1 = face[1];
			line1.From = corners.corners[i];
			line1.To = corners.corners[i == 4 and 1 or i+1];

			local line2 = face[2];
			line2.From = corners.corners[i == 4 and 1 or i+1];
			line2.To = corners.corners[i == 4 and 5 or i+5];

			local line3 = face[3];
			line3.From = corners.corners[i == 4 and 5 or i+5];
			line3.To = corners.corners[i == 4 and 8 or i+4];
		end
	end

	
	local skeletonEnabled = enabled and onScreen and options.skeleton;
	
	-- Set all skeleton visibilities
	visible.skeletonHead.Visible = skeletonEnabled;
	visible.skeletonTorso.Visible = skeletonEnabled;
	visible.skeletonLeftArm1.Visible = skeletonEnabled;
	visible.skeletonLeftArm2.Visible = skeletonEnabled;
	visible.skeletonLeftArm3.Visible = skeletonEnabled;
	visible.skeletonRightArm1.Visible = skeletonEnabled;
	visible.skeletonRightArm2.Visible = skeletonEnabled;
	visible.skeletonRightArm3.Visible = skeletonEnabled;
	visible.skeletonLeftLeg1.Visible = skeletonEnabled;
	visible.skeletonLeftLeg2.Visible = skeletonEnabled;
	visible.skeletonLeftLeg3.Visible = skeletonEnabled;
	visible.skeletonRightLeg1.Visible = skeletonEnabled;
	visible.skeletonRightLeg2.Visible = skeletonEnabled;
	visible.skeletonRightLeg3.Visible = skeletonEnabled;

	if skeletonEnabled and self.skeletonPoints then
		local points = self.skeletonPoints;
		local skeletonColor = parseColor(self, options.skeletonColor[1]);
		local skeletonThickness = options.skeletonThickness or 1;
		
		-- HEAD CIRCLE (made of lines in screen space)
		if points.Head and points.Head[1] then
			local head = findFirstChild(self.character, "Head");
			if head then
				-- Calculate head circle radius based on distance
				local headPos, onScreenHead = worldToScreen(head.Position);
				local headTop = worldToScreen(head.Position + head.CFrame.UpVector * (head.Size.Y / 2));
				local headBottom = worldToScreen(head.Position - head.CFrame.UpVector * (head.Size.Y / 2));
				local radius = (headTop - headBottom).Magnitude / 2;
				
				-- Update the face circle
				updateLineCircle(
					self.faceCircleLines,
					headPos,
					radius,
					skeletonColor,
					options.skeletonColor[2],
					skeletonThickness,
					onScreenHead
				);
			end
		else
			-- Hide face circle if head not found
			updateLineCircle(
				self.faceCircleLines,
				Vector2.zero,
				0,
				skeletonColor,
				options.skeletonColor[2],
				skeletonThickness,
				false
			);
		end
		
		-- Head to Upper Torso
		if points.Head and points.Head[1] and points.Torso and points.Torso[1] then
			local head = findFirstChild(self.character, "Head");
			if head then
				local headBottom = worldToScreen(head.Position - head.CFrame.UpVector * (head.Size.Y / 2));
				visible.skeletonHead.From = headBottom;
				visible.skeletonHead.To = points.Torso[1];
				visible.skeletonHead.Color = skeletonColor;
				visible.skeletonHead.Thickness = skeletonThickness;
				visible.skeletonHead.Transparency = options.skeletonColor[2];
			end
		end
		
		-- Upper Torso to Lower Torso
		if points.Torso and points.Torso[1] and points.Torso[2] then
			visible.skeletonTorso.From = points.Torso[1];
			visible.skeletonTorso.To = points.Torso[2];
			visible.skeletonTorso.Color = skeletonColor;
			visible.skeletonTorso.Thickness = skeletonThickness;
			visible.skeletonTorso.Transparency = options.skeletonColor[2];
		end
		
		-- LEFT ARM (3 segments: UpperTorso → LeftUpperArm → LeftLowerArm → LeftHand)
		if points.LeftArm and points.Torso and points.Torso[1] then
			-- Shoulder to Elbow
			if points.LeftArm[1] then
				visible.skeletonLeftArm1.From = points.Torso[1];
				visible.skeletonLeftArm1.To = points.LeftArm[1];
				visible.skeletonLeftArm1.Color = skeletonColor;
				visible.skeletonLeftArm1.Thickness = skeletonThickness;
				visible.skeletonLeftArm1.Transparency = options.skeletonColor[2];
			end
			-- Elbow to Wrist
			if points.LeftArm[1] and points.LeftArm[2] then
				visible.skeletonLeftArm2.From = points.LeftArm[1];
				visible.skeletonLeftArm2.To = points.LeftArm[2];
				visible.skeletonLeftArm2.Color = skeletonColor;
				visible.skeletonLeftArm2.Thickness = skeletonThickness;
				visible.skeletonLeftArm2.Transparency = options.skeletonColor[2];
			end
			-- Wrist to Hand
			if points.LeftArm[2] and points.LeftArm[3] then
				visible.skeletonLeftArm3.From = points.LeftArm[2];
				visible.skeletonLeftArm3.To = points.LeftArm[3];
				visible.skeletonLeftArm3.Color = skeletonColor;
				visible.skeletonLeftArm3.Thickness = skeletonThickness;
				visible.skeletonLeftArm3.Transparency = options.skeletonColor[2];
			end
		end
		
		-- RIGHT ARM (3 segments)
		if points.RightArm and points.Torso and points.Torso[1] then
			if points.RightArm[1] then
				visible.skeletonRightArm1.From = points.Torso[1];
				visible.skeletonRightArm1.To = points.RightArm[1];
				visible.skeletonRightArm1.Color = skeletonColor;
				visible.skeletonRightArm1.Thickness = skeletonThickness;
				visible.skeletonRightArm1.Transparency = options.skeletonColor[2];
			end
			if points.RightArm[1] and points.RightArm[2] then
				visible.skeletonRightArm2.From = points.RightArm[1];
				visible.skeletonRightArm2.To = points.RightArm[2];
				visible.skeletonRightArm2.Color = skeletonColor;
				visible.skeletonRightArm2.Thickness = skeletonThickness;
				visible.skeletonRightArm2.Transparency = options.skeletonColor[2];
			end
			if points.RightArm[2] and points.RightArm[3] then
				visible.skeletonRightArm3.From = points.RightArm[2];
				visible.skeletonRightArm3.To = points.RightArm[3];
				visible.skeletonRightArm3.Color = skeletonColor;
				visible.skeletonRightArm3.Thickness = skeletonThickness;
				visible.skeletonRightArm3.Transparency = options.skeletonColor[2];
			end
		end
		
		-- LEFT LEG (3 segments)
		if points.LeftLeg and points.Torso and points.Torso[2] then
			if points.LeftLeg[1] then
				visible.skeletonLeftLeg1.From = points.Torso[2];
				visible.skeletonLeftLeg1.To = points.LeftLeg[1];
				visible.skeletonLeftLeg1.Color = skeletonColor;
				visible.skeletonLeftLeg1.Thickness = skeletonThickness;
				visible.skeletonLeftLeg1.Transparency = options.skeletonColor[2];
			end
			if points.LeftLeg[1] and points.LeftLeg[2] then
				visible.skeletonLeftLeg2.From = points.LeftLeg[1];
				visible.skeletonLeftLeg2.To = points.LeftLeg[2];
				visible.skeletonLeftLeg2.Color = skeletonColor;
				visible.skeletonLeftLeg2.Thickness = skeletonThickness;
				visible.skeletonLeftLeg2.Transparency = options.skeletonColor[2];
			end
			if points.LeftLeg[2] and points.LeftLeg[3] then
				visible.skeletonLeftLeg3.From = points.LeftLeg[2];
				visible.skeletonLeftLeg3.To = points.LeftLeg[3];
				visible.skeletonLeftLeg3.Color = skeletonColor;
				visible.skeletonLeftLeg3.Thickness = skeletonThickness;
				visible.skeletonLeftLeg3.Transparency = options.skeletonColor[2];
			end
		end
		
		-- RIGHT LEG (3 segments)
		if points.RightLeg and points.Torso and points.Torso[2] then
			if points.RightLeg[1] then
				visible.skeletonRightLeg1.From = points.Torso[2];
				visible.skeletonRightLeg1.To = points.RightLeg[1];
				visible.skeletonRightLeg1.Color = skeletonColor;
				visible.skeletonRightLeg1.Thickness = skeletonThickness;
				visible.skeletonRightLeg1.Transparency = options.skeletonColor[2];
			end
			if points.RightLeg[1] and points.RightLeg[2] then
				visible.skeletonRightLeg2.From = points.RightLeg[1];
				visible.skeletonRightLeg2.To = points.RightLeg[2];
				visible.skeletonRightLeg2.Color = skeletonColor;
				visible.skeletonRightLeg2.Thickness = skeletonThickness;
				visible.skeletonRightLeg2.Transparency = options.skeletonColor[2];
			end
			if points.RightLeg[2] and points.RightLeg[3] then
				visible.skeletonRightLeg3.From = points.RightLeg[2];
				visible.skeletonRightLeg3.To = points.RightLeg[3];
				visible.skeletonRightLeg3.Color = skeletonColor;
				visible.skeletonRightLeg3.Thickness = skeletonThickness;
				visible.skeletonRightLeg3.Transparency = options.skeletonColor[2];
			end
		end
	else
		-- Hide face circle when skeleton disabled
		updateLineCircle(
			self.faceCircleLines,
			Vector2.zero,
			0,
			Color3.new(1,1,1),
			0,
			1,
			false
		);
	end
end

-- cham object
local ChamObject = {};
ChamObject.__index = ChamObject;

function ChamObject.new(player, interface)
	local self = setmetatable({}, ChamObject);
	self.player = assert(player, "Missing argument #1 (Player expected)");
	self.interface = assert(interface, "Missing argument #2 (table expected)");
	self:Construct();
	return self;
end

function ChamObject:Construct()
	self.highlight = Instance.new("Highlight", container);
	-- NO LONGER CREATE CONNECTION HERE - will be handled by shared connection
end

function ChamObject:Destruct()
	-- NO LONGER DISCONNECT CONNECTION HERE - handled by shared connection
	self.highlight:Destroy();

	clear(self);
end
function ChamObject:Update()
	local interface = self.interface;
	local options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"];
	
	-- Early exit if not enabled
	local enabled = options.enabled and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId));
	
	if not enabled or not options.chams then
		self.highlight.Enabled = false;
		return; -- SKIP EVERYTHING
	end
	
	local character = interface.getCharacter(self.player);
	
	-- Early exit if no character OR if character is not in workspace
	if not character or character.Parent ~= workspace then
		self.highlight.Enabled = false;
		return; -- SKIP EVERYTHING
	end

	local highlight = self.highlight;
	highlight.Enabled = true;
	highlight.Adornee = character;
	highlight.FillColor = parseColor(self, options.chamsFillColor[1]);
	highlight.FillTransparency = options.chamsFillColor[2];
	highlight.OutlineColor = parseColor(self, options.chamsOutlineColor[1], true);
	highlight.OutlineTransparency = options.chamsOutlineColor[2];
	highlight.DepthMode = options.chamsVisibleOnly and "Occluded" or "AlwaysOnTop";
end

-- instance class
local InstanceObject = {};
InstanceObject.__index = InstanceObject;

function InstanceObject.new(instance, options)
	local self = setmetatable({}, InstanceObject);
	self.instance = assert(instance, "Missing argument #1 (Instance Expected)");
	self.options = assert(options, "Missing argument #2 (table expected)");
	self:Construct();
	return self;
end

function InstanceObject:Construct()
	local options = self.options;
	options.enabled = options.enabled == nil and true or options.enabled;
	options.text = options.text or "{name}";
	options.textColor = options.textColor or { Color3.new(1,1,1), 1 };
	options.textOutline = options.textOutline == nil and true or options.textOutline;
	options.textOutlineColor = options.textOutlineColor or Color3.new();
	options.textSize = options.textSize or 13;
	options.textFont = options.textFont or 2;
	options.limitDistance = options.limitDistance or false;
	options.maxDistance = options.maxDistance or 150;

	self.text = Drawing.new("Text");
	self.text.Center = true;

	self.renderConnection = runService.Heartbeat:Connect(function(deltaTime)
		self:Render(deltaTime);
	end);
end

function InstanceObject:Destruct()
	self.renderConnection:Disconnect();
	self.text:Remove();
end

function InstanceObject:Render()
	local instance = self.instance;
	if not instance or not instance.Parent then
		return self:Destruct();
	end

	local text = self.text;
	local options = self.options;
	if not options.enabled then
		text.Visible = false;
		return;
	end

	local world = getPivot(instance).Position;
	local position, visible, depth = worldToScreen(world);
	if options.limitDistance and depth > options.maxDistance then
		visible = false;
	end

	text.Visible = visible;
	if text.Visible then
		text.Position = position;
		text.Color = options.textColor[1];
		text.Transparency = options.textColor[2];
		text.Outline = options.textOutline;
		text.OutlineColor = options.textOutlineColor;
		text.Size = options.textSize;
		text.Font = options.textFont;
		text.Text = options.text
			:gsub("{name}", instance.Name)
			:gsub("{distance}", round(depth))
			:gsub("{position}", tostring(world));
	end
end

-- interface
local EspInterface = {
	_hasLoaded = false,
	_objectCache = {},
	_sharedUpdateConnection = nil,
	whitelist = {},
	sharedSettings = {
		textSize = 13,
		textFont = 2,
		limitDistance = false,
		maxDistance = 150,
		useTeamColor = false
	},
	teamSettings = {
		enemy = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(1,0,0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(1,0,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(1,0,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = Color3.new(),
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = Color3.new(),
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(1,0,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(1,0,0), 0 },
			skeleton = false,
			skeletonColor = { Color3.new(1,1,1), 1 },
			skeletonThickness = 1,
		},
		friendly = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(0,1,0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(0,1,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(0,1,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = Color3.new(),
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = Color3.new(),
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(0,1,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(0,1,0), 0 },
			skeleton = false,
			skeletonColor = { Color3.new(1,1,1), 1 },
			skeletonThickness = 1,
		}
	}
};

function EspInterface.AddInstance(instance, options)
	local cache = EspInterface._objectCache;
	if cache[instance] then
		warn("Instance handler already exists.");
	else
		cache[instance] = { InstanceObject.new(instance, options) };
	end
	return cache[instance][1];
end

--[[
	UNIVERSAL ENTITY ADDING SYSTEM
	
	Use this to add ANY entity (Players, Actors, NPCs, Zombies, etc)
	
	entity: The entity object (Player, Actor, NPC, etc)
	identifier: Unique ID for tracking (defaults to entity itself)
]]
function EspInterface.AddEntity(entity, identifier)
	identifier = identifier or entity;
	
	if EspInterface._objectCache[identifier] then
		warn("Entity already has ESP:", identifier);
		return;
	end
	
	EspInterface._objectCache[identifier] = {
		EspObject.new(entity, EspInterface),
		ChamObject.new(entity, EspInterface),
		_entity = entity
	};
end

--[[
	UNIVERSAL ENTITY REMOVING SYSTEM
	
	identifier: The same identifier used in AddEntity
]]
function EspInterface.RemoveEntity(identifier)
	local object = EspInterface._objectCache[identifier];
	if object then
		for i = 1, #object do
			if type(object[i]) == "table" and object[i].Destruct then
				object[i]:Destruct();
			end
		end
		EspInterface._objectCache[identifier] = nil;
	end
end

--[[
	CUSTOMIZABLE LOAD FUNCTION
	
	onEntityAdded: function(entity) - Called when entity should be added
	onEntityRemoved: function(entity) - Called when entity should be removed
	getInitialEntities: function() - Returns table of initial entities to add
	
	Returns: cleanup function
]]
function EspInterface.LoadCustom(onEntityAdded, onEntityRemoved, getInitialEntities)
	assert(not EspInterface._hasLoaded, "Esp has already been loaded.");
	
	-- Add initial entities
	if getInitialEntities then
		local entities = getInitialEntities();
		for _, entity in pairs(entities) do
			onEntityAdded(entity);
		end
	end
	
	EspInterface._hasLoaded = true;
	EspInterface._customCallbacks = {
		added = onEntityAdded,
		removed = onEntityRemoved
	};
	
	-- Return cleanup function
	return function()
		EspInterface.Unload();
	end;
end

--[[
	STANDARD PLAYER-BASED LOAD (Works like original)
]]
function EspInterface.Load()
	local cleanup = EspInterface.LoadCustom(
		-- onEntityAdded
		function(player)
			EspInterface.AddEntity(player, player.UserId);
		end,
		-- onEntityRemoved
		function(player)
			EspInterface.RemoveEntity(player.UserId);
		end,
		-- getInitialEntities
		function()
			local plrs = players:GetPlayers();
			local entities = {};
			for i = 2, #plrs do
				table.insert(entities, plrs[i]);
			end
			return entities;
		end
	);
	
	-- SINGLE SHARED UPDATE CONNECTION FOR ALL ENTITIES
	EspInterface._sharedUpdateConnection = runService.Heartbeat:Connect(function(deltaTime)
		for _, object in pairs(EspInterface._objectCache) do
			-- Update ESP object (index 1)
			if object[1] and object[1].Update then
				object[1]:Update(deltaTime);
				object[1]:Render(deltaTime);
			end
			-- Update Cham object (index 2)
			if object[2] and object[2].Update then
				object[2]:Update();
			end
		end
	end);
	
	return cleanup;
end

function EspInterface.Unload()
	assert(EspInterface._hasLoaded, "Esp has not been loaded yet.");

	-- Disconnect shared connection FIRST
	if EspInterface._sharedUpdateConnection then
		EspInterface._sharedUpdateConnection:Disconnect();
		EspInterface._sharedUpdateConnection = nil;
	end

	for index, object in next, EspInterface._objectCache do
		for i = 1, #object do
			if type(object[i]) == "table" and object[i].Destruct then
				object[i]:Destruct();
			end
		end
		EspInterface._objectCache[index] = nil;
	end

	if EspInterface.playerAdded then
		EspInterface.playerAdded:Disconnect();
	end
	if EspInterface.playerRemoving then
		EspInterface.playerRemoving:Disconnect();
	end
	
	EspInterface._hasLoaded = false;
	EspInterface._customCallbacks = nil;
end
-- game specific functions (CUSTOMIZE THESE FOR YOUR GAME)
function EspInterface.getWeapon(player)
	-- For standard Player objects
	if player.Character then
		local tool = player.Character:FindFirstChildOfClass("Tool");
		return tool and tool.Name or "None";
	end
	-- For actors/NPCs with _entity reference
	if player._entity and player._entity.Weapon then
		return player._entity.Weapon.Name;
	end
	return "Unknown";
end

function EspInterface.isFriendly(player)
	-- For standard Player objects
	if player.Team then
		return player.Team == localPlayer.Team;
	end
	-- For actors/NPCs
	if player._entity then
		-- Customize this based on your game
		-- return player._entity.Squad == localPlayerSquad
		return false;
	end
	return player.Team and player.Team == localPlayer.Team;
end

function EspInterface.getTeamColor(player)
	-- For standard Player objects
	if player.Team and player.Team.TeamColor then
		return player.Team.TeamColor.Color;
	end
	-- For actors/NPCs
	if player._entity and player._entity.Team then
		return player._entity.Team.Color;
	end
	return nil;
end

function EspInterface.getCharacter(player)
	-- For standard Player objects
	if player.Character then
		return player.Character;
	end
	-- For actors/NPCs
	if player._entity and player._entity.Character then
		return player._entity.Character;
	end
	return player.Character;
end

function EspInterface.getHealth(player)
	-- For standard Player objects
	local character = player.Character or (player._entity and player._entity.Character);
	local humanoid = character and findFirstChildOfClass(character, "Humanoid");
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth;
	end
	-- For actors/NPCs with direct health property
	if player._entity and player._entity.Health then
		return player._entity.Health, player._entity.MaxHealth or 100;
	end
	return 100, 100;
end

return EspInterface;
