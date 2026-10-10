--!strict
-- Puts the map textures (Config/Textures, uploaded studded tiles) onto parts.
--
-- Skin.apply: the tile is a MaterialVariant, so a part gets the look on every
-- face with no extra instances. The variants (MaterialService.Onsen_<key>) are
-- declared in default.project.json, because game scripts may not create them
-- (setting BaseMaterial needs Plugin capability); their image IDs there must
-- match Config/Textures. The part's Color tints the tile, so parts are made
-- near-white (or the given tint). Without the variant the part falls back to the
-- built-in 1-stud surface (Plastic + Studs on top) in its own colour.
--
-- Skin.tile: per-face Texture instances. Only for water, whose textures are
-- scrolled to show the flow.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Textures = require(Shared.Config.Textures)

local Skin = {}

Skin.ALL_SIDES = {
	Enum.NormalId.Top,
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
}

-- The MaterialVariant for texture `key` (MaterialService.Onsen_<key>), nil if missing.
local function variantFor(key: string): MaterialVariant?
	local found = MaterialService:FindFirstChild(`Onsen_{key}`)
	if found and found:IsA("MaterialVariant") then
		return found
	end
	return nil
end

-- Gives `part` texture `key` on all faces, tinted by `tint` (default white).
function Skin.apply(part: BasePart, key: string, tint: Color3?)
	local variant = variantFor(key)
	if variant then
		part.Material = variant.BaseMaterial
		part.MaterialVariant = variant.Name
		part.Color = tint or Color3.new(1, 1, 1)
	else
		part.Material = Enum.Material.Plastic
		part.TopSurface = Enum.SurfaceType.Studs
	end
end

-- Tiles texture `key` on the given faces of `part` (default: the top).
function Skin.tile(part: BasePart, key: string, faces: { Enum.NormalId }?)
	local entry = Textures[key]
	if not entry or entry.id == 0 then
		return
	end
	for _, face in faces or { Enum.NormalId.Top } do
		local texture = Instance.new("Texture")
		texture.Name = `Skin_{key}`
		texture.Texture = `rbxassetid://{entry.id}`
		texture.Face = face
		texture.StudsPerTileU = entry.studsPerTile
		texture.StudsPerTileV = entry.studsPerTile
		texture.Parent = part
		if key == "water" and face == Enum.NormalId.Top then
			Skin.waterTop(part, texture)
		end
	end
end

-- Livelier water on a water top (2026-10-09, user: "better / more realistic"): the
-- base texture drifts a little even on still water, a transparent caustic ripple
-- layer drifts over it at another speed and angle (Controllers/WaterController
-- scrolls both; FlowWater tag), a touch of sky reflection, and on bigger surfaces
-- sun glints twinkling across it.
local RIPPLE_TRANSPARENCY = 0.2
local GLINT_MIN_AREA = 150 -- studs^2 of surface before it gets glints
function Skin.waterTop(part: BasePart, base: Texture)
	base:SetAttribute("DriftU", 0.12)
	base:SetAttribute("DriftV", 0.08)
	local ripple = Textures.waterRipple
	if ripple and ripple.id ~= 0 then
		local layer = Instance.new("Texture")
		layer.Name = "Skin_waterRipple"
		layer.Texture = `rbxassetid://{ripple.id}`
		layer.Face = Enum.NormalId.Top
		layer.StudsPerTileU = ripple.studsPerTile
		layer.StudsPerTileV = ripple.studsPerTile * 0.8
		layer.Transparency = RIPPLE_TRANSPARENCY
		layer:SetAttribute("FlowMul", 0.6)
		layer:SetAttribute("DriftU", -0.45)
		layer:SetAttribute("DriftV", 0.3)
		layer.Parent = part
	end
	part.Reflectance = math.max(part.Reflectance, 0.12)
	CollectionService:AddTag(part, "FlowWater") -- so the client scrolls it (no current)
	local area = part.Size.X * part.Size.Z
	if area >= GLINT_MIN_AREA then
		local glints = Instance.new("ParticleEmitter")
		glints.Name = "Glints"
		glints.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glints.Color = ColorSequence.new(Color3.new(1, 1, 1))
		glints.LightEmission = 1
		glints.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		glints.Transparency = NumberSequence.new(0.15)
		glints.Lifetime = NumberRange.new(0.4, 0.8)
		glints.Speed = NumberRange.new(0)
		glints.Rate = math.clamp(area / 80, 2, 30)
		glints.EmissionDirection = Enum.NormalId.Top
		glints.Shape = Enum.ParticleEmitterShape.Box
		glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		glints.Parent = part
	end
end

return Skin
