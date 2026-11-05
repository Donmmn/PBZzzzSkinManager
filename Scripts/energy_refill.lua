-- Manual local-player utility. Reuses the PBZ-native charge flow verified in
-- debug_refill.lua (sha256 9a0613793a6f466c9ea79cac4fa25ca5a2eb4f4987dc979a33838a733c893ca5).
-- No startup action, timer, ability activation, direct attribute write or scan.
local M={}
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
function M.refill(context)
 assert(type(context)=='table','Local player context unavailable')
 local pc=context.getController()
 assert(valid(pc)and valid(pc.Pawn)and context.isPlayer(pc.Pawn),'Local player unavailable')
 local pawn=pc.Pawn
 local lib=StaticFindObject('/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary')
 assert(valid(lib),'AbilitySystem library unavailable')
 local asc=lib:GetAbilitySystemComponent(pawn);assert(valid(asc),'Local AbilitySystem unavailable')
 local attrs
 for i=1,math.min(#asc.SpawnedAttributes,16)do
  local item=asc.SpawnedAttributes[i]
  if valid(item)and item:IsA('/Script/CharacterBasics.BasicAttributeSet')then attrs=item;break end
 end
 assert(valid(attrs),'BasicAttributeSet unavailable on local player')
 local maximum=attrs.UltimateChargeCount_Max.CurrentValue
 assert(finite(maximum)and maximum>=1 and maximum<=99,'Invalid ultimate capacity; refill refused')
 local before=attrs.UltimateChargeCount.CurrentValue
 assert(finite(before)and finite(attrs.UltimateChargeCount.BaseValue),'Unexpected attribute layout')
 if math.abs(before-maximum)<.001 then return {before=before,after=before,maximum=maximum,changed=false}end
 local cls=StaticFindObject('/Script/SGameUtils.GEAR_AttributeRange')
 assert(valid(cls)and cls:IsClass(),'Native attribute carrier unavailable')
 local carrier=StaticConstructObject(cls,pawn);assert(valid(carrier),'Cannot construct local attribute descriptor')
 local prop=carrier:Reflection():GetProperty('Attribute');assert(valid(prop),'Reflected attribute property unavailable')
 local descriptor='(AttributeName="UltimateChargeCount",Attribute="/Script/CharacterBasics.BasicAttributeSet:UltimateChargeCount",AttributeOwner="/Script/CharacterBasics.BasicAttributeSet")'
 prop:ImportText(descriptor,prop:ContainerPtrToValuePtr(carrier),0,carrier)
 local attribute=carrier.Attribute
 local raw=attribute.AttributeName;local name=type(raw)=='string'and raw or raw:ToString()
 assert(name=='UltimateChargeCount','Attribute import name mismatch')
 assert(valid(attribute.AttributeOwner)and attribute.AttributeOwner:GetFullName()=='Class /Script/CharacterBasics.BasicAttributeSet','Attribute owner import failed')
 local validate=StaticFindObject('/Script/GameplayAbilities.AbilitySystemBlueprintLibrary:IsValid')
 assert(valid(validate)and validate(lib,attribute)==true,'Native attribute field did not resolve')
 local utility=StaticFindObject('/Script/SGameAttributes.Default__AttributeUtils')
 local modify=StaticFindObject('/Script/SGameAttributes.AttributeUtils:ModifyCharacterAttributeValue')
 assert(valid(utility)and valid(modify),'Native attribute modifier unavailable')
 -- Resolve player identity again immediately before the only native mutation.
 assert(context.isPlayer(pawn)and pc.Pawn:GetAddress()==pawn:GetAddress(),'Local player changed during refill')
 modify(utility,pawn,attribute,3,maximum)
 local after=attrs.UltimateChargeCount.CurrentValue
 assert(finite(after)and math.abs(after-maximum)<.001,'Native ultimate readback differs from capacity')
 return {before=before,after=after,maximum=maximum,changed=true}
end
return M
