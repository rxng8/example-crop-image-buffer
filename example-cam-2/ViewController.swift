//
//  ViewController.swift
//  example-cam-2
//
//  Created by Alex Nguyen on 22/07/2021.
//

import UIKit
import AVFoundation
import Accelerate
import CoreImage

class ViewController: UIViewController {

    @IBOutlet weak var pixelDebugView: UIImageView!
    let captureSession = AVCaptureSession()
    var previewLayer: CALayer!
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    var captureDevice: AVCaptureDevice!
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    
    private var cameraConfiguration: CameraConfiguration = .failed
    private var isSessionRunning = false
    
    var converter: vImageConverter?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.attemptToConfigureSession()
        self.setupPreviewLayer()
        self.checkCameraConfigurationAndStartSession()
    }
    
    
    func setupPreviewLayer() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = CGRect(x: 100, y: 100, width: 200, height: 200)
    }
    
    // MARK: Session Start and End methods
    /**
     This method stops a running an AVCaptureSession.
     */
    func stopSession() {
      self.removeObservers()
      sessionQueue.async {
        if self.captureSession.isRunning {
          self.captureSession.stopRunning()
          self.isSessionRunning = self.captureSession.isRunning
        }
      }

    }
    
    /**
     This method starts the AVCaptureSession
     **/
    private func startSession() {
      self.captureSession.startRunning()
      self.isSessionRunning = self.captureSession.isRunning
    }
    
    
    /**
     This method starts an AVCaptureSession based on whether the camera configuration was successful.
     */
    func checkCameraConfigurationAndStartSession() {
      sessionQueue.async {
        switch self.cameraConfiguration {
        case .success:
          self.addObservers()
          self.startSession()
        case .failed:
          DispatchQueue.main.async {
            
          }
        case .permissionDenied:
          DispatchQueue.main.async {
            
          }
        }
      }
    }
    
    // MARK: Session Configuration Methods.
    /**
     This method requests for camera permissions and handles the configuration of the session and stores the result of configuration.
     */
    private func attemptToConfigureSession() {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized:
        self.cameraConfiguration = .success
      case .notDetermined:
        self.sessionQueue.suspend()
        self.requestCameraAccess(completion: { (granted) in
          self.sessionQueue.resume()
        })
      case .denied:
        self.cameraConfiguration = .permissionDenied
      default:
        break
      }

      self.sessionQueue.async {
        self.configureSession()
      }
    }

    /**
     This method requests for camera permissions.
     */
    private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
      AVCaptureDevice.requestAccess(for: .video) { (granted) in
        if !granted {
          self.cameraConfiguration = .permissionDenied
        }
        else {
          self.cameraConfiguration = .success
        }
        completion(granted)
      }
    }


    /**
     This method handles all the steps to configure an AVCaptureSession.
     */
    private func configureSession() {

      guard cameraConfiguration == .success else {
        return
      }
      captureSession.beginConfiguration()

      // Tries to add an AVCaptureDeviceInput.
      guard addVideoDeviceInput() == true else {
        self.captureSession.commitConfiguration()
        self.cameraConfiguration = .failed
        return
      }

      // Tries to add an AVCaptureVideoDataOutput.
      guard addVideoDataOutput() else {
        self.captureSession.commitConfiguration()
        self.cameraConfiguration = .failed
        return
      }

        captureSession.commitConfiguration()
      self.cameraConfiguration = .success
    }

    /**
     This method tries to add an AVCaptureDeviceInput to the current AVCaptureSession.
     */
    private func addVideoDeviceInput() -> Bool {

      /**Tries to get the default back camera.
       */
      guard let camera  = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
        fatalError("Cannot find camera")
      }

      do {
        let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
          return true
        }
        else {
          return false
        }
      }
      catch {
        fatalError("Cannot create video device input")
      }
    }

    /**
     This method tries to add an AVCaptureVideoDataOutput to the current AVCaptureSession.
     */
    private func addVideoDataOutput() -> Bool {

      let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
      videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
      videoDataOutput.alwaysDiscardsLateVideoFrames = true
      videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]

      if captureSession.canAddOutput(videoDataOutput) {
        captureSession.addOutput(videoDataOutput)
        videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
        return true
      }
      return false
    }

    // MARK: Notification Observer Handling
    private func addObservers() {
      
    }

    private func removeObservers() {
      
    }

}

