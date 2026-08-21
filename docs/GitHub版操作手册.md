# GitHub版操作手册

本文面向从 GitHub 仓库获取本项目的使用者，说明如何演示 StickyTags 初步复现，包括运行环境、构建步骤、测试内容、结果判断和代码来源。所有命令默认在仓库根目录执行。

## 1. 演示目标和边界

本次演示需要证明：

1. 论文作者修改的 LLVM/SafeStack 和 TCMalloc 能在 AArch64 MTE 环境中构建并运行；
2. 正常的堆、栈访问不会被误报；
3. 未保护程序的合成堆、栈越界不会产生 MTE 标签故障；
4. StickyTags 保护程序执行相同越界时会产生 MTE 标签故障；
5. 保护程序表现出确定性的 16 标签轮转、有限距离空间保护和标签持久性。

本项目不演示论文中的 SPEC 性能结果、真实 Arm 手机、Juliet、真实 CVE 或侧信道实验。QEMU TCG 的运行时间不能用于评价 StickyTags 性能。

## 2. 哪些代码来自论文作者

论文作者的上游仓库和固定版本为：

```text
https://github.com/vusec/stickytags.git
db3ba2616ce0935fba6352192a43010ba9d3172a
```

当前复现使用了上游仓库中的：

- 修改版 `llvm-project`：其中的 LLVM/SafeStack 修改负责栈对象的尺寸分类、指针标签和持久标签布局；
- 修改版 `gperftools`/TCMalloc：负责堆对象的尺寸分类和持久标签布局；
- `test/test.c`：用于观察作者示例中的堆、栈地址及标签，不作为越界保护效果的主要证据；
- `test/run.sh` 和上游 README：作为原始构建、运行方式的参考。

上游源码没有复制进本仓库，而是保存在默认实验目录：

```text
$HOME/stickytags-lab/src/stickytags
```

准确版本见 `manifests/source-versions.txt`。

## 3. 哪些代码由当前复现项目设计

当前项目自行设计和编写了：

- `Experiment/tests/stickytags-functional.c`：正常访问、堆越界和栈越界功能测试；
- `Experiment/tests/stickytags-mechanism.c`：标签轮转、边界距离、持久性和 MTE 粒度测试；
- `Experiment/build-*.sh`：交叉编译保护版和未保护版测试程序；
- `Experiment/run-*.sh`：在虚拟机中运行用例并判断退出状态、MTE 故障和普通段错误；
- `Experiment/start-mte-vm.sh`、`wait-for-mte-vm.sh` 和 `stop-mte-vm.sh`：控制 QEMU MTE 虚拟机；
- 日志汇总、保护版/未保护版对照及实验报告。

因此，本项目没有从零重写 StickyTags 核心算法，而是构建论文作者的实现，并通过自行设计的测试进行独立验证。

## 4. 测试内容总览

| 测试 | 入口 | 主要内容 | 演示建议 |
|---|---|---|---|
| 功能测试 | `run-functional-tests-in-vm.sh` | 正常访问、上游布局探针、堆越界、栈越界 | 必须现场运行 |
| 快速功能对照 | `run-comparison-in-vm.sh` | 相同越界在保护版和未保护版中的差异 | 必须现场运行 |
| 核心机制测试 | `run-mechanism-tests-in-vm.sh` | 16 标签轮转、1 至 16 槽边界、持久性、MTE 粒度 | 可现场缩小运行，完整结果用归档说明 |
| 完整机制对照 | `run-protected-baseline-in-vm.sh` | 保护版 860 条加未保护版 860 条 | 不建议课堂现场运行 |

### 4.1 功能测试的四个用例

1. `normal`：合法访问必须正常退出，不产生 MTE 故障；
2. `upstream-layout-probe`：运行上游 `test/test.c`，只观察地址和标签；该程序按上游约定返回 1；
3. `heap-oob`：保护版堆越界必须产生 `SEGV_MTEAERR` 或 `SEGV_MTESERR`；
4. `stack-oob`：保护版栈越界必须产生 MTE 专用故障。

