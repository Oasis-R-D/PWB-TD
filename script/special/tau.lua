-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/tauFire.ogg"
local AFTERSHOCKSFX = "MOD/snd/tauElect0.ogg"
local PICKUP_SIZE = 10.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.2
local ALTFIRERATE = 0.2
local PLAYERDAMAGE = 20 -- divided by 100 later
local MAX_RANGE = 208.0
local WPNID = "hltau"
local WPNNAME = "Tau Cannon"

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		coolDown = 0.0,
		inAltAttack = false,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		aftershocksfx = nil,
		chargedTime = nil,
		ammoDepletionTimer = nil,
		angle = 0.0,
		angVel = 0.0,
		body = nil,
		barrel = nil,
		barrelTransform = nil,
		dataReset = true,
	}
end

local function createPlayerSERVERdata()
    return {
		firesound = nil,
	}
end

function server.initTAU()
	laserSprite = LoadSprite("gfx/laser.png")
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/tau.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickTAU(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerSERVERdata()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerTAU(p, dt)
	--end
end

function server.tickPlayerTAU(p, dt)
end

function getFullChargeTime()
	if isMP() then return 1.5 else return 4 end
end

function client.drawlaser(vecSrc, vecDir, raycastDist, clLaserSprite, p, primary)
	local t = Transform(VecLerp(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 0.5))

	local xAxis = VecNormalize(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecSrc))
	local zAxis = VecNormalize(VecSub(vecSrc, GetCameraTransform(p).pos))

	t.rot = QuatAlignXZ(xAxis, zAxis)

	if primary == true then
		DrawSprite(LoadSprite("MOD/gfx/tau.png"), t, raycastDist, 0.33, 1.0, 0.5, 0.0, 0.66, true, true)
	else
		DrawSprite(LoadSprite("MOD/gfx/tau.png"), t, raycastDist, 0.66, 1.0, 1.0, 1.0, 0.9, true, true) -- 0.9 should be the damage instead.
	end
end

