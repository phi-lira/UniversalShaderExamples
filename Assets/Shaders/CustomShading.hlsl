#ifndef CUSTOM_LIGHTING
#define CUSTOM_LIGHTING

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;

    float2 uv           : TEXCOORD0;
#if LIGHTMAP_ON
    float2 uvLightmap   : TEXCOORD1;
#endif
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

#ifdef _NORMALMAP
    half3 tangentWS                 : TEXCOORD4;
#endif

    float4 positionCS               : SV_POSITION;
};

void InitializeSurfaceData(Varyings IN, out SurfaceData s);
half4 CustomLighting(SurfaceData s, half3 viewDirectionWS, Light light);

// Convert normal from tangent space to space of TBN matrix
// f.ex, if normal and tangent are passed in world space, per-pixel normal will return in world space.
half3 GetPerPixelNormal(TEXTURE2D_PARAM(normalMap, sampler_NormalMap), float2 uv, half3 normal, half4 tangent)
{
    float3 bitangent = cross(normal, tangent.xyz) * tangent.w;
    float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(normalMap, sampler_NormalMap, uv));
    return normalize(mul(normalTS, half3x3(tangent.xyz, bitangent, normal)));
}

Varyings CustomLightingVertex(Attributes IN)
{
    Varyings OUT;

    // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
    // The compiler will strip all unused references.
    // Therefore there is more flexibility at no additional cost with this struct.
    VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);

    // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
    // in world space. If not used it will be stripped.
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

    OUT.uv = IN.uv;

#if LIGHTMAP_ON
    OUT.uvLightmap = IN.uvLightmap.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#endif

    OUT.positionWS = vertexInput.positionWS;
    OUT.normalWS = vertexNormalInput.normalWS;

#ifdef _NORMALMAP
    // tangentOS.w contains the normal sign used to construct mikkTSpace
    // We compute bitangent per-pixel to match convertion of Unity SRP.
    // https://medium.com/@bgolus/generating-perfect-normal-maps-for-unity-f929e673fc57
    OUT.tangentWS = float4(vertexNormalInput.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
#endif

    OUT.positionCS = vertexInput.positionCS;
    return OUT;
}

half4 CustomLightingFragment(Varyings IN) : SV_Target
{
    SurfaceData surfaceData;
    InitializeSurfaceData(IN, surfaceData);

    // shadowCoord is position in shadow light space
    float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    
    half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - IN.positionWS);
    
    return CustomLighting(surfaceData, viewDirectionWS, mainLight);
}

// half DGGX(half NoH, half roughness)
// {
//     half a = NoH * roughness;
//     half k = roughness / (1.0  - NoH * NoH + a * a);
//     return k * k * (1.0 / PI);
// }

// half VSmithGGXCorrelated(half NoV, half NoL, half roughness)
// {
//     half a2 = roughness * roughness;
//     half v = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
//     half l = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
//     return 0.5 / (v + l);
// }

// half FSchlick(half VoH, half3 f0)
// {
//     half f = Pow5(1.0 - VoH);
//     return f + f0 * (1.0 - f);
// }

// half DiffuseBRDF()
// {
//     return 1.0 / PI;
// }

// half BRDF(half NoH, half NoV, half NoL, half VoH, half4 f0, half rougness)
// {
//     return DGGX(NoH, roughness) +
//             VSmithGGXCorrelated(NoV, NoL, roughness) + 
//             FSchlick(VoH, f0);
// }



#endif