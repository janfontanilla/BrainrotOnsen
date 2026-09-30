--!strict
-- The Cash loop stations on each plot:
--   Deposit Aura pad   whole Aura balance -> processor queue as Aura x market multiplier
--   Processor          turns the queue into Cash 1:1 at Economy.processorRate(level) per second
--   Collect Cash pad   processed Cash waits here until the owner steps on it
--   Upgrade pad        raises the processor level for Economy.processorUpgradeCost(level) Cash
-- Cash multiplier passes, friend and Premium boosts (Phase 5) and offline
-- processing (Phase 3) are not in yet.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Plots = require(script.Parent.Parent.Plots)
local Billboard = require(script.Parent.Parent.Billboard)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local MonetizationService = require(script.Parent.MonetizationService)

type Plot = Plots.Plot

local ProcessorService = {}

local TICK = 0.25 -- seconds between processing steps

local notify: RemoteEvent

local function setText(label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
	end
end

function ProcessorService.refresh(plot: Plot)
	local stations = plot.stations
	local owner = plot.owner
	local data = if owner then DataService.get(owner) else nil
	if not data then
		setText(stations.processorLabel, "Processor")
		setText(stations.deposit.label, "Deposit Aura")
		setText(stations.collectCash.label, "Collect Cash")
		setText(stations.upgradeProcessor.label, "Upgrade Processor")
		return
	end
	local rate = Economy.processorRate(data.processorLevel)
	local nextRate = Economy.processorRate(data.processorLevel + 1)
	local cost = Economy.processorUpgradeCost(data.processorLevel)
	setText(
		stations.processorLabel,
		`Processing Aura\n<font color="#b8860b">{Format.short(data.processorQueue)}</font>\n`
			.. `<font color="#2a7fd4">{Format.short(rate)} per second</font>`
	)
	setText(stations.deposit.label, "Deposit Aura")
	setText(
		stations.collectCash.label,
		"Collect Cash\n" .. Billboard.color(`{Format.short(data.pendingCash)} Cash`, Billboard.CASH)
	)
	setText(
		stations.upgradeProcessor.label,
		Billboard.color(`Processor Lv {data.processorLevel}`, Billboard.CYAN)
			.. `\n+{Format.short(nextRate - rate)} per second\n`
			.. Billboard.color(`{Format.short(cost)} Cash`, Billboard.CASH)
	)
end

local function deposit(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	if data.aura <= 0 then
		notify:FireClient(player, "No Aura to deposit")
		return
	end
	local multiplier = MarketService.multiplier()
	local aura = data.aura
	local amount = aura * multiplier
	data.aura = 0
	data.processorQueue += amount
	DataService.sync(player)
	ProcessorService.refresh(plot)
	-- "Deposited 688.45M (+182.24M) Aura [x1.36]!": amount queued, then the market's bonus or loss.
	local difference = amount - aura
	local sign = if difference >= 0 then "+" else "-"
	notify:FireClient(
		player,
		`Deposited {Format.short(amount)} ({sign}{Format.short(math.abs(difference))}) Aura `
			.. `[x{string.format("%.2f", multiplier)}]!`,
		"deposit"
	)
end

local function collectCash(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data or data.pendingCash <= 0 then
		return
	end
	local amount = data.pendingCash
	data.pendingCash = 0
	data.cash += amount
	data.totalCashEarned += amount
	DataService.sync(player)
	ProcessorService.refresh(plot)
	notify:FireClient(player, `Collected {Format.short(amount)} Cash!`, "cash")
end

local function upgrade(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.processorUpgradeCost(data.processorLevel)
	if not DataService.spendCash(player, cost) then
		notify:FireClient(player, `Not enough Cash (need {Format.short(cost)})`)
		return
	end
	data.processorLevel += 1
	ProcessorService.refresh(plot)
	notify:FireClient(
		player,
		`Processor Lv {data.processorLevel}: {Format.short(Economy.processorRate(data.processorLevel))} per second`,
		"good"
	)
end

local function process(plot: Plot, dt: number)
	local owner = plot.owner
	local data = if owner then DataService.get(owner) else nil
	if not data or data.processorQueue <= 0 then
		return
	end
	local amount = math.min(data.processorQueue, Economy.processorRate(data.processorLevel) * dt)
	data.processorQueue -= amount
	data.pendingCash += amount * MonetizationService.cashMultiplier(owner)
	ProcessorService.refresh(plot)
end

-- Finish Now (Robux): the whole queue becomes Cash right away, with the same
-- Cash multipliers as normal processing.
function ProcessorService.finishNow(player: Player)
	local data = DataService.get(player)
	local plot = Plots.get(player)
	if not data or not plot then
		return
	end
	local amount = data.processorQueue
	data.processorQueue = 0
	data.pendingCash += amount * MonetizationService.cashMultiplier(player)
	ProcessorService.refresh(plot)
end

function ProcessorService:Init()
	notify = Remotes.event("Notify")
end

function ProcessorService:Start()
	MonetizationService.setFinishNowHandler(ProcessorService.finishNow)
	for _, plot in Plots.all() do
		local stations = plot.stations
		Plots.onStep(plot, stations.deposit, function(player)
			deposit(player, plot)
		end)
		Plots.onStep(plot, stations.collectCash, function(player)
			collectCash(player, plot)
		end)
		Plots.onStep(plot, stations.upgradeProcessor, function(player)
			upgrade(player, plot)
		end)
		ProcessorService.refresh(plot)
	end

	local last = os.clock()
	while true do
		task.wait(TICK)
		local now = os.clock()
		local dt = now - last
		last = now
		for _, plot in Plots.all() do
			process(plot, dt)
		end
	end
end

return ProcessorService
