#version 2

#include "script/include/player.lua"

-- Per weapon constants
local COOKTIME = 3
local BODYTAG = "hlgrenade"
local EXPLSIZE = 1.0

function server.init()
	grenBody = FindBody(BODYTAG)
	
	server.expltimer = 0

	local cookedTime = tonumber(GetTagValue(grenBody, "cooked_time"))
	if cookedTime ~= nil then
		server.expltimer = server.expltimer + tonumber(cookedTime)
	end

	exploded = false
end

function server.tick(dt)
	if exploded then
		return
	end
	
	if IsBodyBroken(grenBody) then
		Explosion(GetBodyTransform(grenBody).pos, EXPLSIZE)
		exploded = true
	end
	
	if server.expltimer < COOKTIME then
		server.expltimer = server.expltimer + dt
	else
		Explosion(GetBodyTransform(grenBody).pos, EXPLSIZE)
		exploded = true
	end
end

function client.init()
end

function client.tick(dt)
end