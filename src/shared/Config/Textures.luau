--!strict
-- Roblox image asset IDs of the generated map textures (assets/textures/*.png,
-- made by tools/make_textures.py; uploaded 2026-09-29 through the Studio MCP). 0 = not uploaded yet: the map then keeps
-- its flat colours. Upload each PNG (Creator Dashboard > Assets > Images, or
-- Studio Asset Manager > Bulk Import), copy the resulting asset ID here, and the
-- server applies the texture on the next start (server/Skin.luau).
--
-- studsPerTile is how many studs one 256px tile covers: one stud "cell" in the
-- image is a quarter of a tile, so 8 studs per tile = 2-stud cells.

export type Entry = { id: number, studsPerTile: number }

local Textures: { [string]: Entry } = {
	grass = { id = 75242265066226, studsPerTile = 8 }, -- plot floor and ground
	water = { id = 124963839053487, studsPerTile = 8 }, -- baths, rivers, channel, pool
	stone = { id = 87193335822641, studsPerTile = 8 }, -- bath bases, rims, dividers, pool rim
	pegboard = { id = 117506550117439, studsPerTile = 8 }, -- the tall wall
	cliff = { id = 96525064219749, studsPerTile = 16 }, -- the cliffs
	arrow = { id = 77482197620211, studsPerTile = 6 }, -- floor arrows toward the pads (not placed yet)
	planks = { id = 118670792677489, studsPerTile = 4 }, -- slides, bridge, stall wood
	onsen = { id = 138167444057526, studsPerTile = 8 }, -- hot-spring mark (white on transparent) for noren banners; a decal, not a tile
}

return Textures
