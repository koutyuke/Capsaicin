# dmgbuild の設定。DMG の見た目だけを決め、署名のジョブが中のアプリを入れ替える（DEC-SYS-028）。
# 使い方: dmgbuild -s settings.py -D app=<Capsaicin.app> -D background=<background.png> Capsaicin <DMG>
# 背景の画像は background.swift が描く。座標は background.swift の値と合わせる。

app = defines["app"]  # noqa: F821
background = defines["background"]  # noqa: F821

format = "ULFO"
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}
icon_locations = {
    "Capsaicin.app": (190, 164),
    "Applications": (470, 164),
    # 隠しファイルを表示する設定の人にも見えないよう、ウインドウの外へ置く。
    # .fseventsd はマウントしたときに macOS が作ることがある
    ".background.tiff": (330, 520),
    ".fseventsd": (190, 520),
}
# 高さはタイトルバーを含む。中身が 400 になるよう 32 を足す
window_rect = ((200, 200), (660, 432))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
