# EEG Preprocessing Pipeline

**Enhanced MATLAB scripts for automated EEG preprocessing using EEGLAB** - Designed for hospital EEG data with 19-channel montage, featuring comprehensive monitoring, validation, and reporting.

## Pipeline Models

### Model 2: Basic Preprocessing (`model2_eeg_prep.m`)
**7-step basic preprocessing pipeline** without ICA:
1. Import with time range (0-180 sec)
2. Remove reference channels (A1, A2) and EOG
3. Downsample to 125 Hz
4. Bandpass filter (0.5-40 Hz)
5. Clean raw data (artifact removal with ASR)
6. Re-reference to average
7. Save as preprocessed EDF

### Model 3: Advanced ICA Pipeline (`model3_eeg_prep.m`)
**11-step advanced preprocessing pipeline** with automated ICA artifact removal:
1. Import with time range (0-180 sec)
2. Remove reference channels (A1, A2) and EOG
3. Downsample to 125 Hz
4. Bandpass filter (0.5-40 Hz)
5. Clean raw data (artifact removal with ASR)
6. Add channel locations (Standard 10-20)
7. **Run ICA decomposition (`pop_runica`)**
8. **Classify components using ICLabel**
9. **Remove artifact components (`pop_subcomp`)**
10. Re-reference to average
11. Save as preprocessed EDF

## Features

### Core Processing Pipeline
- **Multi-format support**: CNT, EDF, and GDF file formats
- **Automated ICA artifact removal** (Model 3 only):
  - Independent Component Analysis using Extended Infomax
  - Automatic component classification with ICLabel
  - Intelligent artifact removal (Brain components >70% retained)
  - Replaces manual component inspection workflow

### Enhanced Monitoring & Validation
- **Processing Time Logging**: Individual step timing and total processing time per file
- **Progress Indicators**: Real-time progress with estimated time remaining for batch processing
- **File Validation**: Automatic validation of file existence, size, and format
- **Smart Logging System**:
  - Single file: Creates `FileName_log.txt`
  - Multiple files: Creates consolidated `Batch_log.txt`
- **Comprehensive Error Handling**: Graceful failure recovery with detailed error reporting

### Quality Assessment & Metrics
- **Signal Quality Analysis**: Before/after amplitude and variability tracking
- **Power Spectral Density Analysis**: Frequency band power analysis (Delta, Theta, Alpha, Beta, Gamma)
- **Advanced Statistical Measures**: Kurtosis, skewness, channel consistency, temporal stability
- **Data Retention Analysis**: Percentage of data preserved after cleaning
- **ICA Quality Metrics** (Model 3 only):
  - ICLabel classification confidence
  - Component breakdown (Brain, Muscle, Eye, Heart, etc.)
  - Brain component consistency and separation quality
  - Artifact reduction estimates

### Manual Workflow Automation (Model 3)
Model 3 automates the complete manual EEGLAB workflow:
- **Channel Locations** (`pop_chanedit`) - Automatic Standard 10-20 lookup
- **ICA Decomposition** (`pop_runica`) - Extended Infomax algorithm
- **Component Classification** - ICLabel replaces manual inspection (`pop_viewprops`)
- **Artifact Removal** (`pop_subcomp`) - Automated based on brain probability threshold

## Usage

### Basic Usage
1. Place EEG files in `eeg_files/` folder
2. Choose your processing model:
   - **Model 2**: Run `model2_eeg_prep.m` for basic preprocessing
   - **Model 3**: Run `model3_eeg_prep.m` for advanced ICA preprocessing
3. Processed files saved to `output/` folder
4. Processing logs saved to `logs/` folder

### Model Selection Guide
- **Use Model 2** for:
  - Quick preprocessing without artifact removal
  - When ICA is not required
  - Baseline preprocessing pipeline
  
- **Use Model 3** for:
  - Research-grade preprocessing with artifact removal
  - When high-quality clean data is required
  - Automated replication of manual EEGLAB workflow
  - Detailed quality assessment and reporting

## Quality Metrics & Logging

### Individual File Logs
Each processing session generates detailed logs with:
- **Step-by-step timing and results**
- **Quality metrics**: Channels, events, data retention, signal statistics
- **Power spectral analysis**: Frequency band changes (before/after)
- **ICA metrics** (Model 3): Component classification, removal decisions
- **Statistical quality**: Kurtosis, skewness, channel consistency
- **Error tracking and diagnostics**

### Batch Summary Reports
- **Processing time statistics**: Average, range, total batch time
- **Success/failure rates**: File processing statistics
- **Quality metric aggregation**: Data retention, signal changes
- **Performance benchmarking**: Processing efficiency analysis

### Advanced Quality Validation (Model 3)
- **Realistic warning thresholds**: Calibrated for typical EEG preprocessing
- **Power change validation**: Flags unrealistic spectral changes (>30 dB)
- **Over-processing detection**: Warns for extreme signal reduction (>20x amplitude, >200x variability)
- **ICA quality assessment**: Component separation quality and confidence metrics

## Requirements

- **MATLAB** (R2018b or later recommended)
- **EEGLAB toolbox** (latest version)
- **ICLabel plugin** (required for Model 3 ICA functionality)
- **Supported EEG file formats**: CNT, EDF, GDF
- **System**: Windows/macOS/Linux compatible

## Directory Structure
```
Model2-EEG-Pipeline/
├── model2_eeg_prep.m          # Basic preprocessing script (7 steps)
├── model3_eeg_prep.m          # Advanced ICA preprocessing script (11 steps)
├── eeg_files/                 # Input EEG files
├── output/                    # Processed EDF files
├── logs/                      # Processing logs and reports
├── Channel Locations.png      # Manual workflow reference screenshots
├── pop_chanedit().png
├── pop_runica().png
├── Classify components using ICLabel; Label components.png
├── pop_viewprops().png
├── View components properties; pop_viewprops().png
├── pop_subcomp().png
└── README.md                  # This file
```

## Technical Details

### ICA Implementation (Model 3)
The automated ICA workflow replicates the manual EEGLAB process:

1. **Channel Location Assignment**: Automatic lookup using Standard 10-20 Cap19
2. **ICA Decomposition**: Extended Infomax algorithm via `pop_runica`
3. **Component Classification**: ICLabel automatic classification replacing manual inspection
4. **Artifact Removal**: Threshold-based removal (Brain probability ≤ 70%)

### Quality Thresholds
- **Brain Component Retention**: >70% brain probability threshold
- **Power Change Validation**: 
  - Normal: <15 dB change
  - Substantial: 15-30 dB change  
  - Warning: >30 dB change (likely error)
- **Signal Reduction Warnings**:
  - Amplitude: >20x reduction flagged
  - Variability: >200x reduction flagged