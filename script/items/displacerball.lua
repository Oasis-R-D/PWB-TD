#version 2

#include "script/include/player.lua"

-- Per weapon constants
local COOKTIME = 3
local BODYTAG = "opfordisplaceball"
local EXPLSIZE = 1.0
local WPNNAME = "Displacer Cannon"
local THINKTIME = 0.1 -- replicates Half-Life's thinking behavior

function server.initTags()
	server.tagsRecieved = true

	server.playerThrew = tonumber(GetTagValue(grenBody, "playerThrew"))


	if server.grenStyle == "timed" then
		local timer = tonumber(GetTagValue(grenBody, "timer"))
		server.explTimer = timer
	end
end

function server.init()
	grenBody = FindBody(BODYTAG)

	server.thinkTime = THINKTIME

	server.shouldExplode = false
	server.exploded = false
	server.tagsRecieved = false

	server.runTime = 0.0
end

function client.init()
	LaserSPR = LoadSprite("gfx/laser.png")
end

function client.drawGrenlaser(vecSrc, vecDir, raycastDist)
	local t = Transform(VecLerp(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 0.5))

	local xAxis = VecNormalize(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecSrc))
	local zAxis = VecNormalize(VecSub(vecSrc, GetCameraTransform().pos))

	t.rot = QuatAlignXZ(xAxis, zAxis)

	DrawSprite(LaserSPR, t, raycastDist, 0.1, 0.0, 0.83, 0.77, 0.25, true, true)
end

function server.think(dt)
	local pos = GetBodyTransform(grenBody).pos

	if server.shouldExplode == true then
		Explosion(pos, 2.0)
		server.exploded = true
		return
	end

	server.thinkTime = THINKTIME
end

function server.tick(dt)
	server.runTime = server.runTime + dt
	
	if server.exploded == true then
		Delete(grenBody)
		return
	end

	if server.tagsRecieved == false then
		if server.playerThrew == nil then
			server.initTags()
			return
		else
			return -- haven't received tags yet
		end
	end

	local grenVel = GetBodyVelocity(grenBody)

	-- BEGIN DETONATION CHECKS

	local grenspeed = VecLength(grenVel)
	QueryRejectBody(grenBody)
	if server.runTime <= 1 then -- don't hit the player directly after firing
		QueryRejectPlayer(server.playerThrew)
	end
	QueryInclude("tool")
	QueryInclude("player")
	local pHit = QueryRaycast(GetBodyTransform(grenBody).pos, VecNormalize(grenVel), grenspeed * dt + 0.2, 0.33)
	if pHit or grenspeed <= 0.01 then
		server.shouldExplode = true
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
end

