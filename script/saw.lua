-- copy this for the most basic mag loaded weapon (INCLUDES PUSHBACK ON FIRE)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 3.8 -- seconds
local RELOAD_SOUND = "MOD/snd/m249r.ogg"
local PRIM_FIRESOUND = "MOD/snd/249_fr0.ogg"
local CLIP_SIZE = 50
local PICKUP_SIZE = 100
local RECOIL_AMNT = 0.2
local FIRERATE = 0.067 -- NO
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.15
local MAX_RANGE = 125.0
local WPNID = "opform249_saw"
local WPNNAME = "M249 SAW"
local CASING_ORG = Vec(0.02, 0.05, -0.05)

-- Per weapon data storer
M249players = {}

function createPlayerDataM249()
    return {
		clipamntM249 = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		alteject = false, -- M249 ejects both the belt bits and bullets (alternating between them in opfor tho)
		firesound = nil,	
	}
end

function server.initM249()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/saw.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickM249(dt)
	for p in PlayersAdded() do
		M249players[p] = createPlayerDataM249()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		M249players[p] = nil
	end

	for p in Players() do
		server.tickPlayerM249(p, dt)
	end
end

function server.tickPlayerM249(p, dt)
	if GetPlayerHealth(p) <= 0 then
		M249players[p] = createPlayerDataM249()
		return
	end
end

function server.primaryFireM249(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	if IsPlayerGrounded(p) and GetPlayerCrouch(p) < 0.1 then
		local playertrans = GetPlayerTransform(p)
		local playerdir = TransformToParentVec(playertrans, Vec(0, 0, 1))
		local newplayervel = VecScale(VecNormalize(playerdir), 1.5)
		SetPlayerVelocity(VecAdd(GetPlayerVelocity(p), newplayervel), p)
	end
	
	local ammo = GetToolAmmo(WPNID, p)
	local data = M249players[p]

	local crouch = GetPlayerCrouch(p)
	local pvel = GetPlayerVelocity(p)

	local spread = GLOBAL_4DEGREES -- assuming spread is a radian value and this is the diameter of the cone
	if crouch > 0.1 then
		spread = GLOBAL_2DEGREES
	end
	
	if not IsPlayerGrounded(p) or VecLength(pvel) > (GetPlayerWalkingSpeed() * 0.75) then
		spread = GLOBAL_10DEGREES
	end

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, spread, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initM249()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickM249(dt)
	for p in PlayersAdded() do
		M249players[p] = createPlayerDataM249();
	end

	for p in PlayersRemoved() do
		M249players[p] = nil
	end

	for p in Players() do
		client.tickPlayerM249(p, dt)
	end
end

clipamnt = 0
local camSineTime = nil

function client.tickPlayerM249(p, dt)
	if GetPlayerHealth(p) <= 0 then
		M249players[p] = createPlayerDataM249()
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
	
	local data = M249players[p]

	if InputPressed("r", p) and data.inreload == false and data.clipamntM249 < CLIP_SIZE and ammo > 0.5 and data.clipamntM249 ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		data.coolDown = RELOAD_TIME
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntM249 = CLIP_SIZE
		if data.clipamntM249 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntM249 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireM249", p)
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
					if data.alteject == true then -- this is unrealistic, it should eject BOTH at the same time but HLOPFOR works like this
						ParticleColor(0.8, 0.6, 0)
					else
						ParticleColor(0.5, 0.5, 0.5)
					end
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
                    SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
					
					data.alteject = not data.alteject

					-- muzzleflash
					for i=0, 3 do
						ParticleReset()
						ParticleGravity(0)
						ParticleRadius(rnd(0.12, 0.17), 0.33)
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
					
				data.clipamntM249 = data.clipamntM249 - 1
				if data.clipamntM249 > 0 then
					data.coolDown = FIRERATE
				elseif ammo > 1 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					data.coolDown = RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end
	
	if IsPlayerLocal(p) then -- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntM249
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
		else
			data.clipamntM727 = 0
			clipamnt = -16
		end
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
	
	local toolBody = GetToolBody(p)
	if toolBody ~= 0 then -- hide shells if low ammo
		local shapes = GetBodyShapes(toolBody)
		
		if data.clipamntM249 < 4.5 then -- four shots left
			-- hide third shell
			SetTag(shapes[3], "invisible")
		elseif HasTag(shapes[3], "invisible") == true then
			RemoveTag(shapes[3], "invisible")
		end
		
		if data.clipamntM249 < 2.5 then -- two shots left
			-- hide second shell
			SetTag(shapes[2], "invisible")
		elseif HasTag(shapes[2], "invisible") == true then
			RemoveTag(shapes[2], "invisible")
		end
		
		if data.clipamntM249 < 0.5 then -- empty mag
			-- hide first shell
			SetTag(shapes[1], "invisible")
		elseif HasTag(shapes[1], "invisible") == true then
			RemoveTag(shapes[1], "invisible")
		end
		
	end
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	-- CAMERA MOVEMENT
	if IsPlayerLocal(p) then
		if camSineTime ~= nil then
			local x = camSineTime
			local e = math.exp(1)
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 7.5 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawM249()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
end