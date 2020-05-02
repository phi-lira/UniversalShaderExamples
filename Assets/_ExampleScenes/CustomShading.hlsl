#ifndef CUSTOM_SHADING
#define CUSTOM_SHADING

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"

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
    float2 uvLightmap               : TEXCOORD1;
    float3 positionWS               : TEXCOORD2;
    half3  normalWS                 : TEXCOORD3;

#ifdef _NORMALMAP
    half4 tangentWS                 : TEXCOORD4;
#endif

    float4 positionCS               : SV_POSITION;
};

// User defined surface data.
struct SurfaceData
{
    half3 diffuse;      // diffuse color. should be black for metals.
    half3 reflectance;  // reflectance color at normal indicence. It's monochromatic for dieletrics.
    half3 normalWS;     // normal in world space
    half  ao;           // ambient occlusion
    half  roughness;    // roughness
    half3 emission;     // emissive color
    half  alpha;        // 0 for transparent materials, 1.0 for opaque.
};

struct LightingData 
{
    Light light;
    half3 environmentLighting;
    half3 environmentReflections;
    half3 halfVector;
    half3 viewDirectionWS;
    half NdotL;
    half NdotV;
    half NdotH;
    half VdotH;
};

// Forward declaration of SurfaceFunction. This function must be implemented in the shader
void SurfaceFunction(Varyings IN, out SurfaceData surfaceData);

// Convert normal from tangent space to space of TBN matrix
// f.ex, if normal and tangent are passed in world space, per-pixel normal will return in world space.
half3 GetPerPixelNormal(TEXTURE2D_PARAM(normalMap, sampler_NormalMap), float2 uv, half3 normal, half4 tangent)
{
    half3 bitangent = cross(normal, tangent.xyz) * tangent.w;
    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(normalMap, sampler_NormalMap, uv));
    return normalize(mul(normalTS, half3x3(tangent.xyz, bitangent, normal)));
}

// defined in latest URP
#if SHADER_LIBRARY_VERSION_MAJOR < 9
// Computes the world space view direction (pointing towards the viewer).
float3 GetWorldSpaceViewDir(float3 positionWS)
{
    if (unity_OrthoParams.w == 0)
    {
        // Perspective
        return _WorldSpaceCameraPos - positionWS;
    }
    else
    {
        // Orthographic
        float4x4 viewMat = GetWorldToViewMatrix();
        return viewMat[2].xyz;
    }
}
#endif

// Adapted from Unity Environment BDRF Approximation
half3 EnvironmentBRDF(half3 f0, half roughness, half NdotV)
{
    half fresnelTerm = Pow4(1.0 - NdotV);
    half grazingTerm = saturate((1.0 - roughness) + f0);

    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
    return lerp(f0, grazingTerm, fresnelTerm) * surfaceReduction;
}

#ifdef CUSTOM_LIGHTING_FUNCTION
    half4 CUSTOM_LIGHTING_FUNCTION(SurfaceData surfaceData, LightingData lightingData);
#else
    half4 CUSTOM_LIGHTING_FUNCTION(SurfaceData surfaceData, LightingData lightingData)
    {
        half3 environmentReflection = lightingData.environmentReflections;
        environmentReflection *= EnvironmentBRDF(surfaceData.reflectance, surfaceData.roughness, lightingData.NdotV);

        half3 environmentLighting = lightingData.environmentLighting * surfaceData.diffuse;

        half3 diffuse = surfaceData.diffuse * Lambert();
        
        // CookTorrance
        // inline D_GGX + V_SmithJoingGGX for better code generations
        half DV = DV_SmithJointGGX(lightingData.NdotH, lightingData.NdotL, lightingData.NdotV, surfaceData.roughness);
        half3 F = F_Schlick(surfaceData.reflectance, lightingData.VdotH);
        half3 specular = DV * F;
        half3 finalColor = (diffuse + specular) * lightingData.light.color * lightingData.NdotL;
        finalColor += environmentReflection + environmentLighting;
        return half4(finalColor, surfaceData.alpha);
    }
#endif

Varyings SurfaceVertex(Attributes IN)
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

half4 SurfaceFragment(Varyings IN) : SV_Target
{
    SurfaceData surfaceData;
    SurfaceFunction(IN, surfaceData);

    LightingData lightingData;

    half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.positionWS));
    half3 reflectVector = reflect(-viewDirectionWS, surfaceData.normalWS);
                
    // shadowCoord is position in shadow light space
    float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
    Light light = GetMainLight(shadowCoord);
    lightingData.light = light;
    lightingData.environmentLighting = SAMPLE_GI(IN.uvLightmap, SampleSH(surfaceData.normalWS), surfaceData.normalWS) * surfaceData.ao;
    lightingData.environmentReflections = GlossyEnvironmentReflection(reflectVector, sqrt(surfaceData.roughness), surfaceData.ao);
    lightingData.halfVector = normalize(light.direction + viewDirectionWS);
    lightingData.viewDirectionWS = viewDirectionWS;
    lightingData.NdotL = saturate(dot(surfaceData.normalWS, light.direction));
    lightingData.NdotV = saturate(dot(surfaceData.normalWS, lightingData.viewDirectionWS)) + HALF_MIN;
    lightingData.NdotH = saturate(dot(surfaceData.normalWS, lightingData.halfVector));
    lightingData.VdotH = saturate(dot(viewDirectionWS, lightingData.halfVector));

    return CUSTOM_LIGHTING_FUNCTION(surfaceData, lightingData);
}

#endif