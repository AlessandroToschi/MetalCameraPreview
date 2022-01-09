//
//  ContentView.swift
//  CameraPreview
//
//  Created by Alessandro Toschi on 09/01/22.
//

import SwiftUI
import MetalViewUI
import AVFoundation
import Combine

struct ContentView: View {
    
    struct Messages {
        static let start = "Start"
        static let stop = "Stop"
    }
        
    @State private var recordButtonText = Messages.start
    @State private var isRecording = false
    @State private var cameraPosition = AVCaptureDevice.Position.back
    @State private var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @State private var captureDeviceFormat: AVCaptureDevice.Format? = nil
    
    private let metalDevice: MTLDevice
    private let captureSession: AVCaptureSession
    private let videoDataOutputDelegate: VideoDataOutputDelgate
    
    init() {
        
        self.metalDevice = MTLCreateSystemDefaultDevice()!
        self.captureSession = AVCaptureSession()
        self.videoDataOutputDelegate = VideoDataOutputDelgate(metalDevice: metalDevice)
        
    }

    var body: some View {
        VStack(spacing: 20.0) {
            MetalView(
                device: self.metalDevice,
                delegate: nil,
                setNeedsDisplayTrigger: nil
            )
                .enableSetNeedsDisplay(true)
                .isPaused(true)
                .clearColor(MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
            if let captureDeviceFormat = self.captureDeviceFormat {
                Text("\(captureDeviceFormat.resolution.width)x\(captureDeviceFormat.resolution.height) - FPS: \(captureDeviceFormat.fps) - Type: \(captureDeviceFormat.mediaSubType.description)")
            }
            HStack(spacing: 20.0) {
                Button(action: {
                    if self.isRecording {
                        self.isRecording = false
                        self.recordButtonText = Messages.start
                        self.captureSession.stopRunning()
                    } else {
                        self.isRecording = true
                        self.recordButtonText = Messages.stop
                        self.captureSession.startRunning()
                    }
                }, label: { Text(recordButtonText) })
                Button(action: {
                    if cameraPosition == .back {
                        cameraPosition = .front
                    } else {
                        cameraPosition = .back
                    }
                }, label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(.largeTitle))
                }).disabled(self.isRecording)
            }
            
        }
        .onAppear(perform: {
            
            self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            
            if self.authorizationStatus == .notDetermined {
                
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                    
                    self.authorizationStatus = granted ? .authorized : .denied
                    
                    if self.authorizationStatus == .authorized {
                        self.setupSession()
                    }
                    
                })
                
            }
            
            if self.authorizationStatus == .authorized {
                self.setupSession()
            }
            
        })
        .disabled(self.authorizationStatus != .authorized)
    }
    
    func setupSession() {

        if self.captureSession.canSetSessionPreset(.high) {
            self.captureSession.sessionPreset = .high
        }
        
        if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.cameraPosition),
           let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice),
           self.captureSession.canAddInput(captureDeviceInput) {
            
            self.captureSession.addInput(captureDeviceInput)
            self.captureDeviceFormat = captureDevice.activeFormat
            
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        videoDataOutput.setSampleBufferDelegate(self.videoDataOutputDelegate, queue: VideoDataOutputDelgate.queue)
        
        if self.captureSession.canAddOutput(videoDataOutput) {
            self.captureSession.addOutput(videoDataOutput)
        }
        
        self.captureSession.commitConfiguration()
        
    }
}

class VideoDataOutputDelgate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    static let queue = DispatchQueue(label: "com.aleto.camera-preview-videodataoutput", qos: .userInitiated)
    
    let metalDevice: MTLDevice
    var texturePublisher: PassthroughSubject<MTLTexture, Never>
    
    init(metalDevice: MTLDevice) {
        
        self.metalDevice = metalDevice
        self.texturePublisher = PassthroughSubject<MTLTexture, Never>()
        
        super.init()
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if let pixelBuffer = sampleBuffer.imageBuffer {
            
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            }
            
            guard let pixelBufferBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let bytesCount = bytesPerRow * height
            
            let textureBuffer = self.metalDevice.makeBuffer(
                bytesNoCopy: pixelBufferBaseAddress,
                length: bytesCount,
                options: .storageModeShared,
                deallocator: nil
            )
            
            let texture = textureBuffer?.makeTexture(
                descriptor: .textureBufferDescriptor(
                    with: .bgra8Unorm,
                    width: width,
                    resourceOptions: .storageModeShared,
                    usage: .shaderRead
                ),
                offset: 0,
                bytesPerRow: bytesPerRow
            )
            
            if let texture = texture {
                self.texturePublisher.send(texture)
            }
            
        }
        
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
