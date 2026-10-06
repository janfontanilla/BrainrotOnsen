--!strict
-- New-player tutorial (steps in Shared.Tutorial). The step is saved as
-- data.tutorialStep: 0 = not decided yet, 1..#STEPS = in progress, Tutorial.DONE =
-- finished or skipped. Brand-new players start at 1; old profiles that already own
-- brainrots are marked done on load, so existing players never see it.
--
-- Services report actions with TutorialService.record(player, id) ("buy",
-- "collect", "deposit", "collectCash", "merge", "upgradeBuyTier"); the last step
-- starts with a reward worth exactly the next Upgrade Buy Tier; the step advances when the current
-- step's action has happened `count` times. Replicated as the TutorialStep and
-- TutorialCount player attributes; GuideController draws the instruction, the beam
-- and the arrow. The client can only ask to skip (TutorialAction "skip").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Tutorial = require(Shared.Tutorial)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Analytics = require(script.Parent.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local counts: { [Player]: number } = {}
local notify: RemoteEvent

local function publish(player: Player, step: number)
	player:SetAttribute("TutorialStep", step)
	player:SetAttribute("TutorialCount", counts[player] or 0)
end

-- Makes sure the player can do the merge step: Cash for 2 more of the buy tier.
local function fundMergeStep(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local needed = Economy.bulkPrice(data.buyTier, data.boughtAtBuyTier, 2)
	if data.cash < needed then
		data.cash = needed
		DataService.sync(player)
	end
end

-- The last step's reward: exactly the Cash for the next Upgrade Buy Tier, so the
-- tutorial ends on new brainrots on the pads.
local function giveReward(player: Player)
	local data = DataService.get(player)
	local cost = data and Economy.buyTierUpgradeCost(data.buyTier)
	if not data or not cost then
		return
	end
	data.cash += cost
	data.totalCashEarned += cost
	DataService.sync(player)
	Analytics.cash(player, "source", cost, data.cash, "Onboarding", "TutorialReward")
	notify:FireClient(player, `Tutorial reward: +{Format.short(cost)} Cash!`, "cash")
end

local function advance(player: Player, step: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	Analytics.onboarding(player, step, Tutorial.STEPS[step].id)
	data.tutorialStep = step + 1
	counts[player] = 0
	publish(player, data.tutorialStep)
	if data.tutorialStep == Tutorial.DONE then
		notify:FireClient(player, "Tutorial complete! Keep merging and upgrading", "newBrainrot")
		return
	end
	local nextId = Tutorial.STEPS[data.tutorialStep].id
	if nextId == "merge" then
		fundMergeStep(player)
	elseif nextId == "upgradeBuyTier" then
		giveReward(player)
	end
end

-- Call once the player's data is loaded (PlotService).
function TutorialService.begin(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local forced = RunService:IsStudio() and Economy.STUDIO_FORCE_TUTORIAL
	if data.tutorialStep == 0 or (data.tutorialStep == 1 and data.totalBrainrots > 0 and not forced) then
		-- Owning brainrots while on step 1 only happens after a forced Studio test
		-- saved the step; such a player is past the tutorial.
		data.tutorialStep = if data.totalBrainrots > 0 then Tutorial.DONE else 1
	end
	if forced then
		data.tutorialStep = 1
	end
	counts[player] = 0
	publish(player, data.tutorialStep)
end

-- An action happened; advances the tutorial when it is the current step's action.
function TutorialService.record(player: Player, id: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local step = data.tutorialStep
	local def = Tutorial.STEPS[step]
	if not def or def.id ~= id then
		return
	end
	counts[player] = (counts[player] or 0) + 1
	if counts[player] >= (def.count or 1) then
		advance(player, step)
	else
		publish(player, step)
	end
end

local function onAction(player: Player, action: unknown)
	if action ~= "skip" then
		return
	end
	local data = DataService.get(player)
	if not data or data.tutorialStep < Tutorial.SKIP_FROM or data.tutorialStep >= Tutorial.DONE then
		return
	end
	data.tutorialStep = Tutorial.DONE
	counts[player] = 0
	publish(player, data.tutorialStep)
end

function TutorialService:Init()
	notify = Remotes.event("Notify")
	Remotes.event("TutorialAction").OnServerEvent:Connect(onAction)
end

function TutorialService:Start()
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)
end

return TutorialService
