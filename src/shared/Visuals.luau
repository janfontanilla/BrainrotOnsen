--!strict
-- Placeholder colors shared by server-built parts and client UI (the Index,
-- the lucky block panel). Replaced by real models in Phase 6.

local Props = require(script.Parent.Props)

local Visuals = {}

function Visuals.tierColor(tier: number): Color3
	return Color3.fromHSV(((tier - 1) * 0.137) % 1, 0.65, 0.95)
end

local BLOCK_COLORS: { [string]: Color3 } = {
	Wood = Color3.fromRGB(160, 110, 60),
	Stone = Color3.fromRGB(150, 150, 160),
	Iron = Color3.fromRGB(205, 210, 220),
	Gold = Color3.fromRGB(255, 205, 50),
	Diamond = Color3.fromRGB(110, 230, 255),
	Emerald = Color3.fromRGB(60, 220, 110),
	Ruby = Color3.fromRGB(230, 50, 80),
	Rainbow = Color3.fromRGB(255, 120, 220),
	Cosmic = Color3.fromRGB(140, 80, 255),
}

-- Rarity rank of each chest (1 = Wood ... 9 = Cosmic): how strongly it glows.
local GLOW_RANK: { [string]: number } = {
	Wood = 1,
	Stone = 2,
	Iron = 3,
	Gold = 4,
	Diamond = 5,
	Emerald = 6,
	Ruby = 7,
	Rainbow = 8,
	Cosmic = 9,
}
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local BEACON_FROM_RANK = 5 -- Diamond and rarer
local BEACON_HEIGHT = 14

-- A soft coloured light and sparkles on a chest, stronger for rarer chests, so a rare
-- one floating in the pool stands out across the plot (2026-10-06).
function Visuals.addGlow(body: BasePart, name: string)
	local rank = GLOW_RANK[name] or 1
	local color = BLOCK_COLORS[name] or Color3.new(1, 1, 1)
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = color
	light.Brightness = 0.6 + rank * 0.25
	light.Range = 6 + rank
	light.Shadows = false
	light.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4))
	sparkles.LightEmission = 1
	sparkles.Rate = 3 + rank * 2
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 + rank * 0.06),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new(0.2)
	sparkles.Parent = body
	-- Rare chests (Diamond and up) also send a soft beam of light upward.
	if rank >= BEACON_FROM_RANK then
		local beacon = Instance.new("Part")
		beacon.Name = "Beacon"
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.CanTouch = false
		beacon.CastShadow = false
		beacon.Material = Enum.Material.Neon
		beacon.Color = color
		beacon.Transparency = 0.65
		beacon.Size = Vector3.new(0.6, BEACON_HEIGHT, 0.6)
		beacon.CFrame = body.CFrame * CFrame.new(0, body.Size.Y / 2 + BEACON_HEIGHT / 2, 0)
		beacon.Parent = body.Parent
	end
end

function Visuals.blockColor(name: string): Color3
	return BLOCK_COLORS[name] or Color3.new(1, 1, 1)
end

local function darker(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * amount)
end

-- A placeholder chest-style lucky block: body, darker lid band and trim, and a
-- lock plate on the front (-Z). Anchored, non-colliding. PrimaryPart = Body.
function Visuals.makeLuckyBlock(name: string, size: number): Model
	-- The voxel chest from tools/voxel_forge.py (Chest<name>, a 1-stud design), scaled
	-- to `size` and centred, with an invisible Body part as PrimaryPart (labels hang on it).
	local voxelName = `Chest{name}`
	if Props.has(voxelName) then
		local chest = Props.clone(voxelName)
		chest.Name = `{name}LuckyBlock`
		chest:ScaleTo(size)
		local centre = chest:GetBoundingBox()
		chest.WorldPivot = CFrame.new(centre.Position)
		chest:PivotTo(CFrame.new())
		for _, part in chest:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.Transparency = 1
		body.Size = Vector3.new(size, size, size)
		body.CFrame = CFrame.new()
		body.Parent = chest
		chest.PrimaryPart = body
		Visuals.addGlow(body, name)
		return chest
	end

	local color = Visuals.blockColor(name)
	local model = Instance.new("Model")
	model.Name = `{name}LuckyBlock`

	local function part(partName: string, partSize: Vector3, offset: CFrame, partColor: Color3): Part
		local p = Instance.new("Part")
		p.Name = partName
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Size = partSize
		p.CFrame = offset
		p.Color = partColor
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end

	local body = part("Body", Vector3.new(size, size, size), CFrame.new(), color)
	part("Lid", Vector3.new(size * 1.04, size * 0.12, size * 1.04), CFrame.new(0, size * 0.18, 0), darker(color, 0.65))
	part("Base", Vector3.new(size * 1.04, size * 0.1, size * 1.04), CFrame.new(0, -size * 0.45, 0), darker(color, 0.65))
	part(
		"Lock",
		Vector3.new(size * 0.22, size * 0.28, size * 0.08),
		CFrame.new(0, size * 0.05, -size * 0.52),
		Color3.fromRGB(60, 60, 70)
	)
	model.PrimaryPart = body
	return model
end

return Visuals
