-- copy this for the most basic melee with charge attack
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"


-- Per weapon constants
function createConstWRNCH()
    return {
		RECOIL_AMNT = 0.3,
		DAMAGE = 0.2,
		MAX_RANGE = 2.25,
		WPNID = "opforwrench",
		WPNNAME = "Pipe Wrench",
	}
end

-- Per weapon data and const storers
WRNCHplayers = {}
WRNCHconst = createConstWRNCH()

function createPlayerDataWRNCH()
    return {
		coolDown = 0.0,
		altCoolDown = 0.0,
		inAltAttack = false,
		altTime = nil,
		altSwingTime = nil,
		waitingforswing = false,
		recoil = 0.0,
		recoildelay = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
	}
end

function server.initWRNCH()
	RegisterTool(WRNCHconst.WPNID, WRNCHconst.WPNNAME, "MOD/prefab/wrench.xml", 1)
	SetToolAmmoPickupAmount(WRNCHconst.WPNID, 99999)
end

function server.tickWRNCH(dt)
	for p in PlayersAdded() do
		WRNCHplayers[p] = createPlayerDataWRNCH()
		SetToolEnabled(WRNCHconst.WPNID, true, p)
		SetToolAmmo(WRNCHconst.WPNID, 99999, p)
	end

	for p in PlayersRemoved() do
		WRNCHplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerWRNCH(p, dt)
	end
end

