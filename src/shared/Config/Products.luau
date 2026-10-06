--!strict
-- Game pass and dev product IDs. IDs are 0 until the products are created on
-- the Creator Dashboard (Phase 5). robux = intended price, for reference only;
-- the real price is whatever is set on the dashboard.

export type Pass = { id: number, robux: number, multiplier: number? }
export type Product = { id: number, robux: number, size: ("S" | "M" | "L")? }

local Products = {}

-- The Roblox group whose members get the group reward. 0 = not set yet: in Studio
-- everyone counts as a member (for testing); live, the pad says it is coming soon.
Products.GROUP_ID = 834891952 -- "PCC. Studios"

Products.GamePasses = {
	DoubleAura = { id = 2002868529, robux = 499 }, -- x2 Aura from drops
	AutoCollect = { id = 2003378487, robux = 79 }, -- Aura drops collected automatically
	Cash2x = { id = 2002022706, robux = 40, multiplier = 2 },
	Cash4x = { id = 1998627814, robux = 80, multiplier = 4 },
	Cash7x = { id = 1998795770, robux = 140, multiplier = 7 },
	Cash12x = { id = 2001602746, robux = 240, multiplier = 12 },
} :: { [string]: Pass }

-- Only the highest owned Cash multiplier applies; they do not stack.
Products.CASH_MULTIPLIER_PASSES = { "Cash12x", "Cash7x", "Cash4x", "Cash2x" }

Products.DevProducts = {
	FinishNow = { id = 3715676418, robux = 19 }, -- instantly process the processor queue
	CashPackS = { id = 3715676473, robux = 29, size = "S" },
	CashPackM = { id = 3715676515, robux = 149, size = "M" },
	CashPackL = { id = 3715676564, robux = 499, size = "L" },
	-- Unlocks the lucky chest the player holds when Cash is short; one price for every
	-- chest (user decision 2026-10-04). Hidden where paid random items are restricted.
	LuckyUnlock = { id = 3716958562, robux = 89 },
} :: { [string]: Product }

return Products
