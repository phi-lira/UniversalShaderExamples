Shader "Universal Render Pipeline/Custom/Matcap"
{
    Properties
    {
    	
        [Header(Surface)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [Normal][NoScaleOffset] _NormalMap("NormalMap", 2D) = "bump" {}    
        [NoScaleOffset]_MatCap("MatCap", 2D) = "black" {}
        _MatCapBlend("Matcap Blend", Range(0, 1)) = 0.25 
    
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/CustomShading.hlsl"
    
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half _MatCapBlend;
        CBUFFER_END
    
        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
        TEXTURE2D(_MatCap); SAMPLER(sampler_MatCap);

        void SurfaceFunction(Varyings IN, inout CustomSurfaceData surfaceData)
        {
            float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
            half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;

            half3 normalWS = GetPerPixelNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS);
            half3 normalVS = TransformWorldToViewDir(normalWS);
            float2 uvMatCap = normalVS.xy * 0.5 + 0.5;

            surfaceData.diffuse = baseColor.rgb;
            surfaceData.alpha = baseColor.a;
            surfaceData.emission = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, uvMatCap) * _MatCapBlend;
        }

        half3 LightingFunction(CustomSurfaceData surfaceData, LightingData lightingData, half3 viewDirectionWS)
        {
            return surfaceData.diffuse * lightingData.light.shadowAttenuation * (1.0 - _MatCapBlend);
        }
    
    
    half3 GlobalIlluminationFunction(CustomSurfaceData surfaceData, half3 environmentLighting, half3 environmentReflections, half3 viewDirectionWS)
    {
        half3 NdotV = saturate(dot(surfaceData.normalWS, viewDirectionWS)) + HALF_MIN;
        environmentReflections *= EnvironmentBRDF(surfaceData.reflectance, surfaceData.roughness, NdotV);
        environmentLighting = environmentLighting * surfaceData.diffuse;

        return (environmentReflections + environmentLighting) * surfaceData.ao;
    }


    void VertexModificationFunction(inout Attributes IN)
    {
    }


    half4 FinalColorFunction(half4 inColor)
    {
        return inColor;
    }


    ENDHLSL

    Subshader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            

            HLSLPROGRAM
            
    		

    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceFunctions.hlsl"
    		

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex SurfaceVertex
    		#pragma fragment SurfaceFragment

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers d3d11_9x gles
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceFunctions.hlsl"
            #pragma vertex SurfaceVertexShadowCaster
            #pragma fragment SurfaceFragmentDepthOnly

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers d3d11_9x gles
            #pragma target 4.5

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceFunctions.hlsl"
            #pragma vertex SurfaceVertex
            #pragma fragment SurfaceFragmentDepthOnly
            
            ENDHLSL
        }

        
    }
    
    
}