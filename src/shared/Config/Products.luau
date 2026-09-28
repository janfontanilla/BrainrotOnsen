--!strict
-- Game pass and dev product IDs. IDs are 0 until the products are created on
-- the Creator Dashboard (Phase 5). robux = intended price, for reference only;
-- the real price is whatever is set on the dashboard.

local Products = {}

Products.GamePasses = {
	DoubleAura = { id = 0, robux = 499 }, -- x2 Aura from drops
	AutoCollect = { id = 0, robux = 79 }, -- Aura drops collected automatically
	Cash2x = { id = 0, robux = 40, multiplier = 2 },
	Cash4x = { id = 0, robux = 80, multiplier = 4 },
	Cash7x = { id = 0, robux = 140, multiplier = 7 },
}

-- Only the highest owned Cash multiplier applies; they do not stack.
Products.CASH_MULTIPLIER_PASSES = { "Cash7x", "Cash4x", "Cash2x" }

Products.DevProducts = {
	FinishNow = { id = 0, robux = 19 }, -- instantly process the processor queue
	CashPackS = { id = 0, robux = 29, size = "S" },
	CashPackM = { id = 0, robux = 149, size = "M" },
	CashPackL = { id = 0, robux = 499, size = "L" },
}

return Products
