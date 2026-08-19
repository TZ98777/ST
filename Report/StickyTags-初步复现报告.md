# StickyTags 初步复现报告

日期：2026-08-19

## 1. 复现目标

本阶段目标不是完整复现论文中的 SPEC 性能、Juliet、真实 CVE 和真实设备侧信道实验，而是验证 StickyTags 的核心机制是否已经在本地环境中工作：

- heap 和 stack 对象使用带 tag 的指针。
- size-class slot 中 tag 呈确定性 round-robin 循环。
- slot 1-15 的相邻越界访问触发 MTE fault，slot 16 因 tag 循环不触发 fault。
- 复用同一地址时 tag 保持稳定，体现 persistent memory tag 行为。
- protected 版本和 baseline 版本在同一测试输入下表现不同，差异来自 StickyTags 机制。

## 2. 清理内容

本次删除了此前确认无复现价值或可再生成的文件：

- `F:\Paper\StickyTags\tmp\stickytags_sp24.txt`
- `F:\Paper\StickyTags\tmp\pdfs`
- `F:\Paper\StickyTags\GitHub\stickytags\gperftools\bak.git`
- `F:\Paper\StickyTags\GitHub\stickytags\gperftools\install`
- `/home/brave/stickytags-lab/src/stickytags/gperftools/bak.git`
- `/home/brave/stickytags-lab/src/stickytags/gperftools/install`

保留了 `Experiment/logs`、`Experiment/tests`、`MECHANISM-VALIDATION.md` 和 `PROTECTED-BASELINE-COMPARISON.md`，因为它们是当前复现实验证据。

## 3. 环境与产物

权威源码目录：

```text
/home/brave/stickytags-lab/src/stickytags
```

VM 和运行环境：

```text
QEMU AArch64 VM: /home/brave/stickytags-lab/vm
SSH 入口: 127.0.0.1:2222
Guest architecture: aarch64
Guest CPU features include: mte, mte3
```

Guest 中的关键二进制：

```text
/opt/stickytags/bin/repository-test
/opt/stickytags/bin/stickytags-functional
/opt/stickytags/bin/unprotected-functional
/opt/stickytags/bin/stickytags-mechanism
/opt/stickytags/bin/unprotected-mechanism
/opt/stickytags/lib/libtcmalloc.so.4.5.10
```

## 4. 原仓库测试

原仓库 `test/run.sh` 写死旧路径 `/root/tagpool/...`，不能直接原样运行。当前环境中已使用现有工具链构建同源 `test/test.c`，产物为：

```text
/opt/stickytags/bin/repository-test
```

运行命令：

```bash
ssh -i /home/brave/.ssh/stickytags_vm_ed25519 -p 2222 brave@127.0.0.1 \
  /opt/stickytags/bin/repository-test 1 2 3 4
```

代表输出：

```text
ptr0 0xaf6587024000 ptr1 0x100af6587024030 ptr2 0x200af6587024060
buf16 0xf00af65867fffc0 buf15 0xe00af65867fff80 buf14 0xf00af6586ffff80
```

该输出说明原仓库测试程序中的 heap 和 stack 指针都带有 top-byte tag。

## 5. 核心机制验证实验

运行命令：

```bash
./Experiment/run-mechanism-tests-in-vm.sh 5 20 1000
```

结果文件：

```text
Experiment/logs/mechanism-test-results.txt
Experiment/logs/mechanism-test-summary.txt
```

复跑结果：

| suite | kind | cases | passed | pass rate |
|---|---|---:|---:|---:|
| cycle | heap | 5 | 5 | 100.0% |
| cycle | stack | 5 | 5 | 100.0% |
| boundary | heap | 320 | 320 | 100.0% |
| boundary | stack | 320 | 320 | 100.0% |
| granularity | heap | 100 | 100 | 100.0% |
| granularity | stack | 100 | 100 | 100.0% |
| persistence | heap | 5 | 5 | 100.0% |
| persistence | stack | 5 | 5 | 100.0% |

关键指标：

```text
cycle_objects=320
persistence_iterations=10000
persistence_reuses=9990
persistence_tag_mismatches=0
fault_cases=840
expected_faults=680
observed_faults=680
```

解释：

- tag cycle、boundary、persistence、granularity 四类机制均通过。
- 680 个预期 MTE fault 全部观察到。
- 10000 次 persistence 迭代中 tag mismatch 为 0。

## 6. 保护版本与未保护版本对照复现

运行命令：

```bash
./Experiment/run-protected-baseline-in-vm.sh 5 20 1000
```

结果文件：

```text
Experiment/logs/protected-baseline-results.txt
Experiment/logs/protected-baseline-summary.txt
```

关键结果：

```text
baseline expected_faults=0
baseline observed_faults=0
baseline cycle_mechanism_passes=0
baseline persistence_tag_mismatches=0

protected expected_faults=680
protected observed_faults=680
protected cycle_mechanism_passes=10
protected persistence_tag_mismatches=0
```

解释：

- baseline 没有观察到 MTE fault，也没有 StickyTags tag-cycle 机制通过记录。
- protected 版本观察到 680/680 个预期 fault。
- 同一测试矩阵下 protected 与 baseline 行为不同，说明 fault 行为来自 StickyTags 保护机制，而不是测试程序本身。

## 7. 与论文主张的对应关系

| 论文机制 | 本地证据 | 当前状态 |
|---|---|---|
| Size-class layout | heap/stack 多 size case 均有 stride/tag cycle 记录 | 已初步复现 |
| Deterministic round-robin tags | `unique_first16=16`, `repeat16=16` | 已初步复现 |
| Bounded spatial guard | slot 1-15 fault，slot 16 不 fault | 已初步复现 |
| Persistent memory tags | `persistence_tag_mismatches=0` | 已初步复现 |
| Heap + stack support | heap/stack 所有 suite 均通过 | 已初步复现 |
| Protected vs baseline difference | protected 版本 680 个 fault，baseline 版本 0 个 fault | 已初步复现 |
| SPEC performance overhead | 需要真实硬件和 SPEC 数据集 | 未复现 |
| Juliet/CVE 安全评估 | 需要真实样本、PoC 和 ground truth | 未复现 |
| Speculative probing | 需要真实 MTE 硬件侧信道环境 | 未复现 |

## 8. 结论

本阶段已经完成 StickyTags 的机制级初步复现：本地构建环境、AArch64 MTE VM、protected/baseline 二进制和完整机制测试矩阵均可运行，并且结果符合论文对 size-class persistent tag、round-robin tag 和 bounded spatial fault 行为的核心描述。

当前结果不能证明论文的完整性能结论、真实 CVE 缓解率或真实设备侧信道实验。后续若要扩展，可优先补充源码机制映射表、快速复现脚本，以及一个真实 CVE 的 baseline/ASan/StickyTags 三方对照样板。
