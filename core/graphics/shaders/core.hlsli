#pragma once

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

static const float PI = 3.14159265;
static const float TAU = 6.28318530;