import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Geometric / color ops. Replay on a full-resolution decode when saving
/// so the on-screen display-sized bitmap is never written back to disk.
enum ImageOp: Equatable {
    case rotateLeft
    case rotateRight
    case flipHorizontal
    case flipVertical
    /// Normalized crop in image space, origin bottom-left, 0…1.
    case crop(CGRect)
    case color(ColorAdjust)
    case resize(width: Int, height: Int)

    var swapsDimensions: Bool {
        switch self {
        case .rotateLeft, .rotateRight, .crop, .resize: return true
        case .flipHorizontal, .flipVertical, .color: return false
        }
    }
}

/// Preview-style Adjust Color. Identity values leave the image unchanged.
struct ColorAdjust: Equatable {
    var exposure: Double = 0
    var contrast: Double = 1
    var brightness: Double = 0
    var saturation: Double = 1
    var highlights: Double = 1
    var shadows: Double = 0
    var temperature: Double = 0
    var tint: Double = 0
    var sepia: Double = 0
    var sharpness: Double = 0
    var autoLevels: Bool = false

    var isIdentity: Bool { self == ColorAdjust() }
}

enum ImageEditError: Error {
    case noCGImage
    case loadFailed
    case writeFailed
}

enum ImageEditing {
    static let jpegQuality: CGFloat = 0.92
    /// Long enough for a letter-size page at ~300 dpi without decoding 50MP RAW-ish stills.
    static let printMaxPixelSize = 4096

    static let exportTypes: [UTType] = {
        var types: [UTType] = [.jpeg, .png, .tiff]
        if let heic = UTType("public.heic") {
            types.append(heic)
        }
        return types
    }()

    static func apply(_ ops: [ImageOp], to image: NSImage) -> NSImage {
        guard !ops.isEmpty, var cg = ImageLoader.cgImage(from: image) else { return image }
        for op in ops {
            guard let next = apply(op, to: cg) else { break }
            cg = next
        }
        return ImageLoader.image(from: cg)
    }

