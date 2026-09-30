--!strict
-- Brainrot polish, on the client only: a newly placed brainrot rises up out of
-- the bath water instead of popping in (only ones the server stamped moments ago
-- animate, so ones streaming in later just appear in place), and pack models
-- loop their Anims.Idle animation. Animation assets owned by someone else may
-- not play in our experience; that fails quietly and the model just stands still.

local TweenService = game:GetService("TweenService")

local RISE_TIME = 0.5
local RISE_WINDOW = 1 -- seconds after SpawnedAt during which a block still animates
local RISE_INFO = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BrainrotController = {}

local function rise(child: Instance)
	if not child:IsA("Model") then
		return
	end
	local spawnedAt = child:GetAttribute("SpawnedAt")
	if typeof(spawnedAt) ~= "number" or workspace:GetServerTimeNow() - spawnedAt > RISE_WINDOW then
		return
	end
	local target = child:GetPivot()
	local height = child:GetExtentsSize().Y
	child:PivotTo(target * CFrame.new(0, -height, 0))
	-- Tween a number and move the whole model with it.
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(value)
		child:PivotTo(target * CFrame.new(0, -height * (1 - value), 0))
	end)
	local tween = TweenService:Create(progress, RISE_INFO, { Value = 1 })
	tween.Completed:Once(function()
		progress:Destroy()
	end)
	tween:Play()
end

local function watchPlot(plot: Instance)
	local folder = plot:WaitForChild("Brainrots", 10)
	if not folder then
		return
	end
	-- Brainrots stand still (user decision); the pack's idle animations belong to its
	-- creator and Roblox refuses to load them in this experience anyway.
	folder.ChildAdded:Connect(rise)
end

function BrainrotController:Start()
	local plots = workspace:WaitForChild("Plots")
	-- Only the player plots (Plot1..Plot6), not the Plaza / Horizon folders.
	local function isPlot(child: Instance): boolean
		return child:IsA("Folder") and string.match(child.Name, "^Plot%d+$") ~= nil
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
end

return BrainrotController
