import AppKit
import CoreImage
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct ExtractionError: Error, CustomStringConvertible {
    let description: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    throw ExtractionError(description: "Usage: swift Scripts/extract_pet_asset.swift <source-image> <output-png>")
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard let inputImage = CIImage(contentsOf: sourceURL) else {
    throw ExtractionError(description: "Could not load image at \(sourceURL.path)")
}

let segmentation = VNGeneratePersonSegmentationRequest()
segmentation.qualityLevel = .accurate
segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8

let handler = VNImageRequestHandler(ciImage: inputImage)
try handler.perform([segmentation])

guard let maskBuffer = segmentation.results?.first?.pixelBuffer else {
    throw ExtractionError(description: "Vision did not produce a person mask.")
}

let maskImage = CIImage(cvPixelBuffer: maskBuffer)
let scaleX = inputImage.extent.width / maskImage.extent.width
let scaleY = inputImage.extent.height / maskImage.extent.height
let scaledMask = maskImage
    .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    .cropped(to: inputImage.extent)

let transparentBackground = CIImage(color: .clear).cropped(to: inputImage.extent)
let personCutout = inputImage.applyingFilter(
    "CIBlendWithMask",
    parameters: [
        kCIInputBackgroundImageKey: transparentBackground,
        kCIInputMaskImageKey: scaledMask
    ]
)

// Keep foreground objects in front of the person while still removing the
// wooden wall background. Vision person segmentation is good for the person,
// but it intentionally drops the desk, laptop, and microphone.
let foregroundObjectMask = foregroundObjectMaskImage(
    width: Int(inputImage.extent.width),
    height: Int(inputImage.extent.height)
)

let foregroundScene = inputImage.applyingFilter(
    "CIBlendWithMask",
    parameters: [
        kCIInputBackgroundImageKey: transparentBackground,
        kCIInputMaskImageKey: foregroundObjectMask
    ]
)

let cutout = foregroundScene.composited(over: personCutout)

let context = CIContext(options: [.useSoftwareRenderer: false])
guard let cutoutCGImage = context.createCGImage(cutout, from: inputImage.extent) else {
    throw ExtractionError(description: "Could not render extracted person.")
}

let cropped = cropToVisiblePixels(cutoutCGImage, alphaThreshold: 18, padding: 18) ?? cutoutCGImage
let finalImage = renderPetCanvas(from: cropped, canvasSize: 512, inset: 22)

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw ExtractionError(description: "Could not create PNG destination.")
}

CGImageDestinationAddImage(destination, finalImage, nil)

guard CGImageDestinationFinalize(destination) else {
    throw ExtractionError(description: "Could not write PNG to \(outputURL.path)")
}

print("Wrote \(outputURL.path)")

