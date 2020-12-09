#ifndef CUSTOM_SHADING
#define CUSTOM_SHADING

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 uv           : TEXCOORD0;
    float2 uvLightmap   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
#if LIGHTMAP_ON
    float2 uvLightmap               : TEXCOORD1;
#endif
    float3 positionWS               : TEXCOORD2;
    half3  normalWS                 : TEXCOORD3;
    half4  tangentWS                : TEXCOORD4;
    float4 positionCS               : SV_POSITION;
};

// User defined surface data.
struct CustomSurfaceData
{
    half3 diffuse;              // diffuse color. should be black for metals.
    half3 reflectance;          // reflectance color at normal indicence. It's monochromatic for dieletrics.
    half3 normalWS;             // normal in world space
    half  ao;                   // ambient occlusion
    half  roughness;            // roughness = perceptualRoughness * perceptualRoughness;
    half3 emission;             // emissive color
    half  alpha;                // 0 for transparent materials, 1.0 for opaque.
};

struct LightingData 
{
    Light light;
    half3 halfDirectionWS;
    half3 normalWS;
    half NdotL;
    half NdotH;
    half LdotH;
};

half3 EnvironmentBRDF(half3 f0, half roughness, half NdotV)
{
#if 1
    // Adapted from Unity Environment BDRF Approximation
    // mmikk
    half fresnelTerm = Pow4(1.0 - NdotV);
    half3 grazingTerm = saturate((1.0 - roughness) + f0);

    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
    return lerp(f0, grazingTerm, fresnelTerm) * surfaceReduction;
#else
    // Brian Karis - Physically Based Shading in Mobile
    const half4 c0 = { -1, -0.0275, -0.572, 0.022 };
    const half4 c1 = { 1, 0.0425, 1.04, -0.04 };
    half4 r = roughness * c0 + c1;
    half a004 = min( r.x * r.x, exp2( -9.28 * NdotV ) ) * r.x + r.y;
    half2 AB = half2( -1.04, 1.04 ) * a004 + r.zw;
    return f0 * AB.x + AB.y;
    return half3(0, 0, 0);
#endif
}

half3 GlossyEnvironmentReflection(half3 reflectVector, half perceptualRoughness)
{
    half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);

    //TODO:DOTS - we need to port probes to live in c# so we can manage this manually.
    #if defined(UNITY_USE_NATIVE_HDR) || defined(UNITY_DOTS_INSTANCING_ENABLED)
    half3 irradiance = encodedIrradiance.rgb;
    #else
    half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
    #endif

    return irradiance;
}

// Convert normal from tangent space to space of TBN matrix
// f.ex, if normal and tangent are passed in world space, per-pixel normal will return in world space.
half3 GetPerPixelNormal(TEXTURE2D_PARAM(normalMap, sampler_NormalMap), float2 uv, half3 normal, half4 tangent)
{
    half3 bitangent = cross(normal, tangent.xyz) * tangent.w;
    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(normalMap, sampler_NormalMap, uv));
    return normalize(mul(normalTS, half3x3(tangent.xyz, bitangent, normal)));
}

// Convert normal from tangent space to space of TBN matrix and apply scale to normal
half3 GetPerPixelNormalScaled(TEXTURE2D_PARAM(normalMap, sampler_NormalMap), float2 uv, half3 normal, half4 tangent, half scale)
{
    half3 bitangent = cross(normal, tangent.xyz) * tangent.w;
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(normalMap, sampler_NormalMap, uv), scale);
    return normalize(mul(normalTS, half3x3(tangent.xyz, bitangent, normal)));
}

// Kelemen 2001, "A Microfacet Based Coupled Specular-Matte BRDF Model with Importance Sampling"
// TODO - Move to Core or switch Visibility term?
real V_Kelemen(real LoH) 
{
    real x = 0.25 / (LoH * LoH);
    #if defined (SHADER_API_MOBILE)
    return min(x, 65504.0);
    #else
    return x;
    #endif
}

#endif