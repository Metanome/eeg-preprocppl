# EEG Preprocessing Pipeline with Automated Comparison

**Complete MATLAB toolkit for automated EEG preprocessing using EEGLAB** - Designed for hospital EEG data with flexible channel montage support (19-128 channels), featuring comprehensive processing, validation, and comparative analysis.

## Quick Start Guide

### Prerequisites
- **MATLAB** (R2018b or later recommended)
- **EEGLAB toolbox** (latest version)
- **ICLabel plugin** (required for Model 3 ICA functionality)
- **Signal Processing Toolbox** (for advanced analysis)

### Basic Usage
1. **Place EEG files** in `eeg_files/` folder (supports CNT, EDF, GDF formats)
2. **Choose processing model**:
   - **Model 2**: Run `model2_eeg_prep.m` for basic preprocessing (7 steps)
   - **Model 3**: Run `model3_eeg_prep.m` for advanced ICA preprocessing (11 steps)
3. **Processed files** saved to `output/` folder:
   - Model 2: `[filename]_model2_preprocessed.edf`
   - Model 3: `[filename]_model3_preprocessed.edf`
4. **Processing logs** saved to `logs/` folder:
   - Single file: `[filename]_model2_log.txt` or `[filename]_model3_log.txt`
   - Batch mode: `Batch_model2_log.txt` or `Batch_model3_log.txt`

### Model Selection Guide
- **Use Model 2** for: Quick preprocessing, baseline processing, when ICA is not required
- **Use Model 3** for: Research-grade preprocessing with artifact removal, high-quality clean data requirements
- **Use Comparison Tool** for: Validating script vs manual processing, evaluating ICA effectiveness

## Pipeline Components

### Model 2: Basic Preprocessing (`model2_eeg_prep.m`)
**7-step basic preprocessing pipeline** without ICA:
1. Import with time range (0-180 sec)
2. Remove unwanted channels (configurable: reference, EOG, EMG, ECG)
3. Downsample to 125 Hz
4. Bandpass filter (0.5-40 Hz)
5. Clean raw data (artifact removal with ASR)
6. Re-reference to average
7. Save as preprocessed EDF

### Model 3: Advanced ICA Pipeline (`model3_eeg_prep.m`)
**11-step advanced preprocessing pipeline** with automated ICA artifact removal:
1. Import with time range (0-180 sec)
2. Remove unwanted channels (configurable: reference, EOG, EMG, ECG)
3. Downsample to 125 Hz
4. Bandpass filter (0.5-40 Hz)
5. Clean raw data (artifact removal with ASR)
6. Add channel locations (Dynamic montage detection: 19/21/25/32/64/128 channels)
7. Run ICA decomposition
8. Classify components using ICLabel
9. Remove artifact components (Brain ≥70% retained, others removed)
10. Re-reference to average
11. Save as preprocessed EDF

### Comparison Tool (`compare_models.m`)
**Automated comparison analysis** for systematic evaluation:
- **Interactive menu system** for easy comparison selection
- **Multiple comparison types**: Script vs Manual, Model 2 vs Model 3
- **Statistical significance testing** with p-values
- **Enhanced visualizations and reporting**
### External Data Preparation (`prepare_external_data.m`)
**Utility script to standardize external EEG datasets to the required 19-channel montage.**
1.  **Place external EEG files** in the `eeg_files/` folder alongside your other data.
2.  **Configure channel renaming** in `prepare_external_data.m` to map dataset-specific channel names to your target names (e.g., `T7` -> `T3`).
3.  **Run the script**.
4.  **Standardized files** are saved to the `output/` folder with a `_prepared.edf` suffix.


## Key Features

### Core Processing Capabilities
- **Multi-format support**: CNT, EDF, and GDF file formats
- **Flexible channel removal**: Configurable removal of reference, EOG, EMG, ECG channels with safety protections
- **Dynamic channel location assignment**: Automatic montage selection (19-128 channels)
- **Automated ICA artifact removal** (Model 3): Extended Infomax with ICLabel classification
- **Robust error handling**: Graceful failure recovery with detailed error reporting

### Channel Removal Configuration
Both models support **flexible channel removal configuration**:
```matlab
%% CHANNEL REMOVAL CONFIGURATION
REMOVE_REFERENCE_CHANNELS = true;    % A1, A2, M1, M2, TP9, TP10, etc.
REMOVE_EOG_CHANNELS = true;          % VEOG, HEOG, EOG1, EOG2, etc.
REMOVE_EMG_CHANNELS = false;         % EMG, Chin, etc.
REMOVE_ECG_CHANNELS = false;         % ECG, EKG, etc.

% Manual specification
MANUAL_CHANNELS_TO_REMOVE = {};      % e.g., {'BadChannel1', 'Artifact2'}

% Safety protection
CHANNELS_TO_NEVER_REMOVE = {'Fp1', 'Fp2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', ...
                            'O1', 'O2', 'F7', 'F8', 'T3', 'T4', 'T5', 'T6', ...
                            'Fz', 'Cz', 'Pz', 'Oz'};
```

### Quality Monitoring & Validation
- **Real-time progress tracking**: Step timing and estimated completion time
- **Smart logging system**: Individual file logs or consolidated batch logs
- **Comprehensive quality metrics**:
  - Signal statistics and power spectral analysis
  - ICA component classification and removal decisions
  - Data retention analysis and processing effectiveness
  - Statistical quality measures (kurtosis, skewness, channel consistency)

## Comparison Analysis

