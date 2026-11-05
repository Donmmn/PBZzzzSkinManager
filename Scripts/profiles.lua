local json=require('json')
local config=require('profile_config')
local M={byId={},list={},current=nil}
-- Locate the adapter from its file, independent of drive and launcher.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
M.root=assert(source:match('^(.*)/Scripts/[^/]+$'),'Cannot locate wardrobe root')
local pathsFile=assert(io.open(M.root..'/paths.json','rb'),'Missing installer-generated paths.json')
local paths=json.decode(pathsFile:read('*a'));pathsFile:close()
assert(type(paths.models_root)=='string' and not paths.models_root:find('["%%&|<>\r\n]'),'Invalid model root')
M.modelsRoot=paths.models_root:match('^%a:/') and paths.models_root or M.root..'/'..paths.models_root
local function read(path)
    local f=io.open(path,'rb');if not f then return nil end
    local value=f:read('*a');f:close();return value
end
function M.reload()
    local currentId=M.current and M.current.id
    local byId,list={},{}
    -- One narrow directory listing on explicit open/refresh. No world traversal.
    local request=assert(io.open(M.root..'/State/ModelsRoot.txt','wb'),'Cannot write model root request')
    request:write(M.modelsRoot..'\n');request:close()
    local listModels=assert(package.loadlib(M.root..'/Tools/PBZCinematicAudio.dll','wardrobe_list_models'))
    listModels()
    local folders=read(M.root..'/State/ModelFolders.txt') or ''
    for folder in folders:gmatch('[^\r\n]+') do
        if folder:match('^[a-z0-9_-]+$') then
            local raw=read(M.modelsRoot..'/'..folder..'/model.json')
            if raw then
                local ok,p=pcall(function() return config.normalize(json.decode(raw),folder,M.modelsRoot) end)
                if ok then byId[p.id]=p;if not p.weapon_only then table.insert(list,p) end
                else print('[PBZWardrobe] Rejected '..folder..': '..tostring(p)..'\n') end
            end
        end
    end
    local builtin=require('native_appearance').profile()
    assert(not byId[builtin.id],'Reserved original-skin ID used by a model pack')
    byId[builtin.id]=builtin;table.insert(list,1,builtin)
    table.sort(list,function(a,b)if a.native_original then return not b.native_original elseif b.native_original then return false else return config.less(a,b)end end)
    local fallback=config.defaultProfile(list)
    M.byId=byId;M.list=list
    local saved=read(M.root..'/selected.txt')
    local savedId=saved and saved:match('^([a-z0-9_-]+)')
    M.current=(currentId and byId[currentId]) or (savedId and byId[savedId]) or fallback
    print('[PBZWardrobe] Model directory read: '..#list..' profiles; selected='..(M.current and M.current.id or 'none')..'\n')
    return list
end
function M.save(id)
    assert(M.byId[id],'Unknown profile')
    local file,err=io.open(M.root..'/selected.txt','wb')
    if not file then error('Could not save selection: '..tostring(err)) end
    file:write(id..'\n');file:close()
end
M.reload()
return M
