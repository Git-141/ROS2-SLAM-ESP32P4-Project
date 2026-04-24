# GUI Charset Bundle

这组文件用于从 `docs/gui.md` 推导 GUI 中文版和日文版的常用字符集，给后续位图字库裁剪或 MCU 端字库加载使用。

当前产物不是字形位图，而是“字符集输入包”：

- `gui_locale_strings.json`
  UI 可见文案的人工整理版。只保留会直接上屏或高概率上屏的词条。
- `manifest.json`
  导出结果摘要，包含每个语言包的字符串数和码点数。
- `zh-CN.strings.txt` / `ja-JP.strings.txt`
  各语言版本的 UI 文案清单。
- `zh-CN.codepoints.txt` / `ja-JP.codepoints.txt`
  去重后的 Unicode 码点列表，便于人工核对。
- `zh-CN.codepoints.bin` / `ja-JP.codepoints.bin`
  MCU 友好的二进制码点表。

## Binary Format

`*.codepoints.bin` 使用固定小端格式：

```c
struct GuiCodepointTableHeader {
    char magic[4];      // "UCS4"
    uint16_t version;   // 1
    uint16_t flags;     // 0
    uint32_t count;     // 后续码点数量
};

uint32_t codepoints[count]; // little-endian Unicode code point
```

说明：

- 码点按升序排列。
- 默认额外包含可打印 ASCII：`U+0020` 到 `U+007E`。
- 之所以使用 `uint32_t`，是为了兼容 `🏠`、`🔒` 这种超出 BMP 的符号。

## Regenerate

```powershell
python tools/build_gui_charset.py
```

## Scope

- 中文版：按 `docs/gui.md` 中实际页面和状态文案整理，并补入毫米波 / 激光 / SLAM 预留页的高概率 UI 词条。
- 日文版：根据当前页面结构和交互语义推测出的对应 UI 文案，不是产品最终翻译稿。
- 图标类符号目前只纳入文档里已经直接出现的少量字符，例如 `←`、`●`、`🔒`、`🏠`。
