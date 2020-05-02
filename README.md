# Universal Shader Examples
###### This project contains a collection of shader examples for [Universal Render Pipeline](https://unity.com/srp/universal-render-pipeline). 
#### Requisites:
- Unity 2019.3.9f1 or later 
- UniversalRP 7.3.1 or later
- You need [git-lfs](https://git-lfs.github.com/) to download the large asset files. Most Git client UI comes with support to git-lfs.

#### How to use this examples
- Clone the repository. You must have git-lfs enabled.
- Load in Unity.
- Examples are located in `_ExampleScenes` folder. Each scene contains a different example bundled with shaders and materials.

# Examples in this project

## Unlit Examples
All unlit shader examples except the first one support realtime shadows (cast and receive).


### 01 UnlitTexture
Basic "hello world" shader. 
![UnlitTexture](../images/Scene01.png?raw=true)

### 02 UnlitTexture + Realtime Shadows
Unlit with support for receiving and casting realtime shadows.
![UnlitTextureShadows](../images/Scene02.png?raw=true)

### 03 Matcap
Matcap with support of per-pixel normals.
![Matcap](../images/Scene03.png?raw=true)

### 04 Screen Space UV
Screen space uv texture mapping.
![SceenSpaceUV](../images/Scene04.png?raw=true)

## Lit Examples
### 50 BakedIndirect
No direct lighting. Global Illumination (skylight + SH and Lightamps) + realtime shadows.
![UnlitTexture](../images/Scene05.png?raw=true)

### 51 LitPhysicallyBased
Physically Based Lit shader supporting metallic workflow.
![LitPhysicallyBased](../images/Scene06.png?raw=true)

# Resources
* Mori Knob downloaded from Morgan McGuire's [Computer Graphics Archive](https://casual-effects.com/data)
* UV grid textures downloaded from [Helloluxx](https://helloluxx.com/tutorials/cinema4d-2/cinema4d-materials/uv-grids/)
* MatCap textures from [Nidorx Github](https://github.com/nidorx/matcaps)
