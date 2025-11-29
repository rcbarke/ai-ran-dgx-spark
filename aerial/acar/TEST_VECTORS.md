# TEST\_VECTORS.md
Stress-Testing cuBB cuPHY with Test Vectors (x86 + ARM/GH200)

ACAR Reference: [Generating TV and Launch Pattern Files](https://docs.nvidia.com/aerial/cuda-accelerated-ran/latest/aerial_cubb/cubb_quickstart/generating_tv.html)

## 1. Purpose

This document describes how to:

1. Generate **cuBB cuPHY test vectors (TVs)** on an x86 host using the Aerial `aerial_mcore` pipeline.
2. Use those TVs to **stress-test cuPHY**.
3. Explain why **TV generation is x86-only** (MATLAB dependency) and how **ARM hosts (DGX Spark, GH200)** must consume **pre-provided or pre-generated** TVs instead of generating their own.

Assumed root:

```bash
export cuBB_SDK=/opt/nvidia/cuBB
````

---

## 2. x86 “TV Bakery” – Generate Test Vectors Once

> This must be done on an **x86** host (e.g., Dell/Supermicro + Aerial cuBB container). MATLAB Runtime is **x86-only**, so this pipeline will not work on Arm.

Inside the x86 Aerial cuBB container:

1. **Install MATLAB Runtime and deps**
   Follow the official cuBB docs to install MATLAB Runtime R2023a and required `apt` packages inside the container.

2. **Generate the E2E OTA coeffs TV (optional if shipped)**

   ```bash
   cd ${cuBB_SDK}/5GModel/aerial_mcore/examples
   source ../scripts/setup.sh
   ../scripts/gen_e2e_ota_tvs.sh

   # Outputs:
   ls -lh GPU_test_input/
   # => cuPhyChEstCoeffs.h5
   ```

3. **Generate the full regression TV set**

   ```bash
   cd ${cuBB_SDK}/5GModel/aerial_mcore/examples
   source ../scripts/setup.sh

   export REGRESSION_MODE=1
   time python3 ./example_5GModel_regression.py allChannels

   ls -alF GPU_test_input/
   du -h GPU_test_input/
   ```

4. **Generate launch patterns for cuPHY/cuBB**

   ```bash
   cd ${cuBB_SDK}/cubb_scripts
   python3 auto_lp.py \
     -i ../5GModel/aerial_mcore/examples/GPU_test_input \
     -t launch_pattern_nrSim.yaml
   ```

5. **Publish TVs to the shared `testVectors/` repo**

   ```bash
   cd ${cuBB_SDK}

   # All .h5 test vectors
   cp ./5GModel/aerial_mcore/examples/GPU_test_input/*.h5 ./testVectors/.

   # Launch patterns for multi-cell/e2e runs
   cp ./5GModel/aerial_mcore/examples/GPU_test_input/launch_pattern* \
      ./testVectors/multi-cell/.
   ```

At this point, the x86 host acts as the **“TV bakery”**. All `.h5` test vectors and launch patterns live under:

* `${cuBB_SDK}/testVectors/`
* `${cuBB_SDK}/testVectors/multi-cell/`

These can now be **rsync’d / scp’d** to any other cuBB host (including DGX Spark and GH200).

---

## 3. Using Test Vectors to Stress-Test cuPHY

Once TVs and launch patterns are available under `${cuBB_SDK}/testVectors`, you can stress-test cuPHY (on either x86 or ARM) by:

1. **Selecting / customizing launch pattern(s)**

   The `launch_pattern*.yaml` files produced by `auto_lp.py` define which channels, bandwidths, numerologies, and MCS combinations are exercised. You can:

   * Use them directly for **full-matrix regression**, or
   * Create reduced or more aggressive patterns for **stress tests** (e.g., high MCS, many UEs, worst-case PRBs).

2. **Running cuPHY perf / regression workloads**

   From the cuBB quickstart / perf sections (examples vary by release):

   ```bash
   cd ${cuBB_SDK}
   # Example: run cuPHY with a chosen launch pattern and corresponding TVs
   # (Refer to the release-specific README for the exact invocation.)
   ./scripts/run_cuPHY_perf.sh \
      --launch-pattern ./testVectors/multi-cell/launch_pattern_nrSim.yaml \
      --tv-dir ./testVectors
   ```

3. **Measuring stress indicators**

   Typical stress metrics include:

   * cuPHY kernel latency and jitter
   * GPU utilization and memory bandwidth
   * Throughput vs. numerology / PRB load
   * Error rates for edge-case test vectors

As long as the launch pattern and TV directory are populated, **cuPHY does not care which CPU architecture generated the TVs**.

---

## 4. ARM Hosts (DGX Spark & GH200): MATLAB Limitation

### 4.1 Why MATLAB-based TV generation fails on ARM

The Aerial `aerial_mcore` module is built with **MATLAB Compiler SDK** and requires the **MATLAB Runtime** shared library:

* `libmwmclmcrrt.so.<version>`

MATLAB Runtime **R2023a** is available for **x86_64 Linux only**, not for Arm. On DGX Spark and GH200 (Grace CPU):

* Importing `aerial_mcore` attempts to locate the MATLAB Runtime in `LD_LIBRARY_PATH`.
* The required library is missing on Arm.
* Any scripts like `gen_e2e_ota_tvs.sh` or `example_5GModel_regression.py` will fail with runtime errors about `libmwmclmcrrt.so` not being found or incompatible.

Therefore:

> **TV generation using `aerial_mcore` is not supported on DGX Spark or GH200.**
> These hosts must **consume** pre-generated TVs; they cannot **produce** them with the MATLAB pipeline.

### 4.2 Using pre-provided test vectors on ARM

NVIDIA ships a minimal set of TVs (e.g., `cuPhyChEstCoeffs.h5`) in the container image for both x86 and ARM under:

```bash
/opt/nvidia/cuBB/testVectors/
```

On DGX Spark or GH200:

1. **Verify the pre-shipped E2E coeffs file:**

   ```bash
   ls -lh /opt/nvidia/cuBB/testVectors/cuPhyChEstCoeffs.h5
   ```

2. (Optional) If example scripts expect it in `GPU_test_input/`:

   ```bash
   mkdir -p ${cuBB_SDK}/5GModel/aerial_mcore/examples/GPU_test_input
   cp /opt/nvidia/cuBB/testVectors/cuPhyChEstCoeffs.h5 \
      ${cuBB_SDK}/5GModel/aerial_mcore/examples/GPU_test_input/
   ```

3. **Copy full TV sets from the x86 “TV bakery” (if needed):**

   From x86 → ARM:

   ```bash
   # On x86 host
   rsync -avz ${cuBB_SDK}/testVectors/ user@arm-host:/opt/nvidia/cuBB/testVectors/
   ```

   After that, the ARM host has the exact same `.h5` and `launch_pattern*` files as the x86 generator, and you can run the same cuPHY stress tests.

---

## 5. Summary

* **Generation** of cuBB cuPHY test vectors (`aerial_mcore` + MATLAB Runtime) is **x86-only**.
* **DGX Spark and GH200 (Grace CPU)** cannot run the MATLAB-based pipeline; they must:

  * Use **pre-provided** TVs shipped in `/opt/nvidia/cuBB/testVectors/`, and/or
  * Consume TVs that were generated once on an x86 Aerial/cuBB host and copied over.
* Once TVs and launch patterns are present under `${cuBB_SDK}/testVectors`, **cuPHY stress-testing is identical** across x86 and ARM/GH200: the GPU stack simply reads `.h5` vectors and executes the configured launch patterns.

Use this file as the reference for setting up a small **x86 TV bakery** and then running high-load cuPHY experiments on your **DGX Spark** and future **GH200** systems.
