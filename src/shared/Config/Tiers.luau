--!strict
-- The 20 brainrot tiers. Index in the list = tier number.
-- aura = Aura per drop (every Economy.DROP_INTERVAL seconds).
-- Tiers 1-12 match Capybara Onsen's Index values; 13-20 continue the ~4x curve.
-- Base buy price is derived in Economy (aura x BASE_PRICE_MULTIPLIER), not stored here.

export type Tier = {
	tier: number,
	name: string,
	item: string,
	aura: number,
}

local list: { Tier } = {
	{ tier = 1, name = "Tim Cheese", item = "Cheese", aura = 1 },
	{ tier = 2, name = "Trippi Troppi", item = "Shrimp", aura = 5 },
	{ tier = 3, name = "Boneca Ambalabu", item = "Tire", aura = 25 },
	{ tier = 4, name = "Frigo Camelo", item = "Ice Cube", aura = 90 },
	{ tier = 5, name = "Lirili Larila", item = "Clock", aura = 300 },
	{ tier = 6, name = "Chimpanzini Bananini", item = "Banana", aura = 1_100 },
	{ tier = 7, name = "Brr Brr Patapim", item = "Leaf", aura = 4_000 },
	{ tier = 8, name = "Bombombini Gusini", item = "Feather", aura = 15_000 },
	{ tier = 9, name = "Cappuccino Assassino", item = "Coffee Bean", aura = 60_000 },
	{ tier = 10, name = "Ballerina Cappuccina", item = "Coffee Cup", aura = 235_000 },
	{ tier = 11, name = "Bombardiro Crocodilo", item = "Bomb", aura = 900_000 },
	{ tier = 12, name = "Tralalero Tralala", item = "Shoe", aura = 4_000_000 },
	{ tier = 13, name = "Tung Tung Tung Sahur", item = "Stick", aura = 16_000_000 },
	{ tier = 14, name = "La Vaca Saturno Saturnita", item = "Milk", aura = 64_000_000 },
	{ tier = 15, name = "Glorbo Fruttodrillo", item = "Fruit", aura = 250_000_000 },
	{ tier = 16, name = "Cocofanto Elefanto", item = "Coconut", aura = 1_000_000_000 },
	{ tier = 17, name = "Odin Din Din Dun", item = "Bell", aura = 4_000_000_000 },
	{ tier = 18, name = "Girafa Celestre", item = "Star", aura = 16_000_000_000 },
	{ tier = 19, name = "Tigrrullini Watermellini", item = "Watermelon", aura = 64_000_000_000 },
	{ tier = 20, name = "Los Tralaleritos", item = "Golden Shoe", aura = 250_000_000_000 },
}

local Tiers = {}

Tiers.list = list
Tiers.MAX_TIER = #list

function Tiers.get(tier: number): Tier
	local entry = list[tier]
	assert(entry, `Unknown tier {tier}`)
	return entry
end

return Tiers
