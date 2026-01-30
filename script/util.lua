-- use this for whatever, I do NOT care -PM09
#version 2

#include "script/include/player.lua"
#include "script/toolanimation.lua"

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
	UiPush()
		UiAlign("center")
		UiTranslate(UiCenter(), UiCenter())
		UiText(curclip .. "/" .. maxclip)
	UiPop()
end

-- hook the Shoot func to add rope damaging (would adding this to the actual function really be THAT hard???)
function ShootHook(pos, dir, shoottype, damage, range, player, weaponid, times)
	times = times or 0
	for i=0, times do
		Shoot(pos, dir, shoottype, damage, range, player, weaponid)
	end

	local hit, dist, joint = QueryRaycastRope(pos, dir, range)
	if hit then
		local breakPoint = VecAdd(pos, VecScale(dir, dist))
		BreakRope(joint, breakPoint)
	end
end