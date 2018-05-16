//
//  ViewController.swift
//  MetalDevices_Mac
//
//  Created by leacode on 2018/5/16.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var textField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let devices = MTLCopyAllDevices()
        guard let _ = devices.first else {
            fatalError("Your GPU does not support Metal!")
        }
        textField.stringValue = "Your system has the following GPU(s):\n"
        for device in devices {
            textField.stringValue += "\(device.name)\n"
        }
    }

}

