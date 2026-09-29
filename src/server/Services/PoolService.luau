--!strict
-- The brainrot spots of each plot (Economy.MAX_SPOTS). Brainrots are stored as counts per tier;
-- this service lays them out as placeholder blocks (highest tier at the front)
-- and remembers which tier sits in which spot so drops can float next to them.
-- Rendering only rebuilds spots whose tier changed; each new block gets a
-- SpawnedAt attribute so clients play the rise-out-of-the-bath animation.
-- Merging and Buy 100 live in ShopService; this only lays out the result.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Models = require(Shared.Models)
local Plots = require(script.Parent.Parent.Plots)
local DataService = require(script.Parent.DataService)

type Plot = Plots.Plot
type Data = DataService.Data

local PoolService = {}

-- plot index -> tier in each used spot, in spot order
local spotTiers: { [number]: { number } } = {}
-- plot index -> spot index -> the brainrot model
local spotParts: { [number]: { [number]: Model } } = {}
-- plot index -> spot index -> os.clock() when that spot's brainrot was placed
local spotSince: { [number]: { [number]: number } } = {}

local function makeBrainrot(parent: Instance, spot: CFrame, tier: number): Model
	local def = Tiers.get(tier)
	local model = Models.makeBrainrot(tier)
	-- Sit in the raised bath's shallow water (the model's origin is its bottom centre).
	model:PivotTo(spot * CFrame.new(0, -0.4, 0))
	model:SetAttribute("Tier", tier)
	model:SetAttribute("SpawnedAt", workspace:GetServerTimeNow())

	local anchor = model:FindFirstChild("Label")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 46)
	gui.StudsOffset = Vector3.new(0, 0.6, 0)
	gui.MaxDistance = 70
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = `{def.name}\n<font color="#ffd966">Tier {tier}</font>`
	label.Parent = gui

	model.Parent = parent
	return model
end

function PoolService.render(plot: Plot, data: Data)
	local tiers: { number } = {}
	for tier = #data.counts, 1, -1 do
		for _ = 1, data.counts[tier] do
			table.insert(tiers, tier)
		end
	end
	assert(#tiers <= #plot.spots, `Plot {plot.index} holds {#tiers} brainrots but has {#plot.spots} spots`)
	local old = spotTiers[plot.index] or {}
	local parts = spotParts[plot.index] or {}
	local since = spotSince[plot.index] or {}
	local now = os.clock()
	for i = 1, math.max(#tiers, #old) do
		if tiers[i] ~= old[i] then
			local existing = parts[i]
			if existing then
				existing:Destroy()
				parts[i] = nil
			end
			since[i] = nil
			if tiers[i] then
				parts[i] = makeBrainrot(plot.brainrotFolder, plot.spots[i], tiers[i])
				since[i] = now
			end
		end
	end
	spotTiers[plot.index] = tiers
	spotParts[plot.index] = parts
	spotSince[plot.index] = since
end

function PoolService.clear(plot: Plot)
	plot.brainrotFolder:ClearAllChildren()
	spotTiers[plot.index] = nil
	spotParts[plot.index] = nil
	spotSince[plot.index] = nil
end

-- Tier in each occupied spot (in spot order) and os.clock() when each spot's
-- brainrot was placed. Read-only views; do not modify.
function PoolService.spots(plot: Plot): ({ number }, { [number]: number })
	return spotTiers[plot.index] or {}, spotSince[plot.index] or {}
end

return PoolService
