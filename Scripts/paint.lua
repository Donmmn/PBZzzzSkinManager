local controls=require('controls')
-- F5 toggles only wardrobe character materials. No timers or world scans.
local M={on=false,parents={}};local profiles,appearance;local UEHelpers=require('UEHelpers.UEHelpers')
local function valid(o) local ok,v=pcall(function() return o and o:IsValid() end);return ok and v end
local function full(o) return valid(o) and o:GetFullName() or '' end
local function includes(t,v) for _,x in ipairs(t or {}) do if x==v then return true end end end
local function log(s) print('[PBZPaint] '..s..'\n') end
local function load(path)
 local p,n=path:match('^(.-)%.([^%.]+)$');local h=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers');assert(valid(h),'Native asset loader unavailable')
 return h:GetAsset({PackageName=UEHelpers.FindOrAddFName(p),AssetName=UEHelpers.FindOrAddFName(n)})
end
function M.active() return M.on end
function M.schemeInfo(profile)
 profile=profile or (profiles and profiles.current)
 local path=profile and profile.paint and profile.paint.parents and profile.paint.parents.Mask
 return {version=type(path)=='string'and(path:match('/ThickPaint/(v%d+)/')or'custom')or'unspecified',scope='full'}
end

function M.supports(profile) return profile and profile.paint and profile.paint.enabled==true end
function M.shouldPaint(index,profile) return M.on and M.supports(profile) and index>=0 and index<#(profile.slots or {}) and not includes(profile.hidden_slots,index) end
function M.materialName(profile,index)
 local prefix=M.shouldPaint(index,profile) and ('PBZPaint_'..M.schemeInfo(profile).version..'_') or 'PBZWardrobe_'
 return prefix..profile.id..'_'..index
end
function M.parentFor(blend,profile)
 profile=profile or profiles.current
 assert(M.supports(profile),'Selected profile has no painterly material capability')
 local key=blend and 'Blend' or 'Mask'
 local path=profile.paint.parents[key]
 if not valid(M.parents[path]) then
  M.parents[path]=load(path)
 end
 assert(valid(M.parents[path]),'Painterly resources unavailable; restart after installing the declared shader package')
 return M.parents[path]
end
function M.healthy(material,index,profile,texture)
 if not valid(material) or not full(material):find('.'..M.materialName(profile,index),1,true) or not valid(texture) then return false end
 local actual=material:K2_GetTextureParameterValue(FName('BaseColorTexture'))
 return valid(actual) and full(actual)==full(texture) and math.abs(material:K2_GetScalarParameterValue(FName('PBZPaintStyle'))-profile.paint.style_value)<.0001
end
function M.configure(material,component,index,profile)
 if not M.shouldPaint(index,profile) then return end
 local kind=profile.paint.surface_types[index]
 if kind==nil then kind=0
 if includes(profile.eye_slots,index) then kind=3
 elseif includes(profile.face_slots,index) then kind=1
 elseif includes(profile.hair_slots,index) then kind=2
 elseif (profile.slots[index+1]or''):find('skin',1,true) then kind=4 end
 end
 material:SetScalarParameterValue(FName('PBZPaintStyle'),profile.paint.style_value)
 material:SetScalarParameterValue(FName('PaintSurfaceType'),kind)
 for parameter,value in pairs(profile.paint.parameters) do material:SetScalarParameterValue(FName(parameter),value) end
end
function M.toggle()
 local previous=M.on
 local ok,err=pcall(function()
  if not previous then assert(M.supports(profiles.current),'Selected character pack has not opted into F5 materials');M.parentFor(false);M.parentFor(true) end
  M.on=not previous;local n=appearance.refreshPaint()
  log((M.on and (controls.shader_name..' 厚涂三渲二：全角色材质开启') or (controls.shader_name..' 厚涂三渲二：关闭，已恢复原材质'))..'；角色组件='..tostring(n))
 end)
 if not ok then
  M.on=previous;pcall(function() appearance.refreshPaint() end)
  log('切换失败，保留原模式：'..tostring(err))
 end
end
function M.init(p,a)
 profiles=p;appearance=a
 if IsKeyBindRegistered(controls.shader_key) then log(controls.shader_name..' already occupied; existing binding preserved');return end
 M.callback=function() ExecuteInGameThread(M.toggle,EGameThreadMethod.ProcessEvent) end
 RegisterKeyBind(controls.shader_key,M.callback)
 log(controls.shader_name..' profile-declared character shader bound; starts OFF; no polling')
end
return M
