-- PetsController.lua --
-- yHasteeD --

-- Types --
type dict<K, V> = {[K]: V}
type array<V> = dict<number, V>
type pet = {
	primaryPart: BasePart,
	nextJump: number,

	BodyPosition: BodyPosition,
	BodyGyro: BodyGyro
}

-- Services --
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

-- Modules --
local Knit = require(ReplicatedStorage.Knit)
local PetsController = Knit.CreateController{
	Name = 'PetsController'
}

local Make = require(Knit.Shared.Make)

-- Constants --
local Player: Player = Knit.Player

local Pets = Make('Folder'){
	Name = 'Pets',
	Parent = workspace
}

local offsetRadius: number = (math.pi * 2)
local petOffsetNumber: number = 4
local petOffsetZ: number = 2.5
local speed: number = 0.65

local zeroCFrame: CFrame = CFrame.new()
local maxVector: Vector3 = Vector3.new(1, 1, 1) * math.huge

local vectorInsert: Vector3 = Vector3.new(0, 2.5, 0)
local bottom: Vector3 = Vector3.new(0, -1, 0) * 200
local removeY: Vector3 = Vector3.new(1, 0, 1)

-- Methods --
local raycastParams: RaycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = { workspace['World 1/Plains'], workspace.Worlds }
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.IgnoreWater = false

function PetsController:_update(deltaTime: number)
	debug.profilebegin('Pet Rendering')

	local clock: number = os.clock()
	local petOffset: number = clock % offsetRadius
	local now: number = deltaTime * 60

	for player: Player, pets: array<pet> in pairs(self._pets) do
		local character: Model? = player.Character
		local primaryPart: BasePart? = character and character.PrimaryPart
		if not primaryPart then
			continue
		end

		local isWalking: boolean = self._walking[player]

		local characterPosition: Vector3 = primaryPart.Position
		local characterCFrame: CFrame = primaryPart.CFrame
		local rightVector: Vector3 = characterCFrame.RightVector
		local defaultLookVector: Vector3 = characterCFrame.LookVector
		local lookVector: CFrame = characterCFrame + defaultLookVector
		local defaultPosition: Vector3 = characterPosition + (-defaultLookVector * petOffsetNumber)

		for index: number, pet: pet in ipairs(pets) do
			local petPosition: Vector3 = pet.primaryPart.CFrame.Position

			local row: number = ((index - 1) % 3) + 1
			local col: number = math.ceil(index / 3) * petOffsetZ
			local newPosition: Vector3 = defaultPosition + (rightVector * (-6 + (3 * row))) + (-defaultLookVector * col)

			local distance: number = ((characterPosition - petPosition) * removeY).Magnitude
			local distanceClamp: number = math.clamp((now * (1 / distance)) * speed, 0, 1)

			local orientation: CFrame = pet.orientation:Lerp(lookVector, distanceClamp)

			if pet.Fly then
				-- Apply Fly --
				local petRotate: number = math.rad(math.cos(petOffset * 4)) * 8

				local position: Vector3 = pet.position:Lerp(newPosition + Vector3.new(0, math.sin(petOffset * 4) * speed, 0), distanceClamp)

				pet.BodyPosition.Position = position + vectorInsert
				pet.BodyGyro.CFrame = orientation * CFrame.Angles(petRotate, 0, 0)

				pet.position = position
			else
				-- Apply Walk --
				local petSize: Vector3 = pet.petSize
				local raycastResult = workspace:Raycast(
					petPosition
					+ petSize
					+ Vector3.new(0, math.max(newPosition.Y - petPosition.Y + 1, 0), 0)
					- Vector3.new(0, math.max((petPosition.Y - newPosition.Y) / 4, 0), 0),

					bottom,

					raycastParams
				)

				local walking: boolean = pet.moving
				local lastMovingCheck: number? = pet.movingCheck
				if not lastMovingCheck or (clock - lastMovingCheck) >= 0.2 then
					walking = distance > (petOffsetNumber + col + row) or isWalking

					pet.moving = walking
					pet.movingCheck = clock
				end

				local movingClock: number? = pet.clock or (walking and clock)
				local rotation: number = math.sin(movingClock and (clock - movingClock) * 11 or 0)

				local position: Vector3 = pet.position:Lerp(Vector3.new(newPosition.X, 0, newPosition.Z), distanceClamp)
				local raycast: Vector3 = pet.raycast:Lerp(Vector3.new(0, raycastResult and raycastResult.Position.Y or characterPosition.Y, 0), math.clamp(now * 0.2, 0, 1))

				pet.BodyPosition.Position = position + raycast + petSize + Vector3.new(0, math.abs(rotation) * 2.25, 0)
				pet.BodyGyro.CFrame = orientation * CFrame.Angles(rotation / 2, 0, rotation / 8)

				pet.position = position
				pet.raycast = raycast
				pet.clock = walking and movingClock
			end

			pet.orientation = orientation
		end
	end

	debug.profileend()
end

local function createPet(pet)
	local clone = pet:Clone()

	local primaryPart: BasePart? = clone.PrimaryPart

	for _, part in pairs(clone:GetDescendants()) do
		if part:IsA('BasePart') and part ~= primaryPart then
			part.Anchored = false
			part.CanCollide = false

			Make('WeldConstraint'){
				Part0 = part,
				Part1 = primaryPart,
				Parent = part
			}
		end
	end

	primaryPart.Anchored = false
	primaryPart.CanCollide = false

	clone.Parent = Pets

	return clone
end

function PetsController:getTable(clone)
	local character: Model = Player.Character or Player.CharacterAdded:Wait()
	local extentsSize: Vector3 = clone:GetExtentsSize()
	return {
		name = clone.Name,
		primaryPart = clone.PrimaryPart,
		extentsSize = extentsSize,
		petSize = Vector3.new(0, extentsSize.Y/2, 0),

		orientation = zeroCFrame,
		position = character.PrimaryPart.Position,
		raycast = Vector3.new(0, character.PrimaryPart.Position, 0),
		Fly = clone:FindFirstChild('Fly') ~= nil,
		Rarity = clone:FindFirstChild('Rarity').Value,
		
		BodyGyro = Make('BodyGyro'){
			D = 750,
			MaxTorque = maxVector,
			P = 40000,
			Parent = clone.PrimaryPart
		},

		BodyPosition = Make('BodyPosition'){
			D = 750,
			MaxForce = maxVector,
			P = 45000,
			Parent = clone.PrimaryPart
		}
	}
end

function PetsController:KnitStart()

	self._pets[Player] = {
		self:getTable(createPet(ReplicatedStorage.TestPet)),
		self:getTable(createPet(ReplicatedStorage.FlyPet))
	}

	RunService.Heartbeat:Connect(function(...)
		self:_update(...)
	end)
end

function PetsController:KnitInit()
	self._walking = {}
	self._pets = {}
	self._petsStoraged = {}
end

return PetsController
