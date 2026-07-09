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
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
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

-- Per weapon data storer
local playerData = {}

-- Stores data for all the BOLTS
CrossbowBolts = {}

function createPlayerCLIENTdataCROSS()
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

function createBallSERVERdataCB(p, pos, dir, body)
    return {
		curDir = dir,
		curPos = pos,
		model = body,
		owner = p,
		totalDist = 0.0,
	}
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
				local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.curDir, (IsPointInWater(data.curPos) == true and PROJ_VELOCITY_WATER or PROJ_VELOCITY) * dt, 0.0, data.owner)

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

						Delete(data.model)
						table.remove(CrossbowBolts, index)
					elseif hitAnimator ~= 0 then
						PlaySound(LoadSound(PROJ_IMPACT_PLAYER), data.curPos, 0.5)

						ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 4))
						BloodVFX(data.curPos, data.curDir, PLAYERDAMAGE, nil, hitAnimator)

						Delete(data.model)
						table.remove(CrossbowBolts, index)
					else
						-- See if we should reflect off this surface
						local hitDot = VecDot(normal, VecScale(data.curDir, -1))
						if hitDot < 0.5 and dist ~= 0 then
							ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 2))
                        	MakeHole(data.curPos, 0.5, 0.25, 0.05)

							data.curDir = VecAdd(VecScale(normal, 2 * hitDot), data.curDir)
							data.curPos = VecAdd(data.curPos, VecScale(data.curDir, 0.01))

							PlaySound(LoadSound(PROJ_IMPACT), data.curPos, 0.25)
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

								Delete(data.model)
								table.remove(CrossbowBolts, index)
							end
						end
					end
				end
			end
		end
	end
end

function server.tickPlayerCROSS(p, dt)
end

function server.primaryFireCROSS(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if ammo <= 0 then return end
	
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0, p)

	local GrenTrans = Transform(Vec(0, -1000, 0))
	local xml = "MOD/prefab/crossbow_bolt.xml"
	local boltEnt = Spawn(xml, GrenTrans)

	-- add bolt to sim
	CrossbowBolts[findArrayOpening(CrossbowBolts)] = createBallSERVERdataCB(p, pos, dir, boltEnt[1])

	PlaySound(LoadSound(PRIM_FIRESOUND), pos, 300)
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initCROSS()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickCROSS(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataCROSS();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerCROSS(p, dt)
	end
end

local camSineTime = nil

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
			playerData[p] = createPlayerCLIENTdataCROSS()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		playerData[p].shapesNeedsUpd = true
		playerData[p].scoped = false
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
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		if data.clipamnt > 0 then
			data.coolDown = RELOAD_TIME
		end
		data.inreload = true
	-- Finish Reload
	elseif data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, ammo) then -- not a good idea to use hasbolt here, only way to prevent THE BUG
		if data.coolDown < 0 then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireCROSS", p)
				camSineTime = 0
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
				PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
				data.coolDown = RELOAD_TIME
				data.inreload = true
				data.timetobolt = 4.4
			end
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
	
	if data.timetobolt ~= nil then
		data.timetobolt = data.timetobolt - dt
		if data.timetobolt <= 0 then
			data.hasBolt = true -- shouldn't matter since you can't switch out of and back with 0 ammo
			if ammo > 0 then -- already plays bolt sfx in reload
				client.boltUPD(p, data.hasBolt)
				PlaySound(LoadSound(BOLT_CYCLE), pt.pos)
				data.toolAnimator.timeSinceFire = 0.0
			end

			data.timetobolt = nil
			data.recoil = 0.05
		end
	end
	-- END SHELL EJECT

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

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 1000 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(0.66, 0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawCROSS()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end