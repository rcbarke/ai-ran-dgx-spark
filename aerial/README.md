# NVIDIA Aerial — Docs Index (ACAR · AODT · Comparisons)

A landing page for everything in the **`aerial/`** directory. Use the jump links to dive in, then pick the right playbook for your experiment.

## Jump links

* [ACAR — Aerial CUDA-Accelerated RAN](./acar.md) 
* [AODT — Aerial Omniverse Digital Twin](./aodt.md) 
* [ACAR vs. AODT — Decision Guide + DoS example](./acar_vs_aodt.md) 
* [Sionna vs. NVIDIA Aerial — What to Use, When](./sionna_vs_aerial.md) 

---

## What’s in here (at a glance)

| File                                           | What it covers                                                                                                                     | When to use                                                                                                                 |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| [`acar.md`](./acar.md)                         | How to run **Aerial CUDA-Accelerated RAN** (cuPHY/cuMAC) on a single node; NGC pulls; container run; cuMAC build; Data Lake notes. | **Fast, slot-time** L1/L2 experiments, scheduler stress tests (**TestMAC + RU-emu**), reproducible per-TTI logs.            |
| [`aodt.md`](./aodt.md)                         | How to deploy **Aerial Omniverse Digital Twin**: UI/FE, EM/RAN backend, Nucleus, NATS, ClickHouse; hardware patterns.              | **End-to-end digital twin** with ray-traced physics, mobility, multi-cell scenes, and coherent CFR/CIR/telemetry datasets.  |
| [`acar_vs_aodt.md`](./acar_vs_aodt.md)         | Side-by-side chooser + a ready-to-run **30-UE DoS/overload** design for ACAR; migration path to AODT RAN mode.                     | You’re deciding **which stack** fits your goal, or you want a **starter experiment** to pressure-test PF/RR.                |
| [`sionna_vs_aerial.md`](./sionna_vs_aerial.md) | Cross-ecosystem chooser: **Sionna PHY/SYS**, **Sionna-RT**, **Sionna-RK (soft-RT)**, **ACAR**, **AODT** — and migration paths.     | You need the **big picture** across simulation ↔ soft-RT ↔ DT, and when to graduate between tools.                          |

---

## Quick chooser

| Goal                                                | Use                                            | Why                                                                           |
| --------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------- |
| Stress PF/RR, DoS/overload, iterate rapidly         | **[ACAR](./acar.md)**                          | Per-TTI control (**TestMAC**), **RU emulator**, no EM overhead/OTA required.  |
| End-to-end digital twin (physics + RAN + telemetry) | **[AODT](./aodt.md)**                          | Ray-traced CFR/CIR + **RAN mode** + ClickHouse datasets & replay.             |
| Need a summary across Sionna↔Aerial stacks          | **[Sionna vs. Aerial](./sionna_vs_aerial.md)** | Clear boundaries and upgrade paths (sim → soft-RT → DT).                      |

---

## Recommended hardware paths

* **Phase 1 (fast iterate):** **DGX Spark → [ACAR](./acar.md)** (all local, no OTA). 
* **Phase 2 (realism):** **Spark (Frontend)** ↔ **GH200 (Backend)** → **[AODT](./aodt.md)** RAN-mode with ClickHouse. 

---

## Getting started

1. **Authenticate to NGC** and pull the current ACAR/AODT images (see each doc for exact tags and run lines).  
2. **Run ACAR** for scheduler experiments or **launch AODT** for DT workflows.
3. Use **`acar_vs_aodt.md`** when choosing or when you want a pre-baked DoS template to start from. 
