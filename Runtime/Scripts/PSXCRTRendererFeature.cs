using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

namespace Retro.CRTEffects
{
    public class PSXCRTRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class PSXCRTSettings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;

            [Header("=== PSX EFFECTS ===")]
            
            [Tooltip("Color bit depth per channel. PS1 used ~5 bits (32 levels). Lower = more banding.")]
            [Range(2, 8)] public float psxColorDepth = 5f;
            
            [Tooltip("Ordered dithering intensity. PS1 used dithering to hide color banding.")]
            [Range(0, 1)] public float psxDitherIntensity = 0.5f;
            
            [Tooltip("Additional color posterization for that crunchy PS1 look.")]
            [Range(0, 1)] public float psxPosterization = 0.2f;
            
            [Tooltip("Resolution scale. 0.25 = PS1-like (320x240 on 1280x960). 1.0 = native res.")]
            [Range(0.1f, 1f)] public float psxResolutionScale = 0.5f;
            
            [Tooltip("Saturation boost. PS1 games often had punchy, saturated colors.")]
            [Range(1f, 2f)] public float psxSaturationBoost = 1.2f;
            
            [Tooltip("Subtle darkening for that authentic PS1 atmosphere.")]
            [Range(0, 1)] public float psxDarkening = 0.1f;

            [Header("=== CRT EFFECTS ===")]
            
            [Header("Pixelation")]
            [Range(1, 20)] public float pixelSize = 1f;

            [Header("Scanlines")]
            [Range(0, 1)] public float scanlineIntensity = 0.3f;
            [Range(100, 1000)] public float scanlineCount = 300f;

            [Header("Distortion")]
            [Range(0, 0.1f)] public float curvature = 0.02f;
            [Range(0, 0.02f)] public float chromaticAberration = 0.003f;

            [Header("Color")]
            [Range(0, 1)] public float vignette = 0.3f;
            [Range(0.5f, 1.5f)] public float brightness = 1f;

            [Header("RGB Phosphor")]
            [Range(0, 1)] public float phosphorIntensity = 0f;

            [Header("Flicker")]
            [Range(0, 1)] public float flickerIntensity = 0f;

            [Header("Rolling Scanline")]
            [Range(0, 1)] public float rollingScanlineIntensity = 0f;
            [Range(0.1f, 2f)] public float rollingScanlineSpeed = 0.5f;

            [Header("Glow")]
            [Range(0, 1)] public float glowIntensity = 0f;
            [Range(1, 10)] public float glowSpread = 3f;

            [Header("Static Noise")]
            [Range(0, 1)] public float noiseIntensity = 0f;

            [Header("Color Bleed")]
            [Range(0, 1)] public float colorBleedIntensity = 0f;