运行器同时检查退出状态、MTE 故障类型和普通 `SIGSEGV`。只有所有条件符合预期才输出 `PASS=1`。

### 4.2 快速功能对照

相同 C 程序分别编译为：

- `protected`：启用修改版 SafeStack、StickyTags TCMalloc 和 MTE；
- `baseline`：不启用 SafeStack，不链接 StickyTags TCMalloc。

正常访问在两个版本中都应成功。堆、栈越界在 baseline 中预期不产生 MTE 故障，在 protected 中预期产生 MTE 故障。

### 4.3 核心机制测试

- 标签轮转：堆、栈各检查 5 种对象尺寸，验证前 16 个标签不同且第 17 个开始重复；
- 边界距离：堆、栈各检查 4 种尺寸和第 1 至 16 个对象槽，第 1 至 15 槽预期故障，第 16 槽预期不故障；
- 标签持久性：堆、栈各检查 5 种尺寸，重复分配或重用栈帧后，同一地址的标签应保持一致；
- MTE 粒度：访问 10 字节逻辑对象的下标 9、10、15、16 和 32，说明 MTE 以 16 字节为检查粒度。

使用参数 `5 20 1000` 时，保护版共产生 860 条 `RESULT` 记录。完整保护版/未保护版对照共产生 1720 条记录。这些是参数组合和重复轮次，不是 860 或 1720 个真实漏洞。

## 5. 当前电脑的演示前检查

### 5.0 通用成功判断规则

在 WSL 中，每条命令运行结束后都可以立即执行：

```bash
echo $?
```

- 输出 `0`：该命令成功完成；
- 输出非 `0`：该命令失败，不能继续把后续结果解释为有效实验结果。

本文在关键命令后使用 `&& echo "..._SUCCESS"`。只有前面的命令返回 0，才会显示对应的成功标志。需要特别注意：堆、栈越界子程序返回 139 是预期的 MTE 故障，但负责判断结果的外层 `run-*.sh` 脚本最终仍必须返回 0。

### 5.1 进入 WSL 和仓库

在 Windows PowerShell 中运行：

```powershell
wsl -d StickyTagsLab
```

**成功标志：** PowerShell 进入 Linux shell，提示符变为类似 `brave@...`，且执行 `uname -m` 输出 `x86_64`。这里的 WSL 是构建和启动 QEMU 的主机，不是后面运行测试的 AArch64 客体。

**失败标志：** 出现“找不到分发版”“分发版未运行”或仍停留在 PowerShell 提示符。

进入 WSL 后运行：

```bash
cd /mnt/f/Paper/StickyTags/ST
git branch --show-current
git log -1 --oneline
```

**成功标志：** `cd` 没有报错，分支输出为 `main`，`git log` 能显示最新提交而不是 `fatal`。演示前不要执行会删除 `$HOME/stickytags-lab` 的命令。

### 5.2 检查虚拟机资产

```bash
source Experiment/lab-env.sh

test -f "$STICKYTAGS_LAB_ROOT/vm/boot/Image-6.8.0-137-generic" &&
test -f "$STICKYTAGS_LAB_ROOT/vm/boot/initrd.img-6.8.0-137-generic" &&
test -f "$STICKYTAGS_LAB_ROOT/vm/images/stickytags-arm64-overlay.qcow2" &&
test -f "$STICKYTAGS_LAB_ROOT/vm/cloud-init/seed.img" &&
test -f "$STICKYTAGS_SSH_KEY" &&
echo "VM_ASSETS_READY"
```

**成功标志：** 最后一行显示 `VM_ASSETS_READY`。

**失败标志：** 没有显示该标志，说明内核、initrd、磁盘镜像、cloud-init 镜像或 SSH 密钥至少缺少一项。

### 5.3 检查已经构建的工具链

```bash
test -x "$STICKYTAGS_LAB_ROOT/build/llvm-rel-gcc13/bin/clang" &&
test -f "$STICKYTAGS_LAB_ROOT/build/gperftools-aarch64-install/lib/libtcmalloc.so.4.5.10" &&
echo "TOOLCHAIN_READY"
```

