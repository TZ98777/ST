# 构建和运行流程

以下命令默认从仓库根目录运行。脚本根据自身位置定位 `Experiment/` 目录，因此仓库可以克隆到任意路径。

## 0. 配置本地环境

主机侧默认配置保存在 `Experiment/lab-env.sh`。默认实验目录为：

```bash
$HOME/stickytags-lab
```

该目录用于保存上游 StickyTags 源码、LLVM 构建目录、QEMU 虚拟机镜像和 AArch64 构建产物。不同机器可以在当前 shell 中覆盖配置，不需要修改仓库文件：

```bash
export STICKYTAGS_LAB_ROOT="$HOME/stickytags-lab"
export STICKYTAGS_SSH_KEY="$HOME/.ssh/stickytags_vm_ed25519"
export STICKYTAGS_VM_HOST=127.0.0.1
export STICKYTAGS_VM_PORT=2222
export STICKYTAGS_VM_USER=brave
export STICKYTAGS_VM_WAIT_ATTEMPTS=180
export STICKYTAGS_VM_WAIT_INTERVAL=5
export STICKYTAGS_CASE_TIMEOUT=120
```

仓库不包含 QEMU 系统镜像、内核和 cloud-init 镜像。运行启动脚本前必须先准备 [虚拟机资产](vm-assets.md)。如果这些文件不存在，不能仅靠克隆仓库启动实验环境。

## 1. 准备上游源码

```bash
./Experiment/scripts/stage3-clone.sh
```

该步骤记录 StickyTags 上游源码和 submodule 版本。

## 2. 构建 LLVM 与 compiler-rt

```bash
./Experiment/configure-llvm.sh
./Experiment/build-llvm.sh
./Experiment/configure-compiler-rt-aarch64.sh
```

## 3. 构建修改版 TCMalloc

```bash
./Experiment/build-gperftools-aarch64.sh
./Experiment/validate-gperftools-aarch64.sh
```

## 4. 启动 MTE 虚拟机

```bash
./Experiment/start-mte-vm.sh
./Experiment/wait-for-mte-vm.sh
```

## 5. 运行功能测试

```bash
./Experiment/build-functional-tests-aarch64.sh
./Experiment/deploy-functional-tests.sh
./Experiment/run-functional-tests-in-vm.sh
```

该步骤包含三个合成用例和一个上游布局探针：正常访问、堆越界、栈越界以及 `test/test.c` 地址/tag 输出。布局探针按上游源码约定返回 1，不执行越界，也不作为防护效果证据。运行器会检查每个用例的退出状态和 MTE 专用故障类型，出现不符合预期的结果时返回失败。

结果文件：

- `Experiment/logs/stage6-functional-test-results.txt`

## 6. 运行 protected/baseline 功能对照

```bash
./Experiment/build-baseline-aarch64.sh
./Experiment/run-comparison-in-vm.sh 20
```

该脚本逐行断言：正常访问和未保护越界用例不产生 MTE fault，保护版本的堆、栈越界用例必须产生 MTE fault；普通 `SIGSEGV` 不能计作 MTE 检测成功。

结果文件：

- `Experiment/logs/stage7-comparison-results.csv`
- `Experiment/logs/stage7-comparison-summary.txt`

## 7. 运行核心机制验证实验

```bash
./Experiment/build-mechanism-tests-aarch64.sh
./Experiment/deploy-functional-tests.sh
./Experiment/run-mechanism-tests-in-vm.sh 5 20 1000
```

结果文件：

- `Experiment/logs/mechanism-test-results.txt`
- `Experiment/logs/mechanism-test-summary.txt`

## 8. 运行保护版本与未保护版本对照实验

```bash
./Experiment/run-protected-baseline-in-vm.sh 5 20 1000
```

结果文件：

- `Experiment/logs/protected-baseline-results.txt`
- `Experiment/logs/protected-baseline-summary.txt`

## 9. 停止虚拟机

```bash
./Experiment/stop-mte-vm.sh
```

## 结果解释

- `run-comparison-in-vm.sh` 是适合课堂演示的简短功能对照。
- `run-mechanism-tests-in-vm.sh` 验证保护版本的标签轮转、边界距离和持久标签。
- `run-protected-baseline-in-vm.sh` 运行完整合成矩阵，主要用于保留详细证据。
- MTE 16 字节粒度测试验证底层 MTE 语义，不应单独表述为 StickyTags 创新。
- 所有时间数据均来自 QEMU TCG，不可用于复现或比较论文的真实性能开销。
