# StickyTags 复现工作总结

日期：2026-08-19

## 1. 一句话结论

我目前完成的是 StickyTags 的“核心机制复现”，不是完整论文复现。

简单说，我已经在本机搭好了一个可以模拟 ARM MTE 的 AArch64 虚拟机，编译了 StickyTags 修改过的 LLVM/Clang、SafeStack 运行库和 TCMalloc，并写了测试程序去验证：受保护程序在发生堆和栈的相邻越界访问时会触发 MTE 标签错误，而普通未保护程序不会触发；同时，标签轮转和持久标签这两个核心设计已经表现出来，MTE 16 字节粒度也通过辅助测试得到确认。

还没有完成的是论文中的大规模性能评测、Juliet 测试集、真实 CVE 复现、真实 ARM 设备侧信道实验和完整内存开销测量。因此当前结果只能说明“机制跑通了”，不能说“论文所有实验都复现了”。

## 2. 论文主要讲了什么

论文《Sticky Tags: Efficient and Deterministic Spatial Memory Error Mitigation using Persistent Memory Tags》研究的是 C/C++ 程序中的空间内存错误，例如 buffer overflow、out-of-bounds read/write。

ARM MTE 可以给“指针”和“内存”都加一个 4 bit 的标签。程序访问内存时，硬件会检查：

```text
指针标签 == 内存标签  -> 允许访问
指针标签 != 内存标签  -> 触发 MTE fault
```

传统 MTE 方案常常在对象分配和释放时反复给内存重新打标签，这会带来较高运行时开销；同时随机标签只有概率保护，攻击者如果猜中或探测到标签，仍可能绕过。

StickyTags 的核心想法是：

- 把 heap 和 stack 按对象大小划分为不同 size class 区域；
- 每个区域里的 slot 按固定顺序使用标签 `0, 1, 2, ..., 15, 0, 1, ...`；
- 内存标签“粘”在内存 slot 上，释放对象后也不立刻改变；
- 新对象进入同一个 slot 时，根据地址计算出应该使用的指针标签；
- 这样可以减少反复 retag memory 的成本，并让每个对象周围最近 15 个 slot 都有不同标签，形成隐式空间保护区。

论文自己的主要结论是：在真实 ARM MTE 设备上，StickyTags 在 SPEC CPU2006 中报告约 `4.0%` 的 heap+stack 运行时开销，低于 MemTagSanitizer+Scudo 的 `20.2%`；同时论文称对评估的 8 个 spatial CVE 中有 7 个可以完全缓解。论文也承认它不是完整内存安全方案，默认不解决 Use-After-Free，且有约 `15.7%` RSS 内存开销。

## 3. 我实际完成了什么

### 3.1 搭建了可重复的实验环境

实验不是直接在 Windows 上跑 ARM 程序，而是采用下面的结构：

```text
Windows 11 x86_64 主机
└── WSL2 Ubuntu 实验环境
    └── QEMU AArch64 虚拟机，开启 MTE 模拟
```

具体做法：

- 在 WSL2 中创建了专用发行版 `StickyTagsLab`，避免污染原来的 Ubuntu 环境；
- 下载并校验 Ubuntu ARM64 cloud image；
- 把基础镜像设为只读；
- 创建 30 GiB 的 QCOW2 overlay 作为可写增量磁盘；
- 使用 QEMU 直接加载 ARM64 kernel/initrd 启动虚拟机；
- 使用 SSH 连接虚拟机，入口是 `127.0.0.1:2222`；
- 在虚拟机内启用 `vm.unprivileged_userfaultfd=1`，因为 StickyTags 需要通过 userfaultfd 在页面第一次访问时初始化持久标签。

这一步的意义是：实验系统可以反复启动、回滚和重建；基础镜像不会被破坏。

验证结果显示：

