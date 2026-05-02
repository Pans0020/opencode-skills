---
name: manual-dataset-cleaning
description: Use when searching Nowcoder or similar sources for interview questions, collecting source-backed records, or manually cleaning a structured dataset duplicated across Markdown, CSV, JSON, or similar final artifacts.
---

# Manual Dataset Collection And Cleaning

## Overview

Manual dataset work has two phases: source-backed collection, then synchronized cleaning. The core rule is: preserve provenance first, normalize carefully, then prove every mirrored artifact still agrees.

## When to Use

Use this when a user asks to search 牛客/Nowcoder, collect interview questions, clean, normalize, categorize, deduplicate, or review a dataset that exists in multiple final files, especially combinations like:

- Search results, browser-collected posts, raw notes, or extracted question lists
- Markdown table for viewing or Notion import
- CSV as source of truth
- JSON with `finalRows` or exported records
- Separate dropped, unreviewed, or source-check files

Do not use this for one-off edits to a single file or when the user wants a generator script changed instead.

## Core Rules

| Rule | Reason |
|---|---|
| Preserve source URL, title, and collection metadata before cleaning | Every normalized record must remain traceable |
| Store raw extracted text before normalization | Cleaning mistakes must be reversible |
| Do not add or drop records unless explicitly requested | Count drift is easy to miss in large manual datasets |
| Pick one source of truth before editing | Prevents circular synchronization mistakes |
| Preserve raw/source fields by default | Raw evidence should remain auditable |
| Clean normalized/display fields only | These are intended for corrected wording and taxonomy |
| Edit every mirrored final artifact in the same batch | Avoids Markdown/CSV/JSON drift |
| Use unique anchors for manual patches | Broad JSON or CSV matches can corrupt unrelated rows |
| Verify with parsers, not visual inspection | Tables and quoting hide failures |

## Nowcoder Search And Collection

1. Define scope before searching.
   - Target role: embedded software, Linux driver, C/C++, verification, algorithm, HR, or other.
   - Target company, business line, city, school-recruiting/social-recruiting, internship/full-time, and year range if relevant.
   - Decide whether to collect only questions or also answers, rounds, candidate background, and offer status.

2. Build a keyword matrix.
   - Company variants: full Chinese name, short name, English name, product line.
   - Role variants: `嵌入式`, `嵌软`, `Linux驱动`, `C++`, `单片机`, `UVM`, `芯片验证`.
   - Embedded variants: `嵌入式软件`, `嵌入式开发`, `底层软件`, `BSP`, `RTOS`, `驱动开发`, `MCU`, `ARM`, `C语言`, `车载`.
   - Process variants: `面经`, `一面`, `二面`, `HR面`, `笔试`, `秋招`, `春招`, `实习`, `校招`.
   - Experience variants: `面试题`, `面试经验`, `面试复盘`, `面试记录`, `面试总结`.
   - Query examples: `公司 嵌入式 面经`, `公司 Linux驱动 一面`, `site:nowcoder.com 公司 岗位 面经`.

3. Search in multiple places.
   - Use Nowcoder search first when available.
   - Use external search with `site:nowcoder.com` for posts missed by internal search.
   - Search both broad role keywords and narrow topic keywords.
   - Record search date and query terms for reproducibility.

4. Triage candidate posts before extraction.
   - Keep: interview experiences, Q&A lists, written-test question lists, detailed round notes.
   - Mark for review: compilations, copied reposts, vague posts, comments with useful questions, screenshots requiring OCR.
   - Drop or ignore as question rows: unrelated job discussion, pure salary chat, no extractable question.
   - Do not silently discard duplicate mirrors; record them as extra provenance when they confirm recurrence or add date, company, round, or role metadata.

5. Capture source metadata first.
   - `来源平台`: `牛客` or `Nowcoder`.
   - `来源链接`: canonical post URL.
   - `post_id`: numeric ID parsed from the URL when available.
   - `标题`: visible post title.
   - `作者`: visible author or `未知`.
   - `发布时间` / `更新时间`: visible values or `未知`.
   - `采集时间`: current collection time.
   - `搜索词`: query that found the source.
   - `原帖快照` or `原文摘录`: saved raw text, screenshot reference, or excerpt sufficient to audit extraction if the post changes.
   - `公司`, `岗位`, `轮次`, `地点`, `候选人类型`: extracted if stated, otherwise `未知`.

6. Extract conservatively.
   - Save `原始问题` exactly as seen, including awkward wording, punctuation, and candidate comments.
   - Create `标准问题` separately for cleaned wording.
   - Do not hallucinate missing constraints, company, round, or answer.
   - If a post contains narrative plus questions, split only clear interview questions; keep uncertain fragments in a review file.
   - For screenshots, OCR output must be marked with lower confidence and manually checked.

