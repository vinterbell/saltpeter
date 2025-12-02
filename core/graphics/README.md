# graphics module
A higher level graphics module built on top of the `core/gpu` module, managing frame lifecycle, and resident GPU resources like textures and pipelines.

- ShaderCompiler:
    - Usable by itself to compile shaders to dxil or spirv.
- RenderDevice:
    - Manages frame lifecycle and command submission.
- GPUResources:
    - Manages resident GPU resources like textures and pipelines.
- gpu_structures:
    - some common GPU structures used by the graphics module.