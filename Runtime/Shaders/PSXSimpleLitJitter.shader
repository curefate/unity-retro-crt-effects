Shader "Retro/PSXSimpleLitJitter"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor("Base Color", Color) = (1,1,1,1)

        [Toggle(_ALPHATEST_ON)] _AlphaClip("Alpha Clipping", Float) = 0
        _Cutoff("Cutoff", Range(0, 1)) = 0.5

        [Toggle(_NORMALMAP)] _NormalMapToggle("Normal Map", Float) = 0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Range(0, 2)) = 1

        [Toggle(_EMISSION)] _EmissionToggle("Emission", Float) = 0
        [HDR] _EmissionColor("Emission Color", Color) = (0,0,0,0)
        [NoScaleOffset] _EmissionMap("Emission Map", 2D) = "white" {}

        [Header(PSX Vertex Jitter)]
        [KeywordEnum(Scale, Fixed)] _JitterMode("Jitter Mode", Float) = 0

        [Header(Scale Mode)]
        _JitterResolutionScale("Jitter Resolution Scale", Range(0.1, 1)) = 0.5

        [Header(Fixed Mode)]
        _JitterTargetRes("Jitter Target Resolution", Vector) = (320,240,0,0)

        _JitterStrength("Jitter Strength", Range(0, 1)) = 1
        [Toggle]_JitterShadows("Affect Shadows", Float) = 1

        [Header(Receive Shadows)]
        [Toggle]_ReceiveShadows("Receive Shadows", Float) = 1
    }

    HLSLINCLUDE
    // Shared code for all passes (single-file, no external includes)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    // PSX-style vertex jitter (clip-space snapping)
    inline float2 PSX_GetJitterResolution(float2 screenSize, float jitterResolutionScale, float2 jitterTargetRes)
    {
    #if defined(_JITTERMODE_FIXED)
        float2 res = max(jitterTargetRes, float2(1.0, 1.0));
    #else
        float2 res = max(screenSize * jitterResolutionScale, float2(160.0, 120.0));
    #endif
        return res;
    }

    inline float4 PSX_ApplyVertexJitter(float4 positionCS, float jitterStrength, float2 jitterRes)
    {
        float2 ndc = positionCS.xy / positionCS.w;
        float2 pixel = (ndc * 0.5 + 0.5) * jitterRes;
        float2 snappedPixel = floor(pixel + 0.5);
        float2 snappedNdc = (snappedPixel / jitterRes) * 2.0 - 1.0;
        float2 snappedXY = snappedNdc * positionCS.w;
        positionCS.xy = lerp(positionCS.xy, snappedXY, saturate(jitterStrength));
        return positionCS;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "UniversalMaterialType"="Lit"
        }
        LOD 200

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag

            // Material features
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _EMISSION

            // Jitter mode
            #pragma shader_feature_local _JITTERMODE_SCALE _JITTERMODE_FIXED

            // URP lighting keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES

            // Fog
            #pragma multi_compile_fog

            // Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;

                float  _Cutoff;
                float  _BumpScale;
                float4 _EmissionColor;

                float  _JitterResolutionScale;
                float4 _JitterTargetRes;
                float  _JitterStrength;
                float  _JitterShadows;

                float  _ReceiveShadows;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
#if defined(_NORMALMAP)
                float4 tangentOS  : TANGENT;
#endif
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
#if defined(_NORMALMAP)
                float4 tangentWS  : TEXCOORD2;
#endif
                float2 uv         : TEXCOORD3;
                half   fogFactor  : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            inline float2 GetJitterResolution()
            {
                return PSX_GetJitterResolution(_ScreenParams.xy, _JitterResolutionScale, _JitterTargetRes.xy);
            }

            inline float3 SampleNormalTS(float2 uv)
            {
                float4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
                return UnpackNormalScale(n, _BumpScale);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInputs = GetVertexNormalInputs(IN.normalOS
#if defined(_NORMALMAP)
                    , IN.tangentOS
#endif
                );

                float4 positionCS = posInputs.positionCS;
                positionCS = PSX_ApplyVertexJitter(positionCS, _JitterStrength, GetJitterResolution());
                OUT.positionCS = positionCS;

                OUT.positionWS = posInputs.positionWS;
                OUT.normalWS = nrmInputs.normalWS;

#if defined(_NORMALMAP)
                OUT.tangentWS = float4(nrmInputs.tangentWS, nrmInputs.tangentSign);
#endif

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.fogFactor = ComputeFogFactor(positionCS.z);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);

                float2 uv = IN.uv;
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                half4 albedoAlpha = baseSample * _BaseColor;

#if defined(_ALPHATEST_ON)
                clip(albedoAlpha.a - _Cutoff);
#endif

                float3 normalWS = normalize(IN.normalWS);

#if defined(_NORMALMAP)
                float3 normalTS = SampleNormalTS(uv);
                float3 tangentWS = normalize(IN.tangentWS.xyz);
                float3 bitangentWS = cross(normalWS, tangentWS) * IN.tangentWS.w;
                float3x3 TBN = float3x3(tangentWS, bitangentWS, normalWS);
                normalWS = normalize(mul(normalTS, TBN));
#endif

                // Main light
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);

                half ndotl = saturate(dot(normalWS, mainLight.direction));
                half3 lighting = (mainLight.color * ndotl);

                // Shadow receive toggle
                if (_ReceiveShadows < 0.5)
                    mainLight.shadowAttenuation = 1.0;

                lighting *= mainLight.shadowAttenuation;

                // Additional lights (per-pixel when _ADDITIONAL_LIGHTS is enabled)
#if defined(_ADDITIONAL_LIGHTS)
                uint additionalLightsCount = GetAdditionalLightsCount();
                for (uint i = 0u; i < additionalLightsCount; i++)
                {
                    Light light = GetAdditionalLight(i, IN.positionWS);
                    half ndotlAdd = saturate(dot(normalWS, light.direction));
                    lighting += light.color * (ndotlAdd * light.distanceAttenuation * light.shadowAttenuation);
                }
#endif

                // Ambient (cheap, makes it feel more like URP)
                half3 ambient = SampleSH(normalWS);

                half3 color = albedoAlpha.rgb * (lighting + ambient);

#if defined(_EMISSION)
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;
                color += emission;
#endif

                color = MixFog(color, IN.fogFactor);
                return half4(color, albedoAlpha.a);
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
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _JITTERMODE_SCALE _JITTERMODE_FIXED
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float  _Cutoff;
                float  _JitterResolutionScale;
                float4 _JitterTargetRes;
                float  _JitterStrength;
                float  _JitterShadows;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            inline float2 GetJitterResolution()
            {
                return PSX_GetJitterResolution(_ScreenParams.xy, _JitterResolutionScale, _JitterTargetRes.xy);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInputs = GetVertexNormalInputs(IN.normalOS);

                float3 positionWS = posInputs.positionWS;
                float3 normalWS = nrmInputs.normalWS;

                float4 shadowPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, 0));
                if (_JitterShadows >= 0.5)
                    shadowPos = PSX_ApplyVertexJitter(shadowPos, _JitterStrength, GetJitterResolution());

                OUT.positionCS = shadowPos;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
#if defined(_ALPHATEST_ON)
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half alpha = baseSample.a * _BaseColor.a;
                clip(alpha - _Cutoff);
#endif
                return 0;
            }
            ENDHLSL
        }
    }
}
