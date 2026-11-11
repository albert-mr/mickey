// mickey's bezel in real Liquid Glass: the capsule macOS 26+ shows for volume and brightness.
// Hammerspoon cannot draw glass, so this small helper does; mickey.lua starts it and writes one line per press to its stdin:
//   show <TAB> centre x <TAB> top y <TAB> 1 = muted <TAB> seconds to stay <TAB> label      (Hammerspoon screen coordinates)
// It quits when stdin closes (Hammerspoon quit or reloaded). Without the binary, mickey falls back to its drawn bezel.
// Build: swiftc -O bezel.swift -o mickey-bezel   (needs Xcode 26 or newer)
import AppKit
import SwiftUI

let margin: CGFloat = 16                    // room around the capsule for the pop's overshoot
let size = NSSize(width: 360, height: 44 + 2 * margin)

final class Model: ObservableObject {
  @Published var shown = false
  @Published var muted = false
  @Published var label = ""
}

struct Bezel: View {
  @ObservedObject var m: Model
  @Environment(\.accessibilityReduceMotion) var calm
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: m.muted ? "mic.slash.fill" : "mic.fill")
        .font(.system(size: 14, weight: .medium))
        .frame(width: 18)
        .contentTransition(.symbolEffect(.replace))   // Apple's own slash draw-on
      Text(m.label)
        .font(.system(size: 13, weight: .semibold))
        .contentTransition(.numericText())            // only the letters that change roll over
    }
    .padding(.horizontal, 16)
    .frame(height: 44)
    .glassEffect(.regular, in: .capsule)
    .scaleEffect(m.shown || calm ? 1 : 0.6, anchor: UnitPoint(x: 0.5, y: -0.5))   // grows out of the menu bar icon above it
    .opacity(m.shown ? 1 : 0)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.top, margin)
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let model = Model()
let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.level = .statusBar
panel.ignoresMouseEvents = true
panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
panel.contentView = NSHostingView(rootView: Bezel(m: model))

var hide: DispatchWorkItem?
func show(cx: CGFloat, top: CGFloat, muted: Bool, secs: Double, label: String) {
  let flip = NSScreen.screens.first?.frame.height ?? 0   // Hammerspoon's y runs down from the primary screen's top
  panel.setFrame(NSRect(x: (cx - size.width / 2).rounded(), y: flip - (top - margin) - size.height, width: size.width, height: size.height), display: true)
  if !model.shown { model.muted = muted; model.label = label }   // a fresh bezel starts in its state; one that is up morphs
  panel.orderFrontRegardless()
  withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { model.muted = muted; model.label = label }
  withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { model.shown = true }
  hide?.cancel()
  let work = DispatchWorkItem {
    withAnimation(.spring(response: 0.3, dampingFraction: 1)) { model.shown = false }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if !model.shown { panel.orderOut(nil) } }
  }
  hide = work
  DispatchQueue.main.asyncAfter(deadline: .now() + secs, execute: work)
}

Thread.detachNewThread {
  while let line = readLine() {
    let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard f.count == 6, f[0] == "show", let cx = Double(f[1]), let top = Double(f[2]), let secs = Double(f[4]) else { continue }
    DispatchQueue.main.async { show(cx: cx, top: top, muted: f[3] == "1", secs: secs, label: f[5]) }
  }
  exit(0)
}
app.run()
