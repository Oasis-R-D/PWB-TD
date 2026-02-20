#version 2

#include "script/include/player.lua"

-- Per weapon constants
local COOKTIME = 3
local BODYTAG = "hlgrenade"
local EXPLSIZE = 1.0
local GRAVMULT = 0.5
local IMPDMGTHRESH = 2.54 -- 100 inches to meters
local WPNNAME = "M1 Frag"
local THINKTIME = 0.1 -- replicates Half-Life's thinking behavior
local AIRRESISTMULT = 0.5

function server.init()
	grenBody = FindBody(BODYTAG)
	
	server.expltimer = 0
	server.shouldExplode = false

	server.thinkTime = THINKTIME
	local cookedTime = tonumber(GetTagValue(grenBody, "cooked_time"))
	if cookedTime ~= nil then
		server.expltimer = server.expltimer + tonumber(cookedTime)
	end

	exploded = false
end

function server.tick(dt)
	if exploded then
		Delete(grenBody)
		return
	end
	
	if IsBodyBroken(grenBody) then
		Explosion(GetBodyTransform(grenBody).pos, EXPLSIZE)
		exploded = true
		return
	end
	
	if server.expltimer < COOKTIME then
		server.expltimer = server.expltimer + dt
	else
		server.shouldExplode = true
	end

	if VecLength(GetBodyVelocity(grenBody)) >= IMPDMGTHRESH then -- stolen from throwing knife mod
		local playerThrew = GetTagValue(grenBody, "playerThrew")
		playerThrew = tonumber(playerThrew)
		
		local players = GetAllPlayers()
		for v=1, #players do 
			local playerID = players[v]
			local camtr = GetPlayerEyeTransform(playerID)
				
			if playerID ~= playerThrew and VecLength(VecSub(camtr.pos, GetBodyTransform(grenBody).pos)) < 1 then
				ApplyPlayerDamage(playerID, 0.01, WPNNAME, playerThrew) -- can't do blood here since util.lua cannot be included (for whatever fucking reason)
			end
		end		
	end

	-- apply faked air resistance
	server.thinkTime = server.thinkTime - dt

	if server.thinkTime <= 0 then
		if server.shouldExplode == true then
			Explosion(GetBodyTransform(grenBody).pos, EXPLSIZE)
			exploded = true
			return
		end

		server.thinkTime = THINKTIME
		local grenVel = GetBodyVelocity(grenBody)
		SetBodyVelocity(grenBody, VecScale(grenVel, AIRRESISTMULT))
	end

	-- apply gravity multiplier
	local pvel = GetBodyVelocity(grenBody)
	local gravity = GetGravity()
	local newVel = VecAdd(pvel, VecScale(gravity, -dt * GRAVMULT))
	SetBodyVelocity(grenBody, newVel)


end