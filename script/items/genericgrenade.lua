#version 2
-- GENERIC GRENADE, INCLUDES IMPACT GRENADE CODE AND TIMER GRENADE CODE
#include "script/include/player.lua"

-- Per weapon constants
local COOKTIME = 3
local BODYTAG = "hlgrenade"
local EXPLSIZE = 1.0
local IMPDMGTHRESH = 2.54 -- 100 inches to meters
local WPNNAME = "M1 Frag"
local THINKTIME = 0.1 -- replicates Half-Life's thinking behavior
local AIRRESISTMULT = 0.5



function server.init()
	grenBody = FindBody(BODYTAG)

	server.playerThrew = tonumber(GetTagValue(grenBody, "playerThrew"))

	server.grenType = GetTagValue(grenBody, "grenType")
	server.grenStyle = GetTagValue(grenBody, "grenStyle")
	server.gravMult = 0.5 -- imp and timer have 0.5

	server.explTimer = 0
	server.shouldExplode = false

	server.thinkTime = THINKTIME
	local timer = tonumber(GetTagValue(grenBody, "timer"))
	if timer ~= nil then
		server.explTimer = (timer)
	else
		server.explTimer = -1
	end

	server.exploded = false
end

function server.negateGravity(dt)
	local pvel = GetBodyVelocity(grenBody)
	local gravity = GetGravity()
	local newVel = VecAdd(pvel, VecScale(gravity, -dt))
	SetBodyVelocity(grenBody, newVel)
end

function server.explode(pos, grenType)
	if grenType == "frag" then
		Explosion(pos, 1.0)
	elseif greType == "m203" then
		Explosion(pos, 0.75)
	elseif grentype == "satchel" then
		Explosion(pos, 2.0)
	elseif grentype == "mine" then
		Explosion(pos, 2.0)
	end
end

function server.think(dt)
	if server.shouldExplode == true then
		server.explode(GetBodyTransform(grenBody).pos, server.grenType)
		server.exploded = true
		return
	end

	server.thinkTime = THINKTIME
	local grenVel = GetBodyVelocity(grenBody)
	SetBodyVelocity(grenBody, VecScale(grenVel, AIRRESISTMULT))

	pHit(queryShot())
	if 
end

function server.tick(dt)
	if server.exploded == true then
		Delete(grenBody)
		return
	end
	
	if IsBodyBroken(grenBody) then
		server.explode(GetBodyTransform(grenBody).pos, server.grenType)
		server.exploded = true
		Delete(grenBody)
		return
	end
	
	if server.explTimer ~= -1 and server.explTimer < COOKTIME then
		server.explTimer = server.explTimer + dt
	else
		server.shouldExplode = true
	end

	if server.grenStyle == "timed" and VecLength(GetBodyVelocity(grenBody)) >= IMPDMGTHRESH then -- stolen from throwing knife mod	
		local players = GetAllPlayers()
		for v=1, #players do 
			local playerID = players[v]
			local camtr = GetPlayerEyeTransform(playerID)
				
			if playerID ~= server.playerThrew and VecLength(VecSub(camtr.pos, GetBodyTransform(grenBody).pos)) < 1 then
				ApplyPlayerDamage(playerID, 0.01, WPNNAME, server.playerThrew) -- can't do blood here since util.lua cannot be included (for whatever fucking reason)
			end
		end		
	end

	-- remove gravity
	server.negateGravity(dt)

	-- think (check impact and explode, apply air resist, friction etc etc)
	server.thinkTime = server.thinkTime - dt
	if server.thinkTime <= 0 then
		server.think(dt)
	end

	local pvel = GetBodyVelocity(grenBody)
	local gravity = GetGravity()
	local newVel = VecAdd(pvel, VecScale(gravity, -dt))
	SetBodyVelocity(grenBody, newVel)
end