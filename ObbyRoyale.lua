
if getgenv().hasExecuted then getgenv().onExecuted() return end

getgenv().hasExecuted = true

-- Services:

local GamepadService = game:GetService("GamepadService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = gethui and gethui() or game:GetService("CoreGui")

-- Modules:

local OrUtils = require(ReplicatedStorage.Utils.ORUtils)
local Difficulties = require(ReplicatedStorage.Info.Difficulties)
local MainUIController = require(Players.LocalPlayer.PlayerGui.MainUI.MainUIController)
local PracticeController = require(Players.LocalPlayer.PlayerGui.MainUI.MainUIController.PracticeController)

-- Variables:

local DefaultGravity = workspace.Gravity
local GameY = 222.69964599609375
local PracticeY = 252.12367248535156

local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local GuiInset = GuiService:GetGuiInset()
local PlaceId = game.PlaceId
local JobId = game.JobId
local PlaceName = MarketplaceService:GetProductInfo(PlaceId).Name
local Rng = Random.new()

local PracticeUI = PlayerGui.MainUI.PracticeUI

local NO_UPVALUES = function(Function)
    return function(...)
        return Function(...)
    end
end

local Cursors = {
	arrowFarCursor = {
		icon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png",
		size = UDim2.fromOffset(64, 64),
		offset = Vector2.new(-32, 4),
	},
	mouseLockedCursor = {
		icon = "rbxasset://textures/MouseLockedCursor.png",
		size = UDim2.fromOffset(32, 32),
		offset = Vector2.new(-16, 20),
	},
}

local Util = {

}

local Tas = {
	animationController = {
		_disabled = false,
		_animationQueue = {},
		_pose = nil,
		_currentAnimationSpeed = 0.1,
		_dead = false,
		_originalWalkSpeed = nil,
		_originalJumpPower = nil,
	},

	cameraController = {
		_zoomControllers = {},
		_cameraCFrame = CurrentCamera.CFrame,
	},

	inputController = {
		_cursor = nil,
		_cursorHolder = nil,
		_cursorFrame = nil,
		_resolution = nil,
		_shiftlockState = false,
		_mouseLockController = nil,
		_controls = nil,
	},

	core = {
		_isReplaying = false,
		_isRecording = false,
		_onStartRecording = nil,
		_onStopRecording = nil,
		_isUsingAllReplay = false,
		_recordingFrames = {},
		_isFrozen = false,
		_freezeFrame = 1,
		_seekDirection = 0,
		_goBackKey = nil,
		_goForwardKey = nil,
	},
}

local ObbyRoyale = {
	autoPlayController = {
		_isAutoPlayEnabled = false,
		_isAutoPlaying = false,
	},

	tasController = {
		_stages = {},
		_oldCloseUI = nil,
		_oldOpenUI = nil,
		_oldPopulateStages = nil,
		_practiceENV = nil,
		_isSelectingStage = false,
		_isTASSING = false,
		_isPracticeUIHooked = false,
		_loadedStage = nil,
	},

	core = {
		_isServerhopping = false,
		_isRejoining = false,
		_isJoiningPro = false,
		_isResetDisabled = false,
		_unlockedPracticeStages = false,
	},
}

local Interface = {
	_window = nil,
	_tabs = {},
}

-- Methods:

do -- Util:
	function Util:getHumanoid()
		local Character = LocalPlayer.Character
		if not Character then return end

		return Character:FindFirstChildOfClass("Humanoid")
	end

	function Util:getRootPart()
		local Character = LocalPlayer.Character
		if not Character then return end

		return Character:FindFirstChild("HumanoidRootPart")
	end

	function Util:roundNumber(Number, Digits)
		local Multi = 10 ^ math.max(tonumber(Digits) or 0, 0)

		return math.floor(Number * Multi + 0.5) / Multi
	end

	function Util:roundTable(Tbl, Digits)
		local RoundedTable = {}

		for I, Number in Tbl do
			RoundedTable[I] = self:roundNumber(Number, Digits)
		end

		return RoundedTable
	end

	function Util:vector3ToTable(Vector3Value)
		return {Vector3Value.X, Vector3Value.Y, Vector3Value.Z}
	end

	function Util:tableToVector3(Tbl)
		return Vector3.new(table.unpack(Tbl))
	end

	function Util:vector2ToTable(Vector2Value)
		return {Vector2Value.X, Vector2Value.Y}
	end

	function Util:tableToVector2(Tbl)
		return Vector2.new(table.unpack(Tbl))
	end

	function Util:cframeToTable(Cframe)
		return {Cframe:GetComponents()}
	end

	function Util:tableToCFrame(Tbl)
		return CFrame.new(table.unpack(Tbl))
	end
end

 do -- Tas:
	do -- animationController:
		function Tas.animationController:stopAllAnimations()
			local Humanoid = Util:getHumanoid()
			if not Humanoid then return end

			for _, AnimationTrack in Humanoid:GetPlayingAnimationTracks() do
				AnimationTrack:Stop()
			end
		end

		function Tas.animationController:isDead()
			return self._dead
		end

		function Tas.animationController:getOriginalJumpPower()
			return self._originalJumpPower
		end

		function Tas.animationController:getOriginalWalkSpeed()
			return self._originalWalkSpeed
		end

		function Tas.animationController:setDisabled(State)
			self._disabled = State
		end

		function Tas.animationController:setPose(Pose)
			self._pose = Pose
		end

		function Tas.animationController:getPose()
			return self._pose
		end

		function Tas.animationController:getAnimationQueue()
			return self._animationQueue
		end

		function Tas.animationController:getAnimationSpeed()
			return self._currentAnimationSpeed
		end

		function Tas.animationController:reAnimate()
			local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

			for _, Obj in Character:GetDescendants() do
				if not Obj:IsA("LocalScript") or Obj.Name ~= "Animate" then continue end

				Obj:Destroy()
			end

			self:stopAllAnimations()

			do -- Animate.lua
				local Torso = Character:WaitForChild("Torso")
				local RightShoulder = Torso:WaitForChild("Right Shoulder")
				local LeftShoulder = Torso:WaitForChild("Left Shoulder")
				local RightHip = Torso:WaitForChild("Right Hip")
				local LeftHip = Torso:WaitForChild("Left Hip")
				local Humanoid = Character:WaitForChild("Humanoid")

				local CurrentAnim = ""
				local CurrentAnimInstance = nil
				local CurrentAnimTrack = nil
				local CurrentAnimKeyframeHandler = nil

				local AnimTable = {}
				local AnimNames = {
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
				local Dances = {"dance1", "dance2", "dance3"}

				-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
				local EmoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

				function configureAnimationSet(Name, FileList)
					if (AnimTable[Name] ~= nil) then
						for _, Connection in pairs(AnimTable[Name].connections) do
							Connection:disconnect()
						end
					end
					AnimTable[Name] = {}
					AnimTable[Name].count = 0
					AnimTable[Name].totalWeight = 0
					AnimTable[Name].connections = {}

					-- check for config values

					-- fallback to defaults
					if (AnimTable[Name].count <= 0) then
						for Idx, Anim in pairs(FileList) do
							AnimTable[Name][Idx] = {}
							AnimTable[Name][Idx].anim = Instance.new("Animation")
							AnimTable[Name][Idx].anim.Name = Name
							AnimTable[Name][Idx].anim.AnimationId = Anim.id
							AnimTable[Name][Idx].weight = Anim.weight
							AnimTable[Name].count = AnimTable[Name].count + 1
							AnimTable[Name].totalWeight = AnimTable[Name].totalWeight + Anim.weight
							--			print(Name .. " [" .. Idx .. "] " .. Anim.id .. " (" .. Anim.weight .. ")")
						end
					end
				end

				-- Setup animation objects

				-- Clear any existing animation tracks
				-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
				local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator") or nil
				if Animator then
					local AnimTracks = Animator:GetPlayingAnimationTracks()
					for I,Track in ipairs(AnimTracks) do
						Track:Stop(0)
						Track:Destroy()
					end
				end


				for Name, FileList in pairs(AnimNames) do
					configureAnimationSet(Name, FileList)
				end

				-- ANIMATION

				-- declarations
				local ToolAnim = "None"
				local ToolAnimTime = 0

				local JumpAnimTime = 0
				local JumpAnimDuration = 0.3

				local ToolTransitionTime = 0.1
				local FallTransitionTime = 0.3
				local JumpMaxLimbVelocity = 0.75

				-- functions

				function stopAllAnimations()
					local OldAnim = CurrentAnim

					-- return to idle if finishing an emote
					if (EmoteNames[OldAnim] ~= nil and EmoteNames[OldAnim] == false) then
						OldAnim = "idle"
					end

					CurrentAnim = ""
					CurrentAnimInstance = nil
					if (CurrentAnimKeyframeHandler ~= nil) then
						CurrentAnimKeyframeHandler:disconnect()
					end

					if (CurrentAnimTrack ~= nil) then
						CurrentAnimTrack:Stop()
						CurrentAnimTrack:Destroy()
						CurrentAnimTrack = nil
					end
					return OldAnim
				end

				function Tas.animationController:setAnimationSpeed(Speed)
					if Speed ~= self._currentAnimationSpeed then
						self._currentAnimationSpeed = Speed
						CurrentAnimTrack:AdjustSpeed(self._currentAnimationSpeed)
					end
				end

				function keyFrameReachedFunc(FrameName)
					if (FrameName == "End") then

						local RepeatAnim = CurrentAnim
						-- return to idle if finishing an emote
						if (EmoteNames[RepeatAnim] ~= nil and EmoteNames[RepeatAnim] == false) then
							RepeatAnim = "idle"
						end

						local AnimSpeed = self._currentAnimationSpeed
						self:playAnimation(RepeatAnim, 0.0)
						self:setAnimationSpeed(AnimSpeed)
					end
				end

				function Tas.animationController:playAnimation(AnimName, TransitionTime, BypassAnimateDisabled)
					pcall(function()
						if self._disabled and not BypassAnimateDisabled then
							return
						end

						if Tas.core:isRecording() then
							table.insert(self._animationQueue, { AnimName, TransitionTime })
						end

						local Humanoid = Util:getHumanoid()
						if not Humanoid then return end

						local Roll = math.random(1, AnimTable[AnimName].totalWeight)
						local OrigRoll = Roll
						local Idx = 1

						while (Roll > AnimTable[AnimName][Idx].weight) do
							Roll = Roll - AnimTable[AnimName][Idx].weight
							Idx = Idx + 1
						end

						--		print(AnimName .. " " .. Idx .. " [" .. OrigRoll .. "]")
						local Anim = AnimTable[AnimName][Idx].anim

						-- switch animation
						if (Anim ~= CurrentAnimInstance) then
							if (CurrentAnimTrack ~= nil) then
								CurrentAnimTrack:Stop(TransitionTime)
								CurrentAnimTrack:Destroy()
							end

							self._currentAnimationSpeed = 1.0

							-- load it to the humanoid, get AnimationTrack
							CurrentAnimTrack = Humanoid:LoadAnimation(Anim)
							CurrentAnimTrack.Priority = Enum.AnimationPriority.Core

							-- play the animation
							CurrentAnimTrack:Play(TransitionTime)
							CurrentAnim = AnimName
							CurrentAnimInstance = Anim

							-- set up keyframe name triggers
							if (CurrentAnimKeyframeHandler ~= nil) then
								CurrentAnimKeyframeHandler:disconnect()
							end
							CurrentAnimKeyframeHandler = CurrentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
						end
					end)
				end

				-------------------------------------------------------------------------------------------
				-------------------------------------------------------------------------------------------

				local ToolAnimName = ""
				local ToolAnimTrack = nil
				local ToolAnimInstance = nil
				local CurrentToolAnimKeyframeHandler = nil

				function toolKeyFrameReachedFunc(FrameName)
					if (FrameName == "End") then
						--		print("Keyframe : ".. FrameName)
						playToolAnimation(ToolAnimName, 0.0, Humanoid)
					end
				end

				function playToolAnimation(AnimName, TransitionTime, Humanoid, Priority)

					local Roll = math.random(1, AnimTable[AnimName].totalWeight)
					local OrigRoll = Roll
					local Idx = 1
					while (Roll > AnimTable[AnimName][Idx].weight) do
						Roll = Roll - AnimTable[AnimName][Idx].weight
						Idx = Idx + 1
					end
					--		print(AnimName .. " * " .. Idx .. " [" .. OrigRoll .. "]")
					local Anim = AnimTable[AnimName][Idx].anim

					if (ToolAnimInstance ~= Anim) then

						if (ToolAnimTrack ~= nil) then
							ToolAnimTrack:Stop()
							ToolAnimTrack:Destroy()
							TransitionTime = 0
						end

						-- load it to the humanoid, get AnimationTrack
						ToolAnimTrack = Humanoid:LoadAnimation(Anim)
						if Priority then
							ToolAnimTrack.Priority = Priority
						end

						-- play the animation
						ToolAnimTrack:Play(TransitionTime)
						ToolAnimName = AnimName
						ToolAnimInstance = Anim

						CurrentToolAnimKeyframeHandler = ToolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
					end
				end

				function stopToolAnimations()
					local OldAnim = ToolAnimName

					if (CurrentToolAnimKeyframeHandler ~= nil) then
						CurrentToolAnimKeyframeHandler:disconnect()
					end

					ToolAnimName = ""
					ToolAnimInstance = nil
					if (ToolAnimTrack ~= nil) then
						ToolAnimTrack:Stop()
						ToolAnimTrack:Destroy()
						ToolAnimTrack = nil
					end


					return OldAnim
				end

				-------------------------------------------------------------------------------------------
				-------------------------------------------------------------------------------------------

				function Tas.animationController:onRunning(Speed)
					if Speed > 0.01 then
						self:playAnimation("walk", 0.1)
						if CurrentAnimInstance and CurrentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
							self:setAnimationSpeed(Speed / 14.5)
						end
						self._pose = "Running"
					else
						if EmoteNames[CurrentAnim] == nil then
							self:playAnimation("idle", 0.1)
							self._pose = "Standing"
						end
					end
				end

				function Tas.animationController:onDied()
					self._pose = "Dead"
				end

				function Tas.animationController:onJumping()
					self:playAnimation("jump", 0.1)
					JumpAnimTime = JumpAnimDuration
					self._pose = "Jumping"
				end

				function Tas.animationController:onClimbing(Speed)
					self:playAnimation("climb", 0.1)
					self:setAnimationSpeed(Speed / 12.0)
					self._pose = "Climbing"
				end

				function Tas.animationController:onGettingUp()
					self._pose = "GettingUp"
				end

				function Tas.animationController:onFreeFall()
					if (JumpAnimTime <= 0) then
						self:playAnimation("fall", FallTransitionTime)
					end
					self._pose = "FreeFall"
				end

				function Tas.animationController:onFallingDown()
					self._pose = "FallingDown"
				end

				function Tas.animationController:onSeated()
					self._pose = "Seated"
				end

				function Tas.animationController:onPlatformStanding()
					self._pose = "PlatformStanding"
				end

				function Tas.animationController:onSwimming(Speed)
					if Speed > 0 then
						self._pose = "Running"
					else
						self._pose = "Standing"
					end
				end

				function getTool()
					for _, Kid in ipairs(Character:GetChildren()) do
						if Kid.className == "Tool" then return Kid end
					end
					return nil
				end

				function getToolAnim(Tool)
					for _, C in ipairs(Tool:GetChildren()) do
						if C.Name == "toolanim" and C.className == "StringValue" then
							return C
						end
					end
					return nil
				end

				function animateTool()

					if (ToolAnim == "None") then
						playToolAnimation("toolnone", ToolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
						return
					end

					if (ToolAnim == "Slash") then
						playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
						return
					end

					if (ToolAnim == "Lunge") then
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

				local LastTick = 0

				function move(Time)
					if self._disabled then
						return
					end

					local Amplitude = 1
					local Frequency = 1
					local DeltaTime = Time - LastTick
					LastTick = Time

					local ClimbFudge = 0
					local SetAngles = false

					if (JumpAnimTime > 0) then
						JumpAnimTime = JumpAnimTime - DeltaTime
					end

					if (self._pose == "FreeFall" and JumpAnimTime <= 0) then
						self:playAnimation("fall", FallTransitionTime)
					elseif (self._pose == "Seated") then
						self:playAnimation("sit", 0.5)
						return
					elseif (self._pose == "Running") then
						self:playAnimation("walk", 0.1)
					elseif (self._pose == "Dead" or self._pose == "GettingUp" or self._pose == "FallingDown" or self._pose == "Seated" or self._pose == "PlatformStanding") then
						--		print("Wha " .. pose)
						stopAllAnimations()
						Amplitude = 0.1
						Frequency = 1
						SetAngles = true
					end

					if (SetAngles) then
						local DesiredAngle = Amplitude * math.sin(Time * Frequency)

						RightShoulder:SetDesiredAngle(DesiredAngle + ClimbFudge)
						LeftShoulder:SetDesiredAngle(DesiredAngle - ClimbFudge)
						RightHip:SetDesiredAngle(-DesiredAngle)
						LeftHip:SetDesiredAngle(-DesiredAngle)
					end

					-- Tool Animation handling
					local Tool = getTool()
					if Tool and Tool:FindFirstChild("Handle") then

						local AnimStringValueObject = getToolAnim(Tool)

						if AnimStringValueObject then
							ToolAnim = AnimStringValueObject.Value
							-- message recieved, delete StringValue
							AnimStringValueObject.Parent = nil
							ToolAnimTime = Time + .3
						end

						if Time > ToolAnimTime then
							ToolAnimTime = 0
							ToolAnim = "None"
						end

						animateTool()
					else
						stopToolAnimations()
						ToolAnim = "None"
						ToolAnimInstance = nil
						ToolAnimTime = 0
					end
				end

				Humanoid.Died:connect(function(...)
					if self._disabled then
						return
					end

					self:onDied(...)
				end)

				Humanoid.Running:connect(function(Speed)
					if self._disabled then
						return
					end

					self:onRunning(Speed)
				end)
				Humanoid.Jumping:connect(function(...)
					if self._disabled then
						return
					end

					self:onJumping(...)
				end)
				Humanoid.Climbing:connect(function(Speed)
					if self._disabled then
						return
					end

					self:onClimbing(Speed)
				end)
				Humanoid.GettingUp:connect(function(...)
					if self._disabled then
						return
					end

					self:onGettingUp(...)
				end)
				Humanoid.FreeFalling:connect(function(...)
					if self._disabled then
						return
					end

					self:onFreeFall(...)
				end)
				Humanoid.FallingDown:connect(function(...)
					if self._disabled then
						return
					end
					--table.insert(AnimationQueue,7)
					self:onFallingDown(...)
				end)
				Humanoid.Seated:connect(function(...)
					if self._disabled then
						return
					end

					self:onSeated(...)
				end)
				Humanoid.PlatformStanding:connect(function(...)
					if self._disabled then
						return
					end

					self:onPlatformStanding(...)
				end)
				Humanoid.Swimming:connect(function(...)
					if self._disabled then
						return
					end

					self:onSwimming(...)
				end)

				game:GetService("Players").LocalPlayer.Chatted:connect(function(Msg)
					local Emote = ""
					if Msg == "/e dance" then
						Emote = Dances[math.random(1, #Dances)]
					elseif (string.sub(Msg, 1, 3) == "/e ") then
						Emote = string.sub(Msg, 4)
					elseif (string.sub(Msg, 1, 7) == "/emote ") then
						Emote = string.sub(Msg, 8)
					end

					if (self._pose == "Standing" and EmoteNames[Emote] ~= nil) then
						self:playAnimation(Emote, 0.1)
					end

				end)

				self:playAnimation("idle", 0.1)
				self._pose = "Standing"

				spawn(function()
					while Character.Parent ~= nil do
						local _, Time = wait(0.1)
						move(Time)
					end
				end)
			end
		end

		function Tas.animationController:characterAdded(Character)
			local Humanoid = Character:WaitForChild("Humanoid")

			self._originalJumpPower = Humanoid.JumpPower
			self._originalWalkSpeed = Humanoid.WalkSpeed

			self:reAnimate()

			Humanoid.Died:Connect(function()
				self._dead = true
			end)

			self._dead = false
		end

		function Tas.animationController:init()
			if LocalPlayer.Character then self:characterAdded(LocalPlayer.Character) end

			LocalPlayer.CharacterAdded:Connect(function(Character) self:characterAdded(Character) end)
		end
	end

	do  -- cameraController:
		function Tas.cameraController:setZoom(Zoom)
			for _, ZoomController in self._zoomControllers do
				pcall(function()
					ZoomController:SetCameraToSubjectDistance(Zoom)
				end)
			end
		end

		function Tas.cameraController:getZoom()
			for _, ZoomController in self._zoomControllers do
				local Zoom = ZoomController:GetCameraToSubjectDistance()

				if Zoom and Zoom ~= 12.5 then
					return Zoom
				end
			end

			return 12.5
		end

		function Tas.cameraController:setCFrame(Cframe)
			self._cameraCFrame = Cframe

			CurrentCamera.CFrame = Cframe
		end

		function Tas.cameraController:init()
			for _, Obj in getgc(true) do
				if typeof(Obj) == "table" and rawget(Obj, "FIRST_PERSON_DISTANCE_THRESHOLD") then
					table.insert(self._zoomControllers, Obj)
				end
			end

			CurrentCamera.Changed:Connect(function()
				if not Tas.core:isReplaying() or not Tas.core:isUsingAllReplay() then return end

				CurrentCamera.CFrame = self._cameraCFrame
			end)
		end
	end

	do -- inputController:
		function Tas.inputController:createCursor()
			local CursorHolder = Instance.new("ScreenGui")
			CursorHolder.DisplayOrder = 999
			CursorHolder.OnTopOfCoreBlur = true
			CursorHolder.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			CursorHolder.Parent = CoreGui

			self._resolution = CursorHolder.AbsoluteSize

			self._cursorHolder = CursorHolder

			local CursorFrame = Instance.new("ImageLabel")
			CursorFrame.BackgroundTransparency = 1
			CursorFrame.ZIndex = 999
			CursorFrame.Parent = CursorHolder

			self._cursorFrame = CursorFrame
		end

		function Tas.inputController:setCursor(CursorName)
			self._cursor = Cursors[CursorName]
		end

		function Tas.inputController:getCursor()
			return self._cursor
		end

		function Tas.inputController:getResolution()
			return self._resolution
		end

		function Tas.inputController:disableControls()
			self._controls:Disable()
		end

		function Tas.inputController:enableControls()
			self._controls:Enable()
		end

		function Tas.inputController:getShiftLockState()
			return self._shiftlockState
		end

		function Tas.inputController:toggleShiftLock(State)
			State = if State == nil then not self._shiftlockState else State

			if self._shiftlockState == State then return end

			self._shiftlockState = State

			if State then
				self:setCursor("mouseLockedCursor")
			else
				self:setCursor("arrowFarCursor")
			end

			self.DoMouseLockSwitch(self._mouseLockController, "MouseLockSwitchAction", Enum.UserInputState.Begin, game)
		end

		function Tas.inputController:init()
			self:createCursor()

			UserInputService.MouseIconEnabled = false

			for _, Obj in getgc(true) do
				if typeof(Obj) == "table" and rawget(Obj, "activeMouseLockController") then
					self._mouseLockController = Obj.activeMouseLockController
					break
				end
			end

            local Old; Old = hookfunction(self._mouseLockController.DoMouseLockSwitch, newcclosure(function(...) -- idk bro fuck GameProcessed
                if not checkcaller() then return end
                return Old(...)
            end))
            self.DoMouseLockSwitch = Old

            self._shiftlockState = self._mouseLockController.isMouseLocked

            if self._shiftlockState then 
                self:setCursor("mouseLockedCursor")
            else 
                self:setCursor("arrowFarCursor")
            end

			for _, Obj in getgc(true) do
				if type(Obj) == "table" and rawget(Obj, "controls") then
					self._controls = Obj.controls
					break
				end
			end
            
			UserInputService.InputBegan:Connect(function(Input, GameProcessed)
                if Tas.core:isReplaying() then return end

				if Input.KeyCode == Enum.KeyCode.LeftShift then
					self:toggleShiftLock()
				elseif Input.KeyCode == Tas.core:getFowardKeybind() then
					Tas.core:freeze(true)

					if Tas.core:getSeekDirection() == 0 then
						Tas.core:setSeekDirection(1)
					end
				elseif Input.KeyCode == Tas.core:getBackKeybind() then
					Tas.core:freeze(true)

					if Tas.core:getSeekDirection() == 0 then
						Tas.core:setSeekDirection(-1)
					end
				end
			end)

			UserInputService.InputEnded:Connect(function(Input, GameProcessed)
				if Tas.core:isReplaying() then return end

				if Input.KeyCode == Tas.core:getFowardKeybind() then
					if Tas.core:getSeekDirection() == 1 then
						Tas.core:setSeekDirection(0)
					end
				elseif Input.KeyCode == Tas.core:getBackKeybind() then
					if Tas.core:getSeekDirection() == -1 then
						Tas.core:setSeekDirection(0)
					end
				end
			end)

			RunService.RenderStepped:Connect(function()
				if not Tas.core:isFrozen() then return end

				local FreezeFrame = Tas.core:getFreezeFrame() + Tas.core:getSeekDirection()
				local RecordingFrames = Tas.core:getRecordingFrames()

				Tas.core:setFreezeFrame(FreezeFrame < 1 and 1 or FreezeFrame > #RecordingFrames and #RecordingFrames or FreezeFrame)
			end)

			task.spawn(function()
				while true do
					self._cursorFrame.Image = self._cursor.icon
					self._cursorFrame.Size = self._cursor.size

					local MousePosition = UserInputService:GetMouseLocation()

					if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
						self._cursorFrame.Position = UDim2.fromOffset(
							(self._resolution.X / 2) + self._cursor.offset.X - GuiInset.X,
							(self._resolution.Y / 2) + self._cursor.offset.Y - GuiInset.Y - 18)
					else
						self._cursorFrame.Position = UDim2.fromOffset(MousePosition.X + self._cursor.offset.X - GuiInset.X,
							MousePosition.Y + self._cursor.offset.Y - GuiInset.Y - 36)
					end

					RunService.RenderStepped:Wait()
				end
			end)
		end
	end

	do -- core:
		function Tas.core:setForwardKeybind(Key)
			self._goForwardKey = Key
		end

		function Tas.core:getFowardKeybind()
			return self._goForwardKey
		end

		function Tas.core:setBackKeybind(Key)
			self._goBackKey = Key
		end

		function Tas.core:getBackKeybind()
			return self._goBackKey
		end

		function Tas.core:saveToFile(FileName)
			if #self._recordingFrames == 0 then return end

			local Success, Encoded = pcall(function()
				return HttpService:JSONEncode(self._recordingFrames)
			end)

			if Success then
				writefile(`TAS Files/{FileName}.json`, Encoded)
			end
		end

		function Tas.core:getFile(FileName)
			if not isfolder("TAS Files") then
				makefolder("TAS Files")
			end

			if not isfile(`TAS Files/{FileName}.json`) then return end

			local Success, Decoded = pcall(function()
				return HttpService:JSONDecode(readfile(`TAS Files/{FileName}.json`))
			end)

			if Success then
				return Decoded
			end
		end

		function Tas.core:syncTASFiles()
			if not request then
				return Interface:sendConsoleMessage("Your executor doesnt support requests!")
			end

			Interface:sendConsoleMessage("Checking TAS files...")

			if not isfolder("TAS Files") then
				makefolder("TAS Files")
			end

			local Result = request({
				Url = "https://api.github.com/repos/rxd977/Scripts/contents/Assets/ObbyRoyale",
				Method = "GET"
			})

			local Success, Files = pcall(function()
				return HttpService:JSONDecode(Result.Body)
			end)

			if not Success or not Files then
				return Interface:sendConsoleMessage("Failed to fetch TAS file list!")
			end

			local DownloadCount = 0

			for _, File in Files do
				if File.type ~= "file" or not File.name:match("%.json$") then continue end

				local FileName = File.name:gsub("%.json$", "")
				local FilePath = `TAS Files/{File.name}`

				if not isfile(FilePath) then
					Interface:sendConsoleMessage(`Downloading {File.name}...`)

					local DownloadResult = request({
						Url = File.download_url,
						Method = "GET"
					})

					if DownloadResult.StatusCode == 200 then
						writefile(FilePath, DownloadResult.Body)
						DownloadCount = DownloadCount + 1
						Interface:sendConsoleMessage(`Downloaded {File.name}`)
					else
						Interface:sendConsoleMessage(`Failed to download {File.name}`)
					end
				end
			end

			if DownloadCount > 0 then
				Interface:sendConsoleMessage(`Finished! Downloaded {DownloadCount} file(s)`)
			else
				Interface:sendConsoleMessage("All TAS files up to date!")
			end
		end

		function Tas.core:isUsingAllReplay()
			return self._isUsingAllReplay
		end

		function Tas.core:setSeekDirection(SeekDirection)
			self._seekDirection = SeekDirection
		end

		function Tas.core:getSeekDirection()
			return self._seekDirection
		end

		function Tas.core:setFreezeFrame(FreezeFrame)
			self._freezeFrame = FreezeFrame
		end

		function Tas.core:getFreezeFrame()
			return self._freezeFrame
		end

		function Tas.core:isFrozen()
			return self._isFrozen
		end

		function Tas.core:getRecordingFrames()
			return self._recordingFrames
		end

		function Tas.core:isReplaying()
			return self._isReplaying
		end

		function Tas.core:isRecording()
			return self._isRecording
		end

		function Tas.core:startRecording()
			if self._isRecording or self._isReplaying or self._isFrozen then return end

			self._isRecording = true
			self._recordingFrames = {}

			if setfpscap then setfpscap(60) end

			Tas.inputController:enableControls()

			task.spawn(function()
				while self._isRecording do
					if self._isFrozen then RunService.RenderStepped:Wait() continue end

					local Humanoid = Util:getHumanoid()
					if not Humanoid then RunService.RenderStepped:Wait() continue end

					local RootPart = Util:getRootPart()
					if not RootPart then RunService.RenderStepped:Wait() continue end

					Interface:setStatus("Recording")

					local Frame = {}

					Frame._rootPartCFrame = Util:roundTable(Util:cframeToTable(RootPart.CFrame), 3)
					Frame._rootPartVelocity = Util:roundTable(Util:vector3ToTable(RootPart.Velocity), 3)
					Frame._rootPartRotVelocity = Util:roundTable(Util:vector3ToTable(RootPart.RotVelocity), 3)
					Frame._cameraCFrame = Util:roundTable(Util:cframeToTable(CurrentCamera.CFrame), 3)
					Frame._zoom = Util:roundNumber(Tas.cameraController:getZoom(), 3)
					Frame._humanoidState = Humanoid:GetState().Value
					Frame._pose = Tas.animationController:getPose()
					Frame._animationQueue = Tas.animationController:getAnimationQueue()
					Frame._animationSpeed = Util:roundNumber(Tas.animationController:getAnimationSpeed(), 3)
					Frame._shiftlockState = Tas.inputController:getShiftLockState()
					Frame._mousePosition = Util:roundTable(Util:vector2ToTable(UserInputService:GetMouseLocation()), 3)

					table.insert(self._recordingFrames, Frame)

					Tas.animationController._animationQueue = {}

					RunService.RenderStepped:Wait()
				end
			end)
		end

		function Tas.core:stopRecording()
			if not self._isRecording or self._isReplaying then return end

			Interface:setStatus("Not Recording")

			self._isRecording = false
			Tas.animationController._animationQueue = {}
		end

		function Tas.core:startReplaying(Frames, UseAll)
			if self._isReplaying or self._isRecording then return end

			setthreadidentity(8)

			self._isReplaying = true
			self._isUsingAllReplay = UseAll

			Interface:setStatus("Replaying")

			Frames = Frames or self._recordingFrames

			Tas.animationController:setDisabled(true)
			Tas.inputController:disableControls()

			workspace.Gravity = 0

			local FrameIndex = 1

			task.spawn(function()
				while self._isReplaying do
					local Humanoid = Util:getHumanoid()
					if not Humanoid then RunService.Heartbeat:Wait() continue end

					local RootPart = Util:getRootPart()
					if not RootPart then RunService.Heartbeat:Wait() continue end

					local Frame = Frames[FrameIndex]
					if not Frame then RunService.Heartbeat:Wait() self:stopReplaying() continue end


					Tas.animationController:setDisabled(true)

					workspace.Gravity = 0

					Humanoid.WalkSpeed = 0
					Humanoid.JumpPower = 0

					if UseAll then
						Tas.cameraController:setCFrame(Util:tableToCFrame(Frame._cameraCFrame))
						Tas.cameraController:setZoom(Frame._zoom)
					end

					Humanoid:ChangeState(Frame._humanoidState)

					Tas.animationController:setPose(Frame._pose)

					for _, Animation in Frame._animationQueue do
						local AnimationName = Animation[1]
						local AnimationTime = Animation[2]

						if AnimationName == "walk" then
							if Humanoid.FloorMaterial ~= Enum.Material.Air and Frame._humanoidState ~= 3 then
								Tas.animationController:playAnimation("walk", AnimationTime, true)
							end
						else
							Tas.animationController:playAnimation(AnimationName, AnimationTime, true)
						end
					end

					pcall(function() Tas.animationController:setAnimationSpeed(Frame._animationSpeed) end)

					if UseAll then
						Tas.inputController:toggleShiftLock(Frame._shiftlockState)

						local Resolution = Tas.inputController:getResolution()
						local Cursor = Tas.inputController:getCursor()

						if not Frame._shiftlockState and Frame._zoom > 0.52 then
							mousemoveabs(Frame._mousePosition[1], Frame._mousePosition[2])
						else
							mousemoveabs((Resolution.X / 2) + Cursor.offset.X - GuiInset.X,
								(Resolution.Y / 2) + Cursor.offset.Y - GuiInset.Y - 36)
						end
					end

					RootPart.CFrame = Util:tableToCFrame(Frame._rootPartCFrame)

					FrameIndex = FrameIndex + 1

					RunService.Heartbeat:Wait()
				end
			end)

			task.spawn(function()
				while self._isReplaying do
					local Character = LocalPlayer.Character
					if not Character then RunService.Stepped:Wait() continue end

					local RootPart = Character:FindFirstChild("HumanoidRootPart")
					if not RootPart then RunService.Stepped:Wait() continue end

					if workspace.Gravity ~= DefaultGravity then
						for _, Obj in Character:GetChildren() do
							if not Obj:IsA("BasePart") then continue end

							Obj.CanCollide = false
						end
					end

					local Frame = Frames[FrameIndex]
					if not Frame then RunService.Stepped:Wait() continue end

					RootPart.CFrame =  Util:tableToCFrame(Frame._rootPartCFrame)

					RunService.Stepped:Wait()
				end
			end)
		end

		function Tas.core:stopReplaying()
			if not self._isReplaying or self._isRecording then return end

			local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
			local RootPart = Character:WaitForChild("HumanoidRootPart")

			Interface:setStatus("Not Recording")

			self._isReplaying = false

			RootPart.AssemblyLinearVelocity = Vector3.zero
			RootPart.AssemblyAngularVelocity = Vector3.zero

			Tas.inputController:enableControls()
			Tas.animationController:setDisabled(false)

			Character.Head.CanCollide = true
			Character.Torso.CanCollide = true
			Character.HumanoidRootPart.CanCollide = true
			Character.Humanoid.JumpPower = Tas.animationController:getOriginalJumpPower()
			Character.Humanoid.WalkSpeed = Tas.animationController:getOriginalWalkSpeed()

			workspace.Gravity = DefaultGravity

			Tas.animationController:playAnimation("idle", 0.1)
			Tas.animationController:setPose("Standing")
		end

		function Tas.core:freeze(State)
			State = if State == nil then not self._isFrozen else State

			if self._isReplaying or self._isFrozen == State then return end

			self._seekDirection = 0

			if not State then
				for I = #self._recordingFrames, self._freezeFrame, -1 do
					self._recordingFrames[I] = nil
				end

				self._isFrozen = false

				local RootPart = Util:getRootPart()
				if RootPart then RootPart.Anchored = false end

				return
			end

			Interface:setStatus("Frozen")

			self._isFrozen = true
			self._freezeFrame = #self._recordingFrames

			task.spawn(function()
				while self._isFrozen do
					local Humanoid = Util:getHumanoid()
					if not Humanoid then RunService.RenderStepped:Wait() continue end

					local RootPart = Util:getRootPart()
					if not RootPart then RunService.RenderStepped:Wait() continue end

					if self._freezeFrame == 0 or self._freezeFrame > #self._recordingFrames then RunService.RenderStepped:Wait() continue end

					local FreezeFrame = Util:roundNumber(self._freezeFrame, 0)
					local Frame = self._recordingFrames[FreezeFrame]

					local Pose
					local Animation

					for I = FreezeFrame, 1, -1 do
						if Pose and Animation then break end

						local Frame = self._recordingFrames[I]

						Pose = Frame._pose
						Animation = Frame._animationQueue[#Frame._animationQueue]
					end

					if Animation then
						if Animation[1] == "walk" then
							if Humanoid.FloorMaterial ~= Enum.Material.Air and Frame._humanoidState ~= 3 then
								Tas.animationController:playAnimation("walk", Animation[2], true)
							end
						else
							Tas.animationController:playAnimation(Animation[1], Animation[2], true)
						end
					end

					RootPart.Anchored = true

					pcall(function() Tas.animationController:playAnimation(Frame._animationSpeed) end)

					Tas.animationController:setPose(Pose)

					Humanoid:ChangeState(Frame._humanoidState)

					RootPart.Velocity = Util:tableToVector3(Frame._rootPartVelocity)
					RootPart.RotVelocity = Util:tableToVector3(Frame._rootPartRotVelocity)
					RootPart.CFrame = Util:tableToCFrame(Frame._rootPartCFrame)

					CurrentCamera.CFrame = Util:tableToCFrame(Frame._cameraCFrame)

					Tas.cameraController:setZoom(Frame._zoom)

					Tas.inputController:toggleShiftLock(Frame._shiftlockState)

					mousemoveabs(Frame._mousePosition[1], Frame._mousePosition[2])

					RunService.RenderStepped:Wait()
				end
			end)
		end
	end

	do -- loader:
		function Tas:load()
			self.animationController:init()
			self.cameraController:init()
			self.inputController:init()
		end
	end
end


do -- obby royale:

	do -- autoPlayController:
		local function ResolveId(Stage)
			local function ResolveMainModel(Model)
				if Model:GetAttribute("StageNum") then 
					return Model 
				elseif Model:FindFirstChildWhichIsA("Model") and Model:FindFirstChildWhichIsA("Model"):GetAttribute("StageNum") then 
					return Model:FindFirstChildWhichIsA("Model")
				end
				return nil
			end

			local MainModel = ResolveMainModel(Stage)
			if not MainModel then
				warn("Didnt find main model")
				return
			end

			local ID = MainModel:GetAttribute("ID") or Stage:GetAttribute("ID") 
			if ID then 
				return ID
			end

			local StageNum = MainModel:GetAttribute("StageNum")
			if not StageNum then 
				warn("Failed to get stage num")
				return 
			end

			local Difficulty = MainModel:GetAttribute("Difficulty") 
			if not Difficulty then 
				warn("Failed to get difficulty")
				return
			end

			local PartCount = MainModel:GetAttribute("PartCount") 
			if not PartCount then 
				warn("Failed to get part count")
				return
			end

			for _, StageModel in ObbyRoyale.tasController:getStages():GetChildren() do 
				local Model = ResolveMainModel(StageModel)
				if not Model then 
					continue 
				end

				if Model:GetAttribute("Difficulty") ~= Difficulty then 
					continue 
				end

				if Model:GetAttribute("StageNum") ~= StageNum then 
					continue
				end

				if Model:GetAttribute("PartCount") ~= PartCount then 
					continue 
				end

				return StageModel:GetAttribute("ID") or StageModel.Name
			end

			return nil
		end


		function ObbyRoyale.autoPlayController:setEnabled(State)
			self._isAutoPlayEnabled = State
		end

		function ObbyRoyale.autoPlayController:getSpawn()
			if not workspace.Arena:FindFirstChild("Stages") then return end

			local Stages = workspace.Arena:FindFirstChild("Stages")
			if not Stages then return end

			local Stage = Stages:WaitForChild(LocalPlayer.Name)

			local StartPosition = Stage.Settings.Start.Position

			local ClosestSpawn
			local LowestMagitude = math.huge

			for _, Obj in workspace.Arena.Spawns:GetChildren()  do
				local Magnitude = (StartPosition - Obj.Top.Position).Magnitude

				if Magnitude < LowestMagitude then
					ClosestSpawn = Obj
					LowestMagitude = Magnitude
				end
			end

			return ClosestSpawn
		end

		function ObbyRoyale.autoPlayController:stopAutoPlay()
			Tas.core:stopReplaying()
		end

		function ObbyRoyale.autoPlayController:startAutoPlay(StageId)
			setthreadidentity(8)

			local Frames = Tas.core:getFile(StageId)
			if not Frames then return end

			local Spawn = self:getSpawn()
			if not Spawn then return end

			local RootPart = Util:getRootPart()
			if not RootPart then return end

			local OldStartPosition = Util:tableToCFrame(Frames[1]._rootPartCFrame).Position

			local RelativeSpawn = (function()
				for _, Spawn in workspace.Arena.Spawns:GetChildren() do 
					if Spawn:GetAttribute("SpawnOrder") == 1 then 
						return Spawn
					end
				end
			end)()
			local StartPositionOffset = Vector3.new(0, OldStartPosition.Y - GameY, 0)
			local RelativeCFrame = RelativeSpawn.PrimaryPart.CFrame

			local function TransformCFrame(Cframe)
				local Old = Spawn.PrimaryPart.CFrame:ToWorldSpace(RelativeCFrame:ToObjectSpace(Util:tableToCFrame(Cframe)))
				local New = Spawn.PrimaryPart.CFrame:ToWorldSpace(RelativeCFrame:ToObjectSpace(Util:tableToCFrame(Cframe))) - StartPositionOffset

				return Util:cframeToTable(New)
			end

			for I = 1, #Frames do
				local Frame = Frames[I]

				Frame._rootPartCFrame, Frame._cameraCFrame = TransformCFrame(Frame._rootPartCFrame), TransformCFrame(Frame._cameraCFrame)
			end

			Interface:sendConsoleMessage(`Autoplay started ({StageId})`)

			Tas.core:startReplaying(Frames, Tas.core._isUsingAllReplay)
		end

		function ObbyRoyale.autoPlayController:startPracticeAutoPlay()
			local Stage = workspace.PracticeArena.Stage:FindFirstChildWhichIsA("Model")
			if not Stage then return end 

			local StageId = ResolveId(Stage)
			if not StageId then 
				warn("Failed to get stage id for instance")
				return
			end

			local Frames = Tas.core:getFile(StageId)
			if not Frames then
				Interface:sendConsoleMessage(`No TAS for stage {StageId}`)
				return
			end

			local StartPart = workspace:FindFirstChild("PracticeArena") and workspace.PracticeArena.Start.PrimaryPart
			if not StartPart then
				Interface:sendConsoleMessage("PracticeArena.Start not found")
				return
			end

			local FramesCopy = {}
			for I, Frame in Frames do
				FramesCopy[I] = table.clone(Frame)
			end

			local OldStartPosition = Util:tableToCFrame(FramesCopy[1]._rootPartCFrame).Position
			local StartPositionOffset = Vector3.new(0, OldStartPosition.Y - GameY, 0)
			local RelativeSpawn = (function()
				for _, Spawn in workspace.Arena.Spawns:GetChildren() do 
					if Spawn:GetAttribute("SpawnOrder") == 1 then 
						return Spawn
					end
				end
			end)()
			local RelativeCFrame = RelativeSpawn.PrimaryPart.CFrame

			local function TransformCFrame(Cframe)
				local Old = workspace.PracticeArena.Start.PrimaryPart.CFrame:ToWorldSpace(RelativeCFrame:ToObjectSpace(Util:tableToCFrame(Cframe)))
				local New = workspace.PracticeArena.Start.PrimaryPart.CFrame:ToWorldSpace(RelativeCFrame:ToObjectSpace(Util:tableToCFrame(Cframe))) - StartPositionOffset

				return Util:cframeToTable(New)
			end

			for _, Frame in FramesCopy do
				Frame._rootPartCFrame = TransformCFrame(Frame._rootPartCFrame)
				Frame._cameraCFrame   = TransformCFrame(Frame._cameraCFrame)
			end

			Interface:sendConsoleMessage(`Practice autoplay started ({StageId})`)
			Tas.core:startReplaying(FramesCopy, Tas.core._isUsingAllReplay)
		end

		function ObbyRoyale.autoPlayController:init()
			task.wait()

			workspace.Arena.Stages.ChildAdded:Connect(function(Instance)
				if Instance.Name ~= LocalPlayer.Name or not self._isAutoPlayEnabled then return end

				local StageId = ResolveId(Instance)
				if not StageId then 
					warn("Failed to find id for instance")
					return
				end

				print(`Got {StageId}`)

				self:startAutoPlay(StageId)
			end)

			workspace.Preloaded.ChildAdded:Connect(function(Instance)
				if Instance.Name ~= LocalPlayer.Name then return end

				self:stopAutoPlay()
			end)
		end
	end

	do
		function ObbyRoyale.tasController:hookPracticeUI()
			if self._isPracticeUIHooked then return end

			local OldOpen = MainUIController.Open
			MainUIController.Open = function(self, Menu)
				if Menu == PlayerGui.MainUI.PracticeUI and not checkcaller() then return end

				return OldOpen(self, Menu)
			end
			self._oldOpenUI = OldOpen

			local OldClose = MainUIController.Close
			MainUIController.Close = function(self, Menu)
				if Menu == PlayerGui.MainUI.PracticeUI and not checkcaller() then return end

				return OldClose(self, Menu)
			end
			self._oldCloseUI = OldClose

			self._isPracticeUIHooked = true
		end

		function ObbyRoyale.tasController:unHookPracticeUI()
			if not self._isPracticeUIHooked then return end

			MainUIController.Open = self._oldOpenUI
			MainUIController.Close = self._oldCloseUI

			self._isPracticeUIHooked = false
		end

		function ObbyRoyale.tasController:getStageDifficulty(StageId)
			for _, Difficulty in OrUtils.Stages do
				for _, Stage in Difficulty.Stages do
					if Stage.ID ~= tonumber(StageId) then continue end

					return Difficulty.Difficulty
				end
			end
		end

		function ObbyRoyale.tasController:getStages()
			return self._stages
		end

		function ObbyRoyale.tasController:loadStages()
			local Stages = InsertService:LoadLocalAsset("rbxassetid://96197253083956")
			Stages.Parent = ReplicatedStorage

			self._stages = Stages
		end

		function ObbyRoyale.tasController:selectStage()
			if self._isSelectingStage then return end

			self._isSelectingStage = true

			if PlayerGui.MainUI.PracticeUI.Visible then
				MainUIController:Close(PlayerGui.MainUI.PracticeUI)

				task.wait(0.5)
			end

			self:hookPracticeUI()

			local function createLabel(Text, Position, Color, Parent)
				local Completed = Instance.new("TextLabel")
				Completed.Text = Text
				Completed.AnchorPoint = Vector2.new(0.5, 0.5)
				Completed.Position = Position
				Completed.Size = UDim2.fromScale(1, 0.1)
				Completed.TextColor3 = Color
				Completed.BackgroundTransparency = 1
				Completed.TextSize = 20
				Completed.Font = Enum.Font.FredokaOne
				Completed.Parent = Parent

				local Stroke = Instance.new("UIStroke")
				Stroke.Thickness = 2
				Stroke.Parent = Completed
			end

			local OldPopulateStages; OldPopulateStages = hookfunction(self._practiceENV.populateStages, newcclosure(function(...)
				OldPopulateStages(...)

				task.spawn(function()
					for _, StageFrame in PlayerGui.MainUI.PracticeUI.Stages.Grid:GetChildren() do
						if not StageFrame:IsA("GuiButton") then continue end

						if Tas.core:getFile(StageFrame.Name) then
							createLabel("Completed!", UDim2.fromScale(0.5, 0.85), Color3.fromRGB(0, 255, 0), StageFrame)
						end

						createLabel(StageFrame.Name, UDim2.fromScale(0.5, 0.1), Color3.fromRGB(255, 255, 255), StageFrame)

						hookfunction(getconnections(StageFrame.Load.LoadButton.MouseButton1Click)[1].Function, newcclosure(function()
							Interface._createPopup:Fire(StageFrame.Name)
						end))

						task.wait()
					end
				end)
			end))
			self._oldPopulateStages = OldPopulateStages

			self._practiceENV.back()

			PlayerGui.MainUI.PracticeUI.DifficultyPick.Difficulties.CanvasPosition = Vector2.zero

			ObbyRoyale.core:unlockPracticeStages()

			for _, TextLabel in PlayerGui.MainUI.PracticeUI.DifficultyPick:GetChildren() do
				if not TextLabel:IsA("TextLabel") then continue end

				if TextLabel.Text == "Practice Stages" then
					TextLabel.Text = "Select Stage"
				else
					TextLabel.Text = "Select stage to TAS"
				end
			end

			PlayerGui.MainUI.PracticeUI.Close.Visible = false
			PlayerGui.MainUI.PracticeUI.Visible = true

			MainUIController:Open(PlayerGui.MainUI.PracticeUI)
		end

		function ObbyRoyale.tasController:stopSelectingStage()
			setthreadidentity(8)

			if not self._isSelectingStage then return end

			self._isSelectingStage = false

			MainUIController:Close(PlayerGui.MainUI.PracticeUI)

			self._practiceENV.back()

			if not self._isTASSING then
				self:unHookPracticeUI()
			end

			hookfunction(self._practiceENV.populateStages, self._oldPopulateStages)

			for _, TextLabel in PlayerGui.MainUI.PracticeUI.DifficultyPick:GetChildren() do
				if not TextLabel:IsA("TextLabel") then continue end

				if TextLabel.Text == "Select Stage" then
					TextLabel.Text = "Practice Stages"
				else
					TextLabel.Text = "In this area you can practice stages from any of the difficulties in game"
				end
			end

			PlayerGui.MainUI.PracticeUI.Visible = false
			PlayerGui.MainUI.PracticeUI.Close.Visible = true
		end

		function ObbyRoyale.tasController:selectNextStage()
			local Stages = {}

			for _, Difficulty in OrUtils.Stages do
				for _, Stage in Difficulty.Stages do
					table.insert(Stages, Stage.ID)
				end
			end

			local Nearest = nil

			for _, Stage in Stages do
				if Stage > tonumber(self._loadedStage or 0) and (Nearest == nil or Stage < Nearest) then
					Nearest = Stage
				end
			end

			if not Nearest then
				Nearest = 1
			end

			self:setupTAS(Nearest)
		end

		function ObbyRoyale.tasController:loadStage(StageId)
			local StageModel = self._stages[StageId]:Clone()
			StageModel.Parent = PlayerGui.LoadedStage

			self._loadedStage = StageId

			return StageModel
		end

		function ObbyRoyale.tasController:setupTAS(StageId, DontDisableControls)
			setthreadidentity(8)

			self._isTASSING = true

			self:stopSelectingStage()
			self:loadStage(StageId)

			Interface:setStage(StageId)

			if not DontDisableControls then
				Tas.inputController:disableControls()
			end

			local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
			Character:PivotTo(workspace.PracticeArena.Start.PrimaryPart.CFrame + Vector3.new(0, 5, 0))
		end

		function ObbyRoyale.tasController:init()
			self:loadStages()

			--self._practiceENV = getsenv(PlayerGui.MainUI.MainUIController.PracticeController)
		end
	end

	do -- core:
		function ObbyRoyale.core:unlockPracticeStages()
			setthreadidentity(8)

			if not firesignal or not getupvalue or not setupvalue then return Interface:sendConsoleMessage("Your executor doesnt support this!") end

			if self._unlockedPracticeStages then return Interface:sendConsoleMessage("Practice stages already unlocked!") end

			Interface:sendConsoleMessage("Unlocked practice stages!")

			firesignal(ReplicatedStorage.ServerCommunication.Events.Practice.Purchases.AllUnlocked.OnClientEvent)
			
			self._unlockedPracticeStages = true
		end

		function ObbyRoyale.core:setDisableReset(State)
			self._isResetDisabled = State
		end

		function ObbyRoyale.core:joinProServer()
			if self._isJoiningPro then return Interface:sendConsoleMessage("Join pro server...") end

			self._isJoiningPro = true

			Interface:sendConsoleMessage("Join pro server...")

			TeleportService:Teleport(17205456753, LocalPlayer)

			local Connection; Connection = LocalPlayer.OnTeleport:Connect(function(TeleportState)
				if TeleportState == Enum.TeleportState.Failed then
					Connection:Disconnect()

					Interface:sendConsoleMessage("Teleport failed!")

					self._isJoiningPro = false
				end
			end)
		end

		function ObbyRoyale.core:rejoin()
			if self._isRejoining or self._isServerhopping then return Interface:sendConsoleMessage("Already rejoining") end

			self._isRejoining = true

			Interface:sendConsoleMessage("Rejoining...")

			TeleportService:TeleportToPlaceInstance(PlaceId, JobId)

			local Connection; Connection = LocalPlayer.OnTeleport:Connect(function(TeleportState)
				if TeleportState == Enum.TeleportState.Failed then
					Connection:Disconnect()

					Interface:sendConsoleMessage("Teleport failed!")

					self._isRejoining = false
				end
			end)
		end

		function ObbyRoyale.core:serverhop()
			if not request then return Interface:sendConsoleMessage("Your executor doesnt support requests!") end

			if self._isServerhopping or self._isRejoining then return Interface:sendConsoleMessage("Already serverhopping!") end

			self._isServerhopping = true

			Interface:sendConsoleMessage("Searching for server...")

			local Result = request({Url =`https://games.roblox.com/v1/games/{game.PlaceId}/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true`})

			local Success, Body = pcall(function()
				return HttpService:JSONDecode(Result.Body)
			end)

			if Success and Body and Body.data then
				local Servers = {}

				for _, Server in Body.data do
					if typeof(Server) == "table" and tonumber(Server.playing) and tonumber(Server.maxPlayers) and Server.playing < Server.maxPlayers and Server.id ~= JobId then
						table.insert(Servers, 1, Server.id)
					end
				end

				if #Servers > 0 then
					Interface:sendConsoleMessage("Found server!")

					task.wait()

					TeleportService:TeleportToPlaceInstance(PlaceId, Servers[Rng:NextInteger(1, #Servers)], LocalPlayer)

					local Connection; Connection = LocalPlayer.OnTeleport:Connect(function(TeleportState)
						if TeleportState == Enum.TeleportState.Failed then
							Connection:Disconnect()

							Interface:sendConsoleMessage("Teleport failed!")
						end
					end)
				else
					Interface:sendConsoleMessage("No servers available!")
				end
			else
				Interface:sendConsoleMessage("Error occured when searching for server!")
			end

			self._isServerhopping = false
		end
	end

	do -- loader:
		function ObbyRoyale:load()
			self.tasController:init()
			self.autoPlayController:init()
			--self.core:init()
		end
	end
end

--[[
for i,v in getconnections(game.Players.LocalPlayer.PlayerGui.LoadedStage.ChildAdded) do
	v:Disable()  
end

local AdService = game:GetService("AdService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = game.Players.LocalPlayer

local info = RS.Info.Stages
local load = RS:WaitForChild("ServerCommunication"):WaitForChild("Requests"):WaitForChild("Practice"):WaitForChild("Load")
local rewardedAdPractice = RS:WaitForChild("ServerCommunication"):WaitForChild("Events"):WaitForChild("Player"):WaitForChild("RewardedAdPractice")
local getUnlocked = RS:WaitForChild("ServerCommunication"):WaitForChild("Requests"):WaitForChild("Practice"):WaitForChild("GetUnlocked")

local DIFFICULTY_ORDER = {
	"Effortless",
	"VeryEasy",
	"Easy",
	"Medium",
	"Hard",
	"Difficult",
	"Challenging",
	"Intense",
	"Insane",
	"Extreme",
	"Nightmare",
	"Hell",
	"Demon",
	"Master"
}

local PRICES = {
	Effortless  = { Price = 0,  FreeVIP = true  },
	VeryEasy    = { Price = 0,  FreeVIP = true  },
	Easy        = { Price = 0,  FreeVIP = true  },
	Medium      = { Price = 29, FreeVIP = true  },
	Hard        = { Price = 29, FreeVIP = true  },
	Difficult   = { Price = 39, FreeVIP = true  },
	Challenging = { Price = 39, FreeVIP = true  },
	Intense     = { Price = 49, FreeVIP = true  },
	Insane      = { Price = 49, FreeVIP = true  },
	Extreme     = { Price = 69, FreeVIP = true  },
	Nightmare   = { Price = 79, FreeVIP = false },
	Hell        = { Price = 89, FreeVIP = false },
	Demon       = { Price = 99, FreeVIP = false },
	Master      = { Price = 99, FreeVIP = false },
}

local TIMEOUT = 30

print("[StageLoader] Fetching unlocked difficulties...")
local unlockedDiffs = getUnlocked:InvokeServer()
print("[StageLoader] Unlocked:", table.concat(unlockedDiffs, ", "))

local isVIP = LocalPlayer.Data:GetAttribute("IsVIP")
print("[StageLoader] IsVIP:", isVIP)

local function isAdAvailable()
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	if not ok then
		print("[StageLoader] Ad availability check error:", result)
		return false
	end
	print("[StageLoader] Ad result:", result.AdAvailabilityResult)
	return result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
end

local function isDifficultyUnlocked(name)
	local p = PRICES[name]
	if not p or p.Price == 0 then return true end
	return table.find(unlockedDiffs, name) or (isVIP and p.FreeVIP)
end

local modules = {}
local function GetModule(name)
	if modules[name] then return modules[name] end
	modules[name] = require(info[name])
	return modules[name]
end

local TEMP = workspace:FindFirstChild("Stages") or Instance.new("Folder")
TEMP.Name = "Stages"
TEMP.Parent = workspace

local totalLoaded = 0
local totalSkipped = 0

print("[StageLoader] Starting stage load...")

for _, name in DIFFICULTY_ORDER do
	local unlocked = isDifficultyUnlocked(name)

	if not unlocked then
		print("[StageLoader] Checking ad availability for locked difficulty:", name)
		if not isAdAvailable() then
			print("[StageLoader] Skipping difficulty (locked, no ad):", name)
			totalSkipped += 1
			continue
		end
	end

	local stageList = GetModule(name)
	print(string.format("[StageLoader] Difficulty: %s | Unlocked: %s | Stages: %d", name, tostring(unlocked), #stageList))

	for _, stageInfo in stageList do
		local thread = coroutine.running()
		local timedOut = false

		local connection
		connection = LocalPlayer.PlayerGui.LoadedStage.ChildAdded:Connect(function(desc)
			print(string.format("[StageLoader] ChildAdded fired: %s (waiting for stage %s)", desc.Name, stageInfo.ID))
			if timedOut then
				print("[StageLoader] ChildAdded fired but already timed out, ignoring")
				return
			end
			connection:Disconnect()
			task.wait()
			desc.Name = stageInfo.ID
			desc.Parent = TEMP
			print(string.format("[StageLoader] Moved %s → Stages.%s", desc.Name, stageInfo.ID))
			coroutine.resume(thread)
		end)

		if unlocked then
			print(string.format("[StageLoader] Loading stage %s (%s)", stageInfo.ID, name))
			load:FireServer(stageInfo.ID)
		else
			if not isAdAvailable() then
				print(string.format("[StageLoader] No ad available for stage %s, skipping difficulty %s", stageInfo.ID, name))
				timedOut = true
				connection:Disconnect()
				totalSkipped += 1
				break
			end
			print(string.format("[StageLoader] Loading stage %s (%s) via ad", stageInfo.ID, name))
			rewardedAdPractice:FireServer(stageInfo.ID)
		end

		coroutine.yield()

		if not timedOut then
			totalLoaded += 1
			print(string.format("[StageLoader] Saved stage %s → Stages.%s (total: %d)", stageInfo.ID, stageInfo.ID, totalLoaded))
		end
	end
end

print(string.format("[StageLoader] Done. Loaded: %d | Skipped: %d", totalLoaded, totalSkipped))
]]

do -- hooks:
	do -- namecall hook:
		local OldNamecall; OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local Args = {...}
			local Method = getnamecallmethod()

			if Method == "FireServer" and tostring(self) == "Load" then 
				local StageId = Args[1]

				if ObbyRoyale.core._unlockedPracticeStages then
					ObbyRoyale.tasController._stages:FindFirstChild(StageId):Clone().Parent = PlayerGui.LoadedStage
				end
			elseif Method == "FireServer" and tostring(self) == "Reset" and ObbyRoyale.core._isResetDisabled then
				return
			end

			return OldNamecall(self, ...)
		end))
	end
end
do -- Interface:
	function Interface:setStatus(Status)
		-- StatusLabel:SetValue(`Status: {Status}`)
	end

	function Interface:setStage(StageId)
		--setthreadidentity(8)
		-- StageLabel:SetValue(`Stage: {StageId} | {ObbyRoyale.tasController:getStageDifficulty(StageId)}`)
	end

	function Interface:sendConsoleMessage(Text)
		Library:Notify{
			Title = "Console",
			Content = `Window -> {Text}`,
			Duration = 5,
		}
	end

	function Interface:createWindow()
		local Window = Library:CreateWindow{
			Title = "Obby Royale TAS",
			TabWidth = 160,
			Size = UDim2.fromOffset(580, 460),
			Acrylic = true,
			Theme = "Dark",
			MinimizeKey = Enum.KeyCode.LeftControl,
		}

		self._window = Window
	end

	function Interface:createTabs()
		self._tabs["main"] = self._window:CreateTab{ Title = "Auto Play", Icon = "play" }
		self._tabs["misc"] = self._window:CreateTab{ Title = "Misc", Icon = "wrench" }
		self._tabs["credits"] = self._window:CreateTab{ Title = "Credits", Icon = "info" }
		self._tabs["settings"] = self._window:CreateTab{ Title = "Settings", Icon = "settings" }
	end

	function Interface:createPopup(StageId)
		setthreadidentity(8)

		self._window:Dialog{
			Title = PlaceName,
			Content = "Are you sure you would like to restart?",
			Buttons = {
				{
					Title = "Yes",
					Callback = function()
						task.spawn(ObbyRoyale.tasController.setupTAS, ObbyRoyale.tasController, StageId)
					end,
				},
				{
					Title = "No",
					Callback = function() end,
				},
			},
		}
	end

	function Interface:setupAutoPlayRegion()
		local Tab = self._tabs["main"]

		Tab:CreateToggle("AutoPlayEnabled", {
			Title = "Auto Play",
			Default = false,
			Callback = function(Value)
				ObbyRoyale.autoPlayController:setEnabled(Value)
			end,
		})

		Tab:CreateButton{
			Title = "Force Stop",
			Callback = function()
				ObbyRoyale.autoPlayController:stopAutoPlay()
			end,
		}

		Tab:CreateButton{
			Title = "Play Again",
			Callback = function()
				ObbyRoyale.autoPlayController:stopAutoPlay()
				task.wait()
				ObbyRoyale.autoPlayController:startAutoPlay()
			end,
		}

		Tab:CreateButton{
			Title = "Replay Practice",
			Callback = function()
				if ObbyRoyale.autoPlayController._isAutoPlayEnabled then return end
				ObbyRoyale.autoPlayController:startPracticeAutoPlay()
			end,
		}

		Tab:CreateToggle("UseAllInputs", {
			Title = "Use All Inputs",
			Default = false,
			Callback = function(Value)
				Tas.core._isUsingAllReplay = Value
			end,
		})
	end

	--[==[
	function Interface:setupTASRegion()
		local Tab = self._tabs["main"]

		Tab:CreateButton{ Title = "Select Stage", Callback = function() ObbyRoyale.tasController:selectStage() end }
		Tab:CreateButton{ Title = "Stop Selecting", Callback = function() ObbyRoyale.tasController:stopSelectingStage() end }

		Tab:CreateKeybind("StartRecordingKey", { Title = "Start Recording", Default = "E", Mode = "Hold",
			Callback = function()
				if not ObbyRoyale.tasController._isTASSING or Tas.core._isRecording then return end
				if ObbyRoyale.tasController._loadedStage then
					ObbyRoyale.tasController:setupTAS(ObbyRoyale.tasController._loadedStage, true)
				end
				task.wait()
				Tas.core:startRecording()
			end,
		})
		Tab:CreateKeybind("StopRecordingKey", { Title = "Stop Recording", Default = "Q", Mode = "Hold",
			Callback = function()
				if not ObbyRoyale.tasController._isTASSING then return end
				Tas.core:stopRecording()
			end,
		})
		Tab:CreateKeybind("StartReplayingKey", { Title = "Start Replaying", Default = "U", Mode = "Hold",
			Callback = function()
				if not ObbyRoyale.tasController._isTASSING then return end
				Tas.core:startReplaying(Tas.core._recordingFrames, true)
			end,
		})
		Tab:CreateKeybind("StopReplayingKey", { Title = "Stop Replaying", Default = "I", Mode = "Hold",
			Callback = function()
				if not ObbyRoyale.tasController._isTASSING then return end
				Tas.core:stopReplaying()
			end,
		})
		Tab:CreateKeybind("FreezeKey", { Title = "Freeze", Default = "F", Mode = "Hold",
			Callback = function() Tas.core:freeze() end,
		})
		Tab:CreateKeybind("GoBackKey", { Title = "Go Back", Default = "T", Mode = "Hold",
			ChangedCallback = function(New) Tas.core:setBackKeybind(New) end,
		})
		Tab:CreateKeybind("GoForwardKey", { Title = "Go Forward", Default = "Y", Mode = "Hold",
			ChangedCallback = function(New) Tas.core:setForwardKeybind(New) end,
		})
		Tab:CreateKeybind("SaveRecordingKey", { Title = "Save Recording", Default = "P", Mode = "Hold",
			Callback = function() Tas.core:saveToFile(ObbyRoyale.tasController._loadedStage) end,
		})
	end
	--]==]

	function Interface:setupMiscRegion()
		local Tab = self._tabs["misc"]

		Tab:CreateButton{
			Title = "Unlock Practice Stages",
			Callback = function()
				ObbyRoyale.core:unlockPracticeStages()
			end,
		}

		Tab:CreateToggle("DisableReset", {
			Title = "Disable Reset",
			Default = false,
			Callback = function(Value)
				ObbyRoyale.core:setDisableReset(Value)
			end,
		})

		Tab:CreateButton{
			Title = "Join Pro Server",
			Callback = function()
				ObbyRoyale.core:joinProServer()
			end,
		}

		Tab:CreateButton{
			Title = "Rejoin",
			Callback = function()
				ObbyRoyale.core:rejoin()
			end,
		}

		Tab:CreateButton{
			Title = "Serverhop",
			Callback = function()
				ObbyRoyale.core:serverhop()
			end,
		}

		Tab:CreateButton{
			Title = "Anti AFK",
			Callback = function()
				local VirtualUser = game:GetService("VirtualUser")
				LocalPlayer.Idled:Connect(function()
					VirtualUser:CaptureController()
					VirtualUser:ClickButton2(Vector2.new())
				end)
			end,
		}
	end

	function Interface:setupCreditsRegion()
		local Tab = self._tabs["credits"]

		Tab:CreateParagraph("Credits", {
			Title = "Credits",
			Content = "Main Developer: Killa0731\nOther: Tasability for most of the TAS functionality",
		})
	end

	function Interface:setupSettingsRegion()
		local SettingsTab = self._tabs["settings"]

		InterfaceManager:SetLibrary(Library)
		SaveManager:SetLibrary(Library)

		SaveManager:IgnoreThemeSettings()
		SaveManager:SetIgnoreIndexes{ "MenuKeybind" }

		InterfaceManager:SetFolder("ObbyRoyale")
		SaveManager:SetFolder("ObbyRoyale")

		InterfaceManager:BuildInterfaceSection(SettingsTab)
		SaveManager:BuildConfigSection(SettingsTab)
			
		self._window:SelectTab(1)

		SaveManager:LoadAutoloadConfig()
	end

	function Interface:load()
		self:createWindow()
		self:createTabs()
		self:setupCreditsRegion()
		self:setupAutoPlayRegion()
		self:setupMiscRegion()
		self:setupSettingsRegion()

		getgenv().onExecuted = function()
			self:sendConsoleMessage("Do not execute twice!")
		end
	end
end

do -- main loader:
	Interface:load()
	Tas:load()
	ObbyRoyale:load()

	Tas.core:syncTASFiles()

	Interface:sendConsoleMessage("Script successfully loaded!")
end
