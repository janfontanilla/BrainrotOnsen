--!strict
-- Placeholder colors shared by server-built parts and client UI (the Index,
-- the lucky block panel). Replaced by real models in Phase 6.

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
