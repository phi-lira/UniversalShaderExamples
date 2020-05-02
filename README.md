# Universal Shader Examples
###### This project contains a collection of shader examples for [Universal Render Pipeline](https://unity.com/srp/universal-render-pipeline). 
##### Requisites:
- Unity 2019.3.9f1 or later 
- UniversalRP 7.3.1 or later

#### How to use this examples
- Clone the repo/Download the zip down to your computer
- Load in Unity.
- Examples are located in `_ExampleScenes` folder. Each scene contains a different example bundled with shaders and materials.

# Examples in this project

## Unlit Examples
All unlit shader examples except the first one support realtime shadows (cast and receive).

### 01 UnlitTexture
Basic "hello world" shader. 

### 02 UnlitTexture + Realtime Shadows
Unlit with support for receiving and casting realtime shadows.

### 03 Matcap
Matcap with support of per-pixel normals.

### 04 Screen Space UV
Screen space uv texture mapping.

## Lit Examples
### 50 BakedIndirect
No direct lighting. Global Illumination (skylight + SH and Lightamps) + realtime shadows.

### 51 LitPhysicallyBased
Physically Based Lit shader supporting metallic workflow.


# Resources
* Mori Knob downloaded from Morgan McGuire's [Computer Graphics Archive](https://casual-effects.com/data)
* UV grid textures downloaded from [Helloluxx](https://helloluxx.com/tutorials/cinema4d-2/cinema4d-materials/uv-grids/)
* MatCap textures from [Nidorx Github](https://github.com/nidorx/matcaps)
