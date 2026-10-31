import AppKit
let canvas = NSImage(size: NSSize(width: 1024, height: 1024))
canvas.lockFocus()
NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.36, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 220, yRadius: 220).fill()
let rope = NSBezierPath()
rope.move(to: NSPoint(x: 125, y: 740))
rope.curve(to: NSPoint(x: 900, y: 740), controlPoint1: NSPoint(x: 350, y: 650), controlPoint2: NSPoint(x: 680, y: 650))
rope.lineWidth = 18
NSColor(calibratedWhite: 0.9, alpha: 1).setStroke()
rope.stroke()
for (x, y) in [(240.0, 305.0), (555.0, 260.0)] {
 NSColor(calibratedRed: 0.96, green: 0.84, blue: 0.61, alpha: 1).setFill()
 NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 235, height: 325), xRadius: 24, yRadius: 24).fill()
 NSColor.white.setFill()
 NSBezierPath(roundedRect: NSRect(x: x+90, y: y+295, width: 40, height: 115), xRadius: 14, yRadius: 14).fill()
 NSColor(calibratedRed: 0.30, green: 0.44, blue: 0.46, alpha: 1).setFill()
 for offset in [105.0, 160.0, 215.0] {
  NSBezierPath(roundedRect: NSRect(x: x+40, y: y+offset, width: 155, height: 13), xRadius: 6, yRadius: 6).fill()
 }
}
canvas.unlockFocus()
let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
