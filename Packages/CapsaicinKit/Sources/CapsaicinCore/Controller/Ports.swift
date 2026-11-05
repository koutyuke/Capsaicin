import Foundation

// コントローラーが OS に作用するためのポート。すべてメインスレッドから同期で呼ぶ。
// 失敗する操作は throw で伝える。コントローラーは失敗を合わせられていない制御か開始の拒否にする。

/// 電源管理アサーション。
@MainActor
public protocol PowerAssertionControlling {
    /// 種類ごとに1つ作る。作成と解放はどちらも冪等で、作ってある種類の作成は何もせずに成功とする。
    /// 失敗した操作の後は状態が分からないものとして、コントローラーが同じ操作をもう一度呼ぶことがある。
    func createAssertion(_ kind: AssertionKind) throws
    /// 作った種類を解放する。冪等で、作っていない種類の解放は何もせずに成功とする。
    func releaseAssertion(_ kind: AssertionKind) throws
}

/// 蓋閉じスリープの制御（kPMSetClamshellSleepState）。プロセスが終わっても戻らないものとして扱う。
@MainActor
public protocol LidSleepControlling {
    /// true で蓋閉じスリープを無効化し、false で無効化を解く。
    func setLidSleepDisabled(_ disabled: Bool) throws
}

/// ヘルパーによるシステムのスリープの制御。
@MainActor
public protocol HelperSleepControlling {
    /// ヘルパーの3つの構成要素がそろっているか。
    var isHelperInstalled: Bool { get }
    /// `SleepDisabled` を読む。読めなければ throw する。
    /// 実装は期限を持ち、期限切れは throw する（メインスレッドから同期で呼ぶため）。
    func readSleepDisabled() throws -> Bool
    /// ヘルパーの `on`。実装は期限を持ち、期限切れは throw する。
    func turnOn() throws
    /// ヘルパーの `off`。実装は期限を持ち、期限切れは throw する。
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

/// Mac の起動時刻（kern.boottime）。
@MainActor
public protocol BootTimeProviding {
    /// 読めないときは取得不能を示す `Date.distantPast` を返す。過去の起動時刻としては扱わない。
    /// 取得不能なら通常の起動とし、自動再開せず、前回のセッションと disablesleep の所有を捨てる。
    var bootTime: Date { get }
}

/// 再開用の記録の読み書き。
@MainActor
public protocol ResumeRecordStoring {
    /// 記録がなければ nil。読めない（壊れている、形式が違う）ときも nil を返し、実装の側でログに残す。
    func load() -> ResumeRecord?
    /// ファイルを置き換えて書き、書きかけの状態を残さない。保存できたら true。
    func save(_ record: ResumeRecord) -> Bool
}

/// 現在時刻と、利用者の暦とタイムゾーン。
@MainActor
public protocol TimeProviding {
    var now: Date { get }
    var calendar: Calendar { get }
}
