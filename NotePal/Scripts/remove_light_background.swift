import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct BackgroundRemovalError: Error, CustomStringConvertible {
    let description: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    throw BackgroundRemovalError(description: "Usage: swift Scripts/remove_light_background.swift <input-png> <output-png>")
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    throw BackgroundRemovalError(description: "Could not read input image.")
}

let width = image.width
let height = image.height
let pixelCount = width * height
var pixels = [UInt8](repeating: 0, count: pixelCount * 4)
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
    throw BackgroundRemovalError(description: "Could not create bitmap context.")
}

context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

let reference = backgroundReferenceColor(from: pixels, width: width, height: height)
let background = connectedBackgroundMask(
    pixels: pixels,
    width: width,
    height: height,
    reference: reference
)
var alpha = alphaMask(from: background, pixels: pixels, width: width, height: height, reference: reference)

// Remove a thin neutral gray matte on the outside edge without cutting into
// actual foreground objects such as the laptop, microphone, table, or bottle.
for _ in 0..<2 {
    trimNeutralEdgeMatte(&alpha, pixels: pixels, width: width, height: height, reference: reference)
}
removeLargeNeutralBackdropIslands(&alpha, pixels: pixels, width: width, height: height)

for index in 0..<pixelCount {
    let base = index * 4
    let opacity = Double(alpha[index]) / 255.0
    pixels[base] = UInt8(Double(pixels[base]) * opacity)
    pixels[base + 1] = UInt8(Double(pixels[base + 1]) * opacity)
    pixels[base + 2] = UInt8(Double(pixels[base + 2]) * opacity)
    pixels[base + 3] = alpha[index]
}

guard
    let outputContext = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ),
    let outputImage = outputContext.makeImage()
else {
    throw BackgroundRemovalError(description: "Could not create output image.")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw BackgroundRemovalError(description: "Could not create PNG destination.")
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    throw BackgroundRemovalError(description: "Could not write output PNG.")
}

print("Wrote \(outputURL.path)")

struct RGB {
    let red: Double
    let green: Double
    let blue: Double
}

func backgroundReferenceColor(from pixels: [UInt8], width: Int, height: Int) -> RGB {
    var redTotal = 0.0
    var greenTotal = 0.0
    var blueTotal = 0.0
    var count = 0.0

    func sample(_ x: Int, _ y: Int) {
        let base = (y * width + x) * 4
        let red = Double(pixels[base])
        let green = Double(pixels[base + 1])
        let blue = Double(pixels[base + 2])

        guard isLightNeutral(red: red, green: green, blue: blue) else {
            return
        }

        redTotal += red
        greenTotal += green
        blueTotal += blue
        count += 1
    }

    let step = max(1, min(width, height) / 160)
    for x in stride(from: 0, to: width, by: step) {
        sample(x, 0)
        sample(x, height - 1)
    }

    for y in stride(from: 0, to: height, by: step) {
        sample(0, y)
        sample(width - 1, y)
    }

    guard count > 0 else {
        return RGB(red: 236, green: 233, blue: 231)
    }

    return RGB(red: redTotal / count, green: greenTotal / count, blue: blueTotal / count)
}

func connectedBackgroundMask(
    pixels: [UInt8],
    width: Int,
    height: Int,
    reference: RGB
) -> [UInt8] {
    var background = [UInt8](repeating: 0, count: width * height)
    var queue = [Int]()
    queue.reserveCapacity(width * height / 3)

    func trySeed(_ x: Int, _ y: Int) {
        let index = y * width + x
        guard background[index] == 0 else {
            return
        }

        let base = index * 4
        if isBackgroundCandidate(
            red: Double(pixels[base]),
            green: Double(pixels[base + 1]),
            blue: Double(pixels[base + 2]),
            reference: reference
        ) {
            background[index] = 1
            queue.append(index)
        }
    }

    for x in 0..<width {
        trySeed(x, 0)
        trySeed(x, height - 1)
    }

    for y in 0..<height {
        trySeed(0, y)
        trySeed(width - 1, y)
    }

    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1

        let x = index % width
        let y = index / width

        if x > 0 {
            trySeed(x - 1, y)
        }
        if x + 1 < width {
            trySeed(x + 1, y)
        }
        if y > 0 {
            trySeed(x, y - 1)
        }
        if y + 1 < height {
            trySeed(x, y + 1)
        }
    }

    return background
}

