--!strict
-- Map decoration for one plot, built in code (Phase 6 art, modeled on the
-- Capybara Onsen screenshots in reference/): a tall pegboard-style wooden wall
-- with hanging paper scrolls around the sides and back, huge stepped cliffs with
-- a waterfall behind the plot, big cherry blossom trees, tall bamboo, stone
-- lanterns and scattered daisies, plus steam / blossom / mist particles.
-- Plot-local coordinates like Plots.luau: x across (-width/2 .. width/2), z from
-- the road (0) to the back (depth).
--
-- Static and anchored. Only the wall, cliffs, front fence, kerbs, bridge and tree trunks collide.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Props = require(Shared.Props)
local Textures = require(Shared.Config.Textures)
local Sounds = require(Shared.Config.Sounds)
local Skin = require(script.Parent.Skin)

local Decor = {}

export type Options = {
	at: (x: number, y: number, z: number) -> CFrame, -- plot-local -> world
	width: number,
	depth: number,
	floorTop: number,
	seed: number,
}

local WALL = Color3.fromRGB(190, 142, 88)
local WALL_DARK = Color3.fromRGB(104, 70, 44)
local BLOSSOM_A = Color3.fromRGB(255, 170, 200)
local CLIFF = Color3.fromRGB(172, 178, 186) -- light warm grey (2026-10-06, was blue-grey 140, 160, 182)
local CLIFF_CAP = Color3.fromRGB(92, 172, 72)
local CLIFF_TIER_TINT = Color3.fromRGB(215, 222, 235) -- upper cliff tier a shade darker than the tile
local FAR_TINT = Color3.fromRGB(235, 242, 250) -- far peaks, pale
local FAR_CAP_TINT = Color3.fromRGB(205, 228, 205)
-- About half the old heights (2026-10-06, docs/visual-overhaul.md): the cliffs framed
-- the plot like a wall of sky-high boxes; Capybara Onsen's frame it lower.
local NEAR_HEIGHTS = { 16, 20, 24, 20, 16 } -- the middle step catches the waterfall
local MID_HEIGHTS = { 36, 50, 42 }
local FAR_HEIGHTS = { 60, 72, 66, 76 }
local PAPER = Color3.fromRGB(245, 240, 225)
local WOOD = Color3.fromRGB(178, 116, 62)
local BRIDGE_RED = Color3.fromRGB(196, 58, 48)
local WOOD_DARK_BENCH = Color3.fromRGB(120, 78, 44)

-- Front edge on the road (reference/capybara-onsen-stations.webp): a canal between
-- two stone kerbs, a low wooden rail fence, and a plank bridge under the torii.
-- The canal and wall sit just behind the station row, so the stations (Deposit Aura
-- and the rest) back onto the wall; a grass verge lies between the road and the canal.
Decor.FRONT_Z = 12 -- plot-local z of the canal's outer kerb
Decor.FRONT_WALL_Z = Decor.FRONT_Z + 5.8 -- the wall on the inner kerb
Decor.ENTRANCE_Z = 8 -- the torii on the verge, at the foot of the bridge
Decor.PLAQUE_Y = 13.9 -- the name board's centre above the floor, on the gate's lintel
Decor.PLAQUE_WIDTH = 17 -- fits between the entrance gate posts
Decor.PATH_END_Z = 32 -- the stone path runs from the bridge to just short of the pads
local KERB_HEIGHT = 1.4
local KERB_WIDTH = 1.2
local CANAL_WIDTH = 4
local BRIDGE_WIDTH = 9
local CANAL_WATER = Color3.fromRGB(70, 205, 240)
local PATH_WIDTH = 6
-- On the +x side the front wall runs straight past the market board, then curves in
-- to meet the +x side wall, cutting off the empty front corner. Plot-local (x, z).
local CURVE = {
	Vector2.new(24, 17.8),
	Vector2.new(40, 21),
	Vector2.new(52, 30),
	Vector2.new(60, 43),
	Vector2.new(64, 58),
}
Decor.CURVE_END_Z = 58 -- where the +x side wall starts

local WALL_HEIGHT = 11
local POST_SPACING = 12
local SCROLL_SPACING = 30

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	collide: boolean?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.CastShadow = collide == true -- small see-through decoration casts no shadow
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ---------- Particles (Roblox built-in textures) ----------

