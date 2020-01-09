// When creating shaders for Lightweight Render Pipeline you can you the ShaderGraph which is super AWESOME!
// However, if you want to author shaders in shading language you can use this teamplate as a base.
// Please note, this shader does not match perfomance of the built-in LWRP Lit shader.
// This shader works with LWRP 5.7.2 version and above
Shader "Universal Render Pipeline/Custom/Toon"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Normal]_Normal("Normal", 2D) = "bump" {}
        _LightCutoff("Light cutoff", Range(0,1)) = 0.5
        _ShadowBands("Shadow bands", Range(1,4)) = 1

        [Header(Specular)]
        _SpecularMap("Specular map", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        [HDR]_SpecularColor("Specular color", Color) = (0,0,0,1)

        [Header(Rim)]
        _RimSize("Rim size", Range(0,1)) = 0
        [HDR]_RimColor("Rim color", Color) = (0,0,0,1)
        [Toggle(SHADOWED_RIM)]
        _ShadowedRim("Rim affected by shadow", float) = 0

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

        // _ReceiveShadows("Receive Shadows", Float) = 1.0

            // Editmode props
        // [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
    }

    SubShader
    {
        // With SRP we introduce a new "RenderPipeline" tag in Subshader. This allows to create shaders
        // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
        // any render pipeline. In case you want your subshader to only run in LWRP set the tag to
        // "LightweightPipeline"
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}

        // ------------------------------------------------------------------
        // Forward pass. Shades GI, emission, fog and all lights in a single pass.
        // Compared to Builtin pipeline forward renderer, LWRP forward renderer will
        // render a scene with multiple lights with less drawcalls and less overdraw.
        Pass
        {
            // "Lightmode" tag must be "UniversalForward" or not be defined in order for
            // to render objects.
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
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _OCCLUSIONMAP

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Lightweight Render Pipeline keywords
            // When doing custom shaders you most often want to copy and past these #pragmas
            // These multi_compile variants are stripped from the build depending on:
            // 1) Settings in the LWRP Asset assigned in the GraphicsSettings at build time
            // e.g If you disable AdditionalLights in the asset then all _ADDITIONA_LIGHTS variants
            // will be stripped from build
            // 2) Invalid combinations are stripped. e.g variants with _MAIN_LIGHT_SHADOWS_CASCADE
            // but not _MAIN_LIGHT_SHADOWS are invalid and therefore stripped.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float _LightCutoff;
            float _ShadowBands;
            half _Glossiness;
            half4 _SpecularColor;

            half _RimSize;
            half4 _RimColor;
            half4 _Emission;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_Normal); SAMPLER(sampler_Normal);
            TEXTURE2D(_SpecularMap); SAMPLER(sampler_SpecularMap);

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
                float2 uvLM         : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                float2 uvLM                     : TEXCOORD1;
                float4 positionWSAndFogFactor   : TEXCOORD2; // xyz: positionWS, w: vertex fog factor
                half3  normalWS                 : TEXCOORD3;

#if _NORMALMAP
                half3 tangentWS                 : TEXCOORD4;
                half3 bitangentWS               : TEXCOORD5;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
                float4 shadowCoord              : TEXCOORD6; // compute shadow coord per-vertex for the main light
#endif
                float4 positionCS               : SV_POSITION;
            };

            struct SurfaceData
            {
                half3 albedo;
                half3 normalWS;
                half smoothness;
                half3 emission;
                half alpha;
            };

            void InitializeSurfaceData(Varyings IN, out SurfaceData s)
            {
                half3 normalWS = IN.normalWS;

#ifdef _NORMALMAP
                float4 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_Normal, sampler__Normal, uv));
                normalWS = TransformTangentToWorld(normalTS,
                    half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));
#endif

                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                s.albedo = color.rgb;
                s.normalWS = normalize(normalWS);
                s.smoothness = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, IN.uv).r * _Glossiness;
                s.emission = s.albedo * _Emission.rgb;
                s.alpha = color.a;
            }

            half4 LightingCelShaded(SurfaceData s, half3 viewDirectionWS, Light light)
            {
                half nDotL = saturate(dot(s.normalWS, light.direction));
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

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;

                // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
                // Our compiler will strip all unused references (say you don't use view space).
                // Therefore there is more flexibility at no additional cost with this struct.
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
                // in world space. If not used it will be stripped.
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                // Computes fog factor per-vertex.
                float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                // TRANSFORM_TEX is the same as the old shader library.
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.uvLM = input.uvLM.xy * unity_LightmapST.xy + unity_LightmapST.zw;

                output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
                output.normalWS = vertexNormalInput.normalWS;

                // Here comes the flexibility of the input structs.
                // In the variants that don't have normal map defined
                // tangentWS and bitangentWS will not be referenced and
                // GetVertexNormalInputs is only converting normal
                // from object to world space
#ifdef _NORMALMAP
                output.tangentWS = vertexNormalInput.tangentWS;
                output.bitangentWS = vertexNormalInput.bitangentWS;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
                // shadow coord for the main light is computed in vertex.
                // If cascades are enabled, LWRP will resolve shadows in screen space
                // and this coord will be the uv coord of the screen space shadow texture.
                // Otherwise LWRP will resolve shadows in light space (no depth pre-pass and shadow collect pass)
                // In this case shadowCoord will be the position in light space.
                output.shadowCoord = GetShadowCoord(vertexInput);
#endif
                // We just use the homogeneous clip position from the vertex input
                output.positionCS = vertexInput.positionCS;
                return output;
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                SurfaceData surfaceData;
                InitializeSurfaceData(input, surfaceData);

#ifdef _MAIN_LIGHT_SHADOWS
                Light mainLight = GetMainLight(input.shadowCoord);
#else
                Light mainLight = GetMainLight();
#endif

                float3 positionWS = input.positionWSAndFogFactor.xyz;
                half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);
                float fogFactor = input.positionWSAndFogFactor.w;

                half4 color = LightingCelShaded(surfaceData, viewDirectionWS, mainLight);

                // Mix the pixel color with fogColor. You can optionaly use MixFogColor to override the fogColor
                // with a custom one.
                color.rgb = MixFog(color.rgb, fogFactor);
                return half4(color.rgb, surfaceData.alpha);

#ifdef LIGHTMAP_ON
                // Normal is required in case Directional lightmaps are baked
                half3 bakedGI = SampleLightmap(input.uvLM, surfaceData.normalWS);
#else
                // Samples SH fully per-pixel. SampleSHVertex and SampleSHPixel functions
                // are also defined in case you want to sample some terms per-vertex.
                half3 bakedGI = SampleSH(surfaceData.normalWS);
#endif
            }
            ENDHLSL
        }

        // Used for rendering shadowmaps
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"

        // Used for depth prepass
        // If shadows cascade are enabled we need to perform a depth prepass. 
        // We also need to use a depth prepass in some cases camera require depth texture
        // (e.g, MSAA is enabled and we can't resolve with Texture2DMS
        UsePass "Universal Render Pipeline/Lit/DepthOnly"

        // Used for Baking GI. This pass is stripped from build.
        UsePass "Universal Render Pipeline/Lit/Meta"
    }

    // Uses a custom shader GUI to display settings. Re-use the same from Lit shader as they have the
    // same properties.
    CustomEditor "UnityEditor.Rendering.Universal.LitShaderGUI"
}