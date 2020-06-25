Shader "Universal Render Pipeline/Custom/VertexAnimation"
{
    Properties
    {
    	
        [Header(Surface)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        [Header(VertAnim)]
        _NoiseStrength("_NoiseStrength", Range(-4,4)) = 1

        [Header(Outline)]
        _OutlineThickness("Outline Thickness", Float) = 0.1
        _OutlineColor("Outline Color", Color) = (1, 1, 1, 1)
    
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/CustomShading.hlsl"
    
        // -------------------------------------
        // Material variables. They need to be declared in UnityPerMaterial
        // to be able to be cached by SRP Batcher
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        float _NoiseStrength;
        float _OutlineThickness;
        float4 _OutlineColor;
        CBUFFER_END
    
        // -------------------------------------
        // Textures are declared in global scope
        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

        // vertex modification adapted from NiloCat:
        // https://github.com/ColinLeung-NiloCat/UnityURP-SurfaceShaderSolution/blob/master/Assets/NiloCat/NiloURPSurfaceShader/ExampleSurfaceShaders/NiloURPSurfaceShader_Example.shader
        float3 GetNoise(float3 positionOS)
        {
            return sin(_Time.y * 10.0 * positionOS) * _NoiseStrength * 0.0125; //random sin() vertex anim
        }    

        void VertexModificationFunction(inout Attributes IN)
        {
            IN.positionOS.xyz += GetNoise(IN.positionOS.xyz);
        }
    
        void SurfaceFunction(Varyings IN, out CustomSurfaceData surfaceData)
        {
            surfaceData = (CustomSurfaceData)0;
            float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
            half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;

            // diffuse color is black for metals and baseColor for dieletrics
            surfaceData.diffuse = baseColor.rgb;
            surfaceData.normalWS = normalize(IN.normalWS);
            surfaceData.alpha = 1.0;
        }
    
    
    half3 GlobalIlluminationFunction(CustomSurfaceData surfaceData, half3 environmentLighting, half3 environmentReflections, half3 viewDirectionWS)
    {
        half3 NdotV = saturate(dot(surfaceData.normalWS, viewDirectionWS)) + HALF_MIN;
        environmentReflections *= EnvironmentBRDF(surfaceData.reflectance, surfaceData.roughness, NdotV);
        environmentLighting = environmentLighting * surfaceData.diffuse;

        return (environmentReflections + environmentLighting) * surfaceData.ao;
    }


    half3 LightingFunction(CustomSurfaceData surfaceData, LightingData lightingData, half3 viewDirectionWS)
    {
        half3 diffuse = surfaceData.diffuse * Lambert();

        // CookTorrance
        // inline D_GGX + V_SmithJoingGGX for better code generations
        half3 NdotV = saturate(dot(surfaceData.normalWS, viewDirectionWS)) + HALF_MIN;
        half DV = DV_SmithJointGGX(lightingData.NdotH, lightingData.NdotL, NdotV, surfaceData.roughness);

        // for microfacet fresnel we use H instead of N. In this case LdotH == VdotH, we use LdotH as it
        // seems to be more widely used convetion in the industry.
        half3 F = F_Schlick(surfaceData.reflectance, lightingData.LdotH);
        half3 specular = DV * F;
        half3 finalColor = (diffuse + specular) * lightingData.light.color * lightingData.NdotL;
        return finalColor;
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

        
        Pass 
        {
            Name "OUTLINE"
            Cull Front
            ZWrite On
            ColorMask RGB
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct OutlineAttributes 
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
        
            struct OutlineVaryings 
            {
                float4 positionCS : SV_POSITION;
                half4 color : COLOR;
            };
            
            OutlineVaryings vert(OutlineAttributes IN) 
            {
                OutlineVaryings output = (OutlineVaryings)0;
                
                IN.positionOS.xyz += IN.normalOS.xyz * _OutlineThickness;
                IN.positionOS.xyz += GetNoise(IN.positionOS.xyz);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                
                output.color = _OutlineColor;
                return output;
            }
            
            half4 frag(OutlineVaryings IN) : SV_Target
            {
                return IN.color;
            }
            ENDHLSL
        }
    
    }
    
    
}