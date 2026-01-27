Shader "Retro/PSXCRTEffectURP"
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
            Name "PSXCRTPass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            // ============================================
            // PSX SETTINGS
            // ============================================
            float _PSXColorDepth;        // Bits per channel (1-8, PS1 was ~5)
            float _PSXDitherIntensity;   // Dithering strength
            float _PSXPosterization;     // Additional color banding
            float _PSXResolutionScale;   // Render at lower res (PS1: 320x240)
            float _PSXSaturationBoost;   // PS1 games often had boosted saturation
            float _PSXDarkening;         // Slight darkening for that PS1 look

            // ============================================
            // CRT SETTINGS (from original shader)
            // ============================================
            float _PixelSize;
            float _ScanlineIntensity;
            float _ScanlineCount;
            float _Curvature;
            float _ChromaticAberration;
            float _Vignette;
            float _Brightness;
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

            // ============================================
            // UTILITY FUNCTIONS
            // ============================================
            
            // Random function for noise
            float random(float2 st)
            {
                return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            // ============================================
            // PSX EFFECT FUNCTIONS
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
                // Get dither value
                float dither = getBayerValue(pixelPos);
                dither = (dither - 0.5) * _PSXDitherIntensity;
                
                // Calculate color levels based on bit depth
                float levels = pow(2.0, _PSXColorDepth);
                
                // Apply dithering before quantization
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
                // PS1 typical resolutions: 256x224, 320x240, 512x240, 640x480
                float2 psxRes = screenSize * _PSXResolutionScale;
                psxRes = max(psxRes, float2(160, 120)); // Minimum resolution
                
                float2 pixelUV = floor(uv * psxRes) / psxRes;
                return pixelUV;
            }

            // Saturation adjustment
            float3 adjustSaturation(float3 color, float saturation)
            {
                float luma = dot(color, float3(0.299, 0.587, 0.114));
                return lerp(float3(luma, luma, luma), color, saturation);
            }

            // ============================================
            // CRT EFFECT FUNCTIONS (from original shader)
            // ============================================
            
            // Apply barrel distortion for CRT curvature
            float2 curveUV(float2 uv)
            {
                uv = uv * 2.0 - 1.0;
                float2 offset = uv.yx * uv.yx * uv.xy * _Curvature;
                uv += offset;
                uv = uv * 0.5 + 0.5;
                return uv;
            }

            // CRT Pixelate the UV coordinates
            float2 crtPixelate(float2 uv, float2 screenSize)
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
                dist = min(dist, 1.0 - dist);
                float scanVal = 1.0 - smoothstep(0.0, 0.1, dist);
                return 1.0 + (scanVal * _RollingScanlineIntensity);
            }

            // Simple blur for glow
            float3 sampleGlow(float2 uv, float2 screenSize)
            {
                float2 texelSize = _GlowSpread / screenSize;
                float3 glow = float3(0, 0, 0);

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
                float frameOffset = floor(frac(_CRTTime * 30.0) * 2.0);
                float interlace = fmod(lineNum + frameOffset, 2.0);
                return 1.0 - (interlace * _InterlacingIntensity * 0.3);
            }

            // ============================================
            // MAIN FRAGMENT SHADER
            // ============================================
            half4 frag(Varyings input) : SV_Target
            {
                float2 screenSize = _ScreenParams.xy;
                float2 uv = input.texcoord;

                // ========== CRT: Apply screen curvature first ==========
                float2 curvedUV = curveUV(uv);

                // Check if we're outside the screen after curvature
                if (curvedUV.x < 0 || curvedUV.x > 1 || curvedUV.y < 0 || curvedUV.y > 1)
                    return half4(0, 0, 0, 1);

                // ========== PSX: Resolution reduction ==========
                float2 psxUV = curvedUV;
                if (_PSXResolutionScale < 0.99)
                {
                    psxUV = psxPixelate(curvedUV, screenSize);
                }

                // ========== CRT: Additional pixelation ==========
                float2 pixelUV = psxUV;
                if (_PixelSize > 1.01)
                {
                    pixelUV = crtPixelate(psxUV, screenSize);
                }

                // ========== Sample base color with chromatic aberration ==========
                float3 col;
                if (_ChromaticAberration > 0.0001)
                {
                    float2 chromaOffset = float2(_ChromaticAberration, 0);
                    float2 uvR = _PixelSize > 1.01 ? crtPixelate(psxUV + chromaOffset, screenSize) : psxUV + chromaOffset;
                    float2 uvB = _PixelSize > 1.01 ? crtPixelate(psxUV - chromaOffset, screenSize) : psxUV - chromaOffset;
                    
                    col.r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uvR).r;
                    col.g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelUV).g;
                    col.b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uvB).b;
                }
                else
                {
                    col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelUV).rgb;
                }

                // ========== PSX: Color effects ==========
                float2 pixelPos = curvedUV * screenSize;
                
                // PSX darkening (subtle)
                if (_PSXDarkening > 0.0001)
                {
                    col *= (1.0 - _PSXDarkening * 0.3);
                }

                // PSX saturation boost
                if (_PSXSaturationBoost > 1.0001)
                {
                    col = adjustSaturation(col, _PSXSaturationBoost);
                }

                // PSX posterization (before dithering)
                if (_PSXPosterization > 0.0001)
                {
                    float posterLevels = lerp(256.0, 8.0, _PSXPosterization);
                    col = posterize(col, posterLevels);
                }

                // PSX color depth reduction with dithering
                if (_PSXColorDepth < 7.99)
                {
                    col = psxColorReduce(col, pixelPos);
                }

                // ========== CRT: Color bleed ==========
                if (_ColorBleedIntensity > 0.0001)
                {
                    float3 bleed = colorBleed(pixelUV, screenSize);
                    col = lerp(col, bleed, _ColorBleedIntensity);
                }

                // ========== CRT: Glow ==========
                if (_GlowIntensity > 0.0001)
                {
                    float3 glow = sampleGlow(pixelUV, screenSize);
                    col += glow * _GlowIntensity;
                }

                // ========== CRT: RGB Phosphor mask ==========
                if (_PhosphorIntensity > 0.0001)
                {
                    col *= phosphorMask(curvedUV, screenSize);
                }

                // ========== CRT: Scanlines ==========
                if (_ScanlineIntensity > 0.0001)
                {
                    float scanline = sin(curvedUV.y * _ScanlineCount * 3.14159) * 0.5 + 0.5;
                    scanline = pow(scanline, 0.5);
                    col *= 1.0 - (_ScanlineIntensity * (1.0 - scanline));
                }

                // ========== CRT: Rolling scanline ==========
                if (_RollingScanlineIntensity > 0.0001)
                {
                    col *= rollingScanline(curvedUV);
                }

                // ========== CRT: Interlacing ==========
                if (_InterlacingIntensity > 0.0001)
                {
                    col *= interlacing(curvedUV, screenSize);
                }

                // ========== CRT: Static noise ==========
                if (_NoiseIntensity > 0.0001)
                {
                    col += staticNoise(curvedUV) - (_NoiseIntensity * 0.5);
                }

                // ========== CRT: Screen flicker ==========
                if (_FlickerIntensity > 0.0001)
                {
                    col *= flicker();
                }

                // ========== CRT: Vignette ==========
                if (_Vignette > 0.0001)
                {
                    float2 vignetteUV = uv * (1.0 - uv.yx);
                    float vignetteVal = vignetteUV.x * vignetteUV.y * 15.0;
                    vignetteVal = pow(vignetteVal, _Vignette);
                    col *= vignetteVal;
                }

                // ========== Final brightness ==========
                col *= _Brightness;

                return half4(saturate(col), 1);
            }
            ENDHLSL
        }
    }
}
