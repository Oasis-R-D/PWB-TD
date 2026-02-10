#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"

--Return a random vector of desired length
function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function rnd(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

-- Returns true if the server is MP
-- use this for balancing or recreating features in weapons that are only in MP
function IsMP()
	return GetMaxPlayers() > 1
end

function client.drawAmmo(curclip, maxclip)
	if curclip == -16 then -- gun is empty
		return
	end
	
	UiPush()
		UiFont("bold.ttf", 32)
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.833))
		if curclip == -8 then
			UiText("RELOADING...")
		else
			UiText(curclip .. "/" .. maxclip)
		end
	UiPop()
end

function client.drawSecAmmo(curclip)
	if curclip == 0 then -- gun is empty
		return
	end
	
	UiPush()
		UiFont("bold.ttf", 32)
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.766))
		if curclip ~= -8 then
			UiText(curclip)
		end
	UiPop()
end

function client.BloodParticles(pos, dir, damage, playerhit)
	local impactsize = damage
	if impactsize > 0.4 then
		impactsize = 0.4
	end

	local playervel = GetPlayerVelocity(playerhit)

	for i=0, 3 do
		ParticleReset()
		ParticleType("smoke")
		ParticleRadius(impactsize)
		ParticleAlpha(10, 0)
		ParticleColor(0.4, 0.01, 0)
		ParticleCollide(0)
		SpawnParticle(pos, playervel, 0.5)
	end		
		
	for i=0, (impactsize * 50) do
		ParticleReset()
		ParticleGravity(rnd(-7, -10))
		ParticleRadius(rnd(0.01, 0.03))
		ParticleAlpha(1, 0, "easein") 
		ParticleColor(0.33, 0.01, 0)
		ParticleTile(6)
		ParticleDrag(0.0625)
		ParticleSticky(0.5)
		ParticleCollide(0, 1, "easein")
		ParticleRotation(0.2, 0)
		ParticleStretch(1, 0, "easein")
		SpawnParticle(pos, VecAdd(VecScale(VecAdd(dir, rndVec(1)), rnd(1, 4)), playervel), 3)
	end
end

function BloodVFX(pos, dir, damage, playerhit)
	ClientCall(0, "client.BloodParticles", pos, dir, damage, playerhit)

	local count = 1
	local noise = 0.1
	if damage < 0.1 then
		noise = 0.2;
		count = 3;
	elseif damage < 0.25 then
		noise = 0.35;
		count = 6;
	else
		noise = 0.45;
		count = 12;
	end

	for i=0, count do 
		local newdir = VecAdd(VecAdd(dir, rndVec(noise)), VecScale(GetGravity(), 0.01))
		local bloodhit, blooddist = QueryRaycast(pos, newdir, 5)
		if bloodhit ~= 0 then
			PaintRGBA(VecAdd(pos, VecScale(newdir, blooddist)), rnd(0.16, 0.33), 0.33, 0.01, 0.0, 1.0, rnd(0.66, 0.99))
		end
	end
	
	local newestdir = VecAdd(dir, VecScale(GetGravity(), 0.01))
	local bigbloodhit, bigblooddist = QueryRaycast(pos, newestdir, 3.75)
	if bigbloodhit ~= 0 then
		PaintRGBA(VecAdd(pos, VecScale(dir, bigblooddist)), 0.5, 0.33, 0.01, 0.0, 1.0, 0.66)
	end
end

-- hook the Shoot func to add rope damaging (would adding this to the actual function really be THAT hard???)
function ShootHook(pos, dir, shoottype, damage, playerdamage, range, player, weaponid, weaponname, times)
	times = times or 0
	newrange = range or 100 -- or is only here just because, not needed.
	playerdamage = playerdamage or 0

	local hit, dist, joint = QueryRaycastRope(pos, dir, range) -- Break Ropes
	if hit then
		local breakPoint = VecAdd(pos, VecScale(dir, dist))
		BreakRope(joint, breakPoint)
	end
	
	local _, pdist, _, playerhit = QueryShot(pos, dir, range, 0, player) -- Play player hit sound and create blud
	if playerhit == 0 then
		for i=0, times do
			Shoot(pos, dir, shoottype, damage, range, player, weaponid)
		end
		return
	end

	newrange = pdist - 0.5 -- don't actually hit the player so we can do our own damage and vfx
	for i=0, times do
		Shoot(pos, dir, shoottype, damage, newrange, player, weaponid)
	end
	ApplyPlayerDamage(playerhit, playerdamage, weaponname, player)

	local SoundPoint = VecAdd(pos, VecScale(dir, pdist))
	PlaySound(LoadSound("MOD/snd/bullet_hit0.ogg"), SoundPoint, 2)

	BloodVFX(SoundPoint, dir, playerdamage, playerhit)
end