**成功标志：** 最后一行显示 `TOOLCHAIN_READY`。

**失败标志：** 没有显示该标志，说明修改版 Clang 或 StickyTags TCMalloc 尚未准备好。教师演示前应提前完成完整 LLVM 和 TCMalloc 构建；现场重新编译整套 LLVM 耗时长，不增加核心机制演示价值。

## 6. 首次准备时的完整构建

只有工具链尚未构建时才运行本节。已经成功构建的当前电脑可直接进入第 7 节。

```bash
./Experiment/scripts/stage3-clone.sh && echo "SOURCE_READY"
./Experiment/configure-llvm.sh && echo "LLVM_CONFIGURED"
./Experiment/build-llvm.sh && echo "LLVM_BUILT"
./Experiment/configure-compiler-rt-aarch64.sh && echo "COMPILER_RT_CONFIGURED"
ninja -C "$STICKYTAGS_LAB_ROOT/build/compiler-rt-aarch64" \
    clang_rt.safestack-aarch64 && echo "SAFESTACK_RUNTIME_BUILT"
resource_dir=$("$STICKYTAGS_LAB_ROOT/build/llvm-rel-gcc13/bin/clang" \
    --print-resource-dir)
install -Dm644 \
    "$STICKYTAGS_LAB_ROOT/build/compiler-rt-aarch64/lib/linux/libclang_rt.safestack-aarch64.a" \
    "$resource_dir/lib/linux/libclang_rt.safestack-aarch64.a" && echo "SAFESTACK_RUNTIME_INSTALLED"
./Experiment/build-gperftools-aarch64.sh && echo "TCMALLOC_BUILT"
./Experiment/validate-gperftools-aarch64.sh && echo "TCMALLOC_VALIDATED"
```

各命令的成功含义如下：

| 成功标志 | 表示什么 |
|---|---|
| `SOURCE_READY` | 上游仓库获取完成，脚本最后应同时显示 `Stage 3 completed successfully.` |
| `LLVM_CONFIGURED` | CMake 配置成功并生成 LLVM Ninja 构建文件 |
| `LLVM_BUILT` | 修改版 Clang/LLVM 构建成功，日志中没有 `ninja: build stopped` |
| `COMPILER_RT_CONFIGURED` | AArch64 compiler-rt 配置成功 |
| `SAFESTACK_RUNTIME_BUILT` | `libclang_rt.safestack-aarch64.a` 构建成功；已经构建时可显示 `ninja: no work to do` |
| `SAFESTACK_RUNTIME_INSTALLED` | SafeStack运行库已放入修改版Clang的资源目录 |
| `TCMALLOC_BUILT` | 修改版TCMalloc及动态库构建、安装成功 |
| `TCMALLOC_VALIDATED` | TCMalloc验证脚本确认目标库可用于AArch64测试 |

可以进一步核对上游版本和关键产物：

```bash
git -C "$STICKYTAGS_LAB_ROOT/src/stickytags" rev-parse HEAD
"$STICKYTAGS_LAB_ROOT/build/llvm-rel-gcc13/bin/clang" --version
test -f "$resource_dir/lib/linux/libclang_rt.safestack-aarch64.a" &&
test -f "$STICKYTAGS_LAB_ROOT/build/gperftools-aarch64-install/lib/libtcmalloc.so.4.5.10" &&
echo "BUILD_OUTPUTS_VERIFIED"
```

第一条应输出 `db3ba2616ce0935fba6352192a43010ba9d3172a`，最后应显示 `BUILD_OUTPUTS_VERIFIED`。这一步构建的是论文作者修改版 LLVM/SafeStack 和 TCMalloc，不建议在课堂上从头执行。

## 7. 推荐的课堂演示流程

### 第一步：启动并等待 MTE 虚拟机

```bash
./Experiment/start-mte-vm.sh && echo "VM_PROCESS_STARTED"
./Experiment/wait-for-mte-vm.sh && echo "VM_SSH_READY"
```

