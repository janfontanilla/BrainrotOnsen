--!strict
-- Brainrot polish, on the client only: a newly placed brainrot rises up out of
-- the bath water instead of popping in (only ones the server stamped moments ago
-- animate, so ones streaming in later just appear in place), and every brainrot near
-- the camera bobs and sways gently in the water (2026-10-06; the pack's own idle
-- animations belong to its creator and Roblox refuses them here).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local RISE_TIME = 0.5
local RISE_WINDOW = 1 -- seconds after SpawnedAt during which a block still animates
local RISE_INFO = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BOB_HEIGHT = 0.18 -- studs up and down
local BOB_SPEED = 1.6 -- radians per second
local SWAY = math.rad(4) -- side-to-side turn
local BOB_RANGE = 140 -- only brainrots this close to the camera move

local BrainrotController = {}

-- Bobbing brainrots and the offset last applied to each, so the next frame can take
-- it off again before applying the new one.
local bobbing: { [Model]: { phase: number, last: CFrame } } = {}

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
	child:SetAttribute("Rising", true)
	child:PivotTo(target * CFrame.new(0, -height, 0))
	-- Tween a number and move the whole model with it.
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(value)
		child:PivotTo(target * CFrame.new(0, -height * (1 - value), 0))
	end)
	local tween = TweenService:Create(progress, RISE_INFO, { Value = 1 })
	tween.Completed:Once(function()
		progress:Destroy()
		child:SetAttribute("Rising", nil)
	end)
	tween:Play()
end

local function addBob(child: Instance)
	if not child:IsA("Model") then
		return
	end
	local p = child:GetPivot().Position
	bobbing[child] = { phase = (p.X * 0.37 + p.Z * 0.61) % (math.pi * 2), last = CFrame.identity }
	child.Destroying:Once(function()
		bobbing[child] = nil
	end)
end

local function watchPlot(plot: Instance)
	local folder = plot:WaitForChild("Brainrots", 10)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		addBob(child)
	end
	folder.ChildAdded:Connect(function(child)
		rise(child)
		addBob(child)
	end)
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

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera.CFrame.Position
		local t = os.clock()
		for model, state in bobbing do
			if model.Parent and not model:GetAttribute("Rising") then
				local pivot = model:GetPivot()
				if (pivot.Position - camera).Magnitude < BOB_RANGE then
					local wave = t * BOB_SPEED + state.phase
					local offset = CFrame.new(0, math.sin(wave) * BOB_HEIGHT, 0)
						* CFrame.Angles(0, math.sin(wave * 0.5) * SWAY, 0)
					model:PivotTo(pivot * state.last:Inverse() * offset)
					state.last = offset
				end
			end
		end
	end)
end

return BrainrotController