- 虚拟机架构是 `aarch64`；
- Linux kernel 是 `6.8.0-137-generic`；
- CPU features 包含 `mte` 和 `mte3`；
- `HWCAP2_MTE=yes`；
- `mmap(PROT_MTE)=ok`；
- `PR_SET_TAGGED_ADDR_CTRL=ok`；
- `userfaultfd` 已开启。

### 3.2 编译了 StickyTags 所需组件

我使用的是作者公开仓库 `https://github.com/vusec/stickytags.git`，记录的主仓库 commit 为：

```text
db3ba2616ce0935fba6352192a43010ba9d3172a
```

子模块 `spectre-mte` commit 为：

```text
9623aa8a6c5ca7cec937faefcea72981beee8c09
```

编译出的关键组件包括：

- 修改版 LLVM/Clang，用来把 C 程序编译成 AArch64 程序，并插入 StickyTags/SafeStack 相关逻辑；
- compiler-rt 中的 SafeStack runtime；
- 修改版 gperftools/TCMalloc，用来提供 StickyTags 的 heap allocator；
- protected 测试程序，即带 StickyTags 保护的程序；
- baseline 测试程序，即不带 StickyTags 保护的普通对照程序。

构建 protected 程序时使用了这些关键编译选项：

```text
--target=aarch64-linux-gnu
-march=armv8.5-a+memtag
-fsanitize=safe-stack
-flto=full
-fuse-ld=lld
-fno-builtin-malloc
-ltcmalloc
```

构建后检查确认：

- protected 程序是 AArch64 ELF 可执行文件；
- protected 程序依赖 `libtcmalloc.so.4`；
- protected 程序包含 `__safestack_init` 符号；
- baseline 程序不依赖 TCMalloc；
- baseline 程序没有 SafeStack 符号。

这说明 protected 和 baseline 的差异不是口头假设，而是通过二进制依赖和符号检查确认过。

## 4. 我使用了哪些程序进行测试

### 4.1 `mte-probe.c`：确认虚拟机真的支持 MTE

这个程序的作用是检查环境本身是否有能力运行 MTE 实验。

它做了三件事：

1. 读取 `AT_HWCAP2`，确认硬件能力位中包含 MTE；
2. 调用 `mmap(..., PROT_MTE, ...)`，确认可以申请带 MTE 属性的内存；
3. 调用 `prctl(PR_SET_TAGGED_ADDR_CTRL, ...)`，确认当前进程可以启用 tagged pointer 和 MTE 检查模式。

结果：

```text
HWCAP2_MTE=yes
mmap_PROT_MTE=ok
PR_SET_TAGGED_ADDR_CTRL=ok
```

这说明后续测试有基础条件，不是在普通 ARM 环境里假跑。

### 4.2 `toolchain-smoke.c`：确认编译器能生成 AArch64 + SafeStack 程序

这是一个最小程序，只输出：

```text
StickyTags toolchain smoke test: OK
```

它本身不测试安全性，作用是验证修改版 Clang 能完成交叉编译，并且生成的目标文件和最终程序确实是 AArch64 格式。

验证结果：

- 生成的 object 文件是 `ELF64`；
- 目标架构是 `AArch64`；
- 生成的 SafeStack 可执行文件包含 `__safestack_init`。

### 4.3 `repository-test`：确认原仓库测试能输出带 tag 地址

原仓库自带的 `test/run.sh` 写死了旧路径，不能直接原样运行。我的处理方式是：用当前已经搭好的修改版工具链重新编译原仓库中的 `test/test.c`，生成 AArch64 可执行程序 `repository-test`，再通过 SSH 放到虚拟机里运行。

运行方式是：

```text
ssh -i /home/brave/.ssh/stickytags_vm_ed25519 -p 2222 brave@127.0.0.1 \
  /opt/stickytags/bin/repository-test 1 2 3 4
```

代表输出：

