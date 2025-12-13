#pragma once

#define BACKEND_VULKAN
#if defined(BACKEND_D3D12)
template<typename T>
struct BufferPtr
{
    uint buffer_index;
    uint offset;

    T Load(uint index)
    {
        ByteAddressBuffer buffer = ResourceDescriptorHeap[buffer_index];
        return buffer.Load<T>(offset + index * sizeof(T));
    }
};

#define ROOT_CONSTANTS(TYPE, NAME) \
    ConstantBuffer<TYPE> NAME : register(b0)

#else
template<typename T>
struct BufferPtr
{
    uint64_t address;

    T Load(uint index)
    {
        return vk::RawBufferLoad<T>(address + index * sizeof(T));
    }
};

#define ROOT_CONSTANTS(TYPE, NAME) \
    [[vk::push_constant]] \
    ConstantBuffer<TYPE> NAME : register(b0)
#endif

static const float PI = 3.14159265;
static const float TAU = 6.28318530;