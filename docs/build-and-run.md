# 构建和运行流程

以下命令默认从仓库根目录运行。脚本已经根据自身位置定位 `Experiment/` 目录，因此仓库克隆到其他路径后，不需要再修改 `/mnt/f/...` 这类固定路径。

实验仍然依赖一个固定的 WSL 工作目录：

```bash
/home/brave/stickytags-lab
```

该目录用于保存上游 StickyTags 源码、LLVM 构建目录、QEMU 虚拟机镜像和 AArch64 构建产物。

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

结果文件：

- `Experiment/logs/stage6-functional-test-results.txt`

## 6. 运行 protected/baseline 功能对照

```bash
./Experiment/build-baseline-aarch64.sh
./Experiment/run-comparison-in-vm.sh
```

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
