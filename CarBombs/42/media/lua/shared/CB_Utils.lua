CIDTimerEnd = {} -- holds target time by carid
CIDTimerTick = {} -- holds tick of timer by carid
CIDTimerSeconds = {} -- hold seconds of timer by carid
CIDTimerCars = {} -- car ids with car timer on
CIDProximityCars = {} -- car ids with proximity on
CIDPlayerActivated = {} -- activation players for client commands

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function FindCarWreak(vehicle) -- returns the best matching vanilla car wreck to the vehicle's script name. should work for custom vehicles too
	local vehiclename = vehicle:getScriptName()
	local keywordlist = {
		'ModernCar', -- handcrafted keyword list based on vanilla burnt models. i put more common vehicles first to speed this up
		'ModernCar02',
		'CarLights',
		'LuxuryCar',
		'PickUpVanLights',
		'PickUpVan',
		'PickUpTruckLights',
		'PickUpTruck',
		'OffRoad',
		'RaceCar',
		'SUV',
		'SmallCar',
		'SmallCar02',
		'SportsCar',
		'Taxi',
		'Ambulance',
		'VanSeats',
		'VanRadio',
		'Van' -- "Van" is deliberately placed last so more specific van types can take precedent, similarly to PickUpVan and PickUpTruck
	}

	for k,v in ipairs(keywordlist) do
		if string.match(vehiclename, v) then
			if k == 3 then -- edge case for "CarLights", it's actually "Base.NormalCarBurntPolice"
				return 'Base.NormalCarBurntPolice'
			elseif k == 7 then -- edge case for "PickUpTruckLights", pickup trucks with lights are "Base.PickupSpecialBurnt" and need to have skin applied
				return 'Base.PickupSpecialBurnt'
			elseif k == 8 then -- edge case, pickup trucks are "Base.PickupBurnt"
				return 'Base.PickupBurnt'
			else
				return 'Base.' .. v .. 'Burnt'
			end
		end
	end

	return 'Base.CarNormalBurnt' -- finally, if no matches, just return the default model
end

function RemoveBomb(player, vehicle, wasDismantled, wasDetonated)
	local vehicledata = vehicle:getModData()
	local vehicleid = vehicle:getId()
	local bombtype = 'Base.PipeBomb'
	vehicledata.Bomb = nil

	if vehicledata.isTimed and wasDetonated then -- remove from timed array
		bombtype = 'Base.PipeBombTriggered'
		for i=0, getTableSize(CIDTimerCars), 1 do
			if CIDTimerCars[i] == vehicleid then
				table.remove(CIDTimerCars, i)
				table.remove(CIDTimerTick, vehicleid)
				table.remove(CIDTimerSeconds, vehicleid)
				break;
			end
		end
	end

	if vehicledata.isProximity and wasDetonated then -- remove from proximity array
		bombtype = 'Base.PipeBombSensorV' .. vehicledata.isProximitySensor
		for i=0, getTableSize(CIDProximityCars), 1 do
			if CIDProximityCars[i] == vehicleid then
				table.remove(CIDProximityCars, i)
				break
			end
		end
	end

	if vehicledata.isRemote then
		bombtype = 'Base.PipeBombRemote'
	end

	if player then -- if player is specified, we know it's CB.UninstallingBomb timedaction
		if wasDismantled and not wasDetonated then
			local worldItem = nil
			for i=0, ZombRand(3)+1, 1 do -- 1-3 electronic scrap
				worldItem = instanceItem('Base.ElectronicsScrap')
				player:getSquare():AddWorldInventoryItem(worldItem, ZombRand(0.1, 0.5), ZombRand(0.1, 0.5), 0)
			end
			if (ZombRand(0, 100)+1)/100 > 0.50 then -- random condition for pipe, if above 50% just make it a broken one, because i'm evil >:)
				worldItem = instanceItem('Base.MetalPipe_Broken')
				worldItem:setCondition(ZombRand((worldItem:getConditionMax()/2))+1) -- make sure the random condition is always below 50%
				player:getSquare():AddWorldInventoryItem(worldItem, ZombRand(0.1, 0.5), ZombRand(0.1, 0.5), 0)
			else
				worldItem = instanceItem('Base.MetalPipe')
				worldItem:setCondition(ZombRand(worldItem:getConditionMax()/2) + (worldItem:getConditionMax()/2)) -- condition always above 50%
			end
			return
		else
			local inventoryItem = instanceItem(bombType)
			player:getInventory():AddItem(inventoryItem)
			return
		end
	end

	if player == nil and SandboxVars.CarBombs.Ditching and not wasDetonated then -- initiate ditching, play noise and tell passengers the bomb fell off
		if wasDismantled then
			local worldItem = nil
			for i=0, ZombRand(3)+1, 1 do -- 1-3 electronic scrap
				worldItem = instanceItem('Base.ElectronicsScrap')
				vehicle:getSquare():AddWorldInventoryItem(worldItem, ZombRand(0.1, 0.5), ZombRand(0.1, 0.5), 0)
			end
			if (ZombRand(0, 100)+1)/100 > 0.50 then
				worldItem = instanceItem('Base.MetalPipe_Broken')
				worldItem:setCondition(ZombRand((worldItem:getConditionMax()/2))+1) -- make sure the random condition is always below 50%
				vehicle:getSquare():AddWorldInventoryItem(worldItem, ZombRand(0.1, 0.5), ZombRand(0.1, 0.5), 0)
			else
				worldItem = instanceItem('Base.MetalPipe')
				worldItem:setCondition(ZombRand(worldItem:getConditionMax()/2) + (worldItem:getConditionMax()/2)) -- condition always above 50%
			end
		elseif wasDismantled then
			local worldItem = instanceItem(bombType)
			vehicle:getSquare():AddWorldInventoryItem(worldItem, 0.5, 0.5, 0)
			getSoundManager():PlayWorldSound('BreakMetalItem', vehicle:getSquare(), 0, 20, 5.0, true)
		end

		for i=0, vehicle:getMaxPassengers() - 1, 1 do
			if vehicle:getCharacter(i) then
				vehicle:getCharacter(i):Say(getText('IGUI_BombDitched'))
			end
		end
	end
