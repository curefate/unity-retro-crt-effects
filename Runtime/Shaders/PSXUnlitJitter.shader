Shader "Retro/PSXUnlitJitter"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(PSX Vertex Jitter)]
        [KeywordEnum(Scale, Fixed)] _JitterMode("Jitter Mode", Float) = 0

        [Header(Scale Mode)]
        _JitterResolutionScale("Jitter Resolution Scale", Range(0.1, 1)) = 0.5

        [Header(Fixed Mode)]
        _JitterTargetRes("Jitter Target Resolution (4:3)", Vector) = (320,240,0,0)

        _JitterStrength("Jitter Strength", Range(0, 1)) = 1
        [Toggle]_JitterShadows("Affect Shadows", Float) = 1

        [Header(UV Quantization)]
        [Toggle]_UVQuantize("Enable UV Quantization", Float) = 1
        _UVQuantizeSteps("UV Quantize Steps", Range(16, 2048)) = 256
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma shader_feature_local _JITTERMODE_SCALE _JITTERMODE_FIXED

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;

                float _JitterResolutionScale;
                float4 _JitterTargetRes;
                float _JitterStrength;
                float _JitterShadows;

                float _UVQuantize;
                float _UVQuantizeSteps;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
            };

            float2 GetJitterResolution()
            {
                float2 screen = _ScreenParams.xy;

                #if defined(_JITTERMODE_FIXED)
                    float2 res = max(_JitterTargetRes.xy, float2(1,1));
                #else
                    float2 res = max(screen * _JitterResolutionScale, float2(160,120));
                #endif

                return res;
            }

            float4 ApplyVertexJitter(float4 positionCS)
            {
                float2 res = GetJitterResolution();

                // Convert to NDC
                float2 ndc = positionCS.xy / positionCS.w;

                // Convert NDC to pixel coords in "jitter resolution" space
                float2 pixel = (ndc * 0.5 + 0.5) * res;
                float2 snappedPixel = floor(pixel + 0.5);

                float2 snappedNdc = (snappedPixel / res) * 2.0 - 1.0;
                float2 snappedXY = snappedNdc * positionCS.w;

                positionCS.xy = lerp(positionCS.xy, snappedXY, saturate(_JitterStrength));
                return positionCS;
            }

            float2 ApplyUVQuantization(float2 uv)
            {
                if (_UVQuantize < 0.5)
                    return uv;

                float steps = max(_UVQuantizeSteps, 1.0);
                return floor(uv * steps) / steps;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = ApplyVertexJitter(posInputs.positionCS);
                OUT.positionWS = posInputs.positionWS;
                OUT.normalWS = nrmInputs.normalWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = ApplyUVQuantization(IN.uv);

                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;

                // Simple Lambert
                float3 normalWS = normalize(IN.normalWS);
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));
                float ndotl = saturate(dot(normalWS, mainLight.direction));
                half3 lit = albedo.rgb * (mainLight.color * ndotl);

                return half4(lit, albedo.a);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _JITTERMODE_SCALE _JITTERMODE_FIXED

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _JitterResolutionScale;
                float4 _JitterTargetRes;
                float _JitterStrength;
                float _JitterShadows;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            float2 GetJitterResolution()
            {
                float2 screen = _ScreenParams.xy;

                #if defined(_JITTERMODE_FIXED)
                    float2 res = max(_JitterTargetRes.xy, float2(1,1));
                #else
                    float2 res = max(screen * _JitterResolutionScale, float2(160,120));
                #endif

                return res;
            }

            float4 ApplyVertexJitter(float4 positionCS)
            {
                if (_JitterShadows < 0.5)
                    return positionCS;

                float2 res = GetJitterResolution();
                float2 ndc = positionCS.xy / positionCS.w;
                float2 pixel = (ndc * 0.5 + 0.5) * res;
                float2 snappedPixel = floor(pixel + 0.5);
                float2 snappedNdc = (snappedPixel / res) * 2.0 - 1.0;
                float2 snappedXY = snappedNdc * positionCS.w;

                positionCS.xy = lerp(positionCS.xy, snappedXY, saturate(_JitterStrength));
                return positionCS;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInputs = GetVertexNormalInputs(IN.normalOS);

                // Compute shadow caster position (URP 14 compatible)
                float3 positionWS = posInputs.positionWS;
                float3 normalWS = nrmInputs.normalWS;
                float4 shadowPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, 0));

                shadowPos = ApplyVertexJitter(shadowPos);
                OUT.positionCS = shadowPos;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
