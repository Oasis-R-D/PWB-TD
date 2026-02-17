-- copy this for the most basic mag loaded weapon (INCLUDES PUSHBACK ON FIRE)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PICKUP_SIZE = 20
local RECOIL_AMNT = 0.05 -- more of a rumble
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.15
local MAX_RANGE = 208
local WPNID = "hlgluon"
local WPNNAME = "Gluon Gun"

local EGON_PULSE_INTERVAL 0.1
local EGON_DISCHARGE_INTERVAL 0.1

local EGON_START 1
local EGON_ON 2
local EGON_STOP 3

-- Per weapon data storer
GLUplayers = {}


-- BEGIN BUILT IN LASER VFX
local hitPos = VecAdd(startPoint, VecScale(dir, dist))

--Draw laser line in ten segments with random offset -- NOTE: gluon gun actually does have something like this where the further you fire, the more the beam wanders
local last = mt -- muzzle
for i=1, 20 do
	local tt = i/20 -- tf is a tt?
	local p = VecLerp(mt, hitPos, tt)
	p = VecAdd(p, rndVec(0.2*tt))
	DrawLine(last, p, 1, 0.5, 0.7)
	last = p
end 
-- END BUILT IN LASER VFX

function createPlayerDataGLU()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		soundState = 0.0, -- Instead of having different timers for the 3 diff sounds, use another var to tell it which sound is sounding through sound emitting devices connected to the device using a sound cable and/or bluetooth
		soundTime = nil,
		serverState = 0.0, -- used in player tick to see if it's firing, starting or stopping (0 for none)
		clientState = 0.0, -- used in player tick to see if it's firing, starting or stopping (0 for none)
		ammoDepleteTime = nil,
	}
end

function server.initGLU()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/gluon.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickGLU(dt)
	for p in PlayersAdded() do
		GLUplayers[p] = createPlayerDataGLU()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		GLUplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerGLU(p, dt)
	end
end

function server.tickPlayerGLU(p, dt)
	if GetPlayerHealth(p) <= 0 then
		GLUplayers[p] = createPlayerDataGLU()
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	local data = GLUplayers[p]

	if data.ammoDepleteTime ~= nil then 
		data.ammoDepleteTime = data.ammoDepleteTime - dt
		if data.ammoDepleteTime <= 0 then
			SetToolAmmo(WPNID, ammo-1, p)
		end
	end
end
 
function server.startGLU(p)
	local data = GLUplayers[p]

	data.ammoDepleteTime = 0
	data.serverState = EGON_START
end

function server.stopGLU(p)
	local data = GLUplayers[p]

	data.ammoDepleteTime = nil
	data.serverState = EGON_STOP
end

function client.initGLU()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickGLU(dt)
	for p in PlayersAdded() do
		GLUplayers[p] = createPlayerDataGLU();
	end

	for p in PlayersRemoved() do
		GLUplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerGLU(p, dt)
	end
end

clipamnt = 0

function client.tickPlayerGLU(p, dt)
	if GetPlayerHealth(p) <= 0 then
		GLUplayers[p] = createPlayerDataGLU()
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
	
	local data = GLUplayers[p]

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then
				if IsPlayerLocal(p) then
					PointLight(mt.pos, 0.1, 0.1, 0.5, 3) -- add sin wave to the B channel to make it flicker (make it local for less lag?)
				else
					PointLight(mt.pos, 0.1, 0.1, 0.5, 3)
				end

				if IsPlayerLocal(p) then
					ServerCall("server.startGLU", p)
				end

				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)

					-- muzzleflash
					for i=0, 3 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.12, 0.17), 0.33)
						ParticleAlpha(1, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5, 1)
						ParticleCollide(0)
						ParticleColor(0,0,1, 0.5,0,0.5)
						SpawnParticle(mt.pos, playervel, 0.125)
					end
				
				end
					
				data.coolDown = 0.2 -- placeholder
				
				data.recoil = RECOIL_AMNT -- rumble the gun
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
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