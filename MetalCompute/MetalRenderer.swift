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
        case input = 0
        case output = 1
    }
    
    // The device (aka GPU) we're using to render
    private var device: MTLDevice?
    
    // Our compute pipeline composed of our kernel defined in the .metal shader file
    private var computePipelineState: MTLComputePipelineState?
    
    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    private var renderPipelineState: MTLRenderPipelineState?
    
    // The command Queue from which we'll obtain command buffers
    private var commandQueue: MTLCommandQueue?
    
    // Texture object which serves as the source for our image processing
    private var inputTexture: MTLTexture!
    
    // Texture object which serves as the output for our image processing
    private var outputTexture: MTLTexture!
    
    // The current size of our view so we can use this in our render pipeline
    private static var viewportSize: vector_uint2 = vector_uint2(0, 0)
    
    // Compute kernel parameters
    private var threadgroupSize: MTLSize! = MTLSizeMake(0, 0, 1)
    private var threadgroupCount: MTLSize! = MTLSizeMake(0, 0, 1)

    public convenience init(mtkView: MTKView) {
        self.init()
        device = mtkView.device
        
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        
        /// Create our render pipeline
        
        // Load all the shader files with a .metal file extension in the project
        let defaultLibrary = device?.makeDefaultLibrary()
        
        // Load the kernel function from the library
        guard let kernelFunction = defaultLibrary?.makeFunction(name: "grayscaleKernel") else { return }
        
        do {
            // Create a compute pipeline state
            computePipelineState = try device?.makeComputePipelineState(function: kernelFunction)
        } catch {
            NSLog("Failed to create compute pipeline state, error \(error)")
        }
        
        
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
            renderPipelineState = try device?.makeRenderPipelineState(descriptor: pipelineStateDesctiptor)
        } catch {
            NSLog("%@", "Failed to created pipeline state, error \(error)")
        }
        
        guard let imageFileLocation = Bundle.main.url(forResource: "Image", withExtension: "tga") else { return }
        
        guard let image = MetalImage(tgaLocation: imageFileLocation) else {
            NSLog("Failed to create the image from \(imageFileLocation.absoluteString)")
            return
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        
        // Indicate we're creating a 2D texture.
        textureDescriptor.textureType = .type2D
        // Indicate that each pixel has a Blue, Green, Red, and Alpha channel,
        //    each in an 8 bit unnormalized value (0 maps 0.0 while 255 maps to 1.0)
        textureDescriptor.pixelFormat = MTLPixelFormat.bgra8Unorm
        textureDescriptor.width = image.width
        textureDescriptor.height = image.height
        textureDescriptor.usage = .shaderRead
        
        // Create an input and output texture with similar descriptors.  We'll only
        //   fill in the inputTexture however.  And we'll set the output texture's descriptor
        //   to MTLTextureUsageShaderWrite
        inputTexture = device?.makeTexture(descriptor: textureDescriptor)
        
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        
        outputTexture = device?.makeTexture(descriptor: textureDescriptor)
        
        let region: MTLRegion = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                          size: MTLSize(width: textureDescriptor.width, height: textureDescriptor.height, depth: 1))
        
        // size of each texel * the width of the textures
        let bytesPerRow = 4 * textureDescriptor.width
        
        // Copy the bytes from our data object into the texture
        inputTexture.replace(region: region,
                             mipmapLevel: 0,
                             withBytes: image.data.bytes,
                             bytesPerRow: bytesPerRow)
        
        // Set the compute kernel's threadgroup size of 16x16
        threadgroupSize = MTLSizeMake(16, 16, 1)
        
        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        threadgroupCount.width  = (inputTexture.width  + threadgroupSize.width -  1) / threadgroupSize.width
        threadgroupCount.height = (inputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height
        
        // Since we're only dealing with a 2D data set, set depth to 1
        threadgroupCount.depth = 1
        
        // Create the command queue
        commandQueue = device?.makeCommandQueue()
    }
    
    // MARK: - MTKViewDelegate
    public func draw(in view: MTKView) {
        
        let quadVertices: [Vertex] = [Vertex(position: [ 250,  -250], textureCoordinate: [1.0, 0.0]),
                                      Vertex(position: [-250,  -250], textureCoordinate: [0.0, 0.0]),
                                      Vertex(position: [-250,   250], textureCoordinate: [0.0, 1.0]),
                                      
                                      Vertex(position: [ 250, -250], textureCoordinate: [1.0, 0.0]),
                                      Vertex(position: [-250,  250], textureCoordinate: [0.0, 1.0]),
                                      Vertex(position: [ 250,  250], textureCoordinate: [1.0, 1.0])
        ]
        
        // Create a new command buffer for each render pass to the current drawable
        let commandBuffer = commandQueue?.makeCommandBuffer()
        commandBuffer?.label = "MyCommand"
        
        let computeEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeEncoder?.setComputePipelineState(computePipelineState!)
        computeEncoder?.setTexture(inputTexture,  index: TextureIndex.input.rawValue)
        computeEncoder?.setTexture(outputTexture, index: TextureIndex.output.rawValue)
        computeEncoder?.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        
        computeEncoder?.endEncoding()
        
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
            
            renderEncoder?.setRenderPipelineState(renderPipelineState!)
            
            renderEncoder?.setVertexBytes(quadVertices,
                                          length: MemoryLayout<Vertex>.size * quadVertices.count,
                                          index: VertextInputIndex.vertices.rawValue)
            
            // Here we're sending a pointer to '_viewportSize' and also indicate its size so the whole
            //   think is passed into the shader.  The AAPLVertexInputIndexViewportSize enum value
            ///  corresponds to the 'viewportSizePointer' argument in our 'vertexShader' function
            //   because its buffer attribute qualifier also uses AAPLVertexInputIndexViewportSize
            //   for its index
            renderEncoder?.setVertexBytes(&MetalRenderer.viewportSize,
                                          length: MemoryLayout<vector_uint2>.size,
                                          index: VertextInputIndex.viewportSize.rawValue)
            
            renderEncoder?.setFragmentTexture(outputTexture, index: TextureIndex.output.rawValue)
            
            // Draw the 3 vertices of our triangle
            renderEncoder?.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)
            
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
