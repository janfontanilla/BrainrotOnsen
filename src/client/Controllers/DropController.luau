--!strict
-- Drops: floats every drop from its brainrot down the slide, river and channel
-- into the pool along the path the server wrote on it (Shared.DropPath), then
-- bobs it there. The server keeps the part still at its resting point.
-- Asks the server to collect a drop in the player's own plot when the character
-- walks over it, wherever it is on its path. The server re-checks ownership and
-- distance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local DropPath = require(Shared.DropPath)

local player = Players.LocalPlayer

local RETRY_AFTER = 1 -- seconds before asking again for a drop the server has not removed
local MAX_HEIGHT_GAP = 6 -- studs between root part and drop that still counts as walking over it

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

function DropController:Start()
	local collectDrop = Remotes.event("CollectDrop")
	local plots = workspace:WaitForChild("Plots")
	-- Only the player plots (Plot1..Plot6), not the Plaza / Horizon folders.
	local function isPlot(child: Instance): boolean
		return string.match(child.Name, "^Plot%d+$") ~= nil
	end
	for _, plot in plots:GetChildren() do
		if isPlot(plot) then
			task.spawn(watchPlot, plot)
		end
	end
	plots.ChildAdded:Connect(function(plot)
		if isPlot(plot) then
			watchPlot(plot)
		end
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
