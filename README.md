# Aerial DGX Spark Lab — Monorepo Index

End-to-end lab for NVIDIA **Aerial** + **Sionna** workflows:

* **DGX Spark specification** → `DGX_SPARK.md`
* **Day-0 bring-up** → `first-boot/`
* **Aerial stacks** (ACAR / AODT) → `aerial/`
* **Sionna modules** (PHY/SYS, RT, RK) → `sionna/`
* **Remote access guide** → `REMOTE_ACCESS.md`
* **6G CI/CD pipeline** → `THREE_COMPUTER_FRAMEWORK.md`

Let's accelerate the RAN.

---

## AI-RAN Stack on DGX Spark: Current Status
1. **PyAerial builds on GB10 but cannot run yet due to GPU conformance checks.**
   The `pyaerial` container successfully compiles against the GB10 toolchain, but the base Aerial image still enforces a supported-GPU allowlist and exits with “GB10 not yet supported.” See [PYAERIAL.md](./aerial/pyaerial/README.md) for build logs and error traces.
   
2. **Sionna PHY/SYS run on GB10 via a Python 3 venv; Sionna-RT does not.** 
   Using a venv with `nvidia-tensorflow[horovod]` from NGC and `pip install "sionna==1.2.1" --no-deps`, we have Sionna PHY and SYS working on the GB10, including LDPC5G and 16-QAM chains and Matplotlib 3D plots. Sionna-RT currently fails on aarch64 due to the `mitsuba==3.7.1` dependency. See [INSTALL_SIONNA.md](./sionna/install_sionna/README.md) for the full installation procedure and unit tests.
   
3. **cuMAC multi‑cell scheduler runs on GB10 with manual GPU/CUDA retargeting.**
   Inside the ACAR cuBB 25‑2 container, cuMAC builds and its 4T4R multi‑cell scheduler testbench runs on DGX Spark once the target GPU index and CUDA architectures are updated (e.g., `gpuDeviceIdx = 0`, `CUDA_VISIBLE_DEVICES=0`, and `CMAKE_CUDA_ARCHITECTURES="80;90;120"`). With these tweaks, the Rayleigh‑fading pipeline yields matching CPU/GPU scheduling solutions for short runs (≈ 50–100 TTIs) before long‑run divergences, making it usable for bounded scheduler studies on GB10 and, by extension, future GB200/GB300 Grace‑Blackwell nodes. See [CUMAC.md](./aerial/acar/CUMAC.md) and [cumac_smoke_test.sh](./aerial/acar/cumac_smoke_test.sh) for the full procedure and harness.

4. **ACAR cuBB cuPHY L1 perf testing uses x86-generated test vectors consumed on DGX Spark/GH200.**
   An x86 “TV bakery” host runs the MATLAB-based `aerial_mcore` pipeline to generate `.h5` and launch-pattern files, which are then synced into `/opt/nvidia/cuBB/testVectors` on ARM systems for stress-testing cuPHY; see [TEST_VECTORS.md](./aerial/acar/TEST_VECTORS.md) for details.

   On DGX Spark specifically, cuPHY L1 can only be **partially** deployed today. The RU Emulator / 7.2x FHI path cannot run because cuVNF has a hard dependency on DOCA and GPUDirect RDMA, and the DGX Spark platform does **not** support GPUDirect RDMA (direct GPU → NIC copies bypassing PCIe/CPU) per [NVIDIA’s DGX Spark GB10 FAQ](https://forums.developer.nvidia.com/t/dgx-spark-gb10-faq/347344). The proposed workaround is to bypass the 7.2x fronthaul and instead use the *cuPHY + TestMAC + SCF L2 standalone adapter* path (see this pathway in NVIDIA’s [cuBB end‑to‑end docs](https://docs.nvidia.com/aerial/archive/aerial-sdk/23-1/text/cubb_quickstart/running_cubb-end-to-end.html)), which effectively assumes an idealized front haul channel. In this mode the L2 standalone adapter builds and runs on DGX Spark/GH200, but the TVnr `.h5` payloads it consumes must be generated on an x86 host with ≥ 64 GB RAM, ≥ 430 GB free storage, and hyperthreading enabled, then `scp`’d into `/opt/nvidia/cuBB/testVectors` on the ARM systems. TV generation itself is not supported on ARM because MATLAB Compiler SDK does not target aarch64, so the cuBB container only ships the lightweight YAML launch patterns by default, not the disk‑heavy HDF5 files. This x86‑generated / ARM‑consumed workflow is planned and will be validated once a x86 lab node with available disk space is freed.

### TO VERIFY

1. **Sionna-RK (Research Kit)**
   Sionna-RK has drifted from the current OAI toolchain; our working hypothesis is that it will deploy on DGX Spark only after the CUDA/patch files are rebuilt against the latest OAI branch and GB10/TF 2.17 stack. NVIDIA provides low-level utilities for this, but they have not been exercised yet. Once replicated, we will check in a `sionna-rk/` subdirectory under `sionna/` with a dedicated `README.md` and reproduction steps. See [SRK known issue #11](https://github.com/NVlabs/sionna-rk/issues/11) for the current upstream status. NVIDIA Research demoed the internal patch mentioned within the known issue at GTC DC 2025.

2. **Aerial Omniverse Digital Twin (AODT)**
   Per the [NVIDIA AODT installation guide](https://docs.nvidia.com/aerial/aerial-dt/text/installation.html#installation), the current installer is pulled from NGC via:

   ```bash
   curl -L "https://api.ngc.nvidia.com/v2/org/nvidia/team/aerial/resources/aodt-installer/versions/$versionTag/files/aodt_1.3.1.zip" \
        -H "Authorization: Bearer $NGC_API_KEY" \
        -H "Content-Type: application/json" \
        -o $downloadedZip

   unzip -o $downloadedZip || jq -r . $downloadedZip
   ```

   On DGX Spark, this sequence currently fails with a `403 Unauthorized` error at the `unzip`/`jq` stage, even when the host is logged into NGC and the `ngc` CLI is configured for the `aerial-ov-digital-twin` assets (per the NGC [first-boot](./first-boot) scripts in this repo). Our working assumption is that this is an entitlement/permissions issue for the AODT 6G Developer Program artifacts rather than a local environment misconfiguration. We will verify the AODT permissions ledger with NVIDIA once our GH200 system is racked, as we anticipate that AODT backend components will not deploy on DGX Spark. The planned topology is **DGX Spark as AODT front end** and **GH200 as backend**. The NGC 6G developer program collection in use is [here](https://registry.ngc.nvidia.com/orgs/esee5uzbruax/collections/aerial-omniverse-digital-twin).

---

## Hardware (lab targets)

* **[DGX Spark](./DGX_SPARK.md) (bench node):** compact developer system for Aerial/Sionna bring-up; supports local console via HDMI 2.1, dual **ConnectX-7 100 GbE (QSFP)** for high-speed lab fabrics, and Dockerized runtimes for ACAR/AODT. USB-C peripherals recommended.
* **GH200 Grace-Hopper (backend):** CPU+GPU **NVLink-C2C unified memory** platform that removes the host–device PCIe bottleneck, ideal for **slot-time cuPHY/cuMAC** experiments and **digital-twin backends** that stream large telemetry/scene datasets.

---

## Repository layout

```
.
├─ first-boot/
│  ├─ README.md
│  ├─ configure_ngc_cli.sh
│  ├─ disable_wifi.sh
│  ├─ display_ethernet_mac.sh
│  └─ install_ngc_cli.sh
├─ aerial/
│  ├─ acar
│  |  ├─ cuBB/
│  |  ├─ TEST_VECTORS.md
│  |  ├─ CUMAC.md
│  |  ├─ cumac_smoke_test.sh
|  |  └─ README.md
│  ├─ pyaerial
│  |  └─ README.md
│  ├─ README.md
│  ├─ acar.md
│  ├─ aodt.md
│  ├─ acar_vs_aodt.md
│  └─ sionna_vs_aerial.md
├─ sionna/
│  ├─ install_sionna
│  |  ├─ inspect_tensorflow.py
│  |  ├─ check_tensorflow.py
│  |  ├─ check_sionna.py
│  |  ├─ check_matplotlib.py
│  |  ├─ sionna_e2e_ldpc_awgn.py
│  |  └─ README.md
│  ├─ README.md              
│  ├─ sionna.md              
│  ├─ sionna-rt.md           
│  ├─ sionna-rk.md           
│  └─ sionna_vs_aerial.md    
├─ DGX_SPARK.md
├─ REMOTE_ACCESS.md
└─ README.md                 
```

---

## Quick start

1. **Read** the datasheet to familiarize yourself with optimizing for the edge → [`DGX_SPARK.md`](./DGX_SPARK.md)
1. **Provision** your Spark → [`first-boot/README.md`](./first-boot/README.md)
2. **Remote access** setup → [`REMOTE_ACCESS.md`](./REMOTE_ACCESS.md)
3. Choose your stack:
   * **Aerial (RAN stacks):** [`aerial/README.md`](./aerial/README.md) →
     * ACAR (cuPHY/cuMAC): [`aerial/acar.md`](./aerial/acar.md)
     * AODT (Digital Twin): [`aerial/aodt.md`](./aerial/aodt.md)
     * ACAR vs AODT: [`aerial/acar_vs_aodt.md`](./aerial/acar_vs_aodt.md)
     * Cross-ecosystem chooser: [`aerial/sionna_vs_aerial.md`](./aerial/sionna_vs_aerial.md)
   * **Sionna (simulation & RK):** [`sionna/README.md`](./sionna/README.md) →
     * PHY/SYS: [`sionna/sionna.md`](./sionna/sionna.md)
     * RT (ray tracing): [`sionna/sionna-rt.md`](./sionna/sionna-rt.md)
     * RK (Jetson/OAI soft-RT): [`sionna/sionna-rk.md`](./sionna/sionna-rk.md)
     * Chooser: [`sionna/sionna_vs_aerial.md`](./sionna/sionna_vs_aerial.md)

---

## Directory details (with one-line summaries)

### `first-boot/`

* [`first-boot/README.md`](./first-boot/README.md) — Day-0 checklist: wired network, MAC registration, user creation, Docker/NGC, DGX Dashboard notes.
* [`first-boot/configure_ngc_cli.sh`](./first-boot/configure_ngc_cli.sh) — Configure **NGC CLI** (default org, prompt for API key) and `docker login nvcr.io`.
* [`first-boot/disable_wifi.sh`](./first-boot/disable_wifi.sh) — Permanently disable Wi-Fi (policy compliance; avoid split-routing).
* [`first-boot/display_ethernet_mac.sh`](./first-boot/display_ethernet_mac.sh) — Print physical NIC MACs for NetReg.
* [`first-boot/install_ngc_cli.sh`](./first-boot/install_ngc_cli.sh) — Install **NGC CLI** (non-interactive helper).

### `aerial/`

* [`aerial/README.md`](./aerial/README.md) — Index for Aerial docs; jump links and hardware path suggestions.
* [`aerial/acar.md`](./aerial/acar.md) — **ACAR**: run **cuPHY/cuMAC** with TestMAC + RU-emulator; rapid slot-time experiments and data capture.
* [`aerial/aodt.md`](./aerial/aodt.md) — **AODT**: Omniverse-based digital twin (ray-traced physics + RAN mode + ClickHouse telemetry).
* [`aerial/acar_vs_aodt.md`](./aerial/acar_vs_aodt.md) — Decision guide plus **30-UE DoS/overload** template for scheduler stress tests.
* [`aerial/sionna_vs_aerial.md`](./aerial/sionna_vs_aerial.md) — Cross-stack chooser (Sionna PHY/SYS, Sionna-RT, Sionna-RK, ACAR, AODT).

### `sionna/`

* [`sionna/README.md`](./sionna/README.md) — Index for Sionna docs (quick links).
* [`sionna/sionna.md`](./sionna/sionna.md) — **PHY/SYS overview** with minimal LDPC+QAM+AWGN “Hello World.”
* [`sionna/sionna-rt.md`](./sionna/sionna-rt.md) — **Sionna-RT**: differentiable ray tracing (scenes → paths → CIR/CFR/taps).
* [`sionna/sionna-rk.md`](./sionna/sionna-rk.md) — **Sionna-RK**: Jetson + OAI; **kernel-level soft-RT** for selected PHY/ML, stack is **non-RT** overall.
* [`sionna/sionna_vs_aerial.md`](./sionna/sionna_vs_aerial.md) — When to use Sionna vs Aerial (and how to migrate).

### Top-level

* [`REMOTE_ACCESS.md`](./REMOTE_ACCESS.md) — Remote console/SSH, network notes, off-campus vpn, and quick configs.
* [`THREE_COMPUTER_FRAMEWORK.md`](./THREE_COMPUTER_FRAMEWORK.md) — How to get the most of the NVIDIA 6G Stack, based on Dr. Joseph Boccuzzi's "AI Native Wireless Communications" paper.
* [`README.md`](./README.md) — (this file) Monorepo index & navigation.


---

## Suggested workflows

* **Algorithm → soft-RT → DT:** Sionna PHY/SYS → Sionna-RK (Jetson/TensorRT) → AODT (physics + RAN mode).
* **Scheduler & throughput (fast):** ACAR (TestMAC + RU-emu) → migrate scenarios to AODT for realism.

---

## Three-Computer Framework — How this repo maps to NVIDIA’s 6G Stack
### Inspired by: "AI-Native Wireless Communications" by NVIDIA Aerial

See the full guide: [`THREE_COMPUTER_FRAMEWORK.md`](./THREE_COMPUTER_FRAMEWORK.md). 

**Purpose.** Move models through **Design/Training → Digital Twin (DT) → E2E/Slot-time Deployment** using one code path (Python → **TensorRT** engine “blob” + optional CUDA pre/post kernels) and measurable timing at each step—exactly the cycle described in the AI-Aerial paper. 

### The three “computers” (roles)

* **Computer A — DGX Spark (Design & Bench)**
  Run **Sionna PHY/SYS** and **Sionna-RT** for differentiable link/system sims and scene-anchored datasets; start **ACAR** (TestMAC + RU-emu) for **slot-time** baselines—fast, reproducible, no radios. Artifacts: trained checkpoints, **TensorRT** engines, YAML module maps. 
* **Computer B — AoDT Digital Twin (Frontend + Backend GPUs)**
  **Frontend (FE) on DGX Spark** for UI/orchestration/analysis; **Backend (BE) on GH200** for EM ray tracing + **RAN mode** execution and telemetry at scale. (1 GbE works; 10/25 GbE preferred for large USD/DB.) Use YAML to drop your TensorRT engines into cuPHY stages and capture CFR/CIR/rays + RAN KPIs in ClickHouse. 
* **Computer C — E2E ACAR Deployment (GH200 + X410 5G SDR or O-RU)**
  Deploy **ACAR** L1 on GH200 with partner L2+/core and real fronthaul/air. This validates field-grade timing and throughput with the *same* ML artifact used in A and B. (ACAR’s real lab E2E demo and >40% UL throughput gains with a CNN CE are shown in the paper.) 

### What to run, where (repo → device)

* **Design / Training (A)** → `sionna/sionna.md`, `sionna/sionna-rt.md`
  Train in Sionna; generate RT datasets; **compile to TensorRT** (the “blob”). 
* **Digital Twin (B)** → `aerial/aodt.md`
  Run **AoDT** with **FE: Spark + BE: GH200**; insert engines via YAML; log telemetry for analysis/replay. 
* **E2E / Slot-time RAN (C)** → `aerial/acar.md` (+ `aerial/acar_vs_aodt.md` for a ready DoS template)
  ACAR on **GH200 + X410/O-RU** to validate live timing; promote scenarios between ACAR and AoDT as needed. 

**Lifecycle loop:**
`Sionna / ACAR (A) → TensorRT export → AoDT FE(Spark)+BE(GH200) (B) → ACAR OTA on GH200 + X410/O-RU (C) → back to Sionna/AoDT` — a virtuous circle of **train → simulate → deploy → replay/tune**. 

> For quick “which tool when” and FE/BE guidance, see the comparison docs: `aerial/acar_vs_aodt.md` and `aerial/sionna_vs_aerial.md`.  

---

**2025 Clemson University IS-WiN Laboratory — Accelerating 5G/6G Research**
