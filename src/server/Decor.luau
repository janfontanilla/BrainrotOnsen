--!strict
-- Map decoration for one plot, built in code (Phase 6 art, modeled on the
-- Capybara Onsen screenshots in reference/): a wooden fence around the sides and
-- back, blocky cliffs with a waterfall behind the plot, cherry blossom trees,
-- bamboo clusters and stone lanterns. Plot-local coordinates like Plots.luau:
-- x across (-width/2 .. width/2), z from the road (0) to the back (depth).
--
-- Static and anchored. Only fences, cliffs and tree trunks collide.

local Decor = {}

export type Options = {
	at: (x: number, y: number, z: number) -> CFrame, -- plot-local -> world
	width: number,
	depth: number,
	floorTop: number,
	seed: number,
}

local WOOD = Color3.fromRGB(150, 100, 60)
local TRUNK = Color3.fromRGB(105, 72, 46)
local BLOSSOM_A = Color3.fromRGB(255, 170, 200)
local BLOSSOM_B = Color3.fromRGB(248, 140, 178)
local BAMBOO = Color3.fromRGB(95, 175, 60)
local BAMBOO_RING = Color3.fromRGB(60, 130, 40)
local CLIFF = Color3.fromRGB(118, 132, 148)
local CLIFF_CAP = Color3.fromRGB(92, 172, 72)
local STONE = Color3.fromRGB(150, 150, 158)
local LAMP = Color3.fromRGB(255, 220, 150)

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
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A run of fence between two plot-local points (posts every ~9 studs, two rails).
local function fenceRun(folder: Folder, o: Options, x1: number, z1: number, x2: number, z2: number)
	local postHeight = 4.5
	local dx, dz = x2 - x1, z2 - z1
	local length = math.sqrt(dx * dx + dz * dz)
	local posts = math.max(1, math.floor(length / 9))
	for i = 0, posts do
		local t = i / posts
		part(
			folder,
			"FencePost",
			Vector3.new(0.9, postHeight, 0.9),
			o.at(x1 + dx * t, o.floorTop + postHeight / 2, z1 + dz * t),
			WOOD,
			true
		)
	end
	local rotation = CFrame.lookAt(Vector3.zero, Vector3.new(dx, 0, dz))
	for _, y in { 1.4, 3.3 } do
		part(
			folder,
			"FenceRail",
			Vector3.new(0.4, 0.55, length),
			o.at((x1 + x2) / 2, o.floorTop + y, (z1 + z2) / 2) * rotation,
			WOOD,
			true
		)
	end
end

local function cherryTree(folder: Folder, o: Options, rng: Random, x: number, z: number, scale: number)
	local trunkHeight = 9 * scale
	part(
		folder,
		"Trunk",
		Vector3.new(1.6 * scale, trunkHeight, 1.6 * scale),
		o.at(x, o.floorTop + trunkHeight / 2, z),
		TRUNK,
		true
	)
	local top = o.floorTop + trunkHeight
	local blocks = {
		{ Vector3.new(7, 3.5, 7), Vector3.new(0, 1.6, 0), BLOSSOM_A },
		{ Vector3.new(5, 3, 5), Vector3.new(1.8, 3.6, -0.8), BLOSSOM_B },
		{ Vector3.new(4.5, 3, 4.5), Vector3.new(-1.9, 3.3, 1.2), BLOSSOM_A },
		{ Vector3.new(3.5, 2.5, 3.5), Vector3.new(0.4, 5.3, 0.3), BLOSSOM_B },
	}
	for _, block in blocks do
		local offset = block[2] * scale
		part(
			folder,
			"Blossom",
			block[1] * scale,
			o.at(x + offset.X, top + offset.Y, z + offset.Z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 45)), 0),
			block[3]
		)
	end
end

