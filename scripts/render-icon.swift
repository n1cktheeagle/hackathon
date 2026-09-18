import AppKit
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let route = NSBezierPath()
route.move(to: NSPoint(x: 310, y: 260))
route.curve(to: NSPoint(x: 696, y: 756), controlPoint1: NSPoint(x: 210, y: 610), controlPoint2: NSPoint(x: 810, y: 390))
route.lineWidth = 68; route.lineCapStyle = .round
NSColor(calibratedRed: 27/255, green: 31/255, blue: 29/255, alpha: 1).setStroke(); route.stroke()
NSColor(calibratedRed: 229/255, green: 100/255, blue: 28/255, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 635, y: 695, width: 122, height: 122)).fill()
NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: 673, y: 733, width: 46, height: 46)).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
