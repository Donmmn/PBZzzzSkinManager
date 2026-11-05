-- Generic, per-profile cinematics. Event-only detection; finite media transactions.
local json=require('json');local contract=require('cinematic_config')
local M={};local profiles,appearance,panel,context,jobs,session,preparedId
local catalog,settings,notes={},{schema=1,profiles={}},{ }
local knownVideos={}
local hooks,pinned={},{}
local warmGeneration=0
local success='GameplayEvent.Ability.Action.Activate.CombatArt.ShachiReinforced'
local function log(s) print('[PBZCinema] '..s..'\n') end
local function valid(o) local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
local function unbox(o) local ok,v=pcall(function()return o:get()end);return ok and v or o end
local function read(path)
    local f=io.open(path,'rb');if not f then return nil end;local s=f:read('*a');f:close();return s
end
local function save()
    local f=assert(io.open(profiles.root..'/State/Cinematics.json','wb'),'Cannot save cinematic settings')
    assert(f:write(json.encode(settings)..'\n'));f:close()
end
local function state(id)
    if type(settings.profiles[id])~='table' then settings.profiles[id]={enabled=false,missing_notified=false} end
    return settings.profiles[id]
end
local function fileExists(path)
    local f=io.open(path,'rb');if not f then return false end
    local size=f:seek('end');f:close();return type(size)=='number' and size>0 and size<=512*1024*1024
end
local function currentId() local p=appearance.current();return p and p.id end
local function eligible(id) return currentId()==id and state(id).enabled==true and catalog[id] and fileExists(catalog[id].video) end
local function release(reason)
    warmGeneration=warmGeneration+1
    if session then session:stop(reason) end
end
local function backendFor(id)
    if preparedId~=id or not session then
        if session then session:stop('profile changed');assert(session.state=='idle','Playback cleanup still pending') end
        local api={log=log,getPlayerController=context.getController,isActiveModel=function(v)return currentId()==v end}
        local backend=require('cinematic_backend').new(api,catalog[id].video,{root=profiles.root,profile_id=id})
        session=require('cinematic_session').new(backend,jobs.after,log);preparedId=id
    end
    return session
end
local function warm(reason,reset)
    warmGeneration=warmGeneration+1;local token=warmGeneration
    if reset and session then session:stop(reason) end
    jobs.after(600,function()
        local id=currentId();if token~=warmGeneration or not id or not eligible(id) then return end
        if not valid(context.getController()) then return end -- player/restart event will retry
        local ok,why=pcall(function()local s=backendFor(id);if s.state=='idle' then assert(s:warm()) end end)
        if not ok then notes[id]='预热失败 / Preparation failed';log(tostring(why)) end
    end)
end
function M.refresh()
    local nextCatalog,nextVideos={},{}
    for _,profile in ipairs(profiles.list) do
        if not profile.native_original then
        local raw=read(profile.directory..'/cinematic.json')
        do
            local ok,value=pcall(function()return contract.normalize(raw and json.decode(raw) or {schema=1,trigger='pbz_combat_art_success'},profile)end)
            if ok then nextCatalog[profile.id]=value;nextVideos[profile.id]=fileExists(value.video)
            else notes[profile.id]='动画配置无效 / Invalid configuration';log('Rejected cinematic '..profile.id..': '..tostring(value)) end
        end
    end
    end
    catalog=nextCatalog;knownVideos=nextVideos
    if session and (not preparedId or not catalog[preparedId] or currentId()~=preparedId) then release('catalog changed') end
    warm('explicit refresh',false)
end
local function openFolder(p)
    local request=assert(io.open(profiles.root..'/State/ImportFolder.txt','wb'))
    assert(request:write(p.directory..'\n'));request:close()
    local open=assert(package.loadlib(profiles.root..'/Tools/PBZCinematicAudio.dll','cinematic_missing_video_notice'));open()
    local result=read(profiles.root..'/State/ImportStatus.txt') or ''
    assert(result:match('^opened 0'),'Cannot open model directory: '..result)
end
local function missing(p)
    local s=state(p.id)
    if s.missing_notified then return end
    -- Win32 wide-character file creation preserves the exact Chinese title;
    -- Windows Lua io.open uses the active code page and cannot reliably do this.
    local ok,why=pcall(openFolder,p);s.missing_notified=true;save()
    if not ok then log(why);notes[p.id]='请打开模型目录导入视频 / Open the model folder to import' end
end
function M.toggle(id)
    local p=catalog[id];if not p then return false,'unavailable' end
    local s=state(id);knownVideos[id]=fileExists(p.video);notes[id]=nil
    if not knownVideos[id] then
        s.enabled=false;save();if preparedId==id then release('missing video')end
        require('folder_actions').open(profiles.root,p.directory,true)
        return true,'missing'
    end
    s.enabled=not s.enabled;save()
    if s.enabled then if currentId()==id then warm('enabled',false)end
    elseif preparedId==id then release('disabled')end
    return true
