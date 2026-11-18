import Foundation

// コントローラーが OS に作用するためのポート。すべてメインスレッドから同期で呼ぶ。
// 失敗する操作は throw で伝える。コントローラーは失敗を合わせられていない制御か開始の拒否にする。
// 輝度の読み書きの失敗はログに残す。輝度の記録を保存・削除できない場合は警告も出す。

/// オンラインの内蔵ディスプレイの輝度。外部ディスプレイは操作しない。
@MainActor
public protocol BuiltInDisplayBrightnessControlling {
    /// 関数がないか、内蔵ディスプレイの輝度を変更できないと分かっているか。対象がなく判定不能なら false。
    var isKnownUnavailable: Bool { get }
    /// 対象がなければ nil。読み取り失敗は throw する。
    func readBrightness() throws -> Float?
    func setBrightness(_ value: Float) throws
}

@MainActor
public protocol PowerAssertionControlling {
    /// 種類ごとに1つ作る。作成と解放はどちらも冪等で、作ってある種類の作成は何もせずに成功とする。
    /// 失敗した操作の後は状態が分からないものとして、コントローラーが同じ操作をもう一度呼ぶことがある。
    func createAssertion(_ kind: AssertionKind) throws
    /// 作った種類を解放する。冪等で、作っていない種類の解放は何もせずに成功とする。
    func releaseAssertion(_ kind: AssertionKind) throws
}

/// どの操作も実装が期限を持ち、期限切れは throw する（メインスレッドから同期で呼ぶため）。
/// XPC の期限切れは接続を取り消す。読み取りの子プロセスは終わるまで見届け、その間の読み取りは throw する。
@MainActor
public protocol HelperSleepControlling {
    /// 署名に Team ID があり、ヘルパーが登録・許可されているか。
    var isHelperInstalled: Bool { get }
    func readSleepDisabled() throws -> Bool
    func turnOn() throws
    func turnOff() throws
}

/// Caps Lock の LED。入力状態は変えない。
@MainActor
public protocol CapsLockLEDControlling {
    /// LED の制御に使う関数が OS にあるか。false ならコントローラーは LED に触れない。
    var isAvailable: Bool { get }
    /// true で点灯（"On"）、false で Caps Lock の状態に連動する通常の動作（"Auto"）にする。
    func setLit(_ lit: Bool) throws
}

/// 電源の状態。変化したらアプリが `BlockingController.powerStateChanged()` を呼ぶ。
@MainActor
public protocol PowerStateProviding {
    var powerState: PowerState { get }
}

public struct BrightnessRecord: Codable, Equatable, Sendable {
    /// 前の版の記録には、輝度を含まないものもある。
    public let savedBrightness: Float?

    public init(savedBrightness: Float?) {
        self.savedBrightness = savedBrightness
    }
}

@MainActor
public protocol BrightnessRecordStoring {
    /// 記録がなければ nil。読めない（壊れている、形式が違う）ときも nil を返し、実装の側でログに残す。
    func load() -> BrightnessRecord?
    /// ファイルを置き換えて書き、書きかけの状態を残さない。失敗は実装の側でログに残す。
    func save(_ brightness: Float) -> Bool
    /// すでに記録がないときも成功とする。失敗は実装の側でログに残す。
    func remove() -> Bool
}

@MainActor
public protocol TimeProviding {
    var now: Date { get }
    var calendar: Calendar { get }
}
