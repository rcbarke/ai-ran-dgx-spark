# Sionna vs. NVIDIA Aerial — What to Use, When

This guide maps the right tool to the right job across simulation, ray tracing, digital twins, and RAN execution.

## Quick chooser (at a glance)

| Goal / Question                                                                  | Use                | Why                                                                                                                        |
| -------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Train/evaluate link & system algorithms with gradients                           | **Sionna PHY/SYS** | Differentiable, GPU‑accelerated link/system blocks in TensorFlow/Keras; fast prototyping & ML integration.                 |
| Need scene‑anchored channels (CIR/CFR) & gradients wrt geometry/materials/arrays | **Sionna‑RT**      | Differentiable ray tracing (Mitsuba3+Dr.Jit) → paths, CIR/CFR/taps; gradients for calibration/optimization.                |
| Validate ML PHY under **real hardware timing** on a low‑cost bench               | **Sionna‑RK**      | Jetson AGX Orin + OAI with **inline** GPU kernels; ML blocks can meet **soft‑RT** deadlines; stack is **non‑RT** overall.  |
| Stress/test Aerial L1/L2 at slot time with maximum control & iteration speed     | **ACAR**           | Containerized cuPHY/cuMAC; TestMAC + RU‑emulator; no OTA needed; ideal for scheduler/throughput research.                  |
| End‑to‑end **digital twin** (ray‑traced physics + RAN mode + datasets/telemetry) | **AODT**           | Omniverse‑based scene/EM + Aerial RAN mode + ClickHouse datasets; scalable DT workflow.                                    |

> For a condensed decision flow and an ACAR DoS/overload example, see the in‑repo comparison guide.  Also see the top‑level README jump table. 

---

## 1) Sionna PHY/SYS — Differentiable link & system simulation

**Use when**

* You need **end‑to‑end differentiable** links (FEC, mod/demap, channels, OFDM, MIMO) and want to **train ML components** in‑loop.
* You’re running **link‑level** studies or **system‑level** sweeps using PHY abstraction (e.g., BLER↔SINR). 

**Don’t use when**

* You require **scene‑anchored** propagation (use Sionna‑RT or AODT).
* You need **slot‑accurate** RAN execution or OTA (use ACAR or RK). 

**Artifacts**

* Tensors, BER/BLER curves, trained Keras models; optional hand‑off to RK (TensorRT) for inline inference. 

---

## 2) Sionna‑RT — Differentiable ray tracing for radio propagation

**Use when**

* You need **physics‑based**, **spatially consistent** channels for specific scenes, with gradients wrt materials/arrays/poses.
* You want **paths → CIR/CFR/taps** to feed into Sionna PHY/SYS or to calibrate against measurements. 

**Don’t use when**

* You need a full RAN digital twin with mobility/telemetry and RAN execution (use **AODT**). 

**Artifacts**

* Ray‑traced paths, coverage maps, time‑varying CIR/CFR/taps; gradient‑based optimization workflows. 

---

## 3) Sionna‑RK — Jetson/OAI testbed for ML‑in‑the‑loop PHY (soft‑RT)

**Use when**

* You must validate **ML PHY blocks under real timing** (TensorRT on Jetson) with **COTS UE** in cabled or OTA setups.
* You accept that **OAI on Linux is non‑deterministic**: RK proves **real‑time (soft‑RT)** at the **kernel level** (e.g., neural receiver, CUDA LDPC), but **not** hard real‑time end‑to‑end. 

**Don’t use when**

* You need carrier‑grade, hard‑RT DU/gNB determinism. Use **ACAR** on data‑center GPUs or vendor DU HW for that class of testing. 

**Artifacts**

* Per‑block latency/throughput measurements; functional BLER/SNR vs. inference‑latency trade‑offs; scripts & Dockerized OAI stack. 

---

## 4) ACAR — Aerial CUDA‑Accelerated RAN (cuPHY/cuMAC, containerized)

**Use when**

* You want **slot‑time** RAN research with **maximum control** (per‑TTI TestMAC), **no radios**, and **fast iteration**.
* You need production‑oriented **cuPHY/cuMAC** offloads (L1/L2), RU‑emulation, data lake capture, and multi‑cell scheduling at scale. 

**Don’t use when**

* You need full EM/scene realism and DT analytics (use **AODT**), or low‑cost bench‑top ML validation (use **RK**). 

**Artifacts**

* Slot‑level telemetry, PRB/layer/MCS decisions, multi‑cell throughput; reproducible **RU‑emu/TestMAC** experiments. 

---

## 5) AODT — Aerial Omniverse Digital Twin (physics + RAN mode)

**Use when**

* You need an **end‑to‑end digital twin**: ray‑traced radio physics with **RAN mode**, UE mobility, multi‑cell scenes, and **ClickHouse** datasets.
* You want to **replay/visualize** scenarios and export coherent **CIR/CFR/ray paths + RAN telemetry** for ML. 

**Don’t use when**

* You only need scheduler stress tests without EM overhead (use **ACAR**), or low‑cost inline ML validation (use **RK**). 

**Artifacts**

* Scene USDs, ray‑traced channels, per‑UE/per‑cell telemetry in ClickHouse, interactive UI/Nucleus/NATS pipeline. 

---

## Migration paths (practical)

* **Algorithm design → soft‑RT validation:** Sionna PHY/SYS → RK (TensorRT export; measure latency BLER vs. depth).  
* **Scheduler research → digital‑twin realism:** ACAR (TestMAC + RU‑emu) → AODT (RAN mode with EM, mobility, telemetry).  
* **Physics‑aware training:** Sionna‑RT → Sionna PHY/SYS (use CIR/CFR/taps) → (optional) RK or AODT for deployment/DT replay.  

---

## Notes on timing realism

* **RK**: **soft‑real‑time** for selected GPU‑accelerated PHY/ML kernels on Jetson; **OAI stack remains non‑RT** overall (general‑purpose Linux). Use RK to validate **kernel‑level deadlines**, not carrier‑grade DU determinism. 
* **ACAR**: slot‑time execution with cuPHY/cuMAC on data‑center GPUs; designed for **RAN performance and scale** and deep scheduler studies (RU‑emu/TestMAC). 
* **AODT**: adds **ray‑traced physics + RAN mode** for DT realism and datasets; front‑/back‑end split (UI vs. EM/RAN) recommended for scale. 

---

### References / Pointers

* Sionna PHY/SYS overview & hello‑world link sim. 
* Sionna‑RT (differentiable ray tracing). 
* Sionna‑RK (Jetson/OAI, soft‑RT clarification). 
* ACAR (cuPHY/cuMAC, TestMAC, RU‑emu, Data Lake). 
* AODT (digital twin platform). 
* ACAR vs. AODT decision guide; top‑level README jump table.  
