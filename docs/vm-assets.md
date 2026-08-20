# 虚拟机资产要求

QEMU AArch64 系统镜像、Linux 内核和 cloud-init 镜像体积较大，目前没有提交到 Git 仓库。`Experiment/start-mte-vm.sh` 只负责启动已经准备好的虚拟机，不负责下载或创建这些文件。

默认实验目录为 `$HOME/stickytags-lab`。启动脚本要求以下文件存在：

```text
$STICKYTAGS_LAB_ROOT/
└── vm/
    ├── boot/
    │   ├── Image-6.8.0-137-generic
    │   └── initrd.img-6.8.0-137-generic
    ├── images/
    │   └── stickytags-arm64-overlay.qcow2
    └── cloud-init/
        └── seed.img
```

客体系统还需要满足以下条件：

- AArch64 Linux 内核和用户空间；
- 内核支持 Arm MTE、tagged address control 和 `userfaultfd`；
- SSH 服务可用，默认用户为 `brave`；
- 该用户能够通过 `sudo` 设置 `vm.unprivileged_userfaultfd=1`；
- 默认 SSH 转发地址为 `127.0.0.1:2222`。

可以在运行前覆盖主机侧配置：

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

当前仓库尚未提供从空白镜像自动创建该客体系统的脚本。因此，其他协作者要完整复跑实验，需要单独获得兼容的虚拟机资产，或者自行创建满足上述条件的 AArch64 MTE 客体。这个限制不影响阅读已有源码、日志和报告，但影响从零重建实验环境。
