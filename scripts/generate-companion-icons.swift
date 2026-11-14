import AppKit
import ImageIO
import UniformTypeIdentifiers

func failure(_ message: String) -> NSError {
    NSError(domain: "CompanionIcons", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

func readImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw failure("Cannot decode \(url.lastPathComponent)")
    }
    return image
}

func context(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw failure("Cannot create image context")
    }
    context.interpolationQuality = .high
    return context
}

func render(_ image: CGImage, width: Int, height: Int, inset: CGFloat = 0) throws -> CGImage {
    let canvas = try context(width: width, height: height)
    let scale = min((CGFloat(width) - inset * 2) / CGFloat(image.width),
                    (CGFloat(height) - inset * 2) / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    canvas.draw(image, in: CGRect(x: (CGFloat(width) - size.width) / 2,
        y: (CGFloat(height) - size.height) / 2, width: size.width, height: size.height))
    guard let output = canvas.makeImage() else { throw failure("Cannot render image") }
    return output
}

func trimmed(_ image: CGImage) throws -> CGImage {
    let canvas = try context(width: image.width, height: image.height)
    canvas.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let data = canvas.data else { throw failure("Cannot read alpha bounds") }
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    var minX = image.width, minY = image.height, maxX = -1, maxY = -1
    for y in 0..<image.height {
        // Generated sources can contain alpha-1 noise far outside the visible mark.
        for x in 0..<image.width where bytes[y * canvas.bytesPerRow + x * 4 + 3] >= 16 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { throw failure("Menu-bar source contains no visible artwork") }
    minX = max(0, minX - 1); minY = max(0, minY - 1)
    maxX = min(image.width - 1, maxX + 1); maxY = min(image.height - 1, maxY + 1)
    guard let normalized = canvas.makeImage(),
          let crop = normalized.cropping(to: CGRect(x: minX, y: minY,
              width: maxX - minX + 1, height: maxY - minY + 1)) else {
        throw failure("Menu-bar source contains no visible artwork")
    }
    return crop
}

private func appIconArtwork(_ image: CGImage) throws -> CGImage {
    let canvas = try context(width: image.width, height: image.height)
    canvas.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let data = canvas.data else { throw failure("Cannot read app-icon pixels") }
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    var minX = image.width, minY = image.height, maxX = -1, maxY = -1
    var opaqueRows = [Int]()
    for y in 0..<image.height {
        var first = image.width, last = -1
        for x in 0..<image.width {
            let alpha = bytes[y * canvas.bytesPerRow + x * 4 + 3]
            if alpha >= 16 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
            if alpha >= 240 { first = min(first, x); last = max(last, x) }
        }
        guard last >= first else { continue }
        opaqueRows.append(y)
        // Extend the existing navy edge underneath the system's mask. Never scale
        // or separate the cyan folder from its background.
        for x in 0..<image.width {
            let edge = x < first ? first : (x > last ? last : x)
            let source = y * canvas.bytesPerRow + edge * 4
            let target = y * canvas.bytesPerRow + x * 4
            let alpha = Int(bytes[source + 3])
            guard alpha > 0 else { throw failure("Unexpected transparent hole inside navy artwork") }
            // The supplied navy pixels have alpha near 253, so undo premultiplication
            // before making the native background fully opaque.
            for channel in 0..<3 {
                bytes[target + channel] = UInt8(min(255, (Int(bytes[source + channel]) * 255 + alpha / 2) / alpha))
            }
            bytes[target + 3] = 255
        }
    }
    guard let firstRow = opaqueRows.first, let lastRow = opaqueRows.last else {
        throw failure("App-icon source contains no opaque artwork")
    }
    for y in 0..<image.height where y < firstRow || y > lastRow {
        let source = (y < firstRow ? firstRow : lastRow) * canvas.bytesPerRow
        data.advanced(by: y * canvas.bytesPerRow).copyMemory(from: data.advanced(by: source), byteCount: canvas.bytesPerRow)
    }
    let side = max(maxX - minX + 1, maxY - minY + 1)
    let crop = CGRect(x: (minX + maxX + 1 - side) / 2, y: (minY + maxY + 1 - side) / 2,
                      width: side, height: side)
    guard let square = canvas.makeImage()?.cropping(to: crop),
          let output = try render(square, width: 1024, height: 1024)
            .copy(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
        throw failure("Cannot normalize native app-icon artwork")
    }
    return output
}

func generate(root: URL) throws {
    let files = FileManager.default
    let originals = root.appendingPathComponent("assets/branding")
    let resources = root.appendingPathComponent("companion/Resources")
    let navyURL = originals.appendingPathComponent("codex-project-router.png")
    let navy = try readImage(navyURL)
    let menu = try trimmed(readImage(originals.appendingPathComponent("menu-bar-source.png")))
    let scratch = files.temporaryDirectory.appendingPathComponent("companion-icons-\(UUID())")
    let iconset = scratch.appendingPathComponent("AppIcon.iconset")
    try files.createDirectory(at: iconset, withIntermediateDirectories: true)
    defer {
        do { try files.removeItem(at: scratch) }
        catch { fputs("Cannot remove icon-generation scratch directory: \(error.localizedDescription)\n", stderr) }
    }
    try files.createDirectory(at: resources, withIntermediateDirectories: true)
    let document = originals.appendingPathComponent("AppIcon.icon")
    let artwork = document.appendingPathComponent("Assets/Artwork.png")
    try files.createDirectory(at: artwork.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let png = CGImageDestinationCreateWithURL(artwork as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw failure("Cannot create native app-icon artwork")
    }
    CGImageDestinationAddImage(png, try appIconArtwork(navy), nil)
    guard CGImageDestinationFinalize(png) else { throw failure("Cannot write native app-icon artwork") }
    let compiled = scratch.appendingPathComponent("catalog")
    let declarations = scratch.appendingPathComponent("icon-info.plist")
    try files.createDirectory(at: compiled, withIntermediateDirectories: true)
    let compiler = Process()
    compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    compiler.arguments = ["actool", document.path, "--compile", compiled.path,
        "--platform", "macosx", "--minimum-deployment-target", "14.0", "--target-device", "mac",
        "--app-icon", "AppIcon", "--output-partial-info-plist", declarations.path, "--warnings", "--errors"]
    let output = Pipe()
    compiler.standardOutput = output; compiler.standardError = output
    try compiler.run()
    let diagnostics = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    compiler.waitUntilExit()
    guard compiler.terminationStatus == 0 else {
        throw failure("actool failed (\(compiler.terminationStatus)); select a full Xcode installation.\n\(diagnostics)")
    }
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: declarations), format: nil) as? [String: Any]
    guard info?["CFBundleIconName"] as? String == "AppIcon" else {
        throw failure("actool did not declare the AppIcon catalog entry.\n\(diagnostics)")
    }
    let catalog = try Data(contentsOf: compiled.appendingPathComponent("Assets.car"))
    guard !catalog.isEmpty else { throw failure("actool produced an empty Assets.car") }
    try catalog.write(to: resources.appendingPathComponent("Assets.car"), options: .atomic)
    if !diagnostics.isEmpty { print(diagnostics, terminator: "") }
    for points in [16, 32, 128, 256, 512] {
        for factor in [1, 2] {
            let pixels = points * factor
            let name = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
            guard let output = CGImageDestinationCreateWithURL(iconset.appendingPathComponent(name) as CFURL,
                UTType.png.identifier as CFString, 1, nil) else { throw failure("Cannot create icon representation") }
            CGImageDestinationAddImage(output, try render(navy, width: pixels, height: pixels), nil)
            guard CGImageDestinationFinalize(output) else { throw failure("Cannot write icon representation") }
        }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["--convert", "icns", "--output", resources.appendingPathComponent("AppIcon.icns").path, iconset.path]
    try process.run(); process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw failure("iconutil failed") }
    try Data(contentsOf: navyURL).write(to: resources.appendingPathComponent("CompanionIcon.png"), options: .atomic)
    guard let tiff = CGImageDestinationCreateWithURL(resources.appendingPathComponent("MenuBarIconTemplate.tiff") as CFURL,
        UTType.tiff.identifier as CFString, 2, nil) else { throw failure("Cannot create menu-bar TIFF") }
    for factor in [1, 2] {
        let image = try render(menu, width: 26 * factor, height: 18 * factor, inset: CGFloat(factor))
        CGImageDestinationAddImage(tiff, image, [kCGImagePropertyDPIWidth: 72 * factor,
            kCGImagePropertyDPIHeight: 72 * factor] as CFDictionary)
    }
    guard CGImageDestinationFinalize(tiff) else { throw failure("Cannot write menu-bar TIFF") }
    print("Generated Assets.car, AppIcon.icns, CompanionIcon.png and MenuBarIconTemplate.tiff")
}

do {
    try generate(root: URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath))
} catch {
    fputs("Icon generation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
