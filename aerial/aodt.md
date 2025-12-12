# Aerial Omniverse Digital Twin (AODT)

## **IMPORTANT: Per the below documentation, there is not yet a DGX or ARM installation path within the AODT installation documentation. NVIDIA's AODT team advised [here](https://forums.developer.nvidia.com/t/aerial-omniverse-digital-twin-installer-403-unauthorized-on-ngc-dell-pathway/354367/2) that DGX support is anticipated in future releases. Please reference the formal hardware recommendations for AODT on NVIDIA's documentation, which is up to date.**

**Download Link:**

* [Aerial Omniverse Digital Twin Collection on NGC](https://registry.ngc.nvidia.com/orgs/esee5uzbruax/collections/aerial-omniverse-digital-twin)

**Documentation:**

* [Aerial Omniverse Digital Twin Documentation](https://docs.nvidia.com/aerial/aerial-dt/index.html)

---

## Overview

**Aerial Omniverse Digital Twin (AODT)** is a scalable simulation platform that integrates NVIDIA’s Omniverse framework with 5G/6G radio network simulation. AODT enables highly realistic modeling of radio environments, offering end-to-end validation of 5G/6G RAN components, from antennas to UE (User Equipment).

AODT leverages **CUDA-accelerated RAN** components and incorporates AI/ML-based analysis to enable efficient design, testing, and training for modern wireless systems. It provides flexibility in both simulating from scratch or using real-world geospatial data for precise modeling.

### Key Features:

* **Realistic Radio Simulation**: Includes physical layer models, MAC scheduling, interference, noise, and channel frequency response (CFR).
* **Complete Integration**: Combines **EM solvers** for radio propagation, **RAN Digital Twin** for network simulations, and **data lakes** for real-time dataset collection.
* **Flexible Deployment**: Supports cloud, on-premise, or hybrid configurations using NVIDIA GPUs, ensuring scalability.

---

## Key Components of AODT

### 1. **User Interface (UI)**

The graphical interface allows users to interact with the simulation environment, visualize results, and configure simulation parameters like UE mobility, RAN configurations, and ray tracing.

### 2. **Omniverse Nucleus**

The Nucleus server manages and provisions scene geometries for AODT. It enables the import of geospatial data in CityGML format and converts it into OpenUSD assets used for the simulation.

### 3. **NATS**

NATS is used for message brokering, enabling communication between the different components (UI, RAN, Scene, etc.) of AODT.

### 4. **ClickHouse Database**

Results from simulations are stored in **ClickHouse**, a high-performance database, and accessed via SQL queries for further analysis.

### 5. **Scene Importer**

The Scene Importer allows the conversion of geospatial data into OpenUSD assets, supporting **CityGML** and **OpenStreetMap (OSM)** imports.

### 6. **RAN Digital Twin**

The RAN digital twin performs key network tasks such as scheduling data transmission, generating waveforms, applying interference, and conducting signal processing for data extraction and decoding.

---

## Hardware Configuration (Ideal Setup)

### A. **Aerial Backend: GH200 Aerial RAN (Production-Grade Node)**

* **Server**: **NVIDIA Grace Hopper MGX (GH200)**

  * **GPU**: **H100 (or A100)** for high throughput & advanced parallel computing
  * **CPU**: **Grace CPU** (custom ARM-based architecture for high-efficiency compute)
* **Network Interface**: **BlueField-3 DPUs/NICs** for low-latency, high-bandwidth network offload and acceleration
* **Memory**: 512 GB+ system RAM
* **Storage**: **NVMe SSDs** with at least 2 TB capacity for storing large simulation datasets and models
* **OS**: **Ubuntu 22.04** (ensure all system drivers and CUDA versions match AODT requirements)
* **Software**: Install **Aerial Omniverse Digital Twin containers** from NGC, supporting both EM and RAN simulations.

### B. **Aerial Front-End: DGX Spark (Research/Development Node)**

* **Server**: **DGX Spark** (single-node, equipped with suitable NVIDIA GPUs)
* **Network**: 10GbE or QSFP for inter-node communication (if needed)
* **Peripherals**: HDMI monitor, USB-C peripherals (keyboard, mouse, etc.)
* **Use Case**: Ideal for **local simulation builds**, development, and **test setups** with 5G/6G protocol testing in controlled conditions (single-cell or small-scale experiments).

---

## Installation and Setup

**Prerequisites**
Before running AODT, ensure that your system meets the following requirements:

* **CUDA 12.9.1** driver version (and corresponding GPU support)
* **NVIDIA Container Toolkit** for GPU acceleration
* **Docker (19.03+)** and **NVIDIA-Docker** for containerized deployment

**Steps**

1. **Login and Pull NGC Image:**

   ```bash
   docker login nvcr.io
   docker pull nvcr.io/nvidia/aerial/aodt:latest
   ```

2. **Run AODT Container (Backend):**

   ```bash
   sudo docker run --gpus all --network host --shm-size=4096m -v ~/share:/opt/cuBB/share --name cuBB -d nvcr.io/nvidia/aerial/aodt:latest
   ```

3. **Run AODT (Frontend):**

   * Run `aodt-ui` on a separate node or colocated. Configure **ClickHouse** and **NATS** servers for multi-node setups.

4. **Access the Simulation UI:**

   * Open the **Omniverse** dashboard and access the simulation via JupyterLab or the built-in visualizer.

---

## Ideal Hardware Configuration (in Detail)

### **Grace Hopper Backend Node (Aerial GH200)**

* **GPU**: **A100 or H100**, with 48 GB+ VRAM, capable of accelerating cuPHY, cuMAC, and other network functions.
* **NIC**: BlueField-3 DPUs provide high throughput and lower latency, ideal for managing traffic across multi-cell simulations.
* **Memory**: Minimum **512 GB system RAM**, optimized for handling large datasets and simulations.
* **Storage**: At least **2 TB of NVMe SSDs**, ensuring fast read/write access to simulation data.
* **Network**: 100/200 GbE backbone for multi-cell simulations, capable of handling intensive data traffic.

### **DGX Spark Front-End (for Local Experiments)**

* **GPU**: Supported **RTX Ada or A10**, optimized for single-cell testing and algorithm development.
* **Memory**: **128 GB system RAM**, capable of supporting test setups with moderate workloads.
* **Storage**: **1 TB NVMe SSD** for local storage of simulation models and results.
* **Network**: **10 GbE** for local tests, suitable for small-scale development.
* **OS**: **Ubuntu 22.04** (Ensure all drivers are configured per requirements).

---

## Additional Setup Steps

1. **Configure Data Capture (Data Lakes)**: Set up **ClickHouse** to store RF data (I/Q samples) from the simulation. Reference Aerial Data Lake documentation for multi-cell configurations and database queries.

2. **Configure Aerial Test Suite**: Implement the necessary configurations for **Aerial TestMAC**, with testing on hardware-specific setups (e.g., RU and DU deployments, antenna panel setups).

3. **Use PyAerial**: Integrate **pyAerial** for simulating physical layer functions and channel estimation. Configure the system for neural receiver validation and ML-based training in the context of RAN digital twin environments.

4. **Monitor/Validate**: Use **NATS** for monitoring real-time simulation telemetry and validate simulation results using **ClickHouse** for querying and logging system performance metrics, including SINR, throughput, and error rates.

---

## Documentation and Support

* **Release Notes & Quickstart**: [Aerial Omniverse Digital Twin Docs](https://docs.nvidia.com/aerial/aerial-dt/index.html)
* **Developer Support**: [Aerial Developer Forum](https://forums.developer.nvidia.com/c/aerial/)

---

This setup ensures full scalability for large-scale multi-cell 5G/6G simulations, with dedicated backend nodes for complex modeling and GPU-intensive tasks, while providing flexible frontend options for developer-centric setups.

