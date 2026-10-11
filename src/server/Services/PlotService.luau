--!strict
-- Builds the plots, then owns the player lifecycle: on join load data (and
-- offline earnings), assign a plot, render it and send the character home; on
-- leave clear the plot and save. Also handles the HUD's Home button.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local Plots = require(script.Parent.Parent.Plots)
local DataService = require(script.Parent.DataService)
local PoolService = require(script.Parent.PoolService)
local ShopService = require(script.Parent.ShopService)
local DropService = require(script.Parent.DropService)
local ProcessorService = require(script.Parent.ProcessorService)
local LuckyBlockService = require(script.Parent.LuckyBlockService)
local MonetizationService = require(script.Parent.MonetizationService)
local TutorialService = require(script.Parent.TutorialService)

local PlotService = {}

local function sendHome(player: Player, character: Model)
	local plot = Plots.get(player)
	if not plot then
		return
	end
	character:WaitForChild("HumanoidRootPart")
	-- Let the default spawn finish first, or it can override the move.
	task.wait()
	if character.Parent then
		character:PivotTo(plot.spawn)
	end
end

local HOME_COOLDOWN = 1 -- seconds between Home button uses

local lastHome: { [Player]: number } = {}

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if not data or player.Parent ~= Players then
		return
	end
	local awaySince = data.lastOnline
	local awayAura, awayCash = DataService.applyOffline(data)
	DataService.sync(player)
	local plot = Plots.assign(player)
	if not plot then
		warn(`[PlotService] No free plot for {player.Name}`)
		player:Kick("This server is full. Please join another one.")
		return
	end
	PoolService.render(plot, data)
	ShopService.refreshPads(plot)
	ProcessorService.refresh(plot)
	LuckyBlockService.onAssigned(player, plot)
	MonetizationService.refresh(player)
	TutorialService.begin(player)

	player.CharacterAdded:Connect(function(character)
		sendHome(player, character)
	end)
	if player.Character then
		task.spawn(sendHome, player, player.Character)
	end

	if awaySince > 0 and os.time() - awaySince >= Economy.OFFLINE_POPUP_MIN_SECONDS and awayAura + awayCash > 0 then
		-- Give the client a moment to load its HUD.
		task.delay(3, function()
			if player.Parent == Players then
				-- The Welcome Back window (WelcomeBackController; 2026-10-11, user: the old
				-- quick popup was easy to miss). Already credited: the window only shows it.
				Remotes.event("OfflineEarnings"):FireClient(player, awayAura, awayCash, os.time() - awaySince)
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	LuckyBlockService.onRemoving(player)
	local plot = Plots.release(player)
	if plot then
		DropService.clearPlot(plot)
		PoolService.clear(plot)
		ShopService.refreshPads(plot)
		ProcessorService.refresh(plot)
		MonetizationService.refreshPads(plot)
	end
	DataService.release(player)
	lastHome[player] = nil
end

local function onGoHome(player: Player)
	local now = os.clock()
	if now - (lastHome[player] or 0) < HOME_COOLDOWN then
		return
	end
	lastHome[player] = now
	local plot = Plots.get(player)
	local character = player.Character
	if plot and character then
		character:PivotTo(plot.spawn)
	end
end

function PlotService:Init()
	Plots.build()
	Remotes.event("GoHome").OnServerEvent:Connect(onGoHome)
end

function PlotService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlotService
