# THREE_COMPUTER_FRAMEWORK.md
**Using this repository across multiple devices to maximize NVIDIA’s 6G Stack**  

**Based on:** AI Native Wireless Communications

**By:** Dr. Joseph Boccuzzi, Principal Network Architect, NVIDIA AI Aerial

This framework turns models into RAN features by moving them through **Design/Training → Digital Twin (DT) Simulation → End‑to‑End (E2E) Deployment**, while keeping one code path and measurable timing at every step. It operationalizes the “three‑computer” development loop formalized by the NVIDIA AI Aerial team.

---

## A. The three computers (our lab mapping)

### **Computer A — DGX Spark (Design & Bench)**
* **Workloads:**  
  * **Sionna PHY/SYS** for differentiable link & system simulation and ML training.  
  * **Sionna‑RT** for scene‑anchored channels (paths → CIR/CFR/taps) and gradient‑based optimization.  
  * **ACAR (TestMAC + RU‑Emu)** for **slot‑time** L1/L2 experiments with deterministic, per‑TTI control—no OTA.  
* **Why Spark:** Unified, coherent CPU+GPU memory and interactive, notebook‑first development environment.
* **Repo pointers:** `sionna/sionna.md`, `sionna/sionna-rt.md`, `aerial/acar.md`, `aerial/acar_vs_aodt.md`.

---

### **Computer B — AODT Digital Twin (Frontend + Backend GPUs)**
* **Hardware pattern:**  
  * **Frontend (FE):** **DGX Spark** — UI, scenario orchestration, data browsing/analysis.  
  * **Backend (BE):** **GH200 Grace‑Hopper** — EM ray tracing and RAN‑mode execution at scale.  
  * Practical link: 1 GbE works; 10/25 GbE recommended for large USD/DB transfers.
* **Workloads:**  
  * **AODT** end‑to‑end digital twin (ray‑traced physics + RAN mode, mobility, multi‑cell) with ClickHouse telemetry.
  * Drop‑in your **TensorRT** engines for ML PHY blocks inside the cuPHY pipeline via YAML configuration.
* **Repo pointers:** `aerial/aodt.md`, `aerial/acar_vs_aodt.md`.

---

### **Computer C — E2E ACAR Deployment (GH200 + SDR/O‑RU)**
* **Hardware:** **GH200** (gNB DU/CU running **ACAR** L1 with partner L2+) + **X410 5G SDR** (or O‑RU).  
  Over‑the‑air **ARC‑OTA** setups mirror production timing and validate field‑grade performance.
* **Workloads:** Deploy the modular ACAR pipeline with your compiled **TensorRT** “blobs” replacing selected DSP modules.
* **Outcome:** Carrier‑realistic validation of ML receivers (e.g., CNN channel estimator) and end‑to‑end KPIs.

---

## B. End‑to‑end lifecycle (what runs where)

```text
A: Sionna / ACAR (Spark)                →  Export TensorRT engine (the “blob”)
B: AODT (Spark FE  ↔  GH200 BE)         →  DT realism: ray‑traced channels + RAN mode + telemetry
C: ACAR OTA (GH200 + X410 / O‑RU)       →  E2E deployment: validate timing, throughput, BLER in the loop
```

**Design/Training (A)**  
1) Prototype and train in **Sionna PHY/SYS**; generate scene‑anchored datasets with **Sionna‑RT**.  
2) Export models to **TensorRT** engines (GPU‑runnable blobs).

**Digital Twin (B)**  
3) Bring your engine into **AODT RAN‑mode** to execute ML PHY blocks inside a city‑scale DT; capture aligned **CIR/CFR/ray paths + RAN** telemetry in ClickHouse.  
4) Iterate scene, mobility, and deployment parameters; replay and compare against ACAR experiments.

**E2E Deployment (C)**  
5) Deploy **ACAR** on **GH200** with **X410/O‑RU** and identical YAML module selections; verify real‑time performance with field‑realistic fronthaul/air timing.

---

## C. Why AODT uses a **Frontend + Backend GPU**

* FE (**Spark**) keeps the UI responsive, hosts scenario control and analysis.  
* BE (**GH200**) runs the heavy **EM + RAN** compute and DT telemetry pipelines.  
* This split scales better than a single‑GPU host and matches how large scenes, mobility and multi‑cell runs are executed at lab scale.

---

## D. Compile‑to‑GPU pipeline (one code path, many targets)

1) **Author in Python** (Sionna / pyAerial).  
2) **Compile to TensorRT engines** (the “blobs”).  
3) **Slot‑in via YAML** to **ACAR** and **AODT RAN‑mode** without changing the C++ core.  
4) Optional **pre/post CUDA kernels** reshape tensors around the TensorRT node for zero‑copy integration.  

This keeps the same ML artifact valid across **A → B → C** with measurable timing at each stage.

---

## E. Minimal checklists

**Day‑0 Spark bring‑up**  
- `first-boot/README.md` and scripts (NGC CLI, disable Wi‑Fi, MACs).  
- DGX Dashboard multi‑user YAML mapping workaround (see `first-boot/README.md`).  
- Pull **ACAR/AODT** containers; run **ACAR** smoke test.

**Model handoff**  
- Export **TensorRT** engine + version‑pinned YAML.  
- For **AODT**, mount engine and YAML into BE (GH200) container; for **ACAR OTA**, bind the same in GH200 deployment.  
- Log DT telemetry to ClickHouse; mirror KPIs in OTA.

**Networking**  
- FE↔BE control/data works over 1 GbE; prefer 10–25 GbE for large scene & telemetry movement.

---

## F. Pointers in this repo

* **Sionna:** `sionna/sionna.md`, `sionna/sionna-rt.md`  
* **Aerial DT:** `aerial/aodt.md`  
* **Aerial RAN:** `aerial/acar.md`  
* **Chooser & DoS example:** `aerial/acar_vs_aodt.md`  
* **Access & provisioning:** `first-boot/README.md`, `REMOTE_ACCESS.md`

---

## G. Citation

Please cite the NVIDIA AI Aerial framework paper that defines this three‑computer cycle and the Python→TensorRT→RAN integration path:

> @misc{cohenarazi2025nvidiaaiaerialainative,  
>         title={NVIDIA AI Aerial: AI-Native Wireless Communications},  
>         author={Kobi Cohen-Arazi and Michael Roe and Zhen Hu and Rohan Chavan and Anna Ptasznik and Joanna Lin and Joao Morais and Joseph Boccuzzi and Tommaso Balercia},  
>         year={2025},  
>         eprint={2510.01533},  
>         archivePrefix={arXiv},  
>         primaryClass={cs.LG},  
>         url={https://arxiv.org/abs/2510.01533}  
> }


