# EV-Solar-Sim

![EvSolarSim Dashboard](https://i.imgur.com/KxE6Xj8.png)

## Digital Twin Framework for EV Charging Optimization

A dynamic, computation-driven platform for optimizing Electric Vehicle (EV) charging infrastructure and policy planning in localized urban systems.

### Overview and Contribution

This repository provides the source code for a novel **Digital Twin framework** designed to manage the complexities of accelerating EV adoption in urban environments. We advance beyond traditional static models by integrating **agent-based decision support** with embedded metaheuristic optimization.

Our core contribution is a flexible, computation-driven platform for EV infrastructure planning, with a **transferable, modular design**.

---

## Technical Stack and Setup

This project uses GAMA for agent-based simulation and Jupyter Notebook for post-simulation data analysis.

### Prerequisites

* **GAMA Platform 1.9.3**
* **Python 3.8+** (for data analysis in Jupyter Notebook)

### Installation

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/dolinh11/EV-Solar-Sim
    cd EV-Solar-Sim
    ```

2.  **GAMA Import:**
    * Import the cloned `EvSolarSim` repository folder directly into the **GAMA Platform** workspace.

3.  **Install Python Dependencies:**
    * Install all required Python packages for data analysis.

4.  **Data Placement:**
    * Place all new data files (map, weather data, etc.) into the designated folder: `./includes`

### Configuration Notes

* To tune the model for a new location, modify the driver behavior in `./models/traffic.gaml` and charging station configurations in `./models/charging_station.gaml`.

> **Attention (Ensure variable names are consistent):** The structure remains the same, but you can tune the logic and map to match your localized urban systems.

---

## Run and Analyze

1.  **Run Simulation:**
    * Run the main simulation file in the GAMA Platform: `./models/main.gaml`
2.  **Download Data:**
    * Download the simulation output data into the dedicated folder: `./res_data`
3.  **Analysis:**
    * Run the analysis notebook in Jupyter Notebook: `Data Analysis.ipynb`

---

## ⚖️ License and Citation

### Citation

If you use this framework or data in your research, please cite our corresponding work. We recommend citing the ArXiv preprint first:

