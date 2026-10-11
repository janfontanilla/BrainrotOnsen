--!strict
-- Swims the koi (Models tagged "Koi" by server/Plots) in slow loops round their
-- pond: an ellipse from the Centre / RadiusX / RadiusZ attributes, each fish at its
-- own Phase and Speed (all the same way round, like a school), nose pointing the way
-- it swims, drifting gently in and out and swaying its tail (turning about the head).
--
-- Players can drag a fish around the pond for fun (2026-10-10, user): a DragDetector
-- on each fish (local only: each player drags their own view). A dragged fish swims
-- slowly after the cursor, staying inside the pond, and when let go it swims back into
-- its loop.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local KOI_TAG = "Koi" -- matches server/Plots
local WIGGLE = math.rad(10)
local WIGGLE_SPEED = 5
local DRIFT = 0.35 -- studs in and out of the circle
local DRIFT_SPEED = 0.6
local HEAD = 1 -- studs from the fish's centre to its head (the sway turns about it)
local DRAG_SPEED = 5 -- studs per second a dragged fish swims after the cursor
local DRAG_WIGGLE_SPEED = 12 -- it wiggles faster while it's being dragged
local POND_MARGIN = 1.2 -- studs kept between a dragged fish and the rim
local RETURN_TIME = 1.5 -- seconds to swim back into the loop after being let go
local DRAG_DISTANCE = 40 -- studs: how far away a fish can be grabbed

type Fish = {
	dragging: boolean,
	target: Vector3?, -- where the cursor points on the water while dragging
	position: Vector3?, -- the fish's own position while dragged / returning
	heading: Vector3,
	releasedAt: number?, -- os.clock() of the let-go, for the swim back
}

local KoiController = {}

local fish: { [Model]: Fish } = {}

local function setupDrag(koi: Model)
	if fish[koi] then
		return
	end
	local state: Fish = { dragging = false, heading = Vector3.new(0, 0, -1) }
	fish[koi] = state
	-- The fish parts were built non-queryable on the server; the drag needs to hit them.
	for _, part in koi:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = true
		end
	end
	local detector = Instance.new("DragDetector")
	detector.Name = "KoiDrag"
	detector.RunLocally = true
	detector.ResponseStyle = Enum.DragDetectorResponseStyle.Custom -- we move it, slowly
	detector.MaxActivationDistance = DRAG_DISTANCE
	detector.Parent = koi

	local function onWater(ray: Ray): Vector3?
		local centre = koi:GetAttribute("Centre")
		if typeof(centre) ~= "Vector3" or math.abs(ray.Direction.Y) < 1e-3 then
			return nil
		end
		local t = (centre.Y - ray.Origin.Y) / ray.Direction.Y
		if t < 0 then
			return nil
		end
		return ray.Origin + ray.Direction * t
	end
	detector.DragStart:Connect(function(_player: Player, ray: Ray)
		state.dragging = true
		state.position = koi:GetPivot().Position
		state.target = onWater(ray) or state.position
	end)
	detector.DragContinue:Connect(function(_player: Player, ray: Ray)
		state.target = onWater(ray) or state.target
	end)
	detector.DragEnd:Connect(function()
		state.dragging = false
		state.releasedAt = os.clock()
	end)
end

function KoiController:Start()
	for _, koi in CollectionService:GetTagged(KOI_TAG) do
		if koi:IsA("Model") then
			setupDrag(koi)
		end
	end
	CollectionService:GetInstanceAddedSignal(KOI_TAG):Connect(function(koi)
		if koi:IsA("Model") then
			task.defer(setupDrag, koi) -- let its parts stream in first
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, koi in CollectionService:GetTagged(KOI_TAG) do
			if koi:IsA("Model") then
				local centre = koi:GetAttribute("Centre")
				local rx = koi:GetAttribute("RadiusX")
				local rz = koi:GetAttribute("RadiusZ")
				local phase = koi:GetAttribute("Phase")
				local speed = koi:GetAttribute("Speed")
				local pondRadius = koi:GetAttribute("PondRadius")
				if
					typeof(centre) == "Vector3"
					and typeof(rx) == "number"
					and typeof(rz) == "number"
					and typeof(phase) == "number"
					and typeof(speed) == "number"
				then
					local a = t * speed + phase
					local drift = 1 + math.sin(t * DRIFT_SPEED + phase * 2) * DRIFT / math.max(rx, 1)
					local loopPosition = centre + Vector3.new(math.cos(a) * rx * drift, 0, math.sin(a) * rz * drift)
					-- The direction of travel along the circle (derivative of the position).
					local loopHeading = Vector3.new(-math.sin(a) * rx, 0, math.cos(a) * rz)
					local position, heading, wiggleSpeed = loopPosition, loopHeading, WIGGLE_SPEED

					local state = fish[koi]
					if state and state.dragging and state.position and state.target then
						-- Swim slowly after the cursor, staying inside the pond.
						local limit = (if typeof(pondRadius) == "number" then pondRadius else rx + 1.5) - POND_MARGIN
						local goal = Vector3.new(state.target.X, centre.Y, state.target.Z)
						local fromCentre = goal - centre
						if fromCentre.Magnitude > limit then
							goal = centre + fromCentre.Unit * limit
						end
						local step = goal - state.position
						if step.Magnitude > 0.05 then
							state.heading = step.Unit
							state.position += step.Unit * math.min(step.Magnitude, DRAG_SPEED * dt)
						end
						position, heading, wiggleSpeed = state.position, state.heading, DRAG_WIGGLE_SPEED
					elseif state and state.releasedAt and state.position then
						-- Let go: blend back into the loop.
						local k = math.clamp((t - state.releasedAt) / RETURN_TIME, 0, 1)
						local eased = k * k * (3 - 2 * k)
						position = state.position:Lerp(loopPosition, eased)
						heading = state.heading:Lerp(loopHeading.Unit, eased)
						if k >= 1 then
							state.releasedAt = nil
							state.position = nil
						end
					end

					if heading.Magnitude < 1e-3 then
						heading = loopHeading
					end
					local facing = CFrame.lookAt(position, position + heading)
					local sway = math.sin(t * wiggleSpeed + phase) * WIGGLE
					koi:PivotTo(facing * CFrame.new(0, 0, -HEAD) * CFrame.Angles(0, sway, 0) * CFrame.new(0, 0, HEAD))
				end
			end
		end
	end)
end

return KoiController
