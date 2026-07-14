-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/displacer_fire.ogg"
local ALT_FIRESOUND = "MOD/snd/displacer_teleport_player.ogg"
local ALTALT_FIRESOUND = "MOD/snd/displacer_self.ogg"
local FAILSOUND = "MOD/snd/displacer_fail.ogg"
local AFTERSHOCKSFX = "MOD/snd/tauElect0.ogg"
local PICKUP_SIZE = 1.0
local RECOIL_AMNT = 0.3
local FIRERATE = 2.5
local PLAYERDAMAGE = 1.0
local MAX_RANGE = 208.0
local WPNID = "opfordisplacer"
local WPNNAME = "Displacer Cannon"

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		coolDown = 0.0,
		inAltAttack = false,
		inAttack = false,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		chargedTime = nil,
		angle = 0.0,
		angVel = 0.0,
		body = nil,
		barrel = nil,
		barrelTransform = nil,
		dataReset = true,
	}
end

function server.initDISP()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/displacer.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickDISP(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in Players() do
		server.tickPlayerDISP(p, dt)
	end
end

function server.tickPlayerDISP(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then return end

	local ammo = GetToolAmmo(WPNID, p)
	if ammo < 9999 and ammo > 6 then
		SetToolAmmo(WPNID, 6, p)
	end
end

function getFullChargeTime()
	if isMP() then return 1.5 else return 4 end
end

function server.primaryFireDISP(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, MAX_RANGE, p)
	
	pos = VecAdd(pos, VecScale(angThrow, 0.5))

	local velocity = TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -12.7))

	local GrenTrans = Transform(pos, QuatLookAt(Vec(), angThrow))
	local xml = "MOD/prefab/disp_proj.xml"
	local dispBall_ent = Spawn(xml, GrenTrans)

	SetTag(dispBall_ent[2], "playerThrew", p)

	SetBodyVelocity(dispBall_ent[2], velocity)
	
	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 200)

	server.depleteAmmo(p, WPNID)
end

function client.drawlaserDISP(vecSrc, vecDir, raycastDist)
	local t = Transform(VecLerp(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 0.5))

	local xAxis = VecNormalize(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecSrc))
	local zAxis = VecNormalize(VecSub(vecSrc, GetCameraTransform().pos))

	t.rot = QuatAlignXZ(xAxis, zAxis)

	DrawSprite(LoadSprite("MOD/gfx/egonBeam.png"), t, raycastDist, 0.33, 0.36, 0.5, 0.063, 1.0, true, true)
end

function client.UpdateEffectDISP(source, endpos, vecDir, dist)
	--Draw laser line in ten segments with random offset -- NOTE: gluon gun actually does have something like this where the further you fire, the more the beam wanders
	if IsPlayerLocal(GetLocalPlayer()) then
		PointLight(source, 0.36, 0.5, 0.063, 5)
		local t = Transform(source)
		t.rot = GetPlayerCameraTransform().rot

		DrawSprite(LoadSprite("MOD/gfx/portal.png"), t, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0, true, true)

		local last = source
		for i=1, 20 do
			local tt = i/20 -- tf is a tt?
			local p = VecLerp(last, endpos, tt)
			p = VecAdd(p, rndVec(tt))
			DrawLine(last, p, 0.72, 1.0, 0.126)

			local length = VecLength(VecSub(last, p))
			client.drawlaserDISP(last, vecDir, length)

			ParticleReset()
			ParticleGravity(0)
			ParticleRadius(rnd(0.15, 0.2), 0.35)
			ParticleAlpha(1, 0)
			ParticleTile(1)
			ParticleDrag(0)
			ParticleRotation(rnd(10, -10), 0)
			ParticleSticky(0)
			ParticleEmissive(5, 1)
			ParticleCollide(0)
			ParticleColor(0.36, 0.5, 0.063)
			SpawnParticle(last, Vec(), 0.125)

			last = p
		end
	end
end

