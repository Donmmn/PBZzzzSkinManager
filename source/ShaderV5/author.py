from pathlib import Path
import unreal,json
R=Path(__file__).resolve().parent
lib=unreal.MaterialEditingLibrary
root='/HuaShira/Mods/PBZWardrobe/ThickPaint/v5'
code=(R/'PBZ_Stylized.hlsl').read_text(encoding='utf-8')
def node(m,cls):return lib.create_material_expression(m,cls,0,0)
def connect(a,out,b,pin):
 names=[str(x)for x in lib.get_material_expression_input_names(b)]
 matches=[x for x in names if x.replace(' ','').replace('_','').lower()==pin.replace(' ','').replace('_','').lower()]
 actual=matches[0]if matches else pin
 assert lib.connect_material_expressions(a,out,b,actual),(out,pin,names)
def scalar(m,name,v):
 n=node(m,unreal.MaterialExpressionScalarParameter);n.set_editor_property('parameter_name',name);n.set_editor_property('default_value',v);return n
def vector(m,name,v):
 n=node(m,unreal.MaterialExpressionVectorParameter);n.set_editor_property('parameter_name',name);n.set_editor_property('default_value',unreal.LinearColor(*v));return n
report={}
for blend in [False,True]:
 name='M_PBZPaintBlend' if blend else 'M_PBZPaintMask'
 m=unreal.load_asset(root+'/'+name)
 if not m:m=unreal.AssetToolsHelpers.get_asset_tools().create_asset(name,root,unreal.Material,unreal.MaterialFactoryNew())
 assert m;lib.delete_all_material_expressions(m)
 for prop,val in dict(material_domain=unreal.MaterialDomain.MD_SURFACE,blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT if blend else unreal.BlendMode.BLEND_MASKED,shading_model=unreal.MaterialShadingModel.MSM_UNLIT,two_sided=True,opacity_mask_clip_value=.35,used_with_skeletal_mesh=True,used_with_morph_targets=True,used_with_clothing=True,automatically_set_usage_in_editor=False).items():m.set_editor_property(prop,val)
 tex=node(m,unreal.MaterialExpressionTextureSampleParameter2D);tex.set_editor_property('parameter_name','BaseColorTexture');tex.set_editor_property('texture',unreal.load_asset('/Engine/EngineResources/WhiteSquareTexture'));tex.set_editor_property('sampler_type',unreal.MaterialSamplerType.SAMPLERTYPE_COLOR)
 factor=vector(m,'BaseColorFactor',(.8,.8,.8,1))
 a=node(m,unreal.MaterialExpressionMultiply);connect(tex,'RGB',a,'A');connect(factor,'RGB',a,'B')
 alpha=node(m,unreal.MaterialExpressionMultiply);connect(tex,'A',alpha,'A');connect(factor,'A',alpha,'B')
 c=node(m,unreal.MaterialExpressionCustom);c.set_editor_property('code',code);c.set_editor_property('output_type',unreal.CustomMaterialOutputType.CMOT_FLOAT3)
 vals={'A':a,'N':node(m,unreal.MaterialExpressionPixelNormalWS),'V':node(m,unreal.MaterialExpressionCameraVectorWS),'T':node(m,unreal.MaterialExpressionVertexTangentWS),'SunDir':node(m,unreal.MaterialExpressionSkyAtmosphereLightDirection)}
 vals.update({k:vector(m,p,v)for k,p,v in [('LightDir','PaintLightDirection',(.25,-.45,.85,0)),('ShadowTint','PaintShadowTint',(.83,.84,.97,1)),('LightTint','PaintLightTint',(1.025,1,.97,1))]})
 vals.update({k:scalar(m,p,v)for k,p,v in [('Brightness','PaintBrightness',.30),('Saturation','PaintSaturation',1.02),('BandSoftness','PaintBandSoftness',.035),('HighlightStrength','PaintHighlight',.065),('HairHighlight','PaintHairHighlight',.12),('HairFlow','PaintHairFlow',1),('RimStrength','PaintRim',.035),('InkStrength','PaintInk',.08),('SurfaceType','PaintSurfaceType',0),('PBZStyle','PBZPaintStyle',1)]})
 inputs=[]
 for k in vals:
  i=unreal.CustomInput();i.set_editor_property('input_name',k);inputs.append(i)
 c.set_editor_property('inputs',inputs)
 for k,n in vals.items():connect(n,'',c,k)
 exposure=node(m,unreal.MaterialExpressionEyeAdaptationInverse);connect(c,'',exposure,'LightValueInput');connect(scalar(m,'PaintExposureCompensation',1),'',exposure,'AlphaInput')
 assert lib.connect_material_property(exposure,'',unreal.MaterialProperty.MP_EMISSIVE_COLOR)
 assert lib.connect_material_property(alpha,'',unreal.MaterialProperty.MP_OPACITY if blend else unreal.MaterialProperty.MP_OPACITY_MASK)
 lib.recompile_material(m);unreal.EditorAssetLibrary.save_asset(root+'/'+name,only_if_is_dirty=False)
 report[name]={'path':m.get_path_name(),'inputs':list(vals),'skeletal':m.get_editor_property('used_with_skeletal_mesh'),'clothing':m.get_editor_property('used_with_clothing')}
(R/'reports/author.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PBZ_ZZZ_V5_AUTHORING_COMPLETE')
