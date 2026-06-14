-- copy this for the most basic melee
#version 2

-- Per weapon constants
local RECOIL_AMNT = 0.3
local DAMAGE = 0.1
local MAX_RANGE = 2.25
local WPNID = "opforknife"
local WPNNAME = "Combat Knife"

-- Per weapon data storer
local playerData = {}

function createPlayerCLIENTdataKNFE()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		recoildelay = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
		dataReset = true,
	}
end

function createPlayerSERVERdataKNFE()
    return {
		coolDown = 0.0,
		dataReset = true,
	}
end

function server.initKNFE()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/knife.xml", 1)
	SetToolAmmoPickupAmount(WPNID, 99999)
end

function server.tickKNFE(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerSERVERdataKNFE()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 99999, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		server.tickPlayerKNFE(p, dt)
	end
end

function server.swingKNFE(m_pPlayer, dt) -- HL1 uses m_pPlayer (use it here for familiarity or whatever)
	local data = playerData[m_pPlayer]
	
	local fDidHit = false
	
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	local _,pos,_,dir = GetPlayerAimInfo(vecSrc.pos, MAX_RANGE, m_pPlayer)
	
	local pHit, pDist, pHitWorld, pHitPlayer, _, pNorm = QueryShot(pos, dir, MAX_RANGE, 0.33, m_pPlayer)
	
	if pHit == false then
		-- Miss
		ClientCall(0, "client.swingKNFE", m_pPlayer, dt, fDidHit, SoundPoint, false, false)
		data.coolDown = 0.5
	else
		-- Hit
		fDidHit = true
		
		local hitAnimator = GetBodyAnimator(GetShapeBody(pHitWorld))

		-- PLAYER DAMAGE
		local SoundPoint = VecAdd(pos, VecAdd(VecScale(dir, pDist), VecScale(pNorm, -0.33)))
		if pHitPlayer ~= 0 then
			ApplyPlayerDamage(pHitPlayer, DAMAGE, WPNNAME, m_pPlayer)
			BloodVFX(SoundPoint, dir, DAMAGE, pHitPlayer)
		elseif hitAnimator ~= 0 then
			pHitPlayer = 1
			BloodVFX(SoundPoint, dir, DAMAGE, nil, hitAnimator)
			
			ApplyBodyImpulse(GetShapeBody(pHitWorld), SoundPoint, VecScale(dir, 800 * 2))
		else
			PlayImpactSFX(pHitWorld, SoundPoint, pNorm, "m")

			ApplyBodyImpulse(GetShapeBody(pHitWorld), SoundPoint, VecScale(dir, 800 * 2))
			MakeHole(SoundPoint, 0.5, 0.05, 0) -- stronger than sledge
		end
		
		-- PLAYER DAMAGE END
		data.coolDown = 0.25
		
		ClientCall(0, "client.swingKNFE", m_pPlayer, dt, fDidHit, SoundPoint, pHitPlayer)
	end
	
	return fDidHit
end

function client.swingKNFE(m_pPlayer, dt, hit, pos, pHitPlayer)
	local data = playerData[m_pPlayer]
	vecSrc = GetPlayerEyeTransform(m_pPlayer)
	data.toolAnimator.timeSinceFire = 0.0
	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/knfe_miss0.ogg"), vecSrc.pos, 0.5)
		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing but further in
		data.coolDown = 0.5
	else
		if pHitPlayer ~= 0 then
			PlaySound(LoadSound("MOD/snd/knfe_hitplayer0.ogg"), pos, 0.5)
		else
			PlaySound(LoadSound("MOD/snd/knfe_hit0.ogg"), pos, 0.25)
		end
		data.recoildelay = 0.1 -- more hit feedback and randomness
		data.coolDown = 0.25
		
		data.toolAnimator.maxActionPoseTime = 0.05 -- stop midswing
	end
end

function server.tickPlayerKNFE(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 and playerData[p].dataReset == false then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerSERVERdataKNFE()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID and playerData[p].dataReset == false then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerSERVERdataKNFE()
		end
		return
	end
	
	local data = playerData[p]

	data.dataReset = false

	-- Check Fire
	if InputDown("usetool", p) and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			server.swingKNFE(p, dt)
		end
	end
	
	data.coolDown = data.coolDown - dt
end

function client.initKNFE()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickKNFE(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataKNFE();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerKNFE(p, dt)
	end
end

function client.tickPlayerKNFE(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataKNFE()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataKNFE()
		end
		return
	end

	local pt = GetPlayerTransform(p)

	local data = playerData[p]

	data.dataReset = false

	-- Check Fire
	if InputDown("usetool", p) and GetPlayerCanUseTool(p) == true then
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

	if data.recoil > -0.5 then
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