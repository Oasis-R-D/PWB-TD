-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/tauFire.ogg"
local AFTERSHOCKSFX = "MOD/snd/tauElect0.ogg"
local PICKUP_SIZE = 10.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.2
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 0.2
local CAMALTMOVETIME = (2 * math.pi) * (0.5 / 0.4) -- Cam movement sine multiplier, 0.4 is how long until it's over
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
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		aftershocksfx = nil,
		chargedTime = nil,
		ammoDepletionTimer = nil,
		firesound = nil,
		angle = 0.0,
		angVel = 0.0,
		body = nil,
		barrel = nil,
		barrelTransform = nil,
		camAltMove = false,
	}
end

function server.initDISP()
	laserSprite = LoadSprite("gfx/laser.png")
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/tau.xml", 6)
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

function client.initDISP()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	gaussLoop = LoadLoop("MOD/snd/tauCharge.ogg")
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
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = DISPplayers[p]

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true and data.inAltAttack ~= true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.5, 0.0, 3)
				data.angVel = 1000
				
				data.aftershocksfx = rnd(0.3, 0.8)
				if IsPlayerLocal(p) then
					ServerCall("server.startShootbeam", true, p)
					camSineTime = 0
				end
				
				local playervel = GetPlayerVelocity(p)
				
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
					ParticleColor(1,0.33,0)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
				
				data.coolDown = FIRERATE
				data.altCoolDown = FIRERATE

				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true and data.inAltAttack ~= true then
		if data.altCoolDown < 0 then
			data.inAltAttack = true
		end
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
			local balance = -15 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 10 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0.0), equation))
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