-- copy this for the most basic tube loaded weapon with alt fire
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstSG()
    return {
		RELOAD_TIME = 6.4, -- seconds
		RELOAD_SOUND = "MOD/snd/sgreloadstart.ogg",
		PRIM_FIRESOUND = "MOD/snd/sbarrel.ogg", 
		ALT_FIRESOUND = "MOD/snd/dbarrel.ogg",
		PUMP_SOUND = "MOD/snd/sgcock.ogg",
		CLIP_SIZE = 8,
		PICKUP_SIZE = 12,
		RECOIL_AMNT = 0.2,
		FIRERATE = 0.75,
		ALTFIRERATE = 1.5,
		DAMAGE = 0.35,
		MAX_RANGE = 60.0,
		WPNID = "hlshotgun",
		WPNNAME = "Assault Shotgun",
		CASING_ORG = Vec(0.02, 0.1, 0.075),
	}
end

-- Per weapon data and const storers
SGplayers = {}
SGconst = createConstSG()
	
function createPlayerDataSG()
    return {
		clipamntSG = SGconst.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		pumptime = nil, -- time until pump sound is played (and animations if those are ever added)
		shellinserttime = nil,
		shellstoload = 0,
		shellstopump = 0.0,
	}
end

function server.initSG()
	RegisterTool(SGconst.WPNID, SGconst.WPNNAME, "MOD/prefab/shotgun.xml", 3)
	SetToolAmmoPickupAmount(SGconst.WPNID, SGconst.PICKUP_SIZE)
end

function server.tickSG(dt)
	for p in PlayersAdded() do
		SGplayers[p] = createPlayerDataSG()
		SetToolEnabled(SGconst.WPNID, true, p)
		SetToolAmmo(SGconst.WPNID, 125, p)
	end

	for p in PlayersRemoved() do
		SGplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerSG(p, dt)
	end
end

function server.tickPlayerSG(p, dt)
	
	if GetPlayerTool(p) ~= SGconst.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(SGconst.WPNID, p)
	local data = SGplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntSG < SGconst.CLIP_SIZE then
		local reloadtime = 0
		if data.clipamntSG > 0 then
			reloadtime = SGconst.RELOAD_TIME - (0.8 * data.clipamntSG)
		else
			reloadtime = SGconst.RELOAD_TIME + 0.3
		end
		data.coolDown = reloadtime
		data.altCoolDown = reloadtime
		data.inreload = true
	end
	
	--Check if firing
	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		local mt = GetToolLocationWorldTransform("muzzle", p)

		if mt == nil then
			return
		end

		if data.coolDown < 0 then
			if data.inreload == true then
				data.inreload = false
				data.clipamntSG = SGconst.CLIP_SIZE
				if data.clipamntSG > ammo then -- make sure the clip cannot be higher than ammo
					data.clipamntSG = ammo
				end
			end
			
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.08716/2 -- assuming spread is a radian value and this is the diameter of the cone
			if crouch > 0.1 then
				spread = 0.06976/2
			end
			
			for i=0, 5 do
				local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
				dir = VecAdd(dir, rndVec(spread))
				Shoot(pos, dir, "bullet", SGconst.DAMAGE, SGconst.MAX_RANGE, p, SGconst.WPNID)
			end
			
			data.recoil = SGconst.RECOIL_AMNT
			data.clipamntSG = data.clipamntSG - 1
			
			if data.clipamntSG > 0 then
				data.coolDown = SGconst.FIRERATE
				data.altCoolDown = SGconst.FIRERATE
			else
				local reloadtime = 0
				if data.clipamntSG > 0 then
					reloadtime = SGconst.RELOAD_TIME - (0.8 * data.clipamntSG)
				else
					reloadtime = SGconst.RELOAD_TIME + 0.3
				end
				data.coolDown = reloadtime
				data.altCoolDown = reloadtime
				data.inreload =  true;
			end
			
			if ammo < 9999 then
				SetToolAmmo(SGconst.WPNID, ammo-1, p)
			end
		end
	end
	
	if InputDown("grab", p) and ammo > 1 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0  then
		local mt = GetToolLocationWorldTransform("muzzle", p)

		if mt == nil then
			return
		end

		if data.altCoolDown < 0 then
			if data.inreload == true then
				data.inreload = false
				data.clipamntSG = SGconst.CLIP_SIZE
				if data.clipamntSG > ammo then -- make sure the clip cannot be higher than ammo
					data.clipamntSG = ammo
				end
			end
			
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.08716/2 -- assuming spread is a radian value and this is the diameter of the cone
			if crouch > 0.1 then
				spread = 0.06976/2
			end
			
			for i=0, 11 do
				local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
				dir = VecAdd(dir, rndVec(spread))
				Shoot(pos, dir, "bullet", SGconst.DAMAGE, SGconst.MAX_RANGE, p, SGconst.WPNID)
			end
			
			data.recoil = 1.5 * SGconst.RECOIL_AMNT
			data.clipamntSG = data.clipamntSG - 2
			
			if data.clipamntSG > 0 then
				data.coolDown = SGconst.ALTFIRERATE
				data.altCoolDown = SGconst.ALTFIRERATE
			else
				local reloadtime = 0
				if data.clipamntSG > 0 then
					reloadtime = SGconst.RELOAD_TIME - (0.8 * data.clipamntSG)
				else
					reloadtime = SGconst.RELOAD_TIME + 0.3
				end
				data.coolDown = reloadtime
				data.altCoolDown = reloadtime
				data.inreload =  true;
			end
			
			if ammo < 9999 then
				SetToolAmmo(SGconst.WPNID, ammo-2, p)
			end
		end
	end
	
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
end

