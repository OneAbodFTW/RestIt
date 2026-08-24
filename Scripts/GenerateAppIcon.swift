import AppKit

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "RestIt/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let pixels = 1024
let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [],
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create the app-icon canvas")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let background = NSGradient(colors: [
    NSColor(srgbRed: 0.024, green: 0.306, blue: 0.231, alpha: 1),
    NSColor(srgbRed: 0.063, green: 0.725, blue: 0.506, alpha: 1)
])!
background.draw(in: canvas, angle: -45)

NSColor.white.withAlphaComponent(0.045).setFill()
NSBezierPath(ovalIn: NSRect(x: -60, y: 606, width: 500, height: 500)).fill()
NSColor(srgbRed: 0.655, green: 0.953, blue: 0.816, alpha: 0.08).setFill()
NSBezierPath(ovalIn: NSRect(x: 570, y: -130, width: 620, height: 620)).fill()

let eye = NSBezierPath()
eye.move(to: NSPoint(x: 188, y: 514))
eye.curve(
    to: NSPoint(x: 512, y: 714),
    controlPoint1: NSPoint(x: 275, y: 651),
    controlPoint2: NSPoint(x: 384, y: 714)
)
eye.curve(
    to: NSPoint(x: 836, y: 514),
    controlPoint1: NSPoint(x: 640, y: 714),
    controlPoint2: NSPoint(x: 749, y: 651)
)
eye.curve(
    to: NSPoint(x: 512, y: 314),
    controlPoint1: NSPoint(x: 749, y: 377),
    controlPoint2: NSPoint(x: 640, y: 314)
)
eye.curve(
    to: NSPoint(x: 188, y: 514),
    controlPoint1: NSPoint(x: 384, y: 314),
    controlPoint2: NSPoint(x: 275, y: 377)
)
eye.close()
eye.lineWidth = 62
eye.lineJoinStyle = .round
NSColor.white.setStroke()
eye.stroke()

let drop = NSBezierPath()
drop.move(to: NSPoint(x: 512, y: 636))
drop.curve(
    to: NSPoint(x: 410, y: 455),
    controlPoint1: NSPoint(x: 512, y: 636),
    controlPoint2: NSPoint(x: 410, y: 515)
)
drop.curve(
    to: NSPoint(x: 512, y: 352),
    controlPoint1: NSPoint(x: 410, y: 398),
    controlPoint2: NSPoint(x: 456, y: 352)
)
drop.curve(
    to: NSPoint(x: 614, y: 455),
    controlPoint1: NSPoint(x: 568, y: 352),
    controlPoint2: NSPoint(x: 614, y: 398)
)
drop.curve(
    to: NSPoint(x: 512, y: 636),
    controlPoint1: NSPoint(x: 614, y: 515),
    controlPoint2: NSPoint(x: 512, y: 636)
)
drop.close()

NSGraphicsContext.saveGraphicsState()
drop.addClip()
let dropGradient = NSGradient(colors: [
    NSColor(srgbRed: 0.404, green: 0.910, blue: 0.976, alpha: 1),
    NSColor(srgbRed: 0.800, green: 0.984, blue: 0.945, alpha: 1)
])!
dropGradient.draw(in: drop.bounds, angle: 90)
NSGraphicsContext.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.68).setFill()
NSBezierPath(ovalIn: NSRect(x: 456, y: 468, width: 46, height: 68)).fill()

NSColor.white.withAlphaComponent(0.72).setStroke()
for (start, end) in [
    (NSPoint(x: 344, y: 788), NSPoint(x: 312, y: 854)),
    (NSPoint(x: 512, y: 822), NSPoint(x: 512, y: 892)),
    (NSPoint(x: 680, y: 788), NSPoint(x: 712, y: 854))
] {
    let lash = NSBezierPath()
    lash.move(to: start)
    lash.line(to: end)
    lash.lineWidth = 34
    lash.lineCapStyle = .round
    lash.stroke()
}

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the app icon")
}
try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
print("Generated \(outputPath)")

