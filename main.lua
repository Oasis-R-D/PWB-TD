#version 2

-- EXTERNAL CREDITS:
-- - VALVe (Half-Life: 1)
-- - GearBox Software (Half-Life: Opposing Force)
-- - Novena (radial spread code)

-- - Verbatim Man (crossbow bolt uses code loosely based on his pellet launcher's code) NOTE: Crossbow is not added yet

----------------------------------------------------------------------------------------------

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

GLOBAL_WEAPONS = {
   "CRBR",
   "WRNCH",

   "Mp5",
   "M727",
   "DE357",
   "PYTH",
   "PIST9MM",
   "SG",

   "M40",
   "M249",

   "TAU",
   "GLU",
   "DISP",

   "FRAG",
   "SATCH",
   "TRIP",
}

GLOBAL_WEAPONS_AMNT = #GLOBAL_WEAPONS -- only calculate this once

----------------------------------------------------------------------------------------------

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

server.weaponTicks = {}
client.weaponTicks = {}

----------------------------------------------------------------------------------------------

-- this file calls all weapon functions.

-- to make a mod using this base, choose a weapon to base your weapon off of, then copy it's xml, vox and lua file (or you can make new ones completely)
-- in the .LUA file, replace all instances of the weapons name (suffix on the functions, some variables) and then add it's suffix here in the weapons list above
-- To remove unused/unwanted weapons, remove it's lua file, xml file(s), vox, sounds and then it's name in the weapons list and also its #include from this file

-- Weapon order in the HUD is set by the order they are written in the weapons list

----------------------------------------------------------------------------------------------

-- TO-DO: 
-- - Gluon gun circular beam
-- - Finish gluon gun and displacer model
-- - Displacer prongs
-- - displacer ball and other billboard sprites doesn't angle correctly when in vehicle camera
-- - make separate player data for server to reduce memory usage

----------------------------------------------------------------------------------------------

-- declare weapons, pickup amounts
function server.init()
   for i = 1, GLOBAL_WEAPONS_AMNT do
      _G.server["init" .. GLOBAL_WEAPONS[i]]()
      table.insert(server.weaponTicks, _G.server["tick" .. GLOBAL_WEAPONS[i]]) 
   end

   -- only on server!
   server.initMED()
end

function server.tick(dt)
   for i = 1, GLOBAL_WEAPONS_AMNT do
      server.weaponTicks[i](dt)
   end
end

-- mostly to load haptics, amongst other things
function client.init()
   for i = 1, GLOBAL_WEAPONS_AMNT do
      _G.client["init" .. GLOBAL_WEAPONS[i]]()
      table.insert(client.weaponTicks, _G.client["tick" .. GLOBAL_WEAPONS[i]]) 
   end
end

function client.tick(dt)
   for i = 1, GLOBAL_WEAPONS_AMNT do
      client.weaponTicks[i](dt)
   end
end

-- Draw the magazine amount hud
function client.draw()
	if GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0 then return end
   
	client.drawM40()
	client.drawPIST9MM()
	client.drawDE357()
	client.drawM727()
	client.drawMp5()
	client.drawPYTH()
	client.drawM249()
	client.drawSG()
end