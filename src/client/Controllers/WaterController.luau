--!strict
-- Makes flowing water look like it flows: scrolls the water textures on parts
-- tagged "FlowWater" (the lake in server/Plaza, rivers and channel in server/Plots)
-- along the part's FlowX / FlowZ attributes (in the part's own frame; on the top
-- face the texture's U runs along the part's x and V along its z) at FlowSpeed
-- studs per second. Visual only: the lake's conveyor velocity is what carries players.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FLOW_TAG = "FlowWater" -- matches Plaza.FLOW_TAG on the server
local VISUAL_SPEED = 0.5 -- texture scroll as a share of the real current (reads calmer)

type Flow = { texture: Texture, u: number, v: number }

local WaterController = {}

local flows: { Flow } = {}

local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local speed = (instance:GetAttribute("FlowSpeed") :: number?) or 0
	local fx = (instance:GetAttribute("FlowX") :: number?) or 0
	local fz = (instance:GetAttribute("FlowZ") :: number?) or 0
	for _, child in instance:GetChildren() do
		if child:IsA("Texture") then
			-- A growing offset moves the image along +U / +V (checked in Studio). Layers
			-- can scale the flow (FlowMul) and add a drift of their own (DriftU / DriftV,
			-- studs per second): the ripple layer on every water top (server/Skin).
			local mul = (child:GetAttribute("FlowMul") :: number?) or 1
			local du = (child:GetAttribute("DriftU") :: number?) or 0
			local dv = (child:GetAttribute("DriftV") :: number?) or 0
			local u = fx * speed * VISUAL_SPEED * mul + du
			local v = fz * speed * VISUAL_SPEED * mul + dv
			if u ~= 0 or v ~= 0 then
				table.insert(flows, { texture = child, u = u, v = v })
			end
		end
	end
end

function WaterController:Start()
	for _, part in CollectionService:GetTagged(FLOW_TAG) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(FLOW_TAG):Connect(function(part)
		task.defer(track, part) -- let its Texture replicate first
	end)
	RunService.RenderStepped:Connect(function(dt)
		for i = #flows, 1, -1 do
			local flow = flows[i]
			if flow.texture.Parent == nil then
				table.remove(flows, i)
			else
				local texture = flow.texture
				texture.OffsetStudsU = (texture.OffsetStudsU + flow.u * dt) % texture.StudsPerTileU
				texture.OffsetStudsV = (texture.OffsetStudsV + flow.v * dt) % texture.StudsPerTileV
			end
		end
	end)
end

return WaterController
