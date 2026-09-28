--!strict
-- Brainrot polish: a newly placed brainrot rises up out of the bath water
-- instead of popping in. Only blocks the server stamped moments ago animate,
-- so blocks streaming in later just appear in place.

local TweenService = game:GetService("TweenService")

local RISE_TIME = 0.5
local RISE_WINDOW = 1 -- seconds after SpawnedAt during which a block still animates
local RISE_INFO = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BrainrotController = {}

local function rise(child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local spawnedAt = child:GetAttribute("SpawnedAt")
	if typeof(spawnedAt) ~= "number" or workspace:GetServerTimeNow() - spawnedAt > RISE_WINDOW then
		return
	end
	local target = child.CFrame
	child.CFrame = target * CFrame.new(0, -child.Size.Y, 0)
	TweenService:Create(child, RISE_INFO, { CFrame = target }):Play()
end

local function watchPlot(plot: Instance)
	local folder = plot:WaitForChild("Brainrots", 10)
	if not folder then
		return
	end
	folder.ChildAdded:Connect(rise)
end

function BrainrotController:Start()
	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		if plot:IsA("Folder") then
			task.spawn(watchPlot, plot)
		end
	end
	plots.ChildAdded:Connect(function(plot)
		if plot:IsA("Folder") then
			watchPlot(plot)
		end
	end)
end

return BrainrotController
