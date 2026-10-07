--!strict
-- Faces the camera toward the baths when the player is sent home (on spawn and with
-- the Home button): the server turns the character toward the plot, but Roblox keeps
-- the camera where it was, so players saw their bathhouse from behind. Any jump of
-- more than TELEPORT_DISTANCE in one frame counts as being sent somewhere; the camera
-- is then put behind the character, looking the way it faces.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TELEPORT_DISTANCE = 25 -- studs in one frame: a teleport, not walking or falling
local CAMERA_BACK = 14 -- studs behind the character
local CAMERA_UP = 7 -- studs above it
local LOOK_AHEAD = 6 -- the camera looks at a point this far in front of the character
local SPAWN_SETTLE = 0.6 -- seconds after spawning: the server has sent the character home by then

local player = Players.LocalPlayer

local CameraController = {}

local function faceForward(root: BasePart)
	local camera = workspace.CurrentCamera
	local look = root.CFrame.LookVector
	local eye = root.Position - look * CAMERA_BACK + Vector3.new(0, CAMERA_UP, 0)
	camera.CFrame = CFrame.lookAt(eye, root.Position + look * LOOK_AHEAD)
end

function CameraController:Start()
	-- On spawn the server moves the character home before this can see the jump, so
	-- face forward once the move has happened.
	local function onCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and root:IsA("BasePart") then
			task.wait(SPAWN_SETTLE)
			faceForward(root)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	local last: Vector3? = nil
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			last = nil
			return
		end
		local position = root.Position
		if last and (position - last).Magnitude > TELEPORT_DISTANCE then
			faceForward(root)
		end
		last = position
	end)
end

return CameraController
