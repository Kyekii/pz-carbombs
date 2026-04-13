GameTime.setServerTimeShift(0) -- necessary to be able to use the following function
local getTime = GameTime.getServerTime -- cache the function to save some overhead

-- cache for benchmark 


CIDTimerEnd = {} --holds target time by carid
CIDTimerTick = {} --holds tick of timer by carid
CIDTimerSeconds = {} --hold seconds of timer by carid
CIDTimerCars = {} --car ids with car timer on
CIDProximityCars = {} --car ids with proximity on
CIDPlayerActivated = {} --activation players for client commands

local assert = assert
local type = type
local pairs = pairs

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function FindCarWreak(vehicle) -- returns the best matching vanilla car wreck to the vehicle's script name. should work for custom vehicles too
	local vehiclename = vehicle:getScriptName()

	local keyword_list = {
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
		'Van' -- 'Van' is deliberately placed last so more specific van types can take precedent, similarly to PickUpVan and PickUpTruck  
	}

	for key,value in ipairs(keyword_list) do
		if string.match(vehiclename, value) then
			if key == 3 then -- edge case for "CarLights", it's actually "Base.NormalCarBurntPolice"
				return 'Base.NormalCarBurntPolice'
			elseif key == 7 then -- edge case for "PickUpTruckLights", pickup trucks with lights are "Base.PickupSpecialBurnt" and need to have skin applied
				return 'Base.PickupSpecialBurnt'
			elseif key == 8 then -- edge case, pickup trucks are "Base.PickupBurnt"
				return 'Base.PickupBurnt'
			else
				return 'Base.' .. value .. 'Burnt' 
			end
		end
	end

	return 'Base.CarNormalBurnt' -- finally, if no matches, just return the default model
end

