-- Profile data contract. Character IDs never select rendering, physics or fallback behavior.
local M={}
local ROOT='/HuaShira/Mods/PBZWardrobe/'
local function number(value,default,lo,hi,label)
    if value==nil then return default end
    assert(type(value)=='number' and value==value and value>=lo and value<=hi,'Invalid '..label)
    return value
end
local function boolean(value,default,label)
    if value==nil then return default end
    assert(type(value)=='boolean','Invalid '..label);return value
end
local function object(value,label)
    if value==nil then return {} end
    assert(type(value)=='table','Invalid '..label);return value
end
local function array(value,label)
    value=object(value,label)
    for k in pairs(value) do assert(type(k)=='number' and k%1==0 and k>=1 and k<=#value,'Invalid '..label..' array') end
    return value
end
local function asset(value,label,isolated)
    assert(type(value)=='string' and #value<=512 and value:match('^/[A-Za-z0-9_/]+%.[A-Za-z0-9_]+$') and not value:find('//',1,true),'Invalid '..label..' asset path')
    if isolated then assert(value:sub(1,#ROOT)==ROOT,label..' must use isolated wardrobe assets')
    else assert(value:find('^/HuaShira/') or value:find('^/Game/') or value:find('^/InterchangeAssets/'),'Unsupported '..label..' asset root') end
    return value
end
local function slots(value,n,label)
    local list=array(value,label);local seen={}
    for _,i in ipairs(list) do
        assert(type(i)=='number' and i%1==0 and i>=0 and i<n and not seen[i],'Invalid '..label..' slot index')
        seen[i]=true
    end
    return list
end
local function strings(value,label,pattern)
    value=array(value,label);local seen={}
    for _,s in ipairs(value) do assert(type(s)=='string' and #s>0 and #s<=512 and s:match(pattern) and not seen[s],'Invalid '..label);seen[s]=true end
    return value
end
local function slotMap(value,n,label,lo,hi,integer)
    local out={}
    for key,v in pairs(object(value,label)) do
        local i=type(key)=='number' and key or (type(key)=='string' and key:match('^%d+$') and tonumber(key))
        assert(i and i%1==0 and i>=0 and i<n and out[i]==nil,'Invalid '..label..' slot key')
        out[i]=number(v,nil,lo,hi,label)
        if integer then assert(v%1==0,'Invalid '..label..' integer') end
    end
    return out
end
local defaults={
    component_names={'Hun_Hat','Hun_Hat01','meshhead','meshBrowLashCard','meshScarf','meshBand','CA_Hun_Cape','CA_Hun_UpperCloth','CA_Hun_Skirt','CA_Hun_Hair'},
    asset_roots={'/huashira/characters/hero/hero_hun/','/game/pbzcontent/characters/hero/hero_hun/'},
    asset_fragments={'/hats/','/hun_cape','/hun_cloth','/hun_upcloth','/hun_downcloth','/hun_frontcloth','/hun_scarf','/hun_uppercloth_render','/hun_skirt_render','/hun_head_','/hun_hair','/hero_hun_hat_'}
}
local function append(base,extras,replace)
    local out,seen={},{}
    if not replace then for _,s in ipairs(base) do out[#out+1]=s;seen[s]=true end end
    for _,s in ipairs(extras) do if not seen[s] then out[#out+1]=s;seen[s]=true end end
    return out
end
function M.normalize(p,folder,modelsRoot)
    assert(type(p)=='table' and p.schema==1 and type(p.id)=='string' and p.id==folder and #p.id<=64 and p.id:match('^[a-z0-9_-]+$'),'Unsupported model manifest')
    assert(type(p.name)=='string' and #p.name>0 and #p.name<=256,'Missing model name')
    p.slots=array(p.slots,'slots');assert(#p.slots>0 and #p.slots<=64,'Invalid material slots')
    for _,key in ipairs(p.slots) do assert(type(key)=='string' and key:match('^[a-z0-9_-]+$'),'Invalid texture identifier') end
    local n=#p.slots
    for _,field in ipairs({'mesh','post_process','physics'}) do p[field]=asset(p[field],field,true) end
    assert(p.animation_class==nil and not p.weapon_only,'Native combat packs require their own adapter')
    p.sort_order=number(p.sort_order,1000,-100000,100000,'sort_order');assert(p.sort_order%1==0,'Invalid sort_order integer')
    p.default=boolean(p.default,false,'default')
    for _,field in ipairs({'hidden_slots','translucent_slots','lit_blend_slots','eye_slots','face_slots','hair_slots','body_emissive_slots'}) do p[field]=slots(p[field],n,field) end
    p.face_emissive=number(p.face_emissive,0,0,100,'face_emissive')
    p.eye_emissive=number(p.eye_emissive,p.face_emissive,0,100,'eye_emissive')
    p.body_emissive=number(p.body_emissive,0,0,100,'body_emissive')
    p.materials=object(p.materials,'materials')
    local mat=p.materials;mat.parents=object(mat.parents,'material parents')
    mat.parents.mask=asset(mat.parents.mask or '/InterchangeAssets/gltf/MaterialInstances/MI_Default_Mask_DS.MI_Default_Mask_DS','mask material',false)
    mat.parents.unlit_blend=asset(mat.parents.unlit_blend or '/InterchangeAssets/gltf/MaterialInstances/MI_Unlit_Blend_DS.MI_Unlit_Blend_DS','transparent material',false)
    mat.parents.lit_blend=asset(mat.parents.lit_blend or '/InterchangeAssets/gltf/MaterialInstances/MI_Default_Blend_DS.MI_Default_Blend_DS','lit blend material',false)
    p.base_color=number(mat.base_color,number(p.base_color,.8,0,4,'base_color'),0,4,'materials.base_color')
    mat.base_color=p.base_color;mat.blend_alpha=number(mat.blend_alpha,.3,0,1,'blend_alpha')
    mat.metallic=number(mat.metallic,0,0,1,'metallic');mat.roughness=number(mat.roughness,1,0,1,'roughness');mat.specular=number(mat.specular,.15,0,1,'specular')
    mat.emissive_by_slot=slotMap(mat.emissive_by_slot,n,'emissive_by_slot',0,100,false)
    if p.fallback_assets~=nil then
        p.fallback_assets=object(p.fallback_assets,'fallback_assets')
        for _,field in ipairs({'mesh','post_process','physics'}) do p.fallback_assets[field]=asset(p.fallback_assets[field],'fallback '..field,false) end
    end
    if p.primary_physics~=nil then
        local pp=object(p.primary_physics,'primary_physics');p.primary_physics=pp
        pp.enabled=boolean(pp.enabled,false,'primary_physics.enabled')
        if pp.enabled then
            pp.asset=asset(pp.asset,'primary physics',false)
            pp.required_sockets=strings(pp.required_sockets or {'pelvis','spine_04'},'required_sockets','^[A-Za-z0-9_]+$')
            assert(#pp.required_sockets>0,'Primary physics requires a socket contract')
        end
    end
    p.paint=object(p.paint,'paint');local paint=p.paint
    paint.enabled=boolean(paint.enabled,false,'paint.enabled')
    if paint.enabled then
        paint.parents=object(paint.parents,'paint.parents')
        for _,key in ipairs({'Mask','Blend'}) do paint.parents[key]=asset(paint.parents[key],'paint '..key,true) end
        paint.style_value=number(paint.style_value,1,.0001,100,'paint.style_value')
        paint.surface_types=slotMap(paint.surface_types,n,'paint.surface_types',0,4,true)
        paint.parameters=object(paint.parameters,'paint.parameters')
        for key,v in pairs(paint.parameters) do
            assert(type(key)=='string' and #key<=128 and key:match('^[A-Za-z][A-Za-z0-9_]*$') and key~='PBZPaintStyle' and key~='PaintSurfaceType','Invalid paint parameter')
            paint.parameters[key]=number(v,nil,-10000,10000,'paint parameter')
        end
    end
    p.spring_groups=array(p.spring_groups,'spring_groups')
    for _,g in ipairs(p.spring_groups) do
        assert(type(g)=='table' and type(g.prefix)=='string' and #g.prefix>0 and #g.prefix<=128 and g.prefix:match('^[A-Za-z0-9_]+$'),'Invalid spring prefix')
        g.stiffness=number(g.stiffness,nil,0,1000000,'spring stiffness');assert(g.stiffness,'Missing stiffness')
        g.damping=number(g.damping,nil,0,100000,'spring damping');assert(g.damping,'Missing damping')
        if g.swing_degrees~=nil then
            g.swing_degrees=number(g.swing_degrees,nil,0,180,'spring swing');g.twist_degrees=number(g.twist_degrees,nil,0,180,'spring twist');assert(g.twist_degrees,'Missing twist')
        else assert(g.twist_degrees==nil,'Twist requires swing_degrees') end
        if g.body_angular_damping~=nil then g.body_angular_damping=number(g.body_angular_damping,nil,0,10000,'body damping') end
    end
    p.hide_original=object(p.hide_original,'hide_original');local h=p.hide_original
    h.enabled=boolean(h.enabled,true,'hide_original.enabled');h.native_cloth=boolean(h.native_cloth,true,'hide_original.native_cloth')
    h.replace_default_names=boolean(h.replace_default_names,false,'replace_default_names')
    local extra=strings(h.component_names,'component_names','^[A-Za-z][A-Za-z0-9_]*$')
    for _,name in ipairs(extra) do assert(name~='CharacterMesh0' and not name:lower():find('weapon',1,true),'Refusing main mesh/weapon hiding') end
    h.component_names=append(defaults.component_names,extra,h.replace_default_names)
    h.asset_roots=strings(h.asset_roots or defaults.asset_roots,'asset_roots','^/[A-Za-z0-9_/]+/$')
    for i,v in ipairs(h.asset_roots) do
        v=v:lower();assert(v:find('^/huashira/characters/hero/hero_hun/') or v:find('^/game/pbzcontent/characters/hero/hero_hun/'),'Hiding roots must target original PBZ hero cosmetics');h.asset_roots[i]=v
    end
    h.asset_fragments=strings(h.asset_fragments or defaults.asset_fragments,'asset_fragments','^/[A-Za-z0-9_/]+$')
    for i,v in ipairs(h.asset_fragments) do h.asset_fragments[i]=v:lower();assert(not h.asset_fragments[i]:find('weapon',1,true),'Refusing weapon hiding') end
    p.directory=modelsRoot..'/'..folder
    return p
end
function M.less(a,b)
    if a.sort_order~=b.sort_order then return a.sort_order<b.sort_order end
    return a.id<b.id
end
function M.defaultProfile(list)
    for _,p in ipairs(list) do if p.default then return p end end
    return list[1]
end
function M.includes(list,value) for _,v in ipairs(list or {}) do if v==value then return true end end;return false end
function M.emissive(profile,index)
    if M.includes(profile.hidden_slots,index) then return 0 end
    local perSlot=profile.materials.emissive_by_slot[index]
    if perSlot~=nil then return perSlot end
    if M.includes(profile.eye_slots,index) then return profile.eye_emissive end
    if M.includes(profile.face_slots,index) then return profile.face_emissive end
    if M.includes(profile.body_emissive_slots,index) then return profile.body_emissive end
    return 0
end
return M
