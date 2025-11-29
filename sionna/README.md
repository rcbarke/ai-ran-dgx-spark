# Sionna — Docs Index

Quick landing page for everything Sionna in this repo. Use the table or jump links to dive in.

## Jump links

* [Sionna — PHY & SYS Overview](./sionna.md) 
* [Sionna RT — Differentiable Ray Tracing](./sionna-rt.md) 
* [Sionna Research Kit (RK) — Jetson/OAI (soft-RT) Testbed](./sionna-rk.md) 
* [Sionna vs. NVIDIA Aerial — What to Use, When](./sionna_vs_aerial.md) 

---

## What’s in each doc

| File                                           | Purpose                                                                                                             | When to use                                                                     |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [`sionna.md`](./sionna.md)                     | Big-picture of **Sionna PHY/SYS** plus a minimal “Hello World” (LDPC + QAM + AWGN) example.                         | Link/system simulations, differentiable pipelines, ML-in-the-loop training.     |
| [`sionna-rt.md`](./sionna-rt.md)               | **Sionna-RT** primer with code sketch (load scene → paths → CIR/CFR/taps), references, and best practices.          | Need **scene-anchored**, gradient-friendly propagation for DTs or calibration.  |
| [`sionna-rk.md`](./sionna-rk.md)               | **Sionna-RK** (Jetson + OAI) quickstart and **RT vs non-RT** clarification (kernel-level soft-RT vs. non-RT stack). | Validate ML PHY under **real timing** on a low-cost bench; prototype AI-RAN.    |
| [`sionna_vs_aerial.md`](./sionna_vs_aerial.md) | Side-by-side chooser across **Sionna PHY/SYS**, **Sionna-RT**, **Sionna-RK**, **ACAR**, and **AODT**.               | Picking the right toolchain; migration paths (sim → soft-RT → DT).              |

---

## External references

* Sionna docs: [https://nvlabs.github.io/sionna/](https://nvlabs.github.io/sionna/)
* Sionna RT docs: [https://nvlabs.github.io/sionna/rt/](https://nvlabs.github.io/sionna/rt/)
* Sionna RK docs: [https://nvlabs.github.io/sionna/rk/](https://nvlabs.github.io/sionna/rk/)
