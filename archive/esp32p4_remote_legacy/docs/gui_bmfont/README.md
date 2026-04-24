# GUI Bitmap Font Package

这套文件把 `docs/gui_charset` 里的字符集输入包，进一步导出为 MCU 可直接加载的多字号位图字库包。

## Why Multiple Sizes

位图字库通常是固定字号，所以这里默认输出三档：

- `16px`
  小字，适合状态栏、辅助说明、日志。
- `20px`
  主字号，适合按钮、标签、普通正文。
- `28px`
  大字，适合页面标题、重点状态、关键数值。

如果后面 UI 证明还需要别的字号，直接重跑导出器即可。

## Output Layout

```text
docs/gui_bmfont/package/gui-ui/
  manifest.json
  zh-CN/
    16/
      index.bin
      glyph.bin
    20/
      index.bin
      glyph.bin
    28/
      index.bin
      glyph.bin
  ja-JP/
    16/
      index.bin
      glyph.bin
    20/
      index.bin
      glyph.bin
    28/
      index.bin
      glyph.bin
```

## Binary Format

### `index.bin`

文件头：

```c
struct BmFontIndexHeader {
    char magic[4];        // "BMFI"
    uint16_t version;     // 1
    uint16_t flags;       // 0
    uint32_t glyph_count;
    uint16_t font_size_px;
    uint16_t line_height_px;
    int16_t ascender_px;
    int16_t descender_px;
    uint32_t reserved;
};
```

索引项：

```c
struct BmFontGlyphIndex {
    uint32_t codepoint;
    uint32_t bitmap_offset;
    uint32_t bitmap_size;
    uint16_t width;
    uint16_t height;
    int16_t x_offset;
    int16_t y_offset;
    uint16_t advance_x;
    uint16_t reserved;
};
```

说明：

- `bitmap_offset` 和 `bitmap_size` 对应 `glyph.bin` 里的原始 A8 灰度位图。
- `x_offset` / `y_offset` 以“行框左上角”为参考，而不是 baseline。
- 空格等无像素字形会保留索引项，但 `width/height/bitmap_size` 可能为 0。

### `glyph.bin`

```c
struct BmFontGlyphBlobHeader {
    char magic[4];        // "BMFG"
    uint16_t version;     // 1
    uint16_t flags;       // bit0 = 1 表示 A8 灰度位图
    uint32_t glyph_data_bytes;
    uint32_t reserved;
};
```

后面紧跟所有字形位图数据，按行优先排列，每像素 1 字节 alpha。

## MCU Render Model

建议板端文本渲染逻辑：

1. 先按 `font_size_px` 选择字库。
2. 查 `codepoint -> BmFontGlyphIndex`。
3. 把 `glyph.bin` 对应区域读到内存或缓存。
4. 在 `(pen_x + x_offset, line_y + y_offset)` 位置绘制 A8 位图。
5. `pen_x += advance_x`。

## Deploy And Loader

这套字库包和“板端加载器”不是同一个东西：

- 放到 SD 卡的是字库数据文件：
  `manifest.json`、`index.bin`、`glyph.bin`
- 不放到 SD 卡的是板端加载器：
  它应该是 ESP32-P4 固件里的 C/C++ 代码，编进固件 flash

推荐部署路径：

```text
/sdcard/BMFONT/gui-ui/
  manifest.json
  zh-CN/16/index.bin
  zh-CN/16/glyph.bin
  zh-CN/20/index.bin
  zh-CN/20/glyph.bin
  zh-CN/28/index.bin
  zh-CN/28/glyph.bin
  ja-JP/...
```

推荐板端模块拆分：

1. `bmfont_fs`
   负责挂载 SD、拼路径、读取文件。
2. `bmfont_index`
   负责解析 `index.bin` 到内存。
3. `bmfont_glyph_cache`
   负责按需从 `glyph.bin` 读取字形并做缓存。
4. `bmfont_draw`
   负责把 A8 位图混合到 framebuffer 或 LVGL draw buffer。
5. `bmfont_text`
   负责 UTF-8 解码、逐字布局、换行和字号选择。

推荐最小加载流程：

1. 启动时挂载 SD 卡。
2. 打开 `/sdcard/BMFONT/gui-ui/manifest.json`，确定支持的语言和字号目录。
3. 选择当前语言，例如 `zh-CN` 或 `ja-JP`。
4. 选择当前字号，例如 `20`。
5. 把对应的 `index.bin` 整体读入 RAM。
6. 渲染时按 Unicode 码点在索引表里查字。
7. 命中后再从 `glyph.bin` 按偏移读位图。
8. 把位图 alpha 混合到目标像素缓冲区。

也就是说：

- `SD 卡` 里保存的是“资源文件”
- `固件` 里保存的是“加载器和渲染逻辑”

### Minimal C Structs

```c
typedef struct __attribute__((packed)) {
    char magic[4];          // "BMFI"
    uint16_t version;
    uint16_t flags;
    uint32_t glyph_count;
    uint16_t font_size_px;
    uint16_t line_height_px;
    int16_t ascender_px;
    int16_t descender_px;
    uint32_t reserved;
} bmfont_index_header_t;

typedef struct __attribute__((packed)) {
    uint32_t codepoint;
    uint32_t bitmap_offset;
    uint32_t bitmap_size;
    uint16_t width;
    uint16_t height;
    int16_t x_offset;
    int16_t y_offset;
    uint16_t advance_x;
    uint16_t reserved;
} bmfont_glyph_index_t;

typedef struct __attribute__((packed)) {
    char magic[4];          // "BMFG"
    uint16_t version;
    uint16_t flags;
    uint32_t glyph_data_bytes;
    uint32_t reserved;
} bmfont_glyph_header_t;
```

### Minimal Loader Outline

```c
bool bmfont_open(const char *root, const char *locale, int size_px);
const bmfont_glyph_index_t *bmfont_find_glyph(uint32_t codepoint);
bool bmfont_read_glyph_bitmap(const bmfont_glyph_index_t *glyph, uint8_t *dst);
void bmfont_draw_text(int x, int y, const char *utf8, lv_color_t color);
```

实现建议：

- `index.bin` 放内存，查找速度更稳定。
- `glyph.bin` 不要整包一次性载入，按需读并做 LRU cache。
- UI 主字号建议先用 `20px`，状态小字用 `16px`，标题用 `28px`。
- 如果后面要支持动态切换中/日文，只要切换当前 locale 对应目录即可。

## Build

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_gui_bmfont.ps1
```

默认输入：

- `docs/gui_charset/zh-CN.codepoints.bin`
- `docs/gui_charset/ja-JP.codepoints.bin`

默认字体链：

- `zh-CN`: `Noto Sans SC` -> `Microsoft YaHei UI` -> `SimHei` -> `Segoe UI Symbol` -> `Segoe UI Emoji`
- `ja-JP`: `Noto Sans JP` -> `Meiryo` -> `Yu Gothic UI` -> `MS Gothic` -> `Segoe UI Symbol` -> `Segoe UI Emoji`

## Notes

- 当前导出器使用 Windows `System.Drawing`，适合先把 PC 端打包流程跑通。
- 这套包格式已经可以给 MCU 使用，但板端还需要实现索引查询和 A8 混合绘制。
- 对于 `🏠`、`🔒` 这类符号，导出器会优先尝试 `Segoe UI Emoji`。
- 字库资源建议上传到 `/sdcard/BMFONT/gui-ui`，不要和板端加载器代码混在一起。
