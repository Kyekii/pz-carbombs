require "TimedActions/ISBaseTimedAction"

ActivatingBomb = ISBaseTimedAction:derive('ActivatingBomb')

function ActivatingBomb:isValid()
	return true;
end

function ActivatingBomb:update()
	self.character:faceThisObject(self.vehicle)
end

function ActivatingBomb:waitToStart() -- Wait until return false
	if self.character:getVehicle() then return false end
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function ActivatingBomb:start()
	self:setActionAnim("ExamineVehicle")
	self:setOverrideHandModels(nil, nil)
	self.character:getEmitter():playSound("ActivatingBomb")
end

function ActivatingBomb:perform()
	local vehicledata = self.vehicle:getModData();
	if vehicledata.isTimed == true then
		table.insert(CIDTimerCars, self.vehicleid)
		CIDTimerEnd[self.vehicleid] = tonumber(vehicledata.isTimedLength)
		CIDTimerTick[self.vehicleid] = 0
		CIDTimerSeconds[self.vehicleid] = 0
		self.character:Say(getText("IGUI_BombTimerArm"))
		CIDPlayerActivated[self.vehicleid] = self.character
		return
	elseif vehicledata.isProximity == true then
		table.insert(CIDProximityCars, self.vehicleid)
		self.character:Say(getText("IGUI_BombProxArm"))
		CIDPlayerActivated[vehicleid] = self.character
		return
	elseif vehicledata.isRemote == true and self.remotelevel ~= nil then
		local distance = self.remotelevel * 30
		local vehiclesquare = self.vehicle:getSquare()
		local playersquare = self.character:getSquare()
		local remotedistance = math.floor(vehiclesquare:DistTo(playersquare))
		if remotedistance > distance then
			self.character:Say(getText('IGUI_BombTooFar'))
			return
		end
	end
	
	if getWorld():getGameMode() == "Multiplayer" then
		if isClient then
			sendClientCommand(self.character, "carbombs", "detonate", {["vehicleid"]=self.vehicleid})
		end
	else
		ExplodeCar(self.character, self.vehicle)
	end

	if self == nil then 
		return
	end
	--FinishTimeBasedAction
	ISBaseTimedAction.perform(self)
end

--[[ function ActivatingBomb:stop()
	if self ~= nil then
		self.item:setJobDelta(0.0);
		ISBaseTimedAction:stop(self)
	end
	return
end
]]--

function ActivatingBomb:new(character, vehicle, time, remotelevel)
	local o = {};
	setmetatable(o, self);
	self.__index = self;
	o.StopOnWalk = true;
	o.character = character;
	o.vehicle = vehicle;
	o.vehicleid = vehicle:getId();
	o.remotelevel = remotelevel;
	o.time = time;
	o.maxTime = 40;
	if character:isTimedActionInstant() then
		o.maxTime = 1
	end

	return o
end
