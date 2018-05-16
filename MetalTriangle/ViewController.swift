//
//  ViewController.swift
//  MetalTriangle_MAC
//
//  Created by leacode on 2018/5/10.
//

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
typealias PlatformViewController = UIViewController
#else
import AppKit
typealias PlatformViewController = NSViewController
#endif

import MetalKit

class ViewController: PlatformViewController {

    var mtkView: MTKView!
    var renderer: MetalRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = self.view as! MTKView
        mtkView.device = MTLCreateSystemDefaultDevice()
        
        if mtkView.device == nil { return }
        
        renderer = MetalRenderer(mtkView: mtkView)
        
        // Initialize our renderer with the view size
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        mtkView.delegate = renderer
        
        mtkView.preferredFramesPerSecond = 60
    }


}

