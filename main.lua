#version 2

-- Feel free to make mods using this base.
-- Most I ask is just including the base name (and maybe the logo) so it's easy to find weapons based on it (but mostly to fuel my ever expanding ego)
-- PM09

-- EXTERNAL CREDITS:
-- - VALVe
-- - GearBox Software
-- - Novena (gaussian spread code)

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

-- to make a mod using this base, choose a weapon below to copy, then copy it's xml, vox and lua file (or you can make new ones completely)
-- in the .LUA file, replace all instances of the weapons name (suffix on the functions, some variables) and then add it's functions here
-- To remove unused/unwanted weapons, remove it's lua file, xml file(s), vox, sounds and then it's function calls and #include from this file

-- Weapon order in the HUD is set by the order they are called in the server.init()

-- TO-DO: 
-- - Gluon gun circular beam
-- - Finish gluon gun and displacer model
-- - Displacer prongs
-- - figure out why blood doesn't work sometimes

function server.init()
   -- MELEE (SLOT 1)
   server.initCRBR()
   server.initWRNCH()

   -- SLOT 3
   server.initMp5()
   server.initM727()
   server.initDE357()
   server.initPYTH()
   server.initPIST9MM()
   server.initSG()

   -- SLOT 6
   server.initM40()
   server.initM249()

   -- SPECIALS (SLOT 6)
   server.initTAU()
   server.initGLU()
   server.initDISP()

   -- ITEMS (SLOT 5/NONE)
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

   -- debug
   if debugpos ~= nil then
      for i=2, #debugpos do
         DebugLine(debugpos[1], debugpos[i], 0.5, 0.0, 0.0)
      end
   end
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