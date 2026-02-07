-- copy this for the most basic mag loaded weapon with alt fire
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/hkr.ogg"
local ALT_FIRESOUND = "MOD/snd/hkgl.ogg"
local PRIM_FIRESOUND = "MOD/snd/hks0.ogg"
local CLIP_SIZE = 50
local PICKUP_SIZE = 50
local RECOIL_AMNT = 0.2
local FIRERATE = 0.1
local ALTFIRERATE = 1
local DAMAGE = 0.45
local PLAYERDAMAGE = 0.12
local MAX_RANGE = 100.0
local WPNID = "hl9mmar"
local WPNNAME = "9mmAR"
local CASING_ORG = Vec(0.02, 0.25, -0.25)	-- casing origin

-- Per weapon data and const storers
MP5players = {}

function createPlayerDataMP5()
    return {
		clipamntMP5 = CLIP_SIZE,
		m203amntMP5 = 1,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
	}
end

function server.initMp5()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/9mmar.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickMp5(dt)
	for p in PlayersAdded() do
		MP5players[p] = createPlayerDataMP5()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		MP5players[p] = nil
	end

	for p in Players() do
		server.tickPlayerMp5(p, dt)
	end
end

function server.tickPlayerMp5(p, dt)
	if GetPlayerHealth(p) <= 0 then
		MP5players[p] = createPlayerDataMP5()
		return
	end
end

function server.primaryFireMp5(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)
	local data = MP5players[p]

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
	local crouch = GetPlayerCrouch(p)
	
	local spread = 0.05234/2 -- assuming spread is a radian value and this is the diameter of the cone
	if crouch > 0.1 then
		spread = 0.03490/2
	end
	
	dir = VecAdd(dir, rndVec(spread))
	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireMp5(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, 100, p)
	local crouch = GetPlayerCrouch(p)
	
	local spread = 0.05234/8 -- assuming spread is a radian value and this is the diameter of the cone
	if crouch > 0.1 then
		spread = 0.03490/8
	end
	
	dir = VecAdd(dir, rndVec(spread))
	Shoot(pos, dir, "rocket", DAMAGE, MAX_RANGE * 2, p, WPNID)
	
	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)
end

function client.initMp5()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
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

clipamnt = 0
altclipamnt = 0

function client.tickPlayerMp5(p, dt)
	if GetPlayerHealth(p) <= 0 then
		MP5players[p] = createPlayerDataMP5()
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end

	local data = MP5players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntMP5 < CLIP_SIZE and ammo > 0.5 and data.clipamntMP5 ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		data.coolDown = RELOAD_TIME
		data.altCoolDown = RELOAD_TIME
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.m203amntMP5 = 1
		data.clipamntMP5 = CLIP_SIZE
		if data.clipamntMP5 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntMP5 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireMp5", p)
				end

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
					
				data.clipamntMP5 = data.clipamntMP5 - 1
				if data.clipamntMP5 > 0 then
					data.coolDown = FIRERATE
					data.altCoolDown = FIRERATE
				elseif ammo > 0.5 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					data.coolDown = RELOAD_TIME
					data.altCoolDown = RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and data.m203amntMP5 > 0.5 and GetPlayerCanUseTool(p) == true  then
			if data.altCoolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.secondaryFireMp5", p)
				end
				
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
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5, 1)
						ParticleCollide(0)
						ParticleColor(1,0.35,0, 1,0,0)
						SpawnParticle(vectuh, playervel, 0.125)
					end
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
				
				data.recoil = 1.5 * RECOIL_AMNT
				
				data.altCoolDown = ALTFIRERATE
				data.coolDown = ALTFIRERATE
				data.m203amntMP5 = data.m203amntMP5 - 1
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if IsPlayerLocal(p) then -- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntMP5
			altclipamnt = data.m203amntMP5
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
			altclipamnt = -8
		else
			data.clipamntMP5 = 0
			clipamnt = -16
			altclipamnt = data.m203amntMP5
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

function client.drawMp5()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
	client.drawSecAmmo(altclipamnt)
end