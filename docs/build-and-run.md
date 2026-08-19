# 构建和运行流程

以下命令基于原始实验路径记录：

```bash
/mnt/f/Paper/StickyTags/Experiment
/home/brave/stickytags-lab
```

如果同学把仓库克隆到其他位置，需要相应修改脚本中的路径，或后续把脚本改造成从当前仓库路径自动推导。

## 1. 准备上游源码

```bash
/mnt/f/Paper/StickyTags/Experiment/scripts/stage3-clone.sh
```

该步骤记录 StickyTags 上游源码和 submodule 版本。

## 2. 构建 LLVM 与 compiler-rt

```bash
/mnt/f/Paper/StickyTags/Experiment/configure-llvm.sh
/mnt/f/Paper/StickyTags/Experiment/build-llvm.sh
/mnt/f/Paper/StickyTags/Experiment/configure-compiler-rt-aarch64.sh
```

## 3. 构建修改版 TCMalloc

```bash
/mnt/f/Paper/StickyTags/Experiment/build-gperftools-aarch64.sh
/mnt/f/Paper/StickyTags/Experiment/validate-gperftools-aarch64.sh
```

## 4. 启动 MTE 虚拟机

```bash
/mnt/f/Paper/StickyTags/Experiment/start-mte-vm.sh
/mnt/f/Paper/StickyTags/Experiment/wait-for-mte-vm.sh
```

## 5. 运行功能测试

```bash
/mnt/f/Paper/StickyTags/Experiment/build-functional-tests-aarch64.sh
/mnt/f/Paper/StickyTags/Experiment/deploy-functional-tests.sh
/mnt/f/Paper/StickyTags/Experiment/run-functional-tests-in-vm.sh
```

结果文件：

- `Experiment/logs/stage6-functional-test-results.txt`

## 6. 运行 protected/baseline 对照

```bash
/mnt/f/Paper/StickyTags/Experiment/build-baseline-aarch64.sh
/mnt/f/Paper/StickyTags/Experiment/run-comparison-in-vm.sh
```

结果文件：

- `Experiment/logs/stage7-comparison-results.csv`
- `Experiment/logs/stage7-comparison-summary.txt`

## 7. 运行 Level 2 机制测试

```bash
/mnt/f/Paper/StickyTags/Experiment/build-level2-aarch64.sh
/mnt/f/Paper/StickyTags/Experiment/deploy-functional-tests.sh
/mnt/f/Paper/StickyTags/Experiment/run-level2-in-vm.sh 5 20 1000
```

结果文件：

- `Experiment/logs/stage8-level2-results.txt`
- `Experiment/logs/stage8-level2-summary.txt`

## 8. 运行 Level 3A 对照测试

```bash
/mnt/f/Paper/StickyTags/Experiment/run-level3a-in-vm.sh 5 20 1000
```

结果文件：

- `Experiment/logs/stage9-level3a-results.txt`
- `Experiment/logs/stage9-level3a-summary.txt`
