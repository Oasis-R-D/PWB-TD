-- copy this for the most basic tube loaded weapon with alt fire
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 0.8 -- seconds
local RELOAD_SOUND = "MOD/snd/sgreloadstart.ogg"
local PRIM_FIRESOUND = "MOD/snd/sbarrel.ogg"
local ALT_FIRESOUND = "MOD/snd/dbarrel.ogg"
local PUMP_SOUND = "MOD/snd/sgcock.ogg"
local CLIP_SIZE = 8
local PICKUP_SIZE = 12
local RECOIL_AMNT = 0.2
local FIRERATE = 0.75
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 1.5
local CAMALTMOVETIME = (2 * math.pi) * (0.5 / ALTFIRERATE) -- Cam movement sine multiplier, ALTFIRERATE is how long until it's over
local DAMAGE = 0.35
local PLAYERDAMAGE = 0.1
local MAX_RANGE = 60.0
local WPNID = "hlshotgun"
local WPNNAME = "Assault Shotgun"
local CASING_ORG = Vec(0.02, 0.1, 0.075)

-- Per weapon data storer
SGplayers = {}
	
function createPlayerDataSG()
    return {
		clipamntSG = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		pumptime = nil, -- time until pump sound is played (and animations if those are ever added)
		shellinserttime = nil,
		shellstoload = 0,
		shellstopump = 0.0,
		camAltMove = false,
	}
end

function server.initSG()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/shotgun.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickSG(dt)
	for p in PlayersAdded() do
		SGplayers[p] = createPlayerDataSG()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 125, p)
	end

	for p in PlayersRemoved() do
		SGplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerSG(p, dt)
	end
end

function server.tickPlayerSG(p, dt)
	if GetPlayerHealth(p) <= 0 then
		SGplayers[p] = createPlayerDataSG()
		return
	end
end

function server.primaryFireSG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)
	local data = SGplayers[p]

	for i=0, 5 do
		local pos, dir = getAimVector(mt.pos, MAX_RANGE, GLOBAL_10DEGREES, p)
		ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	end
	
	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireSG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	local ammo = GetToolAmmo(WPNID, p)
	local data = SGplayers[p]

	for i=0, 11 do
		local pos, dir = getAimVector(mt.pos, MAX_RANGE, GLOBAL_10DEGREES, p)
		ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	end
	
	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-2, p)
	end
end

function client.initSG()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickSG(dt)
	for p in PlayersAdded() do
		SGplayers[p] = createPlayerDataSG();
	end

	for p in PlayersRemoved() do
		SGplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerSG(p, dt)
	end
end

clipamnt = 0

