#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PICKUP_SIZE = 20
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.14
local WPNID = "hlgluon"
local WPNNAME = "Gluon Gun"
local FIRERATE = 0.5

local EGON_PULSE_INTERVAL = 0.1
local EGON_DISCHARGE_INTERVAL = 0.1

local EGON_FIREOFF = 0.0
local EGON_FIRECHARGE = 1.0

-- Per weapon data storer
GLUplayers = {}

-- BEGIN BUILT IN LASER VFX
--[[
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
]]

function createPlayerDataGLU()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		soundState = 0.0, -- Instead of having different timers for the 3 diff sounds, use another var to tell it which sound is sounding through sound emitting devices connected to the device using a sound cable and/or bluetooth
		soundTime = nil,
		fireState = EGON_FIREOFF, -- used in player tick to see if it's firing or off (0 for none)
		ammoDepleteTime = nil,
		shakeTime = 0.0,
		shakeDur = 0.0,
		damageTime = 0.0,
		checkOff = 0.0,
		currentSnd = nil,
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
end

function client.drawlaserGLU(vecSrc, vecDir, raycastDist, p)
	local t = Transform(VecLerp(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 0.5))

	local xAxis = VecNormalize(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecSrc))
	local zAxis = VecNormalize(VecSub(vecSrc, GetCameraTransform(p).pos))

	t.rot = QuatAlignXZ(xAxis, zAxis)

	DrawSprite(LoadSprite("MOD/gfx/egonBeam.png"), t, raycastDist, 0.33, 1.0, 1.0, 1.0, 1.0, true, true)
end

function client.UpdateEffectGlu(source, endpos, vecDir, dist, timedist, player)
	--Draw laser line in ten segments with random offset -- NOTE: gluon gun actually does have something like this where the further you fire, the more the beam wanders
	local last = source
	for i=1, 20 do
		local tt = i/20 -- tf is a tt?
		local p = VecLerp(last, endpos, tt)
		p = VecAdd(p, rndVec(0.2*tt))
		--DrawLine(last, p, 0.5, 0.5, 1.0)

		local length = VecLength(VecSub(last, p))
		client.drawlaserGLU(last, vecDir, length, player) -- to-do: figure out how to get direction from 2 vectors

		local playervel = GetPlayerVelocity(player)
		ParticleReset()
		ParticleGravity(0)
		ParticleRadius(rnd(0.15, 0.2), 0.35)
		ParticleAlpha(1, 0)
		ParticleTile(5)
		ParticleDrag(0)
		ParticleRotation(rnd(10, -10), 0)
		ParticleSticky(0)
		ParticleEmissive(5, 1)
		ParticleCollide(0)
		ParticleColor(0,0,1, 0.5,0,0.5)
		SpawnParticle(last, playervel, 0.125)

		last = p
	end
end

function server.fireGLU(p, dmgTime, dt)
	local eyeTrans = GetPlayerEyeTransform(p)
	local front = TransformToParentVec(eyeTrans, Vec(0, 0, -1))
	local vecDir = VecNormalize(front)
	local vecOrigSrc = GetPlayerEyeTransform(p).pos
	local tmpSrc = GetToolLocationWorldTransform("muzzle", p)

	local data = GLUplayers[p]

	local bHit, iDist, pShape, pPlayerHit = QueryShot(vecOrigSrc, vecDir, 100, 0, p)

	local timedist = (data.damageTime / EGON_DISCHARGE_INTERVAL)

	if timedist < 0 then
		timedist = 0
	elseif timedist > 1 then
		timedist = 1
	end
	timedist = 1 - timedist

	local beamstart = VecAdd(tmpSrc.pos, VecScale(GetPlayerVelocity(player), dt))
	ClientCall(0, "client.UpdateEffectGlu", beamstart, VecAdd(vecOrigSrc, VecScale(vecDir, iDist)), vecDir, iDist, timedist, p, dt)

	if not bHit then
		return
	end

	if dmgTime <= 0 then
		if pPlayerHit ~= 0 then
			ApplyPlayerDamage(pPlayerHit, PLAYERDAMAGE, WPNNAME, p)
			BloodVFX(VecAdd(vecOrigSrc, VecScale(vecDir, iDist)), vecDir, PLAYERDAMAGE, pPlayerHit)
		end

		if pShape ~= 0 then
			ApplyBodyImpulse(GetShapeBody(pShape), VecAdd(vecOrigSrc, VecScale(vecDir, iDist)), VecScale(vecDir, 10000.0))
			local origin = VecAdd(vecOrigSrc, VecScale(vecDir, iDist))
			MakeHole(origin, 1.0, 0.75, 0.5)	
			server.SpawnFireHook(origin, 80)
			Paint(origin, 1.125, "explosion", 0.6)
		end

		if isMP() == true then
			local placeholder = 0 -- radius damage here
		end
	end
