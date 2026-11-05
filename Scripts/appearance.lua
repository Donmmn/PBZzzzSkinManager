-- Native-material binding driven only by lifecycle and material events.
-- Do not load the incompatible UE 5.8 cooked toon shader in this UE 5.7 game.
local pending,busy,textures={},{},{}
local live={}
local originalAnimation={}
local nativeSettings={}
local pawnObserver,selectionGuard
local materialParents={}
local errors=0
local slots={}
local profiles=require("profiles")
local damageCollision=require('damage_collision')
local selected=profiles.current
local nativeOriginal=require('native_appearance')
local requestedOriginal
local config=require('profile_config')
local hiddenOriginal={};local restoringCosmetics=false
local function hiding() return selected.hide_original end
local function originalName(short)
    if not short or not hiding().enabled then return false end
    for _,name in ipairs(hiding().component_names) do if name:lower()==short:lower() then return true end end
    return false
end
local function originalRoot(assetName)
    if not hiding().enabled or assetName:find('/weapon/',1,true) then return false end
    for _,root in ipairs(hiding().asset_roots) do if assetName:find(root,1,true) then return true end end
    return false
end
local function log(message) print('[PBZWardrobe] '..message..'\n') end
local function valid(object)
    if object==nil then return false end
    local ok,result=pcall(function() return object:IsValid() end)
    return ok and result
end
local function full(object)
    if not valid(object) then return '' end
    local ok,result=pcall(function() return object:GetFullName() end)
    return ok and tostring(result) or ''
end
local function unwrap(param)
    local ok,value=pcall(function() return param:get() end)
    if ok then return value end
    return param
end
local function guarded(callback)
    local ok,err=pcall(callback)
    if not ok then
        errors=errors+1
        if errors<=10 then log('ERROR '..tostring(err)) end
    end
end
local function hero(owner)
    local name=full(owner)
    if not name:find(':PersistentLevel.',1,true) or name:find('Default__',1,true) then return false end
    return name:find('BP_Renewal_Hun_C_',1,true) or name:find('BP_Player_Hero_Hun_C_',1,true) or name:find('BP_Seq_Hun_C_',1,true)
end
local function main(component)
    local name=full(component)
    if not name:find('%.CharacterMesh0$') or name:find('TrashedPackage',1,true) then return false end
    return hero(component:GetOwner())
end
local function hide(component)
    if selected.native_original or nativeOriginal.isRestoring() then return end
    nativeOriginal.rememberPart(component)
    local key=full(component)
    if not hiddenOriginal[key] then
        local saved={component=component}
        for _,property in ipairs({'bVisible','bHiddenInGame','bRenderInMainPass','bRenderInDepthPass','CastShadow'}) do
            pcall(function() local value=component[property];if type(value)=='boolean' then saved[property]=value end end)
        end
        hiddenOriginal[key]=saved
    end
    component:SetVisibility(false,false)
    component:SetHiddenInGame(true,false)
    pcall(function() component:SetRenderInMainPass(false) end)
    pcall(function() component:SetRenderInDepthPass(false) end)
    pcall(function() component:SetCastShadow(false) end)
end
local function restoreHidden()
    -- Restore only values captured before this framework changed an original adult-hero component.
    restoringCosmetics=true
    for key,saved in pairs(hiddenOriginal) do
        local component=saved.component
        if valid(component) and hero(component:GetOwner()) then
            if saved.bVisible~=nil then pcall(function() component:SetVisibility(saved.bVisible,false) end) end
            if saved.bHiddenInGame~=nil then pcall(function() component:SetHiddenInGame(saved.bHiddenInGame,false) end) end
            if saved.bRenderInMainPass~=nil then pcall(function() component:SetRenderInMainPass(saved.bRenderInMainPass) end) end
            if saved.bRenderInDepthPass~=nil then pcall(function() component:SetRenderInDepthPass(saved.bRenderInDepthPass) end) end
            if saved.CastShadow~=nil then pcall(function() component:SetCastShadow(saved.CastShadow) end) end
        end
        hiddenOriginal[key]=nil
    end
    restoringCosmetics=false
