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
local AIRRESISTMULT = 0.99


function server.initTags()
	server.tagsRecieved = true

	server.playerThrew = tonumber(GetTagValue(grenBody, "playerThrew"))

	server.grenType = GetTagValue(grenBody, "grenType") -- specific properties
	server.grenStyle = GetTagValue(grenBody, "grenStyle") -- general properties

	if server.grenType == "frag" or server.grenType == "m203" then
		server.gravMult = 0.51 -- half-life 1's gravity is 800 (HU?) which is around 20MS, TD's is 10 so 1/2 20 = 10
	else
		server.gravMult = 1.0
	end

	if server.grenStyle == "timed" then
		local timer = tonumber(GetTagValue(grenBody, "timer"))
		server.explTimer = timer
	end

	DebugWatch("explTimer", server.explTimer)
	DebugWatch("gravMult", server.gravMult)
	DebugWatch("grenType", server.grenType)
	DebugWatch("grenStyle", server.grenStyle)
end

function server.init()
	grenBody = FindBody(BODYTAG)

	server.thinkTime = THINKTIME

	server.shouldExplode = false
	server.exploded = false
	server.tagsRecieved = false
end

function server.explode(pos, grenType)
	if grenType == "frag" then
		Explosion(pos, 1.0)
	elseif grenType == "m203" then
		Explosion(pos, 1.0)
	elseif grentype == "satchel" then
		Explosion(pos, 2.0)
	elseif grentype == "mine" then
		Explosion(pos, 2.0)
	end
end

function server.think(dt)
	local pos = GetBodyTransform(grenBody).pos
	local grenVel = GetBodyVelocity(grenBody)

	if server.shouldExplode == true then
		server.explode(pos, server.grenType)
		server.exploded = true
		return
	end

	server.thinkTime = THINKTIME
	
	--SetBodyVelocity(grenBody, VecScale(grenVel, AIRRESISTMULT))
	--server.gravMult = server.gravMult * 1.011
end

function server.tick(dt)
	if server.exploded == true then
		Delete(grenBody)
		return
	end

	if server.tagsRecieved == false then
		if HasTag(grenBody, "grenStyle") then
			server.initTags()
			return
		else
			return -- haven't received tags yet
		end
	end

	if IsBodyBroken(grenBody) then
		server.explode(GetBodyTransform(grenBody).pos, server.grenType)
		server.exploded = true
		Delete(grenBody)
		return
	end

	local grenVel = GetBodyVelocity(grenBody)

	-- BEGIN DETONATION CHECKS
	if server.grenStyle == "timed" then -- decrease timer
		server.explTimer = server.explTimer - dt
		if server.explTimer < 0 then
			server.shouldExplode = true
		end
	elseif server.grenStyle == "impact" then -- check if impacting
		local grenspeed = VecLength(grenVel)
		QueryRejectBody(grenBody)
		QueryInclude("tool")
		QueryInclude("player")
		local pHit = QueryRaycast(GetBodyTransform(grenBody).pos, VecNormalize(grenVel), grenspeed * dt + 0.2, 0.33)
		if pHit or grenspeed <= 0.01 then
			server.shouldExplode = true
		end
	elseif server.grenStyle == "remote" then
		if HasTag(grenBody, "detonate") then
			server.shouldExplode = true 
		end
	end
	-- END DETONATION CHECKS

	-- think (check explode, apply air resist, friction etc etc)
	server.thinkTime = server.thinkTime - dt
	if server.thinkTime <= 0 then
		server.think(dt)
	end

	-- remove gravity
	local pvel = GetBodyVelocity(grenBody)
	local gravity = GetGravity()
	local newVel = VecAdd(pvel, VecScale(gravity, -dt))
	SetBodyVelocity(grenBody, newVel)

	-- add faked gravity
	local newgravity = VecScale(GetGravity(), server.gravMult)
	local finalVel = VecAdd(newVel, VecScale(newgravity, dt))
	SetBodyVelocity(grenBody, finalVel)
end