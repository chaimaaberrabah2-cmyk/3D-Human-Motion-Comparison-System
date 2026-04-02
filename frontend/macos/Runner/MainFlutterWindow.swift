import Cocoa
import FlutterMacOS
import AVFoundation

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // --- Custom Native Camera Discovery Channel ---
    let cameraChannel = FlutterMethodChannel(name: "com.ikram.camera/discovery",
                                              binaryMessenger: flutterViewController.engine.binaryMessenger)
    cameraChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "getModernCameras" {
            if #available(macOS 10.15, *) {
                let session = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                    mediaType: .video,
                    position: .unspecified)
                
                var devicesInfo: [[String: String]] = []
                for device in session.devices {
                    devicesInfo.append([
                        "deviceId": device.uniqueID,
                        "localizedName": device.localizedName
                    ])
                }
                result(devicesInfo)
            } else {
                result([])
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    super.awakeFromNib()
  }
}
