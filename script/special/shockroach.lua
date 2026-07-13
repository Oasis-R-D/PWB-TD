-- copy this for the most basic scoped mag loaded weapon with slower empty reloads (INCLUDES SCOPE)
#version 2

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/shck_fr.ogg"
local BOLT_CYCLE = "MOD/snd/shck_rchrg.ogg"
local PICKUP_SIZE = 10.0
local RECOIL_AMNT = 0.25
local FIRERATE = 0.2
local DAMAGE = 0.5
local PLAYERDAMAGE = 0.15
local WPNID = "opforroach"
local WPNNAME = "Shockroach"

local PROJ_IMPACT = "MOD/snd/shck_imp.ogg"
local BALL_VELOCITY = 50.8

local COLOR = Vec(0, 1, 1)

-- Per weapon data storer
local playerData = {}

-- Stores data for all the BOLTS
ElectricityBolts = {}

function createPlayerCLIENTdataSHCK()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		timetobolt = nil,
		dataReset = true,
        fakeAmmo = 10,
        deployed = false,
	}
end

function createPlayerSERVERdataSHCK()
    return {
		firesound = nil,
	}
end

function createProjSERVERdataSR(p, pos, dir)
    return {
		curDir = dir,
		curPos = pos,
		owner = p,
		totalDist = 0.0,
	}
end

function server.initSHCK()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/roach.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickSHCK(dt)
	for p in PlayersAdded() do
        playerData[p] = createPlayerSERVERdataSHCK()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 999999, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	if #ElectricityBolts == 0 then return end -- no shock
	
	for index = 1, #ElectricityBolts do
		local data = ElectricityBolts[index]
        if data ~= nil then
            if data.totalDist > 500 then table.remove(ElectricityBolts, index) else
                QueryRequire("large visible physical")
                QueryRejectBody(data.model)
                local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.curDir, BALL_VELOCITY * dt, 0.0, data.owner)

                data.curPos = VecAdd(data.curPos, VecScale(data.curDir, dist))
                
                data.totalDist = data.totalDist + dist

                SetBodyTransform(data.model, Transform(data.curPos, QuatLookAt(Vec(), data.curDir)))

                local hitWater = IsPointInWater(data.curPos)

                -- damage, vfx
                if hit or hitWater == true then
                    local hitAnimator = GetBodyAnimator(GetShapeBody(shape))

                    if hitPlayer ~= 0 then
                        ApplyPlayerDamage(hitPlayer, PLAYERDAMAGE, WPNNAME, data.owner)
                        BloodVFX(data.curPos, data.curDir, PLAYERDAMAGE, hitPlayer)
                    elseif hitAnimator ~= 0 then
                        BloodVFX(data.curPos, data.curDir, PLAYERDAMAGE, nil, hitAnimator)

                        ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 2))
                    elseif hitWater ~= false and data.owner ~= 0 then
                        local firerPos = VecAdd(GetPlayerTransform(data.owner).pos, Vec(0,1,0))

                        PlaySound(LoadSound(PROJ_IMPACT), data.curPos, 0.5)

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

                        PointLight(data.curPos, COLOR[1], COLOR[2], COLOR[3], 1)

                        if IsPointInWater(firerPos) and VecLength(VecSub(firerPos, data.curPos)) < 5 then 
                            ApplyPlayerDamage(data.owner, 0.5, WPNNAME, data.owner)
                            BloodVFX(firerPos, Vec(0, 1, 0), 0.5, data.owner)
                        end
                    else
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

                        PointLight(data.curPos, COLOR[1], COLOR[2], COLOR[3], 1)

                        -- get mat type BEFORE we break it
                        --local matType = GetShapeMaterialAtPosition(shape, data.curPos)

                        ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 2))
                        MakeHole(data.curPos, 0.5, 0.05, 0)

                        server.SpawnFireHook(data.curPos, 75)
                        Paint(data.curPos, 0.4, "explosion", 0.75)
                    end

                    PlaySound(LoadSound(PROJ_IMPACT), data.curPos, 0.5)

                    table.remove(ElectricityBolts, index)
                else
                    PointLight(data.curPos, COLOR[1], COLOR[2], COLOR[3], 0.5)

                    ParticleReset()
                    ParticleCollide(0)
                    ParticleRadius(0.3, 0)
                    ParticleGravity(0)
                    ParticleEmissive(5)
                    ParticleStretch(3)
                    ParticleTile(5)
                    local colorRnd = math.random()
                    local colorRnd2 = math.random()
                    local colorRnd3 = math.random()
                    ParticleColor(0,0.35,1, 1,0.35,0)
                    SpawnParticle(VecSub(data.curPos, VecScale(data.curDir, BALL_VELOCITY*dt*0.5)), VecScale(data.curDir, BALL_VELOCITY), 4*dt)
                    ParticleTile(4)
                    SpawnParticle(data.curPos, Vec(), 2*dt)
                end
            end
        end
	end
