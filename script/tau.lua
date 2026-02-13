-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/tauFire.ogg"
local AFTERSHOCKSFX = "MOD/snd/tauElect0.ogg"
local PICKUP_SIZE = 20.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.2
local ALTFIRERATE = 0.2
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.12
local MAX_RANGE = 150.0
local WPNID = "hltau"
local WPNNAME = "Tau Cannon"

-- Per weapon data storer
TAUplayers = {}

function createPlayerDataTAU()
    return {
		coolDown = 0.0,
		altCoolDown = 0.0,
		inAltAttack = false,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		aftershocksfx = nil,
		chargedTime = nil,
		firesound = nil,
		angle = 0.0,
		angVel = 0.0,
		body = nil,
		barrel = nil,
		barrelTransform = nil,
	}
end

function server.initTAU()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/tau.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickTAU(dt)
	for p in PlayersAdded() do
		TAUplayers[p] = createPlayerDataTAU()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		TAUplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerTAU(p, dt)
	end
end

function server.tickPlayerTAU(p, dt)
	if GetPlayerHealth(p) <= 0 then
		TAUplayers[p] = createPlayerDataTAU()
	end
end

function getFullChargeTime()
	if isMP() then
		return 1.5
	end
	return 4
end

function server.shootbeam(vecOrigSrc, vecDir, flDamage, primary, p)
	local data = MP5players[p]
	
	local vecSrc = vecOrigSrc;
	local vecDest = VecAdd(vecSrc, VecScale(vecDir, 208))

	local pentIgnore = p
	--TraceResult tr, beam_tr
	local flMaxFrac = 1.0
	local nTotal = 0
	local fHasPunched = false
	local fFirstBeam = true
	local nMaxHits = 10

	while flDamage > 10 and nMaxHits > 0 do 
		nMaxHits = nMaxHits - 1

		local raycastHit, raycastDist, raycastShape, raycastPlayer, _, raycastNormal = QueryShot(vecSrc, vecDir, 208, 0, pentIgnore)
		DrawLine(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 1.0, 0.1, 0.1, 1)
		--DrawLine(vecSrc, vecDest, 0.0, 0.1, 1.0, 1)

		if not raycastHit then
			break
		end

		if fFirstBeam == true then
			--m_pPlayer->pev->effects |= EF_MUZZLEFLASH; -- already done in firing code
			fFirstBeam = false

			nTotal = nTotal + 26
		end

		if raycastPlayer ~= 0 then
			ApplyPlayerDamage(raycastPlayer, flDamage/100, WPNNAME, p)
			BloodVFX(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecDir, flDamage, raycastPlayer)
		end

		if raycastShape ~= 0 then -- hit the world, bounce and or penetrate
			local n = nil

			pentIgnore = nil -- able to hit the player again

			n = -1 * VecDot(raycastNormal, vecDir);

			if n < 0.5 then -- 60 degrees
				-- reflect
				local r = Vec()

				r = VecAdd(VecScale(raycastNormal, 2 * n), vecDir) -- probably not the right math
				flMaxFrac = flMaxFrac - ((1/208) * raycastDist)
				local oldVecDir = vecDir
				vecDir = r;
				vecSrc = VecAdd(VecAdd(vecSrc, VecScale(oldVecDir, raycastDist)), VecScale(vecDir, 0.2))
				vecDest = VecAdd(vecSrc, VecScale(vecDir, 208))

				-- small explosion here? (no idea how to do radius damage)
				MakeHole(vecSrc, 0.9, 0.5, 0.25)

				nTotal = nTotal + 34

				-- lose energy
				if n == 0 then
					n = 0.1
				end
				flDamage = flDamage * (1 - n);

			else -- penetrate
				nTotal = nTotal + 13

				-- limit it to one hole punch
				if fHasPunched == true then
					break
				end
				fHasPunched = true

				--- try punching through wall if secondary attack (primary is incapable of breaking through)
				if primary == false then
					local _, pencastDist = QueryShot(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 0.2)), vecDir, 208, 0, pentIgnore)
					if pencastDist >= 0.0625 then
						local pencast2Hit, pencast2Dist, pencast2Shape, pencast2Player, _, pencast2Normal = QueryShot(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 0.2)), VecScale(vecDir, -1), 208, 0, pentIgnore)
						local n = VecLength(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), VecAdd(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 0.2)), VecScale(VecScale(vecDir, -1), pencast2Dist))))

						if n < flDamage then
							if n == 0 then
								n = 1
							end
							flDamage = flDamage - n
							nTotal = nTotal + 21

							nTotal = nTotal + 53

							MakeHole(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 1.25, 0.75, 0.5) -- entry hole

							vecSrc = VecAdd(VecAdd(vecSrc, VecScale(vecDir, raycastDist + 0.2)), VecScale(VecScale(vecDir, -1), pencast2Dist), vecDir)

							MakeHole(vecSrc, 1.25, 0.75, 0.5) -- exit hole
						end
					else
						flDamage = 0
						MakeHole(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 1.25, 0.75, 0.5)
					end
				else
					flDamage = 0
					MakeHole(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 1.25, 0.75, 0.5)
				end
			end
		else
			vecSrc = VecAdd(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecDir)
			MakeHole(vecSrc, 1.25, 0.75, 0.5)
			--pentIgnore = ENT(pEntity->pev);
		end
	end
