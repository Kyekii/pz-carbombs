require "TimedActions/ISBaseTimedAction"

PlantingBomb = ISBaseTimedAction:derive('PlantingBomb')

function PlantingBomb:getDuration()
	if self.character:isTimedActionInstant() then
        return 1
    end
    return 200 - (self.character:getPerkLevel(Perks.Mechanics) * 5)
end

function PlantingBomb:isValid()
	return true
end

function PlantingBomb:update()
	self.character:faceThisObject(self.vehicle)
end

function PlantingBomb:waitToStart()
	if self.character:getVehicle() then return false end
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function PlantingBomb:start()
	self:setActionAnim("ExamineVehicle")
	self:setOverrideHandModels(nil, nil)
	self.character:getEmitter():playSound("PlantingBomb")
end

function PlantingBomb:stop()
	self.item:setJobDelta(0.0)
	ISBaseTimedAction:stop(self)
end

function PlantingBomb:perform()
	local world = getSaveInfo(getWorld():getWorld())
	local vehicleid = self.vehicle:getId()
	local vehicledata = self.vehicle:getModData()
	
	vehicledata.Bomb = true
	
	if self.item:getType() == 'PipeBombRemote' then
		vehicledata.isRemote = true
	end
	
	if self.item:getType() == 'PipeBombSensorV1' then
		vehicledata.isProximity = true
		vehicledata.isProximitySensor = 1
	elseif self.item:getType() == 'PipeBombSensorV2' then
		vehicledata.isProximity = true
		vehicledata.isProximitySensor = 2
	elseif self.item:getType() == 'PipeBombSensorV3' then
		vehicledata.isProximity = true
		vehicledata.isProximitySensor = 3
	end
	
	if self.item:getType() == 'PipeBombTriggered' then
		vehicledata.isTimed = true
		vehicledata.isTimedLength = self.timer
	end
	
	if SandboxVars.CarBombs.Ditching or SandboxVars.CarBombs.AccidentalDetonation then
		local healthbonus = 5 * (self.character:getPerkLevel(Perks.Mechanics) - 1)
		print('healthbonus ', healthbonus)
		print('Mechanics: ', self.character:getPerkLevel(Perks.Mechanics))
		if self.character:getPerkLevel(Perks.Mechanics) > 1 then -- if over Mechanics 1, +5 HP per level 
			vehicledata.bombHealth = SandboxVars.CarBombs.AccidentalDetonationHealth + healthbonus
		else
			vehicledata.bombHealth = SandboxVars.CarBombs.AccidentalDetonationHealth
		end

		vehicledata.bombStartHealth = vehicledata.bombHealth
		vehicledata.lastVelocity = Vector3f.new()
	end
	
	self.character:getInventory():Remove(self.item)
	--FinishTimeBasedAction
	ISBaseTimedAction.perform(self)
	
	self.character:Say(getText("IGUI_BombSet"))
end

function PlantingBomb:new(character, vehicle, item, timer)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.StopOnWalk = true
	o.character = character
	o.item = item
	o.vehicle = vehicle
	o.timer = tonumber(timer)
	o.maxTime = o:getDuration()
	
	return o
end
