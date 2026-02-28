#version 2
--pm09

GLOBAL_HEADSHOTMULT = 2.0 -- 3.0 in the OG Half-Life

GLOBAL_1DEGREE = 0.00873
GLOBAL_2DEGREES = 0.01745
GLOBAL_3DEGREES = 0.02618
GLOBAL_4DEGREES = 0.03490
GLOBAL_5DEGREES = 0.04362
GLOBAL_6DEGREES = 0.05234
GLOBAL_7DEGREES = 0.06105
GLOBAL_8DEGREES = 0.06976
GLOBAL_9DEGREES = 0.07846
GLOBAL_10DEGREES = 0.08716
GLOBAL_15DEGREES = 0.13053
GLOBAL_20DEGREES = 0.17365

#include "script/mp5.lua"
#include "script/m727.lua"
#include "script/shotgun.lua"
#include "script/m40a1.lua"
#include "script/saw.lua"
#include "script/deagle.lua"
#include "script/python.lua"
#include "script/glock.lua"

-- MELEE
#include "script/melee/crowber.lua"
#include "script/melee/wrench.lua"

-- SPECIAL
#include "script/special/tau.lua"
#include "script/special/gluon.lua"
#include "script/special/displacer.lua"

-- ITEMS
#include "script/items/medkit.lua"
#include "script/items/grenade.lua"
#include "script/items/satchel.lua"
#include "script/items/tripmine.lua"

-- this file calls all weapon functions. To add your weapon just add it's functions here (make sure to #include it).

-- to make a mod using this base, choose a weapon below to copy, then copy it's xml and vox (or you can make a new one completely)
-- in the file, replace all instances of the weapons name (suffix on the functions) then add it's functions here
-- To remove unused weapons, remove it's lua file, xml file(s), vox, sounds and it's function calls from this file

-- Weapon order in the HUD is set by the order they are in the server.init

-- TO-DO: 
-- - Gluon gun circular beam
-- - Finish gluon gun and displacer model
-- - Displacer prongs

function server.init()
   -- MELEE
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

   -- SPECIALS
   server.initTAU()
   server.initGLU()
   server.initDISP()

   -- ITEMS
   server.initMED()
   server.initFRAG()
   server.initSATCH()
   server.initTRIP()
end


function server.tick(dt)
   -- MELEE
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

   -- SPECIALS
   server.tickTAU(dt)
   server.tickGLU(dt)
   server.tickDISP(dt)

   -- ITEMS
   server.tickMED(dt)
   server.tickFRAG(dt)
   server.tickSATCH(dt)
   server.tickTRIP(dt)
end

function client.init()
   -- MELEE
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

   -- SPECIALS
   client.initTAU()
   client.initGLU()
   client.initDISP()

   -- ITEMS
   client.initFRAG()
   client.initSATCH()
   client.initTRIP()
end


function client.tick(dt)
   -- MELEE
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

   -- SPECIALS
   client.tickTAU(dt)
   client.tickGLU(dt)
   client.tickDISP(dt)

   -- ITEMS
   client.tickFRAG(dt)
   client.tickSATCH(dt)
   client.tickTRIP(dt)
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