function client.initSG()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(SGconst.WPNID, toolHaptic);
end

function client.tickSG(dt)
	for p in PlayersAdded() do
		SGplayers[p] = createPlayerDataSG();
	end

	for p in PlayersRemoved() do
		SGplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerSG(p, dt)
	end
end

function client.tickPlayerSG(p, dt)
	if GetPlayerTool(p) ~= SGconst.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(SGconst.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = SGplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntSG < SGconst.CLIP_SIZE then
		PlaySound(LoadSound(SGconst.RELOAD_SOUND), pt.pos)
		local reloadtime = 0
		if data.clipamntSG > 0 then
			reloadtime = SGconst.RELOAD_TIME - (0.8 * data.clipamntSG)
			data.shellstoload = (reloadtime / 8) * 10
		else
			reloadtime = SGconst.RELOAD_TIME + 0.3
			data.pumptime = reloadtime - 0.25
			data.shellstoload = ((reloadtime - 0.3) / 8) * 10
		end
		data.coolDown = reloadtime
		data.altCoolDown = reloadtime
		data.shellinserttime = 0.8
		data.inreload = true
	end
	
	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then
				if data.inreload == true then
					data.inreload = false
					data.clipamntSG = SGconst.CLIP_SIZE
					if data.clipamntSG > ammo then -- make sure the clip cannot be higher than ammo
						data.clipamntSG = ammo
					end
				end
				
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				PlaySound(LoadSound(SGconst.PRIM_FIRESOUND), pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					data.shellstopump = 1.0
					
					-- muzzleflash
					for i=0, 3 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.1, 0.15), 0.33)
						ParticleAlpha(1, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5, 1)
						ParticleCollide(0)
						ParticleColor(1,0.35,0, 1,0,0)
						SpawnParticle(mt.pos, playervel, 0.125)
					end
				
				end
					
				data.clipamntSG = data.clipamntSG - 1
				if data.clipamntSG > 0 then
					data.altCoolDown = SGconst.FIRERATE
					data.coolDown = SGconst.FIRERATE
					data.pumptime = SGconst.FIRERATE - 0.25 -- 0.5
				else
					PlaySound(LoadSound(SGconst.RELOAD_SOUND), pt.pos)
					local reloadtime = 0
					if data.clipamntSG > 0 then
						reloadtime = SGconst.RELOAD_TIME - (0.8 * data.clipamntSG)
						data.shellstoload = (reloadtime / 8) * 10
					else
						reloadtime = SGconst.RELOAD_TIME + 0.3
						data.pumptime = reloadtime - 0.25
						data.shellstoload = ((reloadtime - 0.3) / 8) * 10
					end
					data.coolDown = reloadtime
					data.altCoolDown = reloadtime
					data.shellinserttime = 0.8
					data.inreload = true
				end
				
				data.recoil = SGconst.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputDown("grab", p) and ammo > 1 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.altCoolDown < 0 then
				if data.inreload == true then
					data.inreload = false
					data.clipamntSG = SGconst.CLIP_SIZE
					if data.clipamntSG > ammo then -- make sure the clip cannot be higher than ammo
						data.clipamntSG = ammo
					end
				end
				
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				PlaySound(LoadSound(SGconst.ALT_FIRESOUND), pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					data.shellstopump = 2
					
					-- muzzleflash
					for i=0, 4 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.15, 0.2), 0.44)
						ParticleAlpha(1, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5, 1)
						ParticleCollide(0)
						ParticleColor(1,0.35,0, 1,0,0)
						SpawnParticle(mt.pos, playervel, 0.125)
					end
				
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
				
				data.clipamntSG = data.clipamntSG - 2
				if data.clipamntSG > 0 then
					data.altCoolDown = SGconst.ALTFIRERATE
					data.coolDown = SGconst.ALTFIRERATE
					data.pumptime = SGconst.ALTFIRERATE - 0.25
				else
					PlaySound(LoadSound(SGconst.RELOAD_SOUND), pt.pos)
					local reloadtime = 0
					if data.clipamntSG > 0 then
						reloadtime = SGconst.RELOAD_TIME - (0.8 * data.clipamntSG)
						data.shellstoload = (reloadtime / 8) * 10
					else
						reloadtime = SGconst.RELOAD_TIME + 0.3
						data.pumptime = reloadtime - 0.25
						data.shellstoload = ((reloadtime - 0.3) / 8) * 10
					end
					data.coolDown = reloadtime
					data.altCoolDown = reloadtime
					data.shellinserttime = 0.8
					data.inreload = true
				end
				
				data.recoil = 1.5 * SGconst.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- SHELL LOADING
	if data.shellinserttime == nil then
	else
		data.shellinserttime = data.shellinserttime - dt
		
		if data.shellinserttime < 0 and data.shellstoload >= 0.5 then
			PlaySound(LoadSound("MOD/snd/sgshellin0.ogg"), pt.pos)
			data.shellinserttime = 0.8
			data.shellstoload = data.shellstoload - 1
			data.recoil = 0.1
			--data.clipamntSG = data.clipamntSG + 1 -- TO-DO: reimplement
			--if data.clipamntSG > SGconst.CLIP_SIZE then 
				--DebugPrint("SHELL LOADING IS FORKED")
		end
		
		if data.shellstoload <= 0 then
			data.shellinserttime = nil
		end
	end
	-- END SHELL LOADING
	
	-- PUMPING
	if data.pumptime == nil then
	else
		data.pumptime = data.pumptime - dt
	
		-- pump the gun
		if data.pumptime < 0 then
			PlaySound(LoadSound(SGconst.PUMP_SOUND), pt.pos)
			data.pumptime = nil
			-- SHELL EJECT
			local toolBody = GetToolBody(p)
			if toolBody ~= 0 then 
				local transform = GetBodyTransform(toolBody)
				local eject_origin = TransformToParentPoint(transform, Vec(SGconst.CASING_ORG[1],SGconst.CASING_ORG[2],SGconst.CASING_ORG[3]))
				local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
				local playervel = GetPlayerVelocity(p)
				
				for i=1, data.shellstopump do
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.1, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
				end
			end
			-- SHELL EJECT END
		end
	end
	-- END PUMPING
	
	-- RECOIL
	if data.recoil > 0 then
		local recoil = math.max(0, data.recoil)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil)
		
		local inversesiderecoil = rnd(0, 1)
		if inversesiderecoil > 0.5 then
			siderecoil = siderecoil * -1
		end

		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)
end
