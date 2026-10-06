--!strict
-- The new-player tutorial. The server tracks the step (TutorialService, saved as
-- data.tutorialStep); the client shows it (GuideController). Each step names the
-- action that finishes it (TutorialService.record ids), the part it points at, and
-- the map objects that flash while it is on, so players learn
-- what each sign and station does (names inside the player's Plot<N> folder).

export type Step = {
	id: string, -- the action that counts for this step
	text: string,
	target: string, -- part the beam and arrow point at
	flash: { string }, -- map objects highlighted (flashing) during the step
	count: number?, -- how many times the action must happen (default 1)
	altTarget: string?, -- pointed at instead while the step can't be done yet (see GuideController)
}

local STEPS: { Step } = {
	{
		id = "buy",
		text = "Buy your first brainrot!",
		target = "Buy1Pad",
		flash = { "Buy1Pad" },
	},
	{
		id = "collect",
		text = "Walk over the drops to collect Aura",
		target = "Pool",
		flash = { "Pool" },
		count = 3,
	},
	{
		id = "deposit",
		text = "Deposit your Aura",
		target = "DepositPad",
		flash = { "MarketBoard", "DepositStall" },
	},
	{
		id = "collectCash",
		text = "Collect your Cash",
		target = "CollectCashPad",
		flash = { "ProcessorInfo", "ProcessorBarrel", "CollectCashPad" },
	},
	{
		id = "merge",
		text = "Buy 2 more, then step on Merge!",
		target = "MergePad",
		flash = { "MergePad" },
		altTarget = "Buy1Pad",
	},
	{
		id = "upgradeBuyTier",
		text = "Upgrade Buy Tier!",
		target = "UpgradeBuyTierPad",
		flash = { "UpgradeBuyTierPad" },
	},
}

local Tutorial = {}

Tutorial.STEPS = STEPS
Tutorial.DONE = #STEPS + 1 -- finished or skipped
Tutorial.SKIP_FROM = 2 -- the Skip button shows from this step on

return Tutorial
