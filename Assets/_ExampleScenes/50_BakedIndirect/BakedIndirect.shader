Shader "Universal Render Pipeline/Custom/BakedIndirect"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" {}
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _AmbientOcclusion("AmbientOcclusion", Range(0, 1)) = 1.0    
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline"}

        // Include material cbuffer for all passes. 
        // The cbuffer has to be the same for all passes to make this shader SRP batcher compatible.
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        // -------------------------------------
        // Material variables. They need to be declared in UnityPerMaterial
        // to be able to be cached by SRP Batcher
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half _AmbientOcclusion;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            // SurfaceVertex and SurfaceFragment must be used if you are including CustomShading.hlsl
            #pragma vertex SurfaceVertex
            #pragma fragment SurfaceFragment
            
            // Defines a custom lighting function
            #define CUSTOM_LIGHTING_FUNCTION BakedIndirectLighting

            // -------------------------------------
            // Universal Render Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            // Declared SurfaceVertex and SurfaceFragment shaders
            // -------------------------------------
            // Include custom shading helper to create vertex and fragment functions
            // You must declare above SurfaceVertex and SurfaceFragment
            #include "../CustomShading.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            void SurfaceFunction(Varyings IN, out SurfaceData surfaceData)
            {
                float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                
                surfaceData = (SurfaceData)0;
                surfaceData.diffuse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
                surfaceData.ao = _AmbientOcclusion;
#ifdef _NORMALMAP
                surfaceData.normalWS = GetPerPixelNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS);
#else
                surfaceData.normalWS = normalize(IN.normalWS);
#endif
                surfaceData.alpha = 1.0;
            }

            half4 BakedIndirectLighting(SurfaceData surfaceData, LightingData lightingData)
            {
                return half4(surfaceData.diffuse + lightingData.environmentLighting, surfaceData.alpha);
            }
            ENDHLSL
        }

        // Used for rendering shadowmaps
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}