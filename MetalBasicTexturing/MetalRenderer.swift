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
        var textureCoordinate: vector_float2
    }
    
    enum VertextInputIndex: Int {
        case vertices = 0
        case viewportSize = 1
    }
    
    enum TextureIndex : Int {
        case baseColor = 0
    }
    
    // The device (aka GPU) we're using to render
    private var device: MTLDevice?
    
    // Our compute pipeline composed of our kernel defined in the .metal shader file
    private var pipelineState: MTLRenderPipelineState?
    
    // The command Queue from which we'll obtain command buffers
    private var commandQueue: MTLCommandQueue?
    
    // The Metal texture object
    private var texture: MTLTexture!
    
    // The Metal buffer in which we store our vertex data
    private var vertexBuffer: MTLBuffer!
    
    // The current size of our view so we can use this in our render pipeline
    private static var viewportSize: vector_uint2 = vector_uint2(0, 0)
    
    // The number of vertices in our vertex buffer
    private var numVertices: Int = 0
    
    /// Creates a grid of 25x15 quads (i.e. 72000 bytes with 2250 vertices are to be loaded into
    ///   a vertex buffer)
    class func generateVertexData() -> NSData {
        let quadVertices: [Vertex] = [Vertex(position: [ 250,  -250], textureCoordinate: [1.0, 0.0]),
                                      Vertex(position: [-250,  -250], textureCoordinate: [0.0, 1.0]),
                                      Vertex(position: [-250,   250], textureCoordinate: [0.0, 1.0]),
                                      
                                      Vertex(position: [ 250, -250], textureCoordinate: [1.0, 0.0]),
                                      Vertex(position: [-250, -250], textureCoordinate: [0.0, 1.0]),
                                      Vertex(position: [ 250,  250], textureCoordinate: [1.0, 1.0])
                                     ]

        let NUM_COLUMNS = 25
        let NUM_ROWS = 15
        let NUM_VERTICES_RED_QUAD = quadVertices.count
        let QUAD_SPACING: Float = 50.0
        
        let dataSize = MemoryLayout<Vertex>.size * 6 * NUM_COLUMNS * NUM_ROWS
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
        
        guard let imageFileLocation = Bundle.main.url(forResource: "Image", withExtension: "tga") else { return }
        
        guard let image = MetalImage(tgaLocation: imageFileLocation) else {
            NSLog("Failed to create the image from \(imageFileLocation.absoluteString)");
            return
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        
        // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
        // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
        textureDescriptor.pixelFormat = MTLPixelFormat.bgra8Unorm
        
        // Set the pixel dimensions of the texture
        textureDescriptor.width = image.width
        textureDescriptor.height = image.height
        
        // Create the texture from the device by using the descriptor
        texture = device?.makeTexture(descriptor: textureDescriptor)
        
        // Calculate the number of bytes per row of our image.
        let bytesPerRow = 4 * image.width
        
        let region: MTLRegion = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                          size: MTLSize(width: image.width, height: image.height, depth: 1))
        
        // Copy the bytes from our data object into the texture
        texture.replace(region: region, mipmapLevel: 0, withBytes: ((image.data as NSData?)?.bytes)!, bytesPerRow: bytesPerRow)
        
        // Set up a simple MTLBuffer with our vertices which include texture coordinates
        let quadVertices: [Vertex] = [Vertex(position: [ 250,  -250], textureCoordinate: [1.0, 0.0]),
                                      Vertex(position: [-250,  -250], textureCoordinate: [0.0, 0.0]),
                                      Vertex(position: [-250,   250], textureCoordinate: [0.0, 1.0]),
                                      
                                      Vertex(position: [ 250, -250], textureCoordinate: [1.0, 0.0]),
                                      Vertex(position: [-250,  250], textureCoordinate: [0.0, 1.0]),
                                      Vertex(position: [ 250,  250], textureCoordinate: [1.0, 1.0])
        ]
        
        vertexBuffer = device?.makeBuffer(bytes: quadVertices,
                                          length: MemoryLayout<Vertex>.size * quadVertices.count,
                                          options: MTLResourceOptions.storageModeShared)
        
        // Calculate the number of vertices by dividing the byte length by the size of each vertex
        numVertices = (MemoryLayout<Vertex>.size * quadVertices.count) / MemoryLayout<Vertex>.size
        
        /// Create our render pipeline
        
        // Load all the shader files with a .metal file extension in the project
        let defaultLibrary = device?.makeDefaultLibrary()
        
        // Load the vertext function from the library
        let vertextFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        
        // Load the fragment function from the library
        let fragmentFunction = defaultLibrary?.makeFunction(name: "samplingShader")
        
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
            
            renderEncoder?.setVertexBuffer(vertexBuffer,
                                           offset: 0,
                                           index: VertextInputIndex.vertices.rawValue)
            
            renderEncoder?.setVertexBytes(&MetalRenderer.viewportSize,
                                          length: MemoryLayout<vector_uint2>.size,
                                          index: VertextInputIndex.viewportSize.rawValue)
            
            
            // Set the texture object.  The AAPLTextureIndexBaseColor enum value corresponds
            ///  to the 'colorMap' argument in our 'samplingShader' function because its
            //   texture attribute qualifier also uses AAPLTextureIndexBaseColor for its index
            renderEncoder?.setFragmentTexture(texture, index: TextureIndex.baseColor.rawValue)
            
            // Draw the 3 vertices of our triangle
            renderEncoder?.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: numVertices)
            
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
