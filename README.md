# Stuchly–Stuchly Permittivity Extraction Pipeline

## Overview

This repository contains a MATLAB implementation of the Stuchly and Stuchly conversion algorithm for extracting complex permittivity from Vector Network Analyzer (VNA) reflection measurements.

The workflow was developed for dielectric spectroscopy applications and combines:

* S11 measurement processing
* Three-standard calibration
* Complex permittivity extraction
* Repeatability analysis
* Validation-based uncertainty estimation
* Automated plotting and result export

The pipeline processes repeated measurements directly from CSV files and generates frequency-dependent dielectric properties together with associated uncertainty estimates.

---

## Scientific Workflow

The analysis follows the sequence:

```text
Reference Permittivity Data
            +
Calibration Standard Measurements
            +
Material S11 Measurements
            ↓
 Stuchly–Stuchly Algorithm
            ↓
 Complex Permittivity
      (ε′ and ε″)
            ↓
 Uncertainty Analysis
            ↓
 Plots and CSV Export
```

---

## Repository Structure

```text
.
├── stuchly_stuchly_csv_pipeline.m
│
├── example_data/
│   ├── Reference_data/
│   └── Measurements/
│
└── Results/
```

### Reference Data

The `Reference_data` folder contains the dielectric properties of the calibration standards used by the algorithm.

Example:

```text
Reference_data/
├── reference 1.csv
├── reference 2.csv
├── reference 3.csv
└── validation solution.csv
```

Reference data may originate from:

* Published dielectric-property databases
* Analytical models (e.g. Cole–Cole)
* Measurements obtained using a validated dielectric characterization system

---

### Measurements

The `Measurements` folder contains the measured S11 responses.

Each measurement consists of three repeated acquisitions:

```text
sample 1 m1.csv
sample 1 m2.csv
sample 1 m3.csv
```

The pipeline automatically averages repeated measurements before applying the conversion algorithm.

Example:

```text
Measurements/
├── ref 1 m1.csv
├── ref 1 m2.csv
├── ref 1 m3.csv
│
├── ref 2 m1.csv
├── ref 2 m2.csv
├── ref 2 m3.csv
│
├── ref 3 m1.csv
├── ref 3 m2.csv
├── ref 3 m3.csv
│
├── sample 1 m1.csv
├── sample 1 m2.csv
├── sample 1 m3.csv
│
├── sample 2 m1.csv
├── sample 2 m2.csv
├── sample 2 m3.csv
│
├── validation start m1.csv
├── validation start m2.csv
├── validation start m3.csv
│
├── validation end m1.csv
├── validation end m2.csv
└── validation end m3.csv
```

Validation measurements are optional.

---

## Input File Format

### Measurement Files

Measurement CSV files must contain:

| Column | Description    |
| ------ | -------------- |
| 1      | Frequency (Hz) |
| 2      | Real(S11)      |
| 3      | Imag(S11)      |

### Reference Files

Reference permittivity CSV files must contain:

| Column | Description               |
| ------ | ------------------------- |
| 1      | Frequency (Hz)            |
| 2      | Relative permittivity, ε′ |
| 3      | Loss factor, ε″           |

All files used within a single analysis run must share the same frequency axis.

---

## Uncertainty Analysis

The pipeline combines multiple uncertainty contributions:

### Repeatability

Calculated from the standard deviation of repeated measurements (`m1`, `m2`, `m3`).

### Validation Uncertainty

Optional validation measurements may be compared against a known reference material.

Examples include:

* Validation solution measurements
* Reference liquids
* Control measurements

If both validation start and validation end measurements are available, they are first averaged before comparison with the reference dielectric properties.

### Drift Component

An additional user-defined uncertainty component can be included to account for measurement drift and other systematic effects.

### Total Uncertainty

The uncertainty contributions are combined by summing in quadrature.

---

## Outputs

For each material analysed, the pipeline exports:

### CSV Results

```text
sample_1_permittivity.csv
sample_2_permittivity.csv
...
```

containing:

* Frequency
* Relative permittivity (ε′)
* Loss factor (ε″)
* Uncertainty in ε′
* Uncertainty in ε″

### Figures

The pipeline automatically generates:

* Real relative permittivity versus frequency
* Loss factor versus frequency

Optional uncertainty bands may be displayed around selected curves.

---

## Requirements

* MATLAB
* Signal Processing Toolbox (for optional Savitzky–Golay smoothing)

---

## Intended Use

This repository is intended as a demonstration of:

* Scientific programming in MATLAB
* Dielectric spectroscopy data analysis
* Microwave measurement processing
* Permittivity extraction algorithms
* Experimental uncertainty analysis

The implementation can be adapted to different calibration standards, reference materials, and dielectric measurement campaigns.