            [Header("Interlacing")]
            [Range(0, 1)] public float interlacingIntensity = 0f;
        }

        public PSXCRTSettings settings = new PSXCRTSettings();
        private PSXCRTRenderPass renderPass;
        private Material material;

        public override void Create()
        {
            var shader = Shader.Find("Retro/PSXCRTEffectURP");
            if (shader != null)
                material = CoreUtils.CreateEngineMaterial(shader);

            renderPass = new PSXCRTRenderPass(material, settings);
            renderPass.renderPassEvent = settings.renderPassEvent;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (material == null || renderingData.cameraData.cameraType != CameraType.Game)
                return;

            renderPass.UpdateSettings(settings);
            renderer.EnqueuePass(renderPass);
        }

        protected override void Dispose(bool disposing)
        {
            if (material != null)
                CoreUtils.Destroy(material);
        }
    }

    public class PSXCRTRenderPass : ScriptableRenderPass
    {
        private class PassData
        {
            public TextureHandle source;
            public TextureHandle destination;
            public Material material;
        }

        private Material material;
        private PSXCRTRendererFeature.PSXCRTSettings settings;

        // PSX Shader property IDs
        private static readonly int PSXColorDepthID = Shader.PropertyToID("_PSXColorDepth");
        private static readonly int PSXDitherIntensityID = Shader.PropertyToID("_PSXDitherIntensity");
        private static readonly int PSXPosterizationID = Shader.PropertyToID("_PSXPosterization");
        private static readonly int PSXResolutionScaleID = Shader.PropertyToID("_PSXResolutionScale");
        private static readonly int PSXSaturationBoostID = Shader.PropertyToID("_PSXSaturationBoost");
        private static readonly int PSXDarkeningID = Shader.PropertyToID("_PSXDarkening");

        // CRT Shader property IDs
        private static readonly int PixelSizeID = Shader.PropertyToID("_PixelSize");
        private static readonly int ScanlineIntensityID = Shader.PropertyToID("_ScanlineIntensity");
        private static readonly int ScanlineCountID = Shader.PropertyToID("_ScanlineCount");
        private static readonly int CurvatureID = Shader.PropertyToID("_Curvature");
        private static readonly int ChromaticAberrationID = Shader.PropertyToID("_ChromaticAberration");
        private static readonly int VignetteID = Shader.PropertyToID("_Vignette");
        private static readonly int BrightnessID = Shader.PropertyToID("_Brightness");
        private static readonly int PhosphorIntensityID = Shader.PropertyToID("_PhosphorIntensity");
        private static readonly int FlickerIntensityID = Shader.PropertyToID("_FlickerIntensity");
        private static readonly int RollingScanlineIntensityID = Shader.PropertyToID("_RollingScanlineIntensity");
        private static readonly int RollingScanlineSpeedID = Shader.PropertyToID("_RollingScanlineSpeed");
        private static readonly int GlowIntensityID = Shader.PropertyToID("_GlowIntensity");
        private static readonly int GlowSpreadID = Shader.PropertyToID("_GlowSpread");
        private static readonly int NoiseIntensityID = Shader.PropertyToID("_NoiseIntensity");
        private static readonly int ColorBleedIntensityID = Shader.PropertyToID("_ColorBleedIntensity");
        private static readonly int InterlacingIntensityID = Shader.PropertyToID("_InterlacingIntensity");
        private static readonly int TimeID = Shader.PropertyToID("_CRTTime");

        public PSXCRTRenderPass(Material material, PSXCRTRendererFeature.PSXCRTSettings settings)
        {
            this.material = material;
            this.settings = settings;
        }

        public void UpdateSettings(PSXCRTRendererFeature.PSXCRTSettings settings)
        {
            this.settings = settings;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (material == null)
                return;

            var resourceData = frameData.Get<UniversalResourceData>();

            if (resourceData.isActiveTargetBackBuffer)
                return;

            var source = resourceData.activeColorTexture;

            var destinationDesc = renderGraph.GetTextureDesc(source);
            destinationDesc.name = "_PSXCRTTempTexture";
            destinationDesc.clearBuffer = false;

            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            // Set PSX shader properties
            material.SetFloat(PSXColorDepthID, settings.psxColorDepth);
            material.SetFloat(PSXDitherIntensityID, settings.psxDitherIntensity);
            material.SetFloat(PSXPosterizationID, settings.psxPosterization);
            material.SetFloat(PSXResolutionScaleID, settings.psxResolutionScale);
            material.SetFloat(PSXSaturationBoostID, settings.psxSaturationBoost);
            material.SetFloat(PSXDarkeningID, settings.psxDarkening);

            // Set CRT shader properties
            material.SetFloat(PixelSizeID, settings.pixelSize);
            material.SetFloat(ScanlineIntensityID, settings.scanlineIntensity);
            material.SetFloat(ScanlineCountID, settings.scanlineCount);
            material.SetFloat(CurvatureID, settings.curvature);
            material.SetFloat(ChromaticAberrationID, settings.chromaticAberration);
            material.SetFloat(VignetteID, settings.vignette);
            material.SetFloat(BrightnessID, settings.brightness);
            material.SetFloat(PhosphorIntensityID, settings.phosphorIntensity);
            material.SetFloat(FlickerIntensityID, settings.flickerIntensity);
            material.SetFloat(RollingScanlineIntensityID, settings.rollingScanlineIntensity);
            material.SetFloat(RollingScanlineSpeedID, settings.rollingScanlineSpeed);
            material.SetFloat(GlowIntensityID, settings.glowIntensity);
            material.SetFloat(GlowSpreadID, settings.glowSpread);
            material.SetFloat(NoiseIntensityID, settings.noiseIntensity);
            material.SetFloat(ColorBleedIntensityID, settings.colorBleedIntensity);
            material.SetFloat(InterlacingIntensityID, settings.interlacingIntensity);
            material.SetFloat(TimeID, Time.time);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("PSX CRT Effect", out var passData))
            {
                passData.source = source;
                passData.destination = destination;
                passData.material = material;

                builder.UseTexture(source);
                builder.SetRenderAttachment(destination, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("PSX CRT Effect Copy Back", out var passData))
            {
                passData.source = destination;
                passData.destination = source;

                builder.UseTexture(destination);
                builder.SetRenderAttachment(source, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), 0, false);
                });
            }
        }
    }
}
