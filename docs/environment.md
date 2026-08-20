# 实验环境

本项目当前结果来自本地课程级实验环境：

- Host：Windows 11，x86_64
- WSL：Ubuntu / WSL2
- Guest：QEMU AArch64 Linux
- MTE：QEMU TCG 模拟 Armv8.5-A Memory Tagging Extension
- 上游源码：`https://github.com/vusec/stickytags.git`
- 上游 commit：`db3ba2616ce0935fba6352192a43010ba9d3172a`
- `spectre-mte` submodule：`9623aa8a6c5ca7cec937faefcea72981beee8c09`

关键工具版本和二进制证据见：

- `Experiment/manifests/technical-reproduction-manifest.txt`
- `Experiment/logs/stage3-source-versions.txt`
- `Experiment/logs/stage4-toolchain-validation.txt`

主机脚本的可覆盖配置见 `Experiment/lab-env.sh`，虚拟机所需文件和当前缺失的镜像创建流程见 `docs/vm-assets.md`。

## 环境限制

当前平台不是原生 Arm MTE 硬件。QEMU 可以验证 MTE fault 与标签行为，但不能用于复现论文中的真实硬件性能开销。因此报告中应把当前实验定位为功能与机制复现，不应把 QEMU 运行时间与论文中的 Pixel 8 Pro 或其他真实设备数据直接比较。
