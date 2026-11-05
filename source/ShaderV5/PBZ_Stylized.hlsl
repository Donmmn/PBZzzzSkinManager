// Original PBZ character NPR, informed by the linked single-frame ZZZ analysis.
// No proprietary shader, LUT or control texture is copied. Surface slots supply
// the available region information; we do not invent MMD control-map channels.
float3 n = normalize(N + 1e-6);
float3 v = normalize(V + 1e-6);
float3 l = normalize(LightDir.xyz + 1e-6);
if (dot(SunDir,SunDir)>0.15) l=normalize(SunDir);
float eye=1-step(0.4,abs(SurfaceType-3));
float hair=1-step(0.4,abs(SurfaceType-2));
float face=1-step(0.4,abs(SurfaceType-1));
float exposedSkin=1-step(0.4,abs(SurfaceType-4));
float skin=max(face,exposedSkin);
float3 a=max(A,0);
float y=dot(a,float3(.2126,.7152,.0722));
a=max(lerp(y.xxx,a,clamp(Saturation,0,1.25)),0);

// Large stable light shapes, with derivative-softened thresholds rather than
// high frequency UV random noise (which crawls over moving clothing).
float halfLambert=dot(n,l)*.5+.5;
float softness=max(max(BandSoftness,.012),fwidth(halfLambert)*.65);
softness=lerp(softness,max(softness,.105),skin);
float diffuse=smoothstep(.47-softness,.47+softness,halfLambert);
float top=smoothstep(.84-softness,.84+softness,halfLambert);
float floorValue=lerp(.53,.80,skin);
floorValue=lerp(floorValue,.57,hair);

// Independent shadow color: a small chroma shift, not a universal grey tint.
// This is an art-directed approximation, not the article's captured HSV code.
float3 tint=lerp(ShadowTint.rgb,float3(1.025,.89,.925),skin);
float3 shadow=a*tint*floorValue;
float shadowY=dot(shadow,float3(.2126,.7152,.0722));
shadow=max(lerp(shadowY.xxx,shadow,1.10),0);
float3 lit=a*LightTint.rgb;
float3 color=lerp(shadow,lit*.96,diffuse);
color=lerp(color,lit*1.025,top*.22*(1-skin));

float3 h=normalize(l+v+1e-6);
// Cloth gets broad, bounded highlights. Face/skin avoid plastic specular blobs.
float spec=pow(saturate(dot(n,h)),12);
float shape=smoothstep(.48,.67,spec);
color+=a*shape*HighlightStrength*(1-hair)*lerp(1,.10,skin)*diffuse;

// Strand tangent is derived from the mesh UV frame. Flow is editable because
// MMD UV tangent axes are not guaranteed to follow the authored hair strands.
float3 t=T-dot(T,n)*n;
float safeT=step(1e-7,dot(t,t));
t=normalize(t+float3(1e-6,0,0));
float3 b=normalize(cross(n,t)+1e-6);
float3 strand=normalize(lerp(t,b,saturate(HairFlow))+.12*n);
float th=clamp(dot(strand,h),-1,1);
float strandSpec=pow(saturate(1-th*th),24);
float hairAA=max(.02,fwidth(strandSpec)*.7);
float ribbon=smoothstep(.55-hairAA,.55+hairAA,strandSpec);
color+=a*ribbon*HairHighlight*hair*safeT*lerp(.30,1,diffuse);

// A restrained light-facing rim: it is a shading accent, not inverted-hull ink.
float grazing=1-saturate(abs(dot(n,v)));
float rim=smoothstep(.68,.94,grazing)*smoothstep(.02,.5,dot(n,l));
color+=a*rim*RimStrength*lerp(1,.25,skin);
float ink=smoothstep(.965,.995,grazing)*InkStrength*(1-skin*.85);
color*=1-ink;

// Iris/eye whites retain their painted values. No alpha is multiplied here:
// coverage stays in the existing masked/translucent material connection.
color=lerp(color,a,eye);
color=max(color,0);
// Luminance soft knee bounds highlights without shifting hue or clipping white
// clothing to featureless RGB. EyeAdaptationInverse remains outside this node.
float lum=dot(color,float3(.2126,.7152,.0722));
float over=max(lum-.85,0);
float compressed=min(lum,.85)+.25*over/(over+.25);
color*=compressed/max(lum,1e-5);
return color*max(Brightness,0)*max(PBZStyle,0);
