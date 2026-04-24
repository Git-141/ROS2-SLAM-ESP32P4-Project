# 跨设备接口说明

本文档暂时只保留设备身份与接口规划边界。

具体 HTTP、WebSocket、ROS2 topic、消息字段和文件传输接口先不固定，等 Pi 4B 触控终端和 Pi 5 ROS2 核心的实际技术路线确定后再补充，避免旧接口误导实现。

## 1. 设备身份

| 身份 | 设备 | 职责 |
| --- | --- | --- |
| `ROVER_BASE` | RaspRover 底盘 | 黑盒执行单元 |
| `ROS_CORE` | Raspberry Pi 5 Ubuntu | ROS2、SLAM、导航、安全控制 |
| `TOUCH_TERMINAL` | Raspberry Pi 4B + 10.1 寸屏 | 触控 UI、遥控输入、状态显示 |
| `DEV_PC` | PC Ubuntu | RViz、开发、调试 |

旧身份 `ESP32P4` 已迁移到归档资料，不再作为当前实现目标。

## 2. 接口规划原则

- `ROS_CORE` 是唯一决策节点。
- `TOUCH_TERMINAL` 只发送用户操作意图，不直接控制底盘。
- `DEV_PC` 用于开发、可视化和调试，不参与实时控制。
- `ROVER_BASE` 作为黑盒执行单元，本项目不修改其底层固件。
- 所有跨设备接口后续都应标明发送方身份、接收方身份、用途和安全边界。

## 3. 后续待补

等技术路线确认后，再逐步补充：

- Pi 4B 触控 UI 与 Pi 5 的通信方式。
- Pi 5 与 RaspRover 底盘的控制接口。
- PC Ubuntu 与 Pi 5 的 ROS2 / RViz 调试配置。
- 状态、日志、传感器摘要、地图摘要等数据边界。
- 急停、刹车、通信超时等安全策略。
