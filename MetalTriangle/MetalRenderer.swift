//
//  MetalRender.swift
//  MetalCommand_iOS
//
//  Created by leacode on 2018/5/10.
//

import simd
import MetalKit



open class MetalRenderer: NSObject, MTKViewDelegate {
    
    struct Vertex {
        var position: vector_float2
        var color: vector_float4
    }
    
    enum VertextInputIndex: Int {
        case VertextInputIndexVertices = 0
        case VertextInputIndexViewportSize = 1
    }
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    static var viewportSize: vector_uint2 = vector_uint2(0, 0)
    
    public convenience init(mtkView: MTKView) {
        self.init()
        device = mtkView.device
        
        // Load all the shader files with a .metal file extension in the project
        let defaultLibrary = device?.makeDefaultLibrary()
        
        // Load the vertext function from the library
        let vertextFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        
        // Load the fragment function from the library
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")
        
        // Configure a pipeline descriptor that is used to create a pipeline state
        let pipelineStateDesctiptor = MTLRenderPipelineDescriptor()
        pipelineStateDesctiptor.label = "Simple Pipeline"
        pipelineStateDesctiptor.vertexFunction = vertextFunction
        pipelineStateDesctiptor.fragmentFunction = fragmentFunction
        pipelineStateDesctiptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineStateDesctiptor)
        } catch {
            
        }
        // Create the command queue
        commandQueue = device?.makeCommandQueue()
    }
    
    // MARK: - MTKViewDelegate
    public func draw(in view: MTKView) {
        
        let vertexData = [Vertex(position: [ 250, -250], color: [1, 0, 0, 1]),
                          Vertex(position: [ -250, -250], color: [0, 1, 0, 1]),
                          Vertex(position: [ 0, 250], color: [0, 0, 1, 1])]
        
        
        // Create a new command buffer for each render pass to the current drawable
        let commandBuffer = commandQueue?.makeCommandBuffer()
        commandBuffer?.label = "MyCommand"
        
        // Obtain a render pass descriptor, generated from the view's drawable
        if let renderPassDescriptor = view.currentRenderPassDescriptor {
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder?.label = "MyRenderDecoder"
            
            // Set the region of the drawable to which we'll draw.
            renderEncoder?.setViewport(MTLViewport(originX: 0.0,
                                                   originY: 0.0,
                                                   width: Double(MetalRenderer.viewportSize.x),
                                                   height: Double(MetalRenderer.viewportSize.y),
                                                   znear: -1.0, zfar: 1.0))
            renderEncoder?.setRenderPipelineState(pipelineState!)
            
            // We call -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:] to send data from our
            //   Application ObjC code here to our Metal 'vertexShader' function
            // This call has 3 arguments
            //   1) A pointer to the memory we want to pass to our shader
            //   2) The memory size of the data we want passed down
            //   3) An integer index which corresponds to the index of the buffer attribute qualifier
            //      of the argument in our 'vertexShader' function
            
            // You send a pointer to the `triangleVertices` array also and indicate its size
            // The `AAPLVertexInputIndexVertices` enum value corresponds to the `vertexArray`
            // argument in the `vertexShader` function because its buffer attribute also uses
            // the `AAPLVertexInputIndexVertices` enum value for its index
            renderEncoder?.setVertexBytes(vertexData,
                                          length: MemoryLayout<Vertex>.size * 3,
                                          index: VertextInputIndex.VertextInputIndexVertices.rawValue)
            
            // You send a pointer to `_viewportSize` and also indicate its size
            // The `AAPLVertexInputIndexViewportSize` enum value corresponds to the
            // `viewportSizePointer` argument in the `vertexShader` function because its
            //  buffer attribute also uses the `AAPLVertexInputIndexViewportSize` enum value
            //  for its index
            renderEncoder?.setVertexBytes(&MetalRenderer.viewportSize,
                                          length: MemoryLayout<vector_uint2>.size * 3,
                                          index: VertextInputIndex.VertextInputIndexViewportSize.rawValue)
            
            // Draw the 3 vertices of our triangle
            renderEncoder?.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 3)
            
            renderEncoder?.endEncoding()
            
            // Schedule a present once the framebuffer is complete using the current drawable
            commandBuffer?.present(view.currentDrawable!)
        }
        
        // Finalize rendering here and submit the command buffer to the GPU
        commandBuffer?.commit()
    }
    
    /// Called whenever the view size changes or a relayout occurs (such as changing from landscape to
    ///   portrait mode)
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MetalRenderer.viewportSize = vector2(UInt32(size.width), UInt32(size.height))
    }
    
}
