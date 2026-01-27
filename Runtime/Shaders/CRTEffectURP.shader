Shader "Retro/CRTEffectURP"
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
            Name "CRTPass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            // Basic settings
            float _PixelSize;
            float _ScanlineIntensity;
            float _ScanlineCount;
            float _Curvature;
            float _ChromaticAberration;
            float _Vignette;
            float _Brightness;

            // New effects
            float _PhosphorIntensity;
            float _FlickerIntensity;
            float _RollingScanlineIntensity;
            float _RollingScanlineSpeed;
            float _GlowIntensity;
            float _GlowSpread;
            float _NoiseIntensity;
            float _ColorBleedIntensity;
            float _InterlacingIntensity;
            float _CRTTime;

            // Random function for noise
            float random(float2 st)
            {
                return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            // Apply barrel distortion for CRT curvature
            float2 curveUV(float2 uv)
            {
                uv = uv * 2.0 - 1.0;
                float2 offset = uv.yx * uv.yx * uv.xy * _Curvature;
                uv += offset;
                uv = uv * 0.5 + 0.5;
                return uv;
            }

            // Pixelate the UV coordinates
            float2 pixelate(float2 uv, float2 screenSize)
            {
                float2 pixelCount = screenSize / _PixelSize;
                return floor(uv * pixelCount) / pixelCount;
            }

            // RGB Phosphor pattern
            float3 phosphorMask(float2 uv, float2 screenSize)
            {
                float2 pixelPos = uv * screenSize / _PixelSize;
                int pattern = int(floor(pixelPos.x * 3.0)) % 3;

                float3 mask = float3(0.2, 0.2, 0.2);
                if (pattern == 0) mask.r = 1.0;
                else if (pattern == 1) mask.g = 1.0;
                else mask.b = 1.0;

                // Soften the mask
                return lerp(float3(1, 1, 1), mask, _PhosphorIntensity);
            }

            // Screen flicker
            float flicker()
            {
                float f = sin(_CRTTime * 60.0) * 0.5 + 0.5;
                return 1.0 - (_FlickerIntensity * f * 0.1);
            }

            // Rolling scanline
            float rollingScanline(float2 uv)
            {
                float scanPos = frac(_CRTTime * _RollingScanlineSpeed);
                float dist = abs(uv.y - scanPos);
                dist = min(dist, 1.0 - dist); // Wrap around
                float scanVal = 1.0 - smoothstep(0.0, 0.1, dist);
                return 1.0 + (scanVal * _RollingScanlineIntensity);
            }

            // Simple blur for glow (sample nearby pixels)
            float3 sampleGlow(float2 uv, float2 screenSize)
            {
                float2 texelSize = _GlowSpread / screenSize;
                float3 glow = float3(0, 0, 0);

                // 9-tap box blur
                for (int x = -1; x <= 1; x++)
                {
                    for (int y = -1; y <= 1; y++)
                    {
                        float2 offset = float2(x, y) * texelSize;
                        glow += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset).rgb;
                    }
                }
                return glow / 9.0;
            }

            // Static noise
            float3 staticNoise(float2 uv)
            {
                float noise = random(uv + frac(_CRTTime));
                return float3(noise, noise, noise) * _NoiseIntensity;
            }

            // Color bleed (horizontal smear)
            float3 colorBleed(float2 uv, float2 screenSize)
            {
                float2 texelSize = 1.0 / screenSize;
                float bleedAmount = _ColorBleedIntensity * _PixelSize;

                float r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(texelSize.x * bleedAmount, 0)).r;
                float g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).g;
                float b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - float2(texelSize.x * bleedAmount * 0.5, 0)).b;

                return float3(r, g, b);
            }

            // Interlacing effect
            float interlacing(float2 uv, float2 screenSize)
            {
                float lineNum = floor(uv.y * screenSize.y);
                float frameOffset = floor(frac(_CRTTime * 30.0) * 2.0); // Alternate each frame
                float interlace = fmod(lineNum + frameOffset, 2.0);
                return 1.0 - (interlace * _InterlacingIntensity * 0.3);
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 screenSize = _ScreenParams.xy;
                float2 uv = input.texcoord;

                // Apply screen curvature
                float2 curvedUV = curveUV(uv);

                // Check if we're outside the screen after curvature
                if (curvedUV.x < 0 || curvedUV.x > 1 || curvedUV.y < 0 || curvedUV.y > 1)
                    return half4(0, 0, 0, 1);

                // Pixelate
                float2 pixelUV = pixelate(curvedUV, screenSize);

                // Base color with chromatic aberration
                float3 col;
                if (_ChromaticAberration > 0.0001)
                {
                    float2 chromaOffset = float2(_ChromaticAberration, 0);
                    col.r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelate(curvedUV + chromaOffset, screenSize)).r;
                    col.g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelUV).g;
                    col.b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelate(curvedUV - chromaOffset, screenSize)).b;
                }
                else
                {
                    col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelUV).rgb;
                }

                // Color bleed
                if (_ColorBleedIntensity > 0.0001)
                {
                    float3 bleed = colorBleed(pixelUV, screenSize);
                    col = lerp(col, bleed, _ColorBleedIntensity);
                }

                // Glow
                if (_GlowIntensity > 0.0001)
                {
                    float3 glow = sampleGlow(pixelUV, screenSize);
                    col += glow * _GlowIntensity;
                }

                // RGB Phosphor mask
                if (_PhosphorIntensity > 0.0001)
                {
                    col *= phosphorMask(curvedUV, screenSize);
                }

                // Scanlines
                if (_ScanlineIntensity > 0.0001)
                {
                    float scanline = sin(curvedUV.y * _ScanlineCount * 3.14159) * 0.5 + 0.5;
                    scanline = pow(scanline, 0.5);
                    col *= 1.0 - (_ScanlineIntensity * (1.0 - scanline));
                }

                // Rolling scanline
                if (_RollingScanlineIntensity > 0.0001)
                {
                    col *= rollingScanline(curvedUV);
                }

                // Interlacing
                if (_InterlacingIntensity > 0.0001)
                {
                    col *= interlacing(curvedUV, screenSize);
                }

                // Static noise
                if (_NoiseIntensity > 0.0001)
                {
                    col += staticNoise(curvedUV) - (_NoiseIntensity * 0.5);
                }

                // Screen flicker
                if (_FlickerIntensity > 0.0001)
                {
                    col *= flicker();
                }

                // Vignette
                if (_Vignette > 0.0001)
                {
                    float2 vignetteUV = uv * (1.0 - uv.yx);
                    float vignetteVal = vignetteUV.x * vignetteUV.y * 15.0;
                    vignetteVal = pow(vignetteVal, _Vignette);
                    col *= vignetteVal;
                }

                // Brightness
                col *= _Brightness;

                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
