local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ArmorScaling = require(ReplicatedStorage.Core.ArmorScaling)
local Config = require(ReplicatedStorage.RuddevModules.Config)
local Cosmetics = require(ReplicatedStorage.Core.Cosmetics)
local Data = require(ReplicatedStorage.Core.Data)
local Equip = require(ServerScriptService.Shared.Ruddev.Equip)
local Maid = require(ReplicatedStorage.Core.Maid)
local Promise = require(ReplicatedStorage.Core.Promise)
local Settings = require(ReplicatedStorage.Core.Settings)
local XP = require(ReplicatedStorage.Core.XP)

local Armor = {
	Name = "Armor",
	Health = ArmorScaling.ArmorHealth,
}

local Helmet = {
	Name = "Helmet",
	Health = ArmorScaling.HelmetHealth,
}

local DEBUG = true

local function debug(message)
	if DEBUG then
		print("👚 " .. message)
	end
end

local function getLimb(thing)
	local success, limb = pcall(function()
		return Enum.BodyPartR15[thing.Name]
	end)

	if success then
		return limb
	end
end

local resetDeath = {}

local function replaceBodyPartR15(humanoid, limb, part)
	if not resetDeath[humanoid] then
		resetDeath[humanoid] = true
		coroutine.wrap(function()
			RunService.Heartbeat:wait()
			resetDeath[humanoid] = nil
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end)()
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:ReplaceBodyPartR15(limb, part)
	humanoid:BuildRigFromAttachments()
end

local function equipModelThing(thing, character, maid)
	if thing:IsA("CharacterAppearance") or thing:IsA("Accessory") then
		local thing = thing:Clone()
		thing.Parent = character
		maid:GiveTask(thing)
	elseif thing.Name == "Helmet" and thing:IsA("BasePart") then
		local head = character.Head:Clone()

		for _, thing in pairs(head:GetChildren()) do
			if not (thing:IsA("Attachment")
				or thing:IsA("Motor6D")
				or thing:IsA("BillboardGui"))
			then
				thing:Destroy()
			end
		end

		thing.Mesh:Clone().Parent = head

		replaceBodyPartR15(character.Humanoid, Enum.BodyPartR15.Head, head)
			maid:GiveTask(function()
				replaceBodyPartR15(
					character.Humanoid,
					Enum.BodyPartR15.Head,
					ReplicatedStorage.Dummy.Head:Clone()
				)
			end)
	elseif thing.Name == "Helmet" and thing:IsA("Folder") then
		for _, thing in pairs(thing:GetChildren()) do
			local thing = thing:Clone()
			thing.Parent = character
			maid:GiveTask(thing)
		end
	else
		local limb = getLimb(thing)
		if limb then
			replaceBodyPartR15(character.Humanoid, limb, thing:Clone())
			maid:GiveTask(function()
				replaceBodyPartR15(
					character.Humanoid,
					limb,
					ReplicatedStorage.Dummy[limb.Name]:Clone()
				)
			end)
		elseif thing:IsA("Accessory") then
			thing:Clone().Parent = character
		end
	end
end

local function equipModel(item, character, maid)
	if item:IsA("Folder") then
		for _, thing in pairs(item:GetChildren()) do
			equipModelThing(thing, character, maid)
		end
	else
		equipModelThing(item, character, maid)
	end
end

local function equipCosmetic(player, character, equippable, maid)
	return Data.GetPlayerDataAsync(player, "Cosmetics")
		:andThen(function(data)
			local equipped = data.Equipped[equippable.Name]

			if equipped then
				equipModel(Cosmetics.Cosmetics[equipped].Instance, character, maid)
			end

			return equipped ~= nil
		end)
end

local function equip(player, character, equippable, maid)
	return equipCosmetic(player, character, equippable, maid)
		:andThen(function(cosmeticEquipped)
			return Data.GetPlayerDataAsync(player, equippable.Name)
				:andThen(function(equipped)
					local item = ReplicatedStorage.Items[equipped.Type .. equipped.Model]

					if not cosmeticEquipped then
						equipModel(item, character, maid)
					end

					return equippable.Health(equipped.Level, equipped.Rarity)
				end)
		end)
end

local function equipGun(player, character)
	local maid = Maid.new(true)

	local cosmetics = Data.GetPlayerDataAsync(player, "Cosmetics")
	local weapon = Data.GetPlayerDataAsync(player, "Weapon")

	return Promise.all({ weapon, cosmetics }):andThen(function(results)
		local weapon, cosmetics = unpack(results)
		return weapon.UUID .. "/" .. tostring(cosmetics.Equipped.Particle)
	end), function()
		return weapon:andThen(function(data)
			return Promise.async(function(resolve)
				local gun = Data.GetModel(data)
				gun.Name = "Gun"

				local weaponData = Instance.new("Folder")
				weaponData.Name = "WeaponData"

				for statName, stat in pairs(data) do
					local statValue = Instance.new((type(stat) == "number" and "Number" or "String") .. "Value")
					statValue.Name = statName
					statValue.Value = stat
					statValue.Parent = weaponData
				end

				weaponData.Parent = gun
				gun.Ammo.Value = Config:GetConfig(gun).Magazine
				gun.Parent = character

				maid:GiveTask(gun)
				Equip(gun)
				resolve(gun)
			end)
		end):andThen(function(gun)
			return Data.GetPlayerDataAsync(player, "Cosmetics"):andThen(function(cosmetics)
				local particleIndex = cosmetics.Equipped.Particle
				if particleIndex then
					print("particel index", Cosmetics.Cosmetics[particleIndex].Name)
					for _, particle in pairs(Cosmetics.Cosmetics[particleIndex].Instance:GetChildren()) do
						local particle = particle:Clone()
						particle.Parent = gun.PrimaryPart
						maid:GiveTask(particle)
					end
				end
			end)
		end), maid
	end
