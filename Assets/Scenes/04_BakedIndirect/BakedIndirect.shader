Shader "Universal Render Pipeline/Custom/BakedIndirect"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" {}
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}    
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline"}

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            // -------------------------------------
            // Universal Render Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                      
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float2 uvLightmap   : TEXCOORD1;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
#ifdef _LIGHTMAP_ON
                float2 uvLightmap   : TEXCOORD1;
#endif
                float3 normalWS     : TEXCOORD2;
                float4 tangentWS    : TEXCOORD3; // xyz: tangetVS, w: sign to compute binormal
                float3 positionWS   : TEXCOORD4;
                float4 positionHCS  : SV_POSITION;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // GetVertexPositionInputs computes position in different spaces (ViewSpace, WorldSpace, Homogeneous Clip Space)
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);

                // GetVertexNormalInputs computes normal and tanget in WorldSpace. 
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionHCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                OUT.normalWS = normalInputs.normalWS;
                OUT.tangentWS = float4(normalInputs.tangentWS, IN.tangentOS.w);

                OUT.uv = IN.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
#ifdef _LIGHTMAP_ON
                OUT.uvLightmap = IN.uvLightmap * unity_LightmapST.xy + unity_LightmapST.zw;
#endif
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // shadowCoord is position in shadow light space
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                
                // We pass shadowCoord as input as realtime shadow is computed and stored in mainLight struct.
                Light mainLight = GetMainLight(shadowCoord);

                float3 binormalWS = cross(IN.normalWS, IN.tangentWS.xyz) * IN.tangentWS.w;
                float3 perturbedNormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv));
                float3 perturbedNormalWS = normalize(mul(perturbedNormalTS, float3x3(IN.tangentWS.xyz, binormalWS, IN.normalWS)));

                half3 indirectLighting;
#ifdef _LIGHTMAP_ON
                indirectLighting = SampleLightmap(IN.uvLightmap, perturbedNormalWS);
#else
                indirectLighting = SampleSH(perturbedNormalWS);
#endif  
                
                half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 finalColor = baseColor * mainLight.shadowAttenuation + indirectLighting;
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // Used for rendering shadowmaps
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}