function server.swingWRNCH(m_pPlayer, dt) -- HL1 uses m_pPlayer (use it here for familiarity or whatever)
	local data = WRNCHplayers[m_pPlayer]
	
	local fDidHit = false
	
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	local _,pos,_,dir = GetPlayerAimInfo(vecSrc.pos, WRNCHconst.MAX_RANGE, m_pPlayer)

	local pHit, pDist, pHitWorld, pHitPlayer, _, pNorm = QueryShot(pos, dir, WRNCHconst.MAX_RANGE, 0.33, m_pPlayer)
	
	if pHit == false then
		-- Miss
		ClientCall(0, "client.swingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, false, false)
		data.coolDown = 0.75
		data.altCoolDown = 0.75
	else
		-- Hit
		fDidHit = true
		
		-- PLAYER DAMAGE
		local SoundPoint = VecAdd(pos, VecScale(dir, pDist))
		if pHitPlayer ~= 0 then
			ApplyPlayerDamage(pHitPlayer, WRNCHconst.DAMAGE, "tool", m_pPlayer)
		elseif pHitWorld ~= 0 then
			ShootHook(SoundPoint, VecScale(pNorm, -1), "bullet", 0.1, WRNCHconst.MAX_RANGE, m_pPlayer, WRNCHconst.WPNID, 5) -- push objects, "dent" metal
			MakeHole(SoundPoint, 0.9, 0.15, 0) -- stronger than sledge
		end
		
		-- PLAYER DAMAGE END
		data.recoil = 0.1 -- more hit feedback and randomness
		data.coolDown = 0.5
		data.altCoolDown = 0.5
		
		ClientCall(0, "client.swingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, pHitPlayer, pHitWorld)
	end
	
	return fDidHit
end

function client.swingWRNCH(m_pPlayer, dt, hit, pos, pHitPlayer, pHitWorld)
	local data = WRNCHplayers[m_pPlayer]
	vecSrc = GetPlayerEyeTransform(m_pPlayer)
	data.toolAnimator.timeSinceFire = 0.0
	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/WRNCH_miss0.ogg"), vecSrc.pos, 0.5)
		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing but further in
		data.coolDown = 0.75
		data.altCoolDown = 0.75
	else
		if pHitPlayer ~= 0 then
			PlaySound(LoadSound("MOD/snd/WRNCH_hitplayer0.ogg"), pos, 0.5)
		elseif pHitWorld ~= 0 then
			PlaySound(LoadSound("MOD/snd/WRNCH_hit0.ogg"), pos, 0.25)
		end
		
		data.recoildelay = 0.1 -- more hit feedback and randomness -- TO-DO: delay this
		data.coolDown = 0.5
		data.altCoolDown = 0.5
		
		data.toolAnimator.maxActionPoseTime = 0.05 -- stop midswing
	end
end

function server.bigSwingWRNCH(m_pPlayer, dt, heldtime) -- HL1 uses m_pPlayer (use it here for familiarity or whatever)
	local data = WRNCHplayers[m_pPlayer]
	
	local fDidHit = false
	
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	local _,pos,_,dir = GetPlayerAimInfo(vecSrc.pos, WRNCHconst.MAX_RANGE, m_pPlayer)

	local pHit, pDist, pHitWorld, pHitPlayer, _, pNorm = QueryShot(pos, dir, WRNCHconst.MAX_RANGE, 0.33, m_pPlayer)
	
	data.inAltAttack = false
	data.altTime = nil
	if pHit == false then
		-- Miss
		ClientCall(0, "client.bigSwingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, false, false)
		data.coolDown = 1
		data.altCoolDown = 1
	else
		-- Hit
		fDidHit = true
		
		-- PLAYER DAMAGE
		local SoundPoint = VecAdd(pos, VecScale(dir, pDist))
		if pHitPlayer ~= 0 then
			local damage = (heldtime * (WRNCHconst.DAMAGE*100) + 25)/100 -- have to convert to a 100 point health system to use the original game's math
			DebugWatch("damage", damage)
			ApplyPlayerDamage(pHitPlayer, damage, "tool", m_pPlayer)
		elseif pHitWorld ~= 0 then
			ShootHook(SoundPoint, VecScale(pNorm, -1), "bullet", 0.1, WRNCHconst.MAX_RANGE, m_pPlayer, WRNCHconst.WPNID, 5) -- push objects, "dent" metal
			MakeHole(SoundPoint, 1, 0.2, 0) -- stronger than sledge
		end
		
		-- PLAYER DAMAGE END
		data.recoil = 0.1 -- more hit feedback and randomness
		data.coolDown = 0.75
		data.altCoolDown = 0.75
		
		ClientCall(0, "client.bigSwingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, pHitPlayer, pHitWorld)
	end
	
	return fDidHit
end

function client.bigSwingWRNCH(m_pPlayer, dt, hit, pos, pHitPlayer, pHitWorld)
	local data = WRNCHplayers[m_pPlayer]
	vecSrc = GetPlayerEyeTransform(m_pPlayer)
	data.toolAnimator.timeSinceFire = 0.0
	data.toolAnimator.forceSecondaryActionPose = false
	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/WRNCH_bigmiss.ogg"), vecSrc.pos, 0.5)
		data.toolAnimator.maxActionPoseTime = 0.15 -- stop midswing but further in
		data.coolDown = 1
		data.altCoolDown = 1
	else
		if pHitPlayer ~= 0 then
			PlaySound(LoadSound("MOD/snd/WRNCH_bighitplayer0.ogg"), pos, 0.5)
		elseif pHitWorld ~= 0 then
			PlaySound(LoadSound("MOD/snd/WRNCH_hit0.ogg"), pos, 0.5)
		end
		
		data.recoildelay = 0.1 -- more hit feedback and randomness -- TO-DO: delay this
		data.coolDown = 0.75
		data.altCoolDown = 0.75
		
		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing
	end
end

function server.tickPlayerWRNCH(p, dt)
	if GetPlayerTool(p) ~= WRNCHconst.WPNID then
		return
	end
	
	local data = WRNCHplayers[p]

	--Check if firing
	if InputDown("usetool", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 and data.inAltAttack == false then
		if data.coolDown < 0 then
			server.swingWRNCH(p, dt)
		end
	end
	
	if InputDown("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 and data.inAltAttack == false then
		if data.coolDown < 0 then
			data.inAltAttack = true
		end
	end
	
	if data.altTime ~= nil and data.inAltAttack == true then -- deplete timer and check if ready
		if data.waitingforswing == false then -- not waiting on swing
			data.altTime = data.altTime + dt -- increase timer for use in damage calc
			if data.altTime > 1 and not InputDown("grab", p) then -- swing start animation done (in opfor)
				data.altSwingTime = 0.1
				data.waitingforswing = true -- don't mess with altTime any more
			end
		end
	elseif data.inAltAttack == true then -- start timer
		data.altTime = 0
	end
	
	if data.altSwingTime ~= nil and data.inAltAttack == true then
		data.altSwingTime = data.altSwingTime - dt
		if data.waitingforswing == true and data.altSwingTime <= 0 then -- swing
			data.waitingforswing = false
			data.altSwingTime = nil
			data.inAltAttack = false
			server.bigSwingWRNCH(p, dt, data.altTime)
			data.altTime = nil
			
		end
	end
	
	data.coolDown = data.coolDown - dt
end

function client.initWRNCH()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WRNCHconst.WPNID, toolHaptic);
end

function client.tickWRNCH(dt)
	for p in PlayersAdded() do
		WRNCHplayers[p] = createPlayerDataWRNCH();
	end

	for p in PlayersRemoved() do
		WRNCHplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerWRNCH(p, dt)
	end
end

function client.tickPlayerWRNCH(p, dt)
	if GetPlayerTool(p) ~= WRNCHconst.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)

		local data = WRNCHplayers[p]

	--Check if firing
	if InputDown("usetool", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 and data.inAltAttack == false then
		if data.coolDown < 0 then
			data.recoildelay = 0.0 -- make the melee move up a little first
			data.toolAnimator.timeSinceFire = 0.0
		end
	end
	
	if InputDown("grab", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 and data.inAltAttack == false then
		if data.coolDown < 0 then
			data.inAltAttack = true
			data.toolAnimator.forceSecondaryActionPose = true
		end
	end
	
	if data.altTime ~= nil and data.inAltAttack == true then -- deplete timer and check if ready
		if data.waitingforswing == false then -- not waiting on swing
			data.altTime = data.altTime + dt -- increase timer for use in damage calc
			if data.altTime > 1 and not InputDown("grab", p) then -- swing start animation done (in opfor)
				data.altSwingTime = 0.1
				data.recoil = 0.1
				data.waitingforswing = true -- don't mess with altTime any more
			end
		end
	elseif data.inAltAttack == true then -- start timer
		data.altTime = 0
	end
	
	if data.altSwingTime ~= nil and data.inAltAttack == true then
		data.altSwingTime = data.altSwingTime - dt
		if data.waitingforswing == true and data.altSwingTime <= 0 then -- swing
			data.waitingforswing = false
			data.altSwingTime = nil
			data.inAltAttack = false
			data.altTime = nil
		end
	end
	
	-- Simulate coolDown as the server does
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoildelay ~= nil then 
		data.recoildelay = data.recoildelay - dt
		if data.recoildelay < 0 then
			data.recoil = 0.1
			data.recoildelay = nil
		end
	end

	if data.recoil > 0 then
		local recoil = math.max(0, data.recoil)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil * 1.2)
		
		local inversesiderecoil = rnd(0, 1)
		if inversesiderecoil > 0.5 then
			siderecoil = siderecoil * -1
		end

		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p, 6, true)
end