end

function server.tickPlayerSHCK(p, dt)
end

function server.primaryFireSHCK(p)
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0, p)

	-- add bolt to sim
	ElectricityBolts[findArrayOpening(ElectricityBolts)] = createProjSERVERdataSR(p, pos, dir)

    local data = playerData[p]

	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), pos, 100)
end

function client.initSHCK()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickSHCK(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataSHCK();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerSHCK(p, dt)
	end
end

function client.tickPlayerSHCK(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataSHCK()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then 
        playerData[p].deployed = false
        return
    end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	if mt == nil then
		return
	end

	local data = playerData[p]

    if data.deployed == false then
        data.deployed = true
        if isMP() then
            if data.fakeAmmo < 10 then data.timetobolt = 0.25 else data.timetobolt = nil end
        else
            if data.fakeAmmo < 10 then data.timetobolt = 0.5 else data.timetobolt = nil end
        end
    end

	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Check Fire
	if InputDown("usetool", p) and canFire(p, data.fakeAmmo, data.fakeAmmo) then -- not a good idea to use hasbolt here, only way to prevent THE BUG
		if data.coolDown < 0 then
			PointLight(mt.pos, 0, 1, 1, 3)
			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireSHCK", p)
				PlayHaptic(shootHaptic, 1)
			end

			local playervel = GetPlayerVelocity(p)

            for i=1, 4 do
                ParticleReset()
                ParticleGravity(0)
                ParticleRadius(0.3)
                ParticleAlpha(1, 0)
                ParticleTile(1)
                ParticleDrag(0)
                ParticleRotation(rnd(10, -10), 0)
                ParticleSticky(0)
                ParticleEmissive(5, 1)
                ParticleCollide(0)
                ParticleColor(0, 1, 1)
                SpawnParticle(mt.pos, playervel, 0.125)
            end

			data.timetobolt = 1

            if isMP() then
			    data.coolDown = FIRERATE/2
            else
                data.coolDown = FIRERATE  
            end

			data.recoil = RECOIL_AMNT

            data.fakeAmmo = data.fakeAmmo - 1
		end
	end
		
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt
	
	if data.timetobolt ~= nil then
		data.timetobolt = data.timetobolt - dt
		if data.timetobolt <= 0 then
            PlaySound(LoadSound(BOLT_CYCLE), pt.pos)
            data.fakeAmmo = data.fakeAmmo + 1
            data.toolAnimator.timeSinceFire = 0.0
            data.recoil = 0.05

            if isMP() then
                if data.fakeAmmo < 10 then data.timetobolt = 0.25 else data.timetobolt = nil end
            else
                if data.fakeAmmo < 10 then data.timetobolt = 0.5 else data.timetobolt = nil end
            end
		end
	end
	-- END SHELL EJECT
	
	-- RECOIL
	if data.recoil > -0.5 then
		local recoil = 0
		local siderecoil = math.max(0, data.recoil*0.25)
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

function client.drawSHCK()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	client.drawSecAmmo(playerData[p].fakeAmmo)
end