# 同步 FIFO：Verilog + Icarus 自检项目

使用 VS Code 编辑，使用 Icarus Verilog 编译、仿真，通过 SystemVerilog 参考队列自动检查同步 FIFO。工程包含 RTL、自检 testbench、PowerShell 运行入口，以及可复现的日志和 VCD 波形。

这是从已有学习工程整理出的同步专用副本。`rtl/sync_fifo.v`、`tb/tb_sync_fifo.sv`、`sim/run_sync_fifo.ps1` 保持原程序内容；中文说明和验证证据在独立副本中整理。

## 设计行为

- 参数：`DATA_WIDTH`、`DEPTH`，默认 `8×4`。两者均须为正整数，支持深度 `1`、`3` 等配置。
- 接口：`clk`、`rst`、`wr_en`、`rd_en`、`wdata`、`rdata`、`full`、`empty`。
- 单一上升沿时钟，同步高电平复位；复位清零指针、计数和读输出，不清空存储数组。
- 二进制读写指针显式回绕，使用占用计数区分空、满状态。
- 按上升沿前状态接受请求：`do_write = wr_en && !full`，`do_read = rd_en && !empty`。
- 注册读：有效读之后更新 `rdata`；没有有效读时保持原值，不实现旁路。

| 上升沿前状态，且读写请求均为 1 | 实际接受 | 占用量变化 |
| --- | --- | --- |
| 空 | 仅写入 | +1 |
| 满 | 仅读出 | -1 |
| 非空非满 | 读出旧队首，并写入新数据 | 不变 |
| `rst=1` | 执行复位 | 清零 |

## 在 VS Code 中运行

安装 Icarus Verilog，确认可执行 `iverilog` 和 `vvp`。脚本会先检查 `PATH`，再检查代码中列出的常见 Windows 安装位置。使用 VS Code 打开本仓库目录，在集成 PowerShell 终端执行命令。

完整同步矩阵，共 12 个用例，每例 1000 个随机操作周期：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\sim\run_sync_fifo.ps1 -Matrix
```

单例复现：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\sim\run_sync_fifo.ps1 -DataWidth 8 -Depth 3 -Seed 42 -RandomCycles 1000
```

额外参数测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\sim\run_sync_fifo.ps1 -DataWidth 12 -Depth 5 -Seed 99 -RandomCycles 300
```

不带 `-Matrix` 时，脚本只执行一个用例，默认配置为 `8×4`、seed `1`、1000 个随机周期。单例也会打印最后的汇总标记，因此判断完整矩阵还须核对有 12 个不同配置的 `SYNC_FIFO_PASS`。

通过时包含：

```text
SYNC_FIFO_PASS writes=... reads=... discarded=... resets=...
SYNC FIFO REGRESSION PASS
```

每例检查编译和仿真退出码及通过标记；用例失败会使运行失败。测试包含超时保护。

也可以使用 VS Code 的“终端 → 运行任务”，选择 `FIFO: sync full matrix`。`Ctrl+Shift+B` 默认执行 `FIFO: sync smoke (8x4, seed 1)`，这是 100 周期冒烟测试。

## 文件与测试证据

```text
rtl/sync_fifo.v              同步 FIFO
tb/tb_sync_fifo.sv           独立参考队列、自检和覆盖统计
sim/run_sync_fifo.ps1        单例 / 矩阵运行入口
.vscode/                    编辑器设置与同步任务
docs/                       中文说明
evidence/logs/              本次回归的 13 份日志
evidence/waves/             本次回归的 13 份 VCD
evidence/smoke/             原学习工程的 100 周期波形示例
evidence/results.json       本次回归的结构化结果
evidence/verification_manifest.json  源码、日志和波形的 SHA256
```

2026-11-20 在独立副本中验证：完整矩阵 **12/12 通过**，额外参数用例 **1/1 通过**。完整矩阵为 `(8,1)`、`(8,3)`、`(8,4)`、`(16,4)`，各运行 seed `1`、`7`、`42`。

- [测试计划](docs/test_plan.md)
- [实际测试结果](docs/test_results.md)
- [波形查看与关键时刻说明](docs/waveform_guide.md)
- [工具版本与完整命令](docs/tool_version.txt)
- [发布与调试记录](docs/debug_log.md)

自己运行时，新日志写入 `sim/logs/`，新波形写入 `sim/waves/`，这些生成文件不纳入 Git。**同一宽度、深度和 seed 的再次运行会覆盖该目录下的同名结果，即使随机周期数不同。**例如冒烟任务会覆盖 `sim/` 中 `8×4/seed1` 的长回归结果；仓库中的 `evidence/` 快照不受运行脚本影响。

归档日志只将本机绝对源码路径替换为仓库相对路径，配置、统计和通过结果保持不变。`evidence/smoke/` 来自原工程的已有记录，没有计入本次 13 例回归，也没有追溯声明它由本次源码哈希生成。

## 验证范围

RTL 以 Verilog 模块编写，自检使用 SystemVerilog 队列，实际验证编译选项为 `-g2012`。尚未验证其他编译器或严格 Verilog-2001 模式的兼容性。

结果证明所列配置与激励下的 RTL 功能行为。工程没有提供综合、具体存储宏映射、FPGA 板级测试、时序收敛或形式化穷举证明。
