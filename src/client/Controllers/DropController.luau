--!strict
-- Drops: floats every drop from its brainrot down the slide, river and channel
-- into the pool along the path the server wrote on it (Shared.DropPath), then
-- bobs it there. The server keeps the part still at its resting point.
-- Asks the server to collect a drop in the player's own plot when the character
-- walks over it, wherever it is on its path. The server re-checks ownership and
-- distance.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local DropPath = require(Shared.DropPath)

local player = Players.LocalPlayer

local RETRY_AFTER = 1 -- seconds before asking again for a drop the server has not removed
local MAX_HEIGHT_GAP = 6 -- studs between root part and drop that still counts as walking over it
local GAIN_COMBINE = 0.6 -- pickups this close together add into one "+X"
local GAIN_HOLD = 0.5 -- seconds the "+X" stays before floating off
local GAIN_COLOR = Color3.fromRGB(150, 255, 110)
local GAIN_STROKE = Color3.fromRGB(25, 70, 15)

type Tracked = {
	path: { Vector3 },
	flowAt: number, -- server time the drop appeared
	phase: number,
}

local DropController = {}

-- Drop parts, plus lucky block models (animated the same way, never collected
-- through CollectDrop: the server picks those up itself).
local tracked: { [PVInstance]: Tracked } = {}
local requested: { [PVInstance]: number } = {}

local function track(child: Instance)
	if not (child:IsA("BasePart") or child:IsA("Model")) then
		return
	end
	local path, flowAt = DropPath.read(child)
	tracked[child] = { path = path, flowAt = flowAt, phase = math.random() * math.pi * 2 }
end

local function untrack(child: Instance)
	if child:IsA("PVInstance") then
		tracked[child] = nil
		requested[child] = nil
	end
end

local function watchPlot(plot: Instance)
	local drops = plot:WaitForChild("Drops")
	for _, child in drops:GetChildren() do
		track(child)
	end
	drops.ChildAdded:Connect(track)
	drops.ChildRemoved:Connect(untrack)
end

local function myDropFolder(plots: Instance): Instance?
	local index = player:GetAttribute("PlotIndex")
	if typeof(index) ~= "number" then
		return nil
	end
	local plot = plots:FindFirstChild(`Plot{index}`)
	return plot and plot:FindFirstChild("Drops")
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- "+X" over the player's head when drops are collected. Quick pickups add
-- into the same number; it floats up and fades once they stop.
local gainGui: BillboardGui? = nil
local gainTotal = 0
local gainSerial = 0

local function showGain(amount: number)
	local root = rootPart()
	if not root then
		return
	end
	gainSerial += 1
	local serial = gainSerial
	local gui = gainGui
	if gui and gui.Parent and gui.Adornee == root then
		gainTotal += amount
	else
		if gui then
			gui:Destroy()
		end
		gainTotal = amount
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "AuraGain"
		newGui.Adornee = root
		newGui.Size = UDim2.fromOffset(240, 60)
		newGui.StudsOffset = Vector3.new(0, 3.5, 0)
		newGui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Name = "Amount"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = GAIN_COLOR
		label.Parent = newGui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = GAIN_STROKE
		stroke.Parent = label
		newGui.Parent = player:WaitForChild("PlayerGui")
		gui = newGui
		gainGui = newGui
	end
	assert(gui, "gain popup missing")
	local label = gui:FindFirstChild("Amount") :: TextLabel
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	label.Text = `+{Format.short(gainTotal)}`
	label.TextTransparency = 0
	stroke.Transparency = 0
	gui.StudsOffset = Vector3.new(0, 3.5, 0)

	task.delay(GAIN_COMBINE, function()
		if gainSerial ~= serial then
			return
		end
		task.wait(GAIN_HOLD)
		if gainSerial ~= serial then
			return
		end
		gainGui = nil
		local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(gui, fade, { StudsOffset = Vector3.new(0, 6, 0) }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end)
end

function DropController:Start()
	Remotes.event("DropCollected").OnClientEvent:Connect(function(amount: unknown)
		if typeof(amount) == "number" then
			showGain(amount)
		end
	end)
	local collectDrop = Remotes.event("CollectDrop")
	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		task.spawn(watchPlot, plot)
	end
	plots.ChildAdded:Connect(function(plot)
		watchPlot(plot)
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		local root = rootPart()
		local mine = myDropFolder(plots)
		for part, info in tracked do
			local lucky = part:GetAttribute("Lucky") == true
			local position = DropPath.at(info.path, info.flowAt, serverNow)
			part:PivotTo(
				CFrame.new(position)
					* CFrame.new(0, math.sin(now * 2 + info.phase) * 0.3, 0)
					* CFrame.Angles(0, if lucky then 0 else now * 1.5 + info.phase, 0)
			)

			if not lucky and root and mine and part.Parent == mine then
				local offset = root.Position - position
				local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
				local last = requested[part]
				if
					flat <= Economy.DROP_TOUCH_RANGE
					and math.abs(offset.Y) <= MAX_HEIGHT_GAP
					and (not last or now - last > RETRY_AFTER)
				then
					requested[part] = now
					collectDrop:FireServer(part.Name)
				end
			end
		end
	end)
end

return DropController