function client.tickPlayerSG(p, dt)
	if GetPlayerHealth(p) <= 0 then
		SGplayers[p] = createPlayerDataSG()
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
	
	local data = SGplayers[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntSG < CLIP_SIZE and ammo > 0.5 and data.clipamntSG ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		local reloadtime = nil
		local shellsneedingloading = 8 - data.clipamntSG

		if shellsneedingloading > ammo then
			shellsneedingloading = ammo
		end

		if data.clipamntSG > 0 then
			reloadtime = RELOAD_TIME * shellsneedingloading
			data.shellstoload = shellsneedingloading
		else
			reloadtime = (RELOAD_TIME * shellsneedingloading) + 0.3
			data.pumptime = reloadtime - 0.25
			data.shellstoload = shellsneedingloading
		end

		data.coolDown = reloadtime
		data.altCoolDown = reloadtime
		data.shellinserttime = 0.8
		data.inreload = true
	end
	
	if data.inreload == true and data.coolDown < 0 then -- reload the clip
		data.inreload = false
		data.clipamntSG = CLIP_SIZE
		if data.clipamntSG > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntSG = ammo
		end
	end
				
	if InputDown("usetool", p) and ammo > 0.5 and data.clipamntSG > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then				
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireSG", p)
					camSineTime = 0
					data.camAltMove = false
				end

				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					data.shellstopump = 1.0
					
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
				end
					
				data.clipamntSG = data.clipamntSG - 1
				if data.clipamntSG > 0 then
					data.altCoolDown = FIRERATE
					data.coolDown = FIRERATE
					data.pumptime = FIRERATE - 0.25 -- 0.5
				elseif ammo > 1 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					local reloadtime = nil
					local shellsneedingloading = 8 - data.clipamntSG

					if shellsneedingloading > ammo then
						shellsneedingloading = ammo
					end

					reloadtime = (shellsneedingloading * RELOAD_TIME) + 0.3
					data.pumptime = reloadtime - 0.25
					data.shellstoload = shellsneedingloading
					data.coolDown = reloadtime
					data.altCoolDown = reloadtime
					data.shellinserttime = 0.8
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputDown("grab", p) and ammo >= 1 and data.clipamntSG > 1.5 and GetPlayerCanUseTool(p) == true then
			if data.altCoolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.secondaryFireSG", p)
					camSineTime = 0
					data.camAltMove = true
				end

				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					data.shellstopump = 2
					
					-- muzzleflash
					for i=0, 4 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.15, 0.2), 0.44)
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
				
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
				
				data.clipamntSG = data.clipamntSG - 2
				if data.clipamntSG > 0 then
					data.altCoolDown = ALTFIRERATE
					data.coolDown = ALTFIRERATE
					data.pumptime = ALTFIRERATE - 0.25
				elseif ammo > 1 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					local reloadtime = 0
					
					local shellsneedingloading = 8 - data.clipamntSG
					if shellsneedingloading > ammo then
						shellsneedingloading = ammo
					end

					reloadtime = (shellsneedingloading * RELOAD_TIME) + 0.3
					data.pumptime = reloadtime - 0.25
					data.shellstoload = shellsneedingloading
					data.coolDown = reloadtime
					data.altCoolDown = reloadtime
					data.shellinserttime = 0.8
					data.inreload = true
				end
				
				data.recoil = 1.5 * RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if IsPlayerLocal(p) then -- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntSG
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
		else
			data.clipamntM727 = 0
			clipamnt = -16
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- SHELL LOADING
	if data.shellinserttime == nil then
	else
		data.shellinserttime = data.shellinserttime - dt
		
		if data.shellinserttime < 0 and data.shellstoload >= 0.5 then
			PlaySound(LoadSound("MOD/snd/sgshellin0.ogg"), pt.pos)
			data.shellinserttime = 0.8
			data.shellstoload = data.shellstoload - 1
			data.recoil = 0.1
			--data.clipamntSG = data.clipamntSG + 1 -- TO-DO: reimplement
			--if data.clipamntSG > CLIP_SIZE then 
				--DebugPrint("SHELL LOADING IS FORKED")
		end
		
		if data.shellstoload <= 0 then
			data.shellinserttime = nil
		end
	end
	-- END SHELL LOADING
	
	-- PUMPING
	if data.pumptime == nil then
	else
		data.pumptime = data.pumptime - dt
	
		-- pump the gun
		if data.pumptime < 0 then
			PlaySound(LoadSound(PUMP_SOUND), pt.pos)
			data.pumptime = nil
			-- SHELL EJECT
			local toolBody = GetToolBody(p)
			if toolBody ~= 0 then 
				local transform = GetBodyTransform(toolBody)
				local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
				local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
				local playervel = GetPlayerVelocity(p)
				
				for i=1, data.shellstopump do
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.1, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
				end
			end
			-- SHELL EJECT END
		end
	end
	-- END PUMPING
	
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
			local balance = -30 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 1000-- how intense (y at the peak will not equal this though)

			local equation = nil
			if data.camAltMove == true then
				balance = -15
				amp = 1000
				equation = amp * ((math.sin(CAMALTMOVETIME * x) * e^(balance * x)) * x)
			else
				equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)
			end

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -0.75, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawSG()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
end