end
local function cosmeticAsset(asset)
    local name=full(asset):lower()
    if not originalRoot(name) then return false end
    for _,part in ipairs(hiding().asset_fragments) do if name:find(part,1,true) then return true end end
    return false
end

local clothHidden={}
local function componentAsset(component)
    local asset
    for _,property in ipairs({'SkeletalMesh','StaticMesh','ClothAsset','Asset'}) do
        pcall(function() if not valid(asset) then asset=component[property] end end)
    end
    if not valid(asset) then pcall(function() asset=component:GetClothAsset() end) end
    if not valid(asset) then pcall(function() asset=component:GetSkinnedAsset() end) end
    return asset
end
local function nativeCloth(component,asset)
    if not hiding().enabled or not hiding().native_cloth then return false end
    local name=full(component):lower();local assetName=full(asset):lower()
    if not name:find('chaosclothcomponent ',1,true) or name:find('weapon',1,true) or assetName:find('/weapon/',1,true) then return false end
    return originalName(name:match('%.([^%.]+)$')) or originalRoot(assetName)
end
local function hideNativeCloth(component,asset)
    if selected.native_original or nativeOriginal.isRestoring() then return false end
    if restoringCosmetics then return false end
    if not valid(component) or not hero(component:GetOwner()) then return false end
    asset=valid(asset) and asset or componentAsset(component)
    if not nativeCloth(component,asset) then return false end
    local name=full(component)
    clothHidden[name..':busy']=true
    local ok,err=pcall(function() hide(component) end)
    clothHidden[name..':busy']=nil
    if not ok then error(err) end
    if not clothHidden[name] then
        clothHidden[name]=true
        print('[WardrobeClothHide] Hidden '..name..' asset='..full(asset)..'\n')
    end
    return true
end
local function ownedCloth(pawn)
    if not hiding().enabled or not hiding().native_cloth then return end
    local class=StaticFindObject('/Script/ChaosClothAssetEngine.ChaosClothComponent')
    if not valid(class) then return end
    local array=pawn:K2_GetComponentsByClass(class)
    local checked=0
    local function visit(index,entry)
        local component=unwrap(entry)
        checked=checked+1
        guarded(function() hideNativeCloth(component) end)
    end
    -- This game's UE4SS marshals UFunction array returns as ordinary Lua tables.
    if type(array)=='table' then
        for index,entry in ipairs(array) do visit(index,entry) end
    else
        array:ForEach(visit)
    end
    local identity=full(pawn)
    if not clothHidden[identity..':checked'] then
        clothHidden[identity..':checked']=true
        print('[WardrobeClothHideV3] Owner components checked='..checked..' owner='..identity..'\n')
    end
end

local assets={}
local visibleProfile={}
local UEHelpers=require('UEHelpers.UEHelpers')
local function loadIsolated(path)
    -- UE4SS LoadAsset consults registry entries absent for newly added resources.
    -- Native FAssetData loading is also used by the bundled BPModLoaderMod.
    local package,name=path:match('^(.-)%.([^%.]+)$')
    assert(package and name,'Invalid resource path')
    local helpers=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
    if not valid(helpers) then error('Native asset loader unavailable') end
    return helpers:GetAsset({PackageName=UEHelpers.FindOrAddFName(package),AssetName=UEHelpers.FindOrAddFName(name)})
end
local function includes(list,value)
    for _,item in ipairs(list or {}) do if item==value then return true end end
    return false
