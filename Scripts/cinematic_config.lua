-- A role pack supplies data, never an executable callback or arbitrary path.
local M={video_name='Ultimate.mp4',notice_name='请自行导入大招动画或者下载有大招动画的版本.txt'}
function M.normalize(value,profile)
    assert(type(value)=='table' and value.schema==1,'Unsupported cinematic manifest')
    assert(value.trigger=='pbz_combat_art_success','Unsupported cinematic trigger')
    assert(value.video==nil or value.video==M.video_name,'Video must be Ultimate.mp4 beside model.json')
    assert(type(profile.id)=='string' and profile.id:match('^[a-z0-9_-]+$'),'Invalid profile ID')
    assert(type(profile.directory)=='string' and not profile.directory:find('[\r\n%z]'),'Invalid model directory')
    local label=value.name or '大招动画 / ULTIMATE CINEMATIC'
    assert(type(label)=='string' and #label<=256,'Invalid cinematic title')
    return {id=profile.id,name=label,directory=profile.directory,video=profile.directory..'/'..M.video_name,
        enabled_by_default=false,trigger=value.trigger}
end
return M
