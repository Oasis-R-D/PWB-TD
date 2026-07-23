-- copy this for the most basic mag loaded weapon with alt fire
#version 2

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/hkr.ogg"
local ALT_FIRESOUND = "MOD/snd/hkgl.ogg"
local PRIM_FIRESOUND = "MOD/snd/hks0.ogg"
local CLIP_SIZE = 50
local PICKUP_SIZE = 50
local RECOIL_AMNT = 0.2
local FIRERATE = 0.1
local ALTFIRERATE = 1
local DAMAGE = 0.45
local PLAYERDAMAGE = 0.12
local MAX_RANGE = 100.0
local WPNID = "hl9mmar"
local WPNNAME = "9mmAR"
local CASING_ORG = Vec(0.02, 0.25, -0.25)	-- casing origin

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		clipamnt = CLIP_SIZE,
		m203amnt = 1,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		dataReset = true,
	}
end

local function createPlayerSERVERdata()
    return {
		firesound = nil,
	}
end

function server.initMP5()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/9mmar.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickMP5(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerMP5(p, dt)
	--end
end

function server.tickPlayerMP5(p, dt)
end

function server.primaryFireMP5(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local data = playerData[p]
	
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_3DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFireMP5(p)
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

function client.initMP5()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickMP5(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerMP5(p, dt)
	end
end

function client.tickPlayerMP5(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
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

	-- Start Reload
	if InputPressed("r", p) and data.inreload == false and data.clipamnt < CLIP_SIZE and ammo > 0.5 and data.clipamnt ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
		data.coolDown = RELOAD_TIME
		data.inreload = true
	-- Finish Reload
	elseif data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		if data.clipamnt <= 0 then data.m203amnt = 1 end
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt, data.coolDown) then
		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		local playervel = GetPlayerVelocity(p)

		if IsPlayerLocal(p) then
			ServerCall("server.primaryFireMP5", p)
			client.GS_PunchAxis(1, rnd(-2, 2))

			PlayHaptic(shootHaptic, 1)

			-- shell ejection
			ejectBrass(p, CASING_ORG, Vec(0, 0, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
		end
		
		muzzleFlash(mt.pos, 4)
			
		data.clipamnt = data.clipamnt - 1
		if data.clipamnt > 0 then
			data.coolDown = FIRERATE
		elseif ammo > 1 then
			PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
			data.coolDown = RELOAD_TIME
			data.inreload = true
		end
		
		data.recoil = RECOIL_AMNT
	-- Check Altfire
	elseif InputPressed("grab", p) and canFire(p, data.m203amnt, data.m203amnt, data.coolDown) then
		PointLight(mt.pos, 1, 0.7, 0.5, 3)
		if IsPlayerLocal(p) then
			ServerCall("server.secondaryFireMP5", p)
			client.GS_PunchAxis(1, 10)

			PlayHaptic(shootHaptic, 1)
		end
		
		local playervel = GetPlayerVelocity(p)
		local m203FlashPos = VecAdd(mt.pos, Vec(0, -0.25, 0))

		muzzleFlash(m203FlashPos, 5)

		data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
		
		data.recoil = 1.5 * RECOIL_AMNT
		
		data.coolDown = ALTFIRERATE
		data.m203amnt = data.m203amnt - 1
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
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)
end

function client.drawMP5()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
	client.drawSecAmmo(playerData[p].m203amnt)
end