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
	end
end

return Skin
