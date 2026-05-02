# 快速上手指南

> 5 分钟开始使用科研论文写作助手

---

## 方式一：OpenClaw 用户（3 步搞定）

### Step 1: 复制技能文件

将整个 `research-writing` 文件夹复制到：

```
~/.openclaw/workspace/skills/research-writing
```

**Windows 用户**：
```powershell
# 如果已经在正确的目录
Copy-Item -Path ".\skills\research-writing" -Destination "~\.openclaw\workspace\skills\" -Recurse
```

**macOS/Linux 用户**：
```bash
cp -r skills/research-writing ~/.openclaw/workspace/skills/
```

### Step 2: 重启 OpenClaw

```bash
# 方式 1: 重启 Gateway
openclaw gateway restart

# 方式 2: 在聊天中发送
/reload
```

### Step 3: 开始使用

直接对 AI 说：

| 你想做什么 | 这样说 |
|-----------|--------|
| 翻译论文 | "帮我把这段中文翻译成英文" |
| 润色论文 | "帮我润色这段英文" |
| 总结文献 | "帮我总结这篇论文" |
| 写摘要 | "帮我写个摘要" |
| 模拟审稿 | "帮我审阅这篇论文" |
| 回复审稿人 | "帮我写 Rebuttal" |
| 基金申请 | "帮我写基金申请书" |

---

## 方式二：手动复制 Prompt（通用）

### Step 1: 打开 SKILL.md

用文本编辑器打开 `SKILL.md` 文件

### Step 2: 找到需要的 Prompt

使用 Ctrl+F 搜索关键词：
- "中译英" → Prompt #1
- "润色" → Prompt #3, #6
- "文献总结" → Prompt #18
- "摘要" → Prompt #23
- 等等...

### Step 3: 复制 Prompt 模板

复制整个代码块（从 ```markdown 到 ```）

### Step 4: 粘贴到 AI 工具

粘贴到你使用的 AI 工具：
- Claude
- ChatGPT
- Cursor
- Cherry Studio
- 其他...

### Step 5: 替换变量

将模板中的 `{{变量}}` 替换为你的实际内容

---

## 常用场景速查

### 📚 场景 1：快速阅读大量文献

```
1. 使用 Prompt #18 文献总结与笔记
2. 对每篇论文生成结构化笔记
3. 使用 Prompt #19 文献对比分析
4. 整理出研究脉络
```

### ✍️ 场景 2：从零开始写论文

```
1. 使用 Prompt #21 论文大纲生成
2. 使用 Prompt #22 章节内容扩展
3. 分别使用 Prompt #23-25 写摘要、引言、方法
4. 使用 Prompt #6 英文润色
5. 使用 Prompt #16 模拟审稿人检查
```

### 🔧 场景 3：修改已完成的论文

```
1. 使用 Prompt #8 英文去 AI 味
2. 使用 Prompt #6 英文润色
3. 使用 Prompt #9 逻辑检查
4. 使用 Prompt #16 模拟审稿人
```

### 📬 场景 4：回复审稿意见

```
1. 使用 Prompt #26 回复审稿人意见
2. 根据建议补充实验
3. 使用 Prompt #27 更新 Cover Letter
```

### 💰 场景 5：申请科研基金

```
1. 使用 Prompt #28 基金申请书写作
2. 使用 Prompt #29 研究计划
3. 使用 Prompt #30 学术演讲 PPT 大纲
```

---

## 进阶技巧

### 技巧 1：串联使用

```
文献总结 (#18) → 找研究空白 (#20) → 生成大纲 (#21) → 写作 (#22-25) → 润色 (#6) → 审稿模拟 (#16)
```

### 技巧 2：迭代优化

```
初稿 → 去 AI 味 (#7/#8) → 润色 (#3/#6) → 逻辑检查 (#9) → 再润色
```

### 技巧 3：批量处理

对多篇文献：
```
1. 准备一个文件夹存放论文 PDF/文本
2. 对每篇使用 Prompt #18
3. 最后用 Prompt #19 对比分析
```

### 技巧 4：自定义 Prompt

根据自己领域修改 Prompt：
```markdown
# 在原有 Prompt 基础上添加：

## 领域特殊要求
- 术语规范：[你领域的术语标准]
- 格式要求：[你领域的期刊格式]
- 特殊约束：[你领域的特殊要求]
```

---

## 常见问题

### Q: Prompt 太长，AI 不响应怎么办？

**A**: 分段使用：
1. 先发送角色定义部分
2. 再发送任务描述
3. 最后发送具体内容

### Q: 输出格式不符合要求？

**A**: 在 Prompt 末尾添加：
```
请严格按照上述格式输出，不要添加额外内容。
```

### Q: 翻译/润色后失去原意？

**A**: 在 Prompt 中添加：
```
请确保不改变原文的核心含义和技术细节。
如有不确定的地方，请用 [?] 标注。
```

### Q: 如何用于非 AI 领域？

**A**: 修改 Prompt 中的示例和术语：
```
将"模型"改为你的领域术语
将"实验"改为你的研究方法
```

---

## 获取帮助

- 📖 查看完整文档：`README.md`
- 🐛 报告问题：[GitHub Issues](https://github.com/your-username/research-writing-skill/issues)
- 💬 社区讨论：[OpenClaw Discord](https://discord.com/invite/clawd)

---

**祝你科研顺利！🎓✨**
