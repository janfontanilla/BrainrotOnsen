--!strict
-- Number display. Every number shown to players goes through here.
-- Format.short(16_260_000_000) -> "16.26B"; Format.commas(11919393) -> "11,919,393"

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

-- Truncates (never rounds up) so the display never shows more than the player has.
function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local index = math.min(math.floor(math.log10(n) / 3), #SUFFIXES)
	local scaled = n / 10 ^ (index * 3)
	scaled = math.floor(scaled * 100 + 1e-9) / 100
	return sign .. string.format("%.2f", scaled) .. SUFFIXES[index]
end

function Format.commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

function Format.multiplier(m: number): string
	return string.format("%.2fx", m)
end

return Format
