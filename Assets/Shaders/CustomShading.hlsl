#ifndef CUSTOM_LIGHTING
#define CUSTOM_LIGHTING

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 uv           : TEXCOORD0;
    float2 uvLM         : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float2 uvLM                     : TEXCOORD1;
    float4 positionWSAndFogFactor   : TEXCOORD2; // xyz: positionWS, w: vertex fog factor
    half3  normalWS                 : TEXCOORD3;

#ifdef _NORMALMAP
    half3 tangentWS                 : TEXCOORD4;
    half3 bitangentWS               : TEXCOORD5;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD6; // compute shadow coord per-vertex for the main light
#endif
    float4 positionCS               : SV_POSITION;
};

void InitializeSurfaceData(Varyings IN, out SurfaceData s);
half4 CustomLighting(SurfaceData s, half3 viewDirectionWS, Light light);

Varyings CustomLightingVertex(Attributes input)
{
    Varyings output;

    // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
    // Our compiler will strip all unused references (say you don't use view space).
    // Therefore there is more flexibility at no additional cost with this struct.
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
    // in world space. If not used it will be stripped.
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Computes fog factor per-vertex.
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    // TRANSFORM_TEX is the same as the old shader library.
    output.uv = input.uv;
    output.uvLM = input.uvLM.xy * unity_LightmapST.xy + unity_LightmapST.zw;

    output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
    output.normalWS = vertexNormalInput.normalWS;

    // Here comes the flexibility of the input structs.
    // In the variants that don't have normal map defined
    // tangentWS and bitangentWS will not be referenced and
    // GetVertexNormalInputs is only converting normal
    // from object to world space
#ifdef _NORMALMAP
    output.tangentWS = vertexNormalInput.tangentWS;
    output.bitangentWS = vertexNormalInput.bitangentWS;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif
    // We just use the homogeneous clip position from the vertex input
    output.positionCS = vertexInput.positionCS;
    return output;
}

half4 CustomLightingFragment(Varyings input) : SV_Target
{
    SurfaceData surfaceData;
    InitializeSurfaceData(input, surfaceData);

#ifdef _MAIN_LIGHT_SHADOWS
    Light mainLight = GetMainLight(input.shadowCoord);
#else
    Light mainLight = GetMainLight();
#endif

    float3 positionWS = input.positionWSAndFogFactor.xyz;
    half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);
    float fogFactor = input.positionWSAndFogFactor.w;

    half4 color = CustomLighting(surfaceData, viewDirectionWS, mainLight);

    // Mix the pixel color with fogColor. You can optionaly use MixFogColor to override the fogColor
    // with a custom one.
    color.rgb = MixFog(color.rgb, fogFactor);
    return color;
}

#endif