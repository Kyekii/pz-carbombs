-- Car Bombs for Project Zomboid
-- programmed by Kyeki, 2023

local CB = {}

local old_ISVehicleMenu_showRadialMenu = ISVehicleMenu.showRadialMenu
	
function ISInventoryPaneContextMenu.OnTriggerRemoteController(remoteController, player)
	local vehicleid = remoteController:getRemoteControlID()
	local vehicle = getVehicleById(vehicleid)
	
	if vehicle ~= nil then
		local vehicledata = vehicle:getModData()
		local remoteid = remoteController:getRemoteControlID()
		local remotelevel = remoteController:getRemoteRange()
		local container = remoteController:getContainer()
		local player = container:getCharacter()
		
		if remotelevel == 7 then
			remotelevel = 1
		elseif remotelevel == 11 then
			remotelevel = 2
		elseif remotelevel == 15 then
			remotelevel = 3
		end
		
		if vehicledata.Bomb == true and vehicledata.isRemote == true then
			CB.ActivateBomb(player, vehicle, nil, remotelevel)
		end
	end
end

function CB.OnFillWorldObjectContextMenu(playerId, context, worldobjects, test)
	local world = getSaveInfo(getWorld():getWorld())
	local player = getSpecificPlayer(playerId)
	local inventory = player:getInventory()
	
	local bombs = inventory:getAllEvalRecurse(function(item, player)
		return item:getType() == 'PipeBomb'
	end, ArrayList.new())
	
	local remotebombs = inventory:getAllEvalRecurse(function(item, player)
		return item:getType() == 'PipeBombRemote'
	end, ArrayList.new())
	
	local proximitybombs = inventory:getAllEvalRecurse(function(item, player)
		return item:getType() == 'PipeBombSensorV1' or item:getType() == 'PipeBombSensorV2' or item:getType() == 'PipeBombSensorV3'
	end, ArrayList.new())
	
	local timebombs = inventory:getAllEvalRecurse(function(item, player)
		return item:getType() == 'PipeBombTriggered'
	end, ArrayList.new())
	
	local remote = inventory:getAllEvalRecurse(function(item, player)
		return item:getType() == 'RemoteCraftedV1' or item:getType() == 'RemoteCraftedV2' or item:getType() == 'RemoteCraftedV3'
	end, ArrayList.new())
	
	vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	
	if vehicle then
		local vehiclename = vehicle:getScriptName()
		local vehicledata = vehicle:getModData()
		local vehicleid = vehicle:getId()
		
		if string.find(vehiclename, "Burnt") ~= nil then
			return
		end
		
		if vehicledata.Bomb == true then
			if vehicledata.isRemote == true and remote:size() > 0 then
				for i=0, player:getInventory():getItems():size() -1 do
					local item = player:getInventory():getItems():get(i)
					if item:isRemoteController() and item:getRemoteControlID() == -1 then
						context:addOption(getText("ContextMenu_AddCarTrigger"), item, CB.LinkBomb, player, vehicleid)
					end
				end
			end
			if CIDTimerTick[vehicleid] ~= nil then
				return
			end
			
			for i=0, getTableSize(CIDProximityCars), 1 do
				if CIDProximityCars[i] == vehicleid then
					return
				end
			end
			
			context:addOption(getText('ContextMenu_ArmBomb'), player, CB.ActivateBomb, vehicle, time, remotelevel);
			return
		end	
		
		if player:getPerkLevel(Perks.Electricity) < 1 or player:getPerkLevel(Perks.Mechanics) <= 0 then -- players must be Electricity 2 and Mechanics 1 to plant bombs
			return
		end
		
		if bombs:size() <= 0 or remotebombs:size() <= 0 or proximitybombs:size() <= 0 or timebombs:size() <= 0 then
			if bombs:size() > 0 then
				local item = bombs:get(0)
				context:addOption(getText('ContextMenu_AddBomb'), player, CB.AddingBomb, item, nil);
			end
		
			if remotebombs:size() > 0 then
				local item = remotebombs:get(0)
				context:addOption(getText('ContextMenu_AddRemoteBomb'), player, CB.AddingBomb, item, nil);
			end
		
			if proximitybombs:size() > 0 then
				local item = proximitybombs:get(0)
				context:addOption(getText('ContextMenu_AddProximityBomb'), player, CB.AddingBomb, item, nil);
			end
		
			if timebombs:size() > 0 then
				local item = timebombs:get(0)
				
				local bombOption = context:addOption("Add Time Bomb", worldobjects, nil);
				local bombSubMenu = ISContextMenu:getNew(context);
				
				context:addSubMenu(bombOption, bombSubMenu)
				
			--	context:addOption(getText('ContextMenu_AddTimeBomb'), player, CB.AddingBomb, player, item, item);
				bombSubMenu:addOption('10 seconds', player, CB.AddingBomb, item, 0.00000001e9); --scientific notation 10
				bombSubMenu:addOption('30 seconds', player, CB.AddingBomb, item, 30);
				bombSubMenu:addOption('1 minute', player, CB.AddingBomb, item, 60);
				bombSubMenu:addOption('5 minutes', player, CB.AddingBomb, item, 300);
			end
		return
		end
	end
	return
end

