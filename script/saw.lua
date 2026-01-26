-- copy this for the most basic mag loaded weapon
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstM249()
    return {
		RELOAD_TIME = 3.8, -- seconds
		RELOAD_SOUND = "MOD/snd/m249r.ogg",
		CLIP_SIZE = 50,
		PICKUP_SIZE = 200,
		RECOIL_AMNT = 0.2,
		FIRERATE = 0.067, -- NO
		DAMAGE = 0.33,
		MAX_RANGE = 100.0,
		WPNID = "m249_saw",
		WPNNAME = "M249",
	}
end

-- Per weapon data and const storers
M249players = {}
M249const = createConstM249()

function createPlayerDataM249()
    return {
		clipamntM249 = M249const.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		alteject = false, -- M249 ejects both the belt bits and bullets (alternating between them in opfor tho)
	}
end

function server.initM249()
	RegisterTool(M249const.WPNID, M249const.WPNNAME, "MOD/prefab/9mmar.xml", 4)
	SetToolAmmoPickupAmount(M249const.WPNID, M249const.PICKUP_SIZE)
end

function server.tickM249(dt)
	for p in PlayersAdded() do
		M249players[p] = createPlayerDataM249()
		SetToolEnabled(M249const.WPNID, true, p)
		SetToolAmmo(M249const.WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		M249players[p] = nil
	end

	for p in Players() do
		server.tickPlayerM249(p, dt)
	end
end

function server.tickPlayerM249(p, dt)
	
	if GetPlayerTool(p) ~= M249const.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(M249const.WPNID, p)
	local data = M249players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntM249 < M249const.CLIP_SIZE then
		data.coolDown = M249const.RELOAD_TIME
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
				data.clipamntM249 = M249const.CLIP_SIZE
				if data.clipamntM249 > ammo then -- make sure the clip cannot be higher than ammo
					data.clipamntM249 = ammo
				end
			end
			
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.05234/2 -- assuming spread is a radian value and this is the diameter of the cone
			if crouch > 0.1 then
				spread = 0.03490/2
			end
			
			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "bullet", M249const.DAMAGE, M249const.MAX_RANGE, p, M249const.WPNID)
			
			data.recoil = M249const.RECOIL_AMNT
			data.clipamntM249 = data.clipamntM249 - 1
			
			if data.clipamntM249 > 0 then
				data.coolDown = M249const.FIRERATE
			else
				data.coolDown = M249const.RELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(M249const.WPNID, ammo-1, p)
			end
		end
	end
	
	data.coolDown = data.coolDown - dt
end

function client.initM249()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(M249const.WPNID, toolHaptic);
end

function client.tickM249(dt)
	for p in PlayersAdded() do
		M249players[p] = createPlayerDataM249();
	end

	for p in PlayersRemoved() do
		M249players[p] = nil
	end

	for p in Players() do
		client.tickPlayerM249(p, dt)
	end
end

CASING_ORG = Vec(0.02, 0.25, -0.25)		-- casing origin

function client.tickPlayerM249(p, dt)
	if GetPlayerTool(p) ~= M249const.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(M249const.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = M249players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntM249 < M249const.CLIP_SIZE then
		PlaySound(LoadSound(M249const.RELOAD_SOUND), pt.pos)
		data.coolDown = M249const.RELOAD_TIME
		data.inreload = true
	end
	
	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then
				if data.inreload == true then
					data.inreload = false
					data.clipamntM249 = M249const.CLIP_SIZE
					if data.clipamntM249 > ammo then -- make sure the clip cannot be higher than ammo
						data.clipamntM249 = ammo
					end
				end
				
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				PlaySound(shootSnd[math.random(0,#shootSnd)], pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					if data.alteject == true then -- this is unrealistic, it should eject BOTH at the same time but HLOPFOR works like this soooooo
						ParticleColor(0.8, 0.6, 0)
					else
						ParticleColor(0.5, 0.5, 0.5)
					end
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
                    SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
					
					data.alteject = not data.alteject

					-- muzzleflash
					for i=0, 3 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.12, 0.17), 0.33)
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
					
				data.clipamntM249 = data.clipamntM249 - 1
				if data.clipamntM249 > 0 then
					data.coolDown = M249const.FIRERATE
				else
					PlaySound(LoadSound(M249const.RELOAD_SOUND), pt.pos)
					data.coolDown = M249const.RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = M249const.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
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
