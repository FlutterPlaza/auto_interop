import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register auto_interop generated plugins.
    // See: https://pub.dev/packages/auto_interop#macos-setup
    registerAutoInteropPlugins(with: flutterViewController.registrar(forPlugin: "AutoInteropPlugins"))

    super.awakeFromNib()
  }
}
