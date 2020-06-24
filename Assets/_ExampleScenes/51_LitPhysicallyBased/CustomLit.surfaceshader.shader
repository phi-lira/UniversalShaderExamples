Shader "Universal Render Pipeline/Custom/SurfaceLit"
{
    Properties
    {
        [Header(Surface)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        // TODO: Pack the following into a half4 and add support to mask map
        // splitting now as I've not implemented custom shader editor yet and
        // this will make it look nices in the UI
        _Metallic("Metallic", Range(0, 1)) = 1.0
        [NoScaleOffset]_MetallicSmoothnessMap("MetalicMap", 2D) = "white" {}
        _AmbientOcclusion("AmbientOcclusion", Range(0, 1)) = 1.0
        [NoScaleOffset]_AmbientOcclusionMap("AmbientOcclusionMap", 2D) = "white" {}
        _Reflectance("Reflectance for dieletrics", Range(0.0, 1.0)) = 0.5
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

        [Toggle(_NORMALMAP)] _EnableNormalMap("Enable Normal Map", Float) = 0.0
        [Normal][NoScaleOffset]_NormalMap("Normal Map", 2D) = "bump" {}
        _NormalMapScale("Normal Map Scale", Float) = 1.0

        [Header(Emission)]
        [HDR]_Emission("Emission Color", Color) = (0,0,0,1)
    }
    
    
    
    Subshader
{
Tags{"RenderPipeline" = "UniversalRenderPipeline"}
HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/CustomShading.hlsl"


        // -------------------------------------
        // Material Keywords
        #pragma shader_feature _NORMALMAP

        // -------------------------------------
        // Material variables. They need to be declared in UnityPerMaterial
        // to be able to be cached by SRP Batcher
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half _Metallic;
        half _AmbientOcclusion;
        half _Reflectance;
        half _Smoothness;
        half4 _Emission;
        half _NormalMapScale;
        CBUFFER_END
    
        // -------------------------------------
        // Textures are declared in global scope
        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
        TEXTURE2D(_MetallicSmoothnessMap);
        TEXTURE2D(_AmbientOcclusionMap);
    
        void SurfaceFunction(Varyings IN, out CustomSurfaceData surfaceData)
        {
            surfaceData = (CustomSurfaceData)0;
            float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
            
            half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
            half4 metallicSmoothness = SAMPLE_TEXTURE2D(_MetallicSmoothnessMap, sampler_BaseMap, uv);
            half metallic = _Metallic * metallicSmoothness.r;
            // diffuse color is black for metals and baseColor for dieletrics
            surfaceData.diffuse = ComputeDiffuseColor(baseColor.rgb, metallic);

            // f0 is reflectance at normal incidence. we store f0 in baseColor for metals.
            // for dieletrics f0 is monochromatic and stored in reflectance value.
            // Remap reflectance to range [0, 1] - 0.5 maps to 4%, 1.0 maps to 16% (gemstone)
            // https://google.github.io/filament/Filament.html#materialsystem/parameterization/standardparameters
            surfaceData.reflectance = ComputeFresnel0(baseColor.rgb, metallic, _Reflectance * _Reflectance * 0.16);
            surfaceData.ao = SAMPLE_TEXTURE2D(_AmbientOcclusionMap, sampler_BaseMap, uv).g * _AmbientOcclusion;
            surfaceData.roughness = 1.0 - (_Smoothness * metallicSmoothness.a);
#ifdef _NORMALMAP
            surfaceData.normalWS = GetPerPixelNormalScaled(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS, _NormalMapScale);
#else
            surfaceData.normalWS = normalize(IN.normalWS);
#endif
            surfaceData.emission = _Emission.rgb;
            surfaceData.alpha = 1.0;
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