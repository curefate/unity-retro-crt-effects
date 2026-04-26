using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

namespace Retro.PSXEffects
{
    public class CRTRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class CRTSettings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;

            [Header("Pixelation")]
            [Range(1, 20)] public float pixelSize = 4f;

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

        public CRTSettings settings = new CRTSettings();
        private CRTRenderPass crtPass;
        private Material material;

        public override void Create()
        {
            var shader = Shader.Find("Retro/CRTEffectURP");
            if (shader != null)
                material = CoreUtils.CreateEngineMaterial(shader);

            crtPass = new CRTRenderPass(material, settings);
            crtPass.renderPassEvent = settings.renderPassEvent;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (material == null || renderingData.cameraData.cameraType != CameraType.Game)
                return;

            crtPass.UpdateSettings(settings);
            renderer.EnqueuePass(crtPass);
        }

        protected override void Dispose(bool disposing)
        {
            if (material != null)
                CoreUtils.Destroy(material);
        }
    }

    public class CRTRenderPass : ScriptableRenderPass
    {
        private class PassData
        {
            public TextureHandle source;
            public TextureHandle destination;
            public Material material;
        }

        private Material material;
        private CRTRendererFeature.CRTSettings settings;

        // Shader property IDs
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

        public CRTRenderPass(Material material, CRTRendererFeature.CRTSettings settings)
        {
            this.material = material;
            this.settings = settings;
        }

        public void UpdateSettings(CRTRendererFeature.CRTSettings settings)
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
            destinationDesc.name = "_CRTTempTexture";
            destinationDesc.clearBuffer = false;

            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            // Set all shader properties
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

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("CRT Effect", out var passData))
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

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("CRT Effect Copy Back", out var passData))
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
