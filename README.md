# ROS2-SLAM-RaspRover-Project

基于 Waveshare RaspRover 无人车平台的毫米波 + 激光雷达 SLAM 实验系统。

当前硬件方向已经调整：

- 保留 RaspRover 底盘作为黑盒执行单元。
- 使用 Raspberry Pi 5 作为车载 ROS2 核心计算节点。
- 取消 ESP32-P4 独立无线遥控器路线。
- 改用 Raspberry Pi 4B 搭配同款 Waveshare 10.1 寸 DSI 触控屏，作为操作终端 / 状态屏。
- PC Ubuntu 继续作为开发、RViz 可视化和调试工作站。

旧 ESP32-P4 遥控器资料已归档到：

- `archive/esp32p4_remote_legacy/`

---

## 系统组成

系统由四个逻辑节点构成：

- RaspRover 小车：内部 ESP32 控制底盘，作为黑盒使用。
- Raspberry Pi 5：Ubuntu + ROS2，负责感知、SLAM、导航与底盘指令。
- Raspberry Pi 4B：Ubuntu / Raspberry Pi OS + 同款 10.1 寸触控屏，负责人机交互。
- PC Ubuntu：开发、RViz、日志分析和参数调试。

RaspRover 自带 ESP32 负责电机与编码器控制，本项目不修改其固件，仅通过上位接口控制小车运动。

---

## 系统拓扑

```text
PC Ubuntu
   |
   | ROS2 / SSH / 网络调试
   |
Raspberry Pi 5 (Ubuntu + ROS2)
   |
   | SDK / 网络接口
   |
RaspRover 底盘（黑盒）

Raspberry Pi 4B + 10.1 寸触控屏
   |
   | WiFi / Ethernet / HTTP / WebSocket / ROS2 Bridge
   |
Raspberry Pi 5 / PC Ubuntu
```

---

## 各模块职责

### RaspRover 小车

- 内置 ESP32 控制电机与编码器。
- 提供 SDK / 通信接口。
- 本项目不开发底层固件。

定位：移动平台执行单元。

### Raspberry Pi 5

- 接入毫米波雷达与激光雷达。
- 运行 ROS2、SLAM 和导航逻辑。
- 向 RaspRover 下发运动指令。
- 向 Raspberry Pi 4B 和 PC 提供状态、控制与摘要数据接口。

定位：感知 + 决策中心。

### Raspberry Pi 4B + 10.1 寸触控屏

- 运行触控 UI。
- 提供遥控输入、状态显示、网络配置入口。
- 可显示地图摘要、传感器状态和系统日志摘要。
- 不直接驱动底盘电机，控制指令先发给 Raspberry Pi 5。

定位：人机交互终端。

### PC Ubuntu

- RViz、点云显示、地图查看。
- ROS2 调试、参数调节、日志分析。
- 必要时为 Pi 4B UI 提供浏览器访问或开发调试。

定位：工程工作站。

---

## 当前阶段目标

第一阶段：

- 在 Raspberry Pi 5 上接入毫米波测距。
- 基于距离阈值控制 RaspRover 停止 / 前进。
- 在 Raspberry Pi 4B + 10.1 寸屏上实现基础遥控与状态 UI。
- PC Ubuntu 显示基础地图 / 点云。

后续阶段：

- 激光雷达 SLAM。
- 自主导航。
- 毫米波补充感知。
- Pi 4B 屏幕显示简化地图和系统状态。
- 云台扫描实验。

---

## 文档结构

- `docs/rpi.md`：Raspberry Pi 5 与 Raspberry Pi 4B 的角色划分。
- `docs/rpi4b_touch_terminal.md`：Pi 4B + 同款触控屏终端设计。
- `docs/gui.md`：Pi 4B 触控 GUI 设计，参考遥控器概览图。
- `docs/interfaces.md`：跨设备接口与配合需求。
- `docs/pc.md`：PC Ubuntu 开发 / 可视化说明。
- `archive/esp32p4_remote_legacy/`：旧 ESP32-P4 遥控器文档、GUI 字库和工具归档。

在实现某一部分前，请先阅读对应文档，做出改动后同步更新文档。
