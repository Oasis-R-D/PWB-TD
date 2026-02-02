-- copy this for the most basic melee
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"
#include "script/util.lua"


-- Per weapon constants
function createConstCRBR()
    return {
		RECOIL_AMNT = 0.3,
		DAMAGE = 10,
		MAX_RANGE = 2.0,
		WPNID = "hlcrowbar",
		WPNNAME = "Crowbar",
	}
end

-- Per weapon data and const storers
CRBRplayers = {}
CRBRconst = createConstCRBR()

function createPlayerDataCRBR()
    return {
		swingtime = nil,
		damagetime = nil,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
	}
end

function server.initCRBR()
	RegisterTool(CRBRconst.WPNID, CRBRconst.WPNNAME, "MOD/prefab/crowbar.xml", 1)
	SetToolAmmoPickupAmount(CRBRconst.WPNID, 99999)
end

function server.tickCRBR(dt)
	for p in PlayersAdded() do
		CRBRplayers[p] = createPlayerDataCRBR()
		SetToolEnabled(CRBRconst.WPNID, true, p)
		SetToolAmmo(CRBRconst.WPNID, 99999, p)
	end

	for p in PlayersRemoved() do
		CRBRplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerCRBR(p, dt)
	end
end

function swing(fFirst, m_pPlayer, dt, client)
	client = client or false -- so stuff can be not played on client
	local data = CRBRplayers[m_pPlayer]
	
	local fDidHit = false
	
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	local _,pos,_,dir = GetPlayerAimInfo(vecSrc.pos, CRBRconst.MAX_RANGE, m_pPlayer)
	pos = VecAdd(pos, VecScale(dir, 1))
	QueryInclude("player")
	local pHit, pDist = QueryRaycast(pos, dir, CRBRconst.MAX_RANGE)
	
	if pHit == false then
		if fFirst == true then
			-- Miss
			if client == true then
				PlaySound(LoadSound("MOD/snd/cbar_miss.ogg"), pos, 1)
			end
			data.coolDown = 0.5
		end
	else
		-- Hit
		fDidHit = true
		if clent == true and fFirst == false then
			data.toolAnimator.timeSinceFire = 2.5 -- pull the crowbar back
		end

		-- PLAYER DAMAGE

		if client == false then
			QueryRequire("player")
			QueryInclude("player")
			local playerHit, playerDist = QueryRaycast(pos, dir, CRBRconst.MAX_RANGE)
			local SoundPoint = VecAdd(pos, VecScale(dir, pDist))
			if playerHit == true then
				if fFirst == true then
					PlaySound(LoadSound("MOD/snd/crbr_hitplayer0.ogg"), SoundPoint, 1)
				end
			elseif fFirst == false then
				PlaySound(LoadSound("MOD/snd/crbr_hit0.ogg"), SoundPoint, 0.5)
				MakeHole(SoundPoint, 0.75, 0.16, 0)
			end
		end
		-- PLAYER DAMAGE END
		
		data.coolDown = 0.25
		data.damagetime = 0.2
	end
	
	return fDidHit
end

function server.tickPlayerCRBR(p, dt)
	if GetPlayerTool(p) ~= CRBRconst.WPNID then
		return
	end
	
	local data = CRBRplayers[p]

	--Check if firing
	if InputDown("usetool", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 then
		if data.coolDown < 0 then
			if swing(true, p, dt) == true then
				data.swingtime = 0.1 -- hit the object in 0.1 seconds
			end
		end
	end
	
	data.coolDown = data.coolDown - dt
	
	if data.swingtime ~= nil then
		data.swingtime = data.swingtime - dt
		if data.swingtime <= 0 then -- time to swing
			swing(false, p, dt)
			data.swingtime = nil
		end
	end
end

function client.initCRBR()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(CRBRconst.WPNID, toolHaptic);
end

function client.tickCRBR(dt)
	for p in PlayersAdded() do
		CRBRplayers[p] = createPlayerDataCRBR();
	end

	for p in PlayersRemoved() do
		CRBRplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerCRBR(p, dt)
	end
end

function client.tickPlayerCRBR(p, dt)
	if GetPlayerTool(p) ~= CRBRconst.WPNID then
		return
	end

	local pt = GetPlayerTransform(p)

		local data = CRBRplayers[p]

	--Check if firing
	if InputDown("usetool", p) and GetPlayerVehicle(p) == 0 and GetPlayerGrabShape(p) == 0 then
		if data.coolDown < 0 then
			if swing(true, p, dt, true) == true then
				data.swingtime = 0.1 -- hit the object in 0.1 seconds
			end
		end
	end
	
	-- Simulate coolDown as the server does
	-- but only use them for rotating barrel + recoil.
	data.coolDown = data.coolDown - dt
	
	if data.swingtime ~= nil then
		data.swingtime = data.swingtime - dt
		if data.swingtime <= 0 then -- time to swing
			swing(false, p, dt, true)
			data.swingtime = nil
		end
	end

	-- RECOIL
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
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)
end