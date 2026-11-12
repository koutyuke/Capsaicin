/// ディスプレイを閉じたときの画面の扱い。
public enum LidCloseDisplay: String, Codable, Hashable, Sendable, CaseIterable {
    case keepOn
    case turnOff
    case zeroBrightness
}
