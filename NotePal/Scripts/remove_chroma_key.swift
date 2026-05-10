import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ChromaError: Error, CustomStringConvertible {
    let description: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3 || arguments.count == 6 else {
    throw ChromaError(description: "Usage: swift Scripts/remove_chroma_key.swift <input-png> <output-png> [key-red key-green key-blue]")
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let keyColor: (red: Double, green: Double, blue: Double)

if arguments.count == 6 {
    guard
        let red = Double(arguments[3]),
        let green = Double(arguments[4]),
        let blue = Double(arguments[5])
    else {
        throw ChromaError(description: "Key color values must be numeric 0...255 components.")
    }

    keyColor = (red, green, blue)
} else {
    keyColor = (0, 255, 0)
}

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    throw ChromaError(description: "Could not read input image.")
}

let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    throw ChromaError(description: "Could not create bitmap context.")
}

context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

for index in stride(from: 0, to: pixels.count, by: 4) {
    let red = Double(pixels[index])
    let green = Double(pixels[index + 1])
    let blue = Double(pixels[index + 2])

    let keyChannel = max(keyColor.red, keyColor.green, keyColor.blue)
    let nonKeyMax = max(
        keyColor.red == keyChannel ? 0 : red,
        max(
            keyColor.green == keyChannel ? 0 : green,
            keyColor.blue == keyChannel ? 0 : blue
        )
    )
    let actualKeyChannel: Double

    if keyColor.red == keyChannel {
        actualKeyChannel = red
    } else if keyColor.green == keyChannel {
        actualKeyChannel = green
    } else {
        actualKeyChannel = blue
    }

    let keyDominance = actualKeyChannel - nonKeyMax
    let distanceFromKey = sqrt(
        pow(red - keyColor.red, 2) +
        pow(green - keyColor.green, 2) +
        pow(blue - keyColor.blue, 2)
    )

    if keyDominance > 80 && distanceFromKey < 170 {
        let opacity = max(0, min(1, (distanceFromKey - 45) / 125))
        pixels[index + 3] = UInt8(opacity * 255)

        if opacity < 0.98 {
            pixels[index] = UInt8(red * opacity)
            pixels[index + 1] = UInt8(green * opacity)
            pixels[index + 2] = UInt8(blue * opacity)
        }
    }
}

guard let outputContext = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
), let outputImage = outputContext.makeImage() else {
    throw ChromaError(description: "Could not create output image.")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw ChromaError(description: "Could not create output PNG destination.")
}

CGImageDestinationAddImage(destination, outputImage, nil)

guard CGImageDestinationFinalize(destination) else {
    throw ChromaError(description: "Could not write output PNG.")
}

print("Wrote \(outputURL.path)")