```text
ptr0 0xaf6587024000 ptr1 0x100af6587024030 ptr2 0x200af6587024060
buf16 0xf00af65867fffc0 buf15 0xe00af65867fff80 buf14 0xf00af6586ffff80
```

这些地址的最高字节中出现了不同 tag，说明原仓库测试程序中的 heap 和 stack 指针都已经带有 top-byte tag。该程序只输出布局，源码最后主动返回 1，并没有真正执行越界访问，所以它只能作为布局探针，不能作为保护效果证据。

### 4.4 `stickytags-functional.c`：最小功能测试

这是第一组真正观察保护效果的测试程序。它包含三种运行模式：

```text
normal
heap-oob
stack-oob
```

它的测试方法是：

- 在 heap 上申请两个 32 字节对象；
- 在 stack 上创建两个 32 字节数组；
- 打印它们的地址和 top-byte tag；
- 正常访问时只访问对象边界内；
- heap 越界时写 `first[32]`，也就是越过第一个 32 字节对象；
- stack 越界时通过相邻栈数组构造越界写；
- 安装 `SIGSEGV` handler，用来识别是否出现 `SEGV_MTEAERR` 或 `SEGV_MTESERR`。

代表结果：

普通访问：

```text
normal accesses completed
EXIT_STATUS=0
```

protected heap 越界：

```text
caught SIGSEGV: si_code=8 kind=SEGV_MTEAERR
EXIT_STATUS=139
```

protected stack 越界：

```text
caught SIGSEGV: si_code=8 kind=SEGV_MTEAERR
EXIT_STATUS=139
```

baseline 对照结果：

```text
baseline heap-oob: 20 次运行，0 次 MTE fault
baseline stack-oob: 20 次运行，0 次 MTE fault
protected heap-oob: 20 次运行，20 次 MTE fault
protected stack-oob: 20 次运行，20 次 MTE fault
```

这说明相同的越界访问，在普通程序里没有被 MTE 拦下，在 StickyTags protected 程序里被拦下。

### 4.5 综合机制测试程序：验证标签轮转、边界、持久性和 MTE 粒度

综合机制测试程序保存在实验测试源码目录中，作用是把三个 StickyTags 核心现象拆成可重复运行的小测试：标签轮转、空间边界和持久标签；此外还增加 MTE 16 字节粒度辅助测试，用于确认底层硬件语义。

这个程序做了四类测试。

第一类是标签轮转测试。

它分别在 heap 和 stack 上创建 32 个相邻对象，测试大小包括：

```text
16, 32, 64, 128, 256 bytes
```

然后读取每个对象指针高位里的 tag，检查：

- 前 16 个对象是否正好出现 16 个不同 tag；
- 相邻对象 tag 是否不同；
- 第 17 个对象是否和第 1 个对象 tag 相同；
- 对象地址间隔是否符合 size class 的固定步长。

结果：

```text
heap: 5/5 通过
stack: 5/5 通过
unique_first16=16
repeat16=16
```

这对应论文里的 round-robin tag pattern。

第二类是空间边界测试。

它选择一个对象作为起点，然后把访问目标移动到后面第 1 到第 16 个 slot。

预期是：

```text
slot 1-15: tag 不同，应触发 MTE fault
slot 16: tag 循环回同一个值，不应触发 MTE fault
```

实际统计：

```text
slot 1-15: 每个 slot 40 次，全部触发 MTE fault
slot 16: 40 次，全部不触发 MTE fault
```

这说明 StickyTags 的保护是“有界”的：最近 15 个 slot 有确定保护，但第 16 个 slot 因为 4 bit tag 循环，标签会重新相同。

第三类是持久标签测试。

它反复分配、释放和复用对象地址，观察同一个底层地址再次被使用时 tag 是否保持稳定。

结果：

```text
persistence_iterations=10000
persistence_reuses=9990
persistence_tag_mismatches=0
```

这说明同一个 slot 被复用时，tag 没有因为对象生命周期变化而重新随机生成，符合 persistent memory tag 的思想。

