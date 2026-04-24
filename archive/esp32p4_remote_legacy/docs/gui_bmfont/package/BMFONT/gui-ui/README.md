# GUI UI Bitmap Font Files

这个目录就是“要上传到 SD 卡”的字库资源目录。

## Put On SD Card

建议把整个 `gui-ui` 目录上传到：

```text
/sdcard/BMFONT/gui-ui/
```

也就是：

- `/sdcard/BMFONT/gui-ui/manifest.json`
- `/sdcard/BMFONT/gui-ui/zh-CN/16/index.bin`
- `/sdcard/BMFONT/gui-ui/zh-CN/16/glyph.bin`
- `/sdcard/BMFONT/gui-ui/zh-CN/20/index.bin`
- `/sdcard/BMFONT/gui-ui/zh-CN/20/glyph.bin`
- `/sdcard/BMFONT/gui-ui/zh-CN/28/index.bin`
- `/sdcard/BMFONT/gui-ui/zh-CN/28/glyph.bin`
- `/sdcard/BMFONT/gui-ui/ja-JP/...`

## Loader Placement

板端加载器 `不放在 SD 卡`。

板端加载器应该是：

- 你项目里的一个组件或模块
- 用 C/C++ 写
- 编译进 ESP32-P4 固件

所以职责要分清：

- `SD 卡`：只放字库资源文件
- `ESP32-P4 固件`：放读取、查找、缓存、绘制代码

## Minimal Runtime Flow

1. 挂载 SD 卡。
2. 打开 `/sdcard/BMFONT/gui-ui/manifest.json`。
3. 选择语言目录，例如 `zh-CN` 或 `ja-JP`。
4. 选择字号目录，例如 `16`、`20`、`28`。
5. 把对应 `index.bin` 全读到 RAM。
6. 显示文本时，把 UTF-8 解码成 Unicode 码点。
7. 在索引表里查 `codepoint`。
8. 按 `bitmap_offset` 和 `bitmap_size` 从 `glyph.bin` 读取 A8 位图。
9. 按 `x_offset`、`y_offset`、`advance_x` 绘制。

## Suggested Firmware API

```c
bool bmfont_open(const char *root, const char *locale, int size_px);
const bmfont_glyph_index_t *bmfont_find_glyph(uint32_t codepoint);
bool bmfont_read_glyph_bitmap(const bmfont_glyph_index_t *glyph, uint8_t *dst);
void bmfont_close(void);
```

如果后面你要做语言切换：

- 中文界面：打开 `zh-CN/20`
- 日文界面：打开 `ja-JP/20`

如果后面你要做标题和正文分字号：

- 标题：`28`
- 正文按钮：`20`
- 状态小字：`16`

## Notes

- `index.bin` 适合整包载入内存。
- `glyph.bin` 适合按需读取，不建议整包常驻 RAM。
- 当前包格式是 A8 灰度位图，板端要自己做 alpha 混合绘制。
- 上层格式说明见 [../../README.md](/d:/Vscode/ROS2/ROS2-SLAM-ESP32P4-Project/docs/gui_bmfont/README.md)。
