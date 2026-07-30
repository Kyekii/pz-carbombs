require 'TimedActions/ISBaseTimedAction'

UninstallingBomb = ISBaseTimedAction:derive('UninstallingBomb')

function UninstallingBomb:getDuration()
	if self.character:isTimedActionInstant() then
        return 1
    end
    return 180 - (self.character:getPerkLevel(Perks.Mechanics) * 5)
end

function UninstallingBomb:isValid()
	return true;
end

function UninstallingBomb:update()
	self.character:faceThisObject(self.vehicle)
end

function UninstallingBomb:waitToStart() -- Wait until return false
	if self.character:getVehicle() then return false end
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function UninstallingBomb:start()
	self:setActionAnim('VehicleWorkOnTire')
	self:setOverrideHandModels(nil, nil)
	self.sound = self.character:getEmitter():playSound('UninstallingBomb')

	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 1)
end

function UninstallingBomb:stop()
	ISBaseTimedAction.stop(self)

	if self.sound ~= 0 and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound);
    end
end

function UninstallingBomb:perform()
	if self.sound ~= 0 and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound);
    end

	if SandboxVars.CarBombs.UninstallFail then
		local successchance, dismantlechance = GetUninstallChance(self.character)
		local roll = (ZombRand(0, 100)+1)/100 -- first roll to determine if you actually took the bomb off or not

		if roll >= successchance then
			roll = (ZombRand(0, 100)+1)/100 -- second roll to determine if you dismantled the bomb, instead of recovering it
			if roll <= dismantlechance then
				RemoveBomb(self.character, self.vehicle, true, false)
				self.character:getEmitter():playSound('BreakMetalItem')
				self.character:Say(getText('IGUI_BombUninstallDismantle'))
				return
			else
				RemoveBomb(self.character, self.vehicle, false, false)
				self.character:Say(getText('IGUI_BombUninstallSuccess'))
				return
			end
		else
			self.character:Say(getText('IGUI_BombUninstallFail'))
			return
		end
	else
		RemoveBomb(self.character, self.vehicle, false, false)
		self.character:Say(getText('IGUI_BombUninstallSuccess'))
		return
	end

	if self == nil then
		return
	end

	ISBaseTimedAction.perform(self)
end

function UninstallingBomb:new(character, vehicle)
	local o = {};
	setmetatable(o, self);
	self.__index = self;
	o.StopOnWalk = true;
	o.character = character;
	o.vehicle = vehicle;
	o.vehicleid = vehicle:getId();
	o.maxTime = o:getDuration()

	return o
end