### Setup and Usage
1. **Set up comparison folders**:
   - `compare_models/script/model2/` - Script-processed Model 2 files
   - `compare_models/script/model3/` - Script-processed Model 3 files
   - `compare_models/manual/model2/` - Manually-processed Model 2 files
   - `compare_models/manual/model3/` - Manually-processed Model 3 files
2. **Run comparison**: Execute `compare_models.m`
3. **Select comparison type** from interactive menu
4. **Results** saved in `compare_models/results/` with unique filenames

### Analysis Features
- **Signal quality assessment**: Amplitude, variability, SNR improvements
- **Power spectral density analysis**: Frequency band changes (Delta, Theta, Alpha, Beta, Gamma)
- **Statistical significance testing**: Wilcoxon signed-rank tests
- **Channel correlation analysis**: Signal preservation assessment
- **Visual reporting**: Automated plot generation with summary statistics

## Quality Metrics & Thresholds

### Processing Quality Validation
- **Brain Component Retention**: ≥70% brain probability threshold (Model 3)
- **Power Change Validation**: 
  - Normal: <15 dB change
  - Substantial: 15-30 dB change  
  - Warning: >30 dB change (likely error)
- **Signal Reduction Warnings**:
  - Amplitude: >20x reduction flagged
  - Variability: >200x reduction flagged

### ICA Quality Assessment (Model 3)
- **Component classification confidence**: ICLabel probability scores
- **Retained vs removed component breakdown**: Brain, Muscle, Eye, Heart, Line Noise, Channel Noise, Other
- **Brain component consistency**: Variability in brain component confidence scores
- **Component separation quality**: Information entropy measures for classification clarity
- **Artifact reduction effectiveness**: Before/after signal quality comparisons
- **Processing warnings**: Automatic detection of extreme signal reductions or processing issues

## Directory Structure
```
Model2-EEG-Pipeline/
├── model2_eeg_prep.m          # Basic preprocessing script (7 steps)
├── model3_eeg_prep.m          # Advanced ICA preprocessing script (11 steps)
├── prepare_external_data.m    # External data standardization script
├── compare_models.m           # Automated comparison analysis tool
├── eeg_files/                 # Input for all EEG files (main and external)
├── output/                    # Output for all processed files
├── logs/                      # Processing logs and reports
├── compare_models/            # Comparison analysis folder
│   ├── script/               # Script-processed files
│   │   ├── model2/          # Model 2 script results
│   │   └── model3/          # Model 3 script results
│   ├── manual/               # Manually-processed files
│   │   ├── model2/          # Model 2 manual results
│   │   └── model3/          # Model 3 manual results
│   ├── results/              # Comparison plots and analysis
│   ├── logs/                 # Comparison logs
│   └── README.md             # Comparison tool documentation
└── README.md                  # This file
```

## Technical Implementation

### ICA Implementation (Model 3)
The automated ICA workflow replicates the manual EEGLAB process:
- **Channel Location Assignment**: Dynamic selection based on channel count
- **ICA Decomposition**: Extended Infomax algorithm via `pop_runica`
- **Component Classification**: ICLabel automatic classification
- **Artifact Removal**: Threshold-based removal (Brain probability ≥ 70%)

### File Processing Architecture
- **Batch processing**: Multiple files processed automatically with progress tracking
- **Error recovery**: Failed files logged and skipped, processing continues
- **Memory management**: Automatic cleanup between files
- **Smart logging**: Single file or consolidated batch logs
- **Output format**: Model-specific EDF files with suffixes `_model2_preprocessed.edf` and `_model3_preprocessed.edf`
- **Progress indication**: Real-time processing status with time estimates
- **Quality validation**: Automatic warnings for unusual signal changes or processing issues

## Support & Troubleshooting

### Common Issues
- **Dynamic channel location assignment**: Supports 19-128 channel montages with automatic fallbacks
- **ICLabel requires channel locations**: System automatically selects appropriate montage file
- **Memory issues with large files**: Consider processing smaller time segments
- **File format compatibility**: Test with single files first before batch processing
- **Log file access**: Logs are created during processing; ensure write permissions to logs folder
- **Missing dependencies**: Ensure EEGLAB and ICLabel plugin are properly installed

### Error Recovery Features
- **Graceful failure handling**: Failed files are logged and skipped, allowing batch processing to continue
- **Memory management**: Automatic cleanup between files to prevent memory issues
- **Progress tracking**: Real-time progress indicators with estimated completion times
- **Quality validation**: Automatic detection of over-processing or unusual signal changes

### Validation Workflow
1. **Process test files** with both Model 2 and Model 3
2. **Run comparison analysis** to validate ICA effectiveness
3. **Review quality metrics** in generated logs
4. **Check log file naming**: 
   - Single files: `[filename]_model2_log.txt` or `[filename]_model3_log.txt`
   - Batch processing: `Batch_model2_log.txt` or `Batch_model3_log.txt`
5. **Adjust thresholds** if needed for your specific data characteristics

### Log File Organization
- **Individual file processing**: Creates separate log for each file (e.g., `subject001_model2_log.txt`)
- **Batch processing**: Creates consolidated logs (`Batch_model2_log.txt`, `Batch_model3_log.txt`)
- **Log contents**: Step-by-step processing details, quality metrics, error handling, and performance statistics
- **Comparison logs**: Saved in `compare_models/logs/` with timestamp-based naming

### Output File Organization
- **Model-specific naming**: Prevents overwrites when processing same file with both models
- **Clear identification**: Easy to distinguish between Model 2 and Model 3 outputs
- **Comparison-ready**: Output files are automatically organized for comparison tool analysis
- **Example**: `subject001.cnt` → `subject001_model2_preprocessed.edf` + `subject001_model3_preprocessed.edf`