func alphaMask(
    from background: [UInt8],
    pixels: [UInt8],
    width: Int,
    height: Int,
    reference: RGB
) -> [UInt8] {
    var alpha = [UInt8](repeating: 255, count: width * height)

    for index in 0..<background.count where background[index] == 1 {
        alpha[index] = 0
    }

    return alpha
}

func trimNeutralEdgeMatte(
    _ alpha: inout [UInt8],
    pixels: [UInt8],
    width: Int,
    height: Int,
    reference: RGB
) {
    var remove = [Int]()

    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            let index = y * width + x
            guard alpha[index] == 255 else {
                continue
            }

            let hasTransparentNeighbor =
                alpha[index - 1] == 0 ||
                alpha[index + 1] == 0 ||
                alpha[index - width] == 0 ||
                alpha[index + width] == 0

            guard hasTransparentNeighbor else {
                continue
            }

            let base = index * 4
            let red = Double(pixels[base])
            let green = Double(pixels[base + 1])
            let blue = Double(pixels[base + 2])

            if isBackgroundCandidate(red: red, green: green, blue: blue, reference: reference, relaxed: true) {
                remove.append(index)
            }
        }
    }

    for index in remove {
        alpha[index] = 0
    }
}

func removeLargeNeutralBackdropIslands(
    _ alpha: inout [UInt8],
    pixels: [UInt8],
    width: Int,
    height: Int
) {
    let pixelCount = width * height
    let minimumArea = max(500, pixelCount / 2_500)
    var visited = [UInt8](repeating: 0, count: pixelCount)
    var queue = [Int]()
    var component = [Int]()
    queue.reserveCapacity(pixelCount / 16)
    component.reserveCapacity(minimumArea * 2)

    for start in 0..<pixelCount {
        guard visited[start] == 0, isNeutralBackdropIslandPixel(start, alpha: alpha, pixels: pixels) else {
            continue
        }

        visited[start] = 1
        queue.removeAll(keepingCapacity: true)
        component.removeAll(keepingCapacity: true)
        queue.append(start)

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            component.append(index)

            let x = index % width
            let y = index / width
            let neighbors = [
                x > 0 ? index - 1 : nil,
                x + 1 < width ? index + 1 : nil,
                y > 0 ? index - width : nil,
                y + 1 < height ? index + width : nil
            ].compactMap { $0 }

            for neighbor in neighbors where visited[neighbor] == 0 {
                visited[neighbor] = 1
                if isNeutralBackdropIslandPixel(neighbor, alpha: alpha, pixels: pixels) {
                    queue.append(neighbor)
                }
            }
        }

        if component.count >= minimumArea {
            for index in component {
                alpha[index] = 0
            }
        }
    }
}

func isNeutralBackdropIslandPixel(_ index: Int, alpha: [UInt8], pixels: [UInt8]) -> Bool {
    guard alpha[index] == 255 else {
        return false
    }

    let base = index * 4
    let red = Double(pixels[base])
    let green = Double(pixels[base + 1])
    let blue = Double(pixels[base + 2])
    let brightness = (red + green + blue) / 3
    let saturation = max(red, green, blue) - min(red, green, blue)
    let neutral = abs(red - green) < 24 && abs(green - blue) < 24 && abs(red - blue) < 28

    return brightness > 145 && saturation < 28 && neutral
}

func isBackgroundCandidate(red: Double, green: Double, blue: Double, reference: RGB, relaxed: Bool = false) -> Bool {
    let brightness = (red + green + blue) / 3
    let saturation = max(red, green, blue) - min(red, green, blue)
    let neutral = abs(red - green) < 42 && abs(green - blue) < 42 && abs(red - blue) < 52
    let distance = sqrt(
        pow(red - reference.red, 2) +
        pow(green - reference.green, 2) +
        pow(blue - reference.blue, 2)
    )
    let likelyBlueClothing = blue > red + 8 && blue > green + 2

    if relaxed {
        return brightness > 150 && saturation < 82 && neutral && distance < 115 && !likelyBlueClothing
    }

    return brightness > 160 && saturation < 70 && neutral && distance < 95 && !likelyBlueClothing
}

func isLightNeutral(red: Double, green: Double, blue: Double) -> Bool {
    let brightness = (red + green + blue) / 3
    let saturation = max(red, green, blue) - min(red, green, blue)
    let neutral = abs(red - green) < 34 && abs(green - blue) < 34 && abs(red - blue) < 42

    return brightness > 175 && saturation < 55 && neutral
}
