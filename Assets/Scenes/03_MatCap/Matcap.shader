Shader "Universal Render Pipeline/Custom/Matcap"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" {}
        [Normal][NoScaleOffset] _NormalMap("NormalMap", 2D) = "bump" {}    
        [NoScaleOffset]_MatCap("MatCap", 2D) = "black" {}
        _MatCapBlend("Matcap Blend", Range(0, 1)) = 0.25 
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline"}

        // Include material cbuffer for all passes. 
        // The cbuffer has to be the same for all passes to make this shader SRP batcher compatible.
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half _MatCapBlend;
        CBUFFER_END
        ENDHLSL

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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                      
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                half3 normalVS      : TEXCOORD1;
                half4 tangentVS     : TEXCOORD2; // xyz: tangetVS, w: sign to compute binormal
                half3 positionWS    : TEXCOORD3;
                float4 positionHCS  : SV_POSITION;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_MatCap);
            SAMPLER(sampler_MatCap);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // GetVertexPositionInputs computes position in different spaces (ViewSpace, WorldSpace, Homogeneous Clip Space)
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);

                // GetVertexNormalInputs computes normal and tanget in WorldSpace. 
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                // To compute matcap uv coord we need normal and tanget in ViewSpace.
                // We reconstruct binormal in pixel shader to match normal map generation from most bakers.
                // TangentVS.w contains sign to compute binormal.
                // https://medium.com/@bgolus/generating-perfect-normal-maps-for-unity-f929e673fc57
                half3 normalVS = TransformWorldToViewDir(normalInputs.normalWS);
                half4 tangentVS = half4(TransformWorldToViewDir(normalInputs.tangentWS), IN.tangentOS.w * GetOddNegativeScale());

                OUT.positionHCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                OUT.normalVS = normalVS;
                OUT.tangentVS = tangentVS;

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // shadowCoord is position in shadow light space
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                
                // We pass shadowCoord as input as realtime shadow is computed and stored in mainLight struct.
                Light mainLight = GetMainLight(shadowCoord);

                half3 binormalVS = cross(IN.normalVS, IN.tangentVS.xyz) * IN.tangentVS.w;
                half3 perturbedNormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv));
                half3 perturbedNormalVS = normalize(mul(perturbedNormalTS, half3x3(IN.tangentVS.xyz, binormalVS, IN.normalVS)));
                float2 uvMatCap = perturbedNormalVS.xy * 0.5 + 0.5;

                half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 matCapColor = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, uvMatCap);
                half3 finalColor = lerp(baseColor, matCapColor, _MatCapBlend);
                finalColor *= mainLight.shadowAttenuation;
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // Used for rendering shadowmaps
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}