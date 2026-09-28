--!strict
-- Pad polish: a pad sinks while someone stands on it and springs back up when
-- they step off. The server sets the Pressed attribute; this only animates.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local PAD_TAG = "Pad" -- matches Plots.PAD_TAG on the server
local PRESS_DEPTH = 0.3
local PRESS_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local PadController = {}

local function setup(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local pad = instance
	local rest = pad.CFrame
	local function update()
		local pressed = pad:GetAttribute("Pressed") == true
		local goal = if pressed then rest * CFrame.new(0, -PRESS_DEPTH, 0) else rest
		TweenService:Create(pad, if pressed then PRESS_INFO else RELEASE_INFO, { CFrame = goal }):Play()
	end
	pad:GetAttributeChangedSignal("Pressed"):Connect(update)
	if pad:GetAttribute("Pressed") == true then
		update()
	end
end

function PadController:Start()
	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		setup(pad)
	end
	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(setup)
end

return PadController
