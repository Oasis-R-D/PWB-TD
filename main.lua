-- use this for whatever, I do NOT care -PM09
#version 2

#include "script/mp5.lua"
#include "script/shotgun.lua"
#include "script/m40a1.lua"
function server.init()
	server.initMp5()
	server.initM40()
	server.initSG()
end

function server.tick(dt)
	server.tickMp5(dt)
	server.tickM40(dt)
	server.tickSG(dt)
end

function server.tickPlayer(p, dt)
	server.tickPlayerMp5(p, dt)
	server.tickPlayerM40(p, dt)
	server.tickPlayerSG(p, dt)
end

function client.init()
	client.initMp5()
	server.initM40()
	client.initSG()
end

function client.tick(dt)
	client.tickMp5(dt)
	client.tickM40(dt)
	client.tickSG(dt)
end

function client.tickPlayer(p, dt)
	client.tickPlayerMp5(p, dt)
	client.tickPlayerM40(p, dt)
	client.tickPlayerSG(p, dt)
end
