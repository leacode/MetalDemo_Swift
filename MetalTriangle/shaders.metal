//
//  shaders.metal
//  MetalTriangle
//
//  Created by leacode on 2018/5/11.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

enum VertextInputIndex {
    VertexInputIndexVertices     = 0,
    VertexInputIndexViewportSize = 1,
};

struct Vertex {
    float4 position [[position]];
    float4 color;
};

struct RasterizerData {
    float4 clipSpacePosition [[position]];
    float4 color;
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
            constant Vertex *vertices [[buffer(VertexInputIndexVertices)]],
            constant vector_uint2 *viewportSizePointer [[buffer(VertexInputIndexViewportSize)]]) {
    
    RasterizerData out;
    out.clipSpacePosition = vector_float4(0.0, 0.0, 0.0, 1.0);
    float2 pixelSpacePosition = vertices[vertexID].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
    out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);
    out.color = vertices[vertexID].color;
    
    return out;
}

fragment float4
fragmentShader(Vertex vert [[stage_in]]) {
    return vert.color;
}
