local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Vendor.Roact)
local RoactRodux = require(ReplicatedStorage.Vendor.RoactRodux)
local State = require(ReplicatedStorage.State)

local TreasureLoot = require(script.TreasureLoot)

local e = Roact.createElement

local function App()
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	}, {
		TreasureLoot = e(TreasureLoot),
	})
end

return e(RoactRodux.StoreProvider, {
	store = State,
}, {
	App = e(App),
})
