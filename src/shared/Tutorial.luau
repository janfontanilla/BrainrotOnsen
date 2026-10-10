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
	-- Lines the host says before the step's instruction, each pointing at something on
	-- the map for a few seconds (no action needed).
	intro: { { text: string, target: string, flash: { string }, seconds: number } }?,
}

local STEPS: { Step } = {
	{
		id = "buy",
		text = "Step on Buy 1 to get your first brainrot!",
		target = "Buy1Pad",
		flash = { "Buy1Pad" },
	},
	{
		id = "collect",
		text = "Walk over the drops to grab Aura!",
		target = "Pool",
		flash = { "Pool" },
		count = 3,
	},
	{
		id = "deposit",
		text = "Now deposit your Aura here!",
		target = "DepositPad",
		flash = { "DepositStall", "DepositPad" },
	},
	{
		id = "collectCash",
		text = "Now grab your Cash!",
		target = "CollectCashPad",
		flash = { "CollectCashPad" },
		intro = {
			{
				text = "See the Aura Market board? It multiplies your Aura when you deposit: x0.5 to x1.5!",
				target = "MarketBoard",
				flash = { "MarketBoard" },
				seconds = 5,
			},
			{
				text = "This sign shows the Aura you're processing, and how much per second!",
				target = "ProcessorInfo",
				flash = { "ProcessorInfo" },
				seconds = 5,
			},
		},
	},
	{
		id = "merge",
		text = "Buy 2 more, then hit Merge!",
		target = "MergePad",
		flash = { "MergePad" },
		altTarget = "Buy1Pad",
	},
	{
		id = "upgradeBuyTier",
		text = "Here's Cash on me. Upgrade your Buy Tier!",
		target = "UpgradeBuyTierPad",
		flash = { "UpgradeBuyTierPad" },
	},
}

local Tutorial = {}

-- What Tung Tung Tung Sahur says when a step is done (GuideController picks one), and
-- at the very end.
Tutorial.CHEERS = { "Nice!", "Awesome!", "Let's go!", "Great job!", "Perfect!", "You got it!" }
Tutorial.FINISH = "Good luck! Tung Tung Sa-out!"

Tutorial.STEPS = STEPS
Tutorial.DONE = #STEPS + 1 -- finished or skipped
Tutorial.SKIP_FROM = 2 -- the Skip button shows from this step on

return Tutorial