/**
 This enum holds the state of the camera initialization.
 */
enum CameraConfiguration {

  case success
  case failed
  case permissionDenied
}


extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    /** This method delegates the CVPixelBuffer of the frame seen by the camera currently.
     */
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

      // Converts the CMSampleBuffer to a CVPixelBuffer.
      let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

      guard let imagePixelBuffer = pixelBuffer else {
        return
      }
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(imagePixelBuffer)
        print(sourcePixelFormat == kCVPixelFormatType_32ARGB)
        print(sourcePixelFormat == kCVPixelFormatType_32BGRA)
        print(sourcePixelFormat == kCVPixelFormatType_32RGBA)
        
      // Evaluate model with image pixel buffer
        let ciimage = CIImage(cvImageBuffer: imagePixelBuffer)
        
        let newPixelBuffer = resizePixelBuffer(imagePixelBuffer, rect: CGRect(x: 0, y: 500, width: 1080, height: 600))
        
        // Evaluate model with image pixel buffer
          let newciimage = CIImage(cvImageBuffer: newPixelBuffer!)
        
        DispatchQueue.main.async {
            let newui = UIImage(ciImage: newciimage)
            self.pixelDebugView.image = newui
        }
        
    }
}


// MARK: - Extension

extension ViewController {
    
    // Crop
    func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, rect: CGRect) -> CVPixelBuffer? {
        
        CVPixelBufferLockBaseAddress(pixelBuffer,
                                         CVPixelBufferLockFlags.readOnly)
        var error = kvImageNoError
        guard let data = CVPixelBufferGetBaseAddress(pixelBuffer) else {
          return nil
        }
        let bytesPerPixel = 4
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let start = Int(rect.origin.y) * rowBytes + Int(rect.origin.x) * bytesPerPixel
        
        var inBuffer = vImage_Buffer(data: data.advanced(by: start),
                                                       height: vImagePixelCount(rect.height),
                                                       width: vImagePixelCount(rect.width),
                                                       rowBytes: rowBytes)

        var newPixelBuffer: CVPixelBuffer?
        let addressPoint = data.assumingMemoryBound(to: UInt8.self)
        let options = [kCVPixelBufferCGImageCompatibilityKey:true,
                       kCVPixelBufferCGBitmapContextCompatibilityKey:true]
        let status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, Int(rect.width), Int(rect.height), kCVPixelFormatType_32BGRA, &addressPoint[start], Int(rowBytes), nil, nil, options as CFDictionary, &newPixelBuffer)
        if (status != 0) {
            print(status)
            return nil;
        }
        print("done create!")
        
//        var cgImageFormat = vImage_CGImageFormat(
//            bitsPerComponent: 8,
//            bitsPerPixel: 32,
//            colorSpace: nil,
//            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue),
//            version: 0,
//            decode: nil,
//            renderingIntent: .defaultIntent)
//        let cgImage = vImageCreateCGImageFromBuffer(
//            &newPixelBuffer,
//            &cgImageFormat,
//            nil,
//            nil,
//            vImage_Flags(kvImageNoFlags),
//            &error)
//        if let cgImage = cgImage, error == kvImageNoError {
//            DispatchQueue.main.async {
//                let uiimg = UIImage(cgImage: cgImage.takeRetainedValue())
//                self.pixelDebugView.image = uiimg
//            }
//        }
        
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                           CVPixelBufferLockFlags.readOnly)
        
        return newPixelBuffer
    }

    
}
