-- Car Bombs for Project Zomboid
-- programmed by Kyeki, 2023
--
-- GPL-3.0
-- https://github.com/Kyekii/pz-carbombs
--
-- v1.2 - B42 

local CB = {}

local old_ISVehicleMenu_showRadialMenu = ISVehicleMenu.showRadialMenu
	
function ISInventoryPaneContextMenu.OnTriggerRemoteController(remoteController, player) -- this replaces the original game's OnTriggerRemoteController. this allows for other remote mods and vanilla remotes, on top of carbombs, to function properly
	local vehicleid = remoteController:getRemoteControlID()
	local vehicle = getVehicleById(vehicleid)
	
	if vehicle ~= nil then
		local vehicledata = vehicle:getModData()
		if vehicledata ~= nil then
			if vehicledata.Bomb ~= nil and vehicledata.isRemote == true then
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

				CB.ActivateBomb(player, vehicle, nil, remotelevel)
				return
			end 
		end
	else 
		local playerObj = getSpecificPlayer(player);
		local args = { id=remoteController:getRemoteControlID(), range=remoteController:getRemoteRange() }
		sendClientCommand(playerObj, 'object', 'triggerRemote', args)
	end
end 

function CB.OnFillWorldObjectContextMenu(playerId, context, worldobjects, test)
	local player = getSpecificPlayer(playerId)
	local inventory = player:getInventory()
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	
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

	if vehicle and not player:isSeatedInVehicle() then -- prevents accessing options while in car
		local vehiclename = vehicle:getScriptName()
		local vehicledata = vehicle:getModData()
		local vehicleid = vehicle:getId()
		
		if string.find(vehiclename, "Burnt") then
			return
		end
		
		if vehicledata.Bomb then
			if CIDTimerTick[vehicleid] ~= nil then
				return
			end
			
			for i=0, getTableSize(CIDProximityCars), 1 do
				if CIDProximityCars[i] == vehicleid then
					return
				end
			end

			if vehicledata.isRemote == true and remote:size() > 0 then
				for i=0, player:getInventory():getItems():size() -1 do
					local item = player:getInventory():getItems():get(i)
					if item:isRemoteController() and item:getRemoteControlID() == -1 then
						context:addOption(getText("ContextMenu_AddCarTrigger"), item, CB.LinkBomb, player, vehicleid)
					end
				end
			end
			
			local armbomb = context:addOption(getText('ContextMenu_ArmBomb'), player, CB.ActivateBomb, vehicle, time, remotelevel);
			if vehicledata.isProximity ~= true and vehicledata.isTimed ~= true then
				local tooltip = ISWorldObjectContextMenu.addToolTip();
				tooltip.description = getText("ContextMenu_CarBombSuicide");
				armbomb.toolTip = tooltip;
			end

			if player:getPerkLevel(Perks.Electricity) < 1 or player:getPerkLevel(Perks.Mechanics) <= 0 then -- need Electricity 2 and Mechanics 1 to remove bombs, too
				return
			end

			local uninstallbomb = context:addOption(getText("ContextMenu_UninstallBomb"), player, CB.UninstallBomb, vehicle)
		--	local tooltip = ISWorldObjectContextMenu.addToolTip();
		--	tooltip.description = getText("ContextMenu_CarBombSuicide");
		--	armbomb.toolTip = tooltip;
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
				bombSubMenu:addOption('10 seconds', player, CB.AddingBomb, item, 10);
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

function CB.UninstallBomb(player, vehicle)
	local engineHood = nil;
	local vehicleid = vehicle:getId()
	
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
		ISTimedActionQueue.add(ISPathFindAction:pathToVehicleAdjacent(playerObj, vehicle))
	end
	ISTimedActionQueue.add(UninstallingBomb:new(player, vehicle))
	return
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

CB.AddingBomb = function(player, item, vehicle, timer)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	local engineHood = nil;
	local inventoryItems = player:getInventory():getItems()
	local vehicleid = vehicle:getId()
	
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

function CB.CrashCheck() -- check every tick to find players currently driving and check their velocity for sudden changes
	if SandboxVars.CarBombs.AccidentalDetonation then
		if getWorld():getGameMode() == "Multiplayer" then
			players = getOnlinePlayers();
		else
			players = IsoPlayer.getPlayers()
		end

		for i=0, players:size() - 1, 1 do -- this could be inefficient? idk
			if players:get(i) ~= nil then
				local player = players:get(i)
				if player:isSeatedInVehicle() then
					-- pz's driving system uses vectors in java to determine crash speeds, but i couldn't figure out a way to access them via lua. so i just made my own vectors instead.
					local vehicle = player:getVehicle()
					local vehicledata = vehicle:getModData()

					if vehicledata.Bomb then
						local velocityvector = Vector3f.new() -- initializes vector
						local velocitychangedelta = 1.0 -- if the difference in last velocity vs current is greater than delta, car probably crashed
						
						velocityvector = vehicle:getLinearVelocity(velocityvector)
						
						if velocityvector:length() > 6.0 then -- change delta if vehicle is moving fast enough. braking at high speeds otherwise could be misinterpreted
							velocitychangedelta = 2.0
							print('velocitydelta now 2.0')
						elseif velocityvector:length() > 10.0 then
							velocitychangedelta = 3.0
							print('velocitydelta now 3.0')
						end

						if vehicledata.lastVelocity then -- if the difference in last velocity vector and current velocity vector is greater than delta, crash
							if vehicledata.lastVelocity:length() > velocityvector:length() and (vehicledata.lastVelocity:length() - velocityvector:length()) > velocitychangedelta then
								vehicledata.bombHealth = vehicledata.bombHealth - math.ceil(vehicledata.lastVelocity:length() - velocityvector:length())
								print('CarBombs accident! bombhealth ', vehicledata.bombHealth)
								print('Velocity difference: ', vehicledata.lastVelocity:length() - velocityvector:length())

								if vehicledata.bombHealth <= 0.0 then
									if getWorld():getGameMode() == "Multiplayer" then
										sendClientCommand(vehicle:getId(), "carbombs", "detonate", {["vehicleid"]=vehicle:getId()})
									else 
										ExplodeCar(nil, vehicle)
									end
								end

								-- ditching is disabled above 40km/h. this incentivizes cautious driving, vs slamming into trees and expecting the bomb to just "fall off"
								if SandboxVars.CarBombs.Ditching and vehicledata.bombHealth >= 0.0 and vehicle:getCurrentSpeedKmHour() < 40 then
									if (SandboxVars.CarBombs.DitchingStartThreshold * vehicledata.bombStartHealth) >= vehicledata.bombHealth then
										local ditchodds = (1 - (vehicledata.bombHealth)/(SandboxVars.CarBombs.DitchingStartThreshold * vehicledata.bombStartHealth))
										local ditchroll = ZombRandFloat(0.00, 1.00)

										if SandboxVars.CarBombs.DitchingEndThreshold * vehicledata.bombStartHealth >= vehicledata.bombHealth then
											ditchodds = SandboxVars.CarBombs.DitchingMaxChance
										end

										print('ditchodds ', ditchodds, 'ditchroll ', ditchroll)
										if ditchroll <= ditchodds then
											print('Successful ditch roll')
											RemoveBomb(nil, vehicle, false)
											-- wip: add chance of bomb falling off and being scrapped
										end
									end
								end
							end	
						end
						vehicledata.lastVelocity = velocityvector
					end
				end
			end
		end
	end
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
Events.OnTick.Add(CB.CrashCheck)