-- Steam rising off a bath's water.
function Decor.steam(water: Part): Part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 8) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.Rate = 4
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.25
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Parent = water
	return water
end

-- White sparkle foam bubbling over the whole of `strip` (an invisible part along
-- the line where the slides land in a river).
function Decor.foam(strip: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Foam"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(245, 252, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(1.5, 3.5)
	emitter.Rate = 14
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.LightEmission = 0.6
	emitter.Parent = strip
end

-- A looping 3D sound on `source` (water noise), heard within `range` studs.
function Decor.ambient(source: BasePart, id: string, volume: number, range: number)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Ambient"
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = range * 0.2
	sound.RollOffMaxDistance = range
	sound.Playing = true
	sound.Parent = source
end

-- Soft grey smoke puffing up from a chimney.
function Decor.smoke(vent: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(225, 225, 232))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	emitter.Lifetime = NumberRange.new(2.5, 3.5)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.Rate = 3
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Parent = vent
end

local function blossomPetals(canopy: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Petals"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 215))
	emitter.Size = NumberSequence.new(0.7)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Acceleration = Vector3.new(1.5, -3, 0.5)
	emitter.Rate = 2
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 0.4
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = canopy
end

local function waterfallMist(foam: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(215, 240, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 16) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Rate = 6
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.3
	emitter.Parent = foam
end

-- ---------- Wall ----------

-- A tall wooden wall between two plot-local points: a plank panel, a dark top
-- and bottom trim, and posts with caps every POST_SPACING studs.
local function wallRun(
	folder: Folder,
	o: Options,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	inwardOverride: Vector3?,
	base: number?
)
	local dx, dz = x2 - x1, z2 - z1
	local length = math.sqrt(dx * dx + dz * dz)
	local rotation = CFrame.lookAt(Vector3.zero, Vector3.new(dx, 0, dz))
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	local top = base or o.floorTop
	local panel = part(
		folder,
		"WallPanel",
		Vector3.new(0.9, WALL_HEIGHT - 1.4, length),
		o.at(mx, top + 0.5 + (WALL_HEIGHT - 1.4) / 2, mz) * rotation,
		WALL,
		true,
		Enum.Material.WoodPlanks
	)
	Skin.apply(panel, "pegboard")
	part(
		folder,
		"WallBase",
		Vector3.new(1.6, 1.0, length),
		o.at(mx, top + 0.5, mz) * rotation,
		WALL_DARK,
		true,
		Enum.Material.WoodPlanks
	)
	part(
		folder,
		"WallTop",
		Vector3.new(2, 0.9, length),
		o.at(mx, top + WALL_HEIGHT - 0.45, mz) * rotation,
		WALL_DARK,
		true,
		Enum.Material.WoodPlanks
	)
	local posts = math.max(1, math.floor(length / POST_SPACING))
	for i = 0, posts do
		local t = i / posts
		local px, pz = x1 + dx * t, z1 + dz * t
		part(
			folder,
			"WallPost",
			Vector3.new(1.7, WALL_HEIGHT + 0.6, 1.7),
			o.at(px, top + (WALL_HEIGHT + 0.6) / 2, pz),
			WALL_DARK,
			true,
			Enum.Material.WoodPlanks
		)
		part(folder, "WallPostCap", Vector3.new(2.4, 0.7, 2.4), o.at(px, top + WALL_HEIGHT + 0.95, pz), WALL_DARK, true)
	end
	-- Paper scrolls hanging on the inside face, facing into the plot.
	local scrolls = math.floor(length / SCROLL_SPACING)
	for i = 1, scrolls do
		local t = (i - 0.5) / scrolls
		local sx, sz = x1 + dx * t, z1 + dz * t
		-- Inside = towards the plot's middle line (x = 0 for side walls, smaller z for the back wall).
		local inward = inwardOverride
			or if math.abs(dx) > math.abs(dz) then Vector3.new(0, 0, -1) else Vector3.new(-math.sign(x1), 0, 0)
		local px, pz = sx + inward.X * 0.7, sz + inward.Z * 0.7
		local face = CFrame.lookAt(Vector3.zero, inward)
		local cy = top + WALL_HEIGHT - 5.3
		part(folder, "Scroll", Vector3.new(4, 5.6, 0.2), o.at(px, cy, pz) * face, PAPER)
		part(folder, "ScrollRod", Vector3.new(4.6, 0.4, 0.5), o.at(px, cy + 2.9, pz) * face, WALL_DARK)
		part(folder, "ScrollRod", Vector3.new(4.6, 0.4, 0.5), o.at(px, cy - 2.9, pz) * face, WALL_DARK)
		part(folder, "ScrollStripe", Vector3.new(0.9, 3.6, 0.25), o.at(px, cy, pz) * face, Color3.fromRGB(70, 110, 170))
	end
end

-- ---------- Cliffs ----------

-- A cliff block standing on the ground, front face at plot-local z `zFront`, with an
-- optional grass ledge on top. Returns the rock.
local function rockBlock(
	folder: Folder,
	o: Options,
	x: number,
	zFront: number,
	size: Vector3,
	tint: Color3?,
	capTint: Color3?
): Part
	local rock =
		part(folder, "Cliff", size, o.at(x, 0.5 + size.Y / 2, zFront + size.Z / 2), CLIFF, true, Enum.Material.Slate)
	Skin.apply(rock, "cliff", tint)
	local cap = part(
		folder,
		"CliffLedge",
		Vector3.new(size.X + 0.8, 1.6, size.Z + 0.8),
		o.at(x, 0.5 + size.Y + 0.8, zFront + size.Z / 2),
		CLIFF_CAP,
		true
	)
	Skin.apply(cap, "grass", capTint)
	return rock
end

-- The backdrop behind the back wall, in three layers like the reference: low near
-- steps, the three big stepped cliffs, and pale far peaks fading into the haze. The
-- waterfall drops from the tallest cliff onto a pool on the middle near step, then
-- down again to the ground behind the wall.
local function cliffs(folder: Folder, o: Options)
	local back = o.depth + 1
	-- Near layer.
	local nearDepth = 16
	local nearWidth = (o.width + 10) / 5
	for i, height in NEAR_HEIGHTS do
		rockBlock(folder, o, (i - 3) * nearWidth, back, Vector3.new(nearWidth + 1, height, nearDepth))
	end
	-- Mid layer: three big cliffs, each with a narrower, taller tier behind.
	local midFront = back + nearDepth
	local midDepth = 36
	local segment = o.width / 3
	for i, height in MID_HEIGHTS do
		local x = (i - 2) * segment
		rockBlock(folder, o, x, midFront, Vector3.new(segment + 6, height, midDepth))
		rockBlock(
			folder,
			o,
			x,
			midFront + midDepth * 0.4,
			Vector3.new(segment * 0.6, height * 1.25, midDepth * 0.5),
			CLIFF_TIER_TINT
		)
	end
	-- Far layer: pale peaks.
	local farFront = midFront + midDepth + 8
	local farWidth = (o.width + 40) / 4
	for i, height in FAR_HEIGHTS do
		rockBlock(
			folder,
			o,
			(i - 2.5) * farWidth,
			farFront,
			Vector3.new(farWidth + 2, height, 40),
			FAR_TINT,
			FAR_CAP_TINT
		)
	end

	-- Waterfall, upper drop: from the top of the middle cliff down to the near step.
	local nearTop = 0.5 + NEAR_HEIGHTS[3] + 1.6
	local midTop = 0.5 + MID_HEIGHTS[2]
	local function fall(name: string, width: number, top: number, bottom: number, z: number)
		local sheet = part(
			folder,
			name,
			Vector3.new(width, top - bottom, 0.9),
			o.at(0, (top + bottom) / 2, z),
			Color3.fromRGB(110, 215, 250),
			false,
			Enum.Material.Glass
		)
		-- Translucent textured water, not Neon: Neon blooms into a white column.
		sheet.Transparency = 0.25
		sheet.CastShadow = false
		Skin.tile(sheet, "water", { Enum.NormalId.Front })
	end
	fall("Waterfall", 12, midTop, nearTop, midFront - 0.5)
	-- The pool on the near step, foaming where the upper drop lands.
	local ledgePool = part(
		folder,
		"WaterfallPool",
		Vector3.new(14, 0.4, nearDepth - 3),
		o.at(0, nearTop + 0.1, back + nearDepth / 2 + 0.5),
		Color3.fromRGB(110, 215, 250),
		false,
		Enum.Material.Glass
	)
	ledgePool.Transparency = 0.15
	Skin.tile(ledgePool, "water")
	local upperFoam = part(
		folder,
		"WaterfallFoam",
		Vector3.new(14, 1, 3),
		o.at(0, nearTop + 0.5, midFront - 2),
		Color3.fromRGB(235, 248, 255),
		false
	)
	upperFoam.Transparency = 0.15
	waterfallMist(upperFoam)
	-- Lower drop: over the front of the near step to the ground behind the wall.
	fall("WaterfallLower", 10, nearTop, 1, back - 0.5)
	local foam = part(
		folder,
		"WaterfallFoam",
		Vector3.new(14, 1.4, 1.6),
		o.at(0, 1.2, back - 0.2),
		Color3.fromRGB(235, 248, 255),
		false
	)
	foam.Transparency = 0.15
	waterfallMist(foam)
	Decor.ambient(foam, Sounds.WATERFALL, Sounds.WATERFALL_VOLUME, 140)
end

-- ---------- Front edge ----------

-- Along the road: outer kerb, canal, inner kerb (z from 0), a wooden rail fence on
-- the inner kerb with a gap for the bridge, the bridge, and a stone path inward.
local function frontage(folder: Folder, o: Options)
	local half = o.width / 2 - 1
	local top = o.floorTop
	local z0 = Decor.FRONT_Z
	local innerKerbZ = Decor.FRONT_WALL_Z
	for _, z in { z0 + KERB_WIDTH / 2, innerKerbZ } do
		local kerb = part(
			folder,
			"Kerb",
			Vector3.new(o.width, KERB_HEIGHT, KERB_WIDTH),
			o.at(0, top + KERB_HEIGHT / 2, z),
			Color3.fromRGB(150, 155, 168),
			true
		)
		Skin.apply(kerb, "stone", Color3.fromRGB(200, 204, 216))
	end
	local canal = part(
		folder,
		"Canal",
		Vector3.new(o.width, 0.4, CANAL_WIDTH),
		o.at(0, top + 0.2, z0 + KERB_WIDTH + CANAL_WIDTH / 2),
		CANAL_WATER,
		false,
		Enum.Material.Glass
	)
	canal.Transparency = 0.1
	Skin.tile(canal, "water")

	-- The big front wall on the inner kerb (same tall pegboard wall as the sides,
	-- scrolls facing in), both sides of the bridge: the torii is the only way in.
	for _, side in { -1, 1 } do
		wallRun(
			folder,
			o,
			if side < 0 then -half else CURVE[1].X,
			innerKerbZ,
			side * (BRIDGE_WIDTH / 2 + 1),
			innerKerbZ,
			Vector3.new(0, 0, 1),
			top + KERB_HEIGHT
		)
	end

	-- The curved +x corner: wall segments on a stone kerb, scrolls facing in.
	for i = 1, #CURVE - 1 do
		local a, b = CURVE[i], CURVE[i + 1]
		local along = (b - a).Unit
		local inward = Vector3.new(-along.Y, 0, along.X) -- left of the direction of travel: into the plot
		local mid = (a + b) / 2
		local kerb = part(
			folder,
			"Kerb",
			Vector3.new(KERB_WIDTH, KERB_HEIGHT, (b - a).Magnitude + KERB_WIDTH),
			o.at(mid.X, top + KERB_HEIGHT / 2, mid.Y) * CFrame.lookAt(Vector3.zero, Vector3.new(along.X, 0, along.Y)),
			Color3.fromRGB(150, 155, 168),
			true
		)
		Skin.apply(kerb, "stone", Color3.fromRGB(200, 204, 216))
		wallRun(folder, o, a.X, a.Y, b.X, b.Y, inward, top + KERB_HEIGHT)
	end

	-- Bridge: a ramp up from the verge, a plank deck over the canal, a ramp down.
	local deckTop = top + KERB_HEIGHT + 0.3
	local deckFront, deckBack = z0 - 1, z0 + KERB_WIDTH * 2 + CANAL_WIDTH + 1
	local deck = part(
		folder,
		"BridgeDeck",
		Vector3.new(BRIDGE_WIDTH, 0.5, deckBack - deckFront),
		o.at(0, deckTop - 0.25, (deckFront + deckBack) / 2),
		WOOD,
		true
	)
	Skin.apply(deck, "planks")
	for _, ramp in { { from = deckFront, to = deckFront - 4 }, { from = deckBack, to = deckBack + 3 } } do
		local a = o.at(0, deckTop - 0.25, ramp.from).Position
		local b = o.at(0, top - 0.25, ramp.to).Position
		local slope = part(
			folder,
			"BridgeRamp",
			Vector3.new(BRIDGE_WIDTH, 0.5, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			WOOD,
			true
		)
		Skin.apply(slope, "planks")
	end
	for _, side in { -1, 1 } do
		local x = side * (BRIDGE_WIDTH / 2 + 0.3)
		part(
			folder,
			"BridgeRail",
			Vector3.new(0.5, 0.5, deckBack - deckFront),
			o.at(x, deckTop + 2.2, (deckFront + deckBack) / 2),
			BRIDGE_RED,
			true
		)
		for _, z in { deckFront, (deckFront + deckBack) / 2, deckBack } do
			part(folder, "BridgePost", Vector3.new(0.8, 2.6, 0.8), o.at(x, deckTop + 1.1, z), BRIDGE_RED, true)
		end
	end

	-- Stone path from the bridge to the station row.
	local pathStart = deckBack + 3
	local path = part(
		folder,
		"Path",
		Vector3.new(PATH_WIDTH, 0.2, Decor.PATH_END_Z - pathStart),
		o.at(0, top + 0.1, (pathStart + Decor.PATH_END_Z) / 2),
		Color3.fromRGB(150, 155, 168)
	)
	Skin.apply(path, "stone")

	-- Entrance gate (dark wood, like Capybara Onsen's) hung with three blue noren
	-- curtains carrying the hot-spring mark; the name board sits on its lintel (Plots).
	Props.place("EntranceGate", o.at(0, top, Decor.ENTRANCE_Z), folder)
	for _, dx in { -6.3, -2.1, 2.1, 6.3 } do
		local cloth = part(
			folder,
			"Noren",
			Vector3.new(4, 4, 0.2),
			o.at(dx, top + 9, Decor.ENTRANCE_Z),
			Color3.fromRGB(40, 86, 170)
		)
		if Textures.onsen.id ~= 0 then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local mark = Instance.new("Decal")
				mark.Texture = `rbxassetid://{Textures.onsen.id}`
				mark.Face = face
				mark.Parent = cloth
			end
		end
	end
	-- Cherry trees outside the wall, peeking over it.
	Decor.cherryTree(folder, o.at(-33, top, 5.5), 0.8)
	Decor.cherryTree(folder, o.at(55, top, 5.5), 0.8)
	for _, side in { -1, 1 } do
		Props.place("StoneLantern", o.at(side * 15.5, top, Decor.ENTRANCE_Z), folder, 0.8)
	end

	-- Group sign on the third curved wall segment (well into the +x front corner,
	-- clear of the market board), readable from the road and from inside.
	local signY = top + KERB_HEIGHT + 6.5
	local a, b = CURVE[3], CURVE[4]
	local along = (b - a).Unit
	local mid = (a + b) / 2
	local signCf = o.at(mid.X, signY, mid.Y) * CFrame.lookAt(Vector3.zero, Vector3.new(-along.Y, 0, along.X))
	part(folder, "GroupSignFrame", Vector3.new(16, 7.4, 2.4), signCf, WALL_DARK, true)
	local board = part(folder, "GroupSign", Vector3.new(14.6, 6, 2.6), signCf, Color3.fromRGB(250, 238, 205), true)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(600, 250)
		gui.LightInfluence = 0.3
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -30, 1, -24)
		label.Position = UDim2.fromOffset(15, 12)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = '<font color="#ffd84a">Join the group + Like</font>\n'
			.. '<font color="#7dff8a">for money every 10 minutes!</font>'
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 40, 25)
		stroke.Thickness = 3
		stroke.Parent = label
	end
end

-- ---------- Props ----------

-- ---------- Props (voxel models from tools/voxel_forge.py) ----------

-- A cherry tree standing at `cf`; petals fall from an invisible emitter part above
-- its canopy.
function Decor.cherryTree(parent: Instance, cf: CFrame, scale: number)
	Props.place("CherryTree", cf, parent, scale)
	local canopy = part(
		parent,
		"PetalEmitter",
		Vector3.new(14 * scale, 0.5, 14 * scale),
		cf * CFrame.new(0, 15 * scale, 0),
		BLOSSOM_A
	)
	canopy.Transparency = 1
	blossomPetals(canopy)
end

local function cherryTree(folder: Folder, o: Options, rng: Random, x: number, z: number, scale: number)
	local turn = math.rad(90 * rng:NextInteger(0, 3))
	Decor.cherryTree(folder, o.at(x, o.floorTop, z) * CFrame.Angles(0, turn, 0), scale)
end

local function bambooCluster(folder: Folder, o: Options, rng: Random, x: number, z: number, scale: number)
	local turn = math.rad(90 * rng:NextInteger(0, 3))
	Props.place("Bamboo", o.at(x, o.floorTop, z) * CFrame.Angles(0, turn, 0), folder, scale)
end

-- A small low leaf clump (ground cover).
local function sprig(folder: Folder, o: Options, rng: Random, x: number, z: number)
	local turn = CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0)
	Props.place("Sprig", o.at(x, o.floorTop, z) * turn, folder, rng:NextNumber(0.8, 1.2))
end

-- A wooden bench along the -x wall, facing into the plot (+x).
local function bench(folder: Folder, o: Options, x: number, z: number)
	local top = o.floorTop
	local seat = part(folder, "BenchSeat", Vector3.new(2.4, 0.5, 7), o.at(x, top + 1.8, z), WOOD)
	Skin.apply(seat, "planks")
	part(folder, "BenchBack", Vector3.new(0.5, 2, 7), o.at(x - 1.1, top + 3, z), WOOD_DARK_BENCH)
	for _, dz in { -2.8, 2.8 } do
		part(folder, "BenchLeg", Vector3.new(2, 1.6, 0.5), o.at(x, top + 0.8, z + dz), WOOD_DARK_BENCH)
	end
end

-- A tall wooden signpost with `text` written down it, one letter per line, on
-- both faces. `cf` is the bottom centre.
function Decor.signpost(parent: Instance, cf: CFrame, text: string)
	local dark = Color3.fromRGB(96, 64, 40)
	part(parent, "SignpostPole", Vector3.new(1, 3, 1), cf * CFrame.new(0, 1.5, 0), dark, true)
	local board = part(
		parent,
		"Signpost",
		Vector3.new(3, 13, 0.8),
		cf * CFrame.new(0, 3 + 6.5, 0),
		Color3.fromRGB(250, 238, 205),
		true
	)
	part(parent, "SignpostCap", Vector3.new(3.8, 0.8, 1.4), cf * CFrame.new(0, 16.4, 0), dark, true)
	part(parent, "SignpostFrame", Vector3.new(3.6, 13.6, 0.6), cf * CFrame.new(0, 9.5, 0), dark, true)
	local letters = table.concat(string.split(text, ""), "\n")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(120, 520)
		gui.LightInfluence = 0.3
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -16, 1, -16)
		label.Position = UDim2.fromOffset(8, 8)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(200, 60, 50)
		label.Text = letters
		label.Parent = gui
	end
end

local function daisy(folder: Folder, o: Options, rng: Random, x: number, z: number)
	local y = o.floorTop + 0.1
	local turn = math.rad(rng:NextInteger(0, 90))
	local white = Color3.fromRGB(250, 250, 255)
	-- Two parts: a square of petals turned 45 degrees and the yellow core.
	part(folder, "Daisy", Vector3.new(1.1, 0.12, 1.1), o.at(x, y, z) * CFrame.Angles(0, turn + math.rad(45), 0), white)
	part(
		folder,
		"DaisyCore",
		Vector3.new(0.55, 0.2, 0.55),
		o.at(x, y + 0.06, z) * CFrame.Angles(0, turn, 0),
		Color3.fromRGB(255, 215, 60)
	)
end

function Decor.build(parent: Instance, o: Options)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent
	local rng = Random.new(o.seed)
	local half = o.width / 2 - 1

	-- Wall: both sides (leaving the road end open) and the back.
	wallRun(folder, o, -half, Decor.FRONT_WALL_Z, -half, o.depth - 1)
	wallRun(folder, o, half, Decor.CURVE_END_Z, half, o.depth - 1)
	wallRun(folder, o, -half, o.depth - 1, half, o.depth - 1)

	cliffs(folder, o)
	frontage(folder, o)

	-- Trees and bamboo in the strip between the baths and the side walls.
	for _, side in { -1, 1 } do
		if side > 0 then -- (the -x one swapped places with the processor barrel)
			-- moved back from z 68 to make room for the processor board on the wall
			cherryTree(folder, o, rng, half - 3, 92, 0.9)
		end
		cherryTree(folder, o, rng, side * (half - 3), 148, 1.05)
		cherryTree(folder, o, rng, side * (half - 3), 206, 0.85)
		-- Front bamboo: -x clear of the deposit stall, +x inside the curved corner.
		if side < 0 then
			bambooCluster(folder, o, rng, -(half - 4), 46, 1.2)
		else
			bambooCluster(folder, o, rng, 58, 52, 1.2) -- at the end of the curved wall
		end
		bambooCluster(folder, o, rng, side * (half - 4), 108, 1.3)
		bambooCluster(folder, o, rng, side * (half - 4), 184, 1.3)
		if side < 0 then
			bench(folder, o, -(half - 4), 86) -- a bench in the quiet corner by the -x wall
		end
	end

	-- The open lawn left of the pool (+x) stays open, like Capybara Onsen's: a couple
	-- of sprigs and daisies (2026-10-06: fewer; the random scatter read as noise).
	for _ = 1, 3 do
		sprig(folder, o, rng, rng:NextNumber(40, 56), rng:NextNumber(46, 76))
	end
	for _ = 1, 4 do
		daisy(folder, o, rng, rng:NextNumber(40, 56), rng:NextNumber(46, 76))
	end
	-- Sprigs in the strips beside the baths and on the verge by the road.
	for _, side in { -1, 1 } do
		for _, z in { 125, 165, 196 } do
			sprig(folder, o, rng, side * (half - 5), z + rng:NextNumber(-3, 3))
		end
	end

	-- A few daisies on the verge outside the canal (clear of the torii).
	for _ = 1, 6 do
		local side = if rng:NextInteger(0, 1) == 0 then -1 else 1
		daisy(folder, o, rng, side * rng:NextNumber(16, half - 2), rng:NextNumber(1.5, Decor.FRONT_Z - 1.5))
	end
end

-- Map-wide horizon: a huge grass plane under everything (so the edges of the map
-- never show the void) and a ring of pale stepped hills beyond the plots on both
-- sides, fading into the haze.
function Decor.horizon(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Horizon"
	folder.Parent = parent
	local plane =
		part(folder, "HorizonGround", Vector3.new(2048, 1, 2048), CFrame.new(0, -0.55, 0), Color3.fromRGB(112, 190, 74))
	Skin.apply(plane, "grass")
	local rng = Random.new(11)
	for _, side in { -1, 1 } do
		for i = 0, 5 do
			local width = rng:NextNumber(110, 160)
			local height = rng:NextNumber(36, 70) -- lower (2026-10-06, was 50-110)
			local x = side * (330 + rng:NextNumber(0, 80))
			local z = -360 + i * 144 + rng:NextNumber(-20, 20)
			local hill = part(folder, "Hill", Vector3.new(width, height, 100), CFrame.new(x, height / 2, z), CLIFF)
			Skin.apply(hill, "cliff", FAR_TINT)
			local cap = part(
				folder,
				"HillTop",
				Vector3.new(width * 0.7, height * 0.35, 70),
				CFrame.new(x + side * 10, height + height * 0.175, z),
				CLIFF
			)
			Skin.apply(cap, "cliff", FAR_TINT)
			local grass = part(
				folder,
				"HillGrass",
				Vector3.new(width * 0.7 + 1, 1.6, 71),
				CFrame.new(x + side * 10, height * 1.35 + 0.8, z),
				CLIFF_CAP
			)
			Skin.apply(grass, "grass", FAR_CAP_TINT)
		end
	end
end

return Decor
