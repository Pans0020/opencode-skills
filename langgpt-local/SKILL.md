---
name: langgpt-local
description: Use when tasks require structured prompt design, reusable role templates, or paper-style structured Markdown output with explicit sections such as Role, Profile, Goal, Rules, Workflow, and Initialization.
---

# LangGPT

Use LangGPT when the user wants structured prompt writing, prompt templates, paper-style structured Markdown, or highly organized reusable output schemas.

## When to use
- 需要结构化提示词
- 需要 Role / Profile / Goal / Rules / Workflow 这类分节输出
- 需要论文式、模板化、结构严整的 Markdown 输出
- 需要把零散要求整理成可复用 prompt / 模板 / 规范

## Core rules
1. Prefer explicit sectioned Markdown over free-form prose.
2. Keep headings stable and semantically meaningful.
3. Preserve user requirements as reusable structure, not just one-off wording.
4. When combined with other writing skills, use those skills for tone and style, and use LangGPT for output structure.
5. Do not force LangGPT structure on code, logs, commands, configs, or error messages.

## Default output skeleton
# Role

## Profile
- Author:
- Version:
- Language:
- Description:

## Goal
- Outcome:
- Done Criteria:
- Non-Goals:

## Skills
- Skill 1:
- Skill 2:

## Rules
1.
2.

## Workflow
1.
2.
3.

## Output Format
- Section:
- Constraints:

## Initialization
- How the assistant should start.

## References
- See `references/examples.md`
- See `references/templates.md`
