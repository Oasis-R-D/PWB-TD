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

-- hook the Shoot func to add rope damaging (would adding this to the actual function really be THAT hard???)
function ShootHook(pos, dir, shoottype, damage, range, player, weaponid, times)
	times = times or 0
	for i=0, times do
		Shoot(pos, dir, shoottype, damage, range, player, weaponid)
	end

	local hit, dist, joint = QueryRaycastRope(pos, dir, range) -- Break Ropes
	if hit then
		local breakPoint = VecAdd(pos, VecScale(dir, dist))
		BreakRope(joint, breakPoint)
	end
	
	local _, pdist, _, playerhit = QueryShot(pos, dir, range, 0, player) -- Play player hit sound (create blood mayhaps?)
	if playerhit == 0 then
		return
	end
	
	local SoundPoint = VecAdd(pos, VecScale(dir, pdist))
	PlaySound(LoadSound("MOD/snd/bullet_hit0.ogg"), SoundPoint, 2)
	
	-- BLOOD VFX
	for i=0, (times + math.random(0, 1)) do
		local newdir = VecAdd(dir, rndVec(0.125))
		local bloodhit, blooddist = QueryRaycast(SoundPoint, newdir, 4)
		if bloodhit ~= 0 then
			PaintRGBA(VecAdd(SoundPoint, VecScale(newdir, blooddist)), rnd(0.3, 0.75), 0.33, 0.01, 0.0, 1.0, rnd(0.4, 0.6))
		end
	end
	-- END BLOOD VFX
end