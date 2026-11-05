-- Read only the current local pawn's existing material slots, on menu events.
-- Never scans actors, opens files, loads materials, or changes any parameters.
local M={}
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
function M.sample(profile,paint,component,busy)
 local r={busy=busy==true,enabled=false,supported=false,total=0,checked=0,painted=0,versions={},unknown=0}
 if paint then
  local ok,on=pcall(paint.active);r.enabled=ok and on==true
  ok,on=pcall(paint.supports,profile);r.supported=ok and on==true
  if type(paint.schemeInfo)=='function'then local good,info=pcall(paint.schemeInfo);if good and type(info)=='table'then r.scheme=info end end
 end
 if profile and profile.native_original then r.original=true;return r end
 if r.busy or not profile or not valid(component)then return r end
 for i=0,#(profile.slots or {})-1 do
  local hidden=false;for _,n in ipairs(profile.hidden_slots or {})do if n==i then hidden=true;break end end
  if not hidden then
   r.total=r.total+1
   local ok,material=pcall(function()return component:GetMaterial(i)end)
   if ok and valid(material)then
    local good,name=pcall(function()return material:GetFullName()end)
    if good and type(name)=='string'then
     local version=name:match('PBZPaint_(v%d+)_')
     if version then
      -- Check the parent too; an MID name alone is not material provenance.
      local parentOK,parent=pcall(function()return material.Parent end)
      local pathOK,path=pcall(function()return parent:GetFullName()end)
      local actual=parentOK and pathOK and type(path)=='string'and path:match('/ThickPaint/(v%d+)/')
      if actual and actual==version then
       r.checked=r.checked+1;r.painted=r.painted+1;r.versions[actual]=(r.versions[actual]or 0)+1
      else r.unknown=r.unknown+1 end
     elseif name:find('PBZPaint_',1,true)then r.unknown=r.unknown+1
     else r.checked=r.checked+1 end
    else r.unknown=r.unknown+1 end
   else r.unknown=r.unknown+1 end
  end
 end
 return r
end
function M.format(r,language)
 local en=language=='en'
 local prefix=en and 'SHADING: 'or'当前着色：'
 local configured=r.scheme and r.scheme.version
 local scope=r.scheme and r.scheme.scope
 local candidate=configured and(configured..(scope=='probe'and(en and ' torso test'or' 单躯干测试')or(scope=='full'and(en and ' full body'or' 全身')or'')))or(en and 'unspecified'or'未声明')
 if r.busy then return prefix..(en and 'Updating…'or'切换中…'),en and 'Waiting for material assignment to settle'or'等待材质绑定完成后核对' end
 if r.original then return prefix..(en and 'Game original materials'or'游戏原生材质'),en and 'F5 is not applied to Original'or'原皮不应用 F5 角色着色'end
 local count=0;local version
 for v in pairs(r.versions)do count=count+1;version=v end
 if r.total==0 or r.unknown>0 or r.checked~=r.total then
  return prefix..(en and 'Not fully verified'or'待核对'),(en and 'F5 '..(r.enabled and 'ON'or'OFF')..' | Candidate: 'or'F5 '..(r.enabled and'已开'or'已关')..' · 候选：')..candidate
 end
 if r.painted==0 then
  local state=r.enabled and not r.supported and(en and 'unsupported character'or'当前角色不支持')or(r.enabled and(en and 'ON; no toon slots detected'or'已开但未检测到三渲二槽')or(en and 'OFF'or'已关闭'))
  return prefix..(en and 'Character base materials'or'角色基础材质'),(en and 'F5 '..state..' | Candidate: 'or'F5 '..state..' · 候选：')..candidate
 end
 local style=count==1 and version or(en and 'multiple versions'or'多版本混用')
 if count==1 and configured==version then style=candidate end
 local mixed=r.painted<r.total
 local first=prefix..style..(mixed and(en and ' (mixed materials)'or'（混合材质）')or'')
 local second=en and(string.format('Verified toon slots: %d / %d',r.painted,r.total))or(string.format('已核对三渲二：%d / %d 个可见槽',r.painted,r.total))
 if mixed then second=second..(en and '; other slots use base materials'or'；其余使用基础材质')end
 if not r.enabled then second=second..(en and ' | F5 OFF; residual toon detected'or' · F5 已关但有着色残留')end
 return first,second
end
return M
