--!strict
-- Server entry point. Validates config, then loads every ModuleScript in
-- Services: calls :Init() on all of them first, then :Start() on all of them.

local ConfigCheck = require(script.ConfigCheck)
ConfigCheck.run()

type Service = { Init: ((any) -> ())?, Start: ((any) -> ())? }

local services: { [string]: Service } = {}
for _, module in script.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module) :: any
	end
end

for _, service in services do
	if service.Init then
		service:Init()
	end
end

for _, service in services do
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
end

print("[Server] Brainrot Onsen started")