启动脚本成功时应输出 QEMU PID 和控制台日志路径；如果虚拟机已经运行，则输出 `QEMU is already running`，也属于成功。等待脚本最终应输出：

```text
SSH_READY
VM_SSH_READY
```

**成功标准：** 同时看到 `VM_PROCESS_STARTED` 和 `VM_SSH_READY`。这表示 QEMU 进程已存在，并且客体 SSH 已可用。QEMU TCG 启动可能需要数分钟，必须等待 `SSH_READY` 后再继续。

**失败标准：** 输出 `SSH did not become ready`、QEMU启动错误，或没有出现 `VM_SSH_READY`。

### 第二步：构建测试程序

```bash
./Experiment/build-functional-tests-aarch64.sh && echo "FUNCTIONAL_BINARIES_BUILT"
./Experiment/build-baseline-aarch64.sh && echo "BASELINE_BINARY_BUILT"
./Experiment/build-mechanism-tests-aarch64.sh && echo "MECHANISM_BINARIES_BUILT"
```

这一步只重新编译测试程序，不会重新编译整套 LLVM。构建输出应显示：

- 目标架构是 AArch64；
- protected 程序包含 `__safestack_init`；
- protected 程序依赖 StickyTags TCMalloc；
- baseline 程序不包含 SafeStack，也不依赖 TCMalloc。

**成功标准：** 三个成功标志全部出现，并且构建输出满足上述四项。只有“编译命令没有报错”还不够，还应确认保护版和 baseline 的依赖确实不同。

**失败标准：** 出现链接错误、找不到SafeStack运行库、找不到TCMalloc，或任一成功标志缺失。

### 第三步：部署测试程序

```bash
./Experiment/deploy-functional-tests.sh && echo "TEST_BINARIES_DEPLOYED"
```

测试二进制和 TCMalloc 动态库将部署到虚拟机中的：

```text
/opt/stickytags/bin
/opt/stickytags/lib
```

**成功标准：** 输出中列出 `stickytags-functional`、`unprotected-functional`、`stickytags-mechanism`、`unprotected-mechanism` 和 `libtcmalloc.so`，`ldd` 没有显示 `not found`，最后显示 `TEST_BINARIES_DEPLOYED`。

**失败标准：** SSH或tar传输失败、`ldd`显示依赖缺失，或没有出现成功标志。

### 第四步：运行四个功能用例

```bash
./Experiment/run-functional-tests-in-vm.sh && echo "FUNCTIONAL_TESTS_SUCCESS"
```

讲解时重点指出：

- `normal`：`EXIT_STATUS=0`、`MTE_FAULT=0`、`PASS=1`；
- `upstream-layout-probe`：显示非零标签，按上游约定 `EXIT_STATUS=1`，但 `PASS=1`；
- `heap-oob`：`EXIT_STATUS=139`、`MTE_FAULT=1`、`PASS=1`；
- `stack-oob`：`EXIT_STATUS=139`、`MTE_FAULT=1`、`PASS=1`。

退出状态 139 本身不能证明 StickyTags 成功，必须同时看到 `kind=SEGV_MTEAERR` 或 `kind=SEGV_MTESERR`。

运行后可以统计通过用例：

```bash
awk '
    /^PASS=1$/ { passed++ }
    /^PASS=0$/ { failed++ }
    END { printf "passed=%d failed=%d\n", passed + 0, failed + 0 }
' "$STICKYTAGS_LAB_ROOT/logs/stage6-functional-test-results.txt"
```

**成功标准：** 显示 `FUNCTIONAL_TESTS_SUCCESS`，统计输出 `passed=4 failed=0`。

**失败标准：** 任一用例出现 `PASS=0`、protected越界没有MTE故障、正常访问异常退出，或外层脚本没有输出成功标志。

### 第五步：运行保护版/未保护版快速对照

课堂上建议每种越界重复 5 次：

```bash
./Experiment/run-comparison-in-vm.sh 5 && echo "QUICK_COMPARISON_SUCCESS"
```

需要展示的核心结论是：