function RemoveBomb(player, vehicle, wasDismantled)
	local vehicledata = vehicle:getModData()
	local bombType = 'Base.PipeBomb'

	vehicledata.Bomb = nil
	
	if vehicledata.isTimed then -- remove from timed array
		bombType = 'Base.PipeBombTriggered'
		for i=0, getTableSize(CIDTimerCars), 1 do
			if CIDTimerCars[i] == vehicleid then
				table.remove(CIDTimerCars, i)
				table.remove(CIDTimerTick, vehicleid)
				table.remove(CIDTimerSeconds, vehicleid)
				break;
			end
		end
	end
	
	if vehicledata.isProximity then -- remove from proximity array
		bombType = 'Base.PipeBombSensorV' .. vehicledata.isProximitySensor
		for i=0, getTableSize(CIDProximityCars), 1 do
			if CIDProximityCars[i] == vehicleid then
				table.remove(CIDProximityCars, i)
				break
			end
		end
	end

	if vehicledata.isRemote then
		bombType = 'Base.PipeBombRemote'
	end

	if player then -- if player is specified, we know it's CB.UninstallingBomb timedaction
		if wasDismantled then
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

	if player == nil and SandboxVars.CarBombs.Ditching then -- initiate ditching, play noise and tell passengers the bomb fell off
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
		else
			local worldItem = instanceItem(bombType)
			vehicle:getSquare():AddWorldInventoryItem(worldItem, 0.5, 0.5, 0)
			getSoundManager():PlayWorldSound("BreakMetalItem", vehicle:getSquare(), 0, 20, 5.0, true)
		end

		for i=0, vehicle:getMaxPassengers() - 1, 1 do
			if vehicle:getCharacter(i) then
				vehicle:getCharacter(i):Say(getText("IGUI_BombDitched"))
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
	local posX = math.floor(vehicle:getX())
	local posY = math.floor(vehicle:getY())
	local inc = 0
	local cell = getWorld():getCell()
	local vsquare = vehicle:getSquare()
	
	for i=0, vehicle:getMaxPassengers() - 1, 1 do -- eject all players seated in vehicle, they are not long for this world
		if vehicle:getCharacter(i) then
			vehicle:exit(vehicle:getCharacter(i))
		end
	end
	
	RemoveBomb(nil, vehicle, false)

	local fuel = vehicle:getRemainingFuelPercentage() * 0.015 -- returns 0-100 - Remaining Fuel: 98.6893814 
	local radius = 5;
	radius = math.floor(radius*fuel)
	if radius < 5 then
		radius = 5
	end
	
	local vehiclecontainer = vsquare:getVehicleContainer()
	local containerarray = { }
	local flammablearray = { }
	local flammablecount = 0
	local flammablemultiplier = 0
	
	for i=0, vehiclecontainer:getPartCount(), 1 do
		local part = vehiclecontainer:getPartByIndex(i)
		if part then
			if part:getItemContainer() then
				table.insert(containerarray, part:getItemContainer())
			end
		end
	end
	
	for i=0, getTableSize(containerarray), 1 do
		local container = containerarray[i]
		if containerarray[i] ~= nil then
			if container:getItemCount("PetrolCan") > 0 then
				flammablecount = flammablecount + containerarray[i]:getItemCount("PetrolCan")
			end	
			if container:getItemCount("PropaneTank") > 0 then
				flammablecount = flammablecount + containerarray[i]:getItemCount("PropaneTank")
			end	
		end
	end

	for i=1, getTableSize(containerarray), 1 do -- go through all containers and find either propane tanks or gas cans (probably not the most efficient way of doing it)
		local container = containerarray[i]
		local gas = container:getAllEvalRecurse(function(item)
			return item:getType() == 'PetrolCan'
		end, ArrayList.new())

		local propane = container:getAllEvalRecurse(function(item)
			return item:getType() == 'PropaneTank'
		end, ArrayList.new())
		
		if gas:size() > 0 then
			for i=0, gas:size()-1, 1 do
				if gas:get(i) then
					local gasitem = gas:get(i)
					if gasitem:getFluidContainer():getPrimaryFluid() ~= nil then
						table.insert(flammablearray, gasitem)
					else
						flammablecount = flammablecount - 1 -- remove gas cans that have no fluid from count, as they're not "flammable"
					end
				end
			end  
		end
		
		if propane:size() > 0 then
			for i=0, propane:size()-1, 1 do
				if propane:get(i) then
					local propaneitem = propane:get(i)
					table.insert(flammablearray, propaneitem)
				end
			end  
		end
	end
	
	for i=1, getTableSize(flammablearray), 1 do -- add all propane tanks/gas can deltas
		local flammableitem = flammablearray[i]
		local fluidcontainer = flammableitem:getFluidContainer()
		if fluidcontainer == nil then -- propane tanks are still "DrainableComboItem" as opposed to "ComboItem" in b42.10, which handles liquids differently from the new system
			flammablemultiplier = flammablemultiplier + flammableitem:getUseDelta()
		else
			local fluid = fluidcontainer:getPrimaryFluid()
			if fluid == nil then
				break
			end

			local fluidstring = fluid:getFluidTypeString()
			if fluidcontainer and fluidstring == "Petrol" then
				local delta = (fluidcontainer:getPrimaryFluidAmount() / fluidcontainer:getCapacity()) / 8
				print('delta for gas can fluidcontainer ', delta)
				flammablemultiplier = flammablemultiplier + delta
			end
		end
	end
	
	flammablemultiplier = flammablemultiplier+1.5
	if flammablecount == 0 then
		flammablemultiplier = 1
	end
	
	radius = math.floor(radius*flammablemultiplier) -- final radius
	local numFires = math.floor((((radius^2)*9)-radius^2)*0.02)

	print('Flammable Multiplier ', flammablemultiplier)
	print('explosion radius: ', radius)
	print('number of secondary fires: ', numFires)

	if getWorld():getGameMode() ~= "Multiplayer" then
		local emitter = vehicle:getEmitter()
		emitter:playSound('ExplodeBomb', vehicle:getX(), vehicle:getY(), vehicle:getZ())
	end

	local distance = math.floor(radius/2) 
	local corner = cell:getGridSquare(posX-distance, posY-distance, vehicle:getZ())
	local tiletemp = corner
	local tiles = 0
	local row = 0

	while row < radius do -- fire iteration 1: take a square sized region around vehicle with size radius, and fill with fire
		CBStartFire(nil, tiletemp)
		tiles = tiles + 1
		tiletemp = cell:getGridSquare(tiletemp:getX()+1, tiletemp:getY(), vehicle:getZ())
		if (tiles == radius) then
			tiles = 0
			row = row + 1
			tiletemp = cell:getGridSquare(corner:getX(), tiletemp:getY()+1, vehicle:getZ())
		end
	end
	
	for i = 0, numFires do -- fire iteration 2: set random squares on fire in a region size radius*2 
		local sq = cell:getGridSquare(ZombRand(posX-radius*2, posX+radius*2), ZombRand(posY-radius*2, posY+radius*2), vehicle:getZ());
		if sq ~= nil and not sq:haveFire() then		
			CBStartFire(nil, sq)
		end
	end

	CBKillzone(vehicleid, radius)
	CBBurnCar(player, vehicle)
end

function CBKillzone(vehicleid, radius)
	if getWorld():getGameMode() == "Multiplayer" then
		sendServerCommand("carbombs", "killemall", {["vehicleid"]=vehicleid,["radius"]=radius})
	else
		local vehicle = getVehicleById(vehicleid)
		local cell = getWorld():getCell()
		local objects = cell:getLuaObjectList()
		
		for k,v in ipairs(objects) do
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
	if getWorld():getGameMode() == "Multiplayer" then
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
	local isClient = isClient()
	
	if isClient and getWorld():getGameMode() == "Multiplayer" then
		sendClientCommand(player, "carbombs", "setfire", {["square_x"]= square:getX(),["square_y"]= square:getY(),["square_z"]= square:getZ()})
	else
		local randomduration = {150,200,250,300}
		IsoFireManager.StartFire(square:getCell(), square, true, 100, randomduration[ZombRand(4)+1])
	end
end
