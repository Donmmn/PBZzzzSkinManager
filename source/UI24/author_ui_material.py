"""UI-only exposure/tone mapping; no surface or character shader is changed."""
import unreal
root='/HuaShira/Mods/PBZWardrobe/UI/v2';lib=unreal.MaterialEditingLibrary
name='M_CharacterComposite'
m=unreal.load_asset(root+'/'+name)
if not m:m=unreal.AssetToolsHelpers.get_asset_tools().create_asset(name,root,unreal.Material,unreal.MaterialFactoryNew())
assert m;lib.delete_all_material_expressions(m)
m.set_editor_property('material_domain',unreal.MaterialDomain.MD_UI)
m.set_editor_property('blend_mode',unreal.BlendMode.BLEND_TRANSLUCENT)
tex=lib.create_material_expression(m,unreal.MaterialExpressionTextureSampleParameter2D,0,0)
tex.set_editor_property('parameter_name','CharacterTexture')
default=unreal.load_asset(root+'/T_CompositeDefault')
if not default:default=unreal.EditorAssetLibrary.duplicate_asset('/Engine/EngineResources/WhiteSquareTexture',root+'/T_CompositeDefault')
default.set_editor_property('srgb',False);unreal.EditorAssetLibrary.save_asset(root+'/T_CompositeDefault')
tex.set_editor_property('texture',default);tex.set_editor_property('sampler_type',unreal.MaterialSamplerType.SAMPLERTYPE_LINEAR_COLOR)
inv=lib.create_material_expression(m,unreal.MaterialExpressionOneMinus,240,160)
assert lib.connect_material_expressions(tex,'A',inv,'');lib.connect_material_property(inv,'',unreal.MaterialProperty.MP_OPACITY)
custom=lib.create_material_expression(m,unreal.MaterialExpressionCustom,500,0)
custom.set_editor_property('output_type',unreal.CustomMaterialOutputType.CMOT_FLOAT3)
inputs=[]
for name in ['Color','Gain','Tone','ShadowGamma']:
 item=unreal.CustomInput();item.set_editor_property('input_name',name);inputs.append(item)
custom.set_editor_property('inputs',inputs)
custom.set_editor_property('code','float3 x=max(Color*Gain,0); float3 t=pow(x/(1+x),max(ShadowGamma,0.1)); return lerp(x,t,saturate(Tone));')
assert lib.connect_material_expressions(tex,'RGB',custom,'Color')
for i,(name,value,pin)in enumerate([('Exposure',1.,'Gain'),('ToneEnabled',0.,'Tone'),('ShadowGamma',.8,'ShadowGamma')]):
 node=lib.create_material_expression(m,unreal.MaterialExpressionScalarParameter,100,-180-i*90)
 node.set_editor_property('parameter_name',name);node.set_editor_property('default_value',value)
 assert lib.connect_material_expressions(node,'',custom,pin)
assert lib.connect_material_property(custom,'',unreal.MaterialProperty.MP_EMISSIVE_COLOR)
lib.recompile_material(m);unreal.EditorAssetLibrary.save_asset(root+'/M_CharacterComposite',only_if_is_dirty=False)
print('WARDROBE_UI_V2_AUTHORED',m.get_path_name())
