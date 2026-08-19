# 实验步骤与结果

## 测试数据集

本项目当前没有使用 SPEC、Juliet、CVE PoC 或真实应用数据集。测试数据集是自定义合成测试程序，位于：

- `Experiment/tests/stickytags-functional.c`
- `Experiment/tests/stickytags-mechanism.c`

这些测试用例专门覆盖 StickyTags 的核心机制：堆对象、栈对象、相邻对象越界、16 标签周期、地址复用标签持久性和 MTE 16 字节粒度。

## 实验步骤

1. 检查 AArch64 guest 是否支持 MTE、`PROT_MTE`、`prctl` 和 `userfaultfd`。
2. 构建 protected 测试程序，启用 StickyTags LLVM/SafeStack 与修改版 TCMalloc。
3. 构建 baseline 测试程序，不启用 StickyTags 保护。
4. 在 QEMU AArch64 MTE guest 中运行功能测试。
5. 运行 核心机制验证实验，覆盖标签轮转、边界距离、持久性和 MTE 粒度。
6. 运行 保护版本与未保护版本对照测试。
7. 保存原始日志，并提取结果摘要。

## 功能测试结果

| variant | heap-oob | stack-oob |
|---|---:|---:|
| baseline | 0/20 faults | 0/20 faults |
| protected | 20/20 faults | 20/20 faults |

解释：未保护程序不会因为测试中的越界访问触发 MTE fault；protected 程序在堆和栈越界测试中均稳定触发 fault。

## 核心机制验证实验结果

| suite | kind | cases | passed | pass rate |
|---|---|---:|---:|---:|
| boundary | heap | 320 | 320 | 100.0% |
| boundary | stack | 320 | 320 | 100.0% |
| cycle | heap | 5 | 5 | 100.0% |
| cycle | stack | 5 | 5 | 100.0% |
| granularity | heap | 100 | 100 | 100.0% |
| granularity | stack | 100 | 100 | 100.0% |
| persistence | heap | 5 | 5 | 100.0% |
| persistence | stack | 5 | 5 | 100.0% |

关键指标：

- `fault_cases=840`
- `expected_faults=680`
- `observed_faults=680`
- `unexpected_sigsegv=0`
- `cycle_objects=320`
- `persistence_iterations=10000`
- `persistence_reuses=9990`
- `persistence_tag_mismatches=0`

## 保护版本与未保护版本对照结果

| metric | baseline | protected |
|---|---:|---:|
| expected_faults | 0 | 680 |
| observed_faults | 0 | 680 |
| layout_unavailable | 400 | 0 |
| skipped_layout_cases | 400 | 0 |
| unexpected_sigsegv | 0 | 0 |
| cycle_mechanism_passes | 0 | 10 |
| persistence_iterations | 10000 | 10000 |
| persistence_tag_mismatches | 0 | 0 |

解释：protected 版本表现出 StickyTags 的 16 标签轮转和越界 fault 行为；680 个故障均由 `SEGV_MTEAERR` 专用故障码确认，普通段错误数量为 0。baseline 没有 StickyTags size-class 布局的 400 个用例记录为 `SKIP`，不计作通过或失败；其余实际执行的 baseline 用例没有产生 MTE fault。

原始数据见 `Experiment/logs/`，整理摘要见 `results/summary/`。
