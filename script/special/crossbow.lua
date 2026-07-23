-- copy this for the most basic scoped mag loaded weapon with slower empty reloads (INCLUDES SCOPE)
#version 2

-- Per weapon constants
local RELOAD_TIME = 4.5 -- seconds
local RELOAD_SOUND = "MOD/snd/glockR.ogg"
local PRIM_FIRESOUND = "MOD/snd/crossbow_fire.ogg"
local BOLT_CYCLE = "MOD/snd/crossbow_load0.ogg"
local CLIP_SIZE = 5
local PICKUP_SIZE = 5
local RECOIL_AMNT = 0.25
local FIRERATE = 0.75
local ALTFIRERATE = 0.5
local SCOPEFIREDELAY = 0.1
local DAMAGE = 0.5
local PLAYERDAMAGE = 0.45
local WPNID = "hlcrossbow"
local WPNNAME = "Crossbow"

local PROJ_IMPACT = "MOD/snd/crossbow_bt_hit.ogg"
local PROJ_IMPACT_PLAYER = "MOD/snd/crossbow_bt_player0.ogg"

local PROJ_VELOCITY = 50.8
local PROJ_VELOCITY_WATER = 25.4
local PROJ_VELOCITY_AIMED = 10000 -- Hitscan when fired while aiming

-- Per weapon data storer
local playerData = {}

-- Stores data for all the BOLTS
CrossbowBolts = {}

local function createPlayerCLIENTdata()
    return {
		clipamnt = CLIP_SIZE,
		coolDown = 0.0,
		altCoolDown = 0.0,
		inreload = false,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		scoped = false,
		timetobolt = nil,
		hasBolt = true,
		dataReset = true,
		shapesNeedsUpd = true,
	}
end

function createProjSERVERdataCB(p, pos, dir, body, aimed)
    return {
		curDir = dir,
		curPos = pos,
		model = body,
		owner = p,
		scoped = aimed,
		totalDist = 0.0,
	}
end

function server.crossbowExplode(pos, owner, model)
	Paint(pos, 0.75, "explosion", 0.5)
	PointLight(pos, 0.75, 0.5, 0.063, 3)
	PlaySound(LoadSound("snd/explosion/m0.ogg"), pos, 1.0)

	for i=0, 5 do
		ParticleReset()
		ParticleGravity(0)
		ParticleRadius(rnd(0.5, 1), 2)
		ParticleAlpha(1, 0)
		ParticleTile(5)
		ParticleDrag(0)
		ParticleRotation(rnd(10, -10), 0)
		ParticleSticky(0)
		ParticleEmissive(5, 0)
		ParticleCollide(0)
		ParticleColor(1,0.35,0, 1,0,0)
		SpawnParticle(pos, Vec(0,0,0), 0.125)
	end

	for id in Players() do
        local playerPos = TransformToParentPoint(GetPlayerTransform(id), Vec(0, 1))
		local dist = VecLength(VecSub(pos, playerPos))
		if dist <= 3.2512 then
			QueryRejectBody(model)
			QueryRequire("large visible physical")
			local pHit = QueryRaycast(playerPos, VecNormalize(VecSub(pos, playerPos)), dist+0.1)
			if not pHit then
				dist = dist * 39.37
				local damage = 40
				local falloff = damage / 128 -- 3.2512 meters in approx HU
				local flAdjustedDamage = damage - (dist * falloff)
				if flAdjustedDamage > 0 then ApplyPlayerDamage(id, flAdjustedDamage/100, WPNNAME, owner) end
			end
		end
    end

	local strength = 5.0	--Strength of blower
	local maxMass = 1048576	--The maximum mass for a body to be affected
	local maxDist = 3.2512	--The maximum distance for bodies to be affected
	local mi = VecAdd(pos, Vec(-maxDist/2, -maxDist/2, -maxDist/2))
	local ma = VecAdd(pos, Vec(maxDist/2, maxDist/2, maxDist/2))
	QueryRequire("physical dynamic")
	local bodies = QueryAabbBodies(mi, ma)

	for i=1,#bodies do
		local b = bodies[i]

		--Compute body center point and distance
		local bmi, bma = GetBodyBounds(b)
		local bc = VecLerp(bmi, bma, 0.5)
		local dir = VecSub(bc, pos)
		local dist = VecLength(dir)
		
		--Get body mass
		local mass = GetBodyMass(b)

		dir = VecScale(dir, 1.0 / dist)
			
		--Check if body should be affected
		if dist < maxDist and mass < maxMass then
			dir = VecNormalize(dir)
	
			--Compute how much velocity to add
			local massScale = 1 - math.min(mass/maxMass, 1.0)
			local distScale = 1 - math.min(dist/maxDist, 1.0)
			local add = VecScale(dir, strength * massScale * distScale)
			
			--Add velocity to body
			local vel = GetBodyVelocity(b)
			vel = VecAdd(vel, add)
			SetBodyVelocity(b, vel)
		end
	end
