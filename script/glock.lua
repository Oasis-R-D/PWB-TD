-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/glockR.ogg"
local PRIM_FIRESOUND = "MOD/snd/glockFR.ogg"
local NONCLIENTPRIM_FIRESOUND = "MOD/snd/glockFRnc.ogg" -- glock has diff sounds when shot by NPCs (in this case, other players)
local SUPPRIM_FIRESOUND = "MOD/snd/supglockFR.ogg"
local SUPNONCLIENTPRIM_FIRESOUND = "MOD/snd/supglockFRnc.ogg" -- glock has diff sounds when shot by NPCs (in this case, other players)
local CLIP_SIZE = 17.0
local PICKUP_SIZE = 17.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.3
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 0.2
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.12
local MAX_RANGE = 125.0
local WPNID = "hlglock"
local WPNNAME = "9mm HandGun"
local CASING_ORG = Vec(0.02, 0.25, 0.0)

-- Per weapon data storer
local playerData = {}

function createPlayerCLIENTdataPIST9MM()
    return {
		clipamnt = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		tertiaryCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
		suppressed = false,
		dataReset = true,
		shapesNeedsUpd = true,
	}
end

function server.initPIST9MM()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/glock.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickPIST9MM(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerPIST9MM(p, dt)
	--end
end

function server.tickPlayerPIST9MM(p, dt)
end

function server.primaryFirePIST9MM(p, silenced)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	if silenced == true then mt = GetToolLocationWorldTransform("supend", p) end

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0.01, p)

	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFirePIST9MM(p, silenced) -- separated for easy modification
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	if silenced == true then mt = GetToolLocationWorldTransform("supend", p) end

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0.1, p)

	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	server.depleteAmmo(p, WPNID)
end

function client.initPIST9MM()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickPIST9MM(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataPIST9MM();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerPIST9MM(p, dt)
	end
end

local camSineTime = nil

function client.suppress(p, suppressed)
	local toolBody = GetToolBody(p)
	local shapes = GetBodyShapes(toolBody)
	if suppressed == false then
		SetTag(shapes[5], "invisible")
	else
		RemoveTag(shapes[5], "invisible")
	end
end

function client.tickPlayerPIST9MM(p, dt)
	if not IsToolEnabled(WPNID, p) then 
		return 
	end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataPIST9MM()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		playerData[p].shapesNeedsUpd = true
		if IsPlayerLocal(p) then
			camSineTime = nil
		end
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	if playerData[p].suppressed == true then mt = GetToolLocationWorldTransform("supend", p) end

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = playerData[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Restore Suppresor
	if data.shapesNeedsUpd == true then
		if HasTag(GetBodyShapes(GetToolBody(p))[5], "invisible") == true then
			client.suppress(p, data.suppressed)
			data.shapesNeedsUpd = false
		end
	-- Start Reload
	elseif InputPressed("r", p) and data.inreload == false and data.clipamnt < CLIP_SIZE and ammo > 0.5 and data.clipamnt ~= ammo then
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
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt) then
		if data.coolDown < 0 then
			StopSound(data.firesound)
			
			local toolBody = GetToolBody(p)
			local playervel = GetPlayerVelocity(p)

			if data.suppressed == false then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
					ServerCall("server.primaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					ejectBrass(p, CASING_ORG, Vec(0.6, 0.2, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
				else
					data.firesound = PlaySound(LoadSound(NONCLIENTPRIM_FIRESOUND), mt.pos, 300)
				end

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
					ParticleColor(1,0.35,0, 1,0,0)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			else
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(SUPPRIM_FIRESOUND), mt.pos, 20)
					ServerCall("server.primaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					ejectBrass(p, CASING_ORG, Vec(0.6, 0.2, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
				else
					data.firesound = PlaySound(LoadSound(SUPNONCLIENTPRIM_FIRESOUND), mt.pos, 20)
				end

				-- muzzleflash
				for i=0, 2 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.08, 0.12), 0.2)
					ParticleAlpha(0.75, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleCollide(0)
					ParticleColor(0.5,0.5,0.5, 0.25,0.25,0.25)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
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
	-- Check Altfire
	elseif InputDown("grab", p) and canFire(p, ammo, data.clipamnt) then
		if data.coolDown < 0 then
			StopSound(data.firesound)

			local playervel = GetPlayerVelocity(p)

			if data.suppressed == false then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
					ServerCall("server.secondaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					ejectBrass(p, CASING_ORG, Vec(0.6, 0.2, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
				else
					data.firesound = PlaySound(LoadSound(NONCLIENTPRIM_FIRESOUND), mt.pos, 300)
				end

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
					ParticleColor(1,0.35,0, 1,0,0)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			else
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(SUPPRIM_FIRESOUND), mt.pos, 20)
					ServerCall("server.secondaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					ejectBrass(p, CASING_ORG, Vec(0.6, 0.2, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
				else
					data.firesound = PlaySound(LoadSound(SUPNONCLIENTPRIM_FIRESOUND), mt.pos, 20)
				end

				-- muzzleflash
				for i=0, 2 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.08, 0.12), 0.2)
					ParticleAlpha(0.75, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleCollide(0)
					ParticleColor(0.5,0.5,0.5, 0.25,0.25,0.25)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			end
			
			data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
			
			data.clipamnt = data.clipamnt - 1
			if data.clipamnt > 0 then
				data.coolDown = ALTFIRERATE
			elseif ammo > 1 then
				PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
				data.coolDown = RELOAD_TIME
				data.inreload = true
			end
			
			data.recoil = RECOIL_AMNT
		end
	-- Check Tertiaryfire
	elseif InputPressed("mmb", p) and GetPlayerCanUseTool(p) == true then
		if data.tertiaryCoolDown < 0 then
			data.tertiaryCoolDown = 0.5
			data.suppressed = not data.suppressed
			client.suppress(p, data.suppressed)
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.tertiaryCoolDown = data.tertiaryCoolDown - dt
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

		-- QUATEULER: (x, y, z) X is tilting barrel upwards, Y tilts it left/right, Z rotates it
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 66, recoil * -5, recoil * -3))
	end
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -15 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 15 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawPIST9MM()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end