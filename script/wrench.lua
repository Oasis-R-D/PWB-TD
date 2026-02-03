-- copy this for the most basic melee with charge attack
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"


-- Per weapon constants
function createConstWRNCH()
    return {
		RECOIL_AMNT = 0.3,
		DAMAGE = 10,
		MAX_RANGE = 2.0,
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
	pos = VecAdd(pos, VecScale(dir, 1))
	QueryInclude("player")
	local pHit, pDist = QueryRaycast(pos, dir, WRNCHconst.MAX_RANGE)
	
	if pHit == false then
		-- Miss
		ClientCall(0, "client.swingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, false)
		data.coolDown = 0.75
		data.altCoolDown = 0.75
	else
		-- Hit
		fDidHit = true
		
		-- PLAYER DAMAGE
		QueryRequire("player")
		QueryInclude("player")
		local playerHit, playerDist = QueryRaycast(pos, dir, WRNCHconst.MAX_RANGE)
		local SoundPoint = VecAdd(pos, VecScale(dir, pDist))
		if playerHit == true then
			Shoot(SoundPoint, dir, "bullet", 1.0, 1, m_pPlayer, WRNCHconst.WPNID) -- damage players
		else
			ShootHook(SoundPoint, dir, "bullet", 0.1, 1, m_pPlayer, WRNCHconst.WPNID, 5) -- push objects, "dent" metal
			MakeHole(SoundPoint, 0.9, 0.15, 0) -- stronger than sledge
		end
		
		-- PLAYER DAMAGE END
		data.recoil = 0.1 -- more hit feedback and randomness
		data.coolDown = 0.5
		data.altCoolDown = 0.5
		
		ClientCall(0, "client.swingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, playerHit)
	end
	
	return fDidHit
end

function client.swingWRNCH(m_pPlayer, dt, hit, pos, playerHit)
	local data = WRNCHplayers[m_pPlayer]
	vecSrc = GetPlayerEyeTransform(m_pPlayer)
	data.toolAnimator.timeSinceFire = 0.0
	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/WRNCH_miss0.ogg"), vecSrc.pos, 0.75)
		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing but further in
		data.coolDown = 0.75
		data.altCoolDown = 0.75
	else
		if playerHit == true then
			PlaySound(LoadSound("MOD/snd/WRNCH_hitplayer0.ogg"), pos, 0.75)
		else
			PlaySound(LoadSound("MOD/snd/WRNCH_hit0.ogg"), pos, 0.5)
		end
		
		data.recoildelay = 0.1 -- more hit feedback and randomness -- TO-DO: delay this
		data.coolDown = 0.5
		data.altCoolDown = 0.5
		
		data.toolAnimator.maxActionPoseTime = 0.05 -- stop midswing
	end
end

function server.bigSwingWRNCH(m_pPlayer, dt) -- HL1 uses m_pPlayer (use it here for familiarity or whatever)
	local data = WRNCHplayers[m_pPlayer]
	
	local fDidHit = false
	
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	local _,pos,_,dir = GetPlayerAimInfo(vecSrc.pos, WRNCHconst.MAX_RANGE, m_pPlayer)
	pos = VecAdd(pos, VecScale(dir, 1))
	QueryInclude("player")
	local pHit, pDist = QueryRaycast(pos, dir, WRNCHconst.MAX_RANGE)
	
	data.coolDown = 1
	data.altCoolDown = 1

	if pHit == false then
		-- Miss
		ClientCall(0, "client.bigSwingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, false)
	else
		-- Hit
		fDidHit = true
		
		-- PLAYER DAMAGE
		QueryRequire("player")
		QueryInclude("player")
		local playerHit, playerDist = QueryRaycast(pos, dir, WRNCHconst.MAX_RANGE)
		local SoundPoint = VecAdd(pos, VecScale(dir, pDist))
		if playerHit == true then
			Shoot(SoundPoint, dir, "bullet", 1.0, 1, m_pPlayer, WRNCHconst.WPNID) -- damage players
		else
			ShootHook(SoundPoint, dir, "bullet", 0.1, 1, m_pPlayer, WRNCHconst.WPNID, 5) -- push objects, "dent" metal
			MakeHole(SoundPoint, 0.9, 0.15, 0) -- stronger than sledge
		end
		
		-- PLAYER DAMAGE END
		
		ClientCall(0, "client.bigSwingWRNCH", m_pPlayer, dt, fDidHit, SoundPoint, playerHit)
	end
	
	return fDidHit
end

function client.bigSwingWRNCH(m_pPlayer, dt, hit, pos, playerHit)
	local data = WRNCHplayers[m_pPlayer]
	data.toolAnimator.timeSinceFire = 0.0
	data.coolDown = 1
	data.altCoolDown = 1

	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/cbar_miss.ogg"), pos, 1)
		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing but further in
	else
		if playerHit == true then
			PlaySound(LoadSound("MOD/snd/WRNCH_hitplayer0.ogg"), pos, 1)
		else
			PlaySound(LoadSound("MOD/snd/WRNCH_hit0.ogg"), pos, 0.5)
		end
		
		data.recoildelay = 0.1 -- more hit feedback and randomness -- TO-DO: delay this

		data.toolAnimator.maxActionPoseTime = 0.05 -- stop midswing
	end
end

function server.tickPlayerWRNCH(p, dt)
	if GetPlayerTool(p) ~= WRNCHconst.WPNID then
		return
	end
	
	local data = WRNCHplayers[p]

	--Check if firing
	if InputDown("usetool", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 then
		if data.coolDown < 0 then
			server.swingWRNCH(p, dt)
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
	if InputDown("usetool", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 then
		if data.coolDown < 0 then
			data.recoildelay = 0.0 -- make the melee move up a little first
			data.toolAnimator.timeSinceFire = 0.0
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