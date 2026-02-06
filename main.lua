#version 2

#include "script/mp5.lua"
#include "script/m727.lua"
#include "script/shotgun.lua"
#include "script/m40a1.lua"
#include "script/saw.lua"
#include "script/deagle.lua"
#include "script/python.lua"
#include "script/glock.lua"

#include "script/crowber.lua" -- :3
#include "script/wrench.lua"

-- this file calls all weapon functions. To add your weapon just add it's functions here (make sure to #include it).
-- To remove a weapon, remove it's lua file, xml file and function calls from this file

function server.init()
   server.initCRBR()
   server.initWRNCH()

   server.initMp5()
   server.initM727()
   server.initM40()
   server.initM249()
   server.initDE357()
   server.initPYTH()
   server.initPIST9MM()
   server.initSG()
end


function server.tick(dt)
   server.tickCRBR(dt)
   server.tickWRNCH(dt)

   server.tickMp5(dt)
   server.tickM727(dt)
   server.tickM40(dt)
   server.tickM249(dt)
   server.tickDE357(dt)
   server.tickPYTH(dt)
   server.tickPIST9MM(dt)
   server.tickSG(dt)
end


function server.tickPlayer(p, dt)
   server.tickPlayerCRBR(p, dt)
   server.tickPlayerWRNCH(p, dt)

   server.tickPlayerMp5(p, dt)
   server.tickPlayerM727(p, dt)
   server.tickPlayerM40(p, dt)
   server.tickPlayerM249(p, dt)
   server.tickPlayerDE357(p, dt)
   server.tickPlayerPYTH(p, dt)
   server.tickPlayerPIST9MM(p, dt)
   server.tickPlayerSG(p, dt)
end


function client.init()
   client.initCRBR()
   client.initWRNCH()

   client.initMp5()
   client.initM727()
   client.initM40()
   client.initM249()
   client.initDE357()
   client.initPYTH()
   client.initPIST9MM()
   client.initSG()
end


function client.tick(dt)
   client.tickCRBR(dt)
   client.tickWRNCH(dt)

   client.tickMp5(dt)
   client.tickM727(dt)
   client.tickM40(dt)
   client.tickM249(dt)
   client.tickDE357(dt)
   client.tickPYTH(dt)
   client.tickPIST9MM(dt)
   client.tickSG(dt)
end

function client.draw()
	if GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0 then
		return
	end
	client.drawM40()
	client.drawPIST9MM()
	client.drawDE357()
	client.drawM727()
	client.drawMp5()
	client.drawPYTH()
	client.drawM249()
	client.drawSG()
end

function client.tickPlayer(p, dt)
   client.tickPlayerCRBR(p, dt)
   client.tickPlayerWRNCH(p, dt)

   client.tickPlayerMp5(p, dt)
   client.tickPlayerM727(p, dt)
   client.tickPlayerM40(p, dt)
   client.tickPlayerM249(p, dt)
   client.tickPlayerDE357(p, dt)
   client.tickPlayerPYTH(p, dt)
   client.tickPlayerPIST9MM(p, dt)
   client.tickPlayerSG(p, dt)
end