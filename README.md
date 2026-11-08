# CopyShelf

轻量、开源的 macOS 剪贴板管理器，只做一件事：让你的复制历史触手可及。

Lightweight, open-source clipboard history for macOS. One job: keep your copied text close at hand.

## 简体中文

CopyShelf 常驻在菜单栏，记录最近复制的 100 条纯文本。历史只保存在本机，不联网、不同步。

### 使用方法

1. 启动 CopyShelf 后，点击菜单栏中的剪贴板图标。
2. 在任意应用中复制文本；CopyShelf 会把它加入历史记录。
3. 按默认快捷键 `⌥⇧V`，或点击菜单栏图标，呼出历史记录。
4. 选择一条记录将它放回系统剪贴板，再切回目标应用按 `⌘V` 粘贴。CopyShelf 不会自动粘贴，也不需要辅助功能权限。
5. 点击弹层标题旁的键盘图标可以录制自定义快捷键。组合键必须包含至少一个修饰键；若快捷键已被占用，CopyShelf 会提示更换。
6. 点击 **清空** 可删除已保存的历史记录；这不会清空当前系统剪贴板。

退出后重新打开应用，历史记录仍保留在本机。当前版本只记录纯文本，不保存图片或其他类型的剪贴板内容。

### 构建和启动

需要 macOS 13 或更新版本，以及 Xcode Command Line Tools。

```sh
./scripts/build_app.sh
open dist/CopyShelf.app
```

开发时也可以直接运行：

```sh
swift run
```

历史文件位于 `~/Library/Application Support/CopyShelf/history.json`。

## English

CopyShelf lives in the menu bar and keeps the 100 most recent plain-text items you copy. History stays on this Mac; nothing is uploaded or synced.

### How to use

1. Launch CopyShelf and click its clipboard icon in the menu bar.
2. Copy text in any app. CopyShelf adds it to your history.
3. Press the default shortcut `⌥⇧V`, or click the menu bar icon, to show your history.
4. Select an item to put it back on the system clipboard, then switch to the target app and press `⌘V`. CopyShelf does not paste for you and needs no Accessibility permission.
5. Click the keyboard icon beside the popover title to record a custom shortcut. Use at least one modifier key; CopyShelf will let you know if the shortcut is already in use.
6. Click **清空** (“Clear”) to delete the saved history. This does not clear the current system clipboard.

Your history stays on this Mac when you quit and relaunch the app. This version stores plain text only; it does not save images or other clipboard data.

### Build and launch

Requires macOS 13 or later and Xcode Command Line Tools.

```sh
./scripts/build_app.sh
open dist/CopyShelf.app
```

For development, you can also run:

```sh
swift run
```

History is stored at `~/Library/Application Support/CopyShelf/history.json`.

## License

MIT. See [LICENSE](LICENSE).
