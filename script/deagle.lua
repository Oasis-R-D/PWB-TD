-- copy this for the most basic mag loaded weapon (INCLUDES LASER)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/DeagR.ogg"
local PRIM_FIRESOUND = "MOD/snd/DeagFR.ogg"
local LASERONSFX = "MOD/snd/DeagLaser.ogg"
local LASEROFFSFX = "MOD/snd/DeagLaserOff.ogg"
local CLIP_SIZE = 7.0
local PICKUP_SIZE = 15.0
local RECOIL_AMNT = 0.25
local FIRERATE = 0.22 -- laser off
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local LASERFIRERATE = 0.5 -- laser on
local CAMLASERMOVETIME = (2 * math.pi) * (0.5 / LASERFIRERATE)
local ALTFIRERATE = 0.125
local DAMAGE = 0.5
local PLAYERDAMAGE = 0.34
local MAX_RANGE = 150.0
local WPNID = "opfordeagle"
local WPNNAME = "Desert Eagle"
local CASING_ORG = Vec(0.02, 0.25, 0.1)

-- Per weapon data storer
DE357players = {}

function createPlayerCLIENTdataDE357()
    return {
		clipamntDE357 = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		laseron = false,
		firesound = nil,
		laserrefresh = 0.0,
		dataReset = true,
	}
end

function server.initDE357()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/deagle.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickDE357(dt)
	for p in PlayersAdded() do
		DE357players[p] = createPlayerCLIENTdataDE357()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		DE357players[p] = nil
	end

	for p in Players() do
		server.tickPlayerDE357(p, dt)
	end
end

function server.tickPlayerDE357(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if DE357players[p].dataReset == false then
			DE357players[p] = createPlayerCLIENTdataDE357()
		end
		return
	end

	DE357players[p].dataReset = false
end

function server.primaryFireDE357(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)
	local data = DE357players[p]
	
	local spread = 0.1
	if data.laseron == true then
		spread = 0.001
	end

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, spread, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireDE357(p)
	local data = DE357players[p]
	data.laseron = not data.laseron
end

function client.initDE357()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickDE357(dt)
	for p in PlayersAdded() do
		DE357players[p] = createPlayerCLIENTdataDE357();
	end

	for p in PlayersRemoved() do
		DE357players[p] = nil
	end

	for p in Players() do
		client.tickPlayerDE357(p, dt)
	end
end

clipamnt = 0
local camSineTime = nil

function client.tickPlayerDE357(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if DE357players[p].dataReset == false then
			DE357players[p] = createPlayerCLIENTdataDE357()
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
	
	local data = DE357players[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	if InputPressed("r", p) and data.inreload == false and data.clipamntDE357 < CLIP_SIZE and ammo > 0.5 and data.clipamntDE357 ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		if data.clipamntDE357 > 0.5 then
			data.coolDown = RELOAD_TIME
			data.altCoolDown = RELOAD_TIME
		else
			data.coolDown = RELOAD_TIME
			data.altCoolDown = RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntDE357 = CLIP_SIZE
		if data.clipamntDE357 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntDE357 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireDE357", p)
					camSineTime = 0
				end

				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
					local playervel = GetPlayerVelocity(p)
					
					-- shell ejection
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.6, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
                    SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
					
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
					
				data.clipamntDE357 = data.clipamntDE357 - 1
				if data.clipamntDE357 > 0.5 then
					if data.laseron == true then
						data.coolDown = LASERFIRERATE
						data.altCoolDown = LASERFIRERATE
					else
						data.coolDown = FIRERATE
						data.altCoolDown = FIRERATE
					end
				elseif ammo > 1 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					data.coolDown = RELOAD_TIME
					data.altCoolDown = RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			if IsPlayerLocal(p) then
				ServerCall("server.secondaryFireDE357", p)
			end
			
			data.toolAnimator.forceActionPose = true
			if data.laseron == false then
				PlaySound(LoadSound(LASERONSFX), pt.pos)
			else
				PlaySound(LoadSound(LASEROFFSFX), pt.pos)
			end
			data.altCoolDown = ALTFIRERATE
			data.coolDown = ALTFIRERATE
			data.laseron = not data.laseron
			data.laserrefresh = 0
		end
	end

	-- turn off when reloading (accurate to HL:OP4)
	if data.laseron == false or data.inreload then
		data.toolAnimator.forceActionPose = false
	else
		if data.laserrefresh <= 0 then
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
			QueryInclude("player")
			local hit, dist = QueryRaycast(VecSub(pos, Vec(0.0, 0.15, 0.0)), dir, 100)
			local toolBody = GetToolBody(p)
			if toolBody ~= 0 then
				local playervel = GetPlayerVelocity(p)
				local transform = GetBodyTransform(toolBody)
				local laser_origin = TransformToParentPoint(transform, Vec(0.05, 0.05, -0.2))
				dist = dist - 0.1
				if IsPlayerLocal(p) then
					DrawLine(VecAdd(laser_origin, VecScale(playervel, dt)), VecAdd(pos, VecScale(dir, dist)), 1.0, 0.1, 0.1, 0.25)
				end
				if hit then
					local breakPoint = VecAdd(pos, VecScale(dir, dist))
					for i=0, 1 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(0.1)
						ParticleAlpha(0.75, 0)
						ParticleColor(1.0, 0.0, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5)
						ParticleCollide(0)
						SpawnParticle(breakPoint, playervel, 0.05)
					end
				end
				
				-- laser start point
				if IsPlayerLocal(p) then
					for i=0, 1 do
						local playervel = GetPlayerVelocity(p)
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(0.1)
						ParticleAlpha(0.75, 0)
						ParticleColor(1.0, 0.0, 0)
						ParticleTile(5)
						ParticleDrag(0)
						ParticleRotation(rnd(10, -10), 0)
						ParticleSticky(0)
						ParticleEmissive(5)
						ParticleCollide(0)
						SpawnParticle(laser_origin, playervel, 0.05)
					end
				end
			end

			if isMP() then
				data.laserrefresh = 0.02
			else
				data.laserrefresh = 0.0
			end
		end
	end
	
	-- TO-DO: add laser vfx
	if data.laseron == true then
		data.toolAnimator.timeSinceFire = 0.0 -- use force on instead?
	end

	if IsPlayerLocal(p) then -- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntDE357
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
	data.laserrefresh = data.laserrefresh - dt
	
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
			local balance = -15 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 25 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawDE357()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
end
