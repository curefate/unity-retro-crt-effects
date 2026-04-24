Shader "Retro/PSXEffectURP"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        ZWrite Off
        Cull Off
        ZTest Always

        Pass
        {
            Name "PSXPass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            // ============================================
            // PSX SETTINGS
            // ============================================
            float _PSXColorDepth;
            float _PSXDitherIntensity;
            float _PSXPosterization;
            float _PSXResolutionScale;
            float _PSXSaturationBoost;
            float _PSXDarkening;
            float _CRTTime;

            // ============================================
            // UTILITY FUNCTIONS
            // ============================================

            // Ordered dithering (Bayer matrix 4x4)
            static const float bayerMatrix[16] = {
                 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
                12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
                 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
                15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
            };

            float getBayerValue(float2 pixelPos)
            {
                int x = int(fmod(pixelPos.x, 4.0));
                int y = int(fmod(pixelPos.y, 4.0));
                return bayerMatrix[y * 4 + x];
            }

            // Color depth reduction with dithering (PS1 style)
            float3 psxColorReduce(float3 color, float2 pixelPos)
            {
                float dither = getBayerValue(pixelPos);
                dither = (dither - 0.5) * _PSXDitherIntensity;

                float levels = pow(2.0, _PSXColorDepth);

                float3 ditheredColor = color + dither / levels;

                // Quantize to limited color depth
                float3 quantized = floor(ditheredColor * levels) / (levels - 1.0);

                return saturate(quantized);
            }

            // Posterization for additional color banding
            float3 posterize(float3 color, float levels)
            {
                return floor(color * levels) / levels;
            }

            // PS1-style resolution reduction (pixelation at PSX resolution)
            float2 psxPixelate(float2 uv, float2 screenSize)
            {
                float2 psxRes = screenSize * _PSXResolutionScale;
                psxRes = max(psxRes, float2(160, 120));

                return floor(uv * psxRes) / psxRes;
            }

            // Saturation adjustment
            float3 adjustSaturation(float3 color, float saturation)
            {
                float luma = dot(color, float3(0.299, 0.587, 0.114));
                return lerp(float3(luma, luma, luma), color, saturation);
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 screenSize = _ScreenParams.xy;
                float2 uv = input.texcoord;

                // Resolution reduction
                float2 psxUV = uv;
                if (_PSXResolutionScale < 0.99)
                    psxUV = psxPixelate(uv, screenSize);

                float3 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, psxUV).rgb;

                // PSX darkening (subtle)
                if (_PSXDarkening > 0.0001)
                    col *= (1.0 - _PSXDarkening * 0.3);

                // PSX saturation boost
                if (_PSXSaturationBoost > 1.0001)
                    col = adjustSaturation(col, _PSXSaturationBoost);

                // PSX posterization (before dithering)
                if (_PSXPosterization > 0.0001)
                {
                    float posterLevels = lerp(256.0, 8.0, _PSXPosterization);
                    col = posterize(col, posterLevels);
                }

                // PSX color depth reduction with dithering
                if (_PSXColorDepth < 7.99)
                {
                    float2 pixelPos = uv * screenSize;
                    col = psxColorReduce(col, pixelPos);
                }

                return half4(saturate(col), 1);
            }
            ENDHLSL
        }
    }
}
