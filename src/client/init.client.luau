--!strict
-- Client entry point. Loads every ModuleScript in Controllers: :Init() on all,
-- then :Start() on all. Controllers only render and send intents to the server.

type Controller = { Init: ((any) -> ())?, Start: ((any) -> ())? }

local controllers: { [string]: Controller } = {}
for _, module in script.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module) :: any
	end
end

for _, controller in controllers do
	if controller.Init then
		controller:Init()
	end
end

for _, controller in controllers do
	if controller.Start then
		task.spawn(function()
			controller:Start()
		end)
	end
end

print("[Client] Brainrot Bathhouse started")
