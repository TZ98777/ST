# 阶段 1：专用 WSL2 环境记录

采集日期：2026-08-17

| 项目 | 记录值 |
|---|---|
| 原始发行版 | `Ubuntu` |
| 新发行版 | `StickyTagsLab` |
| WSL 版本 | 2 |
| 默认用户 | `brave`（UID 1000） |
| 安装位置 | `F:\WSL\StickyTagsLab` |
| 虚拟磁盘 | `F:\WSL\StickyTagsLab\ext4.vhdx` |
| 初始 VHDX 大小 | 约 2.29 GB |
| 基础导出包 | `F:\WSL\exports\Ubuntu-base-20260817.tar` |
| 基础导出包大小 | 约 1.98 GB |

验证结果：

- 原 `D:\WSL\Ubuntu` 未移动、未删除；
- `StickyTagsLab` 注册为独立 WSL2 发行版；
- 注册表中的 `BasePath` 为 `F:\WSL\StickyTagsLab`；
- 注册表中的 `DefaultUid` 为 1000；
- 以默认用户运行 `id` 时返回 `uid=1000(brave)`。

基础导出包暂时保留，待依赖安装和新环境启动验证完成后再决定是否删除。

