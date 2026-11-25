import AppKit
import Testing

extension SettingsTests {
    @Test("SPEC-SET-001 見える高さが同じでも行高の変更で空き行と余白を測り直す")
    func sidebarRowHeightChanges() async throws {
        _ = NSApplication.shared
        let rows = ResizingSidebarRows()
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 390))
        table.style = .inset
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sidebar")))
        table.intercellSpacing = .zero
        table.dataSource = rows
        table.delegate = rows
        let scroll = NSScrollView(frame: table.frame)
        scroll.documentView = table
        table.reloadData()
        for row in 0 ..< table.numberOfRows {
            _ = try #require(table.rowView(atRow: row, makeIfNecessary: true))
        }
        rows.spacer.availableHeight = 390
        rows.spacer.updateHeight()

        // SwiftUI が intrinsicContentSize を行高へ反映する過程だけをまねる。
        // 最初の接続後は updateHeight を直接呼ばず、AppKit のフレーム通知に任せる。
        func settle() async {
            for _ in 0 ..< 6 {
                table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< table.numberOfRows))
                table.tile()
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async { continuation.resume() }
                }
            }
        }

        rows.height = 40
        await settle()
        #expect(rows.spacer.intrinsicContentSize.height < 390 - 6 * rows.height)
        #expect(abs(table.frame.height - 390) <= 0.5)

        // 余白が減る変更でも、古い測定値の分だけ下端に隙間を残さない。
        table.style = .plain
        for height: CGFloat in [32, 24, 40, 24] {
            rows.height = height
            await settle()
            #expect(rows.spacer.intrinsicContentSize.height == 390 - 6 * height)
            #expect(abs(table.frame.height - 390) <= 0.5)
            #expect(table.rect(ofRow: table.numberOfRows - 1).maxY <= 390)
        }
        rows.spacer.availableHeight = 100
        rows.spacer.updateHeight()
        await settle()
        #expect(rows.spacer.intrinsicContentSize.height == 0)
    }
}

@MainActor
private final class ResizingSidebarRows: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var height: CGFloat = 24
    let spacer = SettingsSidebarSpacer.SpacerView()

    func numberOfRows(in _: NSTableView) -> Int {
        SettingsSection.allCases.count + 1
    }

    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        row == 4 ? max(spacer.intrinsicContentSize.height, 1) : height
    }

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        row == 4 ? spacer : NSView()
    }
}
