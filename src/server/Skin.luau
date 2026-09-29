--!strict
-- Puts the map textures (Config/Textures) onto parts. Does nothing for a texture
-- whose ID is still 0, so the map keeps working with flat colours until the
-- images are uploaded.

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
