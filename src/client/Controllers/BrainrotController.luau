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

local function playIdle(model: Model)
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	local anims = model:FindFirstChild("Anims")
	local idle = anims and anims:FindFirstChild("Idle")
	if not animator or not idle or not idle:IsA("Animation") then
		return
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(idle)
	end)
	if ok and track then
		track.Looped = true
		track:Play()
	end
end

local function watchPlot(plot: Instance)
	local folder = plot:WaitForChild("Brainrots", 10)
	if not folder then
		return
	end
	local function onAdded(child: Instance)
		rise(child)
		if child:IsA("Model") then
			playIdle(child)
		end
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			task.spawn(playIdle, child)
		end
	end
	folder.ChildAdded:Connect(onAdded)
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
