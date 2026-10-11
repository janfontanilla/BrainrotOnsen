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
-- Each purchase flash lasts half a second, with the click (2026-10-11, user).
local FLASH_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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

	-- Purchase flash and the red "can't buy" glow: the pad's own colour (a Highlight was
	-- used first, but Roblox only draws a limited number of them and these were dropped).
	local baseColor = pad.Color
	local flashing = false
	local colorTween: Tween? = nil
	local function setColor(color: Color3, info: TweenInfo?)
		if colorTween then
			colorTween:Cancel()
		end
		if info then
			colorTween = TweenService:Create(pad, info, { Color = color });
			(colorTween :: Tween):Play()
		else
			pad.Color = color
		end
	end
	pad:GetPropertyChangedSignal("Color"):Connect(function()
		-- The server recolours pads (e.g. "Owned"): remember that as the resting colour.
		if not flashing and pad:GetAttribute("Denied") ~= true then
			baseColor = pad.Color
		end
	end)
	pad:GetAttributeChangedSignal("BuyFlash"):Connect(function()
		if pad:GetAttribute("Denied") == true then
			return
		end
		-- A little bounce with each purchase while it stays pressed.
		if pad:GetAttribute("Pressed") == true then
			local down = rest * CFrame.new(0, -PRESS_DEPTH, 0)
			pad.CFrame = down * CFrame.new(0, -PRESS_DEPTH * 0.6, 0)
			TweenService:Create(pad, PRESS_INFO, { CFrame = down }):Play()
		end
		flashing = true
		setColor(BOUGHT_COLOR)
		setColor(baseColor, FLASH_INFO)
		task.delay(FLASH_INFO.Time, function()
			flashing = false
		end)
	end)
	pad:GetAttributeChangedSignal("Denied"):Connect(function()
		if pad:GetAttribute("Denied") == true then
			flashing = true
			setColor(DENIED_COLOR)
		else
			setColor(baseColor, FLASH_INFO)
			task.delay(FLASH_INFO.Time, function()
				flashing = false
			end)
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
