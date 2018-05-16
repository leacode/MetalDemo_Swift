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
    float2 position;
    float2 textureCoordinate;
};

struct RasterizerData {
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
};

vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
            constant Vertex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
            constant vector_uint2 *viewportSizePointer [[ buffer(VertexInputIndexViewportSize) ]]) {
    
    RasterizerData out;
    out.clipSpacePosition = vector_float4(0.0, 0.0, 0.0, 1.0);
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
    out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);
    
    // Set the z component of our clip space position 0 (since we're only rendering in
    //   2-Dimensions for this sample)
    out.clipSpacePosition.z = 0.0;
    
    // Set the w component to 1.0 since we don't need a perspective divide, which is also not
    //   necessary when rendering in 2-Dimensions
    out.clipSpacePosition.w = 1.0;
    
    // Pass our input textureCoordinate straight to our output RasterizerData. This value will be
    //   interpolated with the other textureCoordinate values in the vertices that make up the
    //   triangle.
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    
    return out;
}

    // Fragment function
    fragment float4
    samplingShader(RasterizerData in [[stage_in]],
                   texture2d<half> colorTexture [[ texture(0) ]])
    {
        constexpr sampler textureSampler (mag_filter::linear,
                                          min_filter::linear);
        
        // Sample the texture to obtain a color
        const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
        
        // We return the color of the texture
        return float4(colorSample);
    }
