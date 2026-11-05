-- Captures the actual playable pawn, never a spawned preview mesh or duplicate rig.
-- Isolated actor list; one capture per menu frame, none after close.
local M={};local actor,cap,target,material,lastExposure,lastTone,lastProfile,fillActor,fill
local active=false;local fillStrength=4;local normalExposure=10;local paintExposure=6
local ownRoot=assert(debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/'):match('^(.*)/Scripts/[^/]+$'))
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
local function find(s)local o=StaticFindObject(s);assert(valid(o),'Unavailable: '..s);return o end
function M.reloadSettings()
 local f=io.open(ownRoot..'/preview-fill.txt','rb');local values={}
 if f then for v in f:read('*a'):gmatch('[^%s]+')do values[#values+1]=tonumber(v)end;f:close()end
 local value=values[1]
 if value and value==value and value>=0 and value<=32 then fillStrength=value end
 value=values[2];if value and value==value and value>=.1 and value<=32 then normalExposure=value end
 value=values[3];if value and value==value and value>=.1 and value<=16 then paintExposure=value end
 if active and valid(fill)then fill:SetIntensity(fillStrength)end
 print('[WardrobePreview] Frontal fill='..fillStrength..' cd; normalExposure='..normalExposure..'; paintExposure='..paintExposure..'; active='..tostring(active)..'\n')
end
M.reloadSettings()
local function exposure()
 local p,a=package.loaded.paint,package.loaded.appearance
 if p and a and type(p.active)=='function' and type(p.supports)=='function' and p.active() and p.supports(a.current())then return paintExposure,1 end
 return normalExposure,0
end
local function updateExposure()
 local value,tone=exposure();local changed=lastExposure~=value or lastTone~=tone
 if valid(material)and lastExposure~=value then material:SetScalarParameterValue(FName('Exposure'),value);lastExposure=value end
 if valid(material)and lastTone~=tone then material:SetScalarParameterValue(FName('ToneEnabled'),tone);material:SetScalarParameterValue(FName('ShadowGamma'),.8);lastTone=tone end
 if changed and valid(material)then print('[WardrobePreview] Preview gain='..value..'; tone='..tone..'\n')end
 local a=package.loaded.appearance;local profile=a and a.current()
 local id=profile and profile.id
 if valid(cap)and id~=lastProfile then pcall(function()cap.bCameraCutThisFrame=true end);lastProfile=id end
end
function M.suspend()
 if valid(cap)then cap.bCaptureEveryFrame=false;cap.bCaptureOnMovement=false end
end
function M.resume()
 if active and valid(cap)then
  cap.bCameraCutThisFrame=true;updateExposure();cap.bCaptureEveryFrame=true
 end
end
function M.close()
 active=false
 -- Retain one dormant capture per level. Reuse on reopen; the world owns its
 -- lifetime. No render flush, resource detachment or actor destruction on close.
 if valid(cap)then pcall(function()cap.bCaptureEveryFrame=false;cap.bCaptureOnMovement=false end)end
 if valid(fill)then pcall(function()fill:SetIntensity(0);fill:SetVisibility(false,false)end)end
end
function M.open(pc,image)
 M.close()
 local pawn=pc.Pawn;assert(valid(pawn),'Playable pawn unavailable')
 local game=find('/Script/Engine.Default__GameplayStatics')
 local mathlib=find('/Script/Engine.Default__KismetMathLibrary')
 local rendering=find('/Script/Engine.Default__KismetRenderingLibrary')
 local loc=pawn:K2_GetActorLocation();local facing=pawn:K2_GetActorRotation()
 local f=mathlib:GetForwardVector({Pitch=0,Yaw=facing.Yaw,Roll=0})
 -- Character actor origin is the capsule centre, not the feet.
 local aim={X=loc.X,Y=loc.Y,Z=loc.Z-15}
 local eye={X=loc.X+f.X*325,Y=loc.Y+f.Y*325,Z=aim.Z+10}
 local look=mathlib:FindLookAtRotation(eye,aim)
 local transform={Translation=eye,Rotation=mathlib:Conv_RotatorToQuaternion(look),Scale3D={X=1,Y=1,Z=1}}
 -- Menu-owned frontal fill. No character material, bone or light-channel edits.
 -- Disable it before removing the opaque menu so it cannot light normal play.
 local lampEye={X=eye.X,Y=eye.Y,Z=eye.Z+40}
 local lampLook=mathlib:FindLookAtRotation(lampEye,{X=aim.X,Y=aim.Y,Z=aim.Z+30})
 local lampTransform={Translation=lampEye,Rotation=mathlib:Conv_RotatorToQuaternion(lampLook),Scale3D={X=1,Y=1,Z=1}}
 if not valid(fillActor)then
  fillActor=game:BeginDeferredActorSpawnFromClass(pawn,find('/Script/Engine.SpotLight'),lampTransform,1,pawn,0)
  assert(valid(fillActor),'Preview fill light unavailable')
  fill=fillActor.SpotLightComponent;assert(valid(fill),'SpotLight component unavailable')
  fill:SetMobility(2);fill:SetCastShadows(false);fill:SetIntensityUnits(1)
  fill:SetAttenuationRadius(650);fill:SetInnerConeAngle(38);fill:SetOuterConeAngle(58)
  fill:SetLightColor({R=1,G=.95,B=.90,A=1},false)
  pcall(function()fill.VolumetricScatteringIntensity=0;fill.bAffectDynamicIndirectLighting=false end)
  game:FinishSpawningActor(fillActor,lampTransform,0)
 else fillActor:K2_TeleportTo(lampEye,lampLook)end
 fill:SetVisibility(true,false);fill:SetIntensity(fillStrength);active=true
 if not valid(actor)then
  actor=game:BeginDeferredActorSpawnFromClass(pawn,find('/Script/Engine.SceneCapture2D'),transform,1,pawn,0)
  assert(valid(actor),'SceneCapture actor construction failed')
  game:FinishSpawningActor(actor,transform,0)
 else actor:K2_TeleportTo(eye,look)end
 cap=actor.CaptureComponent2D;assert(valid(cap),'SceneCapture component unavailable')
 cap.bCaptureEveryFrame=false;cap.bCaptureOnMovement=false;cap.bAlwaysPersistRenderingState=true
 cap.CaptureSource=0 -- linear scene color, inverse opacity in alpha
 cap.PrimitiveRenderMode=2 -- ShowOnlyList, never render the scene again
 cap.FOVAngle=38;cap.MaxViewDistanceOverride=1600
 cap:SetComponentTickInterval(.05);cap:ClearShowOnlyComponents();cap:ShowOnlyActorComponents(pawn,true)
 if not valid(target)then target=rendering:CreateRenderTarget2D(pawn,768,768,6,{R=0,G=0,B=0,A=1},false,false)end
 assert(valid(target),'Character render target unavailable');cap.TextureTarget=target
 local path='/HuaShira/Mods/PBZWardrobe/UI/v2/M_CharacterComposite.M_CharacterComposite'
 local base=StaticFindObject(path)
 if not valid(base)then
  local h=find('/Script/AssetRegistry.Default__AssetRegistryHelpers')
  local H=require('UEHelpers.UEHelpers');local p,n=path:match('^(.-)%.([^%.]+)$')
  base=h:GetAsset({PackageName=H.FindOrAddFName(p),AssetName=H.FindOrAddFName(n)})
 end
 assert(valid(base),'UI composite material unavailable; restart after installing UI containers')
 material=find('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(pawn,base,FName('WardrobeUIComposite'),0)
 assert(valid(material),'UI composite dynamic material unavailable')
 material:SetTextureParameterValue(FName('CharacterTexture'),target)
 lastExposure=nil;lastTone=nil;lastProfile=nil;updateExposure()
 image:SetBrushFromMaterial(material)
 cap.bCaptureEveryFrame=true
 return true
end
function M.frame()
 if not valid(cap)then return false end
 -- Render scheduling belongs to the engine, not a Lua callback with an active
 -- UObject dispatch lock. CaptureScene's synchronous render flush can deadlock.
 updateExposure();return true
end
return M