    static func apply(_ op: ImageOp, to image: CGImage) -> CGImage? {
        switch op {
        case .color(let adjust):
            return applyColor(adjust, to: image)
        case .crop(let frac):
            return applyCrop(frac, to: image)
        case .resize(let width, let height):
            return applyResize(to: image, width: width, height: height)
        case .rotateLeft, .rotateRight, .flipHorizontal, .flipVertical:
            break
        }

        let width = image.width
        let height = image.height
        let canvas: (width: Int, height: Int)
        switch op {
        case .rotateLeft, .rotateRight:
            canvas = (height, width)
        default:
            canvas = (width, height)
        }

        guard let ctx = makeContext(width: canvas.width, height: canvas.height, matching: image) else {
            return nil
        }

        switch op {
        case .rotateRight:
            // Clockwise on screen (AppKit y-up): top of the photo moves to the right.
            ctx.translateBy(x: 0, y: CGFloat(width))
            ctx.rotate(by: -.pi / 2)
        case .rotateLeft:
            ctx.translateBy(x: CGFloat(height), y: 0)
            ctx.rotate(by: .pi / 2)
        case .flipHorizontal:
            ctx.translateBy(x: CGFloat(width), y: 0)
            ctx.scaleBy(x: -1, y: 1)
        case .flipVertical:
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
        case .crop, .color, .resize:
            break
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    /// ImageIO thumbnail with transform so EXIF orientation is already baked into pixels.
    static func loadOriented(from url: URL, maxPixelSize: Int) -> NSImage? {
        ImageLoader.load(from: url, maxPixelSize: maxPixelSize)
    }

    static func loadOrientedFullResolution(from url: URL) -> NSImage? {
        ImageLoader.load(from: url, maxPixelSize: 1_000_000)
    }

    static func writableType(for url: URL) -> UTType? {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "jpe", "jfif":
            return .jpeg
        case "png":
            return .png
        case "tif", "tiff":
            return .tiff
        case "heic", "heif":
            return UTType("public.heic") ?? UTType("public.heif")
        case "bmp", "dib":
            return UTType("com.microsoft.bmp") ?? .png
        default:
            return nil
        }
    }

    static func normalizedWriteType(_ type: UTType) -> UTType {
        if type.conforms(to: .jpeg) { return .jpeg }
        if type.conforms(to: .png) { return .png }
        if type.conforms(to: .tiff) { return .tiff }
        if type.identifier == "public.heic" || type.identifier == "public.heif" {
            return UTType("public.heic") ?? .jpeg
        }
        if type.identifier == "com.microsoft.bmp" { return type }
        return .jpeg
    }

    /// Reload the original file at full resolution, replay `ops` and markup, write atomically.
    static func saveFullResolution(
        from source: URL,
        ops: [ImageOp],
        markup: [MarkupItem] = [],
        to destination: URL,
        type: UTType
    ) throws {
        guard let loaded = loadOrientedFullResolution(from: source),
              var cg = ImageLoader.cgImage(from: loaded) else {
            throw ImageEditError.loadFailed
        }
        for op in ops {
            guard let next = apply(op, to: cg) else { throw ImageEditError.noCGImage }
            cg = next
        }
        if !markup.isEmpty, let baked = ImageMarkup.bake(markup, onto: cg) {
            cg = baked
        }
        try write(cg, to: destination, type: type)
    }

    static func write(_ image: CGImage, to url: URL, type: UTType) throws {
        let directory = url.deletingLastPathComponent()
        let tmp = directory.appendingPathComponent(".\(url.lastPathComponent).flip-tmp-\(UUID().uuidString)")
        let uti = type.identifier as CFString
        guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, uti, 1, nil) else {
            throw ImageEditError.writeFailed
        }

        var props: [CFString: Any] = [:]
        if type.conforms(to: .jpeg) || type.identifier == "public.heic" || type.identifier == "public.heif" {
            props[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tmp)
            throw ImageEditError.writeFailed
        }

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: url.path) {
                _ = try fm.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: url)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw error
        }
    }

    @MainActor
    static func printImage(_ image: NSImage, jobTitle: String) {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = true
        info.leftMargin = 36
        info.rightMargin = 36
        info.topMargin = 36
        info.bottomMargin = 36

        let px = ImageLoader.pixelSize(of: image)
        info.orientation = px.width >= px.height ? .landscape : .portrait

        let page = info.imageablePageBounds.size
        let view = ImagePrintView(image: image, fitIn: page)
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.jobTitle = jobTitle
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func applyCrop(_ frac: CGRect, to image: CGImage) -> CGImage? {
        let normalized = frac.standardized
        guard normalized.width > 0.002, normalized.height > 0.002 else { return image }
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        let pixel = CGRect(
            x: normalized.minX * w,
            y: (1 - normalized.maxY) * h,
            width: normalized.width * w,
            height: normalized.height * h
        ).integral
        guard pixel.width >= 1, pixel.height >= 1 else { return image }
        return image.cropping(to: pixel) ?? image
    }

    private static func applyResize(to image: CGImage, width: Int, height: Int) -> CGImage? {
        let w = max(1, width)
        let h = max(1, height)
        guard let ctx = makeContext(width: w, height: h, matching: image) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    private static func applyColor(_ adjust: ColorAdjust, to image: CGImage) -> CGImage? {
        guard !adjust.isIdentity else { return image }
        var current = CIImage(cgImage: image)
        if adjust.autoLevels {
            for filter in current.autoAdjustmentFilters(options: [.enhance: true]) {
                filter.setValue(current, forKey: kCIInputImageKey)
                if let out = filter.outputImage { current = out }
            }
        }
        if abs(adjust.exposure) > 0.0001, let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(current, forKey: kCIInputImageKey)
            filter.setValue(adjust.exposure, forKey: kCIInputEVKey)
            if let out = filter.outputImage { current = out }
        }
        if abs(adjust.contrast - 1) > 0.0001 || abs(adjust.saturation - 1) > 0.0001 || abs(adjust.brightness) > 0.0001,
           let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(current, forKey: kCIInputImageKey)
            filter.setValue(adjust.contrast, forKey: kCIInputContrastKey)
            filter.setValue(adjust.saturation, forKey: kCIInputSaturationKey)
            filter.setValue(adjust.brightness, forKey: kCIInputBrightnessKey)
            if let out = filter.outputImage { current = out }
        }
        if abs(adjust.highlights - 1) > 0.0001 || abs(adjust.shadows) > 0.0001,
           let filter = CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(current, forKey: kCIInputImageKey)
            filter.setValue(adjust.highlights, forKey: "inputHighlightAmount")
            filter.setValue(adjust.shadows, forKey: "inputShadowAmount")
            if let out = filter.outputImage { current = out }
        }
        if abs(adjust.temperature) > 0.0001 || abs(adjust.tint) > 0.0001,
           let filter = CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(current, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(
                CIVector(x: 6500 - adjust.temperature * 1800, y: adjust.tint * 80),
                forKey: "inputTargetNeutral"
            )
            if let out = filter.outputImage { current = out }
        }
        if adjust.sepia > 0.0001, let filter = CIFilter(name: "CISepiaTone") {
            filter.setValue(current, forKey: kCIInputImageKey)
            filter.setValue(adjust.sepia, forKey: kCIInputIntensityKey)
            if let out = filter.outputImage { current = out }
        }
        if adjust.sharpness > 0.0001, let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(current, forKey: kCIInputImageKey)
            filter.setValue(adjust.sharpness, forKey: kCIInputSharpnessKey)
            if let out = filter.outputImage { current = out }
        }
        let extent = current.extent.integral
        return ciContext.createCGImage(current, from: extent) ?? image
    }

    private static func makeContext(width: Int, height: Int, matching image: CGImage) -> CGContext? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let spaces: [CGColorSpace] = [image.colorSpace, CGColorSpaceCreateDeviceRGB()].compactMap { $0 }
        for space in spaces {
            if let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: bitmapInfo
            ) {
                ctx.interpolationQuality = .none
                return ctx
            }
        }
        return nil
    }
}

/// One page: the image scaled to fit the printable area.
final class ImagePrintView: NSView {
    private let image: NSImage

    init(image: NSImage, fitIn page: NSSize) {
        self.image = image
        let source = ImageLoader.pointSize(of: image)
        let fitted = Self.aspectFit(source, in: page)
        super.init(frame: NSRect(origin: .zero, size: fitted))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()
        image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private static func aspectFit(_ size: NSSize, in bounds: NSSize) -> NSSize {
        guard size.width > 0, size.height > 0, bounds.width > 1, bounds.height > 1 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return NSSize(width: size.width * scale, height: size.height * scale)
    }
}