end

local function equipArmor(player, character)
	local maid = Maid.new(true)

	local armor = Data.GetPlayerDataAsync(player, "Armor")
	local cosmetics = Data.GetPlayerDataAsync(player, "Cosmetics")

	return Promise.all({ armor, cosmetics }):andThen(function(results)
		local armor, cosmetics = unpack(results)
		return armor.UUID .. "/" .. tostring(cosmetics.Equipped.Armor)
	end), function()
		return equip(player, character, Armor, maid), maid
	end
end

local function equipHelmet(player, character)
	local maid = Maid.new(true)

	local helmet = Data.GetPlayerDataAsync(player, "Helmet")
	local cosmetics = Data.GetPlayerDataAsync(player, "Cosmetics")

	return Promise.all({ helmet, cosmetics }):andThen(function(results)
		local helmet, cosmetics = unpack(results)
		return helmet.UUID
			.. "/" .. tostring(cosmetics.Equipped.Face)
			.. "/" .. tostring(cosmetics.Equipped.Helmet)
	end), function()
		return equip(player, character, Helmet, maid):andThen(function(health)
			return cosmetics:andThen(function(cosmetics)
				local faceIndex = cosmetics.Equipped.Face
				if faceIndex then
					local face = character.Head:FindFirstChildOfClass("Decal")
					if face then
						face.Transparency = 1
					end

					local face = Cosmetics.Cosmetics[faceIndex].Instance:Clone()
					face.Parent = character.Head
					maid:GiveTask(face)
				else
					local face = character.Head:FindFirstChildOfClass("Decal")
					if face then
						face.Transparency = 0
					end
				end
			end):andThen(function()
				return health
			end)
		end), maid
	end
end

local function equipSkinTone(player, character)
	local tone = Promise.promisify(Settings.GetSetting)("Skin Tone", player)

	return tone, function()
		return tone:andThen(function(tone)
			return Promise.async(function(resolve)
				local description = Instance.new("HumanoidDescription")
				description.LeftArmColor = tone
				description.LeftLegColor = tone
				description.RightArmColor = tone
				description.RightLegColor = tone
				description.HeadColor = tone
				character.Humanoid:ApplyDescription(description)
				resolve()
			end)
		end)
	end
end

local function giveLevel(player)
	local level = Data.GetPlayerDataAsync(player, "Level")

	return level, function()
		return level:andThen(XP.HealthForLevel)
	end
end

local outfitSteps = {
	Gun = equipGun,
	Armor = equipArmor,
	Helmet = equipHelmet,
	SkinTone = equipSkinTone,
	Level = giveLevel,
}

local function giveOutfit(player, character)
	local results = {}
	local state = {}
	local steps = {}

	local function recalculateHealth()
		local health = 0

		for _, result in pairs(results) do
			if result.health then
				health = health + result.health
			end
		end

		character.Humanoid.MaxHealth = health
		character.Humanoid.Health = health
	end

	for stepName, step in pairs(outfitSteps) do
		local stablePromise, exec = step(player, character)

		table.insert(
			steps,
			stablePromise:andThen(function(stable)
				debug(("initial stable: %s: %s"):format(tostring(stepName), tostring(stable)))
				state[stepName] = stable

				local completionPromise, maid = exec()
				return completionPromise:andThen(function(health)
					results[stepName] = {
						health = health,
						maid = maid,
					}
				end)
			end)
		)
	end

	return Promise.all(steps):andThen(function()
		recalculateHealth()

		return function()
			local steps = {}

			for stepName, currentStable in pairs(state) do
				local step = outfitSteps[stepName]
				local stablePromise, exec = step(player, character)

				table.insert(steps, stablePromise:andThen(function(stable)
					if stable == currentStable then
						debug(("%s didn't change (%s)"):format(stepName, tostring(stable)))
					else
						debug(("%s changed (%s -> %s)"):format(stepName, tostring(currentStable), tostring(stable)))
						state[stepName] = stable

						local maid = results[stepName].maid
						if maid then
							maid:DoCleaning()
						end

						local completionPromise, maid = exec()
						return completionPromise:andThen(function(health)
							results[stepName] = {
								health = health,
								maid = maid,
							}
						end)
					end
				end))
			end

			return Promise.all(steps):andThen(recalculateHealth)
		end
	end)
end

return giveOutfit