function server.shootbeam(vecOrigSrc, vecDir, flDamage, primary, p)
	local vecSrc = vecOrigSrc

	local flMaxFrac = 1.0
	local iPunches = 0
	local fFirstBeam = true
	local nMaxHits = 10

	while flDamage > 10.0 and nMaxHits > 0 do 
		nMaxHits = nMaxHits - 1
		
		local raycastHit, raycastDist, raycastShape, raycastPlayer, _, raycastNormal = QueryShot(vecSrc, vecDir, MAX_RANGE, 0.0, p)
		
		--DrawLine(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 1.0, 0.1, 0.1, 1)
		if fFirstBeam == true then
			local mt = GetToolLocationWorldTransform("muzzle", p)
			ClientCall(0, "client.drawlaser", mt.pos, vecDir, raycastDist, laserSprite, p, primary)
			fFirstBeam = false
		else ClientCall(0, "client.drawlaser", vecSrc, vecDir, raycastDist, laserSprite, p, primary) end
		
		if not raycastHit then break end

		if raycastPlayer ~= 0 then
			ApplyPlayerDamage(raycastPlayer, flDamage/100.0, WPNNAME, p)
			BloodVFX(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecDir, flDamage/100, raycastPlayer)
			break
		elseif raycastShape ~= 0 then -- hit the world, bounce and or penetrate
			ApplyBodyImpulse(GetShapeBody(raycastShape), VecAdd(vecSrc, VecScale(vecDir, raycastDist)), VecScale(vecDir, flDamage*800.0))

			local n = -1.0 * VecDot(raycastNormal, vecDir)

			if n < 0.5 then -- 60 degrees
				-- reflect
				local r = Vec()

				r = VecAdd(VecScale(raycastNormal, 2.0 * n), vecDir) -- probably not the right math
				flMaxFrac = flMaxFrac - ((1/MAX_RANGE) * raycastDist)
				local oldVecDir = vecDir
				vecDir = r
				vecSrc = VecAdd(VecAdd(vecSrc, VecScale(oldVecDir, raycastDist)), VecScale(vecDir, 0.2))

				MakeHole(vecSrc, 0.9, 0.5, 0.25)
				Paint(vecSrc, 1.0, "explosion", 0.6)
				server.SpawnFireHook(vecSrc, 25)

				local damage_radius = (flDamage * 2.5 * n) / 39.37
				local falloff = flDamage / damage_radius

				-- Radius Damage
				for id in Players() do
					local playerPos = TransformToParentPoint(GetPlayerTransform(id), Vec(0, 1))
					local dist = VecLength(VecSub(vecSrc, playerPos))
					if dist < damage_radius then
						QueryRequire("large visible physical")
						local pHit = QueryRaycast(playerPos, VecNormalize(VecSub(vecSrc, playerPos)), dist)
						if not pHit then
							local flAdjustedDamage = flDamage - (dist * falloff)
							if flAdjustedDamage > 0 then 
								ApplyPlayerDamage(id, flAdjustedDamage/100, WPNNAME, p)
								BloodVFX(playerPos, VecNormalize(VecSub(playerPos, vecSrc)), flAdjustedDamage/100, id)
							end
						end
					end
				end
						
				-- lose energy
				if n <= 0.0 then n = 0.1 end
				flDamage = flDamage * (1.0 - n)

			elseif primary == false then -- try punching through wall if it's a secondary attack (primary is incapable of breaking through)
				if iPunches > 5 then break end
				
				iPunches = iPunches + 1

				local _, checkPenCastDist = QueryShot(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 1.5)), vecDir, 4.0, 0.0, p)

				if checkPenCastDist >= 0.0625 then
					-- trace backwards to find exit point
					local pencast2Hit, pencast2Dist = QueryShot(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 1.5)), VecScale(vecDir, -1.0), 4.0, 0.0, p)

					local n2 = VecLength(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), VecAdd(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 0.2)), VecScale(VecScale(vecDir, -1.0), pencast2Dist))))

					--DebugWatch("penetration n", n2)

					if n2 < flDamage then
						if n2 <= 0.0 then
							n2 = 1.0
						end
						flDamage = flDamage - n2

						MakeHole(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 1.25, 1.0, 0.75) -- entry hole
						Paint(vecSrc, 1.5, "explosion", 0.6)

						vecSrc = VecAdd(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 1.5)), VecScale(VecScale(vecDir, -1), pencast2Dist - 0.25), vecDir)
						server.SpawnFireHook(vecSrc, 50) 

						local damage_radius = 0
						if isMP() then
							damage_radius = flDamage * 1.75
						else
							damage_radius = flDamage * 2.5
						end

						damage_radius = damage_radius / 39.37

						local falloff = flDamage / damage_radius

						local vecPos = VecAdd(vecSrc, VecScale(VecDir, 1))

						-- Radius Damage
						for id in Players() do
							local playerPos = TransformToParentPoint(GetPlayerTransform(id), Vec(0, 1))
							local dist = VecLength(VecSub(vecPos, playerPos))
							if dist < damage_radius then
								local pHit = QueryRaycast(playerPos, VecNormalize(VecSub(vecPos, playerPos)), dist)
								if not pHit then
									local flAdjustedDamage = flDamage - (dist * falloff)
									if flAdjustedDamage > 0 then 
										ApplyPlayerDamage(id, flAdjustedDamage/100, WPNNAME, p)
										BloodVFX(playerPos, VecNormalize(VecSub(playerPos, vecPos)), flAdjustedDamage/100, id)
									end
								end
							end
						end

						MakeHole(vecSrc, 1.25, 1.0, 0.75) -- exit hole
						Paint(vecSrc, 1.5, "explosion", 0.6)
						server.SpawnFireHook(vecSrc, 50)
					end
				else
					flDamage = 0.0
					local origin = VecAdd(vecSrc, VecScale(vecDir, raycastDist))
					MakeHole(origin, 1.25, 0.75, 0.5)	
					server.SpawnFireHook(origin, 50)
					Paint(origin, 1.33, "explosion", 0.6)
				end
			else
				flDamage = 0.0
				local origin = VecAdd(vecSrc, VecScale(vecDir, raycastDist))
				MakeHole(origin, 1.25, 0.75, 0.5)
				server.SpawnFireHook(origin, 50)
				Paint(origin, 1.33, "explosion", 0.6)
			end
		else vecSrc = VecAdd(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecDir) end
	end
end

