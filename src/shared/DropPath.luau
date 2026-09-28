--!strict
-- The path a drop floats along: from its brainrot, down a slide into the river,
-- along the river to the center channel, down the channel into the pool.
-- The server writes the points onto the drop part as attributes (Path1..PathN,
-- PathCount, FlowAt); the client reads them to animate, and both use `at` so the
-- server can check a pickup against where the drop really is.

local Economy = require(script.Parent.Config.Economy)

local DropPath = {}

function DropPath.write(part: Instance, points: { Vector3 }, flowAt: number)
	for i, point in points do
		part:SetAttribute(`Path{i}`, point)
	end
	part:SetAttribute("PathCount", #points)
	part:SetAttribute("FlowAt", flowAt)
end

-- Points and start time from a drop part or model. Falls back to its position.
function DropPath.read(part: PVInstance): ({ Vector3 }, number)
	local points: { Vector3 } = {}
	local count = part:GetAttribute("PathCount")
	if typeof(count) == "number" then
		for i = 1, count do
			local point = part:GetAttribute(`Path{i}`)
			if typeof(point) == "Vector3" then
				table.insert(points, point)
			end
		end
	end
	if #points == 0 then
		points = { part:GetPivot().Position }
	end
	local flowAt = part:GetAttribute("FlowAt")
	return points, if typeof(flowAt) == "number" then flowAt else 0
end

-- Where a drop is at `now` (server time), moving at constant speed so it
-- reaches the last point after Economy.DROP_FLOW_SECONDS.
function DropPath.at(points: { Vector3 }, flowAt: number, now: number): Vector3
	local progress = math.clamp((now - flowAt) / Economy.DROP_FLOW_SECONDS, 0, 1)
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end
	local distance = progress * total
	for i = 1, #points - 1 do
		local length = (points[i + 1] - points[i]).Magnitude
		if distance <= length and length > 0 then
			return points[i]:Lerp(points[i + 1], distance / length)
		end
		distance -= length
	end
	return points[#points]
end

return DropPath
