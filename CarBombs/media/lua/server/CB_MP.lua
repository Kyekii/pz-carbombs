function OnClientCommand(module, command, player, args)
	if module ~= "carbombs" then return end
	if command == "detonate" then 
		local vehicle = getVehicleById(args.vehicleid)
		ExplodeCar(player, vehicle)
	end
	
	if command == "setfire" then
		local sq = getCell():getGridSquare(args.square_x, args.square_y, args.square_z)
		local randomduration = {150,200,250,300}
		IsoFireManager.StartFire(getCell(), sq, true, 100, randomduration[ZombRand(4)+1])
	end
end

function OnServerCommand(module, command, args)
	if module ~= "carbombs" then return end
	if command == "killemall" then 
		local cell = getWorld():getCell()
		local objects = cell:getLuaObjectList()
		local vehicle = getVehicleById(args.vehicleid)
	
		if getWorld():getGameMode() == "Multiplayer" then
			getSoundManager():PlayWorldSound("ExplodeBomb", vehicle:getSquare(), 0, 600, 1, true)
		end
	
		for k,v in ipairs(objects) do
			if (vehicle:DistTo(v) < args.radius) and (v:isCharacter() or v:isZombie()) then
				v:Kill(nil);
			end	
		end  
	end
end

Events.OnClientCommand.Add(OnClientCommand)
Events.OnServerCommand.Add(OnServerCommand)