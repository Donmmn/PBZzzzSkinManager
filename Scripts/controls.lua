-- Read once on startup. Key names are data, never executable Lua.
local json=require('json');local M={wardrobe_name='F10',shader_name='F5'}
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local root=assert(source:match('^(.*)/Scripts/[^/]+$'),'Cannot locate wardrobe controls')
local file=io.open(root..'/controls.json','rb')
if file then
    local value=json.decode(file:read('*a'));file:close()
    M.wardrobe_name=value.wardrobe_key or M.wardrobe_name
    M.shader_name=value.shader_key or M.shader_name
end
local function key(name)
    local n=type(name)=='string' and tonumber(name:match('^F(%d+)$'))
    assert(n and n>=1 and n<=12 and Key[name]~=nil,'Use F1-F12 in controls.json')
    return Key[name]
end
M.wardrobe_key=key(M.wardrobe_name);M.shader_key=key(M.shader_name)
assert(M.wardrobe_key~=M.shader_key,'Wardrobe and shader keys must differ')
return M