该结果验证的是固定空间布局和减少重复 retag 的设计，不代表 Use-After-Free 防护。论文明确将 temporal errors 排除在 StickyTags 的范围外。

第四类是 MTE 16 字节粒度测试。

这一项验证的是 Arm MTE 自身的标签粒度，不是 StickyTags 单独提出的保护机制。

测试逻辑是：申请一个逻辑上 10 字节的对象，然后访问不同下标：

```text
index 9, 10, 15: 不触发 fault
index 16, 32: 触发 fault
```

原因是 MTE 的最小标签粒度是 16 字节。访问 10 或 15 虽然从 C 语言对象大小看可能已经越界，但仍在同一个 16 字节 MTE 粒度内，所以不会触发标签不匹配；访问 16 或 32 进入下一个 MTE 粒度，才会触发 fault。

实际统计：

```text
index 9: 40 次，0 次 MTE fault
index 10: 40 次，0 次 MTE fault
index 15: 40 次，0 次 MTE fault
index 16: 40 次，40 次 MTE fault
index 32: 40 次，40 次 MTE fault
```

这说明测试结果符合 MTE 16 字节 granularity 的硬件语义。

## 5. 测试是如何运行的

测试不是直接在 Windows 上运行，而是由 WSL2 主机侧脚本通过 SSH 进入 AArch64 虚拟机运行。

整体流程是：

```text
1. 在 WSL2 中编译 AArch64 测试程序
2. 把 protected/baseline 二进制和 libtcmalloc 部署到虚拟机 /opt/stickytags
3. 主机脚本通过 ssh -p 2222 进入虚拟机
4. 在虚拟机中运行 guest-side 测试脚本
5. 把每次运行结果写入 raw log
6. 再用 awk 汇总成 summary
```

使用过的主要脚本包括：

```text
start-mte-vm.sh
wait-for-mte-vm.sh
deploy-functional-tests.sh
build-functional-tests-aarch64.sh
run-functional-tests-in-vm.sh
run-comparison-in-vm.sh
summarize-comparison.sh
```

此外还有用于构建和运行综合机制测试、运行 protected/baseline 全矩阵对照的脚本。从报告角度看，它们分别承担“构建综合测试”“运行综合测试”“运行 protected/baseline 对照测试”和“汇总结果”的作用。

## 6. 当前测试结果汇总

### 6.1 最小功能对照

| 测试对象 | baseline 结果 | protected 结果 | 说明 |
|---|---:|---:|---|
| 正常访问 | 0 次 fault | 0 次 fault | 正常访问不应报错 |
| heap 越界 | 20 次运行，0 次 fault | 20 次运行，20 次 fault | StickyTags 拦下 heap 相邻越界 |
| stack 越界 | 20 次运行，0 次 fault | 20 次运行，20 次 fault | StickyTags 拦下 stack 相邻越界 |

### 6.2 综合机制测试

| 测试内容 | heap 结果 | stack 结果 | 说明 |
|---|---:|---:|---|
| 标签轮转 | 5/5 通过 | 5/5 通过 | 16 个 tag 按固定顺序循环 |
| 空间边界 | 320/320 通过 | 320/320 通过 | slot 1-15 fault，slot 16 不 fault |
| 持久标签 | 5/5 通过 | 5/5 通过 | 复用地址时 tag 不变 |
| 16 字节粒度 | 100/100 通过 | 100/100 通过 | 符合 MTE granularity |

关键总数：

```text
cycle_objects=320
persistence_iterations=10000
persistence_reuses=9990
persistence_tag_mismatches=0
fault_cases=840
expected_faults=680
observed_faults=680
unexpected_sigsegv=0
```

### 6.3 protected 与 baseline 的完整对照

同一套测试矩阵分别在 protected 和 baseline 上运行。

关键结果：

