--!strict
-- Lighting and atmosphere for the whole map: a bright sunny sky, soft haze, warm
-- sunlight and gentle post-processing (bloom, colour correction, sun rays) so the
-- flat colours read as a lit, cheerful place instead of bare plastic. All values
-- here are visual only and safe to tune by eye. Haze is kept light so the cliffs
-- read pale grey-blue (not navy), and the bloom threshold high so only the lantern
-- cores glow (reference/capybara-onsen-plot-overview.webp has no glare).

local Lighting = game:GetService("Lighting")

local AtmosphereService = {}

-- Finds the first child of `className` or makes one.
local function ensure(className: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = Lighting
	return created
end

function AtmosphereService:Init()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.8
	Lighting.Ambient = Color3.fromRGB(110, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 178)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 224)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local sky = ensure("Sky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 0

	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 222, 255)
	atmosphere.Decay = Color3.fromRGB(150, 190, 235)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 0.45

	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.25
	bloom.Size = 32
	bloom.Threshold = 1.2

	local correction = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	correction.Saturation = 0.2
	correction.Contrast = 0.08
	correction.Brightness = 0.02
	correction.TintColor = Color3.fromRGB(255, 251, 242)

	local rays = ensure("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.07
	rays.Spread = 0.6
end

return AtmosphereService
