Shader "Universal Render Pipeline/Custom/Lit"
{
    // TODO: I need to support custom shader inspector for this to hide
    // scale/offset for normal map using NoScaleOffset.
    Properties
    {
        [Header(Surface)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        [Toggle(_MASKMAP)]_EnableMaskMap("Metallic and Smoothness Map", Float) = 0.0
        _MaskMap("Metallic + Smoothness", 2D) = "white" {} 

        // TODO: Pack the following into a half4 and add support to mask map
        // splitting now as I've not implemented custom shader editor yet and
        // this will make it look nices in the UI
        _Metallic("Metallic", Range(0, 1)) = 1.0
        _AmbientOcclusion("AmbientOcclusion", Range(0, 1)) = 1.0
        _DieletricF0("Dieletric F0", Range(0.0, 0.16)) = 0.04
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

        [Header(Normals)]
        [Toggle(_NORMALMAP)] _EnableNormalMap("PerPixelNormals", Float) = 0.0
        [Normal][NoScaleOffset]_NormalMap("Normal Map", 2D) = "bump" {}

        [Header(Emission)]
        [HDR]_Emission("Emission Color", Color) = (0,0,0,1)
    }

    SubShader
    {
        Tags{"RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP

            // -------------------------------------
            // Include custom shading helper to create vertex and fragment functions
            #include "CustomShading.hlsl"

            // -------------------------------------
            // Material variables. They need to be declared in UnityPerMaterial
            // to be able to be cached by SRP Batcher
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _Metallic;
            half _AmbientOcclusion;
            half _DieletricF0;
            half _Smoothness;
            half4 _Emission;
            CBUFFER_END

            // -------------------------------------
            // Textures are declared in global scope
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);

            #define CUSTOM_LIGHTING_FUNCTION MyCustomLightingFunction

            void SurfaceFunction(Varyings IN, out SurfaceData surfaceData)
            {
                float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half4 maskMap = half4(1, 1, 1, 1);
#ifdef _MASKMAP
                maskMap = SAMPLER_TEXTURE2D(_MaskMap, sampler_BaseMap, IN.uv);    
#endif

                half metallic = maskMap.r * _Metallic;
                half roughness = PerceptualSmoothnessToRoughness(maskMap.a * _Smoothness);
                
                // diffuse color is black for metals and baseColor for dieletrics
                surfaceData.diffuse = ComputeDiffuseColor(baseColor.rgb, metallic);

                // f0 is reflectance at normal incidence. we store f0 in baseColor for metals.
                // for dieletrics f0 is monochromatic and stored in dieletricF0.                
                surfaceData.f0 = ComputeFresnel0(baseColor.rgb, metallic, _DieletricF0);
                surfaceData.ao = _AmbientOcclusion;
                surfaceData.roughness = roughness;
#ifdef _NORMALMAP
                surfaceData.normalWS = GetPerPixelNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS);
#else
                surfaceData.normalWS = normalize(IN.normalWS);
#endif
                surfaceData.emission = _Emission.rgb;
                surfaceData.alpha = baseColor.a;
            }

            ENDHLSL
        }

        // TODO: This is currently breaking SRP batcher as these passes don't use the same UnityPerMaterial
        // as the main one. Maybe we can add a DECLARE_PASS macro?
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }

    HLSLINCLUDE
    // -------------------------------------
    // Universal Render Pipeline keywords
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_ON

    #pragma vertex CustomLightingVertex
    #pragma fragment CustomLightingFragment

    ENDHLSL
}