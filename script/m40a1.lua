-- copy this for the most basic scoped mag loaded weapon with slower empty reloads (INCLUDES SCOPE)
#version 2

-- Per weapon constants
local RELOAD_TIME = 2.32 -- seconds
local EMPTYRELOAD_TIME = 4.1 -- seconds
local TACRELOAD_SOUND = "MOD/snd/m40r.ogg"
local EMPTRELOAD_SOUND = "MOD/snd/m40rfll.ogg"
local PRIM_FIRESOUND = "MOD/snd/m40FR.ogg"
local ALT_FIRESOUND = "MOD/snd/m40scp.ogg"
local BOLT_CYCLE = "MOD/snd/m40bolt.ogg"
local CLIP_SIZE = 5.0
local PICKUP_SIZE = 15.0
local RECOIL_AMNT = 0.25
local FIRERATE = 2.0
local ALTFIRERATE = 0.5
local SCOPEFIREDELAY = 0.1
local DAMAGE = 0.6 -- x5
local PLAYERDAMAGE = 0.75 -- instakills in opfor
local MAX_RANGE = 500.0
local WPNID = "opform40a1"
local WPNNAME = "M40A1"
local CASING_ORG = Vec(0.02, 0.25, -0.1) -- casing origin

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		clipamnt = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		scoped = false,
		timetobolt = nil,
		playbolt = true,
		dataReset = true,
	}
end

function server.initM40()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/m40a1.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickM40(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerM40(p, dt)
	--end
end

function server.tickPlayerM40(p, dt)
end

function server.primaryFireM40(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0, p)

	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)

	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function client.initM40()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickM40(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerM40(p, dt)
	end
end

function client.tickPlayerM40(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		playerData[p].scoped = false
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
		if data.clipamnt > 0 then
			data.coolDown = RELOAD_TIME
			PlaySound(LoadSound(TACRELOAD_SOUND), mt.pos)
		else
			data.coolDown = EMPTYRELOAD_TIME
		end
		data.inreload = true
	-- Finish Reload
	elseif data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt) then
		if data.coolDown < 0 then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireM40", p)
				client.SRC_PunchAxis(1, 2)

				PlayHaptic(shootHaptic, 1)
			end
			
			local playervel = GetPlayerVelocity(p)

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
			data.timetobolt = 0.842
			data.clipamnt = data.clipamnt - 1
			if data.clipamnt > 0 then
				data.coolDown = FIRERATE
				data.altCoolDown = SCOPEFIREDELAY
				
			elseif ammo > 1 then
				data.recoil = 0.05
				PlaySound(LoadSound(EMPTRELOAD_SOUND), mt.pos)
				data.coolDown = EMPTYRELOAD_TIME
				data.inreload = true
			end
			
			data.recoil = RECOIL_AMNT
		end
	-- Check Altfire	
	elseif InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			if IsPlayerLocal(p) then
				PlaySound(LoadSound(ALT_FIRESOUND), mt.pos)
			end
			data.altCoolDown = ALTFIRERATE
			data.scoped = not data.scoped
		end
	end

	if data.scoped == false or data.clipamnt < 0 or ammo <= 0 then
		data.toolAnimator.forceSecondaryActionPose = false
	elseif data.scoped == true then
		data.toolAnimator.forceSecondaryActionPose = true
		if IsPlayerLocal(p) then SetCameraFov(18) end
	end
		
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	if data.timetobolt ~= nil then
		data.timetobolt = data.timetobolt - dt
		if data.timetobolt <= 0 and data.playbolt == true then
			if data.clipamnt > 0 then -- already plays bolt sfx in reload
				PlaySound(LoadSound(BOLT_CYCLE), mt.pos)
			end
			data.playbolt = false
			data.recoil = 0.05
		end
		if data.timetobolt <= -0.1 then
			if IsPlayerLocal(p) then
				ejectBrass(p, CASING_ORG, Vec(0, -0.85, 0), "MOD/prefab/casing_762.xml", FSFX_BRASS)
			end

			data.timetobolt = nil
			data.playbolt = true
			data.recoil = 0.025
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

		-- QUATEULER: (x, y, z) X is tilting barrel upwards, Y tilts it left/right, Z rotates it
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 20, recoil * -5, 0))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)
end

function client.drawM40()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	if playerData[p].scoped == true then
		UiPush()
			UiTranslate(UiCenter(), UiMiddle())
			UiAlign("center middle")
			UiImage("MOD/scope.png")
		UiPop()
	end

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end