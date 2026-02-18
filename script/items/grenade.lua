-- copy this for the most basic mag loaded weapon (INCLUDES PUSHBACK ON FIRE)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/249_fr0.ogg"
local PICKUP_SIZE = 5
local RECOIL_AMNT = 0.075
local FIRERATE = 0.5
local EXPLSIZE = 2.0
local FUZESTART = 3.0
local WPNID = "hlgrenade"
local WPNNAME = "M1 Frag"

-- Per weapon data storer
FRAGplayers = {}

function createPlayerDataFRAG()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,	
	}
end

function server.initFRAG()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/grenade.xml", 5)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickFRAG(dt)
	for p in PlayersAdded() do
		FRAGplayers[p] = createPlayerDataFRAG()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		FRAGplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerFRAG(p, dt)
	end
end

function server.tickPlayerFRAG(p, dt)
	if GetPlayerHealth(p) <= 0 then
		FRAGplayers[p] = createPlayerDataFRAG()
		return
	end
end

function server.primaryFireFRAG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)
	local data = FRAGplayers[p]

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
	local pvel = GetPlayerVelocity(p)

	--ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initFRAG()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickFRAG(dt)
	for p in PlayersAdded() do
		FRAGplayers[p] = createPlayerDataFRAG();
	end

	for p in PlayersRemoved() do
		FRAGplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerFRAG(p, dt)
	end
end

function client.tickPlayerFRAG(p, dt)
	if GetPlayerHealth(p) <= 0 then
		FRAGplayers[p] = createPlayerDataFRAG()
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	
	local data = FRAGplayers[p]

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireFRAG", p)
				end

				data.coolDown = FIRERATE
				
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
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

		if ammo < 0.5 then -- no grenades
			-- hide grenade
			SetTag(shapes[0], "invisible")
		elseif HasTag(shapes[0], "invisible") == true then
			RemoveTag(shapes[0], "invisible")
		end
	end
	tickToolAnimator(data.toolAnimator, dt, nil, p)
end