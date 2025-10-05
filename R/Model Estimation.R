############################################################
# Estimation of Switching model using a rolling window
# Config: Normal–eGARCH, K = 2, window W = 504
# Output: signal_prob with P(S_{t+1} = Regime 1 | I_t)
# Notes:
# - Baseline loop: daily re-fit (slow; can hit SE/Hessian issues).
# - Variant loop: weekly refit + daily filtering (mitigates speed/issues).
############################################################

# Inputs assumed available in the environment:
# - close_returns_demeaned : AR(1)-demeaned daily log returns (numeric vector)
# - n, dates, etc. (not required here; this file focuses on estimation only)

################ Baseline: daily re-fit on each window ################

window_size <- 504
n <- length(close_returns_demeaned)
signal_prob <- numeric(n - window_size)

for (t in window_size:(n - 1)) {

  est_data <- close_returns_demeaned[(t - window_size + 1):t]

  spec <- CreateSpec(
    variance.spec     = list(model = "eGARCH"),
    distribution.spec = list(distribution = "norm"),
    switch.spec       = list(K = 2)
    # constraint.spec = list(regime.const = "nu")
  )

  fit_result <- FitML(spec = spec, data = est_data)
  probs <- State(fit_result)
  predictive_probs <- probs$PredProb

  # one-step-ahead prob for t+1 (last row of PredProb)
  signal_prob[t - window_size + 1] <- predictive_probs[window_size + 1, 1, 1]
}

# quick peek if you want:
# signal_prob[3000]

############## Variant: weekly refit + daily filtering ################

# IMPORTANT: define spec ONCE outside the loop (referenced below)
spec <- CreateSpec(
  variance.spec     = list(model = "eGARCH"),
  distribution.spec = list(distribution = "norm"),
  switch.spec       = list(K = 2)
)

k <- 5  # scheduled refit every 5 trading days

# simple shock-trigger: refit if today's |return| is in top 5% of the window
shock_trigger <- function(x) abs(tail(x, 1)) > quantile(abs(head(x, -1)), 0.95, na.rm = TRUE)

last_par <- NULL
last_fit <- NULL

for (t in window_size:(n - 1)) {
  est_idx  <- (t - window_size + 1):t
  est_data <- close_returns_demeaned[est_idx]

  # scheduled refit OR shock trigger
  need_refit <- is.null(last_par) ||
    ((t - window_size) %% k == 0) ||
    shock_trigger(est_data)

  if (need_refit) {
    # warm-start if you can; turn off SEs for speed/stability
    fit <- if (is.null(last_par)) {
      FitML(spec, data = est_data, ctr = list(do.se = FALSE))
    } else {
      FitML(spec, data = est_data, ctr = list(do.se = FALSE, par0 = last_par))
    }
    last_fit <- fit
    last_par <- coef(fit)
    st <- State(last_fit)
  } else {
    # no optimization; just re-filter with fixed params
    st <- State(spec = spec, par = last_par, data = est_data)
  }

  P <- st$PredProb
  signal_prob[t - window_size + 1] <- P[window_size + 1, 1, 1]
}
