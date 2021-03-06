local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Effects = require(ReplicatedStorage.RuddevModules.Effects)
local Raycast = require(ReplicatedStorage.Core.Raycast)
local TakeDamage = require(ServerScriptService.Shared.TakeDamage)

local TURRET_RANGE = 35

local Turret = {}
Turret.__index = Turret

Turret.Model = "Turret"

function Turret.new()
	return setmetatable({}, Turret)
end

function Turret:AfterSpawn()
	local instance = self.instance
	local gun = instance.Gun

	local aimAnimation = self:LoadAnimation(gun.Animations.Aim)
	aimAnimation.Priority = Enum.AnimationPriority.Idle
	aimAnimation.Looped = true
	aimAnimation:Play()

	self.shootAnimation = self:LoadAnimation(gun.Animations.AimShoot)
end

function Turret:InitializeAI()
	local rateOfFire = self:GetScale("RateOfFire")

	spawn(function()
		local root = self.instance.HumanoidRootPart
		wait(math.random(30, 120) / 100)

		while self.alive do
			local closest = { nil, math.huge }

			for _, player in pairs(Players:GetPlayers()) do
				local character = player.Character
				if character and character.Humanoid.Health > 0 then
					local hit, position, normal = Raycast(
						root.Position,
						(root.Position - character.HumanoidRootPart.Position).Unit * -TURRET_RANGE,
						{ self.instance }
					)

					if hit and hit:IsDescendantOf(character) then
						local distance = (root.Position - position).Magnitude
						if distance < closest[2] then
							closest = { player, distance, { hit, position, normal, character.Humanoid } }
						end
					end
				end
			end

			if closest[1] then
				local handlePos = self.instance.Gun.Handle.Position

				ReplicatedStorage.RuddevRemotes.Effect:FireAllClients(
					Effects.EffectIDs.Shoot,
					self.instance.Gun,
					handlePos,
					{ 0 },
					1000,
					closest[3]
				)

				TakeDamage(closest[1], self:GetScale("Damage"))
				self.shootAnimation:Play()
			end

			wait(1 / rateOfFire)
		end
	end)
end

return Turret