end

function server.initCROSS()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/crossbow.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickCROSS(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerCROSS(p, dt)
	--end

	if #CrossbowBolts == 0 then return end -- no crossbow bolts
	
	for index = 1, #CrossbowBolts do
		local data = CrossbowBolts[index]

		if data ~= nil then
			if data.totalDist > 1000 then -- make 500 if using HL2 speed
				Delete(data.model)
				table.remove(CrossbowBolts, index)
			else
				QueryRequire("large visible physical")
				QueryRejectBody(data.model)
				
				local vel = PROJ_VELOCITY

				if data.scoped == true then
					vel = PROJ_VELOCITY_AIMED
				elseif IsPointInWater(data.curPos) == true then
					vel = PROJ_VELOCITY_WATER
				end

				local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.curDir, vel * dt, 0.0, data.owner)

				data.curPos = VecAdd(data.curPos, VecScale(data.curDir, dist))
				
				data.totalDist = data.totalDist + dist

				SetBodyTransform(data.model, Transform(data.curPos, QuatLookAt(Vec(), data.curDir)))

				-- damage, vfx
				if hit then
					local hitAnimator = GetBodyAnimator(GetShapeBody(shape))

					if hitPlayer ~= 0 then
						PlaySound(LoadSound(PROJ_IMPACT_PLAYER), data.curPos, 0.5)

						local playerdamage = PLAYERDAMAGE

						-- apply hitgroups
						QueryRequire("player")
						QueryInclude("player")
						QueryRejectPlayer(data.owner)
						local _, _, _, bodyPart = QueryRaycast(data.curPos, data.curDir, 0.25)

						local hitPart = GetTagValue(GetShapeBody(bodyPart), "bone")
						if hitPart == "head" or hitPart == "neck" then
							playerdamage = playerdamage * GLOBAL_HEADSHOTMULT
						end

						ApplyPlayerDamage(hitPlayer, playerdamage, WPNNAME, data.owner)
						BloodVFX(data.curPos, data.curDir, playerdamage, hitPlayer)

						if data.scoped ~= true then
							server.crossbowExplode(data.curPos, data.owner, data.model)
						end

						Delete(data.model)
						table.remove(CrossbowBolts, index)
					elseif hitAnimator ~= 0 then
						PlaySound(LoadSound(PROJ_IMPACT_PLAYER), data.curPos, 0.5)

						ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 4))
						BloodVFX(data.curPos, data.curDir, PLAYERDAMAGE, nil, hitAnimator)

						if data.scoped ~= true then
							server.crossbowExplode(data.curPos, data.owner, data.model)
						end

						Delete(data.model)
						table.remove(CrossbowBolts, index)
					else
						if IsPointInWater(data.curPos) ~= true then
							-- sparks
							for i=1,10 do
								ParticleReset()
								ParticleCollide(1)
								ParticleRadius(0.02, 0)
								ParticleGravity(-10)
								ParticleEmissive(5)
								ParticleStretch(5)
								ParticleTile(4)
								ParticleColor(1,0.5,0.4, 1,0.25,0)
								SpawnParticle(data.curPos, Vec(math.random(-2,2), math.random(1,4), math.random(-2,2)), 1)
							end
						end
						
						-- get mat type BEFORE we break it
						local pos = VecSub(data.curPos, VecScale(normal, 0.05))
						pos = TransformToLocalPoint(GetShapeWorldTransform(shape), pos)
						for i = 1, 3 do
							pos[i] = math.floor(pos[i]*10)
						end

						local matType = GetShapeMaterialAtIndex(shape, pos[1], pos[2], pos[3])

						ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 4))
						MakeHole(data.curPos, 0.75, 0.4, 0.25)

						if matType ~= "glass" or HasTag(GetShapeBody(shape), "unbreakable") == true then
							PlaySound(LoadSound(PROJ_IMPACT), data.curPos, 0.5)

							if data.scoped ~= true then
								server.crossbowExplode(data.curPos, data.owner, data.model)
							end

							Delete(data.model)
							table.remove(CrossbowBolts, index)
						end
					end
				end
			end
		end
	end