end

function GetUninstallChance(player)
	local successchance = nil
	local dismantlechance = nil

	if player:getPerkLevel(Perks.Electricity) < 2 then -- since we know the player will need electricity 2 to uninstall, only 3 and above will actually increase the odds
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

	return successchance, dismantlechance
end

function ExplodeCar(player, vehicle)
	local vehicledata = vehicle:getModData()
	local vehicleid = vehicle:getId()
	local vehiclesquare = vehicle:getSquare()
	local posX = math.floor(vehicle:getX())
	local posY = math.floor(vehicle:getY())
	local cell = getWorld():getCell()
	local radius = 5;
	local vehiclecontainer = vehiclesquare:getVehicleContainer()
	local containerarray = {}
	local flammablearray = {}
	local flammablemultiplier = 0

	RemoveBomb(nil, vehicle, false, true)

	for i=0, vehicle:getMaxPassengers() - 1, 1 do -- eject all players seated in vehicle, they are not long for this world
		if vehicle:getCharacter(i) then
			vehicle:exit(vehicle:getCharacter(i))
		end
	end

	if vehicle:getRemainingFuelPercentage() > 50 and not NaN then -- this will return NaN if there is no fuel tank
		radius = math.floor(radius + (vehicle:getRemainingFuelPercentage() * 0.025))
	end

	for i = 0, vehiclecontainer:getPartCount(), 1 do
		local part = vehiclecontainer:getPartByIndex(i)
		if part then
			if part:getItemContainer() then
				table.insert(containerarray, part:getItemContainer())
			end
		end
	end

	for i = 0, getTableSize(containerarray), 1 do -- find all flammable items and add to array
		local container = containerarray[i]
		if container ~= nil then
			if container:getItemCount('PetrolCan') > 0 then
				local gascans = container:getAllTypeRecurse('PetrolCan')
				for i=0, gascans:size() - 1, 1 do
					if gascans:get(i) then
						local can = gascans:get(i)
						if can:getFluidContainer():getPrimaryFluid() ~= nil then
							table.insert(flammablearray, gasitem)
						end
					end
				end
			end

			if container:getItemCount('PropaneTank') > 0 then
				local propanetanks = container:getAllTypeRecurse('PropaneTank')
				for i=0, propanetanks:size() - 1, 1 do
					if propanetanks:get(i) then
						local propaneitem = propanetanks:get(i)
						table.insert(flammablearray, propaneitem)
					end
				end
			end

			if container:getItemCount('Fertilizer') > 0 then
				local fertilizer = container:getAllTypeRecurse('Fertilizer')
				for i = 0, fertilizer:size() - 1, 1 do
					if fertilizer:get(i) then
						local fertilizeritem = fertilizer:get(i)
						table.insert(flammablearray, fertilizeritem)
					end
				end
			end
		end
	end

	for i = 1, getTableSize(flammablearray), 1 do -- get all flammable items from array and calculate deltas
		local flammableitem = flammablearray[i]
		local fluidcontainer = flammableitem:getFluidContainer()

		if flammableitem:getType() == 'Fertilizer' or 'PropaneTank' then
			local delta = flammableitem:getCurrentUsesFloat()
			if delta > 0.5 then
				flammablemultiplier = flammablemultiplier + 0.5
			elseif delta > 0.25 then
				flammablemultiplier = flammablemultiplier + 0.25
			end
		else
			local fluid = fluidcontainer:getPrimaryFluid()
			if fluid == nil then break end
			local fluidstring = fluid:getFluidTypeString()
			if fluidcontainer and fluidstring == 'Petrol' then
				local delta = (fluidcontainer:getPrimaryFluidAmount() / fluidcontainer:getCapacity()) / 8
				flammablemultiplier = flammablemultiplier + delta
			end
		end
	end

	if getTableSize(flammablearray) == 0 then
		flammablemultiplier = 1
	else
		flammablemultiplier = flammablemultiplier + 1.5
	end

	radius = math.floor(radius * flammablemultiplier) -- final radius
	local firecount = math.floor((((radius ^ 2) * 9) - radius ^ 2) * 0.02)
	print('[CarBombs] Vehicle ' .. vehicleid .. ' detonation: FlammableMultiplier ' .. flammablemultiplier .. ', radius ' .. radius)
	print('[CarBombs] flammablearray size: ' .. getTableSize(flammablearray))

	if getWorld():getGameMode() ~= 'Multiplayer' then
		local emitter = vehicle:getEmitter()
		emitter:playSound('ExplodeBomb', vehicle:getX(), vehicle:getY(), vehicle:getZ())
	end

	local distance = math.floor(radius/2)
	local corner = cell:getGridSquare(posX-distance, posY-distance, vehicle:getZ())
	local tiletemp = corner

	for i = 0, radius - 1 do -- fire iteration 1: take a square sized region around vehicle with size radius, and fill with fire
		for i = 0, radius - 1 do
			CBStartFire(nil, tiletemp)
			tiletemp = cell:getGridSquare(tiletemp:getX() + 1, tiletemp:getY(), vehicle:getZ())
		end
		tiletemp = cell:getGridSquare(corner:getX(), tiletemp:getY() + 1, vehicle:getZ())
	end

	for i = 0, firecount do -- fire iteration 2: set random squares on fire in a region size radius * 2
		local sq = cell:getGridSquare(ZombRand(posX-radius * 2, posX+radius * 2), ZombRand(posY - radius * 2, posY + radius * 2), vehicle:getZ());
		if sq ~= nil and not sq:haveFire() then
			CBStartFire(nil, sq)
		end
	end

	CBKillzone(vehicleid, radius)
	CBBurnCar(player, vehicle)
