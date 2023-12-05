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

function ExplodeCar(player, vehicle)
	print("Starting ExplodeCar on vehicle ", vehicle)
	local vehicledata = vehicle:getModData()
	local vehicleid = vehicle:getId() --temp
	local posX = math.floor(vehicle:getX());
	local posY = math.floor(vehicle:getY());
	local inc = 0;
	local cell = getWorld():getCell();
	local vsquare = vehicle:getSquare();

	vehicledata.Bomb = nil;
	
	if vehicledata.isTimed == true then -- remove from timed array
		for i=0, getTableSize(CIDTimerCars), 1 do
			if CIDTimerCars[i] == vehicleid then
				table.remove(CIDTimerCars, i)
				table.remove(CIDTimerTick, vehicleid)
				table.remove(CIDTimerSeconds, vehicleid)
				break;
			end
		end
	end
	
	if vehicledata.isProximity == true then -- remove from proximity array
		for i=0, getTableSize(CIDProximityCars), 1 do
			if CIDProximityCars[i] == vehicleid then
				table.remove(CIDProximityCars, i)
				break;
			end
		end
	end
	
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

	for i=1, getTableSize(containerarray), 1 do --go through all containers and find either propane tanks or gas cans (probably not the most efficient way of doing it)
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
					table.insert(flammablearray, gasitem)
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
		flammablemultiplier = flammablemultiplier + flammableitem:getUseDelta()
	end
	
	flammablemultiplier = flammablemultiplier+1.5
	if flammablecount == 0 then
		flammablemultiplier = 1
	end
	
	radius = math.floor(radius*flammablemultiplier) -- final radius
	print('Flammable Multiplier ', flammablemultiplier)
	print('explosion radius: ', radius)
	print('number of secondary fires: ', numFires)
	local numFires = math.floor((((radius^2)*9)-radius^2)*0.02)
	
	if getWorld():getGameMode() ~= "Multiplayer" then
		getSoundManager():PlayWorldSound("ExplodeBomb", vehicle:getSquare(), 0, 600, 1, true)
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
--[[	for k,v in ipairs(objects) do
		print("vehicle distto ", vehicle:DistTo(v))
		print("radius ", radius)
		print("isCharacter ", v:isCharacter(), " isZombie ", v:isZombie())
		if (vehicle:DistTo(v) < radius) and (v:isCharacter() or v:isZombie()) then
			print('Killing ', v)
			v:getBodyDamage():setHealth(0);
		end	
	end  --]]
	
	CBBurnCar(player, vehicle)
end

function CBKillzone(vehicleid, radius)
	
	if getWorld():getGameMode() == "Multiplayer" then
		sendServerCommand("carbombs", "killemall", {["vehicleid"]=vehicleid,["radius"]=radius})
	else
		local vehicle = getVehicleById(vehicleid)
		local cell = getWorld():getCell();
		local objects = cell:getLuaObjectList();
		
		for k,v in ipairs(objects) do
			if (vehicle:DistTo(v) < radius) and (v:isCharacter() or v:isZombie()) then
				v:Kill(nil);
			end	
		end  
	end
end

function CBBurnCar(player, vehicle)
	
	if getWorld():getGameMode() == "Multiplayer" then
		vehicle:permanentlyRemove()
	else
		vehicle:setScriptName("Base.CarNormalBurnt")
		vehicle:scriptReloaded()
	end
end

function CBStartFire(player, square)
	local isClient = isClient()
	
	if isClient and getWorld():getGameMode() == "Multiplayer" then
		sendClientCommand(player, "carbombs", "setfire", {["square_x"]= square:getX(),["square_y"]= square:getY(),["square_z"]= square:getZ()})
	else
		local randomduration = {150,200,250,300}
		IsoFireManager.StartFire(square:getCell(), square, true, 100, randomduration[ZombRand(4)+1]);
	end
end