func cropToVisiblePixels(_ image: CGImage, alphaThreshold: UInt8, padding: Int) -> CGImage? {
    guard let pixels = rgbaPixels(from: image) else {
        return nil
    }

    let width = image.width
    let height = image.height
    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0
    var foundPixel = false

    for y in 0..<height {
        for x in 0..<width {
            let alpha = pixels[(y * width + x) * 4 + 3]
            guard alpha > alphaThreshold else {
                continue
            }

            foundPixel = true
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard foundPixel else {
        return nil
    }

    minX = max(0, minX - padding)
    minY = max(0, minY - padding)
    maxX = min(width - 1, maxX + padding)
    maxY = min(height - 1, maxY + padding)

    return image.cropping(
        to: CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    )
}

func rgbaPixels(from image: CGImage) -> [UInt8]? {
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
        return nil
    }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

func renderPetCanvas(from image: CGImage, canvasSize: Int, inset: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

    guard let context = CGContext(
        data: nil,
        width: canvasSize,
        height: canvasSize,
        bitsPerComponent: 8,
        bytesPerRow: canvasSize * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Could not create canvas context.")
    }

    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    context.interpolationQuality = .high

    let availableWidth = CGFloat(canvasSize - inset * 2)
    let availableHeight = CGFloat(canvasSize - inset * 2)
    let imageWidth = CGFloat(image.width)
    let imageHeight = CGFloat(image.height)
    let scale = min(availableWidth / imageWidth, availableHeight / imageHeight)
    let drawWidth = imageWidth * scale
    let drawHeight = imageHeight * scale
    let drawRect = CGRect(
        x: (CGFloat(canvasSize) - drawWidth) / 2,
        y: CGFloat(inset),
        width: drawWidth,
        height: drawHeight
    )

    context.draw(image, in: drawRect)

    guard let finalImage = context.makeImage() else {
        fatalError("Could not render final image.")
    }

    return finalImage
}

func foregroundObjectMaskImage(width: Int, height: Int) -> CIImage {
    var bytes = [UInt8](repeating: 0, count: width * height)

    for row in 0..<height {
        for column in 0..<width {
            let x = Double(column)
            let y = Double(row)
            let alpha = foregroundObjectAlpha(x: x, y: y)
            bytes[row * width + column] = UInt8(max(0, min(255, Int(alpha * 255))))
        }
    }

    return CIImage(
        bitmapData: Data(bytes),
        bytesPerRow: width,
        size: CGSize(width: width, height: height),
        format: .L8,
        colorSpace: CGColorSpaceCreateDeviceGray()
    )
}

func foregroundObjectAlpha(x: Double, y: Double) -> Double {
    var alpha = 0.0

    // Red tablecloth / desk surface.
    alpha = max(alpha, smoothRectAlpha(x: x, y: y, rect: CGRect(x: 0, y: 442, width: 646, height: 205), feather: 2))

    // Laptop in front of the person.
    alpha = max(alpha, smoothRectAlpha(x: x, y: y, rect: CGRect(x: 0, y: 400, width: 304, height: 105), feather: 3))

    // Microphone head and its diagonal stem.
    alpha = max(alpha, ellipseAlpha(x: x, y: y, center: CGPoint(x: 350, y: 276), radiusX: 15, radiusY: 31, feather: 3))
    alpha = max(alpha, lineAlpha(x: x, y: y, start: CGPoint(x: 353, y: 300), end: CGPoint(x: 386, y: 584), width: 12, feather: 3))
    alpha = max(alpha, ellipseAlpha(x: x, y: y, center: CGPoint(x: 367, y: 612), radiusX: 41, radiusY: 28, feather: 4))

    // Small visible hardware at the microphone base.
    alpha = max(alpha, smoothRectAlpha(x: x, y: y, rect: CGRect(x: 337, y: 574, width: 75, height: 73), feather: 4))

    return alpha
}

func smoothRectAlpha(x: Double, y: Double, rect: CGRect, feather: Double) -> Double {
    let left = Double(rect.minX)
    let right = Double(rect.maxX)
    let top = Double(rect.minY)
    let bottom = Double(rect.maxY)

    guard x >= left - feather, x <= right + feather, y >= top - feather, y <= bottom + feather else {
        return 0
    }

    let distanceInside = min(x - left, right - x, y - top, bottom - y)
    if distanceInside >= feather {
        return 1
    }

    return max(0, min(1, (distanceInside + feather) / feather))
}

func ellipseAlpha(x: Double, y: Double, center: CGPoint, radiusX: Double, radiusY: Double, feather: Double) -> Double {
    let normalized = sqrt(
        pow((x - Double(center.x)) / radiusX, 2) +
        pow((y - Double(center.y)) / radiusY, 2)
    )

    if normalized <= 1 {
        return 1
    }

    let featherScale = 1 + feather / max(radiusX, radiusY)
    if normalized >= featherScale {
        return 0
    }

    return 1 - ((normalized - 1) / (featherScale - 1))
}

func lineAlpha(x: Double, y: Double, start: CGPoint, end: CGPoint, width: Double, feather: Double) -> Double {
    let ax = Double(start.x)
    let ay = Double(start.y)
    let bx = Double(end.x)
    let by = Double(end.y)
    let dx = bx - ax
    let dy = by - ay
    let lengthSquared = dx * dx + dy * dy

    guard lengthSquared > 0 else {
        return 0
    }

    let t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / lengthSquared))
    let closestX = ax + t * dx
    let closestY = ay + t * dy
    let distance = hypot(x - closestX, y - closestY)
    let radius = width / 2

    if distance <= radius {
        return 1
    }

    if distance >= radius + feather {
        return 0
    }

    return 1 - ((distance - radius) / feather)
}