7. Deduplicate without losing provenance.
   - Use normalized question text, source URL, post ID, and fuzzy similarity.
   - Merge repeated questions only when the meaning is the same.
   - Preserve all source links in source notes or merge notes when multiple posts contain the same question.
   - Prefer structured multi-source fields when possible: `source_urls[]`, `source_post_ids[]`, `source_titles[]`, `first_seen_query`, `merge_sources`.
   - Do not merge variants that differ in constraints, language, platform, or depth.

8. Build review artifacts.
   - Raw collection file: source-backed extracted questions before cleanup.
   - Manual review file: rows needing category, source, OCR, or merge decisions.
   - Final CSV/JSON/Markdown: normalized and synchronized outputs only after review.

## Cleaning Workflow

1. Identify artifacts and schema.
   - List the final files that must stay synchronized.
   - Read enough rows to know headers, top-level JSON keys, row order, and field names.
   - Find intermediate or dropped files, but do not modify them unless requested.

2. Decide the source of truth.
   - Prefer CSV if it has the complete normalized and provenance schema.
   - Prefer JSON if it is the only artifact with richer nested source provenance.
   - Treat Markdown as a view unless the user says otherwise.
   - When files disagree, resolve the conflict by updating non-canonical artifacts to match the chosen source of truth unless the source is obviously corrupt.

3. Classify each intended edit.
   - Normalized question/title cleanup: edit `标准问题` or equivalent.
   - Taxonomy cleanup: edit category, subcategory, topic, tags, difficulty, or related normalized fields.
   - Source evidence: leave `原始问题`, source URL, and source notes unchanged unless explicitly instructed.
   - Dropped/kept decision: only change quality or dropped files when the task includes that scope.

4. Patch narrowly.
   - Use `apply_patch` for manual edits.
   - Anchor JSON patches on a unique question, row number context, or surrounding object, not generic fields like `Topic` or `标签`.
   - In CSV, preserve quoting and escaped quotes.
   - In Markdown, update only the visible cell that corresponds to the normalized field.

5. Verify after each batch.
   - Parse CSV and JSON.
   - Count rows in every final artifact.
   - Compare CSV and JSON over an explicit field allowlist.
   - Compare Markdown display fields to the source of truth.
   - Search normalized fields for residual noise patterns.
   - Check domain-specific misclassification patterns discovered during review.

## Verification Pattern

Use a single fresh verification command before claiming completion. Adapt paths and field names.

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$base = "C:\path\to\final"
$csv = Import-Csv -Path "$base\dataset.csv" -Encoding UTF8
$json = Get-Content -Path "$base\dataset.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$rows = $json.finalRows
$expectedCount = 928

$fields = @('标准问题','大类','小类','Topic','难度','标签','厂商','出现次数','是否项目相关','质量标记','原始问题','来源链接','来源说明','合并说明')
$csvJsonMismatches = New-Object System.Collections.Generic.List[string]
for ($i=0; $i -lt [Math]::Min($csv.Count,$rows.Count); $i++) {
  foreach ($f in $fields) {
    if ([string]$csv[$i].$f -ne [string]$rows[$i].$f) {
      $csvJsonMismatches.Add("Row=$($i+1) Field=$f")
    }
  }
}

$mdLines = Get-Content -Path "$base\dataset.md" -Encoding UTF8 | Where-Object { $_ -match '^\| \d+ \|' }
$mdCsvMismatches = New-Object System.Collections.Generic.List[string]
for ($i=0; $i -lt [Math]::Min($csv.Count,$mdLines.Count); $i++) {
  $parts = $mdLines[$i] -split '\|'
  $md = @{
    '标准问题'=$parts[2].Trim(); '大类'=$parts[3].Trim(); '小类'=$parts[4].Trim()
    'Topic'=$parts[5].Trim(); '厂商'=$parts[6].Trim(); '出现次数'=$parts[7].Trim()
  }
  foreach ($f in @('标准问题','大类','小类','Topic','厂商','出现次数')) {
    if ([string]$csv[$i].$f -ne [string]$md[$f]) {
      $mdCsvMismatches.Add("Row=$($i+1) Field=$f CSV=[$([string]$csv[$i].$f)] MD=[$([string]$md[$f])]")
    }
  }
}

$noiseMatches = New-Object System.Collections.Generic.List[string]
for ($i=0; $i -lt $rows.Count; $i++) {
  $q = [string]$rows[$i].'标准问题'
  if ($q -match '不懂|没说|不会|没回答|好丢人|笨比|嘴瓢|\.\.\.|。。。|\u200b|\?\?|\？\？|"\？|（笔试|笔试＋面试|上来|没答') {
    $noiseMatches.Add("Row=$($i+1) Q=[$q]")
  }
}

