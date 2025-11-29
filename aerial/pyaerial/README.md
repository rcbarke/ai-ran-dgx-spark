# PyAerial on DGX Spark (GB10) with cuBB 25-2

## Summary

As of **cuBB tag `25-2`**:

- ✅ **PyAerial builds successfully** on **DGX Spark with the NVIDIA GB10 superchip (ARM64)**.
- ❌ The resulting **PyAerial container does *not* start** on this platform.
- ✅ The **same cuBB 25-2 PyAerial setup runs successfully on GH200** (Grace Hopper).

The GB10 failure is caused by a **strict hardware conformance check inside the base PyAerial/cuBB container**. It is **not** due to insufficient GPU capability on GB10.

---

## Environment

- **Host system:** NVIDIA DGX Spark  
  - GPU: `NVIDIA GB10`  
  - `nvidia-smi` reports:
    - Driver Version: `580.95.05`
    - CUDA Version: `13.0`
- **Architecture:** ARM64 (aarch64)
- **cuBB SDK:** `25-2`
- **Base Aerial/cuBB image:**
  - `nvcr.io/nvidia/aerial/aerial-cuda-accelerated-ran:25-2-cubb`
- **Custom PyAerial image (overlay):**
  - Example tag: `pyaerial:ryan-25-2-cubb-arm64`

---

## What Works: Build on DGX Spark / GB10

Building the PyAerial image on DGX Spark with GB10 **completes successfully**.

### Example build output (tail)

```text
 => [stage-1 12/22] RUN python3 -m venv /opt/venv --system-site-packages                                                   1.5s
 => [stage-1 13/22] RUN if [ -f /opt/nvidia/cuBB/CMakeLists.txt ]; then     cmake -Bbuild -GNinja --log-level=warning -  143.0s
 => [stage-1 14/22] COPY --chown=aerial ./requirements.txt /tmp/                                                           0.1s 
 => [stage-1 15/22] COPY --chown=aerial ./requirements-arm64.txt /tmp/                                                     0.1s 
 => [stage-1 16/22] RUN pip install pip --upgrade &&     pip install -r /tmp/requirements.txt -r /tmp/requirements-arm64  43.9s 
 => [stage-1 17/22] COPY --chown=aerial --from=tensorflow /tmp/pip /tmp/pip                                                0.4s 
 => [stage-1 18/22] RUN pip install --no-cache-dir /tmp/pip/tensorflow-*.whl &&     pip check &&     rm -rf /tmp/pip      16.7s 
 => [stage-1 19/22] WORKDIR /tmp                                                                                           0.1s
 => [stage-1 20/22] RUN wget -q https://download.pytorch.org/whl/triton-3.3.1-cp310-cp310-manylinux_2_27_aarch64.manyli  108.1s
 => [stage-1 21/22] RUN rm -rf /home/aerial/.cache                                                                         5.3s
 => [stage-1 22/22] WORKDIR /home/aerial                                                                                   0.1s
 => exporting to image                                                                                                     7.5s
 => => exporting layers                                                                                                    7.5s
 => => writing image sha256:1e65b7396d6ef83bc438e69fc624ba727e1fee44353f29cc5c36950845dd27f6                               0.0s
 => => naming to docker.io/library/pyaerial:ryan-25-2-cubb-arm64                                                           0.0s
````

The built image is visible:

```bash
$ docker image ls
REPOSITORY                                          TAG                          IMAGE ID       CREATED              SIZE
pyaerial                                            ryan-25-2-cubb-arm64         1e65b7396d6e   About a minute ago   40.8GB
tensorflow-with-whl-for-arm                         latest                       15acc1332d06   11 hours ago         30.7GB
nvcr.io/nvidia/aerial/aerial-cuda-accelerated-ran   25-2-cubb                    a4d6066bbc21   4 months ago         28.3GB
nvidia/cuda                                         12.4.1-runtime-ubuntu22.04   1e6b8889e9e6   19 months ago        2.1GB
```

**Conclusion:** For cuBB `25-2`, **PyAerial builds cleanly on DGX Spark / GB10**.

---

## What Fails: Container Runtime on DGX Spark / GB10

Starting the PyAerial container via the cuBB helper script **fails immediately** on DGX Spark / GB10.

### Example run invocation

```bash
$ ${cuBB_SDK}/pyaerial/container/run.sh
/home/ryan/aerial-dgx-spark/aerial/acar/cuBB/pyaerial/container/run.sh starting...
Start container instance at bash prompt

==========
== CUDA ==
==========

CUDA Version 12.9.1

Container image Copyright (c) 2016-2023, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
Copyright 2017-2024 The TensorFlow Authors.  All rights reserved.

This container image and its contents are governed by the NVIDIA Deep Learning Container License.
By pulling and using the container, you accept the terms and conditions of this license:
https://developer.nvidia.com/ngc/nvidia-deep-learning-container-license

A copy of this license is made available in this container at /NGC-DL-CONTAINER-LICENSE for your convenience.
WARNING: Detected NVIDIA GB10 GPU, which is not yet supported in this version of the container
ERROR: No supported GPU(s) detected to run this container
```

After these messages, the container exits; the interactive PyAerial shell **never appears**.

**Key point:** The failure happens **before** any PyAerial code actually runs. It is the **container’s GPU support check** that aborts.

---

## Interpretation: Hardware Conformance Check vs. GPU Capability

From the observed behavior:

* The **image build succeeds**, including:

  * cuBB compilation,
  * Python environment creation,
  * PyAerial dependencies (TensorFlow, Triton, etc.).
* The **runtime error explicitly calls out GB10 as “not yet supported in this version of the container”**.
* The error text is:

  ```text
  WARNING: Detected NVIDIA GB10 GPU, which is not yet supported in this version of the container
  ERROR: No supported GPU(s) detected to run this container
  ```

This indicates:

* The failure is due to a **hard-coded support/allow-list check inside the base Aerial/cuBB container**, most likely tied to:

  * recognized GPU product names, or
  * driver/CUDA combinations that the container considers valid.
* **GB10 is new enough that cuBB 25-2 does not include it in that list**, so the container refuses to run, even though the host driver and hardware are capable.

In other words, this is a **software / driver support gate in the container**, *not* a question of GB10’s ability to run PyAerial workloads.

---

## Comparison: GH200 vs. GB10

Empirically:

* On a **GH200 (Grace Hopper)** platform with cuBB `25-2`:

  * The same base image and PyAerial overlay **build and run successfully**.
* On **DGX Spark / GB10** with cuBB `25-2`:

  * **Build:** succeeds.
  * **Runtime:** fails at the GPU support check with “No supported GPU(s) detected”.

Summary table:

| Platform                    | Architecture | cuBB `25-2` PyAerial Build | cuBB `25-2` PyAerial Runtime   |
| --------------------------- | ------------ | -------------------------- | ------------------------------ |
| DGX Spark (NVIDIA GB10)     | Arm64        | ✅ Succeeds                 | ❌ Fails: “No supported GPU(s)” |
| GH200 (Grace Hopper server) | Arm64/x86    | ✅ Succeeds                 | ✅ Container runs               |

---

## Practical Implications

* For **cuBB `25-2`**:

  * DGX Spark / GB10 can be used to **validate PyAerial builds**, but
  * the **PyAerial container cannot currently be deployed** due to the GB10 support gate in the base image.
* **GH200 platforms** are currently the better match for **running** PyAerial with cuBB `25-2`.

This document should be updated once a future cuBB/Aerial release adds **explicit GB10 support**, allowing the PyAerial container to both build and run on DGX Spark.
