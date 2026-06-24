# Orchestra membership — apsimR

> **This project (apsimR) is a MEMBER of the Orchestra** (one coordination
> structure; reconciled 2026-06-03). The leader-node is **ORCHESTRA_dev**
> (governance, roster, contracts, TACI, publication); the technical inference hub
> is **flexyBayes** (the dependency-DAG sink). This file is apsimR's back-pointer
> to that charter and a map of my siblings.

- **My role:** the **external process-based engine** — APSIM Next Generation (.NET)
  wrapped as a contract-emitting member: a forward-model closure
  (`apsim_forward_model()`), calibrate / sensitivity / emulate / validate, and the
  **OSSE causal test-bench** (`apsim_ground_truth()` — known-ATE synthetic data for
  scoring TACI/kernR causal estimators). APSIM is real, never stubbed.
- **Contracts I own / honour:** I **emit `apsim_manifest`** (a
  `pesto_ensemble_manifest`-compatible S7, bridged via `as_pesto_manifest()` →
  PESTO's **C2** contract). The exact-GP emulator emits a `"parameters"`-shaped
  result. I consume no manifest.
- **My edge:** producer — apsimR is a process-based forward model upstream of
  **PESTO** (inversion: `apsim_calibrate(backend="ies")` delegates to PESTO) and
  **kernR/TACI** (the OSSE benchmark the causal tests are scored against). Acyclic:
  upstream of the inference/test layers.
- **What binds me (charter invariants):** *single-responsibility* (the process
  forward model + its OSSE bench — not inference/decision); *typed honest
  abstention* (`apsim_abstention` when the APSIM binary is absent; failed
  realisations → counted NA, never silently dropped); *Independent-Oracle* — facts
  about the APSIM authority are grounded against a replayed real run, and the
  emulator's `backend="exact"` is a genuine ML-fitted ARD exact GP (re-grounded vs
  DiceKriging, v0.3.0); *leader-directed adoption*.
- **Governance:** apsimR is a **Max-owned personal package** (`max578`, MIT source
  + combined-GPL when distributed with APSIM); the AAGI-AUS canon does not apply.

## My siblings (the full roster — so I am informed about the others)

| Member | Role | Class |
|---|---|---|
| flexyBayes | inference hub (owns C1/C4/C5/C7) | open (AAGI-gated) |
| PESTO | calibration + manifest source (C2) | open |
| kernR | validation + TACI/ACI engine | open |
| proxymix | KL-optimal proxy compression; the `proxymix_map` optimisation engine | open |
| gretaR | engine — torch MCMC | open |
| koine | synthesis — fourth opinion | open |
| terroir | data collector (C6) | open (MIT) |
| kalmix | state-space / change-point / ACI | open (MIT) |
| masque | data sovereignty (clones) | open |
| apsimR | **external engine — APSIM Next Gen (this package; forward model + OSSE bench)** | open (MIT-src) |
| bourse | grounded market-data connector (trading arm) | open |
| survkit | time-to-event toolkit | open |
| janusplot | asymmetric GAM association matrices (diagnostic-viz) | open |
| gpfield | change-of-support spatial GP; emits `orchestra_manifest` | open (MIT) |
| decideR | decision layer (loss-optimal closer) | open |
| grainPlan | grain decision-orchestration (on decideR) | open (MIT) |
| optimix | optimisation meta-layer; emits `orchestra_manifest` | open (MIT) |
| flexyBayesOrchestra | composition layer (surrogates, koine backend) | open |

Planned: genoR. **Canonical charter:** `ORCHESTRA_dev/ORCHESTRA.md` (mirrored in
the MaxAIbase brain, open tier). **Contract + dependency DAG:**
`ORCHESTRA_dev/integration/orchestra_manifest.R`.
