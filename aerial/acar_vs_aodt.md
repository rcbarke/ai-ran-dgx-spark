# ACAR vs. AODT — Which one for your experiment?

**TL;DR**

* **Choose AODT (Aerial Omniverse Digital Twin)** when you want an **end-to-end digital twin** with **ray-traced radio physics**, scene geometry, mobility, multi-cell, and a RAN that runs in “RAN mode” (it embeds the Aerial stack).
* **Choose ACAR (Aerial CUDA-Accelerated RAN)** when you want **maximum control and iteration speed** to stress the MAC scheduler (e.g., DoS/overload) using **TestMAC + RU emulator**—**no radios/OTA required**.

---

## What each delivers

### ACAR (Aerial CUDA-Accelerated RAN)

* **Purpose:** Fast, modular **L1/L2** experimentation (cuPHY, cuMAC) inside containers.
* **Traffic/control:** Ships with **TestMAC** (L2 driver) and **RU emulator**; you can script **per-TTI** launch patterns, PRB allocation pressure, and pathologic mixes to stress PF/RR schedulers.
* **Best for:** Scheduler research, DoS/overload studies, ablations (PF α, Ton/Toff, UE counts), deterministic replay, CI pipelines.
* **Hardware:** Runs entirely **in-silico** (no O-RU). OTA only when you deliberately move to ARC-OTA.

### AODT (Aerial Omniverse Digital Twin)

* **Purpose:** **Large-scale system-level simulation**: EM ray tracing, scene import (CityGML/OSM→OpenUSD), mobility (procedural/urban), **RAN mode** using the Aerial stack, and **ClickHouse** data products (CFR/CIR/rays + RAN telemetry).
* **Best for:** **Realism** (geometry, materials, dynamics), multi-cell scenes, UE cohorts, repeatable datasets for ML, and visual analysis.
* **Hardware pattern:** **Frontend** (UI) on a lighter GPU; **Backend** (EM/RAN) on a **48 GB+** GPU. Single-GPU works sequentially (init→replay); concurrent FE+BE prefers 2 GPUs.

---

## Does ACAR require hardware OTA?

**No.** ACAR can run **TestMAC + RU emulator** with **no O-RU and no over-the-air** hardware. You only need radios/fronthaul when you step up to **ARC-OTA**.

---

## DGX Spark & GH200: practical deployments

* **DGX Spark**: Perfect for **ACAR/TestMAC + RU-emu**. Also a great **AODT Frontend** host.
* **GH200 (Grace-Hopper)**: Excellent **AODT Backend** (meets VRAM + throughput for ray-traced/RAN).
* **Networking (FE↔BE):** 1 GbE works; **10/25 GbE** is nicer for large USD/DB transfers. No RDMA/IB required for FE/BE control data.

### Recommended topologies

* **Phase 1 (fast iterate):** **Spark → ACAR** (all local).
* **Phase 2 (realism):** **Spark (FE)** ↔ **GH200 (BE)** for **AODT**; reuse your traffic/scheduler ideas inside RAN mode.

---

## Choosing quickly

| Goal                                                      | Use                         | Why                                                    |
| --------------------------------------------------------- | --------------------------- | ------------------------------------------------------ |
| Stress PF/RR scheduler, DoS patterns, tight repeatability | **ACAR** (TestMAC + RU-emu) | Direct per-TTI control, zero EM overhead, no OTA       |
| End-to-end digital twin (physics + RAN + mobility)        | **AODT (RAN mode)**         | Ray-traced CFR/CIR + full RAN telemetry with UI/replay |
| Move to live OTA later                                    | **ARC-OTA**                 | Real fronthaul/air once sims are done                  |

---

## Example: DDoS/Overload study on **ACAR** (30 UEs)

**Objective:** Reproduce PRB-starvation/blackout phenomena by coordinating adversaries; set the stage for later **Stackelberg** defenses.

### Experiment design

* **Carrier:** n78, **SCS 30 kHz (µ=1)**, **40 MHz**, **106 PRBs**.
* **Scheduler:** PF with **α = 0.01** (sweep later).
* **UEs:** **30 total** → **10 benign URLLC**, **20 adversarial**.
* **Benign URLLC traffic:** small payload (≈128 B), **periodic 1 ms** (or 2 ms) with tight latency.
* **Adversaries:** **Ton <= 50 ms**, **Toff = 250-300 ms**; **Poisson superposition** for **time offsets** and **spatial placement** to create overlapping cohorts and persistent starvation windows.
* **Channels:** Start **AWGN/equal SINR** to isolate scheduler; add pathloss later if desired.

### Minimal workflow (container-centric)

1. **Launch RU-emulator + cuPHY** with 40 MHz n78 configs.
2. **Start TestMAC** with a **30-UE profile** and enable **PRB ledger logging** per slot.
3. **Generate UE configs**:

   * `ue_config.csv`: `ue_id, role (benign_urlLC|adversary), x, y`
   * `urllc_schedule.csv`: `ue_id, period_ms, payload_bytes`
   * `adv_schedule.csv`: `ue_id, Ton_s, Toff_s, initial_offset_s (Exp(λ))`
4. **Run** for sufficient duration (e.g., ≥ 3–5 minutes) to capture multiple Ton/Toff cycles.
5. **Post-process**:

   * **Starved-TTI %** for URLLC cohort
   * **Strict/tolerant blackout run-lengths** (e.g., tolerant allows ≤1 ms gaps)
   * **Per-slot Jain’s fairness** (J(t))
   * **Duty-window** summaries (e.g., 120 ms windows)

### Knobs to sweep

* **α** ∈ {0.005, 0.01, 0.02}
* **Ton/Toff** ∈ {(25/250), (25/300), (50/300), (50/250)}
* **Poisson staggering mean** (temporal)
* **Benign URLLC period/payload** bounds

### Why use ACAR first?

* You avoid EM runtime and scene complexity; **every iteration is fast**.
* You get **deterministic slot-time logs** to validate your metrics and figures.
* The **same stress profiles** can later be replayed **inside AODT (RAN mode)** for realism.

---

## Migration path (ACAR → AODT)

1. Validate scheduler effects in **ACAR** (3 UEs → 30 UEs).
2. Port traffic/time scripts to **AODT RAN mode**, keep **URBAN mobility** disabled initially.
3. Add **geometry/materials**, **mobility**, and **64T** panels to study MU-MIMO grouping sensitivity.
4. Log telemetry to **ClickHouse** (telemetry/cfrs/cirs/raypaths) for deeper ML/analytics.

---

## Common pitfalls & tips

* **“ngc not found”**: Install NGC CLI or use `docker login nvcr.io -u '$oauthtoken'` with your **NGC API key**.
* **`ngc` not in PATH after install**: Symlink to `/usr/local/bin` or a PATH dir and **re-source** your shell.
* **`ngc` works but **`docker pull` 401s**:** stale token or whitespace; use `--password-stdin` and rotate the key.
* **PRB logs missing**: Confirm TestMAC flags for **per-slot PRB/UE CSV** are enabled and writable.
* **AODT FE↔BE flaky**: treat it as app control/data (not I/Q). **1 GbE is fine**; prefer **10/25 GbE** for big maps/DBs.

---

## Quick “Which one?” checklist

* Need **physics** (CFR/CIR/raypaths), **mobility**, **city scenes** → **AODT**
* Need **tight scheduler control**, rapid **DoS/overload** loops → **ACAR**
* Want **OTA** later → **ARC-OTA** after ACAR/AODT validation