"csv=$($csv.Count) jsonFinalRows=$($rows.Count) mdRows=$($mdLines.Count)"
"expectedCount=$expectedCount countMatches=$($csv.Count -eq $expectedCount -and $rows.Count -eq $expectedCount -and $mdLines.Count -eq $expectedCount)"
"csvJsonFieldMismatches=$($csvJsonMismatches.Count)"
$csvJsonMismatches | Select-Object -First 10
"mdCsvDisplayFieldMismatches=$($mdCsvMismatches.Count)"
$mdCsvMismatches | Select-Object -First 10
"standardQuestionNoiseMatches=$($noiseMatches.Count)"
$noiseMatches | Select-Object -First 10
```

## Markdown Table Caveat

Do not compare every Markdown column with naive `-split '\|'` if cells can contain pipe-like content. In the Nowcoder cleanup, `来源说明` could contain `||`, so Markdown verification only compared stable display fields: normalized question, category, subcategory, topic, company, and count.

The sample command's simple split is valid only when every compared Markdown field appears before any pipe-prone field. If a compared field itself can contain `|`, use a Markdown-aware parser or documented escaping.

If a column can contain literal pipes, use one of these:

- Compare only columns before the problematic field.
- Use a Markdown-aware table parser.
- Escape literal pipes before generating Markdown, then compare after documented unescaping.

## Noise Cleanup Rules

Clean normalized question fields when they contain:

- Candidate self-commentary: `不会`, `没回答`, `好丢人`, `嘴瓢`
- Process clutter embedded in the question: `上来`, `笔试＋面试`, unrelated narrative
- Placeholder or OCR artifacts: zero-width spaces, duplicated punctuation, `??`, `。。。`
- Ambiguous dangling punctuation after source extraction

Do not clean raw/source fields unless requested. If a noise regex hits only `原始问题`, that is usually acceptable because raw provenance is preserved.

## Collection Verification

Before moving collected Nowcoder records into final review files, verify:

- Every extracted question has a source URL or a documented reason for missing one.
- Every source URL has title or post ID metadata when available.
- Raw post snapshot, raw text excerpt, screenshot reference, or access-date evidence is stored for auditability.
- Search queries and collection time are recorded somewhere reproducible.
- Required fields are present: raw question, source link, source description, normalized question placeholder, company or `未知`.
- Duplicate detection was run on normalized text and source URL/post ID.
- Merged duplicates retain all source provenance.
- Every final merged record maps back to one or more raw collection rows, and every retained raw source maps to a final row or a documented dropped reason.
- Uncertain OCR, screenshot, copied compilation, or low-confidence rows are marked for manual review.
- CSV/JSON escaping preserves Chinese punctuation, code snippets, quotes, commas, and newlines.

Do not claim a collection is comprehensive. State the search scope, queries, dates, and known gaps instead.

## Misclassification Checks

Add dataset-specific checks for classes of mistakes discovered while reviewing. Examples from embedded/Nowcoder interview questions:

```powershell
$badUvm = @($rows | Where-Object { $_.'标准问题' -match 'UVM' -and ($_.'大类' -eq '数据结构与算法' -or $_.'大类' -eq 'C/C++ 编程基础') }).Count
$badWatchdog = @($rows | Where-Object { $_.'标准问题' -match '看门狗' -and $_.'大类' -eq 'Linux 内核与驱动' }).Count
"badUvmCategoryMatches=$badUvm badWatchdogCategoryMatches=$badWatchdog"
```

Use these checks as guardrails, not as the only review. Update them when new taxonomy mistakes are found.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Starting cleanup before source URLs are captured | Capture provenance first, then normalize |
| Claiming Nowcoder search is exhaustive | Report search scope and known gaps instead |
| Dropping duplicates silently | Merge duplicates while preserving all source links |
| Trusting OCR or screenshots without review | Mark low confidence and manually verify |
| Only editing Markdown because it is easiest to see | Immediately sync CSV and JSON, then verify |
| Treating count equality as sufficient | Also compare fields and row order |
| Cleaning `原始问题` while normalizing `标准问题` | Revert raw field unless the user asked for source cleanup |
| Using a broad JSON patch around `Topic` or `标签` | Re-patch using unique row/question context |
| Trusting Markdown split results for all columns | Exclude pipe-prone columns or use a real parser |
| Saying complete after spot checks | Run a fresh full verification command |

## Completion Criteria

Before reporting success, fresh verification must show:

- Collection scope, queries, and collection date if new sources were searched
- Known search gaps and non-exhaustiveness caveat for Nowcoder collection
- Required source metadata present for collected records
- Duplicate handling preserves provenance
- Raw-to-final mapping or documented dropped reasons for retained collected rows
- Expected row count in every final artifact
- Count equality against the known expected number, not just equality between files
- CSV parses successfully
- JSON parses successfully
- CSV and JSON full-field mismatches are zero for the chosen field list
- Markdown display-field mismatches are zero
- Normalized-field noise matches are zero or explained
- Known category guardrail matches are zero or explained

Report the exact verification output in the final response.
