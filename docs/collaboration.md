# 协作建议

建议把后续工作拆成四类：

1. 报告撰写

   负责整理 `Report/`，把设计思路、实验步骤、实验结果、局限性写成正式实验报告。

2. 运行流程维护

   负责维护 `docs/build-and-run.md` 和 `Experiment/*.sh`，让同学能够按步骤复跑实验。后续重点是把脚本中的固定路径改成可配置路径。

3. 测试数据和结果整理

   负责维护 `docs/experiment-design.md`、`Experiment/tests/`、`Experiment/logs/` 和 `results/summary/`，把原始日志整理成表格、图和结论。

4. 复现边界说明

   负责维护 `docs/limitations.md`，明确哪些内容已经完成，哪些内容只是机制验证，哪些内容没有复现。

## Git 工作方式

建议使用分支协作：

- `main`：稳定版本。
- `report/*`：实验报告修改。
- `experiment/*`：脚本、测试和结果更新。
- `docs/*`：说明文档更新。

每次提交尽量只做一类修改，例如“补充 Level 3A 结果说明”或“整理运行流程文档”，避免报告、脚本和大量日志混在一个提交里。
