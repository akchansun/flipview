import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Image types this viewer will open and treat as siblings in a folder.
enum SupportedFormats {
    /// Common still-image extensions macOS ImageIO can usually decode.
    static let fileExtensions: Set<String> = [
        // JPEG family
        "jpg", "jpeg", "jpe", "jfif",
        // PNG / GIF / WebP
        "png", "gif", "webp",
        // Apple / HEIF
        "heic", "heif", "heics",
        // TIFF / BMP
        "tif", "tiff", "bmp", "dib",
        // Icons
        "ico", "icns", "cur",
        // JPEG 2000
        "jp2", "j2k", "jpf", "jpx", "j2c",
        // Others commonly handled by ImageIO on macOS
        "tga", "targa",
        "exr", "hdr",
        "avif",
        "astc",
        "ktx",
        "pbm", "pgm", "ppm", "pnm",
        "sgi", "rgb", "rgba", "bw",
        "pct", "pict",
        "psd" // flat composite preview via ImageIO when available
    ]

    static var contentTypes: [UTType] {
        var types: [UTType] = [
            .jpeg, .png, .gif, .webP, .tiff, .heic, .image
        ]
        let extras = [
            "public.heif",
            "public.jpeg-2000",
            "com.microsoft.bmp",
            "com.microsoft.ico",
            "com.apple.icns",
            "org.webmproject.webp",
            "public.avif",
            "com.truevision.tga-image",
            "com.adobe.photoshop-image",
            "com.ilm.openexr-image",
            "public.pbm",
            "public.pgm",
            "public.ppm"
        ]
        for id in extras {
            if let t = UTType(id) { types.append(t) }
        }
        return types
    }

    static func hasKnownImageExtension(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return !ext.isEmpty && fileExtensions.contains(ext)
    }

    static func isSupported(url: URL) -> Bool {
        // Directory listing must stay extension-only — never touch file bytes here.
        if hasKnownImageExtension(url) { return true }
        return ImageLoader.canDecode(url)
    }
}

/// Loads still frames via ImageIO so HEIC / WebP / TIFF / GIF (first frame) work the same way.
enum ImageLoader {
        static func canDecode(_ url: URL) -> Bool {
        // Header-only probe. Never read the whole file (ExFAT directories would crawl).
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else { return false }
        return CGImageSourceGetCount(source) > 0
    }

    /// Longest side used for on-screen viewing (Retina-aware, with headroom for moderate zoom).
    static func displayMaxPixelSize() -> Int {
        let screen = NSScreen.main
        let scale = screen?.backingScaleFactor ?? 2
        let size = screen?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let longest = max(size.width, size.height) * scale
        return Int(max((longest * 1.25).rounded(), 2048))
    }

    /// Decode a display-sized frame via ImageIO thumbnail API (does not require slurping the whole file first).
    static func load(from url: URL, maxPixelSize: Int? = nil) -> NSImage? {
        let pixelCap = maxPixelSize ?? displayMaxPixelSize()
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return NSImage(contentsOf: url)
        }

        let decodeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelCap
        ]

        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary) {
            return image(from: cgImage)
        }
        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions as CFDictionary) {
            return image(from: cgImage)
        }
        return NSImage(contentsOf: url)
    }

/// Point size for 100% = one image pixel per screen pixel on the main display.
    static func pointSize(of image: NSImage) -> NSSize {
        let pixels = pixelSize(of: image)
        let scale = max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
        return NSSize(width: pixels.width / scale, height: pixels.height / scale)
    }

    static func pixelSize(of image: NSImage) -> NSSize {
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }

    private static func image(from cgImage: CGImage) -> NSImage {
        let scale = max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
        let size = NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return NSImage(cgImage: cgImage, size: size)
    }
}