end

function CBKillzone(vehicleid, radius)
	if getWorld():getGameMode() == 'Multiplayer' then
		sendServerCommand('carbombs', 'killemall', {['vehicleid'] = vehicleid, ['radius'] = radius})
	else
		local vehicle = getVehicleById(vehicleid)
		local cell = getWorld():getCell()
		local objects = cell:getLuaObjectList()

		for _,v in ipairs(objects) do
			if (vehicle:DistTo(v) < radius) and (v:isCharacter() or v:isZombie()) then
				if not v:isZombie() and v:getBodyDamage():isInfected() then -- disable coming back as a zombie via car explosion (for obvious reasons)
					local body = v:getBodyDamage()
					body:setInfected(false)
					body:setInfectionMortalityDuration(0)
					body:setInfectionTime(0)
					body:setInfectionLevel(0)
				end
				v:Kill(nil)
			end
		end
	end
end

function CBBurnCar(player, vehicle)
	if getWorld():getGameMode() == 'Multiplayer' then
		vehicle:permanentlyRemove()
	else
		local wreckname = FindCarWreak(vehicle)
		local vehiclename = vehicle:getScriptName()
		local skinindex = 0

		if wreckname == 'Base.PickupSpecialBurnt' then -- select the proper special pickup truck model
			if vehiclename == 'Base.PickUpTruckLightsFire' then
				skinindex = 0
			elseif vehiclename == 'Base.PickUpTruckLightsFossoil' then
				skinindex = 1
			else -- there's a ranger skin on index 3, but i couldn't get it working for some reason
				wreckname = 'Base.PickupBurnt'
			end
		end

		vehicle:setScriptName(wreckname)
		vehicle:setSkinIndex(skinindex)
		vehicle:transmitSkinIndex()
		vehicle:scriptReloaded()
	end
end

function CBStartFire(player, square)
	if isClient() and getWorld():getGameMode() == 'Multiplayer' then
		sendClientCommand(player, 'carbombs', 'setfire', {['square_x'] = square:getX(), ['square_y'] = square:getY(), ['square_z'] = square:getZ()})
	else
		local randomduration = {150, 200, 250, 300}
		IsoFireManager.StartFire(square:getCell(), square, true, 100, randomduration[ZombRand(4) + 1])
	end
end
