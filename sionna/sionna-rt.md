# Sionna RT — Differentiable Ray Tracing for Radio Propagation

[Sionna RT docs → nvlabs.github.io/sionna/rt](https://nvlabs.github.io/sionna/rt/index.html)

Sionna RT is a **hardware-accelerated, differentiable ray tracer** for radio propagation. It produces environment-specific, spatially consistent channels (paths → CIR/CFR/taps) and exposes **gradients** w.r.t. scene, materials, antennas, positions/orientations, and array geometry—unlocking gradient-based optimization (e.g., learning radio materials, optimizing TX orientation) and ML-in-the-loop workflows for 6G and digital twins. 

> **Reference:** J. Hoydis *et al.*, “Sionna RT: Differentiable Ray Tracing for Radio Propagation Modeling,” *IEEE Globecom Workshops*, 2023, pp. 317–321, doi:10.1109/GCWkshps58843.2023.10465179.

---

## Why it matters

* **Spatial consistency:** Scene-anchored channels vs. stochastic models; crucial for DTs, localization, RIS/ISAC studies. 
* **End-to-end gradients:** Differentiate CIRs, coverage maps, etc., w.r.t. **materials (εr, σ), antenna patterns, array geometry, poses**—enabling calibration and design via gradient descent. 
* **Seamless handoff to PHY:** CIRs feed directly into link-level simulations (Sionna PHY/SYS). 

---

## Architecture at a glance

* **Mitsuba 3 + Dr.Jit** handle scene I/O (XML), intersections, and differentiable rendering infrastructure.
* **TensorFlow** computes polarized field transformations along paths and assembles time-varying **CIRs/CFRs** with auto-diff. 

---

## Core capabilities

* **Scenes & cameras:** Load built-ins (e.g., Munich, Étoile) or Blender-exported Mitsuba XML; preview, render stills. *(Listings & figures in paper)* 
* **Devices & arrays:** Define **PlanarArray** for TX/RX (explicit per-element paths or synthetic plane-wave arrays). 
* **Propagation:** LoS, **specular reflections**, optional **diffuse** scattering; first-order diffraction; max interaction depth. 
* **Solvers:**

  * **PathSolver** → geometric paths (+ Doppler via object velocities)
  * **RadioMapSolver** → path-gain/RSS/SINR maps for regions/planes 
* **Channels:** Paths → **CIR** (`paths.cir()`), **CFR** (`paths.cfr()`), **taps** (`paths.taps()`), including time evolution via Doppler. 
* **Differentiable workflows (examples):**

  * **Learn radio materials** from data (optimize εr, σ to match measured/target responses).
  * **Optimize TX orientation** to maximize regional received power/SINR. 

---

## Minimal quickstart (Python sketch)

```python
# Install: pip install sionna-rt
import sionna, numpy as np
from sionna.rt import load_scene, PlanarArray, Transmitter, Receiver, \
                      PathSolver, RadioMapSolver, subcarrier_frequencies

# 1) Load scene (try: sionna.rt.scene.munich or etoile)
scene = load_scene(sionna.rt.scene.munich)

# 2) Configure arrays for all TX/RX
scene.tx_array = PlanarArray(num_rows=1, num_cols=1, pattern="tr38901", polarization="V")
scene.rx_array = PlanarArray(num_rows=1, num_cols=1, pattern="dipole",  polarization="cross")

# 3) Place devices
tx = Transmitter(name="tx", position=[8.5,21,27]); scene.add(tx)
rx = Receiver(name="rx",  position=[45,90,1.5]);  scene.add(rx)
tx.look_at(rx)

# 4) Trace paths
paths = PathSolver()(scene=scene, max_depth=5, los=True,
                     specular_reflection=True, diffuse_reflection=False,
                     refraction=False, synthetic_array=False, seed=41)

# 5) Convert to channels
a, tau = paths.cir(normalize_delays=True, out_type="numpy")  # CIR
f = subcarrier_frequencies(1024, 30e3)
H = paths.cfr(frequencies=f, normalize=True, out_type="numpy") # CFR
T = paths.taps(bandwidth=100e6, l_min=-6, l_max=100, out_type="numpy") # taps
```

*(These steps reflect the paper’s Listings / APIs: load scene, set arrays, add TX/RX, solve paths, produce CIR/CFR/taps.)* 

---

## Best practices & notes

* **Performance:** Use `synthetic_array=True` for large arrays (plane-wave approximation); use merged shapes for complex scenes to speed up tracing. 
* **Reproducibility:** Set `seed` in the path solver; diffuse scattering uses randomized directions. 
* **Mobility:** Set `velocity` on devices/objects; call `paths.apply_doppler(...)` or request time-evolving CIRs directly. 
* **Materials:** Use ITU-style materials or define frequency-dependent functions; gradients enable calibration vs. data. 

---

## Installation pointers

* **Package:** `pip install sionna-rt` (standalone).
* **Deps:** Same baseline as **Mitsuba 3**; Dr.Jit requires **LLVM** for CPU mode. See the [RT docs](https://nvlabs.github.io/sionna/rt/index.html) for platform specifics.

---

## Citation

> J. Hoydis, S. Cammerer, F. A. Aoudia, M. Nimier-David, N. Binder, G. Marcus, and A. Keller, “**Sionna RT: Differentiable Ray Tracing for Radio Propagation Modeling**,” *2023 IEEE Globecom Workshops (GC Wkshps)*, Kuala Lumpur, Malaysia, 2023, pp. 317–321. doi: 10.1109/GCWkshps58843.2023.10465179.

*(Overview, capabilities, code listings, and examples summarized from the paper.)* 