local function bambooCluster(folder: Folder, o: Options, rng: Random, x: number, z: number, stalks: number)
	for _ = 1, stalks do
		local height = rng:NextNumber(9, 15)
		local sx, sz = x + rng:NextNumber(-2.2, 2.2), z + rng:NextNumber(-2.2, 2.2)
		part(folder, "Bamboo", Vector3.new(0.8, height, 0.8), o.at(sx, o.floorTop + height / 2, sz), BAMBOO)
		for ring = 1, math.floor(height / 4) do
			part(
				folder,
				"BambooRing",
				Vector3.new(1.1, 0.35, 1.1),
				o.at(sx, o.floorTop + ring * 4 - 1, sz),
				BAMBOO_RING
			)
		end
	end
end

local function stoneLantern(folder: Folder, o: Options, x: number, z: number)
	local y = o.floorTop
	part(folder, "LanternBase", Vector3.new(2, 0.6, 2), o.at(x, y + 0.3, z), STONE, true)
	part(folder, "LanternPillar", Vector3.new(0.8, 2.2, 0.8), o.at(x, y + 1.7, z), STONE, true)
	part(folder, "LanternLamp", Vector3.new(1.9, 1.6, 1.9), o.at(x, y + 3.6, z), LAMP, true, Enum.Material.Neon)
	part(folder, "LanternCap", Vector3.new(2.8, 0.5, 2.8), o.at(x, y + 4.65, z), STONE, true)
	part(folder, "LanternTop", Vector3.new(1.2, 0.6, 1.2), o.at(x, y + 5.2, z), STONE, true)
end

-- Three blocky cliffs behind the back fence, a waterfall on the middle one.
local function cliffs(folder: Folder, o: Options)
	local depth = 26
	local heights = { 34, 50, 40 }
	local segment = o.width / 3
	local zCenter = o.depth + 1 + depth / 2
	for i, height in heights do
		local x = (i - 2) * segment
		part(
			folder,
			"Cliff",
			Vector3.new(segment + 4, height, depth),
			o.at(x, 0.5 + height / 2, zCenter),
			CLIFF,
			true,
			Enum.Material.Slate
		)
		part(
			folder,
			"CliffCap",
			Vector3.new(segment + 4.6, 1.4, depth + 0.6),
			o.at(x, 0.5 + height + 0.7, zCenter),
			CLIFF_CAP,
			true
		)
	end
	local fall = part(
		folder,
		"Waterfall",
		Vector3.new(9, heights[2] - 2, 0.8),
		o.at(0, 1 + (heights[2] - 2) / 2, o.depth + 0.6),
		Color3.fromRGB(120, 215, 255),
		false,
		Enum.Material.Neon
	)
	fall.Transparency = 0.35
	local foam = part(
		folder,
		"WaterfallFoam",
		Vector3.new(13, 1.2, 5),
		o.at(0, 1.1, o.depth + 2.5),
		Color3.fromRGB(235, 248, 255),
		false,
		Enum.Material.Neon
	)
	foam.Transparency = 0.3
end

function Decor.build(parent: Instance, o: Options)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent
	local rng = Random.new(o.seed)
	local half = o.width / 2 - 1

	-- Fence: both sides (leaving the road end open) and the back.
	fenceRun(folder, o, -half, 6, -half, o.depth - 1)
	fenceRun(folder, o, half, 6, half, o.depth - 1)
	fenceRun(folder, o, -half, o.depth - 1, half, o.depth - 1)

	cliffs(folder, o)

	-- Trees and bamboo in the strip between the baths and the side fences.
	for _, side in { -1, 1 } do
		cherryTree(folder, o, rng, side * (half - 4.5), 70, 1)
		cherryTree(folder, o, rng, side * (half - 4.5), 150, 1.1)
		cherryTree(folder, o, rng, side * (half - 4.5), 208, 0.9)
		bambooCluster(folder, o, rng, side * (half - 2.5), 12, 5)
		bambooCluster(folder, o, rng, side * (half - 2.5), 108, 6)
		bambooCluster(folder, o, rng, side * (half - 2.5), 188, 6)
		bambooCluster(folder, o, rng, side * (half - 5), o.depth - 5, 5)
		-- Lanterns: entrance, and either side of the pool.
		stoneLantern(folder, o, side * 24, 5)
		stoneLantern(folder, o, side * 11, 62)
		stoneLantern(folder, o, side * 11, 84)
	end
end

return Decor
