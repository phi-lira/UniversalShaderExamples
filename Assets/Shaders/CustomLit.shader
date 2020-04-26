Shader "Universal Render Pipeline/Custom/Lit"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Normal]_Normal("Normal", 2D) = "bump" {}

        // r: metalness
        // g: ambient occlusion
        // b: fresnel reflectance at normal incidence for dieletrics
        // a: perceptual roughness
        _SurfaceMask("Metalness AO Roughness ") = (1.0, 1.0, 0.04, 0.0)

        //[Header(Rim)]
        //_RimSize("Rim size", Range(0,1)) = 0
        //[HDR]_RimColor("Rim color", Color) = (0,0,0,1)
        //[Toggle(SHADOWED_RIM)]
        //_ShadowedRim("Rim affected by shadow", float) = 0

        [Header(Emission)]
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
            // unused shader_feature variants are stripped from build automatically
            #pragma shader_feature SHADOWED_RIM
            #pragma shader_feature _NORMALMAP

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half4 _SurfaceMask;
            half4 _Emission;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_Normal); SAMPLER(sampler_Normal);
            
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
                half3 normalWS = IN.normalWS;

#ifdef _NORMALMAP
                float4 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, uv));
                normalWS = TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));
#endif

                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                s.baseColor = color;
                s.metalness = _SurfaceMask.r;
                s.ao = _SurfaceMask.g;
                s.dieletricReflectance = _SurfaceMask.b;
                s.roughness = _SurfaceMask.a * _SurfaceMask.z;
                s.normalWS = normalize(normalWS);
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

                half diff = round(saturate(nDotL / _LightCutoff) * _ShadowBands) / _ShadowBands;

                float3 refl = reflect(light.direction, s.normalWS);
                float vDotRefl = dot(viewDirectionWS, -refl);
                float3 specular = _SpecularColor.rgb * step(1 - s.smoothness, vDotRefl);

                half3 rim = _RimColor.rgb * step(1 - _RimSize, 1 - saturate(dot(viewDirectionWS, s.normalWS)));

                half stepAtten = round(light.distanceAttenuation);
                half shadow = diff * stepAtten;

                half3 col = (s.albedo + specular) * light.color;

                half4 c;
#ifdef SHADOWED_RIM
                c.rgb = (col + rim) * shadow;
#else
                c.rgb = col * shadow + rim;
#endif            
                c.a = s.alpha;
                return c;
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
    #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_ON
    #pragma multi_compile_fog

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #pragma vertex CustomLightingVertex
    #pragma fragment CustomLightingFragment

    ENDHLSL
}