-- copy this for the most basic mag loaded weapon with slower empty reloads
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
function createConstPIST9MM()
    return {
		RELOAD_TIME = 1.5, -- seconds
		RELOAD_SOUND = "MOD/snd/glockR.ogg",
		PRIM_FIRESOUND = "MOD/snd/glockFR.ogg", 
		CLIP_SIZE = 17.0,
		PICKUP_SIZE = 34.0, -- should be 17 but idc
		RECOIL_AMNT = 0.17,
		FIRERATE = 0.3,
		ALTFIRERATE = 0.2,
		DAMAGE = 0.4,
		MAX_RANGE = 125.0,
		WPNID = "aaabbbbbb", -- TO-DO: see if this is how weapons are sorted in the inventory (to force the game to have our weapons first)
		WPNNAME = "9mm HandGun",
		CASING_ORG = Vec(0.02, 0.25, -0.25)
	}
end

-- Per weapon data and const storers
PIST9MMplayers = {}
PIST9MMconst = createConstPIST9MM()

function createPlayerDataPIST9MM()
    return {
		clipamntPIST9MM = PIST9MMconst.CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
	}
end

function server.initPIST9MM()
	RegisterTool(PIST9MMconst.WPNID, PIST9MMconst.WPNNAME, "MOD/prefab/deagle.xml", 2)
	SetToolAmmoPickupAmount(PIST9MMconst.WPNID, PIST9MMconst.PICKUP_SIZE)
end

function server.tickPIST9MM(dt)
	for p in PlayersAdded() do
		PIST9MMplayers[p] = createPlayerDataPIST9MM()
		SetToolEnabled(PIST9MMconst.WPNID, true, p)
		SetToolAmmo(PIST9MMconst.WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		PIST9MMplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerPIST9MM(p, dt)
	end
end

function server.tickPlayerPIST9MM(p, dt)
	
	if GetPlayerTool(p) ~= PIST9MMconst.WPNID then
		return
	end
	
	local ammo = GetToolAmmo(PIST9MMconst.WPNID, p)
	local data = PIST9MMplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntPIST9MM < PIST9MMconst.CLIP_SIZE then
		if data.clipamntPIST9MM > 0 then
			data.coolDown = PIST9MMconst.RELOAD_TIME
			data.altCoolDown = PIST9MMconst.RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPIST9MM = PIST9MMconst.CLIP_SIZE
		if data.clipamntPIST9MM > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPIST9MM = ammo
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
			
			local spread = 0.01/2 -- assuming spread is a radian value and this is the diameter of the cone

			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "bullet", PIST9MMconst.DAMAGE, PIST9MMconst.MAX_RANGE, p, PIST9MMconst.WPNID)

			data.recoil = PIST9MMconst.RECOIL_AMNT
			data.clipamntPIST9MM = data.clipamntPIST9MM - 1
			
			if data.clipamntPIST9MM > 0 then
				data.coolDown = PIST9MMconst.FIRERATE
				data.altCoolDown = PIST9MMconst.FIRERATE
			else
				data.coolDown = PIST9MMconst.RELOAD_TIME
				data.altCoolDown = PIST9MMconst.RELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(PIST9MMconst.WPNID, ammo-1, p)
			end
		end
	end
	
	if InputPressed("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
			local crouch = GetPlayerCrouch(p)
			
			local spread = 0.1/2 -- assuming spread is a radian value and this is the diameter of the cone

			dir = VecAdd(dir, rndVec(spread))
			Shoot(pos, dir, "bullet", PIST9MMconst.DAMAGE, PIST9MMconst.MAX_RANGE, p, PIST9MMconst.WPNID)

			data.recoil = PIST9MMconst.RECOIL_AMNT
			data.clipamntPIST9MM = data.clipamntPIST9MM - 1
			
			if data.clipamntPIST9MM > 0 then
				data.coolDown = PIST9MMconst.ALTFIRERATE
				data.altCoolDown = PIST9MMconst.ALTFIRERATE
			else
				data.coolDown = PIST9MMconst.RELOAD_TIME
				data.altCoolDown = PIST9MMconst.RELOAD_TIME
				data.inreload =  true;
			end
			
			
			if ammo < 9999 then
				SetToolAmmo(PIST9MMconst.WPNID, ammo-1, p)
			end
		end
	end
	
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
end

function client.initPIST9MM()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(PIST9MMconst.WPNID, toolHaptic);
end

function client.tickPIST9MM(dt)
	for p in PlayersAdded() do
		PIST9MMplayers[p] = createPlayerDataPIST9MM();
	end

	for p in PlayersRemoved() do
		PIST9MMplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerPIST9MM(p, dt)
	end
end

function client.tickPlayerPIST9MM(p, dt)
	if GetPlayerTool(p) ~= PIST9MMconst.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(PIST9MMconst.WPNID, p)

	if mt == nil then
		return
	end

	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	local data = PIST9MMplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntPIST9MM < PIST9MMconst.CLIP_SIZE then
		PlaySound(LoadSound(PIST9MMconst.RELOAD_SOUND), pt.pos)
		if data.clipamntPIST9MM > 0 then
			data.coolDown = PIST9MMconst.RELOAD_TIME
			data.altCoolDown = PIST9MMconst.RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPIST9MM = PIST9MMconst.CLIP_SIZE
		if data.clipamntPIST9MM > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPIST9MM = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0 and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
			if data.coolDown < 0 then	
				--Light, particles and sound
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				PlaySound(LoadSound(PRIM_FIRESOUND), pt.pos)
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(PIST9MMconst.CASING_ORG[1],PIST9MMconst.CASING_ORG[2],PIST9MMconst.CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, 0.2, 0))
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
					
				data.clipamntPIST9MM = data.clipamntPIST9MM - 1
				if data.clipamntPIST9MM > 0 then
					data.coolDown = PIST9MMconst.FIRERATE
					data.altCoolDown = PIST9MMconst.FIRERATE
				else
					PlaySound(LoadSound(PIST9MMconst.RELOAD_SOUND), pt.pos)
					data.coolDown = PIST9MMconst.RELOAD_TIME
					data.altCoolDown = PIST9MMconst.RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = PIST9MMconst.RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape() == 0 then
		if data.altCoolDown < 0 then
			data.altCoolDown = PIST9MMconst.ALTFIRERATE
			data.coolDown = PIST9MMconst.ALTFIRERATE
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
