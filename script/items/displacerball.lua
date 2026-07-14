#version 2

#include "script/include/player.lua"

--Return a random vector of desired length
function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function rnd(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

-- Per weapon constants
local BODYTAG = "opfordisplaceball"
local EXPLSIZE = 1.0
local WPNNAME = "Displacer Cannon"
local THINKTIME = 0.1 -- replicates Half-Life's thinking behavior
local BEAMDIST = 20

function getBodyCenter(body)
	local bmi, bma = GetBodyBounds(body)
	local bc = VecLerp(bmi, bma, 0.5)
	return bc
end

function server.initTags()
	server.tagsRecieved = true

	server.playerThrew = tonumber(GetTagValue(grenBody, "playerThrew"))

	server.properVel = VecSub(GetBodyVelocity(grenBody), VecScale(GetGravity(), server.runTime))
end

function server.init()
	grenBody = FindBody(BODYTAG)

	server.think = "nil"
	server.thinkTime = THINKTIME

	server.tagsRecieved = false

	server.runTime = 0.0
	
	server.hitPlayer = nil
	shared.deleted = false
end

function client.init()
	grenBody = FindBody(BODYTAG)
	portalSPR = LoadSprite("MOD/gfx/portal.png")
end

function server.Killthink()
	ClientCall(0, "client.explFX")

	-- "teleport" hit enemy BUGBUG: only removes them on host's client!
	if server.hitPlayer ~= nil then
		local bodyDisposal = Transform(Vec(9999))

		local playerAnimator = GetPlayerAnimator(server.hitPlayer)
		local playerBodies = GetEntityChildren(playerAnimator, '', false, 'body')

		for j = 1, #playerBodies do
			local body = playerBodies[j]

			SetBodyTransform(body, bodyDisposal)
		end

		server.hitPlayer = nil
	end

	server.think = "ExplodeThink"
	server.thinkTime = 0.2
end

function server.Explodethink(dt)
	local vecPos = getBodyCenter(grenBody)
	PlaySound(LoadSound("MOD/snd/displacer_teleport.ogg"), vecPos, 100)
	
	Paint(vecPos, 4.5, "explosion", 0.6)

	for i=0, 10 do MakeHole(vecPos, 3.0, 3.0, 3.0) end

	for id in Players() do
        local playerPos = TransformToParentPoint(GetPlayerTransform(id), Vec(0, 1))
		local dist = VecLength(VecSub(vecPos, playerPos))
		if dist <= 7.62 then
			QueryRejectBody(grenBody)
			local pHit = QueryRaycast(playerPos, VecNormalize(VecSub(vecPos, playerPos)), dist+0.1)
			if not pHit then
				dist = dist * 39.37
				local damage = 250
				local falloff = damage / 300 -- 7.62 meters in approx HU
				local flAdjustedDamage = damage - (dist * falloff)
				if flAdjustedDamage > 0 then ApplyPlayerDamage(id, flAdjustedDamage/100, WPNNAME, server.playerThrew) end
			end
		end
    end
	
	-- Delete and suck in objects
	local strength = 10.0	--Strength of blower
	local maxMass = 1048576	--The maximum mass for a body to be affected
	local maxDist = 12	--The maximum distance for bodies to be affected
	local mi = VecAdd(vecPos, Vec(-maxDist/2, -maxDist/2, -maxDist/2))
	local ma = VecAdd(vecPos, Vec(maxDist/2, maxDist/2, maxDist/2))
	QueryRequire("physical dynamic")
	local bodies = QueryAabbBodies(mi, ma)

	for i=1,#bodies do
		local b = bodies[i]

		--Compute body center point and distance
		local bmi, bma = GetBodyBounds(b)
		local bc = VecLerp(bmi, bma, 0.5)
		local dir = VecSub(vecPos, bc)
		local dist = VecLength(dir)
		
		--Get body mass
		local mass = GetBodyMass(b)

		if dist <= 2 and mass < 128 then
			Delete(b) -- "teleport" small objects when close
		else -- suck in nearby remaining objects
			dir = VecScale(dir, 1.0/dist)
			
			--Check if body should be affected
			if dist < maxDist and mass < maxMass then
				dir = VecNormalize(dir)
		
				--Compute how much velocity to add
				local massScale = 1 - math.min(mass/maxMass, 1.0)
				local distScale = 1 - math.min(dist/maxDist, 1.0)
				local add = VecScale(dir, strength * massScale * distScale)
				
				--Add velocity to body
				local vel = GetBodyVelocity(b)
				vel = VecAdd(vel, add)
				SetBodyVelocity(b, vel)
			end
		end
	end

	shared.deleted = true
	Delete(grenBody)
end

function server.tick(dt)
	if shared.deleted == true then return end

	server.runTime = server.runTime + dt

	if server.tagsRecieved == false then
		if server.playerThrew == nil then
			server.initTags()
			return
		else
			return -- haven't received tags yet
		end
	end

	local grenVel = GetBodyVelocity(grenBody)
	local grenPos = getBodyCenter(grenBody)

	-- BEGIN DETONATION CHECKS
	if server.think == "nil" then
		SetBodyVelocity(grenBody, server.properVel)

		QueryRejectBody(grenBody)
		QueryRejectPlayer(server.playerThrew)
		QueryInclude("player")

		local pHit = QueryShot(grenPos, VecNormalize(grenVel), 0.25, 0.2, server.playerThrew)
		if pHit then
			Paint(grenPos, 2.0, "explosion", 0.8)
			server.think = "KillThink"
			server.thinkTime = 0.2

			QueryRejectPlayer(server.playerThrew)
			QueryRequire("player")

			-- raycast again but for players because teardown sucks and hates me
			local pHit2, _, _, playerId = QueryShot(grenPos, VecNormalize(grenVel), 0.25, 1.0, server.playerThrew)
			if pHit2 then
				server.hitPlayer = playerId
				ApplyPlayerDamage(server.hitPlayer, 1.0, WPNNAME, server.playerThrew)
			end
		end
	else
		SetBodyVelocity(grenBody, Vec(0))
	end
	-- END DETONATION CHECKS

	server.thinkTime = server.thinkTime - dt
	if server.thinkTime <= 0 then
		if server.think == "KillThink" then
			server.Killthink()
		elseif server.think == "ExplodeThink" then
			server.Explodethink(dt)
		end
	end
end

function client.explFX()
	local pos = getBodyCenter(grenBody)

	ParticleReset()
	ParticleColor(0.09, 0.859, 0.176)
	ParticleEmissive(0.75)
	ParticleRadius(0.25)
	ParticleAlpha(1, 0, "easeout")
	ParticleTile(1)
	for a=0, math.pi*2, 0.049 do -- 64 times
		local x = math.cos(a)*1
		local y = 0.25
		local z = math.sin(a)*1
		local d = VecNormalize(Vec(x, y, z))
		local d2 = VecNormalize(Vec(x, 0, z))
		SpawnParticle(VecAdd(pos, d), VecScale(d2, 10), 0.5)
	end

	ParticleReset()
	ParticleColor(0.906, 0.549, 0.155)
	ParticleEmissive(1)
	ParticleRadius(0.33)
	ParticleAlpha(1, 0, "easeout")
	ParticleTile(1)
	for a=0, math.pi*2, 0.049 do -- 64 times
		local x = math.cos(a)*1
		local y = 0.0
		local z = math.sin(a)*1
		local d = VecNormalize(Vec(x, y, z))
		local d2 = VecNormalize(Vec(x, 0, z))
		SpawnParticle(VecAdd(pos, d), VecScale(d2, 10), 0.5)
	end

	ParticleReset()
	ParticleColor(0.09, 0.859, 0.176)
	ParticleEmissive(0.75)
	ParticleRadius(0.25)
	ParticleAlpha(1, 0, "easeout")
	ParticleTile(1)
	for a=0, math.pi*2, 0.049 do -- 64 times
		local x = math.cos(a)*1
		local y = -0.25
		local z = math.sin(a)*1
		local d = VecNormalize(Vec(x, y, z))
		local d2 = VecNormalize(Vec(x, 0, z))
		SpawnParticle(VecAdd(pos, d), VecScale(d2, 10), 0.5)
	end
end

function client.drawlaserDISP(vecSrc, vecDir, raycastDist)
	local t = Transform(VecLerp(vecSrc, VecAdd(vecSrc, VecScale(vecDir, raycastDist)), 0.5))

	local xAxis = VecNormalize(VecSub(VecAdd(vecSrc, VecScale(vecDir, raycastDist)), vecSrc))
	local zAxis = VecNormalize(VecSub(vecSrc, GetCameraTransform().pos))

	t.rot = QuatAlignXZ(xAxis, zAxis)

	DrawSprite(LoadSprite("MOD/gfx/egonBeam.png"), t, raycastDist, 0.33, 0.36, 0.5, 0.063, 1.0, true, true)
end

function client.UpdateEffect(source, endpos, vecDir, dist)
	--Draw laser line in ten segments with random offset -- NOTE: gluon gun actually does have something like this where the further you fire, the more the beam wanders
	local last = source
	for i=1, 20 do
		local tt = i/20 -- tf is a tt?
		local p = VecLerp(last, endpos, tt)
		p = VecAdd(p, rndVec(tt))
		DrawLine(last, p, 0.72, 1.0, 0.126)

		local length = VecLength(VecSub(last, p))
		client.drawlaserDISP(last, vecDir, length) -- to-do: figure out how to get direction from 2 vectors

		ParticleReset()
		ParticleGravity(0)
		ParticleRadius(rnd(0.15, 0.2), 0.35)
		ParticleAlpha(1, 0)
		ParticleTile(1)
		ParticleDrag(0)
		ParticleRotation(rnd(10, -10), 0)
		ParticleSticky(0)
		ParticleEmissive(5, 1)
		ParticleCollide(0)
		ParticleColor(0.36, 0.5, 0.063)
		SpawnParticle(last, Vec(), 0.125)

		last = p
	end
end

function client.tick(dt)
	if shared.deleted == true then return end
	local pos = getBodyCenter(grenBody)
	PointLight(pos, 0.36, 0.5, 0.063, 5)

	local t = Transform(pos)
	t.rot = GetCameraTransform().rot

	DrawSprite(portalSPR, t, 1.25, 1.25, 1.0, 1.0, 1.0, 1.0, true, true)

	local vecDir = GetRandomDirection()
	QueryRejectBody(grenBody)
	local hit, dist = QueryRaycast(pos, vecDir, BEAMDIST)
	if hit then
		local endpos = VecAdd(pos, VecScale(vecDir, dist))
		client.UpdateEffect(pos, endpos, vecDir, dist)
	end
end