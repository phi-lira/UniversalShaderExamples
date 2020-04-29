Shader "Universal Render Pipeline/Custom/PhysicallyBased"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" {}
        [Normal]_NormalMap("NormalMap", 2D) = "bump" {}

        // r: metalness
        // g: ambient occlusion
        // b: fresnel reflectance at normal incidence for dieletrics
        // a: perceptual roughness
        //_SurfaceMask ("Metalness AO Roughness", Color) = (1.0, 1.0, 0.04, 0.0)

        //[Header(Rim)]
        //_RimSize("Rim size", Range(0,1)) = 0
        //[HDR]_RimColor("Rim color", Color) = (0,0,0,1)
        //[Toggle(SHADOWED_RIM)]
        //_ShadowedRim("Rim affected by shadow", float) = 0

        //[Header(Emission)]
        [HDR]_Emission("Emission", Color) = (0,0,0,1)

        // Blending state
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }

    SubShader
    {
        Tags{"RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half4 _SurfaceMask;
            half4 _Emission;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            
            // User defined surface data.
            struct SurfaceData
            {
                half3 baseColor;
                half3 normalWS;
                half metalness;
                half ao;
                half dieletricReflectance;
                half roughness;
                half3 emission;
                half alpha;
            };

            #include "CustomShading.hlsl"
            
            // Function to initialize surface data from interpolators
            void InitializeSurfaceData(Varyings IN, out SurfaceData s)
            {
                float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                s.baseColor = color;
                s.metalness = _SurfaceMask.r;
                s.ao = _SurfaceMask.g;
                s.dieletricReflectance = _SurfaceMask.b;
                s.roughness = _SurfaceMask.a * _SurfaceMask.z;
#ifdef _NORMALMAP
                s.normalWS = GetPerPixelNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS);
#else
                s.normalWS = normalize(IN.normalWS);
#endif
                s.emission = _Emission.rgb;
                s.alpha = color.a;
            }

            half4 CustomLighting(SurfaceData s, half3 viewDirectionWS, Light light)
            {
                half halfVector = normalize(light.direction + viewDirectionWS);
                half NoL = saturate(dot(s.normalWS, light.direction));
                half NoV = saturate(dot(s.normalWS, viewDirectionWS));
                half NoH = saturate(dot(s.normalWS, halfVector));
                half VoH = saturate(dot(viewDirectionWS, halfVector));

                half4 finalColor = (s.baseColor, s.alpha);
                return finalColor;
            }
            ENDHLSL
        }

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
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #pragma vertex CustomLightingVertex
    #pragma fragment CustomLightingFragment

    ENDHLSL
}