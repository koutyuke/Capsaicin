// DMG のウインドウの背景を、1倍と2倍の PNG に描く（DEC-SYS-028）。
// 使い方: xcrun swift background.swift <出力ディレクトリ> <アプリのアイコンの PNG>
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// 見せる範囲は 660×400 で、settings.py の window_rect と合わせる。下は白だけを描き足す。
/// 隠しファイルを表示する設定の人が、ウインドウの外に置いた .background.tiff までスクロールしても、
/// 背景が途切れないようにするため
let size = CGSize(width: 660, height: 680)
// アイコンの行の高さ（settings.py の icon_locations の y と同じ値にする）
let iconRowY: CGFloat = 164
let hudTop: CGFloat = 304
let logoOrigin = CGPoint(x: 24, y: 22)
let logoIconSize: CGFloat = 28

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat(hex >> 16 & 0xFF) / 255,
        green: CGFloat(hex >> 8 & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha,
    )
}

let ink = color(0x1D1D1F)

let arguments = CommandLine.arguments
guard arguments.count == 3, let icon = NSImage(contentsOfFile: arguments[2]) else {
    fatalError("Usage: background.swift <output-dir> <icon-png>")
}

func draw(in cg: CGContext) {
    NSColor.white.setFill()
    CGRect(origin: .zero, size: size).fill()

    // アイコンの間の3つの山。先へ向かって大きく濃くなる（先端の x、高さ、幅、不透明度）
    for (tip, height, width, alpha) in [(318.0, 18.0, 8.0, 0.35), (335, 24, 10, 0.65), (354, 30, 13, 1)] {
        let chevron = NSBezierPath()
        chevron.move(to: CGPoint(x: tip - width, y: iconRowY - height / 2))
        chevron.line(to: CGPoint(x: tip, y: iconRowY))
        chevron.line(to: CGPoint(x: tip - width, y: iconRowY + height / 2))
        chevron.lineWidth = 4
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        color(0x8E8C89, alpha).setStroke()
        chevron.stroke()
    }

    // 左上のロゴ: アプリのアイコンと名前。Finder のアイコンと違い、外観の設定によらず赤で描く
    icon.draw(
        in: CGRect(origin: logoOrigin, size: CGSize(width: logoIconSize, height: logoIconSize)),
        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil,
    )
    let logo = NSAttributedString(
        string: "Capsaicin",
        attributes: [.font: NSFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: ink],
    )
    logo.draw(at: CGPoint(
        x: logoOrigin.x + logoIconSize + 8,
        y: logoOrigin.y + (logoIconSize - logo.size().height) / 2,
    ))

    drawHUD(in: cg)
}

/// アプリの HUD（高さ 48 のカプセル、LED の記号、semibold の名前）を白い塗りで描く
func drawHUD(in cg: CGContext) {
    let strong: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
        .foregroundColor: ink,
    ]
    let separator: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 17),
        .foregroundColor: color(0x9F9B97),
    ]
    let weak: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: color(0x5F5C58)]
    let parts = [
        NSAttributedString(string: "Capsaicin", attributes: strong),
        NSAttributedString(string: "→", attributes: separator),
        NSAttributedString(string: "Applications", attributes: weak),
    ]
    let symbolSize: CGFloat = 20, gap: CGFloat = 10, separatorPadding: CGFloat = 2
    let width = 18 + symbolSize + parts.reduce(0) { $0 + gap + $1.size().width } + 2 * separatorPadding + 20
    let capsule = CGRect(x: (size.width - width) / 2, y: hudTop, width: width, height: 48)

    cg.saveGState()
    // 影のずれは変換の前の座標（上が正）で効くので、下へ落とすには負にする
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.10).cgColor)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: capsule, xRadius: 24, yRadius: 24).fill()
    cg.restoreGState()
    let border = NSBezierPath(roundedRect: capsule.insetBy(dx: 0.25, dy: 0.25), xRadius: 23.75, yRadius: 23.75)
    border.lineWidth = 0.5
    NSColor.black.withAlphaComponent(0.08).setStroke()
    border.stroke()

    // 記号: custom.capsaicin.led（角丸のキーと、左上の LED）
    var x = capsule.minX + 18
    let key = CGRect(x: x + 1.5, y: capsule.midY - symbolSize / 2 + 1.5, width: 17, height: 17)
    let keyPath = NSBezierPath(roundedRect: key, xRadius: 5, yRadius: 5)
    keyPath.lineWidth = 1.6
    ink.setStroke()
    keyPath.stroke()
    let led = NSBezierPath(ovalIn: CGRect(x: key.minX + 5.5 - 2.6, y: key.minY + 5.5 - 2.6, width: 5.2, height: 5.2))
    led.lineWidth = 1.4
    led.stroke()
    x += symbolSize

    for (index, part) in parts.enumerated() {
        let padding = index == 1 ? separatorPadding : 0
        x += gap + padding
        let partSize = part.size()
        part.draw(at: CGPoint(x: x, y: capsule.midY - partSize.height / 2))
        x += partSize.width + padding
    }
}

func render(scale: Int, to url: URL) throws {
    let pixels = CGSize(width: size.width * CGFloat(scale), height: size.height * CGFloat(scale))
    guard let cg = CGContext(
        data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ) else { throw CocoaError(.fileWriteUnknown) }
    // 左上を原点にし、ポイントで描く
    cg.translateBy(x: 0, y: pixels.height)
    cg.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    draw(in: cg)
    NSGraphicsContext.current = nil

    guard let image = cg.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    // dmgbuild が @2x と組み合わせて1つの TIFF にするので、DPI で倍率を示す
    let dpi = 72 * scale
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary,
    )
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let output = URL(fileURLWithPath: arguments[1])
try render(scale: 1, to: output.appendingPathComponent("background.png"))
try render(scale: 2, to: output.appendingPathComponent("background@2x.png"))
