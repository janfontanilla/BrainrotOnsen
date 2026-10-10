--!strict
-- Swims the koi (Models tagged "Koi" by server/Plots) in slow loops round their
-- pond: an ellipse from the Centre / RadiusX / RadiusZ attributes, each fish at its
-- own Phase and Speed (all the same way round, like a school), nose pointing the way
-- it swims, drifting gently in and out and swaying its tail (turning about the head).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local KOI_TAG = "Koi" -- matches server/Plots
local WIGGLE = math.rad(10)
local WIGGLE_SPEED = 5
local DRIFT = 0.35 -- studs in and out of the circle
local DRIFT_SPEED = 0.6
local HEAD = 1 -- studs from the fish's centre to its head (the sway turns about it)

local KoiController = {}

function KoiController:Start()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, koi in CollectionService:GetTagged(KOI_TAG) do
			if koi:IsA("Model") then
				local centre = koi:GetAttribute("Centre")
				local rx = koi:GetAttribute("RadiusX")
				local rz = koi:GetAttribute("RadiusZ")
				local phase = koi:GetAttribute("Phase")
				local speed = koi:GetAttribute("Speed")
				if
					typeof(centre) == "Vector3"
					and typeof(rx) == "number"
					and typeof(rz) == "number"
					and typeof(phase) == "number"
					and typeof(speed) == "number"
				then
					local a = t * speed + phase
					local drift = 1 + math.sin(t * DRIFT_SPEED + phase * 2) * DRIFT / math.max(rx, 1)
					local position = centre + Vector3.new(math.cos(a) * rx * drift, 0, math.sin(a) * rz * drift)
					-- The direction of travel along the circle (derivative of the position).
					local heading = Vector3.new(-math.sin(a) * rx, 0, math.cos(a) * rz)
					local facing = CFrame.lookAt(position, position + heading)
					local sway = math.sin(t * WIGGLE_SPEED + phase) * WIGGLE
					koi:PivotTo(facing * CFrame.new(0, 0, -HEAD) * CFrame.Angles(0, sway, 0) * CFrame.new(0, 0, HEAD))
				end
			end
		end
	end)
end

return KoiController
