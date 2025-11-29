# Aerial CUDA-Accelerated RAN (ACAR)

**Links**

* **Download (NGC Collection):** [https://catalog.ngc.nvidia.com/orgs/nvidia/teams/aerial/collections/aerial-cuda-accelerated-ran/artifacts](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/aerial/collections/aerial-cuda-accelerated-ran/artifacts)
* **Documentation Hub:** [https://docs.nvidia.com/aerial/cuda-accelerated-ran/latest/index.html](https://docs.nvidia.com/aerial/cuda-accelerated-ran/latest/index.html)

## What is ACAR?

**Aerial CUDA-Accelerated RAN** brings together the Aerial 5G/6G software stack and NVIDIA accelerated computing to deliver a fully software-defined, cloud-native RAN on COTS servers:

* **Software-defined & modular**: No fixed-function accelerators; composable L1/L2+/CU/UPF modules.
* **End-to-end acceleration**: Inline **cuPHY** (L1), **cuMAC** (L2 scheduling), plus CU/UPF offload for top performance/TCO.
* **General-purpose infra**: Multi-tenancy for RAN + AI workloads → better RoA and infra monetization.

---

## What’s New (high-level)

### 25-2 (current release highlights)

* **cuPHY (4T4R)**: Static beam ID extension, optional static BFW to RU, expanded UEs/cell and bandwidth (40 MHz, CA 100+40+40) “without timing closure” workarounds, **192 SRS resources** for mMIMO, PTP status monitor, logging improvements.
* **cuMAC**

  * **cuMAC-CP**: CUDA copy/compute overlap; new L2 integration testbench for PF metric + sort latency; **20%** CPU–GPU transfer reduction; peak cell capacity ↑ (8→12 cells @ 100 MHz 4T4R).
  * **cuMAC-Sch 64TR**: Dynamic/semi-persistent **UE grouping** per TTI; CUDA RZF beamforming; SRS UL power control; expanded APIs/buffers for 64T64R; new validation testbench.
* **E2E validation**:

  * **4T4R 100 MHz ×20 cells**: UL-only 213 Mb/s; DL-only 1.25 Gb/s; mixed DL 1.1 Gb/s / UL 145 Mb/s.
  * **64T64R 100 MHz ×1 cell**: 2 UEs (2 layers each) hitting 1.44 Gb/s peak.
  * **ARC with OAI/TestMAC**: WNC O-RU integrated; 55 UEs attached; multi-L2 to single L1 (2 cells traffic).
  * **Data Lakes**: real-time, multi-cell IQ capture (≤4 cells).
* **Performance ceilings**: **20×100 MHz 4T4R** peak cells; **6×100 MHz 64T64R** peak cells (16DL/4UL layers with early-HARQ; 16DL/8UL without).
* **Robustness**: EVPN-MH FH, dual PTP, GM holdover; tighter L1 error handling (DOCA/NIC init, FAPI limits, RX failure cases, reconfig validity).

### 25-1 (prior)

* **cuPHY 4TR**: **20×100 MHz** peak cells on GH200; NN-based PUSCH channel estimate.
* **cuPHY 64TR**: **3×100 MHz** ave cells on GH200; static beam weight reconfig.
* **cuMAC-Sch 4TR**: **40×100 MHz** ave cells on GH200; PF techniques (Type-0/1), UE down-selection, PRB/layer selection, OLLA, DRL-MCS.
* **E2E**: 8 peak cells (CN+RAN+UE-EM, eCPRI) with agg DL≈11.2 Gb/s, UL≈1.68 Gb/s; MIG-validated AI-RAN.
* **pyAerial**: CuPy backend, config API, SRS pipelines, CRC, more notebooks.

### 24-3 (earlier)

* **cuPHY**: Multi-cell mMIMO (≤3 cells), special-slot DL scheduling, richer SRS patterns, PRG-level PUSCH channel estimation, RKHS estimator.
* **Resiliency**: RU health monitor, L1 recovery window, filtered nvIPC PCAP, crash backtraces.
* **cuMAC**: DRL-MCS (TensorRT), 64TR MU-MIMO (UE sorting/grouping), aperiodic SRS manager, GPU-TDL channel sim.
* **pyAerial**: CSI-RS, RSRP/SINR, CFO/TA estimation, CRC, fading channel, multi-UE PUSCH, improved APIs.

### 24-2.1 / 24-2 (select)

* **64T64R mMIMO**: 100 MHz DL (≤16 layers), UL (≤8 layers), dynamic/static beamforming, flexible PRG/PRB sizing, multiple UE groups; GH200+BF3 as RU-emu.
* **MGX GH+BF3**: **20 peak 4T4R @100 MHz**; L1–L2 interface refinements; eCPRI dual-port FH; multi-L2 per L1; OTA validation.

---

## Getting and Running ACAR

**Prereqs (host):**

* CUDA **12.9.1** driver (575.57.08), GDRCopy **2.5.1**
* Docker + NVIDIA Container Toolkit

**Login & Pull:**

```bash
docker login nvcr.io
# Username: $oauthtoken
# Password: <Your NGC API Key>

sudo docker pull nvcr.io/nvidia/aerial/aerial-cuda-accelerated-ran:25-2-cubb
```

**Run container (cuBB):**

```bash
sudo docker run --restart unless-stopped -dP --gpus all --network host --shm-size=4096m --privileged -it \
  --device=/dev/gdrdrv:/dev/gdrdrv -v /lib/modules:/lib/modules -v /dev/hugepages:/dev/hugepages \
  -v ~/share:/opt/cuBB/share --userns=host --ipc=host -v /var/log/aerial:/var/log/aerial \
  --name cuBB nvcr.io/nvidia/aerial/aerial-cuda-accelerated-ran:25-2-cubb

sudo docker exec -it cuBB /bin/bash
```

---

## cuMAC (focus for multi-cell scheduling research)

**Purpose:** GPU-accelerated L2 scheduler offload (UE selection, PRB allocation, layer selection, MCS/OLLA, 64T64R MU-MIMO grouping, beamforming hooks). Supports **per-TTI** execution across **multiple coordinated cells**.

**Execution pattern (per TTI):**

1. Host (CPU) prepares data in GPU memory for **three API structs**:

   * `cumacCellGrpPrms` (cell-group constants & topology)
   * `cumacCellGrpUeStatus` (UE state: avg rates, TB errors, HARQ flags, etc.)
   * `cumacSchdSol` (solutions: set of scheduled UEs, allocSol, layerSelSol, mcsSelSol)
2. For each module (UE select / PRB / layer / MCS): call `setup()` (bind params, GPU buffers) then `run()` (launch CUDA kernels).
3. Read back `cumacSchdSol` to apply decisions in L2.

**Representative structs (for logging/instrumentation later):**

* **`cumacCellGrpPrms`**:
  `nUe`, `nActiveUe`, `numUeSchdPerCellTTI`, `nCell`, `nPrbGrp`, `nBsAnt`, `nUeAnt`, bandwidth `W`, noise `sigmaSqrd`, `precodingScheme` (0/1), `receiverScheme` (MMSE-IRC), `allocType` (type-0/1), `betaCoeff` (cell-edge weight), `sinValThr`, `prioWeightStep`, `cellId[]`, `cellAssoc[]`, `cellAssocActUe[]`, `prgMsk[][]`, `postEqSinr[]`, `wbSinr[]`, `estH_fr`/**`estH_fr_half`** (SRS channel coeffs), `prdMat[]`, `detMat[]`, `sinVal[]`.

* **`cumacCellGrpUeStatus`**:
  `avgRates[]`, `avgRatesActUe[]`, `prioWeightActUe[]`, `tbErrLast[]`/**`tbErrLastActUe[]`**, `newDataActUe[]`, `allocSolLastTx`, `mcsSelSolLastTx[]`, `layerSelSolLastTx[]`.

* **`cumacSchdSol`**:
  `setSchdUePerCellTTI[]`, **`allocSol[]`** (type-0 bitmap per PRG per cell **or** type-1 start/end per UE), internal scratch arrays `pfMetricArr[]`/`pfIdArr[]` (GPU), `mcsSelSol[]`, `layerSelSol[]`.

**Key classes (C++):**
`cumac::multiCellUeSelection`, `cumac::multiCellScheduler`, `cumac::multiCellLayerSel`, `cumac::mcsSelectionLUT` — each provides `setup()` + `run()` per TTI and a `debugLog()` for structured dumps.

**Build in cuBB:**

```bash
sudo docker exec -it cuBB /bin/bash
cd /opt/nvidia/cuBB/cuMAC
cmake -Bbuild -GNinja
cmake --build build
```

**Sanity:**

```bash
nvidia-smi               # host
sudo docker exec cuBB nvidia-smi
```

---

## Aerial Data Lake (for OTA datasets)

* Real-time capture of **uplink I/Q** + FAPI metadata from vRAN nodes running ACAR.
* ClickHouse-backed, **time-coherent** across many cells; scalable (each gNB captures its own data).
* APIs exposed so **pyAerial** can transform RF captures into training sets for ML (e.g., soft demapper, neural receivers).
* Storage guidance: **660 GB** for 1M transmissions from a 4T4R 100 MHz RU.

**Quick start (host):**

```bash
docker run -d --network=host \
  -v $(realpath ./ch_data):/var/lib/clickhouse/ \
  -v $(realpath ./ch_logs):/var/log/clickhouse-server/ \
  --cap-add=SYS_NICE --cap-add=NET_ADMIN --cap-add=IPC_LOCK \
  --name my-clickhouse-server --ulimit nofile=262144:262144 \
  clickhouse/clickhouse-server

# allow large table drops if needed
sudo touch ./ch_data/flags/force_drop_table
sudo chmod 666 ./ch_data/flags/force_drop_table
```

**Enable capture (cuPHY controller YAML):**

```yaml
cuphydriver_config:
  datalake_core: 19
  datalake_address: localhost
  datalake_samples: 1000000
```

**Import sample parquet (from cuBB) & query with ClickHouse client** (optional) to validate.

---

## pyAerial (for link/system simulation & ML pipelines)

* Python API for Aerial **cuPHY** components and differentiable link/system simulations.
* Examples: PUSCH link sim, LDPC chain, SRS/CSI-RS pipelines, dataset generation (simulation + Data Lake), neural receiver validation, ML channel estimation, multi-RU decoding notebooks.
* Used to **bridge** digital-twin and OTA: generate data in sim; train/validate using **Data Lake** captures.

---

## Ideal Lab Hardware Configurations

### A. **Aerial Backend (production-grade research node)**

* **Server**: **MGX Grace Hopper GH200** (Grace CPU + H100 GPU)
* **DPU/NIC**: **BlueField-3** (BF3) with O-RAN 7.2x-capable NICs
* **Switching/Timing**: 100/200 GbE spine/leaf with **PTP** (grandmaster + holdover validated), EVPN-MH support
* **Storage**: High-end NVMe (logs, ClickHouse Data Lake), ≥2 TB
* **SW stack**: CUDA 12.9.1 (575.57.08), GDRCopy 2.5.1, Docker + NVIDIA Container Toolkit, ACAR **25-2-cubb** containers
* **Use cases**: multi-cell **64T64R** trials, ARC-OTA, Data Lake at scale, L2 offload (cuMAC-CP/Sch), RU emulation

### B. **Standalone Developer Node (single DGX Spark)**

* **Compute**: **DGX Spark** (single node) with supported GPU
* **Networking**: 10 GbE campus (static-DHCP), optional QSFP for clustering
* **Peripherals**: HDMI monitor, USB-C KB/Mouse (or hub)
* **SW stack**: Same container/toolkit as above
* **Use cases**: Local **digital-twin** builds, cuMAC experimentation (UE grouping/PRB/MCS), TestMAC & RU emu loops, **pyAerial** and **Data Lake** prototyping before scaling to GH200

> **Tip:** Use the Spark for algorithm development and dataset generation; promote to GH200 for multi-cell, high-layer-count, or tight-latency OTA validations.

---

## Quick Setup Checklist

1. **NGC auth**

   ```bash
   ngc --version
   docker login nvcr.io        # $oauthtoken / <NGC API key>
   ```
2. **Pull & run cuBB** (25-2-cubb)
3. **Inside cuBB**: build **cuMAC**, run testbenches; enable **Data Lake** if capturing.
4. **For multi-cell**: configure coordinated cells (L2→cuMAC-CP→cuMAC-sch).
5. **Log/Export**: dump `cumac*` API buffers per TTI for research metrics (PF, fairness, blackout run-lengths, etc.).

---

## License & Support

By pulling and using the Aerial collection/containers you accept the **EULA** included with the product.
Support: **NVIDIA Aerial Developer Forum** (requires developer account).
Latest tag noted in NGC: **`25-2-cubb`** (≈19.9 GB compressed; multi-arch; single-node container).