CB.LinkBomb = function(remote, player, vehicleid)
    if remote:getRemoteControlID() == -1 then
        remote:setRemoteControlID(vehicleid);
    end
end

function ISVehicleMenu.showRadialMenu(player)
	old_ISVehicleMenu_showRadialMenu(player)
	
	local vehicle = player:getVehicle()
	local menu = getPlayerRadialMenu(player:getPlayerNum())
	
	if menu:isReallyVisible() then
		if menu.joyfocus then
			setJoypadFocus(player:getplayerObjNum(), nil)
		end 
		menu:undisplay()
		return
	end
	
	if vehicle ~= nil then
		local vehicledata = vehicle:getModData()
		local seat = vehicle:getSeat(player)
		if seat == 0 or seat == 1 then
			if vehicledata.Bomb then	
				menu:addSlice(getText('ContextMenu_ArmBomb'), getTexture("media/ui/vehicles/carActivateBomb.png"), CB.ActivateBomb, player, vehicle, nil) 
				menu:addToUIManager()
			end
		end
	end
end

CB.AddingBomb = function(player, item, timer)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	local engineHood = nil;
	local inventoryItems = player:getInventory():getItems()
	local vehicleid = vehicle:getId()

--	if time ~= nil then
--		CIDTimerStart[vehicleid] = time
--	end
	
	if item:getContainer() ~= player:getInventory() then
		ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), player:getInventory(), nil))
	end

	engineHood = vehicle:getPartById("EngineDoor");
	if player:getVehicle() then
		ISVehicleMenu.onExit(player)
	end
	
	if engineHood then
		ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(player, vehicle, engineHood:getArea()))
		if not engineHood:getDoor() or not engineHood:getInventoryItem() then
			engineHood = nil
		end
	else
		-- Burned vehicles and trailers don't have a hood
		ISTimedActionQueue.add(ISPathFindAction:pathToVehicleAdjacent(playerObj, vehicle))
	end
	ISTimedActionQueue.add(PlantingBomb:new(player, vehicle, item, timer))
	return
end

CB.ActivateBomb = function(player, vehicle, time, remotelevel)
	ISTimedActionQueue.add(ActivatingBomb:new(player, vehicle, time, remotelevel))
	return
end

function CB.BombCheck()
	for i=0, getTableSize(CIDTimerCars), 1 do -- a primitive timer for bombs that have been enabled
		if CIDTimerCars[i] ~= nil then 
			local vehicle = getVehicleById(CIDTimerCars[i])
			if vehicle == nil then
				table.remove(CIDTimerCars, i)
				table.remove(CIDTimerTick, vehicleid)
				table.remove(CIDTimerSeconds, vehicleid)
				break
			end
			
			local vehicleid = CIDTimerCars[i]
			local vehicledata = vehicle:getModData()
			
			if vehicledata.Bomb ~= true then
				table.remove(CIDTimerCars, i)
				table.remove(CIDTimerTick, vehicleid)
				table.remove(CIDTimerSeconds, vehicleid)
				break
			end
			
			local tick = CIDTimerTick[CIDTimerCars[i]]
			
			CIDTimerTick[CIDTimerCars[i]] = tick + 1 
			if CIDTimerTick[CIDTimerCars[i]] == 60 then
				local second = CIDTimerSeconds[CIDTimerCars[i]]	
				
				CIDTimerSeconds[vehicleid] = second + 1
				CIDTimerTick[vehicleid] = 0
				if CIDTimerSeconds[vehicleid] == CIDTimerEnd[vehicleid] then
					if getWorld():getGameMode() == "Multiplayer" then
						sendClientCommand(CIDPlayerActivated[vehicleid], "carbombs", "detonate", {["vehicleid"]=vehicleid})
					else 
						ExplodeCar(nil, vehicle)
					end
				end
			end
		end
	end
	
	for i=0, getTableSize(CIDProximityCars), 1 do -- check entities in a radius and keep a count of zombies
		if CIDProximityCars[i] ~= nil then		
			if getVehicleById(CIDProximityCars[i]) == nil then
				table.remove(CIDProximityCars, i)
				break
			end
			
			local vehicleid = CIDProximityCars[i]
			local vehicle = getVehicleById(CIDProximityCars[i])
			local vehicledata = vehicle:getModData()
			local cell = vehicle:getCell()
			local proxradius = 0;
			local objects = cell:getLuaObjectList()
			local inc = 0
			
			if tonumber(vehicledata.isProximitySensor) == 1 then
				proxradius = 8;
			elseif tonumber(vehicledata.isProximitySensor) == 2 then
				proxradius = 6;
			else 
				proxradius = 4;
			end
			
			for k,v in ipairs(objects) do
				if (vehicle:DistTo(v) < proxradius) and (v:isZombie() or v:isCharacter()) then
					inc = inc + 1
					if inc >= 6 then
						if getWorld():getGameMode() == "Multiplayer" then
							sendClientCommand(CIDPlayerActivated[vehicleid], "carbombs", "detonate", {["vehicleid"]=vehicleid})
						else 
							ExplodeCar(nil, vehicle)
						end
					end
				end
			end 
		end		
	end
end

Events.OnFillWorldObjectContextMenu.Add(CB.OnFillWorldObjectContextMenu)
Events.OnTick.Add(CB.BombCheck)