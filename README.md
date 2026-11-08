# CopyShelf

一个轻量、开源的 macOS 剪贴板历史工具。只保留一件事：让最近复制的纯文本随手可取。

- 点击菜单栏图标查看最近 100 条文本
- 点击一条记录，把它放回系统剪贴板，然后回到原应用自行粘贴
- 历史只保存在本机的 `~/Library/Application Support/CopyShelf/history.json`
- 不联网、不同步、不读取图片或其他非文本内容

## 构建和运行

需要 macOS 13 或更新版本，以及 Xcode Command Line Tools。

```sh
./scripts/build_app.sh
open dist/CopyShelf.app
```

也可以直接运行开发版本：

```sh
swift run
```

## 说明

应用以菜单栏常驻项运行。选择历史记录只会恢复剪贴板内容，不会模拟键盘输入，也不会自动粘贴。退出并重新打开应用后，本机保存的文本历史仍然可用。删除历史会移除应用保存的记录，不会清空当前系统剪贴板。

## 开源许可

MIT，详见 [LICENSE](LICENSE)。
