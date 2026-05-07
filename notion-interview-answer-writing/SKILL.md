---
name: notion-interview-answer-writing
description: Use when writing or revising Notion interview-answer pages for embedded/Linux/MCU questions, especially when answers must be expanded into interview-ready prose with dual-context coverage, Notion callouts, inline code formatting, and review/write/verify discipline.
---

# Notion Interview Answer Writing

Use this skill when turning面经题 into可直接面试口述的 Notion 答案，尤其是 Linux/U-Boot/Kernel 与 MCU/Cortex-M4/STM32 这类双语境题。

## Overview
- 目标不是“写提纲”，而是写成面试时能直接说出口的答案。
- 先判定题目语境，再决定是单语境还是双语境。
- 所有技术符号、文件名、寄存器名、段名都要按 Notion inline code 处理。
- 关键概念、环境标签和题目核心词要做 **加粗**，让答案有面试时可扫读的层次。

## When to Use
- 用户让你写、重写、扩写、整理 Notion 面经答案。
- 题目涉及启动地址、链接脚本、向量表、中断、Bootloader、U-Boot、DTB、DMA、`SCB->VTOR`、`MSP`、`Reset_Handler`、`.Scatter`、`.isr_vector`、`.text`、`.data`。
- 需要把同一题同时写成 Linux 语境和 MCU 语境。
- 需要保持 `答案` 蓝色 callout 和 `补充 / 追问` 黄色 callout。

## Core Pattern
1. 先判断题目是 `linux_only`、`mcu_only`，还是 `dual`。
2. `dual` 题必须写出两个小标题：`Linux / U-Boot / Kernel 语境` 和 `MCU / Cortex-M4 / STM32 语境`。
3. 每个语境都要写成“结论 + 机制 + 怎么做 + 怎么验证 + 常见坑”，不能只列关键词。
4. `Linux` 语境优先讲启动协议、地址规划、IRQ 分发、驱动框架、验证手段。
5. `MCU` 语境优先讲向量表、链接脚本、Flash/RAM 布局、Bootloader 跳转、`VTOR`、`MSP`、`Reset_Handler`。
6. `补充 / 追问` 要补“如果面试官追问 Linux 怎么答”“如果追问 MCU 怎么答”“两种语境最容易混淆什么”。
7. 每个语境小标题、每个回答段落的核心关键词要 **加粗**，例如 **启动地址**、**链接脚本**、**中断向量表**、**Bootloader**、**DTB**、**VTOR**。

## Formatting Rules
- 语境标签必须保留原样，但建议用 **加粗** 强调：**Linux / U-Boot / Kernel 语境**、**MCU / Cortex-M4 / STM32 语境**。
- 每段第一句最好给出 **一句话结论**，结论里的核心概念要加粗。
- 技术符号、寄存器、段名、文件名必须用 inline code，不要用粗体代替 code。
- 概念词和动词优先加粗，符号优先 code；例如 **向量表**、**启动地址**、`SCB->VTOR`、`.isr_vector`。
- 不要把整段都加粗，保留可读性，只突出核心词。

## Quick Reference
- 用 inline code 的词：`.Scatter`、`.isr_vector`、`.text`、`.data`、`.bss`、`.rodata`、`SCB->VTOR`、`VTOR`、`MSP`、`Reset_Handler`、`bootcmd`、`bootargs`、`DTB`、`IAP`、`Bootloader`。
- 对高频关键字做 **加粗**：**启动地址**、**链接脚本**、**中断**、**向量表**、**Linux**、**MCU**、**U-Boot**、**Kernel**。
- `答案` callout 保持蓝色。
- `补充 / 追问` callout 保持黄色。
- dual 题不要只写 2-3 条 bullet；要写到能口述至少 1 分钟的密度。
- `linux_only` 题不要硬塞 MCU；`mcu_only` 题不要硬塞 Linux。

## Answer Template
Use this structure for `dual` questions:

```markdown
**一句话结论**

<一句能区分环境的结论，核心词加粗，符号用 `code`。>

**面试回答**

**Linux / U-Boot / Kernel 语境**
- <机制：这件事在 Linux/U-Boot/Kernel 里到底指什么。>
- <怎么做：实际改哪些配置、地址、API、脚本或驱动路径。>
- <怎么验证：用什么 log、命令、寄存器、map/readelf/objdump 验证。>
- <常见坑：地址覆盖、上下文错误、睡眠/中断限制、缓存一致性等。>

**MCU / Cortex-M4 / STM32 语境**
- <机制：这件事在 Cortex-M/STM32 里到底指什么。>
- <怎么做：改链接脚本、启动文件、向量表、`SCB->VTOR`、`MSP` 等。>
- <怎么验证：看 map、PC/MSP、寄存器、调试器、HardFault 现场。>
- <常见坑：只改跳转地址不改链接地址，只改链接脚本不改 Bootloader。>

**面试时如何区分题目语境**
- <出现哪些词说明是 Linux。>
- <出现哪些词说明是 MCU。>
- <题面没说清时如何主动澄清。>

**结合我的简历**
- <把答案落到 RK3588 Linux 驱动、mmap/ioctl、V4L2、FreeRTOS、UART DMA、OTA Bootloader 等真实经历。>

**关键细节**
- <补 3-5 条容易被追问的细节。>

**易错点**
- <补 3 条典型错误。>
```

## Minimal Example
Question: **如何修改启动地址？**

```markdown
**一句话结论**

**启动地址** 要先区分环境：**Linux / U-Boot** 里多半是在改 kernel、`DTB`、initrd 的加载/传参地址；**MCU / Cortex-M** 里多半是在改 Flash 起始地址、`.isr_vector`、`MSP`、`Reset_Handler` 和 `SCB->VTOR`。

**Linux / U-Boot / Kernel 语境**
- **Linux / U-Boot** 里不要只说“改一个地址”，要说清楚 kernel load address、`DTB` 地址、initrd 地址、`bootcmd`/`bootargs` 和 DDR 布局之间不能互相覆盖。
- 验证时看 `printenv`、`bdinfo` 和 boot log，确认 kernel、`DTB`、initrd 实际传入地址都落在安全范围内。

**MCU / Cortex-M4 / STM32 语境**
- **MCU** 里通常要改链接脚本或 `.Scatter` 的 Flash ORIGIN，让 `.isr_vector`、`.text`、`.data` 都按新 App 起始地址布局。
- `Bootloader` 跳 App 前读取向量表第 0 项设置 `MSP`，读取第 1 项作为 `Reset_Handler`，必要时设置 `SCB->VTOR`。
```

## Common Mistakes
- 把答案写成标题式提纲，没有展开机制、步骤和验证。
- 只讲“修改启动地址”却不讲加载地址、链接地址、向量表和跳转流程的关系。
- 把 Linux 的 `request_irq` 当成 MCU 硬件向量表。
- 忘记把 `.Scatter`、`.isr_vector`、`.text`、`.data` 这类符号格式化成 Notion inline code。
- dual 题没写区分语境的段落，导致面试官不知道你会不会切换语境。
- 把关键字当普通文本，导致页面扫起来没有重点，应该把核心词 **加粗**、把符号放进 `code`。
