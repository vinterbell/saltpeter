# gpu module
A thin wrapper around gpu apis like dx12 and later vulkan and metal. 

## Notes
- No shader compilation or resource management here
- No vertex buffers, use vertex pulling as this makes it so that the huge permutations of vertex layouts don't need to be managed
- No frame management, command submission, or swapchain management here, you can create the resources and command lists needed to do that yourself
- No resource residency management, you can create and destroy resources as needed yourself
- Manual synchronization, commandTextureBarrier, commandBufferBarrier, etc.
- Complete bindless resource binding model except for root constants which can be used to pass in small amounts of data (and for subsequent data access via raw buffers)
- Please use structures that pack to have no padding so that they can be easily passed to the GPU without worrying about alignment issues (mainly dx12 issue as it doesnt have scalar layouts like in vk) https://maraneshi.github.io/HLSL-ConstantBufferLayoutVisualizer/
- Use `core/graphics` module for higher level abstractions

## Vulkan
- vulkan/api.zig is generated using: `zig translate-c C:\VulkanSDK\1.4.304.1\Include\vulkan\vulkan_win32.h -IC:/VulkanSDK/1.4.304.1/Include/ -lc > vk.zig`