end

function client.initGLU()
	startSND = LoadLoop("MOD/snd/egon_start.ogg") -- use a loop so it tracks with the weapon
	loopSND = LoadLoop("MOD/snd/egon_loop.ogg")
	stopSND = LoadSound("MOD/snd/egon_stop.ogg")
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickGLU(dt)
	for p in PlayersAdded() do
		GLUplayers[p] = createPlayerDataGLU()
	end

	for p in PlayersRemoved() do
		GLUplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerGLU(p, dt)
	end
end

function client.tickPlayerGLU(p, dt)
	if GetPlayerHealth(p) <= 0 then
		GLUplayers[p] = createPlayerDataGLU()
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", p)
	if mt == nil then
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	local data = GLUplayers[p]

	if InputDown("usetool", p) and GetPlayerCanUseTool(p) == true and ammo > 0 then
		if data.coolDown < 0 then
			if data.fireState == EGON_FIREOFF then
				data.ammoDepleteTime = 0

				data.currentSnd = PlayLoop(startSND, mt.pos, 100)
				data.soundState = 1
				data.soundTime = 3

				data.shakeTime = 0

				data.checkOff = 0.1

				data.damageTime = EGON_PULSE_INTERVAL
				data.fireState = EGON_FIRECHARGE
			elseif data.fireState == EGON_FIRECHARGE then
				if IsPlayerLocal(p) then -- would it be better to do the host here so it doesn't need networked?
					ServerCall("server.fireGLU", p, data.damageTime, dt)
				end

				if data.damageTime <= 0 then
					data.damageTime = EGON_DISCHARGE_INTERVAL
				end

				if (data.soundState == 1 and data.soundTime <= 0.0) or data.soundState == 2 then
					data.soundState = 2
					data.currentSnd = PlayLoop(loopSND, mt.pos, 100)
				elseif data.soundState == 1 and data.soundTime > 0.0 then
					data.currentSnd = PlayLoop(startSND, mt.pos, 100)
				end

				if IsPlayerLocal(p) then
					PointLight(mt.pos, 0.1, 0.1, 0.5, math.abs((math.sin(GetTime() + rnd(1, 6)) * 3)) + 3) -- add sin wave to the B channel to make it flicker (make it local for less lag?)
				else
					PointLight(mt.pos, 0.1, 0.1, 0.5, 3)
				end

				if ammo <= 0 then
					data.coolDown = 1
				end
			end

			if data.ammoDepleteTime ~= nil then
				data.ammoDepleteTime = data.ammoDepleteTime - dt
				if data.ammoDepleteTime <= 0 then
					if IsPlayerLocal(p) then
						ServerCall("server.depleteAmmo", p, WPNID)
					end

					if isMP() == true then
						data.ammoDepleteTime = 0.2
					else
						data.ammoDepleteTime = 0.1
					end
				end
			end

			data.shakeTime = data.shakeTime - dt

			if IsPlayerLocal(p) then
				ShakeCamera(rnd(0.2, 0.3))
			end

			data.recoil = math.abs((math.sin(GetTime() + rnd(0.1, 0.2)) * 0.0625)) + 0.0625

			if data.shakeTime < 0 then
				if IsPlayerLocal(p) then
					ShakeCamera(rnd(0.35, 0.45))
				end

				data.recoil = data.recoil + 0.0625

				data.shakeDur = data.shakeDur + dt
				if data.shakeDur >= 0.75 then
					data.shakeTime = 1.5
					data.shakeDur = 0
				end
			end

			local toolBody = GetToolBody(p)
			if toolBody ~= 0 then
				local playervel = GetPlayerVelocity(p)

				-- muzzleflash
				ParticleReset()
				ParticleGravity(0)
				ParticleRadius(rnd(0.15, 0.2), 0.35)
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

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	elseif data.fireState ~= EGON_FIREOFF then
		data.checkOff = data.checkOff - dt
		if data.checkOff <= 0 then
			data.coolDown = FIRERATE
			SetSoundLoopProgress(loopSND, 0.0)
			SetSoundLoopProgress(startSND, 0.0)
			PlaySound(stopSND, mt.pos, 100)
			StopSound(data.currentSnd)
			data.soundTime = nil
			data.soundState = 0

			data.fireState = EGON_FIREOFF
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt
	data.damageTime = data.damageTime - dt
	
	if data.soundTime ~= nil then
		data.soundTime = data.soundTime - dt
	end

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