#!/usr/bin/env bash
set -euo pipefail

# Basic environment
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}
export cuBB_SDK=/opt/nvidia/cuBB

cd "${cuBB_SDK}/cuMAC"

echo "[cuMAC] Using GPU ${CUDA_VISIBLE_DEVICES}"
nvidia-smi || echo "[WARN] nvidia-smi not available inside container"

# 1) Configure for Grace/ARM + GB10 (sm_120 added)
cmake -Bbuild -GNinja \
    -DCMAKE_TOOLCHAIN_FILE="${cuBB_SDK}/cuPHY/cmake/toolchains/grace-cross" \
    -DCMAKE_CUDA_ARCHITECTURES="80;90;120"

# 2) Build
cmake --build build -j"$(nproc)"

# 3) (Optional) sanity tweak in examples/parameters.h:
#    - gpuDeviceIdx = 0
#    - numSimChnRlz = 200   # shorter run for a quick smoke test
#    You can bake those into your repo as a patched parameters.h.

BIN=./build/examples/multiCellSchedulerUeSelection/multiCellSchedulerUeSelection

echo "[cuMAC] Running 4T4R DL PF scheduler smoke test (GPU vs CPU)..."
echo "[cuMAC]   -d 1  (DL)"
echo "[cuMAC]   -f 0  (Rayleigh fading)"
echo "[cuMAC]   -b 0  (CPU reference enabled)"
echo "[cuMAC]   -p 0  (FP32 GPU kernels)"

set +e
${BIN} -d 1 -f 0 -b 0 -p 0
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
    echo "[PASS] cuMAC DL 4T4R GPU/CPU consistency test (exit code ${rc})"
else
    echo "[FAIL] cuMAC DL 4T4R testbench returned ${rc} – see logs above for details."
fi

exit "$rc"

