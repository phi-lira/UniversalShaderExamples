Shader "Universal Render Pipeline/Custom/BakedIndirect"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" {}
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _AmbientOcclusion("AmbientOcclusion", Range(0, 1)) = 1.0    
    }
    
    
    
    Subshader
{
Tags{"RenderPipeline" = "UniversalRenderPipeline"}
HLSLINCLUDE

        // Defines a custom lighting function
        #define CUSTOM_GI_FUNCTION GlobalIllumination
        #define CUSTOM_LIGHTING_FUNCTION BakedIndirectLighting
                
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/CustomShading.hlsl"


        // -------------------------------------
        // Material variables. They need to be declared in UnityPerMaterial
        // to be able to be cached by SRP Batcher
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half _AmbientOcclusion;
        CBUFFER_END

        // -------------------------------------
        // Textures are declared in global scope
        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);

        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);

        void SurfaceFunction(Varyings IN, out CustomSurfaceData surfaceData)
        {
            float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
            
            surfaceData = (CustomSurfaceData)0;
            surfaceData.diffuse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
            surfaceData.ao = _AmbientOcclusion;
#ifdef _NORMALMAP
            surfaceData.normalWS = GetPerPixelNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS);
#else
            surfaceData.normalWS = normalize(IN.normalWS);
#endif
            surfaceData.alpha = 1.0;
        }

        half3 BakedIndirectLighting(CustomSurfaceData surfaceData, LightingData lightingData, half3 viewDirectionWS)
        {
            return half3(0, 0, 0);
        }
        
        half3 GlobalIllumination(CustomSurfaceData surfaceData, half3 environmentLighting, half3 environmentReflections, half3 viewDirectionWS)
        {
            return surfaceData.diffuse + environmentLighting * surfaceData.ao;
        }
    
ENDHLSL
Pass
{
    Name "ForwardLit"
    Tags{"LightMode" = "UniversalForward"}

    Blend One Zero
    ZWrite On
    Cull Back
   
    HLSLPROGRAM

    #pragma vertex SurfaceVertex
    #pragma fragment SurfaceFragment

    // -------------------------------------
    // Universal Render Pipeline keywords
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_ON
    
    ENDHLSL
}
Pass
{
    Name "DepthOnly"
    Tags{"LightMode" = "DepthOnly"}

    Blend One Zero
    ZWrite On
    ColorMask 0
    Cull Back

    HLSLPROGRAM
    
    #pragma vertex SurfaceVertex
    #pragma fragment SurfaceFragmentDepthOnly

    // -------------------------------------
    // Universal Render Pipeline keywords
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_ON
    
    ENDHLSL
}
Pass
{
    Name "ShadowCaster"
    Tags{"LightMode" = "ShadowCaster"}

    Blend One Zero
    ZWrite On
    ColorMask 0
    Cull Back

    HLSLPROGRAM
    
    #pragma vertex SurfaceVertexShadowCaster
    #pragma fragment SurfaceFragmentDepthOnly

    // -------------------------------------
    // Universal Render Pipeline keywords
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_ON
    
    ENDHLSL
}
}


}