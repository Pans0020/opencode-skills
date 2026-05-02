# DeepSeekMath: Pushing the Limits of Mathematical Reasoning in Open Language Models

*Example output of the Paper Reader + Heilmeier's Catechism skill.*
*Source paper: [arXiv:2402.03300](https://arxiv.org/abs/2402.03300)*

## 1. What are you trying to do?

The paper makes a small open language model **good at hard math**, while keeping training affordable.

More technically, the authors take a 7-billion-parameter base model, continue pretraining it on a large math-focused web corpus, instruction-tune it, and then refine it with a reinforcement learning step that is cheaper to run than the standard recipe used for language models.

## 2. What is the problem, how is it done today, and what are the limits of current practice?

In early 2024, **open-source LLMs were far behind closed models** like GPT-4 and Gemini Ultra on math benchmarks such as GSM8K and MATH. Two structural bottlenecks held the field back:

- *Data scarcity.* The public math pretraining corpora were small. **OpenWebMath** had ~13.6B tokens, **Proof-Pile-2** ~51.9B, and most efforts leaned heavily on arXiv as a math source.
- *Expensive RL fine-tuning.* The standard reinforcement learning recipe was **PPO** (Proximal Policy Optimization), which requires training and holding in memory a value (critic) network of comparable size to the policy itself, doubling the memory footprint.

A small editorial framing: the deeper limit was less about any single component and more about the absence of a credible **end-to-end recipe** for taking a small open base model to competition-level math performance using only verifiable rewards.

## 3. What is new in the approach, including core idea, math, and method, and why does the paper claim it will succeed?

The paper has two largely independent contributions: a **data pipeline** and a **new RL algorithm**.

### *Data pipeline*

The authors build the **DeepSeekMath Corpus** by iteratively mining Common Crawl:

1. Start from **OpenWebMath** as a seed corpus.
2. Train a **fastText classifier** to recall additional math-like pages from Common Crawl.
3. Identify whole **math-heavy URL domains** and add their pages to the seed.
4. Retrain the classifier and repeat.

After four iterations: **35.5M pages, 120B tokens, multilingual, ~7x the math content used by Minerva**.

This corpus then drives a multi-stage training pipeline:

- **DeepSeekMath-Base 7B.** Continued pretraining of DeepSeek-Coder-Base-v1.5 7B on **500B tokens** (56% from the new corpus, the rest code, arXiv, and general text).
- **DeepSeekMath-Instruct 7B.** Instruction tuning on **776K** math problems with chain-of-thought, program-of-thought, and tool-use formats.
- **DeepSeekMath-RL 7B.** Reinforcement learning with **GRPO** on chain-of-thought GSM8K/MATH data.

### *GRPO algorithm*

Let:

- $\pi_\theta$ = current policy
- $\pi_{\theta_{old}}$ = the policy that produced the rollouts
- $\pi_{ref}$ = a frozen reference policy
- $V_\psi$ = a learned value function (used by PPO, removed by GRPO)

PPO maximizes a clipped surrogate objective using a per-token advantage $A_t$ produced by $V_\psi$. For a question $q$ from a question distribution $P(Q)$ and an output $o$ sampled from $\pi_{\theta_{old}}$, PPO optimizes (Eq. 1 of the paper):

$$
\mathcal{J}_{PPO}\left(\theta\right) = \mathbb{E}\left[\frac{1}{|o|} \sum_{t=1}^{|o|} \min\left(\rho_t\left(\theta\right) A_t,\ \mathrm{clip}\left(\rho_t\left(\theta\right),\ 1-\varepsilon,\ 1+\varepsilon\right) A_t\right)\right],
$$

where $\rho_t(\theta) = \pi_\theta(o_t \mid q, o_{<t}) / \pi_{\theta_{old}}(o_t \mid q, o_{<t})$ is the per-token importance ratio and $\varepsilon$ is the clipping range.

**Group Relative Policy Optimization (GRPO)** removes $V_\psi$ entirely. For each question $q$, GRPO samples a group of $G$ outputs $\left\{o_1, \ldots, o_G\right\}$ from $\pi_{\theta_{old}}$, scores each with a reward model giving rewards $\mathbf{r}=\left(r_1, \ldots, r_G\right)$, and constructs each output's advantage by **normalizing within the group**:

$$
\hat{A}_{i,t} = \tilde{r}_i = \frac{r_i - \mathrm{mean}\left(\mathbf{r}\right)}{\mathrm{std}\left(\mathbf{r}\right)},
$$

where $\hat{A}_{i,t}$ is the advantage assigned to the $t$-th token of the $i$-th output (the same scalar broadcast across all tokens, in the outcome-supervision variant). GRPO also moves the KL penalty against $\pi_{ref}$ from the reward into the loss using an unbiased KL estimator.

Mechanically, the in-group normalization gives a baseline for free: outputs above the group mean get reinforced, those below get suppressed, and the critic disappears, **freeing roughly half the memory**.

### *Why the paper claims it will succeed*

- **On data:** Common Crawl contains far more high-quality math content than the community had been exploiting, and a carefully iterated classifier can extract it at scale.
- **On RL:** GRPO's group baseline aligns naturally with the comparative structure of reward models, and removing the critic both reduces memory and avoids a shaky learned baseline that is hard to train when reward arrives only at the final token.

## 4. Who cares? If successful, what difference does it make?

For the math-LLM community in 2024, the immediate payoff was a **competitive open math model and a reusable data recipe**. In my opinion, the larger and more durable impact has been **GRPO itself**, not DeepSeekMath.

Evidence of adoption since publication:

- DeepSeek's own R1 paper explicitly adopts GRPO as the RL framework for both DeepSeek-R1-Zero and DeepSeek-R1, citing the cost savings from foregoing the critic.
- Independent commentary describes GRPO as currently **the most common RL optimizer for open reasoning models** trained with verifiable rewards, with its popularity driven primarily by R1.
- The R1 line of work was published in **Nature in September 2025**, which is unusual for an LLM paper and gave the GRPO recipe substantial cross-disciplinary visibility.

My read is that anyone wanting to do reasoning RL on LLMs without burning compute on a value model now reaches for GRPO by default, which by 2025 was essentially the entire open reasoning-model community.

## 5. What are the risks?

The paper itself flags several:

- **arXiv-only pretraining yielded no measurable gain** on math benchmarks, suggesting source quality matters more than raw token count.
- The model **struggles on geometry and theorem proving** and shows limited few-shot improvement compared to GPT-4, hinting at data-selection bias.
- The Pass@K vs Maj@K diagnostic in Section 5.2.2 shows **RL improves Maj@K but not Pass@K**, which the authors interpret as RL re-weighting existing capabilities rather than expanding them.

In my opinion, two further risks deserve more attention than the paper gives them:

- **Reward hacking and brittleness of rule-based rewards.** GRPO with group-normalized advantages amplifies whatever signal the reward function provides, so a noisy or gameable reward gets optimized efficiently in the wrong direction. The paper sidesteps this because GSM8K and MATH have crisp ground truth, but extrapolating GRPO to non-verifiable domains is not free. Later work on DeepSeek-R1 explicitly avoided neural reward models for large-scale RL and used only rule-based verifiable rewards because of reward-hacking concerns.
- **Benchmark contamination.** The authors describe a 10-gram filter against benchmark substrings, but Common Crawl is famously hard to fully decontaminate, and the reported MATH gains should be read with that caveat.

## 6. How much will it cost?

I am interpreting cost as **compute and engineering effort to reproduce**. The paper does not provide a dollar figure or full GPU-hour count, but enough hints to estimate.

Key training hyperparameters from the paper:

- **Continued pretraining:** 500B tokens, batch size **10M tokens**, peak LR 4.2e-4.
- **SFT:** 500 steps, batch size 256, constant LR 5e-5.
- **GRPO:** 64 samples per question, batch size 1024, max length 1024, ~144K questions, KL coefficient 0.04, policy LR 1e-6.

In my opinion:

- The **dominant cost** is the 500B-token continued pretraining, not the RL stage, even though GRPO is the part that gets headlines.
- A research group with **8 to 32 H100s** could reasonably reproduce the GRPO step against an existing instruction-tuned 7B.
- Reproducing the full pipeline (corpus mining, pretraining, SFT, and RL) is a **serious industrial effort**.
- I will not quote a dollar figure for DeepSeekMath because the paper does not give one. Figures floating around for related DeepSeek models such as R1 refer to different training runs and should not be conflated with this paper.

## 7. What are the experiments and results?

**Benchmarks used:**

- *English math:* GSM8K, MATH, OCW, SAT, MMLU-STEM
- *Chinese math:* CMATH, MGSM-zh, Gaokao-MathCloze, Gaokao-MathQA
- *Formal math:* miniF2F (Isabelle)
- *General capability:* MMLU, BBH, HumanEval, MBPP

**Headline numbers:**

| Model | GSM8K | MATH (CoT) | Notes |
|---|---|---|---|
| DeepSeekMath-Base 7B | **64.2%** | **36.2%** | beats Minerva 540B (77x larger) |
| DeepSeekMath-Instruct 7B | 82.9% | 46.8% | strong open SFT baseline |
| **DeepSeekMath-RL 7B** | **88.2%** | **51.7%** | beats all open 7B–70B models, most closed models |
| DeepSeekMath-RL + maj@64 | — | **60.9%** | with self-consistency |

DeepSeekMath-RL still trails GPT-4 and Gemini Ultra on MATH chain-of-thought, but closes most of the gap.

**Key ablations:**

- *Code before math.* Code pretraining before math pretraining helps math reasoning both with and without tools.
- *arXiv-only pretraining.* Shows no measurable math gains and sometimes hurts.
- *RL variants ranked.* Process-supervision GRPO > outcome-supervision GRPO > online RFT > offline RFT.

**One small gap worth noting:** the headline DeepSeekMath-RL run uses only chain-of-thought data from GSM8K and MATH yet improves out-of-domain Chinese benchmarks too. The paper presents this as a positive surprise but does not fully explain it.
