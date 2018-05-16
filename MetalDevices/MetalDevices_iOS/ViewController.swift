//
//  ViewController.swift
//  MetalDevices_iOS
//
//  Created by leacode on 2018/5/16.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let device = MTLCreateSystemDefaultDevice() {
            var text = "Your system has the following GPU(s):\n"
            text += "\(device.name)"
            label.text = text
        } else {
            fatalError("Your GPU does not support Metal!")
        }
        
    }

}