end

function server.startShootbeam(primary, p, chargetime)
	chargetime = chargetime or 0
	local data = MP5players[p]

	local flDamage = 0.0
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local _,vecSrc,_,vecAiming = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
	if primary == false then
		if chargetime > getFullChargeTime() then
			flDamage = 200
		else
			flDamage = 200 * (chargetime / getFullChargeTime())
		end
	else 
		-- fixed damage in primary
		flDamage = 20
	end
	server.shootbeam(vecSrc, vecAiming, flDamage, primary, p);
end

function client.initTAU()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	gaussLoop = LoadLoop("MOD/snd/tauCharge.ogg")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickTAU(dt)
	for p in PlayersAdded() do
		TAUplayers[p] = createPlayerDataTAU();
	end

	for p in PlayersRemoved() do
		TAUplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerTAU(p, dt)
	end
end

clipamnt = 0

function client.tickPlayerTAU(p, dt)
	if GetPlayerHealth(p) <= 0 then
		TAUplayers[p] = createPlayerDataTAU()
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
	
	local data = TAUplayers[p]

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.75, 0.0, 3)
				data.angVel = 1000
				StopSound(data.firesound)
				data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
				
				data.aftershocksfx = rnd(0.3, 0.8)
				if IsPlayerLocal(p) then
					ServerCall("server.startShootbeam", true, p)
				end
				
				local toolBody = GetToolBody(p)
				if toolBody ~= 0 then
					local playervel = GetPlayerVelocity(p)
					
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
						ParticleColor(1,1,1, 1,0.75,0)
						SpawnParticle(mt.pos, playervel, 0.125)
					end
				
				end
				
				data.coolDown = FIRERATE
				data.altCoolDown = FIRERATE

				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	if InputDown("grab", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
		if data.altCoolDown < 0 then
			data.inAltAttack = true
		end
	end

	if data.chargedTime ~= nil and data.inAltAttack == true then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- increase timer for use in damage calc
		
		local pitch = (data.chargedTime) * (150 / getFullChargeTime()) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100
		data.angVel = math.min(1500, data.angVel + (pitch * 20))
		PlayLoop(gaussLoop, mt.pos, 1, true, pitch)
		if (data.chargedTime > 0.5 and not InputDown("grab", p)) or data.chargedTime > 10 then -- swing start animation done (in opfor)
			StopSound(data.firesound)
			data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
			
			data.aftershocksfx = rnd(0.3, 0.8)
			if IsPlayerLocal(p) then
				ServerCall("server.startShootbeam", false, p, data.chargedTime)
			end

			data.recoil = 2 * RECOIL_AMNT
			data.chargedTime = nil
			data.inAltAttack = false
		end
	elseif data.inAltAttack == true then -- start timer
		data.chargedTime = 0
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	data.angle = data.angle + data.angVel*dt
	data.angVel = math.max(0, data.angVel - dt*1000)

	if data.aftershocksfx ~= nil then
		data.aftershocksfx = data.aftershocksfx - dt
		if data.aftershocksfx <= 0 then
			data.aftershocksfx = nil
			PlaySound(LoadSound(AFTERSHOCKSFX), mt.pos, 1)
		end
	end

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

	--Animate barrel around the attachment point
	local b = GetToolBody(p)
	local voxSize = 0.04
	local attach = Transform(Vec(0, 2.5*voxSize, 2.5*voxSize))
	if data.body ~= b then
		data.body = b
		-- Barrel is the second shape in vox file. Remember original position in attachment frame
		local shapes = GetBodyShapes(b)
		data.barrel = shapes[6]
		data.barrelTransform = TransformToLocalTransform(attach, GetShapeLocalTransform(data.barrel))
	end
	if data.barrel then
		attach.rot = QuatEuler(0, 0, -data.angle) -- negative to make it spin the right way
		t = TransformToParentTransform(attach, data.barrelTransform)
		SetShapeLocalTransform(data.barrel, t)
	end
end