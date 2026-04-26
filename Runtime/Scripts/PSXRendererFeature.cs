using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

namespace Retro.PSXEffects
{
    public class PSXRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class PSXSettings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;

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
        }

        public PSXSettings settings = new PSXSettings();
        private PSXRenderPass renderPass;
        private Material material;

        public override void Create()
        {
            var shader = Shader.Find("Retro/PSXEffectURP");
            if (shader != null)
                material = CoreUtils.CreateEngineMaterial(shader);

            renderPass = new PSXRenderPass(material, settings);
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

    public class PSXRenderPass : ScriptableRenderPass
    {
        private class PassData
        {
            public TextureHandle source;
            public TextureHandle destination;
            public Material material;
        }

        private Material material;
        private PSXRendererFeature.PSXSettings settings;

        // PSX Shader property IDs
        private static readonly int PSXColorDepthID = Shader.PropertyToID("_PSXColorDepth");
        private static readonly int PSXDitherIntensityID = Shader.PropertyToID("_PSXDitherIntensity");
        private static readonly int PSXPosterizationID = Shader.PropertyToID("_PSXPosterization");
        private static readonly int PSXResolutionScaleID = Shader.PropertyToID("_PSXResolutionScale");
        private static readonly int PSXSaturationBoostID = Shader.PropertyToID("_PSXSaturationBoost");
        private static readonly int PSXDarkeningID = Shader.PropertyToID("_PSXDarkening");
        private static readonly int TimeID = Shader.PropertyToID("_CRTTime");

        public PSXRenderPass(Material material, PSXRendererFeature.PSXSettings settings)
        {
            this.material = material;
            this.settings = settings;
        }

        public void UpdateSettings(PSXRendererFeature.PSXSettings settings)
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
            destinationDesc.name = "_PSXTempTexture";
            destinationDesc.clearBuffer = false;

            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            // Set shader properties
            material.SetFloat(PSXColorDepthID, settings.psxColorDepth);
            material.SetFloat(PSXDitherIntensityID, settings.psxDitherIntensity);
            material.SetFloat(PSXPosterizationID, settings.psxPosterization);
            material.SetFloat(PSXResolutionScaleID, settings.psxResolutionScale);
            material.SetFloat(PSXSaturationBoostID, settings.psxSaturationBoost);
            material.SetFloat(PSXDarkeningID, settings.psxDarkening);
            material.SetFloat(TimeID, Time.time);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("PSX Effect", out var passData))
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

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("PSX Effect Copy Back", out var passData))
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
