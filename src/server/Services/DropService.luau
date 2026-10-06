--!strict
-- Drops. Every brainrot drops its tier's item every Economy.DROP_INTERVAL
-- seconds, on its own timer that starts when it is placed, worth that tier's
-- Aura. A drop slides out of the bath and floats down the river and the center
-- channel into the pool (Economy.DROP_FLOW_SECONDS), where it waits to be
-- collected. At Economy.DROP_CAP uncollected drops the plot silently stops
-- producing until drops are picked up (no banner, no backlog).
--
-- The server keeps each drop part at its resting point in the pool and writes
-- the flow path onto it (Shared.DropPath); clients animate the float.
--
-- Collecting: the client asks with CollectDrop(dropId) when its character walks
-- over a drop, anywhere along its path or in the pool. The server checks
-- ownership and distance to where the drop is right now before crediting Aura.

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local DropPath = require(Shared.DropPath)
local Models = require(Shared.Models)
local Plots = require(script.Parent.Parent.Plots)
local DataService = require(script.Parent.DataService)
local PoolService = require(script.Parent.PoolService)
local MonetizationService = require(script.Parent.MonetizationService)
local TutorialService = require(script.Parent.TutorialService)

type Plot = Plots.Plot

type Drop = {
	part: Model,
	value: number,
	path: { Vector3 },
	flowAt: number, -- server time the drop appeared
}

local DropService = {}

local dropCollected: RemoteEvent

-- plot index -> drop id -> drop
local drops: { [number]: { [string]: Drop } } = {}
local dropCounts: { [number]: number } = {}
-- plot index -> spot index -> timer for that spot's brainrot
local timers: { [number]: { [number]: { since: number, nextAt: number } } } = {}
-- plot index -> takes the place of that plot's next drop (lucky blocks)
local replacers: { [number]: (path: { Vector3 }, flowAt: number) -> () } = {}
local nextId = 0
local random = Random.new()
local TICK = 0.2 -- seconds between timer checks

local function interval(): number
	if RunService:IsStudio() and Economy.STUDIO_DROP_INTERVAL > 0 then
		return Economy.STUDIO_DROP_INTERVAL
	end
	return Economy.DROP_INTERVAL
end

local function spawnDrop(plot: Plot, spotIndex: number, tier: number, value: number, autoCollect: boolean)
	local path = Plots.dropPath(plot, spotIndex, random)
	local flowAt = workspace:GetServerTimeNow()
	local replacer = replacers[plot.index]
	if replacer then
		replacers[plot.index] = nil
		replacer(path, flowAt)
		return
	end
	local owner = plot.owner
	if autoCollect and owner then
		-- Auto Collect: no drop floats out, the Aura is credited straight away.
		local credited = value * MonetizationService.auraMultiplier(owner)
		DataService.addAura(owner, credited)
		dropCollected:FireClient(owner, credited)
		TutorialService.record(owner, "collect")
		return
	end

	nextId += 1
	local id = tostring(nextId)

	local part = Models.makeDropItem(tier)
	part.Name = id
	part:PivotTo(CFrame.new(path[#path]))
	part:SetAttribute("Tier", tier)
	DropPath.write(part, path, flowAt)

	part.Parent = plot.dropFolder

	local plotDrops = drops[plot.index]
	if not plotDrops then
		plotDrops = {}
		drops[plot.index] = plotDrops
	end
	plotDrops[id] = { part = part, value = value, path = path, flowAt = flowAt }
	dropCounts[plot.index] = (dropCounts[plot.index] or 0) + 1
end

local function produce(plot: Plot, now: number)
	if not plot.owner then
		return
	end
	local tiers, since = PoolService.spots(plot)
	local plotTimers = timers[plot.index]
	if not plotTimers then
		plotTimers = {}
		timers[plot.index] = plotTimers
	end
	local step = interval()
	local autoCollect = MonetizationService.hasAutoCollect(plot.owner)
	for i, tier in tiers do
		local placed = since[i] or now
		local timer = plotTimers[i]
		if not timer or timer.since ~= placed then
			-- New brainrot in this spot: first drop one interval after it was placed.
			timer = { since = placed, nextAt = placed + step }
			plotTimers[i] = timer
		end
		if now >= timer.nextAt then
			-- Skip missed intervals instead of queueing them (the cap drops them silently).
			while timer.nextAt <= now do
				timer.nextAt += step
			end
			-- Auto Collect owners never fill up: nothing is left lying around.
			if autoCollect or (dropCounts[plot.index] or 0) < Economy.DROP_CAP then
				spawnDrop(plot, i, tier, Tiers.get(tier).aura, autoCollect)
			end
		end
	end
	for i = #tiers + 1, #plotTimers do
		plotTimers[i] = nil
	end
end

local function onCollect(player: Player, dropId: unknown)
	if typeof(dropId) ~= "string" then
		return
	end
	local plot = Plots.get(player)
	if not plot then
		return
	end
	local plotDrops = drops[plot.index]
	local drop = plotDrops and plotDrops[dropId]
	if not plotDrops or not drop then
		return
	end
	local root = Plots.rootPart(player)
	if not root then
		return
	end
	local where = DropPath.at(drop.path, drop.flowAt, workspace:GetServerTimeNow())
	local distance = (root.Position - where).Magnitude
	if distance > Economy.DROP_PICKUP_RANGE then
		if RunService:IsStudio() then
			warn(`[DropService] Refused drop {dropId} for {player.Name}: {math.floor(distance)} studs away`)
		end
		return
	end
	plotDrops[dropId] = nil
	dropCounts[plot.index] -= 1
	drop.part:Destroy()
	local credited = drop.value * MonetizationService.auraMultiplier(player)
	DataService.addAura(player, credited)
	dropCollected:FireClient(player, credited)
	TutorialService.record(player, "collect")
end

-- Uncollected drops on the plot right now.
function DropService.dropCount(plot: Plot): number
	return dropCounts[plot.index] or 0
end

-- The plot's next drop is replaced: instead of an Aura drop, `replacer` gets
-- the drop's path and start time (it floats its own thing down that path).
function DropService.replaceNextDrop(plot: Plot, replacer: (path: { Vector3 }, flowAt: number) -> ())
	replacers[plot.index] = replacer
end

function DropService.clearPlot(plot: Plot)
	replacers[plot.index] = nil
	plot.dropFolder:ClearAllChildren()
	drops[plot.index] = nil
	dropCounts[plot.index] = nil
	timers[plot.index] = nil
end

function DropService:Init()
	Remotes.event("CollectDrop").OnServerEvent:Connect(onCollect)
	dropCollected = Remotes.event("DropCollected")
end

function DropService:Start()
	while true do
		task.wait(TICK)
		local now = os.clock()
		for _, plot in Plots.all() do
			produce(plot, now)
		end
	end
end

return DropService
