# Raspberry Pi 节点说明

本项目当前使用两台 Raspberry Pi，职责需要明确分开。

## 1. Raspberry Pi 5：车载 ROS2 核心

身份：`Raspberry Pi 5 / Ubuntu / ROS2`

主要职责：

- 接入毫米波雷达、激光雷达等传感器。
- 运行 ROS2 节点、SLAM、导航和安全逻辑。
- 接收 Pi 4B 触控终端发来的人工控制指令。
- 将运动指令下发给 RaspRover 底盘。
- 向 Pi 4B 和 PC Ubuntu 提供状态、日志、地图摘要和服务状态。

设计原则：

- Raspberry Pi 5 是唯一决策节点。
- 不把触控 UI 和复杂人机交互塞进 Pi 5。
- 不让 Pi 4B 或 PC 直接控制底盘，必须经过 Pi 5 的安全逻辑。

## 2. Raspberry Pi 4B：触控操作终端

身份：`Raspberry Pi 4B / Touch UI`

主要职责：

- 搭配同款 Waveshare 10.1 寸 DSI 触控屏。
- 运行本地触控 UI，可以是浏览器全屏 Web UI、Qt、GTK 或轻量 Python UI。
- 显示系统总览、网络状态、Pi 5 通信状态、传感器状态和控制页面。
- 发送人工控制输入到 Pi 5。
- 提供必要的本地文件管理、配置页和日志查看入口。

设计原则：

- Pi 4B 只做人机交互，不运行核心 SLAM 决策。
- UI 可以比 ESP32-P4 路线更灵活，不需要继续受 MCU 字体、SD 卡字库、FreeType 性能限制。
- 优先使用标准 Linux 图形栈和 Web 技术，降低后续维护成本。

## 3. 推荐启动顺序

1. Pi 5 启动 ROS2、传感器、底盘桥接和状态服务。
2. Pi 4B 启动触控 UI。
3. UI 连接 Pi 5 的状态接口。
4. PC Ubuntu 按需启动 RViz 和调试工具。

## 4. 当前优先级

1. 先确定 Pi 4B 能否稳定驱动同款 10.1 寸 DSI 触控屏。
2. 选定 UI 技术路线：推荐先用全屏浏览器 Web UI。
3. Pi 5 提供最小 HTTP / WebSocket 状态服务。
4. Pi 4B 实现首页、控制页、状态页。
5. 再逐步接入毫米波、激光、SLAM 摘要信息。
