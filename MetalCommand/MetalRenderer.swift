//
//  MetalRender.swift
//  MetalCommand_iOS
//
//  Created by leacode on 2018/5/10.
//

import simd
import MetalKit

typealias Color = (red: Double, green: Double, blue: Double, alpha: Double)

open class MetalRenderer: NSObject, MTKViewDelegate {
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    public convenience init(mtkView: MTKView) {
        self.init()
        device = mtkView.device
        commandQueue = device?.makeCommandQueue()
    }
    
    /// Gradually cycles through different colors on each invocation.  Generally you would just pick
    ///   a single clear color, set it once and forget, but since that would make this sample
    ///   very boring we'll just return a different clear color each frame :)
    
    
    func makeFancyColor() -> Color {
        
        struct ColorConstant{
            static var growing = true
            static var primaryChannel: Int = 0
            static var colorChannels: [Double] = [1.0, 0.0, 0.0, 1.0]
        }
        
        let DynamicColorRate: Double = 0.002
        
        if ColorConstant.growing {
            let dynamicChannelIndex: Int = (ColorConstant.primaryChannel + 1) % 3
            ColorConstant.colorChannels[dynamicChannelIndex] += DynamicColorRate
            if ColorConstant.colorChannels[dynamicChannelIndex] >= 1.0 {
                ColorConstant.growing = false
                ColorConstant.primaryChannel = dynamicChannelIndex
            }
        } else {
            let dynamicChannelIndex: Int = (ColorConstant.primaryChannel + 2) % 3
            ColorConstant.colorChannels[dynamicChannelIndex] -= DynamicColorRate
            if ColorConstant.colorChannels[dynamicChannelIndex] <= 0.0 {
                ColorConstant.growing = true
            }
        }
        var color: Color
        color.red = ColorConstant.colorChannels[0]
        color.green = ColorConstant.colorChannels[1]
        color.blue = ColorConstant.colorChannels[2]
        color.alpha = ColorConstant.colorChannels[3]
        return color
    }
    
    static var i = 0
    
    // MARK: - MTKViewDelegate
    public func draw(in view: MTKView) {
        
        if MetalRenderer.i%60 == 0 {
            print("draw \(MetalRenderer.i/60)")
        }
        MetalRenderer.i += 1
        
        let color = self.makeFancyColor()
        
        view.clearColor = MTLClearColorMake(color.red, color.green, color.blue, color.alpha)
        
        // Create a new command buffer for each render pass to the current drawable
        let commandBuffer = commandQueue?.makeCommandBuffer()
        commandBuffer?.label = "MyCommand"
        
        // Obtain a render pass descriptor, generated from the view's drawable
        if let renderPassDescriptor = view.currentRenderPassDescriptor {
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder?.label = "MyRenderDecoder"
            
            // We would normally use the render command encoder to draw our objects, but for
            //   the purposes of this sample, all we need is the GPU clear command that
            //   Metal implicitly performs when we create the encoder.
            
            // Since we aren't drawing anything, indicate we're finished using this encoder
            renderEncoder?.endEncoding()
            
            // Add a final command to present the cleared drawable to the screen
            commandBuffer?.present(view.currentDrawable!)
        }
        
        // Finalize rendering here and submit the command buffer to the GPU
        commandBuffer?.commit()
    }
    
    /// Called whenever the view size changes or a relayout occurs (such as changing from landscape to
    ///   portrait mode)
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
}
