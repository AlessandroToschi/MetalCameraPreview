//
//  Preview.swift
//  CameraPreview
//
//  Created by Alessandro Toschi on 09/01/22.
//

import Foundation
import AVFoundation

struct Preview {
    
    static func videoFormats(position: AVCaptureDevice.Position) -> [AVCaptureDevice.Format] {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)?.formats ?? []
    }
    
}

extension AVCaptureDevice.Format: Identifiable {
    
    var resolution: CMVideoDimensions {
        self.formatDescription.dimensions
    }
    
    var fps: Int {
        Int(self.videoSupportedFrameRateRanges[0].maxFrameRate)
    }
    
    var mediaSubType: CMFormatDescription.MediaSubType {
        self.formatDescription.mediaSubType
    }
    
}
