import CapsaicinCore
import CapsaicinIPC
import Foundation
import Testing

private final class CLICatalogLocator: NSObject {}

struct CLICatalogTests {
    @Test("SPEC-CLI-003 SPEC-CLI-007 CLI カタログがアプリに収録され、全キーを日本語で読める")
    func localizedCatalog() throws {
        let products = Bundle(for: CLICatalogLocator.self).bundleURL.deletingLastPathComponent()
        let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
        #expect(app.url(forResource: "CLI", withExtension: "strings", subdirectory: "ja.lproj") != nil)
        for key in CLITextKey.allCases {
            let value = app.localizedString(forKey: key.rawValue, value: nil, table: "CLI")
            #expect(value != key.rawValue)
            #expect(!value.contains("\n"))
        }
        let text = CLIText(bundle: app)
        #expect(text(.alreadyBlocking).contains("指定した条件は適用していません"))
        #expect(text(.battery, "35").contains("35%"))
        #expect(text(.timer, "1970-01-01T00:00:00Z").contains("1970-01-01T00:00:00Z"))
    }
}
