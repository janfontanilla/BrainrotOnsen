--!strict
-- Pad polish: a pad sinks while someone stands on it and springs back up when
-- they step off. Buy pads also flash green on every purchase (BuyFlash, a
-- counter) and glow red while the player can't buy any more (Denied) until they step
-- off (2026-10-10, user). The server sets the attributes; this only animates.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local PAD_TAG = "Pad" -- matches Plots.PAD_TAG on the server
local PRESS_DEPTH = 0.3
local PRESS_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLASH_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOUGHT_COLOR = Color3.fromRGB(90, 255, 110)
local DENIED_COLOR = Color3.fromRGB(255, 50, 40)

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

	-- Purchase flash and the red "can't buy" glow, as a Highlight over the pad.
	local glow: Highlight? = nil
	local function highlight(): Highlight
		if not glow or glow.Parent == nil then
			local h = Instance.new("Highlight")
			h.Name = "PadGlow"
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.OutlineTransparency = 1
			h.FillTransparency = 1
			h.Adornee = pad
			h.Parent = pad
			glow = h
		end
		return glow :: Highlight
	end
	pad:GetAttributeChangedSignal("BuyFlash"):Connect(function()
		if pad:GetAttribute("Denied") == true then
			return
		end
		local h = highlight()
		h.FillColor = BOUGHT_COLOR
		h.FillTransparency = 0.2
		TweenService:Create(h, FLASH_INFO, { FillTransparency = 1 }):Play()
	end)
	pad:GetAttributeChangedSignal("Denied"):Connect(function()
		local h = highlight()
		if pad:GetAttribute("Denied") == true then
			h.FillColor = DENIED_COLOR
			h.FillTransparency = 0.35
		else
			TweenService:Create(h, FLASH_INFO, { FillTransparency = 1 }):Play()
		end
	end)
end

function PadController:Start()
	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		setup(pad)
	end
	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(setup)
end

return PadController
