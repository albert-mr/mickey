// Renders mickey's menu bar icons from the system's own SF Symbols (mic.fill, mic.slash.fill)
// at the size and weight macOS 26 draws the mic in its recording indicator: 14 pt medium. Hammerspoon cannot load
// SF Symbols itself, so the output (PNG@2x data URLs) is pasted into ICON in mickey.lua.
// Run: swift icons.swift   (needs the Xcode command line tools)
import AppKit
for (symbol, key) in [("mic.fill", "live"), ("mic.slash.fill", "muted")] {
  let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))!
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(img.size.width * 2), pixelsHigh: Int(img.size.height * 2),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = img.size   // 2x pixels, 1x points: macOS reads it back as a Retina image
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  img.draw(in: NSRect(origin: .zero, size: img.size))
  let png = rep.representation(using: .png, properties: [:])!.base64EncodedString()
  print("  \(key) = \"data:image/png;base64,\(png)\",   -- \(symbol) \(Int(img.size.width))x\(Int(img.size.height)) pt")
}
