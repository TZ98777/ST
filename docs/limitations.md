# 当前复现边界

本项目已经完成 StickyTags 核心机制的课程级初步复现，但不等于完整论文复现。

已完成：

- 阅读并理解 StickyTags 的标签持久化与空间漏洞防护思路。
- 构建并验证 QEMU AArch64 MTE 实验环境。
- 构建 modified LLVM/SafeStack、compiler-rt 和 modified TCMalloc。
- 编译 protected 与 baseline 测试程序。
- 验证堆越界和栈越界在 protected 版本中触发 MTE fault。
- 验证 16 标签轮转、边界距离、标签持久性和 MTE 16 字节粒度。
- 完成 protected/baseline 对照实验。

未完成：

- SPEC CPU2006/2017 性能复现。
- 真实 Arm MTE 设备上的运行时间和内存开销测量。
- Pixel 8 Pro、Samsung 设备或论文中移动平台数据复现。
- Juliet、真实 CVE 或真实应用数据集测试。
- x86 analog redzone 性能对比。
- Spectre-MTE 或其他侧信道相关实验。

不属于本项目目标：

- temporal safety 或 use-after-free 防护。论文明确将 temporal errors 排除在 StickyTags 范围外，因此这不是“尚未完成的论文功能”，也不能用持久标签测试证明。

报告中建议使用如下表述：

> 本实验完成了 StickyTags 论文核心保护机制的初步复现，重点验证其对堆/栈空间越界访问的标签失配检测能力，以及标签轮转和持久性设计。由于实验平台使用 QEMU AArch64 MTE 模拟环境，本实验结果只支持功能与机制层面的结论，不支持论文级真实硬件性能结论。
