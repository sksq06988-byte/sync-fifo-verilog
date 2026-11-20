# 同步 FIFO 实际测试结果

验证日期：2026-11-20。以下 13 例均在独立发布副本中实际运行，编译和仿真进程退出码为 0，并出现各例通过标记与脚本最终通过标记。

完整矩阵为四种参数配置 × 三个 seed，共 12 例，每例 1000 个随机操作周期。额外参数用例为 `DATA_WIDTH=12, DEPTH=5, SEED=99, RANDOM_CYCLES=300`。定向测试周期另计。

| 宽度×深度 | seed | 随机周期 | 接受写入 | 接受读出 | 复位丢弃 | 复位次数 | 结果 | 日志 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8×1 | 1 | 1000 | 250 | 248 | 2 | 3 | PASS | [查看](../evidence/logs/sync_w8_d1_s1.log) |
| 8×1 | 7 | 1000 | 249 | 248 | 1 | 3 | PASS | [查看](../evidence/logs/sync_w8_d1_s7.log) |
| 8×1 | 42 | 1000 | 251 | 249 | 2 | 3 | PASS | [查看](../evidence/logs/sync_w8_d1_s42.log) |
| 8×3 | 1 | 1000 | 416 | 414 | 2 | 3 | PASS | [查看](../evidence/logs/sync_w8_d3_s1.log) |
| 8×3 | 7 | 1000 | 428 | 426 | 2 | 3 | PASS | [查看](../evidence/logs/sync_w8_d3_s7.log) |
| 8×3 | 42 | 1000 | 457 | 454 | 3 | 3 | PASS | [查看](../evidence/logs/sync_w8_d3_s42.log) |
| 8×4 | 1 | 1000 | 444 | 439 | 5 | 3 | PASS | [查看](../evidence/logs/sync_w8_d4_s1.log) |
| 8×4 | 7 | 1000 | 451 | 447 | 4 | 3 | PASS | [查看](../evidence/logs/sync_w8_d4_s7.log) |
| 8×4 | 42 | 1000 | 485 | 481 | 4 | 3 | PASS | [查看](../evidence/logs/sync_w8_d4_s42.log) |
| 12×5 | 99 | 300 | 175 | 171 | 4 | 3 | PASS | [查看](../evidence/logs/sync_w12_d5_s99.log) |
| 16×4 | 1 | 1000 | 444 | 439 | 5 | 3 | PASS | [查看](../evidence/logs/sync_w16_d4_s1.log) |
| 16×4 | 7 | 1000 | 451 | 447 | 4 | 3 | PASS | [查看](../evidence/logs/sync_w16_d4_s7.log) |
| 16×4 | 42 | 1000 | 485 | 481 | 4 | 3 | PASS | [查看](../evidence/logs/sync_w16_d4_s42.log) |

13 例总计：4986 次接受写入 = 4944 次接受读出 + 42 次复位丢弃。每例结束时参考队列均为空。

各例覆盖统计均满足现有 testbench 的检查门槛：读空、写满、空/满时同时请求、读写指针回绕、非空复位；深度大于 1 时还要求非空非满的同时读写。深度 1 不存在非空非满状态，因此不要求该项覆盖。

每份日志均有 3 次复位记录。数据在运行中复位时会被清除，因此守恒式包含复位丢弃量。

对应 VCD 文件位于 [evidence/waves](../evidence/waves)，文件基本名与日志一致；每例的明确路径也记录在 [results.json](../evidence/results.json)。

## 复现与证据处理

完整命令及本机核验的工具版本见 [tool_version.txt](tool_version.txt)。[verification_manifest.json](../evidence/verification_manifest.json) 记录本次实际使用的三个程序文件与归档日志、VCD 的 SHA256。

归档日志只把仿真器输出的本机绝对源码路径替换为相对路径；数值、配置、覆盖统计、PASS 结果保持不变。归档 VCD 保持生成内容。

[evidence/smoke](../evidence/smoke) 为原学习工程留下的 100 周期示例，用于讲解波形；它未计入本表，未追溯关联本次源码哈希。

重新运行会写入 `sim/logs/` 和 `sim/waves/`，不会更新这里的归档快照。相同宽度、深度和 seed 的用例会覆盖这些生成目录下的同名结果。

本结果没有验证综合、硬件资源、具体存储宏、板级运行或时序约束；它是所列配置与测试刺激下的 RTL 仿真结果。
