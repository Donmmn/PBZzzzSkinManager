local profiles=require('profiles')
if not profiles.current then
    print('[PBZWardrobe] Core ready; install an authorized character pack and restart the game. No character hooks activated.\n')
    return
end
local appearance=require('appearance')
require('panel').init(profiles,appearance)
require('paint').init(profiles,appearance)
local ok,why=pcall(function()require('cinematics').init(profiles,appearance,require('panel'))end)
if not ok then print('[PBZCinema] Cinematics unavailable; wardrobe remains usable: '..tostring(why)..'\n')end
print('[PBZWardrobe] Core 2.4.5-F6; generic wardrobe, character shader and per-profile cinematics.\n')
