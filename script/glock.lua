-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/glockR.ogg"
local PRIM_FIRESOUND = "MOD/snd/glockFR.ogg"
local NONCLIENTPRIM_FIRESOUND = "MOD/snd/glockFRnc.ogg" -- glock has diff sounds when shot by NPCs (in this case, other players)
local CLIP_SIZE = 17.0
local PICKUP_SIZE = 17.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.3
local ALTFIRERATE = 0.2
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.12
local MAX_RANGE = 125.0
local WPNID = "hlglock"
local WPNNAME = "9mm HandGun"
local CASING_ORG = Vec(0.02, 0.25, 0.1)

-- Per weapon data storer
PIST9MMplayers = {}

function createPlayerDataPIST9MM()
    return {
		clipamntPIST9MM = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
	}
end

function server.initPIST9MM()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/glock.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickPIST9MM(dt)
	for p in PlayersAdded() do
		PIST9MMplayers[p] = createPlayerDataPIST9MM()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		PIST9MMplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerPIST9MM(p, dt)
	end
end

function server.tickPlayerPIST9MM(p, dt)
	if GetPlayerHealth(p) <= 0 then
		PIST9MMplayers[p] = createPlayerDataPIST9MM()
	end
end

function server.primaryFirePIST9MM(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)
	local data = PIST9MMplayers[p]

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
	local spread = 0.01/2 -- assuming spread is a radian value and this is the diameter of the cone

	dir = VecAdd(dir, rndVec(spread))
	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFirePIST9MM(p) -- separated for easy modability
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	local ammo = GetToolAmmo(WPNID, p)
	local data = PIST9MMplayers[p]

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
	local spread = 0.1/2 -- assuming spread is a radian value and this is the diameter of the cone

	dir = VecAdd(dir, rndVec(spread))
	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initPIST9MM()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
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

clipamnt = 0

function client.tickPlayerPIST9MM(p, dt)
	if GetPlayerHealth(p) <= 0 then
		PIST9MMplayers[p] = createPlayerDataPIST9MM()
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
	
	local data = PIST9MMplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntPIST9MM < CLIP_SIZE and ammo > 0.5 and data.clipamntPIST9MM ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		if data.clipamntPIST9MM > 0 then
			data.coolDown = RELOAD_TIME
			data.altCoolDown = RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPIST9MM = CLIP_SIZE
		if data.clipamntPIST9MM > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPIST9MM = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
					
				StopSound(data.firesound)
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
					ServerCall("server.primaryFirePIST9MM", p)
				else
					data.firesound = PlaySound(LoadSound(NONCLIENTPRIM_FIRESOUND), mt.pos, 300)
				end
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
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
					for i=0, 2 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.08, 0.13), 0.3)
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
					
				data.clipamntPIST9MM = data.clipamntPIST9MM - 1
				if data.clipamntPIST9MM > 0 then
					data.coolDown = FIRERATE
					data.altCoolDown = FIRERATE
				elseif ammo > 1 then
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

	if InputDown("grab", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				
				StopSound(data.firesound)
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
					ServerCall("server.secondaryFirePIST9MM", p)
				else
					data.firesound = PlaySound(LoadSound(NONCLIENTPRIM_FIRESOUND), mt.pos, 300)
				end
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
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
				
				data.clipamntPIST9MM = data.clipamntPIST9MM - 1
				if data.clipamntPIST9MM > 0 then
					data.coolDown = ALTFIRERATE
					data.altCoolDown = ALTFIRERATE
				elseif ammo > 1 then
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
	
	if IsPlayerLocal(p) then -- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntPIST9MM
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
		else
			data.clipamntM727 = 0
			clipamnt = -16
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoil > -0.5 then
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

function client.drawPIST9MM()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
end