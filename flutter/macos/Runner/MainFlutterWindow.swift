import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 1200 by 800, or 90% of the screen when that is smaller, in its middle.
    let area = (self.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    self.setContentSize(NSSize(width: min(1200, area.width * 0.9), height: min(800, area.height * 0.9)))
    self.contentMinSize = NSSize(width: 400, height: 560)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
