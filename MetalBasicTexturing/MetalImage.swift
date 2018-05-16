//
//  MetalImage.swift
//  MetalBasicTexturing
//
//  Created by leacode on 2018/5/14.
//

import Foundation
import simd

class MetalImage: NSObject {

    var width: Int!
    var height: Int!
    var data: NSData!
    
    convenience init?(tgaLocation: URL) {
        self.init()
        
        let fileExtension = tgaLocation.pathExtension
        
        if !(fileExtension.caseInsensitiveCompare("TGA") == ComparisonResult.orderedSame) {
            NSLog("This image loader only loads TGA files");
            return nil
        }

//        var error: NSError?
//        let version = 0x0100
//        let reserved = 0
//        let packer = CStruct(format: "=HHI")
        
        // Structure fitting the layout of a TGA header containing image metadata.
        struct TGAHeader {
            var IDSize: UInt8           // Size of ID info following header
            var colorMapType: UInt8     // Whether this is a paletted image
            var imageType: UInt8        // type of image 0=none, 1=indexed, 2=rgb, 3=grey, +8=rle packed
            
            var colorMapStart: Int8    // Offset to color map in palette
            var colorMapLength: Int8   // Number of colors in palette
            var colorMapBpp: UInt16      // number of bits per palette entry
            
            var xOffset: UInt16         // Number of pixels to the right to start of image
            var yOffset: UInt16         // Number of pixels down to start of image
            var width: UInt16           // Width in pixels
            var height: UInt16          // Height in pixels
            var bitsPerPixel: UInt8     // Bits per pixel 8,16,24,32
            var descriptor: UInt8       // Descriptor bits (flipping, etc)
        }
        
        // Copy the entire file to this fileData variable
        
        let fileData = try! NSData(contentsOf: tgaLocation, options: NSData.ReadingOptions.dataReadingMapped)
        
        let tgaInfo: UnsafePointer<TGAHeader> = fileData.bytes.assumingMemoryBound(to: TGAHeader.self)
        if tgaInfo.pointee.imageType != 2 {
            NSLog("This image loader only supports non-compressed BGR(A) TGA files")
            return nil
        }
        if tgaInfo.pointee.colorMapType > 0 {
            NSLog("This image loader doesn't support TGA files with a colormap")
            return nil
        }
        if tgaInfo.pointee.xOffset > 0 || tgaInfo.pointee.yOffset > 0 {
            NSLog("This image loader doesn't support TGA files with offsets");
            return nil
        }
        if !(tgaInfo.pointee.bitsPerPixel == 32 || tgaInfo.pointee.bitsPerPixel == 24) {
            NSLog("This image loader only supports 24-bit and 32-bit TGA files")
            return nil
        }
        if tgaInfo.pointee.bitsPerPixel == 32 {
            if tgaInfo.pointee.descriptor & 0xF != 8 {
                NSLog("Image loader only supports 32-bit TGA files with 8 bits of alpha");
            }
        } else if tgaInfo.pointee.descriptor > 0 {
            NSLog("Image loader only supports 24-bit TGA files with the default descriptor");
            return nil
        }
        
        width = Int(tgaInfo.pointee.width)
        height = Int(tgaInfo.pointee.height)
        
        // Calculate the byte size of our image data.  Since we store our image data as
        //   32-bits per pixel BGRA data
        let dataSize = width * height * 4
        
        if tgaInfo.pointee.bitsPerPixel == 24 {
            
            // Metal will not understand an image with 24-bpp format so we must convert our
            //   TGA data from the 24-bit BGR format to a 32-bit BGRA format that Metal does
            //   understand (as MTLPixelFormatBGRA8Unorm)
            
            let mutableData = NSMutableData(length: dataSize)!
            
            // TGA spec says the image data is immediately after the header and the ID so set
            //   the pointer to file's start + size of the header + size of the ID
            // Initialize a source pointer with the source image data that's in BGR form
//            let srcImageData = fileData.bytes.assumingMemoryBound(to: UInt8.self).pointee + UInt8(MemoryLayout<TGAHeader>.size) + tgaInfo.pointee.IDSize
            
            let srcImageData = (fileData.bytes + MemoryLayout<TGAHeader>.size + Int(tgaInfo.pointee.IDSize)).assumingMemoryBound(to: UInt8.self)
            
            // Initialize a destination pointer to which you'll store the converted BGRA
            // image data
            let dstImageData = mutableData.mutableBytes.assumingMemoryBound(to: UInt8.self)
            
            // For every row of the image
            for y in 0..<height {
                // For every column of the current row
                for x in 0..<width {
                    // Calculate the index for the first byte of the pixel you're
                    // converting in both the source and destination images
                    let srcPixelIndex = 3 * (y * width + x)
                    let dstPixelIndex = 4 * (y * width + x)
                    
                    // Copy BGR channels from the source to the destination
                    // Set the alpha channel of the destination pixel to 255
                    dstImageData[dstPixelIndex + 0] = srcImageData[srcPixelIndex + 0]
                    dstImageData[dstPixelIndex + 1] = srcImageData[srcPixelIndex + 1]
                    dstImageData[dstPixelIndex + 2] = srcImageData[srcPixelIndex + 2]
                    dstImageData[dstPixelIndex + 3] = 255                    
                }
            }
            data = mutableData
        } else {
            // Metal will understand an image with 32-bpp format so we must only create
            //   an NSData object with the file's image data
            
            // TGA spec says the image data is immediately after the header and the ID so set
            //   the pointer to file's start + size of the header + size of the ID
            let srcImageData = (fileData.bytes + MemoryLayout<TGAHeader>.size + Int(tgaInfo.pointee.IDSize)).assumingMemoryBound(to: UInt8.self)
//            let srcImageData = fileData.bytes.assumingMemoryBound(to: UInt8.self).pointee + UInt8(MemoryLayout<TGAHeader>.size) + tgaInfo.pointee.IDSize
//            let srcImageData = NSData(data: fileData.bytes.assumingMemoryBound(to: UInt8.self).pointee + UInt8(MemoryLayout<TGAHeader>.size) + tgaInfo.pointee.IDSize).bytes
            data = NSData(bytes: srcImageData, length: dataSize)
            
        }
        
    }
    
    
}
