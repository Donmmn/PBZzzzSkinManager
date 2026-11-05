-- Apply an opted-in profile's primary hit-query physics asset to its declared cosmetic mesh only.
-- No health/damage values, collision channels, timers or world scans.
local M={};local rebuilt,assets={},{}
local function valid(o) local ok,v=pcall(function() return o and o:IsValid() end);return ok and v end
local function full(o) return valid(o) and o:GetFullName() or '' end
local function log(s) print('[WardrobeDamageCollision] '..s..'\n') end
function M.supports(profile) return profile and profile.primary_physics and profile.primary_physics.enabled==true end
function M.apply(component,profile)
    if not M.supports(profile) then return end
    local contract=profile.primary_physics
    local mesh=component.SkeletalMesh;local meshName=full(mesh)
    local expected=profile.mesh
    local declaredFallback=profile.fallback_assets and profile.fallback_assets.mesh
    assert(meshName~='' and (meshName:find(expected,1,true) or (declaredFallback and meshName:find(declaredFallback,1,true))),'Refusing physics change outside the selected cosmetic profile')
    assert(valid(StaticFindObject('/Script/Engine.SkinnedMeshComponent:SetPhysicsAsset')),'Native SetPhysicsAsset UFunction unavailable')
    for _,socket in ipairs(contract.required_sockets) do assert(component:DoesSocketExist(FName(socket)),'Primary physics socket unavailable: '..socket) end
    local target=assets[contract.asset]
    if not valid(target) then target=LoadAsset(contract.asset);assets[contract.asset]=target end
    assert(valid(target),'Declared primary physics asset unavailable')
    local changed=full(mesh.PhysicsAsset)~=full(target)
    if changed then
        assert(not valid(mesh.PhysicsAsset),'Unknown existing mesh physics asset preserved')
        mesh.PhysicsAsset=target;assert(full(mesh.PhysicsAsset)==full(target),'Primary mesh physics reference did not apply')
    end
    local identity=full(component);local signature=meshName..'|'..full(target)
    if changed or rebuilt[identity]~=signature then
        local prior=component.PhysicsAssetOverride
        component:SetPhysicsAsset(valid(prior) and prior or nil,true)
        assert(full(component.PhysicsAssetOverride)==full(prior),'Component override changed unexpectedly')
        rebuilt[identity]=signature
        log('Primary hit bodies restored model='..profile.id..' asset='..full(target)..' actor='..identity)
    end
end
return M
