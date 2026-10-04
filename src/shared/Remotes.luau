--!strict
-- RemoteEvent definitions. The server creates them; the client waits for them.
-- Clients only send intents (never amounts); the server validates everything.
--
-- BuyProduct   client -> server  (name: string)     HUD Cash pack buttons: "CashPackS" | "CashPackM" | "CashPackL" | "FinishNow"
-- CollectDrop  client -> server  (dropId: string)   "I walked over this drop"
-- DropCollected server -> client (aura: number)     a drop was credited; show "+X" over the player
-- GoHome       client -> server  ()                 Home button: send my character to my plot
-- LuckyBlockAction client -> server ("unlock" | "discard")  buttons on the held block's panel
-- LuckyBlockOpened server -> all clients (player, blockName, tier)  play the open-up reveal
-- TutorialAction client -> server ("skip")         Skip button on the tutorial line (TutorialService)
-- Notify       server -> client  (message: string, kind: string?)  HUD message:
--              "deposit" / "cash" / "away" / "lucky" / "newBrainrot" = big popup; "good" = green toast; nil = red toast

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Name =
	"BuyProduct"
	| "CollectDrop"
	| "DropCollected"
	| "GoHome"
	| "LuckyBlockAction"
	| "LuckyBlockOpened"
	| "Notify"
	| "TutorialAction"

local FOLDER_NAME = "Remotes"

local Remotes = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.event(name: Name): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
