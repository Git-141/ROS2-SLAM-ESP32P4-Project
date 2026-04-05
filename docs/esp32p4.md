# ESP32-P4 Touch GUI Notes

本文档对应工程 `D:\Vscode\ESP_IDF\esp32p4_touch_gui_terminal`。

目标已经调整为：

- 先把 10.1 寸屏的显示、触摸、中文/日文字体方案跑通
- UI 按新的示意图从头写，不沿用旧的多页面原型
- 暂时不把 ROS2、底盘控制、SLAM、Wi-Fi 配网等业务逻辑混进当前联调

## 1. 已确认的硬件信息

- 开发板：Waveshare ESP32-P4-WIFI6-DEV-KIT-C 
- 屏幕：`Waveshare 10.1-DSI-TOUCH-A`
- 显示 IC：`JD9365`
- 触摸 IC：`GT9271`

当前实机日志已经确认：

- LCD 驱动识别为 `jd9365`
- 触摸地址识别为 `0x5d`
- GT9xx 日志可读到 `0x39 0x32 0x37`

结论：

- 显示链路是通的
- 触摸硬件是通的
- 中文显示问题不在显示 IC 或触摸 IC，本质在字体

## 2. 当前工程的有效状态

截至 2026-04-05，当前工程已经临时收缩为最小测试路径：

- `main/main.c`
- `components/terminal_gui_app/src/app/terminal_gui_app.c`
- `components/terminal_gui_app/src/ui/ui_shell.c`
- `components/terminal_gui_app/src/ui/ui_theme.c`

当前不是正式业务 UI，而是联调版：

- 启动 NVS
- 启动 BSP 显示与触摸
- 进入单页触摸测试界面
- 测试页显示中文、颜色按钮、触摸坐标和按压变色反馈

旧的多页面路由、mock backend、状态层架构代码仍在仓库里，但当前不应作为下一版 UI 的设计基线。

## 3. 当前已验证有效的显示与触摸配置

当前 `terminal_gui_app.c` 使用：

- `rotation = ESP_LV_ADAPTER_ROTATE_90`
- `swap_xy = 1`
- `mirror_x = 1`
- `mirror_y = 0`

当前结论：

- 这组参数下，触摸方向已经从之前的“对角反着”修正到可用状态
- 之前的问题不是触摸坏了，而是横屏后的触摸坐标变换没有对齐

## 4. 已确认的问题归因

### 4.1 显示黑屏

已解决。

原因是早期屏幕型号配置不对，不是 LVGL 本身不能出图。

### 4.2 按屏后界面卡死

已基本解决。

此前已经修改过 `managed_components/espressif__esp_lvgl_adapter/src/input/esp_lv_adapter_input_touch.c`，把无 IRQ 触摸的读取从 LVGL 线程中分离出来，改为后台轮询缓存。当前触摸链路已可持续出点，不再是一按就把 GUI 拖死的状态。

### 4.3 中文出现方块

未解决，但原因已经比较明确：

- 问题不在 `JD9365`
- 问题不在 `GT9271`
- 问题主要在字体覆盖范围

当前 `ui_theme.c` 使用的是静态字体：

- `lv_font_source_han_sans_sc_14_cjk`
- `lv_font_source_han_sans_sc_16_cjk`

这不等于“完整中文都已覆盖”，更不等于后续日语可直接覆盖。

## 5. 与字体有关的当前判断

如果后面要加入日语，继续只靠编进固件的小静态字库会越来越难维护。

当前更合理的方案是双层字体策略：

- 固件内保留一套小 fallback 字体
  用于启动页、报错页、SD 卡未挂载时的基础文本
- SD 卡放完整字体文件
  例如后续放中日文字体的 `ttf` / `otf`
- 运行时用 FreeType 加载 SD 卡字体

当前工程和 BSP 已具备这条路线的基础：

- BSP 有 `bsp_sdcard_mount()`
- 工程里已有 `espressif__freetype`
- 工程里已有 `espressif__esp_lv_fs`

## 6. 对下一版 UI 的建议

下一版 UI 建议按下面顺序做，不要再回到旧的多页面原型上叠改：

1. 先根据新的手绘示意图直接重写布局
2. 第一版只实现静态页面结构、触摸命中、颜色/状态反馈
3. 第二版再补统一字体入口
4. 第三版再决定是否接入 SD 卡字体
5. 最后才考虑把旧工程里的业务状态、mock、页面导航逐步接回去

简化原则：

- 先验证“页面长什么样”和“触摸点得准不准”
- 不要同时调页面逻辑、字体、网络、状态层
- 不要让旧的架构预设限制新的界面设计

## 7. 当前最值得保留的经验

- 10.1 寸屏必须按正确屏型配置，不要再按 7 寸思路处理
- 触摸调试必须把 `rotation / swap_xy / mirror_x / mirror_y` 当成一组来看
- 中文/日文显示问题优先从字体层处理，不要误判成屏驱动问题
- 如果 UI 要支持中文和日语，最终大概率需要“内置 fallback + SD 卡字体”
- 如果你给出新的草图或线框图，可以直接按图重写，不必绑定旧 UI 结构

## 8. 当前构建状态

截至本次整理时：

- `idf.py build` 通过
- 当前联调版固件可用于继续验证显示、触摸、字体路径

## 9. 不再作为当前决策依据的内容

以下内容暂时不再作为当前阶段重点：

- 旧的 7 页面业务原型
- mock backend 的完整分层说明
- 未来 Raspberry Pi 真 backend 接口设计细节
- Wi-Fi 页面和车辆业务动作占位逻辑
- 与当前“按示意图重写 UI”无关的长篇推测性调试记录
