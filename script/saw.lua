-- copy this for the most basic mag loaded weapon (INCLUDES PUSHBACK ON FIRE)
#version 2

-- Per weapon constants
local RELOAD_TIME = 3.8 -- seconds
local RELOAD_SOUND = "MOD/snd/m249r.ogg"
local PRIM_FIRESOUND = "MOD/snd/249_fr0.ogg"
local CLIP_SIZE = 50
local PICKUP_SIZE = 100
local RECOIL_AMNT = 0.2
local FIRERATE = 0.067 -- NO
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.15
local MAX_RANGE = 125.0
local WPNID = "opform249_saw"
local WPNNAME = "M249 SAW"
local CASING_ORG = Vec(0.02, 0.05, -0.05)

-- Per weapon data storer
local playerData = {}

function createPlayerCLIENTdataM249()
    return {
		clipamnt = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		alteject = false, -- M249 ejects both the belt bits and bullets (alternating between them in opfor tho)
		dataReset = true,
	}
end

function createPlayerSERVERdataM249()
    return {
		firesound = nil,
	}
end

function server.initM249()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/saw.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickM249(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerSERVERdataM249()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerM249(p, dt)
	--end
end

function server.tickPlayerM249(p, dt)
end

function server.primaryFireM249(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	if IsPlayerGrounded(p) and GetPlayerCrouch(p) < 0.1 then
		local vecVelocity = GetPlayerVelocity(p)
		local flZVel = vecVelocity[2]

		local vecInvPushDir = TransformToParentVec(GetPlayerTransform(p), Vec(0, 0, -2))

		local flNewZVel = 10.1575

		if vecInvPushDir[2] >= 0.3714 then
			flNewZVel = vecInvPushDir[2]
		end

		local newVel = 0

		if isMP() then
			newVel = VecSub(vecVelocity, vecInvPushDir)

			-- Restore Z velocity to make deathmatch easier.
			newVel[2] = flZVel
		else
			local flZTreshold = -1 * (flNewZVel + 3.174)

			newVel = vecVelocity

			if (vecVelocity[1] > flZTreshold) then
				newVel[1] = newVel[1] - vecInvPushDir[1]
			end

			if (vecVelocity[3] > flZTreshold) then
				newVel[3] = newVel[3] - vecInvPushDir[3]
			end

			newVel[2] = newVel[2] - vecInvPushDir[2]
			
		end

		SetPlayerVelocity( newVel, p )
	end
	
	local data = playerData[p]

	local crouch = GetPlayerCrouch(p)
	local pvel = GetPlayerVelocity(p)

	local spread = GLOBAL_4DEGREES -- assuming spread is a radian value and this is the diameter of the cone
	if crouch > 0.1 then
		spread = GLOBAL_2DEGREES
	end
	
	if not IsPlayerGrounded(p) or VecLength(pvel) > (GetPlayerWalkingSpeed() * 0.75) then
		spread = GLOBAL_10DEGREES
	end

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, spread, p)

	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)

	server.depleteAmmo(p, WPNID)
end

function client.initM249()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickM249(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataM249();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerM249(p, dt)
	end
end

local camSineTime = nil

function client.tickPlayerM249(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataM249()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		if IsPlayerLocal(p) then
			camSineTime = nil
		end
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = playerData[p]

	-- make data reset when reset conditions are met
	data.dataReset = false
	
	-- Start Reload
	if InputPressed("r", p) and data.inreload == false and data.clipamnt < CLIP_SIZE and ammo > 0.5 and data.clipamnt ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		data.coolDown = RELOAD_TIME
		data.inreload = true
	-- Finish Reload
	elseif data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt) then
		if data.coolDown < 0 then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			local toolBody = GetToolBody(p)
			local playervel = GetPlayerVelocity(p)

			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireM249", p)
				camSineTime = 0
				PlayHaptic(shootHaptic, 1)

				-- shell ejection
				local transform = GetBodyTransform(toolBody)
				local eject_origin = TransformToParentPoint(transform, CASING_ORG)
				local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
				ParticleReset()
				ParticleGravity(rnd(-2, -8))
				ParticleRadius(0.02)
				ParticleAlpha(1)
				if data.alteject == true then -- opfor ejects casings and belt bits separately
					ParticleColor(0.8, 0.6, 0)
				else
					ParticleColor(0.5, 0.5, 0.5)
				end
				ParticleTile(6)
				ParticleDrag(0.125)
				ParticleSticky(0.5)
				ParticleCollide(1)
				SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
				
				data.alteject = not data.alteject
			end

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
				ParticleColor(1,0.35,0, 1,0,0)
				SpawnParticle(mt.pos, playervel, 0.125)
			end
				
			data.clipamnt = data.clipamnt - 1
			if data.clipamnt > 0 then
				data.coolDown = FIRERATE
			elseif ammo > 1 then
				PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
				data.coolDown = RELOAD_TIME
				data.inreload = true
			end
			
			data.recoil = RECOIL_AMNT
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
	
	-- hide shells if low ammo
	local toolBody = GetToolBody(p)
	local shapes = GetBodyShapes(toolBody)
	
	if data.clipamnt < 4.5 then -- four shots left
		-- hide third shell
		SetTag(shapes[3], "invisible")
	elseif HasTag(shapes[3], "invisible") == true then
		RemoveTag(shapes[3], "invisible")
	end
	
	if data.clipamnt < 2.5 then -- two shots left
		-- hide second shell
		SetTag(shapes[2], "invisible")
	elseif HasTag(shapes[2], "invisible") == true then
		RemoveTag(shapes[2], "invisible")
	end
	
	if data.clipamnt < 0.5 then -- empty mag
		-- hide first shell
		SetTag(shapes[1], "invisible")
	elseif HasTag(shapes[1], "invisible") == true then
		RemoveTag(shapes[1], "invisible")
	end
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 7.5 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawM249()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end