-- copy this for the most basic scoped mag loaded weapon
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstM40()
    return {
		RELOAD_TIME = 2.32, -- seconds
		EMPTYRELOAD_TIME = 4.1 -- seconds
		RELOAD_SOUND = "MOD/snd/m40R.ogg",
		FIRESOUND = "MOD/snd/m40FR.ogg", 
		ALT_FIRESOUND = "MOD/snd/m40scp.ogg",
		CLIP_SIZE = 5.0,
		PICKUP_SIZE = 15.0,
		RECOIL_AMNT = 0.25,
		FIRERATE = 2.0,
		ALTFIRERATE = 0.5,
		SCOPEFIREDELAY = 0.1,
		DAMAGE = 0.4, -- x5
		MAX_RANGE = 200.0,
		WPNID = "m40a1",
		WPNNAME = "M40A1",
	}
end

-- Per weapon data and const storers
M40players = {}
M40const = createConstM40()

function createPlayerDataM40()
    return {
		clipamntM40 = M40const.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		scoped = false,
	}
end

function server.initM40()
	RegisterTool(M40const.WPNID, M40const.WPNNAME, "MOD/prefab/9mmar.xml", 4)
	SetToolAmmoPickupAmount(M40const.WPNID, M40const.PICKUP_SIZE)
end

function server.tickM40(dt)
	for p in PlayersAdded() do
		M40players[p] = createPlayerDataM40()
		SetToolEnabled(M40const.WPNID, true, p)
		SetToolAmmo(M40const.WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		M40players[p] = nil
	end

	for p in Players() do
		server.tickPlayerM40(p, dt)
	end
end

function server.tickPlayerM40(p, dt)
	
	if GetPlayerTool(p) ~= M40const.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(M40const.WPNID, p)
	local data = M40players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntM40 < M40const.CLIP_SIZE then
		if data.clipamntM40 > 0 then
			data.coolDown = M40const.RELOAD_TIME
			data.altCoolDown = M40const.RELOAD_TIME
		else
			data.coolDown = M40const.EMPTYRELOAD_TIME
			data.altCoolDown = M40const.EMPTYRELOAD_TIME
		end
		data.inreload = true
	end
	
	--Check if firing
	if InputPressed("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		local mt = GetToolLocationWorldTransform("muzzle", p)

		if mt == nil then
			return
		end

		if data.coolDown < 0 then	
			if data.inreload == true then
				data.inreload = false
				data.clipamntM40 = M40const.CLIP_SIZE
				if data.clipamntM40 > ammo then -- make sure the clip cannot be higher than ammo
					data.clipamntM40 = ammo
				end
			end
			
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.0005/2 -- assuming spread is a radian value and this is the diameter of the cone
			if crouch > 0.1 then
				spread = 0.00025/2
			end
			
			if not data.scoped == true then -- make fire from center of screen?
				dir = VecAdd(dir, rndVec(spread))

			for i=0, 4 do -- this should make it penetrate stuff?
				Shoot(pos, dir, "bullet", M40const.DAMAGE, M40const.MAX_RANGE, p, M40const.WPNID)
			end

			data.recoil = M40const.RECOIL_AMNT
			data.clipamntM40 = data.clipamntM40 - 1
			
			if data.clipamntM40 > 0 then
				data.coolDown = M40const.FIRERATE
				data.altCoolDown = M40const.FIRERATE
			else
				data.coolDown = M40const.RELOAD_TIME
				data.altCoolDown = M40const.RELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(M40const.WPNID, ammo-1, p)
			end
		end
	end
	
	if InputDown("grab", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.altCoolDown = M40const.ALTFIRERATE
			data.coolDown = M40const.SCOPEFIREDELAY
			data.scoped = true
		end
	else
		data.scoped = false
	end
	
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
end

function client.initM40()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(M40const.WPNID, toolHaptic);
end

function client.tickM40(dt)
	for p in PlayersAdded() do
		M40players[p] = createPlayerDataM40();
	end

	for p in PlayersRemoved() do
		M40players[p] = nil
	end

	for p in Players() do
		client.tickPlayerM40(p, dt)
	end
end

CASING_ORG = Vec(0.02, 0.25, -0.25)		-- casing origin

function client.tickPlayerM40(p, dt)
	if GetPlayerTool(p) ~= M40const.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(M40const.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = M40players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntM40 < M40const.CLIP_SIZE then
		PlaySound(LoadSound(M40const.RELOAD_SOUND), pt.pos)
		if data.clipamntM40 > 0 then
			data.coolDown = M40const.RELOAD_TIME
			data.altCoolDown = M40const.RELOAD_TIME
		else
			data.coolDown = M40const.EMPTYRELOAD_TIME
			data.altCoolDown = M40const.EMPTYRELOAD_TIME
		end
		data.inreload = true
	end
	
	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then
				if data.inreload == true then
					data.inreload = false
					data.clipamntM40 = M40const.CLIP_SIZE
					if data.clipamntM40 > ammo then -- make sure the clip cannot be higher than ammo
						data.clipamntM40 = ammo
					end
				end
				
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				PlaySound(LoadSound(FIRESOUND), pt.pos)
				
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
					
				data.clipamntM40 = data.clipamntM40 - 1
				if data.clipamntM40 > 0 then
					data.coolDown = M40const.FIRERATE
					data.altCoolDown = M40const.FIRERATE
				else
					PlaySound(LoadSound(M40const.RELOAD_SOUND), pt.pos)
					data.coolDown = M40const.RELOAD_TIME
					data.altCoolDown = M40const.RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = M40const.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputDown("grab", p) and ammo > 0 and GetPlayerVehicle(p) == 0  and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight -- make forced
				
			data.altCoolDown = M40const.ALTFIRERATE
			data.coolDown = M40const.SCOPEFIREDELAY
			data.scoped = true
		end
	else
		data.scoped = false
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
