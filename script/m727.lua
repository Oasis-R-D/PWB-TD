-- just copy the MP5 instead (also this has modified recoil to make the arm dislocation less noticeable)
#version 2

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/hkr.ogg"
local ALT_FIRESOUND = "MOD/snd/hkgl.ogg"
local PRIM_FIRESOUND = "MOD/snd/727_fr0.ogg"
local CLIP_SIZE = 50
local PICKUP_SIZE = 50
local RECOIL_AMNT = 0.185
local FIRERATE = 0.1
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 1
local CAMALTMOVETIME = (2 * math.pi) * (0.5 / ALTFIRERATE) -- Cam movement sine multiplier, ALTFIRERATE is how long until it's over
local DAMAGE = 0.45
local PLAYERDAMAGE = 0.12
local MAX_RANGE = 100.0
local WPNID = "hlm727"
local WPNNAME = "Colt M727"
local CASING_ORG = Vec(0.02, -0.05, 0.13)

-- Per weapon data storer
local playerData = {}

function createPlayerCLIENTdataM727()
    return {
		clipamnt = CLIP_SIZE,
		m203amnt = 1,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		camAltMove = false,
		dataReset = true,
	}
end

function createPlayerSERVERdataM727()
    return {
		firesound = nil,
	}
end

function server.initM727()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/m727.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickM727(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerSERVERdataM727()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerM727(p, dt)
	--end
end

function server.tickPlayerM727(p, dt)
end

function server.primaryFireM727(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local data = playerData[p]

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_3DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFireM727(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)

	pos = VecAdd(pos, VecScale(dir, 0.5))
	
	local GrenTrans = Transform(pos, QuatLookAt(Vec(), dir))
	local xml = "MOD/prefab/gren_m203.xml"
	grenade_ent = Spawn(xml, GrenTrans)
	SetTag(grenade_ent[2], "grenType", "m203")
	SetTag(grenade_ent[2], "grenStyle", "impact")
	SetTag(grenade_ent[2], "playerThrew", p)
	SetBodyVelocity(grenade_ent[2], VecScale(dir, 20.32))
	SetBodyAngularVelocity(grenade_ent[2], TransformToParentVec(mt, Vec(-rnd(2.54, 12.7), 0, 0)))

	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)
end

function client.initM727()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickM727(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataM727();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerM727(p, dt)
	end
end

local camSineTime = nil

function client.tickPlayerM727(p, dt)
if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataM727()
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
		if data.clipamnt <= 0 then data.m203amnt = 1 end
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt) then
		if data.coolDown < 0 then	
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			local playervel = GetPlayerVelocity(p)

			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireM727", p)
				camSineTime = 0
				camRandY = rnd(-7, 7)
				data.camAltMove = false
				PlayHaptic(shootHaptic, 1)

				-- shell ejection
				ejectBrass(p, CASING_ORG, Vec(0, 0, 0), "MOD/prefab/casing_556.xml", FSFX_BRASS)
			end
			
			-- muzzleflash
			for i=0, 3 do
				ParticleReset()
				ParticleGravity(0)
				ParticleRadius(rnd(0.1, 0.15), 0.33)
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
	-- Check Altfire
	elseif InputPressed("grab", p) and canFire(p, data.m203amnt, data.m203amnt) then
		if data.coolDown < 0 then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			if IsPlayerLocal(p) then
				ServerCall("server.secondaryFireM727", p)
				camSineTime = 0
				data.camAltMove = true
				PlayHaptic(shootHaptic, 1)
			end
			
			local toolBody = GetToolBody(p)
			local playervel = GetPlayerVelocity(p)
			local m203FlashPos = VecAdd(mt.pos, Vec(0.15, -0.2, 0))
			-- muzzleflash
			for i=0, 4 do
				ParticleReset()
				ParticleGravity(0)
				ParticleRadius(rnd(0.1, 0.15), 0.33)
				ParticleAlpha(1, 0)
				ParticleTile(5)
				ParticleDrag(0)
				ParticleRotation(rnd(10, -10), 0)
				ParticleSticky(0)
				ParticleEmissive(5, 1)
				ParticleCollide(0)
				ParticleColor(1,0.35,0, 1,0,0)
				SpawnParticle(m203FlashPos, playervel, 0.125)
			end
			
			data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
			
			data.recoil = 1.5 * RECOIL_AMNT
			
			data.coolDown = ALTFIRERATE
			data.m203amnt = data.m203amnt - 1
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoil > -0.5 then
		local recoil = math.max(0, data.recoil / 2)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil * 1.5)
		
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
			local balance = -15 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 10 -- how intense (y at the peak will not equal this though)

			local equation = nil
			if data.camAltMove == true then
				balance = -10
				amp = 800
				equation = amp * ((math.sin(CAMALTMOVETIME * x) * math.exp(balance * x)) * x)

				if equation >= 0 then
					local t = Transform(Vec(), QuatAxisAngle(Vec(1, 0, 0), equation))
					SetPlayerCameraOffsetTransform(t)
					camSineTime = camSineTime + dt
				else camSineTime = nil end
			else
				equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

				if equation >= 0 then
					local t = Transform(Vec(), QuatAxisAngle(Vec(camRandY, -1.0, 0), equation))
					SetPlayerCameraOffsetTransform(t)
					camSineTime = camSineTime + dt
				else camSineTime = nil end
			end
		end
	end
end

function client.drawM727()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
	client.drawSecAmmo(playerData[p].m203amnt)
end