function server.secondaryFireDISP(p) -- separated for easy modability
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0.1, p)

	local spawns = FindLocations("playerspawn", true)
	if spawns == nil or #spawns == 0 then
		PlaySound(LoadSound(FAILSOUND), mt.pos, 1)
		return
	end

	local chosenSpawn = math.random(1, #spawns)
	if spawns[chosenSpawn] ~= nil then
		-- Fire a ball downwards for funny
		local velocity = TransformToParentVec(GetPlayerEyeTransform(p), GetGravity())

		local GrenTrans = Transform(pos, QuatLookAt(Vec(), VecNormalize(velocity)))
		local xml = "MOD/prefab/disp_proj.xml"
		local dispBall_ent = Spawn(xml, GrenTrans)

		SetTag(dispBall_ent[2], "playerThrew", p)

		SetBodyVelocity(dispBall_ent[2], velocity)

		-- Teleport the Player
		local playerVel = GetPlayerVelocity(p)

		local trans = GetLocationTransform(spawns[chosenSpawn])

		SetPlayerTransform(trans, p)
		SetPlayerVelocity(playerVel, p)

		PlaySound(LoadSound(ALTALT_FIRESOUND), trans.pos, 50)

		-- Cool VFX
		local lghtngPos = VecAdd(trans.pos, GetPlayerUp(p))
		for i=0, 6 do
			local vecDir = GetRandomDirection()
			QueryRejectBody(grenBody)
			local hit, dist = QueryRaycast(lghtngPos, vecDir, 30)
			if hit then
				local endpos = VecAdd(lghtngPos, VecScale(vecDir, dist))
				ClientCall(0, "client.UpdateEffectDISP", lghtngPos, endpos, vecDir, dist)
			end
		end
	end
	
	server.depleteAmmo(p, WPNID, 3)
end

function client.initDISP()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	spinLoop = LoadLoop("MOD/snd/displacer_spin.ogg")
	spinLoopAlt = LoadLoop("MOD/snd/displacer_spin2.ogg")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickDISP(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerDISP(p, dt)
	end
end

function client.tickPlayerDISP(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		-- punish players who try cheating
		if playerData[p].inAttack == true then
			if playerData[p].inAltAttack == true then
				playerData[p].inAltAttack = false
				if IsPlayerLocal(p) then
					ServerCall("server.depleteAmmo", p, WPNID)
				end
			else
				if IsPlayerLocal(p) then
					ServerCall("server.depleteAmmo", p, WPNID, 3)
				end
			end

			playerData[p].chargedTime = nil
			playerData[p].inAttack = false
		end

		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", p)
	if mt == nil then
		return
	end

	local ammo = GetToolAmmo(WPNID, p)

	local data = playerData[p]
	
	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Check Fire
	if InputPressed("usetool", p) and canFire(p, ammo, ammo, data.coolDown) and data.inAttack ~= true then
		data.inAttack = true
		data.coolDown = FIRERATE
	-- Check Altfire
	elseif InputPressed("grab", p) and GetPlayerCanUseTool(p) == true and data.inAttack ~= true then
		if data.coolDown < 0 then
			data.coolDown = FIRERATE
			data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
			local spawns = FindLocations("playerspawn", true)
			if spawns == nil or #spawns == 0 or ammo < 3 then
				PlaySound(LoadSound(FAILSOUND), mt.pos, 1)
			else
				data.inAttack = true
				data.inAltAttack = true
			end
		end
	end

	if data.chargedTime ~= nil and data.inAttack == true then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- increase timer for use in damage calc
		PointLight(mt.pos, 0.36, 0.5, 0.063, data.chargedTime*2)
		local pitch = (data.chargedTime) * (150 / getFullChargeTime()) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100

		data.angVel = math.min(1000, data.angVel + (pitch * 30))
		data.recoil = math.min(0.1, data.recoil + (pitch * 0.5))

		if data.inAltAttack == true then
			PlayLoop(spinLoopAlt, mt.pos, 1, true)
		else
			PlayLoop(spinLoop, mt.pos, 1, true)
		end

		local playervel = GetPlayerVelocity(p)
		-- muzzleflash
		ParticleReset()
		ParticleGravity(0)
		ParticleRadius(0.1 + (data.chargedTime / 2))
		ParticleAlpha(1, 0)
		ParticleTile(1)
		ParticleDrag(0)
		ParticleRotation(rnd(10, -10), 0)
		ParticleSticky(0)
		ParticleEmissive(5, 1)
		ParticleCollide(0)
		ParticleColor(0.36, 0.5, 0.063)
		SpawnParticle(mt.pos, playervel, 0.125)

		if data.chargedTime > 1 then
			SetSoundLoopProgress(spinLoop, 0.0)
			SetSoundLoopProgress(spinLoopAlt, 0.0)

			PointLight(mt.pos, 0.36, 0.5, 0.063, 5)

			data.toolAnimator.forceActionPose = false

			if IsPlayerLocal(p) then
				client.SRC_PunchAxis(1, 2)
				if data.inAltAttack == true then
					PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 20)
					ServerCall("server.secondaryFireDISP", p)

					PlayHaptic(shootHaptic, 1)
				else
					ServerCall("server.primaryFireDISP", p)

					PlayHaptic(shootHaptic, 1)
				end
			end

			data.recoil = RECOIL_AMNT
			data.chargedTime = nil
			data.inAltAttack = false
			data.inAttack = false
		end
	elseif data.inAttack == true then -- start timer
		SetSoundLoopProgress(spinLoop, 0.0)
		SetSoundLoopProgress(spinLoopAlt, 0.0)
		data.chargedTime = 0
		data.toolAnimator.forceActionPose = true
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt
	data.angle = data.angle + data.angVel*dt
	data.angVel = math.max(0, data.angVel - dt*1000)

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

	--Animate barrel around the attachment point
	local b = GetToolBody(p)
	local voxSize = 0.0333
	local attach = Transform(Vec(0, 6.66*voxSize, 6.66*voxSize))
	
	if data.body ~= b then
		data.body = b
		-- Barrel is the second shape in vox file. Remember original position in attachment frame
		local shapes = GetBodyShapes(b)
		data.barrel = shapes[2]
		data.barrelTransform = TransformToLocalTransform(attach, GetShapeLocalTransform(data.barrel))
	end
	if data.barrel then
		attach.rot = QuatEuler(0, 0, -data.angle) -- negative to make it spin the right way
		t = TransformToParentTransform(attach, data.barrelTransform)
		SetShapeLocalTransform(data.barrel, t)
	end
end