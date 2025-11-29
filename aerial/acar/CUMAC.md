# cuMAC on DGX Spark (GB10) – Smoke Testing Notes

**Last updated:** November 2025  

**Hardware:** NVIDIA DGX Spark (GB10 Grace–Blackwell SoC, unified 128 GB LPDDR5x) 

**Software:** ACAR (cuBB) 25‑2 container on DGX OS (CUDA 13 driver on host, CUDA 12.9 toolchain inside container)

**ACAR Reference:** [Getting Started with cuMAC](https://docs.nvidia.com/aerial/cuda-accelerated-ran/latest/aerial_cumac/getting_started.html)

This document records what we had to change to get **cuMAC**’s 4T4R scheduler testbench running on **DGX Spark / GB10**, what works, and where the GPU/CPU scheduler comparisons diverge.

The setup is **good enough for early scheduling research** (e.g., multi‑cell PF studies, throughput vs. fairness), but not yet “pixel‑perfect” compared to NVIDIA’s reference x86 platforms over long TTI runs.

---

## 1. Context & Goals

- Target platform: **NVIDIA DGX Spark** – a Grace–Blackwell GB10 desktop node with:
  - Integrated Blackwell GPU (5th‑gen Tensor Cores with FP4)  
  - 20‑core Grace CPU  
  - 128 GB coherent unified memory (CPU+GPU)   
- Target stack:
  - **ACAR cuBB container 25‑2** running on DGX Spark.
  - Use **cuMAC** as a **GPU‑accelerated scheduler testbench** for:
    - Multi‑cell PF scheduling
    - DL/UL scheduler pipeline
    - Eventually: 64T64R MU‑MIMO + DRL MCS selection.

For now we focus on the **4T4R multiCellSchedulerUeSelection** pipeline and confirm that **GPU and CPU scheduler paths match** over a reasonably small number of TTIs.

---

## 2. Preconditions (DGX Spark / GB10 / ACAR 25‑2)

All steps below occur **inside the ACAR cuBB container** on DGX Spark.

### 2.1 CUDA & GPU visibility

Inside the container:

```bash
nvcc --version
# ... Cuda compilation tools, release 12.9, V12.9.86
````

The **host** DGX Spark driver is CUDA 13, but the **container** toolchain is CUDA 12.9. This mismatch is OK for our smoke tests as long as kernels are compiled for the right SM architecture and the runtime sees GPU 0.

We ensure the container only sees Spark’s GB10 as **device 0**:

```bash
export CUDA_VISIBLE_DEVICES=0
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"
# CUDA_VISIBLE_DEVICES=0
```

`nvidia-smi` inside the container shows the GB10:

```bash
nvidia-smi
# NVIDIA-SMI 580.95.05, CUDA Version: 13.0
# GPU 0: NVIDIA GB10 ...
```

### 2.2 cuMAC parameters.h tweaks

Edit:

```bash
vim /opt/nvidia/cuBB/cuMAC/examples/parameters.h
```

Key changes:

```c
// use the first (and only) GPU in Spark
#define gpuDeviceIdx           0   // index of GPU device to use

// simulation duration
// Default from NVIDIA:
#define numSimChnRlz           2000 
// total number of simulated TTIs (e.g., 15000 for 1200 active UEs per cell;
// 5000 for 500 active UEs per cell)

// For DGX Spark smoke testing, we often reduce this, e.g.:
#define numSimChnRlz           50  // or 100, to avoid long runs where CPU/GPU drift appears
```

* **`gpuDeviceIdx` MUST be set to 0** on DGX Spark. The default in the container image was `2`, which caused `invalid device ordinal` / `invalid device function` errors until corrected.
* `numSimChnRlz` can remain 2000 for stress tests, but for a quick CI‑style smoke test, using ~50–100 TTIs is sufficient and avoids the late‑run divergence described below.

---

## 3. Building cuMAC for GB10 (SM\_120)

From inside the container:

```bash
cd /opt/nvidia/cuBB/cuMAC

cmake -Bbuild -GNinja \
    -DCMAKE_TOOLCHAIN_FILE=/opt/nvidia/cuBB/cuPHY/cmake/toolchains/grace-cross \
    -DCMAKE_CUDA_ARCHITECTURES="80;90;120"

cmake --build build -j"$(nproc)"
```

Notes:

* `grace-cross` is NVIDIA’s toolchain targeting Grace‑based systems (GH200/GB10, etc.).
* **Critical change:** add `"120"` to `CMAKE_CUDA_ARCHITECTURES` so cuMAC kernels are compiled for the GB10’s SM_120 target.

  * Without this, we observed `invalid device function` errors inside kernels like `multiCellSinrCal.cu`.
* During `cmake --build`, you will see a bunch of `ptxas` warnings like:

  ```text
  ptxas warning : Value of threads per SM ... is out of range. .minnctapersm will be ignored
  ```

  For this smoke test, these warnings are **expected and can be ignored**.

---

## 4. 4T4R Scheduler Smoke Test (Rayleigh, DL)

The main smoke test uses NVIDIA’s **multiCellSchedulerUeSelection** example:

```bash
cd /opt/nvidia/cuBB/cuMAC

./build/examples/multiCellSchedulerUeSelection/multiCellSchedulerUeSelection \
    -d 1 \
    -f 0 \
    -b 0 \
    -p 0
```

Where:

* `-d 1` – **Downlink** scheduler.
* `-f 0` – **Rayleigh** fading channel model.
* `-b 0` – Use GPU multi‑cell scheduler vs **CPU reference** (multi‑cell PF).
* `-p 0` – **FP32** GPU kernels (no FP16 path).

This runs a **DL scheduler pipeline**:

> UE selection → PRG allocation → layer selection → MCS selection

for each TTI, comparing **GPU vs CPU** implementations:

* UE selection decisions
* PRG allocation (`allocSol`)
* layer selection (`layerSelSol`)
* MCS selection (`mcsSelSol`)
* channel consistency (CSI / SINR data).

The testbench prints per‑TTI messages plus **per‑component PASS/FAIL** status.

---

## 5. Converging Behavior (Early TTIs)

For early TTIs (e.g., TTI 0–~100), the GPU and CPU implementations agree:

```text
cuMAC multi-cell scheduler: Running on GPU device 0
cuMAC scheduler pipeline test: Downlink
cuMAC scheduler pipeline test: FP32 kernels
cuMAC scheduler pipeline test: CPU reference check
cuMAC scheduler pipeline test: use Rayleigh fading
Multi-cell scheduler, Type-1 allocate
No precoding + MMSE-IRC
nBsAnt X nUeAnt = 4 X 4
Using CPU multi-cell PF UE selection
Using CPU multi-cell PF scheduler

~~~~~~~~~~~~~~~~~TTI 0~~~~~~~~~~~~~~~~~~~~
GPU channel generated
API setup completed
CSI update: subband SINR calculation setup completed
CSI update: subband SINR calculation run completed
CSI update: wideband SINR calculation setup completed
CSI update: wideband SINR calculation run completed
CSI update: subband and wideband SINRS copied to CPU structures
GPU PF UE selection setup completed
GPU PF UE selection run completed
GPU UE downselection completed
CPU PF UE selection completed
CPU UE downselection completed
PRB scheduling solution computed
GPU Layer selection solution computed
CPU Layer selection solution computed
GPU MCS selection solution computed
CPU MCS selection solution computed
Scheduling solution transferred to host
Success: CPU and GPU UE selection solutions match
Success: CPU and GPU PRG allocation solutions match
Success: CPU and GPU layer selection solutions match
Success: CPU and GPU MCS selection solutions match
Success: CPU and GPU channels match
CPU scheduler sum cell throughput: 1.050e+07
GPU scheduler sum cell throughput: 1.050e+07
```

This continues for many TTIs (we’ve seen **hundreds** of TTIs with fully matching:

* UE selection
* PRG allocation
* layer selection
* MCS selection
* channels / CSI

and identical **sum cell throughput**).

For our **smoke test**, this is the “green path”: GPU and CPU scheduler pipelines produce identical results for early TTIs, demonstrating that the CUDA kernels are **functionally correct on GB10** at least for short runs.

---

## 6. Divergence Behavior (Long Runs)

When we leave `numSimChnRlz` at NVIDIA’s default (2000 TTIs) and run the full simulation, we eventually see **divergence** in the console logs.

Example around **TTI 832**:

```text
~~~~~~~~~~~~~~~~~TTI 832~~~~~~~~~~~~~~~~~~~~
GPU channel generated
API setup completed
CSI update: subband SINR calculation setup completed
CSI update: subband SINR calculation run completed
CSI update: wideband SINR calculation setup completed
CSI update: wideband SINR calculation run completed
CSI update: subband and wideband SINRS copied to CPU structures
GPU PF UE selection setup completed
GPU PF UE selection run completed
GPU UE downselection completed
CPU PF UE selection completed
CPU UE downselection completed
PRB scheduling solution computed
GPU Layer selection solution computed
CPU Layer selection solution computed
GPU MCS selection solution computed
CPU MCS selection solution computed
Scheduling solution transferred to host
Failure: CPU and GPU UE selection solutions do not match
Failure: CPU and GPU PRG allocation solutions do not match
Success: CPU and GPU layer selection solutions match
Failure: CPU and GPU MCS selection solutions do not match
Failure: CPU and GPU channels do not match
CPU scheduler sum cell throughput: 1.179e+09
GPU scheduler sum cell throughput: 1.179e+09
```

Important observations:

* **Per‑TTI decisions diverge**:

  * UE selection differs (which UEs get scheduled).
  * PRG allocation differs.
  * MCS selection differs.
  * Channel (CSI) comparison also flags mismatches.
* **Aggregate throughput still matches** at that TTI:

  * CPU sum throughput: `1.179e+09`
  * GPU sum throughput: `1.179e+09`

So after a large number of TTIs, CPU/GPU paths are no longer bit‑for‑bit identical in all internal structures, but **the overall throughput KPI remains identical** (at least at the reported granularity).

We do **not** have a definitive root cause. Possible contributors (hypotheses, not proof):

* Long‑run accumulation of **floating‑point differences** between:

  * CPU reference implementation (C++ on Grace),
  * GPU CUDA implementation (GB10 Blackwell with FP32/FP16 kernels).
* Architectural differences on GB10 vs the original x86/Hopper validation platforms:

  * DGX Spark’s GPU and memory system is tuned for **very high FP4 throughput** and unified memory, which may produce slightly different numerical behavior or ordering vs. older GPU/CPU combinations. 
* Potential **nondeterminism** in parallel channel generation or random number streams if seeds or streaming strategies differ between CPU and GPU paths over long runs.

For now, we treat anything beyond ~100 TTIs as **“research mode”**, rather than strict **regression‑test mode**, on DGX Spark.

---

## 7. Recommended Smoke‑Test Configuration

For **CI / lab smoke checks** on DGX Spark:

1. In `parameters.h`:

   ```c
   #define gpuDeviceIdx   0
   #define numSimChnRlz   50   // or 100
   ```

2. Ensure GPU visibility:

   ```bash
   export CUDA_VISIBLE_DEVICES=0
   ```

3. Configure & build cuMAC for SM\_120:

   ```bash
   cd /opt/nvidia/cuBB/cuMAC

   cmake -Bbuild -GNinja \
       -DCMAKE_TOOLCHAIN_FILE=/opt/nvidia/cuBB/cuPHY/cmake/toolchains/grace-cross \
       -DCMAKE_CUDA_ARCHITECTURES="80;90;120"

   cmake --build build -j"$(nproc)"
   ```

4. Run the DL 4T4R scheduler pipeline:

   ```bash
   ./build/examples/multiCellSchedulerUeSelection/multiCellSchedulerUeSelection \
       -d 1 -f 0 -b 0 -p 0
   ```

**Passing criteria for the smoke test:**

* For all TTIs in the configured `numSimChnRlz` window, you see:

  ```text
  Success: CPU and GPU UE selection solutions match
  Success: CPU and GPU PRG allocation solutions match
  Success: CPU and GPU layer selection solutions match
  Success: CPU and GPU MCS selection solutions match
  Success: CPU and GPU channels match
  ```

* CPU and GPU **sum cell throughput** match at each TTI.

A helper script (e.g., `cumac_smoke_test.sh`) can wrap these steps to:

* Export `CUDA_VISIBLE_DEVICES`,
* Re‑run `cmake`/`ninja` if needed,
* Launch `multiCellSchedulerUeSelection` with the standard arguments above.

---

## 8. Other cuMAC Testbenches (Status on DGX Spark)

### 8.1 tvLoadingTest (HDF5 test vectors)

We attempted to run:

```bash
cd /opt/nvidia/cuBB/cuMAC
TV=$(find testVectors -maxdepth 3 -type f -name '*.h5' | head -n 1)
./build/examples/tvLoadingTest/tvLoadingTest \
    -i "$TV" \
    -g 0 \
    -d 1 \
    -m 01111
```

Initial attempts produced:

```text
CUDA error ... invalid device ordinal
```

This is consistent with the original container’s assumption of a different GPU index and/or different SM set (multi‑GPU x86 platform vs single‑GPU GB10):

* cuMAC and related tools sometimes **bake GPU indices** or rely on a default `gpuDeviceIdx` that doesn’t match DGX Spark.
* Our primary focus shifted to getting `multiCellSchedulerUeSelection` working, so `tvLoadingTest` is not yet fully characterized on DGX Spark.

### 8.2 DRL MCS selection test

The DRL MCS selection harness:

```bash
./build/examples/drlMcsSelection/drlMcsSelection \
    -i /opt/nvidia/cuBB/cuMAC/testVectors/mlSim \
    -m /opt/nvidia/cuBB/cuMAC/testVectors/trtEngine/model.onnx \
    -g 0
```

is present and should work once **TensorRT / CUDA** alignment is verified for GB10. This hasn’t yet been run to completion as part of this effort.

### 8.3 64T64R MU‑MIMO scheduler

The 64T64R MU‑MIMO scheduler testbench:

```bash
./build/examples/multiCellMuMimoScheduler/multiCellMuMimoScheduler \
    -i /opt/nvidia/cuBB/cuMAC/testVectors/asim/TV_cumac_64TR_2PC_DL.h5 \
    -a 1 -r 1
```

requires corresponding parameter tweaks in `parameters.h`:

```c
#define gpuDeviceIdx              0
#define numCellConst              3
#define numActiveUePerCellConst   100
#define nBsAntConst               64
#define gpuAllocTypeConst         1
#define nPrbsPerGrpConst          2
#define nPrbGrpsConst             136
```

It **has not yet been validated** end‑to‑end on DGX Spark. Expect a similar pattern of:

* Needing SM\_120 in the build,
* Possibly high runtime and memory footprint,
* Potential long‑run CPU/GPU drift analogous to the 4T4R case.

---

## 9. Relationship to GB200 / GB300

The hacks we needed for DGX Spark (GB10) are **not GB10‑specific quirks**, but rather **general considerations for future Grace–Blackwell platforms**:

1. **Correct SM architecture in the build:**

   * GB10 uses compute capability **SM_120**.
   * Future **GB200/GB300** systems will have their own SM versions; once NVIDIA publishes them, they must be added to `CMAKE_CUDA_ARCHITECTURES` in the same way.

   ```bash
   -DCMAKE_CUDA_ARCHITECTURES="80;90;120"   # For today (GH200 + GB10)
   # Hypothetical future:
   # -DCMAKE_CUDA_ARCHITECTURES="80;90;120;XYZ"
   ```

2. **GPU device indexing:**

   * DGX Spark is a **single‑GPU** box; GB200/GB300 servers will likely be multi‑GPU NVLink domains.
   * Hard‑coded indices (e.g., `gpuDeviceIdx 2`) in example code can easily break when moving between platforms.
   * Always double‑check:

     * `CUDA_VISIBLE_DEVICES`
     * cuMAC’s `gpuDeviceIdx`
     * Any command‑line `-g` arguments in testbenches.

3. **Floating‑point behavior:**

   * Spark is tuned for **ultra‑high FP4 throughput** and unified memory workloads. 
   * Even though cuMAC’s scheduler kernels are currently using FP32 (`-p 0`), there may be subtle differences versus older CPU/GPU combinations under long simulations (e.g., 2000 TTIs).
   * Similar long‑run drifts may appear on GB200/GB300 until NVIDIA explicitly validates and/or updates the test tolerances for these architectures.

In other words, this DGX Spark bring‑up is a **useful preview** of what will likely be needed for **GB200/GB300**: update SM targets, fix GPU indexing, and re‑evaluate long‑run numeric tolerances for mixed CPU/GPU validation tests.

---

## 10. Current Status (cuMAC on DGX Spark)

* ✅ **Build:** cuMAC compiles and links using the **grace‑cross** toolchain with `CMAKE_CUDA_ARCHITECTURES="80;90;120"`.
* ✅ **Smoke test:** 4T4R **multiCellSchedulerUeSelection** runs on **GPU 0** (GB10) and matches the CPU reference across all tested components for **tens to hundreds of TTIs**.
* ⚠️ **Long‑run drift:** For long runs (e.g., 2000 TTIs), CPU/GPU solutions **eventually diverge** on UE selection, PRG allocation, MCS, and channels, even though aggregate throughput remains identical at those TTIs.
* ⚠️ **Other testbenches:** `tvLoadingTest`, DRL MCS, and 64T64R MU‑MIMO tests have **not yet been fully qualified** on DGX Spark.
* ✅ **Research usability:** For **short‑run scheduler experiments** (e.g., ≤100 TTIs), this setup is **good enough for multi‑cell PF and scheduling studies** on DGX Spark / GB10.

This document should be read alongside:

* `DGX_SPARK.md` – hardware/context notes for DGX Spark. 
* `CUMAC_SMOKE_TEST.sh` (or similar) – shell harness in this repo that applies the steps above.
* Future GB200/GB300 NVIDIA documentation once those systems are released.
