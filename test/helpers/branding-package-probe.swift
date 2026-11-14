import AppKit
import ImageIO

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: "BrandingPackageProbe", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: message]) }
}

func verifyBranding() throws {
let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let bundle = try { () throws -> Bundle in
    guard let bundle = Bundle(url: appURL) else {
        throw NSError(domain: "BrandingPackageProbe", code: 1)
    }
    return bundle
}()
try require(bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String == "AppIcon.icns", "App icon declaration missing")
let resources = appURL.appendingPathComponent("Contents/Resources")
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
