-- copy this for the most basic mag loaded weapon (INCLUDES LASER)
#version 2

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
local LASERFIRERATE = 0.5 -- laser on
local ALTFIRERATE = 0.125
local DAMAGE = 0.5
local PLAYERDAMAGE = 0.34
local MAX_RANGE = 150.0
local WPNID = "opfordeagle"
local WPNNAME = "Desert Eagle"
local CASING_ORG = Vec(0.02, 0.2, 0.13)

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		clipamnt = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		laseron = false,
		laserrefresh = 0.0,
		dataReset = true,

		body = nil,
		slide = nil,
		slide_2pt = nil,
		slideTransform = nil,
		slideTransform_2pt = nil,
	}
end

local function createPlayerSERVERdata()
    return {
		laseron = false,
		firesound = nil,
		dataReset = true,
	}
end

function server.initDE357()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/deagle.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickDE357(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerSERVERdata()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		server.tickPlayerDE357(p, dt)
	end
end

function server.tickPlayerDE357(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerSERVERdata()
		end
		return
	end

	playerData[p].dataReset = false
end

function server.primaryFireDE357(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local data = playerData[p]
	
	local spread = 0.1
	if data.laseron == true then
		spread = 0.001
	end

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, spread, p)

	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFireDE357(p)
	local data = playerData[p]
	data.laseron = not data.laseron
end

function client.initDE357()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickDE357(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerDE357(p, dt)
	end
end

local SlideTime = nil

function client.tickPlayerDE357(p, dt)
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
		if data.clipamnt > 0.5 then
			data.coolDown = RELOAD_TIME
		else
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
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			local playervel = GetPlayerVelocity(p)

			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireDE357", p)
				PlayHaptic(shootHaptic, 1)

				client.SRC_PunchAxis(1, 4)

				SlideTime = 0

				-- shell ejection
				ejectBrass(p, CASING_ORG, Vec(0.6, 0.2, 0), "MOD/prefab/casing_50ae.xml", FSFX_BRASS)
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
			if data.clipamnt > 0.5 then
				if data.laseron == true then
					data.coolDown = LASERFIRERATE
				else
					data.coolDown = FIRERATE
				end
			elseif ammo > 1 then
				PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
				data.coolDown = RELOAD_TIME
				data.inreload = true
			end
			
			data.recoil = RECOIL_AMNT
		end
	-- Check Altfire
	elseif InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			if IsPlayerLocal(p) then
				ServerCall("server.secondaryFireDE357", p)
			end
			
			if data.laseron == false then
				PlaySound(LoadSound(LASERONSFX), mt.pos)
			else
				PlaySound(LoadSound(LASEROFFSFX), mt.pos)
			end
			data.coolDown = ALTFIRERATE
			data.laseron = not data.laseron
			data.laserrefresh = 0
		end
	end

	-- turn off when reloading (accurate to HL:OP4)
	if data.laseron == false or data.inreload then
		data.toolAnimator.forceActionPose = false
	else
		data.toolAnimator.forceActionPose = true
		if data.laserrefresh <= 0 then
			local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
			QueryInclude("player")
			local hit, dist = QueryRaycast(VecSub(pos, Vec(0.0, 0.15, 0.0)), dir, 100)
			local toolBody = GetToolBody(p)
			local playervel = VecScale(GetPlayerVelocity(p), dt)
			local transform = GetBodyTransform(toolBody)
			local laser_origin = TransformToParentPoint(transform, Vec(0.05, 0.05, -0.2))
			dist = dist - 0.1

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

				DrawLine(VecAdd(laser_origin, playervel), VecAdd(pos, VecScale(dir, dist)), 1.0, 0.1, 0.1, 0.25)

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
					SpawnParticle(laser_origin, playervel, 0.05)
				end
			end

			if isMP() then
				data.laserrefresh = 0.02
			else
				data.laserrefresh = 0.0
			end
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
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

		-- QUATEULER: (x, y, z) X is tilting barrel upwards, Y tilts it left/right, Z rotates it
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 75, recoil * -5, recoil * -5))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		--Animate Slide
		local GunBody = GetToolBody(p)
		if data.body ~= GunBody then
			data.body = GunBody
			-- Slide is the third shape in vox file. Remember original position in attachment frame
			local shapes = GetBodyShapes(GunBody)
			data.slide = shapes[2]
			data.slide_2pt = shapes[3]
			data.slideTransform = GetShapeLocalTransform(data.slide)
			data.slideTransform_2pt = GetShapeLocalTransform(data.slide_2pt)
		end
		if data.slide and SlideTime ~= nil then
			SlideTime = SlideTime + dt

			-- don't go over!
			if SlideTime > 0.25 then
				SlideTime = 0.25
			-- Lock open during reloads
			elseif SlideTime > 0.125 and data.inreload == true and data.coolDown > 0.63 then
				SlideTime = 0.125
			end

			-- Slide has returned
			if SlideTime >= 0.25 then
				SetShapeLocalTransform(data.slide, data.slideTransform) -- force back just in case
				SetShapeLocalTransform(data.slide_2pt, data.slideTransform_2pt) -- force back just in case
				SlideTime = nil
			else
				local TOffset = Transform(Vec(0, 0, 0.08 * math.sin(4 * math.pi * SlideTime)))
				local t = TransformToParentTransform(TOffset, data.slideTransform)
				local t_2pt = TransformToParentTransform(TOffset, data.slideTransform_2pt)

				
				SetShapeLocalTransform(data.slide, t)
				SetShapeLocalTransform(data.slide_2pt, t_2pt)
			end
		end
	end
end

function client.drawDE357()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end