```text
protected expected_faults=680
protected observed_faults=680
protected unexpected_sigsegv=0
protected cycle_mechanism_passes=10
protected persistence_tag_mismatches=0

baseline expected_faults=0
baseline observed_faults=0
baseline unexpected_sigsegv=0
baseline cycle_mechanism_passes=0
baseline layout_unavailable=400
baseline skipped_layout_cases=400
```

解释：

- protected 的 680 个预期 MTE fault 全部由 `SEGV_MTEAERR`（`si_code=8`）确认，普通段错误为 0；
- baseline 没有 MTE fault，符合“普通程序没有 StickyTags 保护”的预期；
- baseline 没有出现 StickyTags 的 16-tag 机制通过记录；
- baseline 有 400 条布局不可用记录，说明它没有 StickyTags 的 size-class/tag layout；这些用例现在记为 `SKIP`，不再算作“通过”；
- 因此，故障差异来自 protected 程序中的 StickyTags 机制，而不是测试程序本身。

## 7. 当前结果能说明什么

当前结果可以说明：

- 实验环境确实支持 AArch64 MTE 模拟；
- 修改版 Clang/LLVM 能生成 AArch64 + SafeStack 程序；
- 修改版 TCMalloc 能被 protected 程序加载；
- protected 程序中的 heap 指针和 stack 指针都带 top-byte tag；
- heap 和 stack 的相邻对象 tag 不同；
- 相邻越界访问会因为 tag mismatch 触发 MTE fault；
- tag 按 16 个一轮循环，slot 16 不再被保护；
- 同一地址复用时 tag 保持稳定；
- protected 和 baseline 在相同输入下表现不同。

换句话说，我已经复现了论文 StickyTags 设计中最重要的几个机制现象：

```text
size-class layout
persistent memory tags
deterministic round-robin tags
bounded spatial guard
heap + stack support
protected vs baseline difference
```

## 8. 当前结果不能说明什么

当前结果不能说明：

- 不能证明论文中的 `4.0%` SPEC CPU2006 运行时开销；
- 不能证明论文中的 `15.7%` RSS 内存开销；
- 不能证明论文中 Juliet 测试集的检测率和缓解率；
- 不能证明真实 CVE 的 7/8 完整缓解结论；
- 不能证明真实 Pixel 8 Pro 或 Samsung Galaxy S22 上的表现；
- 不能复现论文的 speculative probing 侧信道攻击；
- 不能证明 StickyTags 是完整 memory safety 方案；
- Use-After-Free 属于论文明确排除的 temporal error，不应把持久标签结果解释为 UAF 防护。

最重要的限制是：本实验使用 QEMU TCG 模拟 ARM MTE，不是真实 ARM MTE 硬件。QEMU 可以用来验证功能逻辑，但运行时间包含跨架构模拟成本，不能拿来和论文的真机性能数字直接比较。

## 9. 还需要改善什么

后续可以优先改善以下内容。

第一，补充真实 benchmark 或至少做一个清楚的本地性能对照。

当前只做了功能和机制验证，没有测性能。若要靠近论文，需要运行 SPEC CPU2006/2017 或选择一个可获得的替代 benchmark，并明确说明 QEMU 结果只能比较趋势，不能对应论文真机百分比。

第二，补充真实漏洞样本。

现在的越界程序是自己写的合成测试，能说明机制，但不等于真实漏洞复现。可以选择一个较小的公开 spatial CVE，做 baseline、ASan、StickyTags 三方对照。

第三，补充 Juliet 测试集。

论文用 Juliet 说明 detected 和 mitigated 的区别。当前没有跑 Juliet，因此报告里不能复用论文的 Juliet 结论作为自己的实验结果。

第四，补充源码机制映射。

可以把论文中的四个组件对应到代码位置：

```text
LLVM/SafeStack pass -> stack 对象重定向和 pointer tag 计算
TCMalloc -> heap size class 和 region metadata
userfaultfd handler -> 页面首次访问时初始化 memory tag
MTE instructions -> STG/LDG/IRG 等底层标签操作
```

