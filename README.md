# MSGARCH_Algo

**MS‑GARCH–based Bitcoin regime detection & trading.**

This repo extends my master’s thesis on Markov‑Switching GARCH models. It documents progress, current blockers, and the plan toward a full, reproducible trading study.

> Status: **Work in progress** — focus today is **model estimation** and **out‑of‑sample predictive probabilities**.

---

## Project plan (4 steps)

1. **Model estimation & predictive probabilities (current)**

   * Estimate MS‑GARCH on rolling windows and extract **one‑step‑ahead** regime probabilities (PredProb last row).
   * **Current configuration under test:** Normal‑eGARCH, **K = 2** regimes, **W = 504** trading days (~2 years).
   * **Next configurations:** alternative window sizes (e.g., 252/378/756) and **K = 3** regimes.

2. **Strategy backtests (next)**

   * Use the predictive probabilities as inputs to multiple trading rules (binary threshold, probability‑weighted, vol‑aware).
   * Compare to **Buy & Hold** with realistic trading frictions.

3. **Statistical validation**

   * Apply **White’s Reality Check** (data‑snooping robust) to assess if outperformance vs Buy & Hold is statistically significant.
   * (Optionally cross‑check with SPA or block‑bootstrap tests.)

4. **Forward testing**

   * Paper‑trade the selected strategy and monitor live performance.

---

## Current experiment (Step 1)

* **Asset & returns:** BTC daily close → log returns.
* **Rolling alignment:** fit on ([t−W+1, …, t]), use `State(fit)$PredProb` **last row** as (P(S_{t+1}\mid\mathcal{I}_t)), map to return at **t+1** (no look‑ahead).
* **Spec under test:** **Normal–eGARCH**, `K = 2`, `W = 504` (2y).
* **Loop range:** `t = W … n−1` so each probability forecasts an available next‑day return.

### Issues observed (and how we’ll address them)

* **Hessian / eigen failure when computing SEs**
  Error messages seen: `Error in eigen(mNegHessian)` and `NaNs produced in sqrt(diag(mSandwitch))`.
  **Planned approach:** compute **without SEs** inside rolling loops; if SEs are needed, compute them **once** on a single stable fit.

* **Long stretches of 0/NA probabilities after long runs (~3k obs)**
  Can stem from a failing window, boundary solutions, or numeric brittleness.
  **Planned guardrails (no look‑ahead impact):** initialize with NA, `tryCatch` around fit/filter, clamp probs to `(1e‑12, 1−1e‑12)`, and consider **weekly refits with daily filtering** to stabilize optimization.
  (For robustness checks later we may also test Student‑t errors and enforce consistent regime labels; today we keep **Normal‑eGARCH** as specified.)

---

## Repository map (minimal for now)

```
MSGARCH_Algo/
├─ README.md                  # this file
├─ R/
│  ├─ Model Estimation.R      # estimation loop (to be added next)
│  ├─ Trading Strategies.R         # spec helpers (to be added)
│  └─ metrics.R               # simple stats (later)
├─ scripts/
│  ├─ run_backtest.R          # runs one config & saves artifacts (later)
│  └─ repro_*                 # tiny scripts reproducing current issues (later)
├─ data/
│  └─ btc_daily.csv           # local only; schema: date,close
└─ results/
   ├─ figures/                # plots saved by scripts
   └─ tables/                 # CSV summaries
```

---


---

## What reviewers should know

* The repo is intentionally **transparent**: problems are logged, and fixes are planned before adding trading logic.
* We avoid **look‑ahead** by mapping (P(S_{t+1}\mid\mathcal{I}_t)) to return at (t+1).
* Statistical validation will use **White’s Reality Check** before any forward test claims.


**Contact:** Mohammad Aghvami — https://www.linkedin.com/in/aghvami-mo/
