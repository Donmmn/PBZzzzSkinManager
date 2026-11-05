-- Original appearance is applied on a fresh player, never by rebuilding the
-- active component's animation/cloth/physics in Lua. The earlier hot-restore
-- transaction caused a native GameThread access violation and is retired.
local M={}
function M.profile()
 return {schema=1,id='pbz_original',name='游戏原皮 / ORIGINAL',native_original=true,sort_order=-100000,
 slots={},paint={enabled=false},hide_original={enabled=false,native_cloth=false,component_names={},asset_roots={},asset_fragments={}}}
end
function M.isRestoring()return false end
-- Compatibility entry points for the existing cosmetic adapter. No UObject
-- snapshots or setters are needed: the game builds its own original character.
function M.capture()end
function M.rememberPart()end
return M