```text
baseline,heap-oob: 0% MTE faults
baseline,stack-oob: 0% MTE faults
protected,heap-oob: 100% MTE faults
protected,stack-oob: 100% MTE faults
```

5轮运行产生22条数据记录：2条正常访问，加上2种越界、2个版本、每种5轮。可以检查：

```bash
awk -F, 'NR > 1 && $10 != 1 { failed++ } END { print failed + 0 }' \
    "$STICKYTAGS_LAB_ROOT/logs/stage7-comparison-results.csv"
```

**成功标准：** 显示 `QUICK_COMPARISON_SUCCESS`，汇总比例符合上表，检查命令输出 `0`。

**失败标准：** 任一CSV记录的 `pass` 不是1、baseline意外产生MTE故障、protected越界没有产生MTE故障，或出现普通段错误。

仓库归档结果使用了 20 轮。需要重现相同规模时运行：

```bash
./Experiment/run-comparison-in-vm.sh 20 && echo "COMPARISON_20_ROUNDS_SUCCESS"
```

20轮成功时共有82条数据记录，所有记录的 `pass` 均为1，最后显示 `COMPARISON_20_ROUNDS_SUCCESS`。

### 第六步：展示完整机制结果

课堂上优先展示已经归档的完整摘要：

```bash
cat results/summary/mechanism-test-summary.txt
cat results/summary/protected-baseline-summary.txt
```

讲解以下指标：

```text
机制测试：860/860 通过
预期 MTE 故障：680
观察到的 MTE 故障：680
普通意外 SIGSEGV：0
持久性迭代：10000
地址复用：9990
标签不一致：0
```

**成功标准：** `cat` 本身返回0只能说明文件存在；实验成功还必须看到各测试组通过率为100%、`expected_faults=680`、`observed_faults=680`、`unexpected_sigsegv=0` 和 `persistence_tag_mismatches=0`。完整对照摘要中不能有 `failed` 大于0。

**失败标准：** 文件不存在、预期与实际故障数不一致、出现意外普通段错误、标签不一致次数非0，或任何测试组存在失败记录。

### 第七步：关闭虚拟机

```bash
./Experiment/stop-mte-vm.sh && echo "VM_SHUTDOWN_SUCCESS"
```

**成功标准：** 输出 `QEMU_STOPPED` 或 `QEMU_ALREADY_STOPPED`，最后显示 `VM_SHUTDOWN_SUCCESS`。

**失败标准：** 输出 `QEMU_STILL_RUNNING`，或者没有显示成功标志。

## 8. 运行全部测试

如需在课前或课后重新执行所有测试，完成启动、构建和部署后运行：

```bash
# 四个基础功能用例
./Experiment/run-functional-tests-in-vm.sh && echo "ALL_FUNCTIONAL_CASES_PASSED"

# 20 轮快速功能对照，产生 82 条数据记录
./Experiment/run-comparison-in-vm.sh 20 && echo "ALL_QUICK_COMPARISONS_PASSED"

# 保护版完整机制测试，产生 860 条 RESULT 记录
./Experiment/run-mechanism-tests-in-vm.sh 5 20 1000 && echo "ALL_860_MECHANISM_RECORDS_PASSED"

# 保护版和未保护版完整对照，产生 1720 条 RESULT 记录
./Experiment/run-protected-baseline-in-vm.sh 5 20 1000 && echo "ALL_1720_COMPARISON_RECORDS_PASSED"
```

全部运行结束后检查记录数和失败数：

```bash
awk -F, '
    $1 == "RESULT" { records++ }
    /pass=0/ { failed++ }
    END { printf "mechanism_records=%d failed=%d\n", records + 0, failed + 0 }
' "$STICKYTAGS_LAB_ROOT/logs/mechanism-test-results.txt"

awk -F, '
    $1 == "RESULT" { records++ }
    /comparison_status=fail/ { failed++ }
    END { printf "comparison_records=%d failed=%d\n", records + 0, failed + 0 }
' "$STICKYTAGS_LAB_ROOT/logs/protected-baseline-results.txt"
```

