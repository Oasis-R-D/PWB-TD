-- copy this for the most basic mag loaded weapon with slower empty reloads
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstDE357()
    return {
		RELOAD_TIME = 2.32, -- seconds
		EMPTYRELOAD_TIME = 4.1, -- seconds
		RELOAD_SOUND = "MOD/snd/DeagR.ogg",
		PRIM_FIRESOUND = "MOD/snd/DeagFR.ogg", 
		ALT_FIRESOUND = "MOD/snd/DeagLaser.ogg",
		CLIP_SIZE = 7.0,
		PICKUP_SIZE = 15.0,
		RECOIL_AMNT = 0.25,
		FIRERATE = 0.22, -- laser off
		LASERFIRERATE = 0.5, -- laser on
		ALTFIRERATE = 0.125,
		DAMAGE = 1,
		MAX_RANGE = 150.0,
		WPNID = "deagle",
		WPNNAME = "Desert Eagle",
		CASING_ORG = Vec(0.02, 0.25, 0.1),
	}
end

-- Per weapon data and const storers
DE357players = {}
DE357const = createConstDE357()

function createPlayerDataDE357()
    return {
		clipamntDE357 = DE357const.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		laseron = false,
		firesound = nil,
	}
end

function server.initDE357()
	RegisterTool(DE357const.WPNID, DE357const.WPNNAME, "MOD/prefab/deagle.xml", 2)
	SetToolAmmoPickupAmount(DE357const.WPNID, DE357const.PICKUP_SIZE)
end

function server.tickDE357(dt)
	for p in PlayersAdded() do
		DE357players[p] = createPlayerDataDE357()
		SetToolEnabled(DE357const.WPNID, true, p)
		SetToolAmmo(DE357const.WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		DE357players[p] = nil
	end

	for p in Players() do
		server.tickPlayerDE357(p, dt)
	end
end

function server.tickPlayerDE357(p, dt)
	
	if GetPlayerTool(p) ~= DE357const.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(DE357const.WPNID, p)
	local data = DE357players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntDE357 < DE357const.CLIP_SIZE then
		if data.clipamntDE357 > 0 then
			data.coolDown = DE357const.RELOAD_TIME
			data.altCoolDown = DE357const.RELOAD_TIME
		else
			data.coolDown = DE357const.EMPTYRELOAD_TIME
			data.altCoolDown = DE357const.EMPTYRELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntDE357 = DE357const.CLIP_SIZE
		if data.clipamntDE357 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntDE357 = ammo
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
			
			local spread = 0.1/2 -- assuming spread is a radian value and this is the diameter of the cone
			if data.laseron == true then
				spread = 0.001/2
			end

			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "bullet", DE357const.DAMAGE, DE357const.MAX_RANGE, p, DE357const.WPNID)

			data.recoil = DE357const.RECOIL_AMNT
			data.clipamntDE357 = data.clipamntDE357 - 1
			
			if data.clipamntDE357 > 0 then
				if data.laseron == true then
					data.coolDown = DE357const.LASERFIRERATE
					data.altCoolDown = DE357const.LASERFIRERATE
				else
					data.coolDown = DE357const.FIRERATE
					data.altCoolDown = DE357const.FIRERATE
				end
			else
				data.coolDown = DE357const.EMPTYRELOAD_TIME
				data.altCoolDown = DE357const.EMPTYRELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(DE357const.WPNID, ammo-1, p)
			end
		end
	end
	
	if InputPressed("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.altCoolDown = DE357const.ALTFIRERATE
			data.coolDown = DE357const.ALTFIRERATE
			data.laseron = not data.laseron
		end
	end
	
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
end

function client.initDE357()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(DE357const.WPNID, toolHaptic);
end

function client.tickDE357(dt)
	for p in PlayersAdded() do
		DE357players[p] = createPlayerDataDE357();
	end

	for p in PlayersRemoved() do
		DE357players[p] = nil
	end

	for p in Players() do
		client.tickPlayerDE357(p, dt)
	end
end

function client.tickPlayerDE357(p, dt)
	if GetPlayerTool(p) ~= DE357const.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(DE357const.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = DE357players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntDE357 < DE357const.CLIP_SIZE then
		PlaySound(LoadSound(DE357const.RELOAD_SOUND), pt.pos)
		if data.clipamntDE357 > 0 then
			data.coolDown = DE357const.RELOAD_TIME
			data.altCoolDown = DE357const.RELOAD_TIME
		else
			data.coolDown = DE357const.EMPTYRELOAD_TIME
			data.altCoolDown = DE357const.EMPTYRELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntDE357 = DE357const.CLIP_SIZE
		if data.clipamntDE357 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntDE357 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then	
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				
				StopSound(data.firesound)
				data.firesound = PlaySound(LoadSound(DE357const.PRIM_FIRESOUND), pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(DE357const.CASING_ORG[1],DE357const.CASING_ORG[2],DE357const.CASING_ORG[3]))
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
					
				data.clipamntDE357 = data.clipamntDE357 - 1
				if data.clipamntDE357 > 0 then
					if data.laseron == true then
						data.coolDown = DE357const.LASERFIRERATE
						data.altCoolDown = DE357const.LASERFIRERATE
					else
						data.coolDown = DE357const.FIRERATE
						data.altCoolDown = DE357const.FIRERATE
					end
				else
					PlaySound(LoadSound(DE357const.RELOAD_SOUND), pt.pos)
					data.coolDown = DE357const.EMPTYRELOAD_TIME
					data.altCoolDown = DE357const.EMPTYRELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = DE357const.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.toolAnimator.forceActionPose = true
			PlaySound(LoadSound(DE357const.ALT_FIRESOUND), pt.pos)
			data.altCoolDown = DE357const.ALTFIRERATE
			data.coolDown = DE357const.SCOPEFIREDELAY
			data.laseron = not data.laseron
		end
	end

	if data.laseron == false then
		data.toolAnimator.forceActionPose = false
	end
	
	-- TO-DO: add laser vfx
	if data.laseron == true then
		data.toolAnimator.timeSinceFire = 0.0 -- use force on instead?
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
