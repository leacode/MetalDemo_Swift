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
    
    var vertexBuffer: MTLBuffer!
    var numVertices: Int = 0
    
    /// Creates a grid of 25x15 quads (i.e. 72000 bytes with 2250 vertices are to be loaded into
    ///   a vertex buffer)
    class func generateVertexData() -> NSData {
        let quadVertices: [Vertex] = [Vertex(position: [-20,  20], color: [1, 0, 0, 1]),
                                      Vertex(position: [ 20,  20], color: [0, 0, 1, 1]),
                                      Vertex(position: [-20, -20], color: [0, 1, 0, 1]),
                                      
                                      Vertex(position: [ 20, -20], color: [1, 0, 0, 1]),
                                      Vertex(position: [-20, -20], color: [0, 1, 0, 1]),
                                      Vertex(position: [ 20,  20], color: [0, 0, 1, 1])
                                     ]

        let NUM_COLUMNS = 25
        let NUM_ROWS = 15
        let NUM_VERTICES_RED_QUAD = quadVertices.count
        let QUAD_SPACING: Float = 50.0
        
//        MemoryLayout.size(ofValue: quadVertices)
        
        let dataSize = MemoryLayout<Vertex>.size * quadVertices.count * NUM_COLUMNS * NUM_ROWS
        let vertexData: NSMutableData = NSMutableData(length: dataSize)!
        
        var currentQuad: UnsafeMutablePointer<Vertex> = vertexData.mutableBytes.assumingMemoryBound(to: Vertex.self)
        
        for row in 0..<NUM_ROWS {
            for column in 0..<NUM_COLUMNS {
                var upperLeftPosition = vector_float2()

                upperLeftPosition.x = (-Float(NUM_COLUMNS)/2.0 + Float(column)) * QUAD_SPACING + QUAD_SPACING/2.0
                upperLeftPosition.y = (-Float(NUM_ROWS)/2.0 + Float(row)) * QUAD_SPACING + QUAD_SPACING/2.0
                
                memcpy(currentQuad, quadVertices, MemoryLayout<Vertex>.size * 6)
                for vertextInQuad in 0..<NUM_VERTICES_RED_QUAD {
                    currentQuad[vertextInQuad].position += upperLeftPosition
                }
                currentQuad += 6
            }
        }
        
        return vertexData
    }

    public convenience init(mtkView: MTKView) {
        self.init()
        device = mtkView.device
        
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        
        
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
            NSLog("%@", "Failed to created pipeline state, error \(error)")
        }
        
        let vertexData = MetalRenderer.generateVertexData()

        vertexBuffer = device?.makeBuffer(length: vertexData.length, options: MTLResourceOptions.storageModeShared)
        
        memcpy(vertexBuffer.contents(), vertexData.bytes, vertexData.length);
        
        // Calculate the number of vertices by dividing the byte length by the size of each vertex
        numVertices = vertexData.length / MemoryLayout<Vertex>.size;
        
        // Create the command queue
        commandQueue = device?.makeCommandQueue()
    }
    
    // MARK: - MTKViewDelegate
    public func draw(in view: MTKView) {
        
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
                                                   znear: 0.0, zfar: 1.0))
            renderEncoder?.setRenderPipelineState(pipelineState!)
            
            // We call -[MTLRenderCommandEncoder setVertexBuffer:offset:atIndex:] to send data in our
            //   preloaded MTLBuffer from our ObjC code here to our Metal 'vertexShader' function
            // This call has 3 arguments
            //   1) buffer - The buffer object containing the data we want passed down
            //   2) offset - They byte offset from the beginning of the buffer which indicates what
            //      'vertexPointer' point to.  In this case we pass 0 so data at the very beginning is
            //      passed down.
            //      We'll learn about potential uses of the offset in future samples
            //   3) index - An integer index which corresponds to the index of the buffer attribute
            //      qualifier of the argument in our 'vertexShader' function.  Note, this parameter is
            //      the same as the 'index' parameter in
            //              -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:]
            //
            renderEncoder?.setVertexBuffer(vertexBuffer,
                                           offset: 0,
                                           index: VertextInputIndex.VertextInputIndexVertices.rawValue)
            
            // You send a pointer to `_viewportSize` and also indicate its size
            // The `AAPLVertexInputIndexViewportSize` enum value corresponds to the
            // `viewportSizePointer` argument in the `vertexShader` function because its
            //  buffer attribute also uses the `AAPLVertexInputIndexViewportSize` enum value
            //  for its index
            renderEncoder?.setVertexBytes(&MetalRenderer.viewportSize,
                                          length: MemoryLayout<vector_uint2>.size,
                                          index: VertextInputIndex.VertextInputIndexViewportSize.rawValue)
            
            // Draw the 3 vertices of our triangle
            renderEncoder?.drawPrimitives(type: MTLPrimitiveType.triangle,
                                          vertexStart: 0,
                                          vertexCount: numVertices)
            
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
