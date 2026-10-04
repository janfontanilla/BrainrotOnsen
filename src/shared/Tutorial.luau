--!strict
-- The new-player tutorial. The server tracks the step (TutorialService, saved as
-- data.tutorialStep); the client shows it (GuideController). Each step names the
-- action that finishes it (TutorialService.record ids) and the part it points at
-- (a name inside the player's Plot<N> folder).

export type Step = {
	id: string, -- the action that counts for this step
	text: string,
	target: string, -- part the beam and arrow point at
	count: number?, -- how many times the action must happen (default 1)
	altTarget: string?, -- pointed at instead while the step can't be done yet (see GuideController)
}

local STEPS: { Step } = {
	{ id = "buy", text = "Buy your first brainrot!", target = "Buy1Pad" },
	{ id = "collect", text = "Walk over the drops to collect Aura", target = "Pool", count = 3 },
	{ id = "deposit", text = "Deposit your Aura", target = "DepositPad" },
	{ id = "collectCash", text = "Collect your Cash", target = "CollectCashPad" },
	{ id = "merge", text = "Buy 2 more, then step on Merge!", target = "MergePad", altTarget = "Buy1Pad" },
}

local Tutorial = {}

Tutorial.STEPS = STEPS
Tutorial.DONE = #STEPS + 1 -- finished or skipped
Tutorial.SKIP_FROM = 2 -- the Skip button shows from this step on

return Tutorial
