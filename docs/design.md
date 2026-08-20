# 完整设计思路

## 论文方法理解

StickyTags 面向 C/C++ 程序中的有界空间越界访问。传统随机标记方案可能让相邻对象获得相同标签；MTE 只有 4 位标签，攻击者还可能通过反复尝试或侧信道获知标签。因此，这类方案只能为跨对象访问提供概率检测。

StickyTags 的核心思想是把对象标签设计成可预测但持久的布局属性，而不是一次性随机属性。内存按 size class 划分区域，同一区域中的对象槽按照固定的 16 标签周期分配标签，同一槽位被再次复用时保持相同标签。这样可以让跨入前后 15 个对象槽的访问稳定触发标签不匹配，隐式保护范围为 `15 × size_class` 字节。第 16 个对象槽会重新使用相同标签，因此保护是有界的。

持久标签的目的主要是减少重复内存标记开销并维持确定性的空间布局。StickyTags 不提供 temporal safety；论文明确把 use-after-free 等时间错误排除在范围外。

## 堆保护思路

堆对象由修改版 TCMalloc 管理。分配器按照 size class 管理对象区域，并让同一 size class 内相邻对象遵循 16 标签循环。访问指针携带逻辑标签，内存本身带有分配标签；当越界访问落入相邻对象且标签不同，Arm MTE 会产生 fault。

本复现通过 protected 与 baseline 两类二进制对比：

- protected：使用修改版 StickyTags LLVM/SafeStack、`-fsanitize=safe-stack`、AArch64 MTE 编译参数和修改版 TCMalloc。
- baseline：普通 AArch64 程序，不链接 StickyTags TCMalloc，也不启用 SafeStack。

## 栈保护思路

栈保护依赖修改版 LLVM SafeStack。编译器把需要保护的栈对象放入可标记区域，并按照 StickyTags 的标签策略管理栈对象标签。复现实验中分别构造堆对象和栈对象的越界访问，验证二者都能触发 MTE fault。

## 持久标签思路

StickyTags 的“sticky”体现在标签与地址布局绑定，而不是每次分配重新随机化。复现实验反复申请、释放并复用同一地址，检查复用地址的标签是否稳定。结果中 `persistence_tag_mismatches=0` 表示在测试范围内没有观察到复用地址标签变化。

需要注意：baseline 中标签全为 0，因此 baseline 的持久性结果本身不代表 StickyTags 机制存在；必须结合 protected 版本的 16 标签轮转结果一起解释。标签在地址复用时保持不变也意味着旧指针可能继续匹配该槽位，所以该结果不能作为 UAF 检测证据。

## 本项目复现路线

1. 在 Windows + WSL2 中准备构建环境。
2. 使用 QEMU AArch64 TCG 启动支持 MTE 的 Linux guest。
3. 构建 StickyTags 修改版 LLVM/Clang、compiler-rt 和 gperftools/TCMalloc。
4. 编译 protected 与 baseline 两组测试程序。
5. 在 AArch64 guest 中运行堆/栈越界、标签轮转、边界距离、标签持久性和 MTE 粒度测试。
6. 汇总日志，比较 protected 与 baseline 的 fault 行为和标签布局行为。
