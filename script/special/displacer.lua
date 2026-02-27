-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/displacer_fire.ogg"
local ALT_FIRESOUND = "MOD/snd/displacer_self.ogg"
local AFTERSHOCKSFX = "MOD/snd/tauElect0.ogg"
local PICKUP_SIZE = 10.0
local RECOIL_AMNT = 0.3
local FIRERATE = 2.5
local CAMMOVETIME = (2 * math.pi) * (0.5 / (FIRERATE-1)) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local PLAYERDAMAGE = 1.0
local MAX_RANGE = 208.0
local WPNID = "opfordisplacer"
local WPNNAME = "Displacer Cannon"

-- Per weapon data storer
DISPplayers = {}

function createPlayerDataDISP()
    return {
		coolDown = 0.0,
		altCoolDown = 0.0,
		inAltAttack = false,
		inAttack = false,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		aftershocksfx = nil,
		chargedTime = nil,
		angle = 0.0,
		angVel = 0.0,
		body = nil,
		barrel = nil,
		barrelTransform = nil,
		camAltMove = false,
	}
end

function server.initDISP()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/displacer.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickDISP(dt)
	for p in PlayersAdded() do
		DISPplayers[p] = createPlayerDataDISP()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		DISPplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerDISP(p, dt)
	end
end

function server.tickPlayerDISP(p, dt)
	if GetPlayerHealth(p) <= 0 then
		DISPplayers[p] = createPlayerDataDISP()
	end
end

function getFullChargeTime()
	if isMP() then
		return 1.5
	end
	return 4
end

function server.primaryFireDISP(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)
	local data = DISPplayers[p]

	local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, MAX_RANGE, p)
	
	pos = VecAdd(pos, VecScale(angThrow, 0.5))

	local velocity = TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -12.7))

	local GrenTrans = Transform(pos, QuatLookAt(Vec(), angThrow))
	local xml = "MOD/prefab/disp_proj.xml"
	dispBall_ent = Spawn(xml, GrenTrans)

	SetTag(dispBall_ent[2], "playerThrew", p)

	SetBodyVelocity(dispBall_ent[2], velocity)
	
	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 200)

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireDISP(p) -- separated for easy modability
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	local ammo = GetToolAmmo(WPNID, p)
	local data = DISPplayers[p]

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0.1, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 100)

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initDISP()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	spinLoop = LoadLoop("MOD/snd/displacer_spin.ogg")
	spinLoopAlt = LoadLoop("MOD/snd/displacer_spin2.ogg")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickDISP(dt)
	for p in PlayersAdded() do
		DISPplayers[p] = createPlayerDataDISP();
	end

	for p in PlayersRemoved() do
		DISPplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerDISP(p, dt)
	end
end

function client.tickPlayerDISP(p, dt)
	if GetPlayerHealth(p) <= 0 then
		DISPplayers[p] = createPlayerDataDISP()
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		camSineTime = nil
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = DISPplayers[p]

	if InputPressed("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true and data.inAttack ~= true then
		if data.coolDown < 0 then	
			data.inAttack = true
			data.altCoolDown = FIRERATE
			data.coolDown = FIRERATE
		end
	end

	if InputPressed("grab", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true and data.inAttack ~= true then
		if data.altCoolDown < 0 then
			data.inAttack = true
			data.inAltAttack = true
			data.altCoolDown = FIRERATE
			data.coolDown = FIRERATE
		end
	end

	if data.chargedTime ~= nil and data.inAttack == true then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- increase timer for use in damage calc

		local pitch = (data.chargedTime) * (150 / getFullChargeTime()) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100

		data.angVel = math.min(1750, data.angVel + (pitch * 20))
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

			data.aftershocksfx = rnd(0.3, 0.8)

			if data.inAltAttack == true then
				if IsPlayerLocal(p) then
					ServerCall("server.secondaryFireDISP", p)
					camSineTime = 0
				end
			else
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireDISP", p)
					camSineTime = 0
				end
			end

			data.recoil = RECOIL_AMNT
			data.chargedTime = nil
			data.inAltAttack = false
			data.inAttack = false
		end
	elseif data.inAttack == true then -- start timer
		data.chargedTime = 0
		data.toolAnimator.forceActionPose = true
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	data.angle = data.angle + data.angVel*dt
	data.angVel = math.max(0, data.angVel - dt*1000)

	if data.aftershocksfx ~= nil then
		data.aftershocksfx = data.aftershocksfx - dt
		if data.aftershocksfx <= 0 then
			data.aftershocksfx = nil
			PlaySound(LoadSound(AFTERSHOCKSFX), mt.pos, 1)
			data.recoil = 0.05
		end
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

	-- CAMERA MOVEMENT
	if IsPlayerLocal(p) then
		if camSineTime ~= nil then
			local x = camSineTime
			local e = math.exp(1)
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 300 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -0.33, 0.0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end

	--Animate barrel around the attachment point
	local b = GetToolBody(p)
	local voxSize = 0.04
	local attach = Transform(Vec(0, 2.5*voxSize, 2.5*voxSize))
	if data.body ~= b then
		data.body = b
		-- Barrel is the second shape in vox file. Remember original position in attachment frame
		local shapes = GetBodyShapes(b)
		data.barrel = shapes[6]
		data.barrelTransform = TransformToLocalTransform(attach, GetShapeLocalTransform(data.barrel))
	end
	if data.barrel then
		attach.rot = QuatEuler(0, 0, -data.angle) -- negative to make it spin the right way
		t = TransformToParentTransform(attach, data.barrelTransform)
		SetShapeLocalTransform(data.barrel, t)
	end
end