end
function M.recheck(id)
    M.refresh();notes[id]=nil
    return catalog[id] and fileExists(catalog[id].video) and '视频已就绪 / Video found' or '未找到 Ultimate.mp4 / Video missing'
end
function M.preview(id)
    assert(currentId()==id,require('ui_locale').get('apply_first'))
    assert(catalog[id] and fileExists(catalog[id].video),require('ui_locale').get('missing'))
    panel.close()
    jobs.after(100,function()
        if currentId()~=id then return end
        local ok,why=pcall(function()local started,err=backendFor(id):start(true);assert(started,err)end)
        if not ok then log('Preview failed: '..tostring(why)) end
    end)
end
function M.recheckAndPreview(id)
    M.recheck(id)
    if not catalog[id]or not knownVideos[id]then return false,'missing'end
    M.preview(id);return true
end
function M.describe(profile)
    local p=catalog[profile.id]
    if not p then return {installed=false,enabled=false,status=notes[profile.id] or '未安装动画可选包 / NOT INSTALLED',file='Ultimate.mp4',actions={}} end
    local enabled=state(profile.id).enabled==true;local exists=knownVideos[profile.id]==true
    return {installed=true,enabled=enabled,exists=exists,status=notes[profile.id] or (not exists and '等待导入视频 / VIDEO MISSING' or (enabled and '已开启 / ENABLED' or '已关闭 / DISABLED')),
        file='Ultimate.mp4',actions={
            {name='大招动画 / CINEMATIC     '..(enabled and '[ ON ]' or '[ OFF ]'),run=function()M.toggle(profile.id)end},
            {name='预览动画 / PREVIEW',run=function()M.preview(profile.id)end},
            {name='重新检测视频 / RECHECK VIDEO',run=function()return M.recheck(profile.id)end},
        }}
end
local function hook(path,callback)
    if hooks[path] then return true end
    if not valid(StaticFindObject(path)) then return false end
    local before=function()end
    local after=function(...)local ok,why=pcall(callback,...);if not ok then log('Event failed: '..tostring(why))end end
    local ok,a,b=pcall(RegisterHook,path,before,after);if not ok then log('Hook unavailable '..path..': '..tostring(a));return false end
    hooks[path]={a,b};pinned[#pinned+1]=before;pinned[#pinned+1]=after;log('Hook ready '..path);return true
end
function M.init(p,a,ui)
    profiles=p;appearance=a;panel=ui
    context=require('player_context').new(appearance.playerCandidates)
    jobs=require('game_thread_queue').new(log)
    local raw=read(profiles.root..'/State/Cinematics.json')
    if raw then local ok,value=pcall(json.decode,raw);if ok and value.schema==1 and type(value.profiles)=='table' then settings=value end end
    panel.setCinematics(M);M.refresh()
    panel.registerModelChangeListener(function()warm('model selection',true)end)
    assert(hook('/Script/GameplayAbilities.GameplayAbility:SendGameplayEvent',function(contextArg,tagArg)
        local id=currentId();if not id or not catalog[id] or state(id).enabled~=true then return end
        local tag=unbox(tagArg)
        local value=tag.TagName;local name=type(value)=='string' and value or value:ToString()
        if name~=success then return end
        local ability=unbox(contextArg)
        if not valid(ability) or not context.isPlayer(ability:GetAvatarActorFromActorInfo()) or not eligible(id) then return end
        log('CombatArt success profile='..id)
        jobs.after(0,function()
            if not eligible(id) then return end
            local ok,why=pcall(function()local s=backendFor(id);local started,reason=s:start(false);if not started then log('Not started: '..tostring(reason))end end)
            if not ok then log('Playback failed: '..tostring(why)) end
        end)
    end),'PBZ successful CombatArt event unavailable')
    for _,path in ipairs({'/Script/Engine.PlayerController:ClientRestart','/Script/Engine.PlayerController:ClientRetryClientRestart'}) do
        hook(path,function(arg)local pc=unbox(arg);if valid(pc) and context.isPlayer(pc.Pawn) then warm('player restart',true)end end)
    end
    local begin=function(arg)local pawn=unbox(arg);if valid(pawn) and context.isPlayer(pawn) then warm('local player BeginPlay',true)end end
    pinned[#pinned+1]=begin;RegisterBeginPlayPostHook(begin)
    local cancel=function()
        if session and session.state~='ready' and session.state~='idle' then release('Escape');return true end
        return false
    end
    pinned[#pinned+1]=cancel
    if type(panel.registerCancelHandler)=='function' then
        panel.registerCancelHandler(cancel)
    elseif not IsKeyBindRegistered(Key.ESCAPE) then
        -- Compatibility with an older panel. Current Core uses one shared
        -- binding so its menu close cannot disable video cancellation.
        local keyCancel=function()jobs.after(0,cancel)end
        pinned[#pinned+1]=keyCancel;RegisterKeyBind(Key.ESCAPE,keyCancel)
    end
    log('Generic cinematics ready; per-profile settings; own MP4; no idle polling')
end
M._roots={hooks=hooks,callbacks=pinned}
return M
