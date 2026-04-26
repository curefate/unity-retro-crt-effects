# Retro CRT Effects for Unity URP

**Forked from [Mushroom-Ano/unity-retro-crt-effects](https://github.com/Mushroom-Ano/unity-retro-crt-effects)**

A collection of retro visual effects for Unity's Universal Render Pipeline (URP), including CRT monitor simulation and PSX-style rendering with VHS-inspired distortions.

## Features

### CRT Effect

- **Scanlines**: Classic horizontal scan lines with adjustable intensity
- **Screen Curvature**: Barrel distortion to simulate curved CRT screens
- **Chromatic Aberration**: Color separation for authentic analog feel
- **Phosphor Glow**: RGB phosphor mask simulation
- **Pixelation**: Adjustable pixel size for retro look
- **Vignette**: Screen edge darkening
- **Flicker**: Subtle screen flicker effect
- **Rolling Scanline**: Animated interference line
- **Static Noise**: VHS-style noise and grain
- **Color Bleed**: Horizontal color smearing
- **Interlacing**: Alternating scan line effect
- **Glow/Bloom**: Soft glow around bright areas

### PSX Effect

- **Color Depth Reduction**: Simulate PS1's limited color palette (5-bit color)
- **Dithering**: Ordered Bayer dithering to hide color banding
- **Posterization**: Additional color banding for that crunchy PS1 look
- **Resolution Scaling**: Render at PS1-like resolutions (320x240)
- **Saturation Boost**: Punchy, saturated colors typical of PS1 games
- **Darkening**: Subtle darkening for authentic PS1 atmosphere

## Installation

### Option 1: Unity Package Manager (Git URL)

1. Open Unity Package Manager (Window > Package Manager)
2. Click the "+" button and select "Add package from git URL"
3. Enter: `https://github.com/curefate/unity-retro-crt-effects.git`

### Option 2: Manual Installation

1. Download or clone this repository
2. Copy the folder to your project's `Packages` directory
3. Unity will automatically detect and import the package

## Usage

### Basic Setup

1. **Add Renderer Feature**
   - Select your URP Renderer asset (usually in `Settings/ForwardRenderer`)
   - Click "Add Renderer Feature"
      - Choose either:
         - `CRT Renderer Feature` for classic CRT effects
         - `PSX Renderer Feature` for PSX-style rendering (no CRT)

2. **Configure Settings**
   - Adjust the parameters in the Renderer Feature inspector
   - Effects are applied in real-time

### Effect Parameters

#### CRT Effect Parameters

- **Pixel Size** (1-20): Size of individual pixels
- **Scanline Intensity** (0-1): Darkness of scan lines
- **Scanline Count** (100-1000): Number of horizontal lines
- **Curvature** (0-0.1): Screen edge curvature amount
- **Chromatic Aberration** (0-0.02): Color separation strength
- **Vignette** (0-1): Edge darkening
- **Brightness** (0.5-1.5): Overall brightness adjustment
- **Phosphor Intensity** (0-1): RGB pixel mask visibility
- **Flicker Intensity** (0-1): Screen flicker amount
- **Rolling Scanline Intensity** (0-1): Interference line brightness
- **Rolling Scanline Speed** (0.1-2): Speed of interference line
- **Glow Intensity** (0-1): Bloom effect strength
- **Glow Spread** (1-10): Bloom radius
- **Noise Intensity** (0-1): Static noise amount
- **Color Bleed Intensity** (0-1): Horizontal color smearing
- **Interlacing Intensity** (0-1): Scan line interlacing

#### PSX Effect Parameters

- **PSX Color Depth** (2-8): Bits per color channel (5 = PS1)
- **PSX Dither Intensity** (0-1): Dithering pattern visibility
- **PSX Posterization** (0-1): Additional color quantization
- **PSX Resolution Scale** (0.1-1): Render resolution (0.25 = 320x240 on 1280x960)
- **PSX Saturation Boost** (1-2): Color saturation multiplier
- **PSX Darkening** (0-1): Subtle darkening amount

## Requirements

- Unity 2022.3 or later
- Universal Render Pipeline (URP) 14.0 or later
- Render Graph enabled in your URP settings

## Examples

### Classic CRT Look

```text
Pixel Size: 4
Scanline Intensity: 0.3
Curvature: 0.02
Chromatic Aberration: 0.003
Vignette: 0.3
Noise Intensity: 0.1
```

### PS1 Style

```text
PSX Color Depth: 5
PSX Dither Intensity: 0.5
PSX Resolution Scale: 0.5
PSX Saturation Boost: 1.2
Scanline Intensity: 0.2
```

### VHS Tape Effect

```text
Rolling Scanline Intensity: 0.3
Rolling Scanline Speed: 0.5
Noise Intensity: 0.2
Color Bleed Intensity: 0.3
Interlacing Intensity: 0.3
Chromatic Aberration: 0.005
```

## Performance Notes

- Effects are optimized with conditional branches to skip disabled features
- For better performance, disable unused effects (set intensity to 0)
- The glow effect uses a 9-tap blur which is more expensive
- PSX color reduction with dithering has minimal performance impact

## Technical Details

- Uses URP's Render Graph API for efficient rendering
- Shaders use HLSL with URP shader libraries
- Post-processing is applied after built-in post-processing
- Effects are screen-space and resolution-independent

## License

MIT License - Feel free to use in personal and commercial projects

## Credits

Created for retro-style game development and nostalgic visual aesthetics.

## Support

For issues, questions, or contributions, please visit:
