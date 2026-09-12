// mkgif.swift — assemble PNG frames into an animated GIF (via ImageIO).
// Usage: mkgif <out.gif> <delay_ms> <frame1.png> <frame2.png> ...
import Foundation
import ImageIO
import CoreGraphics

let a = CommandLine.arguments
guard a.count >= 4, let delayMs = Double(a[2]) else {
    FileHandle.standardError.write("usage: mkgif <out.gif> <delay_ms> <frames...>\n".data(using: .utf8)!)
    exit(1)
}
let outURL = URL(fileURLWithPath: a[1]) as CFURL
let frames = Array(a[3...])

guard let dest = CGImageDestinationCreateWithURL(
        outURL, "com.compuserve.gif" as CFString, frames.count, nil) else {
    FileHandle.standardError.write("mkgif: cannot create \(a[1])\n".data(using: .utf8)!)
    exit(1)
}
let loop: [String: Any] = [kCGImagePropertyGIFDictionary as String:
                           [kCGImagePropertyGIFLoopCount as String: 0]]
CGImageDestinationSetProperties(dest, loop as CFDictionary)
let frameProps: [String: Any] = [kCGImagePropertyGIFDictionary as String:
                                 [kCGImagePropertyGIFDelayTime as String: delayMs / 1000.0]]

for f in frames {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: f) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    CGImageDestinationAddImage(dest, img, frameProps as CFDictionary)
}
if CGImageDestinationFinalize(dest) {
    print("mkgif: wrote \(a[1]) (\(frames.count) frames)")
} else {
    FileHandle.standardError.write("mkgif: finalize failed\n".data(using: .utf8)!)
    exit(1)
}
