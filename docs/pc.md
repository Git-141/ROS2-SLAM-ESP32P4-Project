# PC Ubuntu 开发与可视化说明

PC Ubuntu 在当前架构中作为工程工作站，不参与实时控制。

## 1. 主要职责

- 运行 RViz，查看点云、地图、TF 和导航状态。
- 通过 SSH 管理 Raspberry Pi 5 和 Raspberry Pi 4B。
- 调试 ROS2 topic、service、action 和参数。
- 查看日志、录制 rosbag、分析传感器数据。
- 开发或预览 Pi 4B 触控 UI。

## 2. 和 Raspberry Pi 5 的关系

身份：`DEV_PC`

配合方：`ROS_CORE`

PC 可以访问 Pi 5 的：

- ROS2 网络。
- SSH。
- Web 状态接口。
- 日志和 bag 文件。

PC 不应该绕过 Pi 5 的安全逻辑直接控制 RaspRover 底盘。

## 3. 和 Raspberry Pi 4B 的关系

身份：`DEV_PC`

配合方：`TOUCH_TERMINAL`

PC 可用于：

- 远程预览或开发触控 UI。
- 同步 UI 代码。
- 调试浏览器页面、WebSocket 和 HTTP 接口。
- 检查 kiosk 自启动配置。

## 4. 后续待补

- ROS2 域 ID 和网络配置。
- RViz 配置文件位置。
- 常用调试命令。
- bag 录制脚本。
- Pi 5 / Pi 4B 的 SSH 主机名和固定 IP 规划。
