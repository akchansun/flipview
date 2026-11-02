import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Lossless 90° rotate / flip ops. Replay on a full-resolution decode when saving
/// so the on-screen display-sized bitmap is never written back to disk.
enum ImageOp: Equatable {
    case rotateLeft
    case rotateRight
    case flipHorizontal
    case flipVertical

    var swapsDimensions: Bool {
        switch self {
        case .rotateLeft, .rotateRight: return true
        case .flipHorizontal, .flipVertical: return false
        }
    }
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
        let width = image.width
        let height = image.height
        let canvas: (width: Int, height: Int)
        switch op {
        case .rotateLeft, .rotateRight:
            canvas = (height, width)
        case .flipHorizontal, .flipVertical:
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

    /// Reload the original file at full resolution, replay `ops`, write atomically.
    static func saveFullResolution(from source: URL, ops: [ImageOp], to destination: URL, type: UTType) throws {
        guard let loaded = loadOrientedFullResolution(from: source),
              var cg = ImageLoader.cgImage(from: loaded) else {
            throw ImageEditError.loadFailed
        }
        for op in ops {
            guard let next = apply(op, to: cg) else { throw ImageEditError.noCGImage }
            cg = next
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
