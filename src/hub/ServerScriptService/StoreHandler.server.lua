local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Core.Cosmetics)
local Data = require(ReplicatedStorage.Core.Data)

local UpdateCosmetics = ReplicatedStorage.Remotes.UpdateCosmetics

local function playerOwnsCosmetic(player, index)
	for _, owned in pairs(Data.GetPlayerData(player, "Cosmetics").Owned) do
		if owned == index then
			return true
		end
	end
end

Players.PlayerAdded:connect(function(player)
	local data = Data.GetPlayerData(player, "Cosmetics")
	UpdateCosmetics:FireClient(player, data.Owned, data.Equipped, data.LastSeen)
end)

UpdateCosmetics.OnServerEvent:connect(function(player, itemIndex)
	local data, dataStore = Data.GetPlayerData(player, "Cosmetics")

	if type(itemIndex) == "string" then
		if data.Equipped[itemIndex] then
			dataStore:Update(function(data)
				data.Equipped[itemIndex] = nil
				UpdateCosmetics:FireClient(player, nil, data.Equipped)
				return data
			end)
		end
	else
		if not playerOwnsCosmetic(player, itemIndex) then
			warn("player doesn't own cosmetic they're equipping")
			return
		end

		local cosmetic = assert(Cosmetics.Cosmetics[itemIndex], "equipping non-existent cosmetic!")

		local cosmeticType = cosmetic.Type
		if cosmeticType == "GunLowTier" or cosmetic.Type == "GunHighTier" then
			cosmeticType = "GunSkin"
		end

		if data.Equipped[cosmeticType] ~= itemIndex then
			dataStore:Update(function(data)
				data.Equipped[cosmeticType] = itemIndex
				UpdateCosmetics:FireClient(player, nil, data.Equipped)
				return data
			end)
		end
	end
end)

ReplicatedStorage.Remotes.UpdateStoreLastSeen.OnServerEvent:connect(function(player)
	local data, dataStore = Data.GetPlayerData(player, "Cosmetics")
	data.LastSeen = os.date("!*t").yday
	dataStore:Set(data)
end)

ReplicatedStorage.Remotes.GetServerDateStamp.OnServerInvoke = function()
	return os.date("!*t").year + os.date("!*t").yday
end
