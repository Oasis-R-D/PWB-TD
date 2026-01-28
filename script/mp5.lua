-- copy this for the most basic mag loaded weapon with alt fire
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstMP5()
    return {
		RELOAD_TIME = 1.5, -- seconds
		RELOAD_SOUND = "MOD/snd/hkr.ogg",
		ALT_FIRESOUND = "MOD/snd/hkgl.ogg",
		CLIP_SIZE = 50,
		PICKUP_SIZE = 50,
		RECOIL_AMNT = 0.2,
		FIRERATE = 0.1,
		ALTFIRERATE = 1,
		DAMAGE = 0.45,
		MAX_RANGE = 100.0,
		WPNID = "hl9mmAR",
		WPNNAME = "9mmAR",
		CASING_ORG = Vec(0.02, 0.25, -0.25),		-- casing origin
	}
end

-- Per weapon data and const storers
MP5players = {}
MP5const = createConstMP5()

function createPlayerDataMP5()
    return {
		clipamntMP5 = MP5const.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
	}
end

function server.initMp5()
	RegisterTool(MP5const.WPNID, MP5const.WPNNAME, "MOD/prefab/9mmar.xml", 3)
	SetToolAmmoPickupAmount(MP5const.WPNID, MP5const.PICKUP_SIZE)
end

function server.tickMp5(dt)
	for p in PlayersAdded() do
		MP5players[p] = createPlayerDataMP5()
		SetToolEnabled(MP5const.WPNID, true, p)
		SetToolAmmo(MP5const.WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		MP5players[p] = nil
	end

	for p in Players() do
		server.tickPlayerMp5(p, dt)
	end
end

function server.tickPlayerMp5(p, dt)
	
	if GetPlayerTool(p) ~= MP5const.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(MP5const.WPNID, p)
	local data = MP5players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntMP5 < MP5const.CLIP_SIZE then
		data.coolDown = MP5const.RELOAD_TIME
		data.altCoolDown = MP5const.RELOAD_TIME
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntMP5 = MP5const.CLIP_SIZE
		if data.clipamntMP5 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntMP5 = ammo
		end
	end

	--Check if firing
	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		local mt = GetToolLocationWorldTransform("muzzle", p)

		if mt == nil then
			return
		end

		if data.coolDown < 0 then	
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.05234/2 -- assuming spread is a radian value and this is the diameter of the cone
			if crouch > 0.1 then
				spread = 0.03490/2
			end
			
			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "bullet", MP5const.DAMAGE, MP5const.MAX_RANGE, p, MP5const.WPNID)
			
			data.recoil = MP5const.RECOIL_AMNT
			data.clipamntMP5 = data.clipamntMP5 - 1
			
			if data.clipamntMP5 > 0 then
				data.coolDown = MP5const.FIRERATE
				data.altCoolDown = MP5const.FIRERATE
			else
				data.coolDown = MP5const.RELOAD_TIME
				data.altCoolDown = MP5const.RELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(MP5const.WPNID, ammo-1, p)
			end
		end
	end
	
	if InputPressed("grab", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		local mt = GetToolLocationWorldTransform("muzzle", p)

		if mt == nil then
			return
		end

		if data.altCoolDown < 0 then
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.05234/8 -- assuming spread is a radian value and this is the diameter of the cone
			if crouch > 0.1 then
				spread = 0.03490/8
			end
			
			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "rocket", MP5const.DAMAGE, MP5const.MAX_RANGE * 2, p, MP5const.WPNID)
			
			data.recoil = 1.5 * MP5const.RECOIL_AMNT
			
			data.altCoolDown = MP5const.ALTFIRERATE
			data.coolDown = MP5const.ALTFIRERATE
		end
	end
	
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
end

function client.initMp5()
	MP5shootSnd = LoadSound("MOD/snd/hks0.ogg")

	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(MP5const.WPNID, toolHaptic);
end

function client.tickMp5(dt)
	for p in PlayersAdded() do
		MP5players[p] = createPlayerDataMP5();
	end

	for p in PlayersRemoved() do
		MP5players[p] = nil
	end

	for p in Players() do
		client.tickPlayerMp5(p, dt)
	end
end

function client.tickPlayerMp5(p, dt)
	if GetPlayerTool(p) ~= MP5const.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(MP5const.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = MP5players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntMP5 < MP5const.CLIP_SIZE then
		PlaySound(LoadSound(MP5const.RELOAD_SOUND), pt.pos)
		data.coolDown = MP5const.RELOAD_TIME
		data.altCoolDown = MP5const.RELOAD_TIME
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntMP5 = MP5const.CLIP_SIZE
		if data.clipamntMP5 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntMP5 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then	
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				StopSound(data.firesound)
				data.firesound = PlaySound(MP5shootSnd, pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(MP5const.CASING_ORG[1],MP5const.CASING_ORG[2],MP5const.CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.6, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
                    SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
					
					-- muzzleflash
					for i=0, 3 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.1, 0.15), 0.33)
						ParticleAlpha(1, 0)
						ParticleColor(0.8, 0.6, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5, 1)
						ParticleCollide(0)
						ParticleColor(1,0.5,0, 1,0,0)
						SpawnParticle(mt.pos, playervel, 0.125)
					end
				
				end
					
				data.clipamntMP5 = data.clipamntMP5 - 1
				if data.clipamntMP5 > 0 then
					data.coolDown = MP5const.FIRERATE
					data.altCoolDown = MP5const.FIRERATE
				else
					PlaySound(LoadSound(MP5const.RELOAD_SOUND), pt.pos)
					data.coolDown = MP5const.RELOAD_TIME
					data.altCoolDown = MP5const.RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = MP5const.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and ammo > 0 and GetPlayerVehicle(p) == 0  and GetPlayerGrabShape() == 0 then
			if data.altCoolDown < 0 then
				
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				PlaySound(LoadSound(MP5const.ALT_FIRESOUND), pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)
					local vectuh = VecAdd(mt.pos, Vec(0, -0.25, 0))
					-- muzzleflash
					for i=0, 4 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.1, 0.15), 0.33)
						ParticleAlpha(1, 0)
						ParticleColor(0.8, 0.6, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5, 1)
						ParticleCollide(0)
						ParticleColor(1,0.5,0, 1,0,0)
						SpawnParticle(vectuh, playervel, 0.125)
						
					end
				
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
				
				data.recoil = 1.5 * MP5const.RECOIL_AMNT
				
				data.altCoolDown = MP5const.ALTFIRERATE
				data.coolDown = MP5const.ALTFIRERATE
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
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
