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