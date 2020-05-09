Shader "Universal Render Pipeline/Custom/Clear Coat"
{
    // TODO: I need to support custom shader inspector for this to hide
    // scale/offset for normal map using NoScaleOffset.
    Properties
    {
        [Header(Surface)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        _Metallic("Metallic", Range(0, 1)) = 1.0
        [NoScaleOffset]_MetallicSmoothnessMap("MetalicMap", 2D) = "white" {}
        _AmbientOcclusion("AmbientOcclusion", Range(0, 1)) = 1.0
        [NoScaleOffset]_AmbientOcclusionMap("AmbientOcclusionMap", 2D) = "white" {}
        _Reflectance("Reflectance for dieletrics", Range(0.0, 1.0)) = 0.5
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _ClearCoatStrength("Clear Coat Strength", Range(0.0, 1.0)) = 0.5
        _ClearCoatSmoothness("Clear Coat Smoothness", Range(0.0, 1.0)) = 0.5

        [Toggle(_NORMALMAP)] _EnableNormalMap("Enable Normal Map", Float) = 0.0
        [Normal][NoScaleOffset]_NormalMap("Normal Map", 2D) = "bump" {}
        _NormalMapScale("Normal Map Scale", Float) = 1.0

        [Header(Emission)]
        [HDR]_Emission("Emission Color", Color) = (0,0,0,1)
    }

    SubShader
    {
        Tags{"RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}

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
        half _Metallic;
        half _AmbientOcclusion;
        half _Reflectance;
        half _Smoothness;
        half4 _Emission;
        half _ClearCoatSmoothness;
        half _ClearCoatStrength;
        half _NormalMapScale;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex SurfaceVertex
            #pragma fragment SurfaceFragment
            #define CUSTOM_LIGHTING_FUNCTION ClearCoatLightingFunction

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP
            
            // -------------------------------------
            // Universal Render Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            // -------------------------------------
            // Include custom shading helper to create vertex and fragment functions
            #include "../CustomShading.hlsl"

            // -------------------------------------
            // Textures are declared in global scope
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicSmoothnessMap);
            TEXTURE2D(_AmbientOcclusionMap);

            void SurfaceFunction(Varyings IN, out SurfaceData surfaceData)
            {
                surfaceData = (SurfaceData)0;
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
                surfaceData.perceptualRoughness = 1.0 - (_Smoothness * metallicSmoothness.a);
#ifdef _NORMALMAP
                surfaceData.normalWS = GetPerPixelNormalScaled(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS, _NormalMapScale);
#else
                surfaceData.normalWS = normalize(IN.normalWS);
#endif
                surfaceData.emission = _Emission.rgb;
                surfaceData.alpha = 1.0;
            }

            half4 ClearCoatLightingFunction(SurfaceData surfaceData, LightingData lightingData)
            {
                ///////////////////////////////////////////////////////////////
                // Parametrization                                            /
                ///////////////////////////////////////////////////////////////
                // 0.089 perceptual roughness is the min value we can represent in fp16
                // to avoid denorm/division by zero as we need to do 1 / (pow(perceptualRoughness, 4)) in GGX
                half perceptualCoatRoughness = max(1.0 - _ClearCoatSmoothness, 0.089);
                half coatRoughness = PerceptualRoughnessToRoughness(perceptualCoatRoughness);
                half coatStrength = _ClearCoatStrength;
                
                half perceptualRoughness = max(surfaceData.perceptualRoughness, 0.089);
                half baseRoughness = PerceptualRoughnessToRoughness(perceptualRoughness);

                // We recompute reflectance for base layer as we are not considering air as interface
                // ConvertF0ForAirInterfaceToF0ForClearCoat15 converts reflectance considering IOR of clear coat instead of air.
                half3 baseReflectance = lerp(surfaceData.reflectance, ConvertF0ForAirInterfaceToF0ForClearCoat15(surfaceData.reflectance), coatStrength);

                ///////////////////////////////////////////////////////////////
                // Environment                                                /
                ///////////////////////////////////////////////////////////////
                // pre-integrated diffuse is stored in either SH or lightmap
                half3 environmentLighting = lightingData.environmentLighting * surfaceData.diffuse;

                // split sum approaximation. 
                // pre-integrated specular D stored in cubemap, roughness store in different mips
                // DG term is analytical
                half3 baseEnvironmentReflection = lightingData.environmentReflections;
                baseEnvironmentReflection *= EnvironmentBRDF(baseReflectance, baseRoughness, lightingData.NdotV);
                
                // split sum approximation with F0 = CLEAR_COAT_F0
                half3 coatEnvironmentReflection = GlossyEnvironmentReflection(lightingData.reflectionDirectionWS, perceptualCoatRoughness, surfaceData.ao); 
                coatEnvironmentReflection *= EnvironmentBRDF(CLEAR_COAT_F0, coatRoughness, lightingData.NdotV);

                ///////////////////////////////////////////////////////////////
                // Direct Light Contribution                                  /
                ///////////////////////////////////////////////////////////////
                half3 baseDiffuse = surfaceData.diffuse * Lambert();
                
                // Base Specular BDRF
                // inline D_GGX + V_SmithJoingGGX for better code generations
                half baseDV = DV_SmithJointGGX(lightingData.NdotH, lightingData.NdotL, lightingData.NdotV, baseRoughness);
                half3 baseF = F_Schlick(baseReflectance, lightingData.LdotH);
                half3 baseSpecular = (baseDV * baseF);

                // Clear Specular Coat BRDF - We assume coat to be dieletric, this allows for a simpler visibility term
                // We use V_Kelemen instead of V_SmithJoingGGX
                half coatD = D_GGX(lightingData.NdotH, coatRoughness);
                half coatV = V_Kelemen(lightingData.LdotH);
                half3 coatF = F_Schlick(CLEAR_COAT_F0, lightingData.LdotH);
                half3 coatSpecular = (coatD * coatV * coatF);

                ///////////////////////////////////////////////////////////////
                // Irradiance and layer blending                              /
                ///////////////////////////////////////////////////////////////
                half3 irradiance = lightingData.light.color * lightingData.NdotL;
                baseDiffuse = baseDiffuse * irradiance + environmentLighting;
                baseSpecular = baseSpecular * irradiance + baseEnvironmentReflection;
                coatSpecular = coatSpecular * irradiance + coatEnvironmentReflection;

                // Coat Blending from glTF 
                // https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_clearcoat
                half3 emission = surfaceData.emission;
                half3 finalColor = (emission + baseDiffuse + baseSpecular) * (1.0 - coatF * coatStrength) + coatSpecular * coatStrength;
                return half4(finalColor, surfaceData.alpha);
            }
            ENDHLSL
        }

        // TODO: This is currently breaking SRP batcher as these passes are including
        //  a different cbuffer. We need to fix it in URP side.
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }
}