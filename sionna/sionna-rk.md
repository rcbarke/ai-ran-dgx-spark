# Sionna Research Kit (RK) — GPU-Accelerated AI-RAN Testbed (soft-RT)

Docs: [https://nvlabs.github.io/sionna/rk/index.html](https://nvlabs.github.io/sionna/rk/index.html)

**Sionna RK** is a compact, affordable research platform that brings AI/ML components into a standards-compliant 5G NR stack on **NVIDIA Jetson AGX Orin** with **OpenAirInterface (OAI)**. It enables **inline GPU-accelerated signal processing** and **on-device ML inference** for AI-RAN experiments using COTS UE. **RK demonstrates real-time (soft-RT) performance for selected PHY/ML kernels**, while the **end-to-end RAN stack remains non-real-time** (OAI on general-purpose Linux). 

> **Citation:** S. Cammerer *et al.*, “Sionna Research Kit: A GPU-Accelerated Research Platform for AI-RAN,” *IEEE ICMLCN*, 2025, pp. 1–2. doi:10.1109/ICMLCN64995.2025.11140427. 

---

## Real-Time vs. Non-Real-Time: What RK Actually Guarantees

* **Overall stack (OAI): non-real-time.**
  OAI runs on general-purpose Linux and does **not** provide hard real-time determinism for the full DU/gNB pipeline. Treat end-to-end behavior as **research-grade / soft-RT**, suitable for functional validation and algorithm prototyping—not carrier-grade, time-deterministic operation. 

* **RT where it counts (select PHY/ML kernels): real-time-capable.**
  RK demonstrates **inline** GPU stages on Jetson (shared CPU-GPU **unified memory**) to minimize copy overhead, enabling **real-time signal processing and ML inference** for targeted blocks (e.g., **neural receiver with TensorRT**, **CUDA-accelerated LDPC decoding**) under realistic latency budgets. 

* **Design implication:**
  Use RK to (i) measure **per-block latency/throughput**, (ii) validate **ML-in-the-loop PHY** under **tight timing**, and (iii) iterate on algorithm/engine constraints. Do **not** assume hard-RT guarantees for the full RAN stack (TTI scheduling, fronthaul timing, etc.). 

---

## Why RK?

* **Bridge sim → real:** Train with **Sionna** (PHY/SYS), deploy into a **live 5G NR** setup, and validate ML components under measured latency/throughput constraints. 
* **Inline acceleration:** Jetson’s **unified memory** favors **inline** GPU kernels over look-aside offload, reducing transfers and jitter for soft-RT behavior. 
* **Low barrier to entry:** Dockerized OAI, scripts, and tutorials; a table-top demo (USRP + Jetson + COTS 5G modem). 

---

## Architecture (high level)

* **Platform:** NVIDIA **Jetson AGX Orin** (CUDA, TensorRT)
* **RAN stack:** **OpenAirInterface** (gNB + core), containerized
* **I/O:** Ettus **USRP B210** (RF) and **Quectel RM520N-GL** (UE)
* **ML path:** Train in **Sionna**, export with **TensorRT**, deploy **inline** in RK’s pipeline 

---

## Capabilities (examples)

* **Standard-compliant Neural Receiver (NRX):** Real-time inference on Jetson; **BLER/SNR** vs. **network depth/latency** trade-offs. 
* **CUDA-accelerated LDPC:** Integrated into OAI with caching/transfer tuning; unified memory reduces copy overhead. 

---

## Quickstart (abridged)

```bash
git clone https://github.com/NVlabs/sionna-rk.git
cd sionna-rk
make prepare-system
sudo reboot

make sionna-rk
# RF simulator (no RF HW)
./scripts/start_system.sh rfsim_arm64
# Real RF (set B210 serial in config/b200_arm64/.env)
./scripts/start_system.sh b200_arm64

docker ps -a
docker logs -f oai-gnb
```

> **Regulatory note:** Start cabled with attenuators; follow local OTA rules. 

---

## Interop with Sionna

* Train in **Sionna**, export to **TensorRT**, deploy inside RK (e.g., neural demapper/receiver).
* Use RK **plugins** for **data acquisition** to build real-world datasets (sim↔real loop). 

---

## Hardware (reference)

* **Jetson AGX Orin** (NVMe recommended)
* **Ettus USRP B210/B206mini**, **Quectel RM520N-GL**, programmable SIMs
* RF cables/splitters/attenuators or antennas (for OTA)
* *DGX Spark support noted as forthcoming.* 

---

## Best Practices

* Profile **end-to-end latency** (I/O → CUDA/TensorRT → stack interaction).
* Keep ML blocks **inline**; avoid unnecessary host-device copies.
* Treat RK as **soft-RT**: validate per-block deadlines; do not rely on hard-RT end-to-end guarantees. 

---

## BibTeX

```bibtex
@INPROCEEDINGS{Cammerer2025_SionnaRK,
  author={Cammerer, Sebastian and Marcus, Guillermo and Zirr, Tobias and Aït Aoudia, Fayçal and Maggi, Lorenzo and Hoydis, Jakob and Keller, Alexander},
  booktitle={2025 IEEE International Conference on Machine Learning for Communication and Networking (ICMLCN)},
  title={Sionna Research Kit: A GPU-Accelerated Research Platform for AI-RAN},
  year={2025},
  pages={1-2},
  doi={10.1109/ICMLCN64995.2025.11140427},
  keywords={Cellular networks;Training;5G mobile communication;Signal processing algorithms;Signal processing;Throughput;Real-time systems;Hardware acceleration;Testing;Radio access networks}
}
```