function server.startShootbeam(primary, p, chargetime)
	local data = playerData[p]
	
	local flDamage = 0.0
	local mt = GetToolLocationWorldTransform("muzzle", p)

	StopSound(data.firesound)

	local _,vecSrc,_,vecAiming = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, MAX_RANGE, p)
	if primary == false then
		chargetime = chargetime or 0

		if chargetime > getFullChargeTime() then
			flDamage = 200
		else
			flDamage = 200 * (chargetime / getFullChargeTime())
		end

		data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 350)

		local eyeTrans = GetPlayerEyeTransform(p)
		local back = TransformToParentVec(eyeTrans, Vec(0, 0, 1))
		local newplayervel = VecAdd(GetPlayerVelocity(p), VecScale(VecNormalize(back), flDamage * 0.0625))
		SetPlayerVelocity(newplayervel, p)
		
		if chargetime > 10 then
			ApplyPlayerDamage(p, 0.5, "Overcharged")
			BloodVFX(GetPlayerEyeTransform(p).pos, VecNormalize(back), 0.66, p)
		end
	else 
		server.depleteAmmo(p, WPNID)

		flDamage = PLAYERDAMAGE -- fixed damage in primary
		data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	end

	server.shootbeam(vecSrc, vecAiming, flDamage, primary, p)
end

function client.initTAU()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	gaussLoop = LoadLoop("MOD/snd/tauCharge.ogg")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickTAU(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerTAU(p, dt)
	end
end

function client.tickPlayerTAU(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
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
	if InputDown("usetool", p) and canFire(p, ammo, ammo, data.coolDown) and data.inAltAttack ~= true then	
		PointLight(mt.pos, 1, 0.5, 0.0, 3)
		data.angVel = 1000
		
		data.aftershocksfx = rnd(0.3, 0.8)
		if IsPlayerLocal(p) then
			ServerCall("server.startShootbeam", true, p)
			client.SRC_PunchAxis(1, 2)

			PlayHaptic(shootHaptic, 1)
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

		data.recoil = RECOIL_AMNT
	-- Check Altfire
	elseif InputPressed("grab", p) and canFire(p, ammo, ammo, data.coolDown) and data.inAltAttack ~= true then
		data.inAltAttack = true
	end

	if data.chargedTime ~= nil and data.inAltAttack == true then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- increase timer for use in damage calc
		local forceFire = false
		if data.ammoDepletionTimer ~= nil then
			if data.ammoDepletionTimer <= 0 and data.chargedTime < getFullChargeTime() then

				if ammo < 2 then
					forceFire = true
				end

				if IsPlayerLocal(p) then
					ServerCall("server.depleteAmmo", p, WPNID)
				end

				if isMP() == true then
					data.ammoDepletionTimer = 0.2
				else
					data.ammoDepletionTimer = 0.6
				end
			end

			data.ammoDepletionTimer = data.ammoDepletionTimer - dt
		else
			if isMP() == true then
				data.ammoDepletionTimer = 0.2
			else
				data.ammoDepletionTimer = 0.6
			end
		end
		
		local pitch = (data.chargedTime) * (150 / getFullChargeTime()) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100

		data.angVel = math.min(1750, data.angVel + (pitch * 20))
		data.recoil = math.min(0.1, data.recoil + (pitch * 0.5))

		PlayLoop(gaussLoop, mt.pos, 1, true, pitch)

		if (data.chargedTime > 0.5 and not InputDown("grab", p)) or data.chargedTime > 10 or forceFire == true then -- swing start animation done (in opfor)
			PointLight(mt.pos, 1, 1, 1, 5)

			data.toolAnimator.forceActionPose = false

			local playervel = GetPlayerVelocity(p)
				
			-- muzzleflash
			for i=0, 3 do
				ParticleReset()
				ParticleGravity(0)
				ParticleRadius(rnd(0.1, 0.2), 0.4)
				ParticleAlpha(1, 0)
				ParticleTile(5)
				ParticleDrag(0)
				ParticleRotation(rnd(10, -10), 0)
				ParticleSticky(0)
				ParticleEmissive(5, 1)
				ParticleCollide(0)
				ParticleColor(1,0.8,0.75)
				SpawnParticle(mt.pos, playervel, 0.125)
			end

			data.aftershocksfx = rnd(0.3, 0.8)

			if IsPlayerLocal(p) then
				ServerCall("server.startShootbeam", false, p, data.chargedTime)
				client.SRC_PunchAxis(1, 4)

				PlayHaptic(shootHaptic, 1)
			end

			data.coolDown = 0.2
			if data.chargedTime > 10 then
				data.coolDown = 1
			end

			data.recoil = 2.5 * RECOIL_AMNT
			data.chargedTime = nil
			data.inAltAttack = false
		end
	elseif data.inAltAttack == true then -- start timer
		data.chargedTime = 0
		data.toolAnimator.forceActionPose = true
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
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