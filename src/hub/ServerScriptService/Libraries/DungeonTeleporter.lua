local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local FastSpawn = require(ReplicatedStorage.Core.FastSpawn)
local PlaceIds = require(ReplicatedStorage.Core.PlaceIds)
local Promise = require(ReplicatedStorage.Core.Promise)

local dungeonDataStore = DataStoreService:GetDataStore("DungeonInfo")

local DungeonTeleporter = {}

function DungeonTeleporter.ReserveServer()
	return Promise.promisify(function()
		local startTime = tick()
		local accessCode, privateServerId = TeleportService:ReserveServer(PlaceIds.GetMissionPlace())
		print("🕴Reserve server took", tick() - startTime, "seconds")
		return accessCode, privateServerId
	end)()
end

function DungeonTeleporter.TeleportPlayers(lobby, accessCode, privateServerId, loadingScreen)
	return Promise.promisify(function()
		local playerIds = {}

		for _, player in pairs(lobby.Players) do
			table.insert(playerIds, player.UserId)
		end

		local startTime = tick()
		local data = {
			Campaign = lobby.Campaign,
			Gamemode = lobby.Gamemode,
			Members = playerIds,
		}

		if lobby.Gamemode == "Arena" then
			data.ArenaLevel = lobby.ArenaLevel
		elseif lobby.Gamemode == "Boss" then
			data.Boss = lobby.Boss
		else
			data.Difficulty = lobby.Difficulty
		end

		if lobby.Gamemode ~= "Arena" then
			data.Hardcore = lobby.Hardcore
		end

		dungeonDataStore:SetAsync(privateServerId, data)
		print("🕴Setting dungeon data store took", tick() - startTime, "seconds")

		for _, player in ipairs(lobby.Players) do
			FastSpawn(function()
				TeleportService:TeleportToPrivateServer(
					PlaceIds.GetMissionPlace(),
					accessCode,
					{ player },
					nil,
					nil,
					loadingScreen
				)
			end)
		end
	end)()
end

return DungeonTeleporter
