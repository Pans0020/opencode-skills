# 📄 Paper Reader + Heilmeier's Catechism

## ✨ What it does

Turns any research paper into a **single Heilmeier-style analysis** that is both a faithful summary *and* a critical review, with strict rules separating **what the paper says** from **what the agent thinks**.

## 🎯 What is different from other paper-reading skills

- 📝 **Most tools just summarize.** Useful for details, but it does not tell you whether the paper *matters*.
- 🔭 **Significance comes first.** What you usually need before digging in is a big-picture verdict.
- 🤖 **Evaluation needs the agent's judgment**, not just paraphrasing.
- 🚧 **But judgment without guardrails kills trust.** The line between *paper* and *opinion* must stay visible.
- 📦 **This skill treats every paper as a product:** structured evaluation framework, explicit per-question boundary, attribution markers on every opinion.

## 🧭 How it modifies the standard Heilmeier's Catechism

The **Heilmeier's Catechism** (after DARPA director George Heilmeier) is a checklist for evaluating *proposed* research projects. It asks: (1) what are you trying to do, no jargon; (2) how is it done today, what are the limits; (3) what is new and why will it succeed; (4) who cares; (5) what are the risks; (6) how much will it cost; (7) how long will it take; (8) what are the mid-term and final exams.

This skill repurposes it for **completed papers**:

- **Q1** absorbs the one-sentence plain-language summary. *No separate summary section needed.*
- **Old Q2 + Q3 → new Q2.** Problem, state of the art, and limits are merged.
- **Q3 absorbs the entire technical method**, math included, and is *strictly opinion-free*.
- **Old Q7 ("how long") is dropped.** Papers report finished work.
- **Old Q8 → "what are the experiments and results".** The experiments are the exams; the results are the grades.

Two cross-cutting rules sit on top:

- 🎚️ **Per-question opinion control.** Q1 and Q3 are paper-only. Q4, Q5, Q6 invite analysis. Every personal judgment is prefixed with *"In my opinion,"* or *"My read is,"* so the source is never ambiguous.
- 🔗 **Strict citation discipline.** Every external reference must come from a **web search performed in the same response**. Citations from memory are forbidden. The only carve-out: repeating verbatim what the paper itself says about a work it cites.

## ⚠️ Known limitations

- 🆕 **Very recent arXiv papers** may not be retrievable until they are indexed.
- 🔒 **Paywalled and subscription-only publishers** cannot be downloaded. Works on open-access PDFs, arXiv, pasted text, and uploaded files.
- 🖼️ **Scanned PDFs** without an embedded text layer cannot be parsed. OCR is not part of the pipeline.
