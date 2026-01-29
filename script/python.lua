-- copy this for the most basic mag loaded weapon with slower empty reloads
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstPYTH()
    return {
		RELOAD_TIME = 2.0, -- seconds
		RELOAD_SOUND = "MOD/snd/DeagR.ogg",
		PRIM_FIRESOUND = "MOD/snd/357FR0.ogg", 
		ALT_FIRESOUND = "MOD/snd/DeagLaser.ogg",
		CLIP_SIZE = 6.0,
		PICKUP_SIZE = 6.0,
		RECOIL_AMNT = 0.25,
		FIRERATE = 0.75,
		ALTFIRERATE = 0.125,
		DAMAGE = 1,
		MAX_RANGE = 150.0,
		WPNID = "python",
		WPNNAME = "Colt Python",
		CASING_ORG = Vec(0.02, 0.25, -0.25),
	}
end

-- Per weapon data and const storers
PYTHplayers = {}
PYTHconst = createConstPYTH()

function createPlayerDataPYTH()
    return {
		clipamntPYTH = PYTHconst.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
	}
end

function server.initPYTH()
	RegisterTool(PYTHconst.WPNID, PYTHconst.WPNNAME, "MOD/prefab/glock.xml", 6)
	SetToolAmmoPickupAmount(PYTHconst.WPNID, PYTHconst.PICKUP_SIZE)
end

function server.tickPYTH(dt)
	for p in PlayersAdded() do
		PYTHplayers[p] = createPlayerDataPYTH()
		SetToolEnabled(PYTHconst.WPNID, true, p)
		SetToolAmmo(PYTHconst.WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		PYTHplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerPYTH(p, dt)
	end
end

function server.tickPlayerPYTH(p, dt)
	
	if GetPlayerTool(p) ~= PYTHconst.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(PYTHconst.WPNID, p)
	local data = PYTHplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntPYTH < PYTHconst.CLIP_SIZE then
		if data.clipamntPYTH > 0 then
			data.coolDown = PYTHconst.RELOAD_TIME
			data.altCoolDown = PYTHconst.RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPYTH = PYTHconst.CLIP_SIZE
		if data.clipamntPYTH > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPYTH = ammo
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
			
			local spread = 0.001/2 -- assuming spread is a radian value and this is the diameter of the cone

			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "bullet", PYTHconst.DAMAGE, PYTHconst.MAX_RANGE, p, PYTHconst.WPNID)

			data.recoil = PYTHconst.RECOIL_AMNT
			data.clipamntPYTH = data.clipamntPYTH - 1
			
			if data.clipamntPYTH > 0 then
				data.coolDown = PYTHconst.FIRERATE
				data.altCoolDown = PYTHconst.FIRERATE
			else
				data.coolDown = PYTHconst.RELOAD_TIME
				data.altCoolDown = PYTHconst.RELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(PYTHconst.WPNID, ammo-1, p)
			end
		end
	end
	
	if InputPressed("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.altCoolDown = PYTHconst.ALTFIRERATE
			data.coolDown = PYTHconst.ALTFIRERATE
		end
	end
	
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
end

function client.initPYTH()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(PYTHconst.WPNID, toolHaptic);
end

function client.tickPYTH(dt)
	for p in PlayersAdded() do
		PYTHplayers[p] = createPlayerDataPYTH();
	end

	for p in PlayersRemoved() do
		PYTHplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerPYTH(p, dt)
	end
end

function client.tickPlayerPYTH(p, dt)
	if GetPlayerTool(p) ~= PYTHconst.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(PYTHconst.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = PYTHplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntPYTH < PYTHconst.CLIP_SIZE then
		PlaySound(LoadSound(PYTHconst.RELOAD_SOUND), pt.pos)
		if data.clipamntPYTH > 0 then
			data.coolDown = PYTHconst.RELOAD_TIME
			data.altCoolDown = PYTHconst.RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPYTH = PYTHconst.CLIP_SIZE
		if data.clipamntPYTH > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPYTH = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then	
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				
				StopSound(data.firesound)
				data.firesound = PlaySound(LoadSound(PYTHconst.PRIM_FIRESOUND), pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(PYTHconst.CASING_ORG[1],PYTHconst.CASING_ORG[2],PYTHconst.CASING_ORG[3]))
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
					
				data.clipamntPYTH = data.clipamntPYTH - 1
				if data.clipamntPYTH > 0 then
					data.coolDown = PYTHconst.FIRERATE
					data.altCoolDown = PYTHconst.FIRERATE
				else
					PlaySound(LoadSound(PYTHconst.RELOAD_SOUND), pt.pos)
					data.coolDown = PYTHconst.RELOAD_TIME
					data.altCoolDown = PYTHconst.RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = PYTHconst.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.altCoolDown = PYTHconst.ALTFIRERATE
			data.coolDown = PYTHconst.ALTFIRERATE
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
