# Sionna — PHY & SYS Overview

Docs: [https://nvlabs.github.io/sionna/index.html#](https://nvlabs.github.io/sionna/index.html#)

Sionna™ is a hardware-accelerated, **differentiable** open-source library for communication-system research. Its core ideas are **modularity**, **extensibility**, and **end-to-end differentiability**, so you can assemble complex links the same way you stack layers in a neural network. 

> Modules
> • **Sionna PHY** — link-level simulation for wireless & optical systems
> • **Sionna SYS** — system-level studies via physical-layer abstraction
> • **Sionna RT** — differentiable ray tracing (documented separately in `sionna-rt.md`)

---

## What the introductory paper emphasizes (why Sionna exists)

* **Rapid prototyping** with a high-level Python/TensorFlow API; GPU acceleration enables interactive exploration (e.g., notebooks).
* **Benchmarking** against carefully tested, state-of-the-art algorithms to save time on “supporting” components.
* **Native ML integration** and **automatic gradients** through the whole chain for AI-native air-interface work.
* **Scale & realism**: supports realistic 3GPP-style channels and large batch/tensor execution on single or multi-GPU.
* **Reproducibility**: encourages sharing code and components for apples-to-apples comparisons. 

---

## Design principles you should know

* **Tensor-first, batch-parallel** execution (avoid Python loops) → efficient GPU use.
* **Everything is a Keras Layer** → plug-and-play, easy replacement with learned blocks; gradients flow end-to-end.
* Supports eager & graph modes; most layers are XLA/JIT-compatible for extra speed. Default dtype is `tf.complex64`. 

---

## Sionna PHY (link-level)

**Purpose.** Build end-to-end differentiable links (bits → FEC → modulation → channel → demap → decode) and train/benchmark classical and ML-based blocks.

**Feature snapshot** (non-exhaustive):

* **FEC**: 5G **LDPC** & **Polar** (with rate-matching), CRC, convolutional & RM codes; BP, SC/SCL/SCL-CRC, Viterbi; EXIT.
* **Channels**: AWGN; flat-fading with correlation; **3GPP TR 38.901** TDL/CDL/UMa/UMi/RMa; time or frequency-domain outputs; dataset import.
* **MIMO**: multi-user/multi-cell; 3GPP & custom arrays/patterns; ZF precoding; MMSE equalization.
* **OFDM**: modulation/demod, CP, flexible 5G-like frame & pilots; LS estimation + nearest-neighbor interpolation.
* Metrics: BER/BLER, MI, etc. 

**When to use**: classical link studies, learned demappers/decoders, ablations across SNR/fading/code rates, generating datasets for higher-level ML.

---

## Sionna SYS (system-level)

**Purpose.** Run faster network-scale studies using **physical-layer abstraction** that maps link behavior (e.g., BLER vs. SINR) into system simulations.

**Highlights**: multi-user/multi-cell helpers, scheduler/interference studies, coverage & throughput distributions, outage/fairness KPIs; can ingest link-level results or analytical mappings. 

---

## Minimal “Hello World” (link-level)

A tiny example: bits → 5G LDPC → 16-QAM → AWGN → LLR demap → LDPC decode → BER. (Adapted from the paper’s Listing 1.) 

> Install:
>
> ```bash
> pip install sionna
> ```

```python
import tensorflow as tf
from sionna.utils import BinarySource, ebnodb2no, compute_ber
from sionna.fec.ldpc.encoding import LDPC5GEncoder
from sionna.fec.ldpc.decoding import LDPC5GDecoder
from sionna.mapping import Constellation, Mapper, Demapper
from sionna.channel.awgn import AWGN

# Parameters
bs = 1024          # batch size
k, n = 512, 1024   # LDPC info/codeword lengths
m = 4              # 16-QAM
ebnodb = 6.0       # Eb/N0 [dB]

const = Constellation("qam", m)
rate = k / n
no = ebnodb2no(ebnodb, rate, const.energy_norm)

# Layers
src   = BinarySource()
enc   = LDPC5GEncoder(k, n)
dec   = LDPC5GDecoder(enc)
mapx  = Mapper(constellation=const)
demap = Demapper(demapping_method="app", constellation=const)
awgn  = AWGN()

# Graph
b = src([bs, k])
c = enc(b)
x = mapx(c)
y = awgn([x, no])
llr = demap([y, no])
b_hat = dec(llr)
ber = compute_ber(b, b_hat)

print(f"BER @ Eb/N0={ebnodb:.1f} dB : {float(ber.numpy()):.3e}")
```

**Next steps**

* Sweep `ebnodb` and plot BER.
* Replace `Demapper` with an NN demapper (drop-in Keras layer) and/or make the **Constellation** trainable (see paper Listings 2–3). 

---

## Performance & limitations (from the paper)

* **GPU memory** can bottleneck very large batches → reduce batch size or distribute across multiple GPUs.
* Algorithms with complex per-example control flow may need **custom TensorFlow ops in C++/CUDA** for speed/clarity; gradients can be defined to keep differentiability. 

---

## Research Kit (deployment note)

The **Sionna Research Kit (SRK)** lets you deploy trained AI/ML components in a real software-defined 5G NR RAN (OpenAirInterface; Jetson platform). 

---

## License

Apache-2.0 (see `LICENSE`). 

---

### See also

* **Sionna RT (differentiable ray tracing)** → `sionna-rt.md`
* Docs home: [https://nvlabs.github.io/sionna/index.html#](https://nvlabs.github.io/sionna/index.html#)
* Paper: Hoydis *et al.*, *“Sionna: An Open-Source Library for Next-Generation Physical Layer Research,”* arXiv:2203.11854 (2023). 