end

function server.tickPlayerCROSS(p, dt)
end

function server.primaryFireCROSS(p, scoped)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if ammo <= 0 then return end
	
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0, p)

	local GrenTrans = Transform(Vec(0, -1000, 0))
	local xml = "MOD/prefab/crossbow_bolt.xml"
	local boltEnt = Spawn(xml, GrenTrans)

	-- add bolt to sim
	CrossbowBolts[findArrayOpening(CrossbowBolts)] = createProjSERVERdataCB(p, pos, dir, boltEnt[1], scoped)

	PlaySound(LoadSound(PRIM_FIRESOUND), pos, 300)
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initCROSS()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickCROSS(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerCROSS(p, dt)
	end
end

-- stolen from glock, used to hide/show bolt
function client.boltUPD(p, suppressed)
	local toolBody = GetToolBody(p)
	local shapes = GetBodyShapes(toolBody)
	if suppressed == false then
		SetTag(shapes[2], "invisible")
	else
		RemoveTag(shapes[2], "invisible")
	end
end

function client.tickPlayerCROSS(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		playerData[p].shapesNeedsUpd = true
		playerData[p].scoped = false
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", p)
	if mt == nil then
		return
	end

	local ammo = GetToolAmmo(WPNID, p)

	

	local data = playerData[p]

	-- tell gun to restore bolt state
	if data.shapesNeedsUpd == true then
		data.shapesNeedsUpd = false

		if data.timetobolt == nil or data.timetobolt <= 0 then
			data.timetobolt = 0.1
		end

		data.toolAnimator.timeSinceFire = 0.0
	end

	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Start Reload
	if InputPressed("r", p) and data.inreload == false and data.clipamnt < CLIP_SIZE and ammo > 0.5 and data.clipamnt ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
		if data.clipamnt > 0 then
			data.coolDown = RELOAD_TIME
		end
		data.inreload = true
	-- Finish Reload
	elseif data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, ammo, data.coolDown) then -- not a good idea to use hasbolt here, only way to prevent THE BUG
		if IsPlayerLocal(p) then
			ServerCall("server.primaryFireCROSS", p, data.scoped)
			client.SRC_PunchAxis(1, 2)

			PlayHaptic(shootHaptic, 1)
		end
		
		local playervel = GetPlayerVelocity(p)

		data.hasBolt = false
		client.boltUPD(p, data.hasBolt)

		data.altCoolDown = SCOPEFIREDELAY

		data.recoil = data.scoped == true and 0 or RECOIL_AMNT

		data.clipamnt = data.clipamnt - 1
		if data.clipamnt > 0 then
			data.coolDown = FIRERATE
			data.timetobolt = 0.842
		elseif ammo > 1 then
			PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
			data.coolDown = RELOAD_TIME
			data.inreload = true
			data.timetobolt = 4.4
		end
	-- Check Altfire
	elseif InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			data.altCoolDown = ALTFIRERATE
			data.scoped = not data.scoped
		end
	end

	if data.scoped == false or ammo <= 0 then
		data.toolAnimator.forceSecondaryActionPose = false
	elseif data.scoped == true then
		data.toolAnimator.forceSecondaryActionPose = true

		if IsPlayerLocal(p) then
			SetCameraFov(18)
		end
	end
		
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- Put new bolt in
	if data.timetobolt ~= nil then
		data.timetobolt = data.timetobolt - dt
		if data.timetobolt <= 0 then
			data.hasBolt = true -- shouldn't matter since you can't switch out of and back with 0 ammo
			if ammo > 0 then -- already plays bolt sfx in reload
				client.boltUPD(p, data.hasBolt)
				PlaySound(LoadSound(BOLT_CYCLE), mt.pos)
				data.toolAnimator.timeSinceFire = 0.0
			end

			data.timetobolt = nil
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
end

function client.drawCROSS()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end