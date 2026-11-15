import AppKit
import ImageIO

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: "BrandingPackageProbe", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: message]) }
}

func verifyBranding() throws {
    if CommandLine.arguments[1] == "--artwork" {
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "BrandingPackageProbe", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot decode native artwork"])
        }
        try require(image.width == 1024 && image.height == 1024, "Incorrect native artwork canvas")
        let bitmap = NSBitmapImageRep(cgImage: image)
        var minX = 1024, minY = 1024, maxX = -1, maxY = -1
        for y in 0..<1024 {
            for x in 0..<1024 {
                let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                try require(color.alphaComponent == 1, "Transparent native icon background")
                if color.greenComponent > 100.0 / 255 && color.blueComponent > 100.0 / 255 &&
                    color.greenComponent > color.redComponent * 1.5 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        // Measured source: 828×667 cyan bounds on a 1204px-wide navy tile.
        try require(abs(maxX - minX + 1 - 704) <= 2 && abs(maxY - minY + 1 - 567) <= 2,
                    "Folder proportions changed in native artwork")
        try require(abs(Double(minX + maxX) / 2 - 514) <= 2 &&
                    abs(Double(minY + maxY) / 2 - 487) <= 2, "Folder position changed in native artwork")
        print("branding-artwork-pass")
        return
    }
    let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
    guard let bundle = Bundle(url: appURL) else {
        throw NSError(domain: "BrandingPackageProbe", code: 1)
    }
    try require(bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String == "AppIcon", "Native icon catalog declaration missing")
    try require(bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String == "AppIcon.icns", "App icon declaration missing")
    let resources = appURL.appendingPathComponent("Contents/Resources")
    let catalog = resources.appendingPathComponent("Assets.car")
    try require((try? Data(contentsOf: catalog).isEmpty) == false, "Cannot read icon catalog Assets.car")
    if CommandLine.arguments.contains("--catalog-only") {
        try require(!FileManager.default.fileExists(atPath: resources.appendingPathComponent("AppIcon.icns").path),
                    "Catalog probe must exclude ICNS fallback")
        guard let icon = bundle.image(forResource: "AppIcon"), !icon.representations.isEmpty,
              icon.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            throw NSError(domain: "BrandingPackageProbe", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot resolve AppIcon from Assets.car"])
        }
        print("branding-catalog-pass")
        return
    }
    for name in ["AppIcon.icns", "CompanionIcon.png", "MenuBarIconTemplate.tiff"] {
        let url = resources.appendingPathComponent(name)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw NSError(domain: "BrandingPackageProbe", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot decode \(name)"])
        }
        try require(CGImageSourceGetCount(source) > 0, "Cannot decode \(name)")
        var dimensions = Set<String>()
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                throw NSError(domain: "BrandingPackageProbe", code: 1)
            }
            dimensions.insert("\(image.width)x\(image.height)")
            let bitmap = NSBitmapImageRep(cgImage: image)
            try require(bitmap.hasAlpha, "Missing alpha in \(name)")
            try require(bitmap.colorAt(x: 0, y: 0)!.alphaComponent == 0, "Opaque corner in \(name)")
            if name == "MenuBarIconTemplate.tiff" {
                var minY = image.height, maxY = -1
                for y in 0..<image.height {
                    for x in 0..<image.width where bitmap.colorAt(x: x, y: y)!.alphaComponent >= 0.5 {
                        minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
                let factor = image.height / 18
                try require(maxY - minY + 1 >= 14 * factor, "Invisible padding shrinks menu artwork")
            }
        }
        if name == "AppIcon.icns" {
            try require(Set(["16x16", "32x32", "64x64", "128x128", "256x256", "512x512", "1024x1024"]).isSubset(of: dimensions), "Missing app icon sizes")
        } else if name == "MenuBarIconTemplate.tiff" {
            try require(dimensions == ["26x18", "52x36"], "Missing menu-bar resolutions")
        }
    }
    guard let menu = bundle.image(forResource: "MenuBarIconTemplate"),
          let header = bundle.image(forResource: "CompanionIcon") else {
        throw NSError(domain: "BrandingPackageProbe", code: 1)
    }
    try require(menu.isTemplate, "Menu image must be a template")
    try require(menu.size == NSSize(width: 26, height: 18), "Incorrect menu image point size")
    try require(!header.isTemplate, "Header must preserve its colors")
    print("branding-package-pass")
}
do { try verifyBranding() } catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
