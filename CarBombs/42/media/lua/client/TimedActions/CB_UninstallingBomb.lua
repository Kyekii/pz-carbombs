require "TimedActions/ISBaseTimedAction"

UninstallingBomb = ISBaseTimedAction:derive('UninstallingBomb')

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
	self:setActionAnim("ExamineVehicle")
	self:setOverrideHandModels(nil, nil)
	self.character:getEmitter():playSound("UninstallingBomb")
end

function UninstallingBomb:perform()
	if SandboxVars.CarBombs.UninstallFail then
		local successchance = 0
		local dismantlechance = 0

		if self.character:getPerkLevel(Perks.Electricity) < 2 then -- since we know the player will need electricity 2 to uninstall, only 3 and above will actually increase the odds
		 	successchance = SandboxVars.CarBombs.UninstallSuccessChance + (0.10 * self.character:getPerkLevel(Perks.Electricity))
			dismantlechance = SandboxVars.CarBombs.UninstallDismantleChance - (0.10 * self.character:getPerkLevel(Perks.Electricity))
		else
			successchance = SandboxVars.CarBombs.UninstallSuccessChance 
			dismantlechance = SandboxVars.CarBombs.UninstallDismantleChance
		end
		
		if successchance >= 1 then
			successchance = 1
		elseif dismantlechance <= 0 then
			dismantlechance = 0
		end

		local roll = (ZombRand(0, 100)+1)/100 -- first roll to determine if you actually took the bomb off or not
		print('SuccessRoll: ', roll, ' >= ', successchance)
		if roll >= successchance then
			roll = (ZombRand(0, 100)+1)/100 -- second roll to determine if you dismantled the bomb, instead of recovering it
			print('DismantleRoll: ', roll, ' <= ', dismantlechance)
			if roll <= dismantlechance then
				RemoveBomb(self.character, self.vehicle, true)
				self.character:getEmitter():playSound("BreakMetalItem")
				self.character:Say(getText("IGUI_BombUninstallDismantle"))
				return
			else
				RemoveBomb(self.character, self.vehicle, false)
				self.character:Say(getText("IGUI_BombUninstallSuccess"))
				return
			end
		else
			self.character:Say(getText("IGUI_BombUninstallFail"))
			return
		end
	else
		RemoveBomb(self.character, self.vehicle, false)
		self.character:Say(getText("IGUI_BombUninstallSuccess"))
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
	o.maxTime = 200;
	if character:isTimedActionInstant() then
		o.maxTime = 1
	end

	return o
end