end
local function loadModel(profile)
    local cache=assets[profile.id] or {}
    if not valid(cache.mesh) then cache.mesh=loadIsolated(profile.mesh) end
    if not valid(cache.post) then cache.post=loadIsolated(profile.post_process) end
    if not valid(cache.physics) then
        cache.physics=loadIsolated(profile.physics)
        cache.springsApplied=nil
    end
    if profile.fallback_assets and (not valid(cache.mesh) or not valid(cache.post) or not valid(cache.physics)) then
        local fallback=profile.fallback_assets
        cache.mesh=LoadAsset(fallback.mesh);cache.post=LoadAsset(fallback.post_process);cache.physics=LoadAsset(fallback.physics)
        if not cache.fallback then log('Using declared fallback assets model='..profile.id);cache.fallback=true end
    end
    if not valid(cache.mesh) or not valid(cache.post) or not valid(cache.physics) then
        if not cache.logged then
            log('Load diagnostic '..profile.id..' mesh='..tostring(valid(cache.mesh))..' post='..tostring(valid(cache.post))..' physics='..tostring(valid(cache.physics)))
            cache.logged=true;assets[profile.id]=cache
        end
        error('Model resources unavailable (restart after adding packages): '..profile.id)
    end
    if profile.animation_class and not valid(cache.animation) then
        cache.animation=loadIsolated(profile.animation_class)
        assert(valid(cache.animation),'Native animation class unavailable')
    end
    assets[profile.id]=cache
    if profile.spring_groups and #profile.spring_groups>0 and not cache.springsApplied then
        local count=0
        local ok,err=pcall(function()
            local constraints=cache.physics.ConstraintSetup
            for i=1,#constraints do
                local instance=constraints[i].DefaultInstance
                local bone=instance.ConstraintBone1:ToString()
                for _,group in ipairs(profile.spring_groups) do
                    if bone:sub(1,#group.prefix)==group.prefix then
                        local function drive(angular)
                            angular.bAccelerationMode=true;angular.AngularDriveMode=1
                            angular.SlerpDrive.Stiffness=group.stiffness
                            angular.SlerpDrive.Damping=group.damping
                            angular.SlerpDrive.MaxForce=0
                            angular.SlerpDrive.bEnablePositionDrive=true
                            angular.SlerpDrive.bEnableVelocityDrive=true
                        end
                        local function applyProfile(p)
                            drive(p.AngularDrive)
                            if group.swing_degrees then
                                p.ConeLimit.Swing1LimitDegrees=group.swing_degrees
                                p.ConeLimit.Swing2LimitDegrees=group.swing_degrees
                                p.TwistLimit.TwistLimitDegrees=group.twist_degrees
                            end
                        end
                        applyProfile(instance.ProfileInstance)
                        -- Instantiation may copy the transient default-profile cache.
                        local defaultOk,defaultError=pcall(function() applyProfile(constraints[i].DefaultProfile) end)
                        if group.swing_degrees then
                            log('Chest joint tuning bone='..bone..' stiffness='..instance.ProfileInstance.AngularDrive.SlerpDrive.Stiffness..' damping='..instance.ProfileInstance.AngularDrive.SlerpDrive.Damping..' swing='..instance.ProfileInstance.ConeLimit.Swing1LimitDegrees..' default_profile='..tostring(defaultOk))
                            if not defaultOk then log('Default profile tuning unavailable: '..tostring(defaultError)) end
                        end
                        count=count+1
                    end
                end
            end
            for i=1,#cache.physics.SkeletalBodySetups do
                local body=cache.physics.SkeletalBodySetups[i]
                local bone=body.BoneName:ToString()
                for _,group in ipairs(profile.spring_groups) do
                    if group.body_angular_damping and bone:sub(1,#group.prefix)==group.prefix then
                        body.DefaultInstance.AngularDamping=group.body_angular_damping
                        log('Chest body damping bone='..bone..' value='..body.DefaultInstance.AngularDamping)
                    end
                end
            end
        end)
        cache.springsApplied=true
        if ok and count>0 then cache.refreshPost=true;log('Native spring drives applied model='..profile.id..' constraints='..count)
        elseif not ok then log('Spring tuning unavailable: '..tostring(err)) end
    end
    return cache
end
local function emissiveFor(index) return config.emissive(selected,index) end
local function nativeParent(path)
    if not valid(materialParents[path]) then materialParents[path]=LoadAsset(path) end
    assert(valid(materialParents[path]),'Declared native material unavailable: '..path)
    return materialParents[path]
end
-- PBZPaint integration: native F5 character material switch
local paint=require('paint')
local function materialName(index) return paint.materialName(selected,index) end
local function healthy(material,index)
    if paint.shouldPaint(index,selected) then
        return paint.healthy(material,index,selected,textures[selected.id..':'..selected.slots[index+1]])
    end
    if not full(material):find('.'..materialName(index),1,true) then return false end
    if includes(selected.hidden_slots,index) then return true end
    do
        local expected=emissiveFor(index)
        local value=material:K2_GetScalarParameterValue(FName('EmissiveStrength'))
        if math.abs(value-expected)>.000001 then return false end
    end
    local expected=textures[selected.id..':'..selected.slots[index+1]]
    local actual=material:K2_GetTextureParameterValue(FName('BaseColorTexture'))
    return valid(expected) and valid(actual) and full(actual)==full(expected)
end
local function textureFor(component,key)
    local identity=selected.id..':'..key
    if not valid(textures[identity]) then
        local library=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
        textures[identity]=library:ImportFileAsTexture2D(component,selected.directory..'/Textures/'..key..'.png')
        if not valid(textures[identity]) then error('PNG import failed: '..identity) end
    end
    return textures[identity]
end
local function bind(component,reason)
    if selected.native_original then return end
    if not main(component) then return end
    local identity=full(component)
    if busy[identity] then return end
    busy[identity]=true
    local changed=0
    local ok,err=pcall(function()
        local model=loadModel(selected)
        local current=componentAsset(component)
        local nativeChanged=false
        if selected.animation_class and not nativeSettings[identity] then
            nativeSettings[identity]={disableMorph=component.bDisableMorphTarget,refPose=component.bUseRefPoseOnInitAnim,pause=component.bPauseAnims,tick=component:IsComponentTickEnabled()}
            component.bDisableMorphTarget=selected.disable_morph_targets==true
            component.bUseRefPoseOnInitAnim=false
            component.bPauseAnims=false
            component:SetComponentTickEnabled(true)
            nativeChanged=true
        elseif not selected.animation_class and nativeSettings[identity] then
            local previous=nativeSettings[identity]
            component.bDisableMorphTarget=previous.disableMorph
            component.bUseRefPoseOnInitAnim=previous.refPose
            component.bPauseAnims=previous.pause
            component:SetComponentTickEnabled(previous.tick)
            nativeSettings[identity]=nil
        end
        -- Save the game class before changing skeleton, not after UE reinitializes it.
        if selected.animation_class and not originalAnimation[identity] then
            local instance=component:GetAnimInstance()
            assert(valid(instance),'Original animation instance unavailable')
            local original=instance:GetClass()
            assert(valid(original),'Original animation class unavailable')
            originalAnimation[identity]=original
        end
        if full(current)~=full(model.mesh) then
            component:SetSkeletalMeshAsset(model.mesh)
            log('Mesh assigned '..selected.id..' actor='..identity)
        end
        damageCollision.apply(component,selected)
        local currentInstance=component:GetAnimInstance()
        if selected.animation_class then
            if not valid(currentInstance) or full(currentInstance:GetClass())~=full(model.animation) then
                component:SetAnimInstanceClass(model.animation)
                nativeChanged=true
                log('Native animation class applied model='..selected.id)
            end
        elseif originalAnimation[identity] then
            local original=originalAnimation[identity]
            assert(valid(original),'Saved animation class unavailable; refusing unsafe restore')
            component:SetAnimInstanceClass(original)
            originalAnimation[identity]=nil
            log('Previous game animation class restored')
        end
        local instance=component.PostProcessAnimInstance
        if model.refreshPost or not valid(instance) or full(instance:GetClass())~=full(model.post) then
            local rebuild=model.refreshPost
            component:SetOverridePostProcessAnimBP(model.post,true)
            if rebuild then
                component:SetAnimationMode(0,true)
                log('Animation and secondary-physics instances force-reinitialized once for spring tuning')
            end
            model.refreshPost=false
        end
        if nativeChanged then
            component:SetAnimationMode(0,true)
            log('Native animation initialized; ref pose disabled, tick enabled; morph compatibility='..tostring(selected.disable_morph_targets==true))
        end
        if valid(StaticFindObject('/Script/Engine.SkinnedMeshComponent:ShowMaterialSection')) then
            local reset=visibleProfile[identity]~=selected.id
            if reset then component:ShowAllMaterialSections(0);visibleProfile[identity]=selected.id end
            for _,slot in ipairs(selected.hidden_slots or {}) do
                if reset or component:IsMaterialSectionShown(slot,0) then
                    component:ShowMaterialSection(slot,slot,false,0)
                    log('Overlay geometry hidden model='..selected.id..' slot='..slot..' shown='..tostring(component:IsMaterialSectionShown(slot,0)))
                end
            end
        end
        for index=0,#selected.slots-1 do
            if not healthy(component:GetMaterial(index),index) then
                local hidden=includes(selected.hidden_slots,index)
                local blend=includes(selected.translucent_slots,index)
                local skinBlend=includes(selected.lit_blend_slots,index)
                local materialConfig=selected.materials
                local parents=materialConfig.parents
                local chosenParent=nativeParent(skinBlend and parents.lit_blend or (hidden or blend) and parents.unlit_blend or parents.mask)
                if paint.shouldPaint(index,selected) then chosenParent=paint.parentFor(skinBlend or blend,selected) end
                local material=component:CreateDynamicMaterialInstance(index,chosenParent,FName(materialName(index)))
                if not valid(material) then error('MID creation failed: '..index) end
                if hidden then
                    material:SetVectorParameterValue(FName('BaseColorFactor'),{R=0,G=0,B=0,A=0})
                else
                    local texture=textureFor(component,selected.slots[index+1])
                    local color=selected.base_color or .8
                    material:SetTextureParameterValue(FName('BaseColorTexture'),texture)
                    material:SetVectorParameterValue(FName('BaseColorFactor'),{R=color,G=color,B=color,A=blend and materialConfig.blend_alpha or 1})
                    material:SetScalarParameterValue(FName('MetallicFactor'),materialConfig.metallic)
                    material:SetScalarParameterValue(FName('RoughnessFactor'),materialConfig.roughness)
                    material:SetScalarParameterValue(FName('SpecularFactor'),materialConfig.specular)
                    material:SetScalarParameterValue(FName('EmissiveStrength'),0)
                    material:SetVectorParameterValue(FName('EmissiveFactor'),{R=0,G=0,B=0,A=1})
                    if emissiveFor(index)>0 then
                        material:SetTextureParameterValue(FName('EmissiveTexture'),texture)
                        material:SetVectorParameterValue(FName('EmissiveFactor'),{R=1,G=1,B=1,A=1})
                        material:SetScalarParameterValue(FName('EmissiveStrength'),emissiveFor(index))
                        if includes(selected.face_slots,index) then log('Face fill applied model='..selected.id..' strength='..tostring(material:K2_GetScalarParameterValue(FName('EmissiveStrength')))) end
                        if includes(selected.body_emissive_slots,index) then log('Body fill applied model='..selected.id..' strength='..tostring(material:K2_GetScalarParameterValue(FName('EmissiveStrength')))) end
                    end
                end
                if paint.active() and not hidden then paint.configure(material,component,index,selected) end
                changed=changed+1
            end
        end
    end)
    busy[identity]=nil
    if not ok then error(err) end
    if changed>0 then log('Bound '..changed..' slots model='..selected.id..' reason='..reason..' actor='..identity) end
end

local function request(component,reason)
    if not main(component) then return end
    local identity=full(component)
    if requestedOriginal and not live[identity] then
        local owner=full(component:GetOwner())
        if owner:find('BP_Renewal_Hun_C_',1,true) or owner:find('BP_Player_Hero_Hun_C_',1,true) then
            selected=requestedOriginal;profiles.current=selected;requestedOriginal=nil
            log('Original mode active on fresh playable character; no hot mesh/animation/physics restore')
        end
    end
    live[identity]=component
    if not busy[identity] and not nativeOriginal.isRestoring() then nativeOriginal.capture(component,selected.native_original==true) end
    if selected.native_original then return end
    if busy[identity] or pending[identity] then return end
    pending[identity]=true
    -- Coalesce a batch of model material SetMaterial calls into one game-thread callback.
    ExecuteInGameThread(function()
        pending[identity]=nil
        guarded(function() if valid(component) then bind(component,reason) end end)
    end,EGameThreadMethod.ProcessEvent)
end
local function initializePawn(pawn,reason)
    if not valid(pawn) or not hero(pawn) then return end
    if pawnObserver then guarded(function() pawnObserver(pawn,reason) end) end
    local ok,component=pcall(function() return pawn.Mesh end)
    if ok and valid(component) then request(component,reason) end
    guarded(function() ownedCloth(pawn) end)
    if hiding().enabled then
        for _,name in ipairs(hiding().component_names) do
            pcall(function() local part=pawn[name];if valid(part) then hide(part) end end)
        end
    end
end
local function inspect(component,asset,reason)
    if not valid(component) then return end
    local name=full(component)
    if name:find('TrashedPackage',1,true) then return end
    if hideNativeCloth(component,asset) then return end
    if main(component) then initializePawn(component:GetOwner(),reason)
    elseif hero(component:GetOwner()) and (originalName(name:match('%.([^%.]+)$')) or cosmeticAsset(asset)) then hide(component) end
end
local function hook(path,callback)
    local ok,err=pcall(function()
        RegisterHook(path,function() end,function(...)
            local args={...}
            guarded(function() callback(table.unpack(args)) end)
        end)
    end)
    log('Hook '..path..' installed='..tostring(ok)..(ok and '' or (' error='..tostring(err))))
end
for _,path in ipairs({'/Script/Engine.PlayerController:ClientRestart','/Script/Engine.PlayerController:ClientRetryClientRestart'}) do
    hook(path,function(context,newPawn) initializePawn(unwrap(newPawn),'pawn_restart') end)
end
for _,path in ipairs({'/Script/Engine.SkeletalMeshComponent:SetSkeletalMeshAsset','/Script/Engine.SkinnedMeshComponent:SetSkinnedAssetAndUpdate'}) do
    hook(path,function(context,newAsset) inspect(unwrap(context),unwrap(newAsset),'mesh_assignment') end)
end
for _,path in ipairs({'/Script/Engine.PrimitiveComponent:SetMaterial','/Script/Engine.PrimitiveComponent:SetMaterialByName'}) do
    hook(path,function(context) request(unwrap(context),'material_assignment') end)
end
hook('/Script/Engine.Actor:K2_TeleportTo',function(context) initializePawn(unwrap(context),'teleport') end)
local ok,err=pcall(function()
    RegisterBeginPlayPostHook(function(actor)
        guarded(function() initializePawn(unwrap(actor),'begin_play') end)
    end)
end)
log('BeginPlay hook installed='..tostring(ok)..(ok and '' or (' error='..tostring(err))))
-- Only initial lookup; subsequent repairs receive the changed component directly.
ExecuteInGameThread(function()
    guarded(function()
        for _,component in ipairs(FindAllOf('SkinnedMeshComponent') or {}) do
            inspect(component,componentAsset(component),'initial_lookup')
        end
    end)
    log('Initial lookup finished; no repeating timers or scene scans')
end,EGameThreadMethod.ProcessEvent)
log('Loaded native-only persistent binding')

local visibilityBusy={}
local function enforceCosmetic(component)
    if selected.native_original or nativeOriginal.isRestoring() then return end
    if restoringCosmetics or not hiding().enabled then return end
    if not valid(component) or not hero(component:GetOwner()) then return end
    local identity=full(component)
    if visibilityBusy[identity] or clothHidden[identity..':busy'] or identity:find('%.CharacterMesh0$') then return end
    local short=identity:match('%.([^%.]+)$')
    local asset
    pcall(function() asset=component.SkeletalMesh end)
    if not valid(asset) then pcall(function() asset=component.StaticMesh end) end
    asset=valid(asset) and asset or componentAsset(component)
    if not originalName(short) and not cosmeticAsset(asset) and not nativeCloth(component,asset) then return end
    visibilityBusy[identity]=true
    local ok,err=pcall(function() hide(component) end)
    visibilityBusy[identity]=nil
    if not ok then error(err) end
end
for _,path in ipairs({'/Script/Engine.SceneComponent:SetVisibility','/Script/Engine.SceneComponent:SetHiddenInGame','/Script/Engine.PrimitiveComponent:SetRenderInMainPass'}) do
    hook(path,function(context) enforceCosmetic(unwrap(context)) end)
end
hook('/Script/Engine.StaticMeshComponent:SetStaticMesh',function(context,newAsset)
    inspect(unwrap(context),unwrap(newAsset),'static_mesh_assignment')
end)
print('[WardrobeCutsceneFix] Adult BP_Seq_Hun_C supported; live actors only; event-only visibility enforcement\n')

for _,path in ipairs({'/Script/ChaosClothAssetEngine.ChaosClothComponent:SetClothAsset','/Script/ChaosClothAssetEngine.ChaosClothComponent:SetAsset'}) do
    if valid(StaticFindObject(path)) then
        hook(path,function(context,asset) inspect(unwrap(context),unwrap(asset),'cloth_asset_assignment') end)
    end
end
print('[WardrobeClothHideV3] Native K2 component enumeration and explicit original costume names active; no polling\n')


local M={}
function M.playerCandidates()
    local candidates={}
    for _,component in pairs(live) do
        local ok,pawn=pcall(function()
            if not valid(component) then return nil end
            local owner=component:GetOwner();local name=full(owner)
            if not name:find(':PersistentLevel.',1,true) or name:find('Default__',1,true) or name:find('TrashedPackage',1,true) then return nil end
            if name:find('BP_Renewal_Hun_C_',1,true) or name:find('BP_Player_Hero_Hun_C_',1,true) then return owner end
        end)
        if ok and valid(pawn) then candidates[#candidates+1]=pawn end
    end
    return candidates
end
function M.select(id,options)
    options=options or {}
    if selectionGuard and not options.internal then selectionGuard(id) end
    local profile=profiles.byId[id]
    if not profile then error('Unknown model: '..tostring(id)) end
    -- Resolve dependencies before changing the active selection.
    if profile.native_original then
        requestedOriginal=profile
        if not options.transient then profiles.save(id) end
        log('Original requested; current component preserved; takes effect on reload/restart')
        return '原皮将在重新读档后生效 / ORIGINAL WILL APPLY AFTER RELOADING YOUR SAVE'
    end
    requestedOriginal=nil
    local candidate=loadModel(profile)
    selected=profile;profiles.current=profile
    restoreHidden()
    local changed=0
    for name,component in pairs(live) do
        if valid(component) and main(component) then
            initializePawn(component:GetOwner(),'model_selection');changed=changed+1
        else live[name]=nil end
    end
    if not options.transient then profiles.save(id) end
    log('Selected '..profile.id..' live_components='..changed)
    return changed
end
function M.onPawn(callback) pawnObserver=callback end
function M.guardSelection(callback) selectionGuard=callback end
function M.current() return selected end
function M.pendingSelection()return requestedOriginal and requestedOriginal.id end
function M.hasPlayer()
    for _,component in pairs(live) do if valid(component) and main(component) then return true end end
    return false
end
function M.refreshPaint()
    local count=0
    for _,component in pairs(live) do
        if valid(component) and main(component) then bind(component,'F5_paint_toggle');count=count+1 end
    end
    return count
end
return M