第五，整理脚本命名和一键复跑流程。

现有脚本能跑，但文件名包含实验过程中的临时阶段命名。后续可以增加一个更清楚的入口，例如：

```text
run-all-functional-reproduction.sh
run-protected-baseline-comparison.sh
run-mechanism-tests.sh
```

第六，补充图表。

可以把当前结果画成三张图：

- protected vs baseline 的 heap/stack fault 对照图；
- slot 1-16 的 fault 分布图；
- tag 0-15 round-robin 循环示意图。

这些图比单纯贴日志更适合给不懂实现细节的人看。

第七，明确记录清理过的文件和当前源码状态。

之前已经删除了无复现价值或可再生成的 gperftools 备份和安装目录。后续如果要提交或交作业，应确认源码目录、实验脚本目录和报告目录的边界，避免把大体积构建产物或备份目录当作源代码提交。

## 10. 使用的软件和版本

### 主机与 WSL2

| 项目 | 版本或配置 |
|---|---|
| 电脑 | ASUS TUF Gaming F15 FX507ZM |
| CPU | Intel Core i7-12700H |
| 主机系统 | Windows 11 Home |
| Windows 版本 | 10.0.26200, Build 26200 |
| 主机架构 | x64 |
| WSL | WSL2 |
| WSL 专用发行版 | `StickyTagsLab` |
| WSL 用户 | `brave` |
| WSL 可见内存 | 约 7.6 GiB |
| WSL swap | 2.0 GiB |

### WSL2 工具链

| 工具 | 版本 |
|---|---|
| Git | 2.53.0 |
| CMake | 4.2.3 |
| Ninja | 1.13.2 |
| Ubuntu clang | 21.1.8 |
| QEMU | 10.2.1 |
| AArch64 GCC | 15.2.0 |

### StickyTags 源码和修改版工具链

| 项目 | 版本或记录 |
|---|---|
| StickyTags 仓库 | `https://github.com/vusec/stickytags.git` |
| StickyTags commit | `db3ba2616ce0935fba6352192a43010ba9d3172a` |
| `spectre-mte` commit | `9623aa8a6c5ca7cec937faefcea72981beee8c09` |
| 修改版 Clang | 16.0.0 |
| LLD | 16.0.0 |
| TCMalloc library | `libtcmalloc.so.4.5.10` |

### AArch64 MTE 虚拟机

| 项目 | 版本或配置 |
|---|---|
| 虚拟机架构 | AArch64 |
| 虚拟机系统 | Ubuntu 24.04 ARM64 cloud image |
| Guest kernel | Linux 6.8.0-137-generic |
| QEMU machine | `virt,mte=on` |
| QEMU CPU | `max` |
| QEMU accelerator | `tcg,thread=multi` |
| QEMU vCPU | 2 |
| QEMU memory | 2048 MiB |
| SSH 入口 | `127.0.0.1:2222` |
| Page size | 4096 bytes |
| CPU features | 包含 `mte`, `mte3` |
| userfaultfd | `vm.unprivileged_userfaultfd=1` |

## 11. 最后结论

这次复现已经达到了“让 StickyTags 核心机制在本地跑起来并用对照测试证明”的程度。最关键的证据是：同一个测试程序，普通 baseline 不触发 MTE fault，而 protected 版本在 heap 和 stack 的有界越界访问中触发了预期 fault；同时标签轮转、持久标签和 slot 1-15 保护范围都被原始日志验证，MTE 16 字节粒度则作为底层语义得到辅助确认。

下一步如果要把它提升到更完整的论文复现，需要从“机制正确”扩展到“真实工作负载、真实漏洞和性能数据”。尤其要补充 SPEC 或替代 benchmark、Juliet 或真实 CVE、内存开销测量，以及真实 ARM MTE 设备上的验证。
