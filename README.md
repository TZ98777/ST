# StickyTags 论文复现项目

本仓库用于整理 StickyTags 论文的课程级复现材料，目标是让组员能够共同维护实验报告、运行流程、测试代码、测试数据说明和实验结果。

当前复现状态：已完成核心机制层面的初步复现，包括 AArch64 MTE 环境检查、修改版 LLVM/SafeStack 与 TCMalloc 构建、堆/栈越界功能测试、16 标签轮转、边界距离测试、标签持久性测试、MTE 16 字节粒度测试，以及 protected/baseline 对照实验。

这不是完整论文复现。当前结果主要证明 StickyTags 的空间漏洞防护思路能够在本地 QEMU AArch64 MTE 环境中跑通；尚未复现论文中的 SPEC 性能表、真实 Arm MTE 硬件开销、Pixel/Samsung 实机数据、真实应用大规模评测和侧信道实验。

## 目录说明

```text
.
├── Experiment/        # 构建脚本、运行脚本、测试源码、原始日志和阶段记录
├── Report/            # 已有实验报告和通俗总结
├── docs/              # 设计思路、环境、运行流程、实验设计、协作说明
├── results/summary/   # 从日志中提取出的关键结果摘要
├── manifests/         # 上游源码版本和复现实验清单
├── patches/           # 后续若修改上游源码，在这里保存补丁
└── third_party/        # 第三方源码引用说明，不直接提交大型上游仓库
```

## 快速入口

- 完整设计思路：`docs/design.md`
- 实验环境：`docs/environment.md`
- 构建和运行流程：`docs/build-and-run.md`
- 测试数据集与结果：`docs/experiment-design.md`
- 当前复现边界：`docs/limitations.md`
- 分工建议：`docs/collaboration.md`

## 关键结果

功能测试：

| variant | heap-oob | stack-oob |
|---|---:|---:|
| baseline | 0/20 faults | 0/20 faults |
| protected | 20/20 faults | 20/20 faults |

Level 2 机制测试：

| suite | kind | cases | passed |
|---|---|---:|---:|
| boundary | heap | 320 | 320 |
| boundary | stack | 320 | 320 |
| cycle | heap | 5 | 5 |
| cycle | stack | 5 | 5 |
| granularity | heap | 100 | 100 |
| granularity | stack | 100 | 100 |
| persistence | heap | 5 | 5 |
| persistence | stack | 5 | 5 |

Level 3A protected/baseline 对照：

| metric | baseline | protected |
|---|---:|---:|
| expected_faults | 0 | 680 |
| observed_faults | 0 | 680 |
| layout_unavailable | 400 | 0 |
| cycle_mechanism_passes | 0 | 10 |
| persistence_tag_mismatches | 0 | 0 |

原始记录见 `Experiment/logs/`，整理摘要见 `results/summary/`。
