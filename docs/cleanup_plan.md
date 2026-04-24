# 当前目录清理说明

本次清理采用“归档，不直接删除”的方式。

## 保留在当前主线的内容

- `README.md`：项目总说明，已改为 Raspberry Pi 4B 触控终端路线。
- `docs/rpi.md`：两台 Raspberry Pi 的职责划分。
- `docs/rpi4b_touch_terminal.md`：Pi 4B + 同款屏幕的终端设计。
- `docs/gui.md`：Pi 4B 触控 GUI 设计，参考遥控器概览图。
- `docs/interfaces.md`：Pi 4B、Pi 5、PC、底盘之间的接口。
- `docs/pc.md`：PC Ubuntu 预留文档。

## 已归档的内容

归档目录：

- `archive/esp32p4_remote_legacy/`

其中包括：

- 旧 ESP32-P4 触控终端文档。
- 旧 LVGL GUI 设计文档。
- 旧 GUI 字符集和位图字库产物。
- 旧字库生成工具。

这些内容不再参与当前主线，但保留作为屏幕、触摸、字体和旧方案经验参考。

## 不建议删除的内容

- `.git/`：版本库。
- `.gitignore`：忽略规则。
- `.history/`：已被 `.gitignore` 忽略，如无需要可后续手动清理。
- `archive/`：旧 ESP32-P4 资料归档，建议至少保留到 Pi 4B 触控屏跑通之后。

## 后续建议新增的目录

等开始写实际代码时，建议新增：

```text
ros_core/              # Raspberry Pi 5 ROS2 工作区或服务代码
touch_terminal/        # Raspberry Pi 4B 触控 UI
scripts/               # 部署、启动、诊断脚本
configs/               # 网络、服务、UI 配置模板
```

当前没有提前创建这些目录，是为了避免空目录和未定技术栈造成干扰。