**全部测试成功标准：** 四个成功标志全部出现；统计输出 `mechanism_records=860 failed=0` 和 `comparison_records=1720 failed=0`。机制摘要还应满足预期MTE故障680次、实际MTE故障680次、意外普通段错误0次、持久标签不一致0次。

**失败标准：** 任何成功标志缺失、记录数不足、失败数非0、脚本被状态137超时终止，或SSH中途断开。

完整矩阵在 QEMU TCG 中耗时较长，不应为了课堂演示重复运行。功能测试和快速对照负责现场证明，860/1720 条矩阵负责保留详细实验依据。

如需缩小机制测试用于现场说明，可运行：

```bash
./Experiment/run-mechanism-tests-in-vm.sh 1 1 20 && echo "REDUCED_MECHANISM_DEMO_SUCCESS"
```

**成功标准：** 显示 `REDUCED_MECHANISM_DEMO_SUCCESS`，摘要中四类机制均有记录、所有测试组通过率为100%、`unexpected_sigsegv=0`。该命令仍覆盖四类机制，但减少重复轮次；它只能作为现场缩小演示，不能替代仓库中使用标准参数生成的完整结果。

## 9. 日志位置

每次实际运行生成的日志位于：

```text
$STICKYTAGS_LAB_ROOT/logs
```

主要文件包括：

```text
stage6-functional-test-results.txt
stage7-comparison-results.csv
stage7-comparison-summary.txt
mechanism-test-results.txt
mechanism-test-summary.txt
protected-baseline-results.txt
protected-baseline-summary.txt
```

仓库中的 `Experiment/logs` 和 `results/summary` 是经过检查后保存的归档证据。运行脚本不会自动覆盖这些仓库文件。不要用课堂缩小测试结果覆盖完整归档结果。

可以检查本次运行日志是否实际生成：

```bash
ls -lh "$STICKYTAGS_LAB_ROOT/logs/"{stage6-functional-test-results.txt,stage7-comparison-results.csv,mechanism-test-results.txt,protected-baseline-results.txt}
```

**成功标志：** `ls`列出所需文件且文件大小非0。文件存在只证明日志已生成，最终仍要按照第7、8节检查其中的通过率和失败数。

## 10. 如何向老师解释结果

建议按以下顺序说明：

1. StickyTags 核心实现来自论文作者修改的 LLVM/SafeStack 和 TCMalloc；
2. 当前项目负责在 QEMU MTE 环境中构建它，并自行设计验证程序；
3. 作者原始 `test/test.c` 只用于观察标签布局；
4. 自编功能测试用相同越界分别测试 protected 和 baseline；
5. protected 产生 MTE 专用故障，而 baseline 不产生，说明差异来自 StickyTags 配置；
6. 完整机制测试进一步验证 16 标签轮转、第 1 至 15 槽保护、第 16 槽标签重复和地址复用标签持久性；
7. 结论是核心机制初步复现成功，不是论文全部性能和安全实验的完整复现。

## 11. 常见问题

### SSH 长时间未就绪

查看虚拟机控制台：

```bash
source Experiment/lab-env.sh
tail -n 80 "$STICKYTAGS_LAB_ROOT/logs/qemu-mte-console.log"
```

不要在 QEMU 仍启动时重复执行启动脚本。`start-mte-vm.sh` 会在 PID 有效时提示已经运行。

### 用例退出状态为 137

137 通常表示用例被超时强制终止，不表示发现了 MTE 故障。可以增加单用例超时后重新运行：

```bash
export STICKYTAGS_CASE_TIMEOUT=180
```

### 只看到普通 segmentation fault

普通段错误不能算作 StickyTags 检测成功。必须在测试输出中确认：

```text
kind=SEGV_MTEAERR
```

或：

```text
kind=SEGV_MTESERR
```

### 为什么不现场跑 1720 条

1720 条是同一套 860 条参数矩阵分别运行 protected 和 baseline 的完整回归。它增强证据覆盖，但不会引入新的核心功能。课堂现场运行四个功能用例和快速对照，再展示完整摘要，更清晰也更节省时间。
