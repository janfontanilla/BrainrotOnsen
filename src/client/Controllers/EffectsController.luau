--!strict
-- Little bursts that make actions feel good (2026-10-06), on the client only:
--   * a sparkle burst on the Merge! pad when the player's brainrots merge (the
--     Brainrots attribute drops while TotalBrainrots does not);
--   * a burst of gold coins on the Collect Cash pad when Cash is collected (the
--     "cash" Notify popup that says "Collected").
-- Effects only; the server already did the work.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local MERGE_COLOR = Color3.fromRGB(255, 230, 120)
local COIN_COLOR = Color3.fromRGB(255, 204, 40)
local MERGE_COUNT = 40
local COIN_COUNT = 30
local NEAR_PAD = 10 -- studs

local player = Players.LocalPlayer

local EffectsController = {}

local function myPart(name: string): BasePart?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and typeof(index) == "number" and plots:FindFirstChild(`Plot{index}`)
	local part = plot and plot:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

-- One-shot burst of `count` particles from the top of `part`.
local function burst(part: BasePart, color: Color3, count: number, coins: boolean)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, part.Size.Y / 2 + 0.5, 0)
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = if coins then 0.3 else 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if coins then 1.2 else 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, if coins then -40 else -10, 0)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

function EffectsController:Start()
	local function number(name: string): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else 0
	end
	local lastBrainrots = number("Brainrots")
	local lastTotal = number("TotalBrainrots")
	player:GetAttributeChangedSignal("Brainrots"):Connect(function()
		local now, total = number("Brainrots"), number("TotalBrainrots")
		if now < lastBrainrots and total <= lastTotal then
			local pad = myPart("MergePad")
			if pad then
				burst(pad, MERGE_COLOR, MERGE_COUNT, false)
			end
		end
		lastBrainrots, lastTotal = now, total
	end)
	player:GetAttributeChangedSignal("TotalBrainrots"):Connect(function()
		lastTotal = number("TotalBrainrots")
	end)

	Remotes.event("Notify").OnClientEvent:Connect(function(message: unknown, kind: unknown)
		if kind == "cash" and typeof(message) == "string" and string.find(message, "Collected") then
			-- The group reward says "Collected" too: only burst when standing at the pad.
			local pad = myPart("CollectCashPad")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if pad and root and root:IsA("BasePart") and (root.Position - pad.Position).Magnitude < NEAR_PAD then
				burst(pad, COIN_COLOR, COIN_COUNT, true)
			end
		end
	end)
end

return EffectsController
