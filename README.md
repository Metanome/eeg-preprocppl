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
2. **Configure settings** at the top of the script (see Configuration Options below)
3. **Choose processing model**:
   - **Model 2**: Run `model2_eeg_prep.m` for basic preprocessing (7 steps)
   - **Model 3**: Run `model3_eeg_prep.m` for advanced ICA preprocessing (11 steps)
4. **Processed files** saved to `output/` folder:
   - Model 2: `[filename]_model2_preprocessed.edf`
   - Model 3: `[filename]_model3_preprocessed.edf`
5. **Processing logs** saved to `logs/` folder

### Model Selection Guide
- **Use Model 2** for: Quick preprocessing, baseline processing, when ICA is not required
- **Use Model 3** for: Research-grade preprocessing with artifact removal, high-quality clean data requirements
- **Use ASR Optimization Tool** for: Finding the best ASR parameters for your specific dataset
- **Use Comparison Tool** for: Validating script vs manual processing, evaluating ICA effectiveness

## Directory Structure
```
Model2-EEG-Pipeline/
├── model2_eeg_prep.m          # Basic preprocessing script (7 steps)
├── model3_eeg_prep.m          # Advanced ICA preprocessing script (11 steps)
├── optimize_asr_parameters.m  # ASR parameter optimization tool
├── compare_models.m           # Automated comparison analysis tool
├── prepare_external_data.m    # External data standardization script
├── eeg_files/                 # Input for all EEG files
├── output/                    # Output for all processed files
├── logs/                      # Processing logs and reports
├── compare_models/            # Comparison analysis folder
│   ├── script/                # Script-processed files
│   ├── manual/                # Manually-processed files
│   ├── results/               # Comparison plots and analysis
│   └── logs/                  # Comparison logs
└── README.md                  # This file
```

## Pipeline Components

### Model 2: Basic Preprocessing (`model2_eeg_prep.m`)
**7-step basic preprocessing pipeline** without ICA:
1. Import with configurable time range
1b. Clean channel labels (remove reference suffixes like -AA, -Ref)
2. Remove unwanted channels (configurable: reference, EOG, EMG, ECG)
3. Downsample to target sample rate
4. Bandpass filter
5. Clean raw data (artifact removal with ASR)
6. Re-reference to average
7. Save as preprocessed EDF

### Model 3: Advanced ICA Pipeline (`model3_eeg_prep.m`)
**11-step advanced preprocessing pipeline** with automated ICA artifact removal:
1. Import with configurable time range (Steps 1-4 same as Model 2)
5. Clean raw data (artifact removal with ASR)
6. Add channel locations (Dynamic montage detection: 19/21/25/32/64/128 channels)
7. Run ICA decomposition (Extended Infomax)
8. Classify components using ICLabel
9. Remove artifact components (configurable brain threshold, default ≥70%)
10. Re-reference to average
11. Save as preprocessed EDF

### ASR Optimization Tool (`optimize_asr_parameters.m`)
**Systematic parameter testing tool** to find optimal ASR settings:
- Tests multiple combinations of Burst and Window criteria
- Balances high data retention with signal quality (SNR, Kurtosis)
- Provides per-file breakdown and actionable recommendations
- **Usage**: Run `optimize_asr_parameters` from MATLAB command line

### Comparison Tool (`compare_models.m`)
**Automated comparison analysis** for systematic evaluation:
- **Interactive menu system** for easy comparison selection
- **Multiple comparison types**: Script vs Manual, Model 2 vs Model 3
- **Statistical significance testing** with p-values
- **Enhanced visualizations and reporting**

### External Data Preparation (`prepare_external_data.m`)
**Utility script to standardize external EEG datasets** to the required montage.
- Automatically renames channels (e.g., T7 -> T3) based on map
- Strips channel suffixes
- Saves standardized files to `output/` with `_prepared.edf` suffix

## Configuration Options

Each script features a centralized **USER CONFIGURATION** section at the top.

### Processing Parameters
```matlab
IMPORT_TIME_RANGE_SEC = 180;         % Import first N seconds (set to Inf for all data)
TARGET_SAMPLE_RATE_HZ = 125;         % Target sample rate after downsampling
FILTER_LOW_HZ = 0.5;                 % Bandpass filter low cutoff (Hz)
FILTER_HIGH_HZ = 40;                 % Bandpass filter high cutoff (Hz)
```

### ICA Parameters (Model 3 only)
```matlab
BRAIN_THRESHOLD = 0.7;               % ICLabel: minimum brain probability to keep component
```

### ASR Parameters
```matlab
ASR_BURST_CRITERION = 23;            % Threshold for burst removal (lower = more aggressive)
ASR_WINDOW_CRITERION = 0.25;         % Proportion of bad channels to trigger window rejection
ASR_WINDOW_TOLERANCES = [-Inf 7];    % Tolerance range for window rejection
```

### Channel Name Cleaning
```matlab
STRIP_CHANNEL_SUFFIXES = true;       % Remove reference suffixes from channel names
CHANNEL_SUFFIX_PATTERN = '-(AA|Ref)$';  % Regex pattern for suffixes to remove
```

### Folder Configuration
```matlab
INPUT_FOLDER = fullfile(pwd, 'eeg_files'); % Input data location
OUTPUT_FOLDER = fullfile(pwd, 'output');   % Output data location
LOG_FOLDER = fullfile(pwd, 'logs');        % Log file location
```

### Channel Removal Configuration
Both models support **flexible channel removal configuration**:
```matlab
REMOVE_REFERENCE_CHANNELS = true;    % A1, A2, M1, M2, TP9, TP10, etc.
REMOVE_EOG_CHANNELS = true;          % VEOG, HEOG, EOG1, EOG2, etc.
CHANNELS_TO_NEVER_REMOVE = {'Fp1', 'Fp2', 'F3', ...}; % Safety protection
```

## Feature Documentation

### ASR Parameter Optimization
The `optimize_asr_parameters.m` tool runs a sweep of parameter combinations to find the best balance for your specific data.

**Configuration:**
```matlab
BURST_VALUES = [20, 30, 40, 50];           % Values to test
WINDOW_VALUES = {0.25, 0.5, 0.75, 'off'};  % Values to test
TARGET_RETENTION = 0.90;                   % Target data retention (e.g., 90%)
MAX_FILES_TO_TEST = 10;                    % Test subset of files (or 'all')
```

**Output:**
- Results table with retention, SNR, kurtosis, and quality scores
- Per-file breakdown showing which files pass/fail
- Recommendation for optimal settings
- CSV report saved to `logs/asr_optimization_results.csv`

> [!TIP]
> The tool's recommendation is a statistically optimal starting point. We recommend checking values slightly above/below the recommendation (e.g., Burst +/- 1) using visual inspection in EEGLAB, as manual validation may yield even better results for specific noise profiles.

### Comparison Analysis
Execute `compare_models.m` to start the interactive tool.

1. **Set up comparison folders**:
   - `compare_models/manual/model2/` & `model3/` - Manually-processed files
   - `compare_models/script/model2/` & `model3/` - Script-processed files
2. **Select comparison type** from the menu.
3. **View Results**: Saved in `compare_models/results/` with unique filenames.

**Analysis Features:**
- **Signal quality assessment**: Amplitude, variability, SNR improvements
- **Power spectral density analysis**: Frequency band changes
- **Statistical significance testing**: Wilcoxon signed-rank tests
- **Channel correlation analysis**: Signal preservation assessment

## Quality Metrics & Thresholds

### Processing Quality Validation
- **Brain Component Retention**: ≥70% brain probability threshold (Model 3)
- **Power Change Validation**:
  - Normal: <15 dB change
  - Substantial: 15-30 dB change
  - Warning: >30 dB change (likely error)
- **Signal Reduction Warnings**: Amplitude >20x or Variability >200x reduction flagged

### ICA Quality Assessment (Model 3)
- **Component classification confidence**: ICLabel probability scores
- **Retained vs removed component breakdown**: Detailed count of artifact types
- **Component separation quality**: Information entropy measures for classification clarity

## Support & Troubleshooting

### Common Issues
- **Dynamic channel location assignment**: Supports 19-128 channel montages with automatic fallbacks
- **ICLabel requires channel locations**: System automatically selects appropriate montage file
- **Memory issues**: Reduce `IMPORT_TIME_RANGE_SEC` if running out of RAM
- **GUI not showing**: Set `SHOW_EEGLAB_GUI = true` to debug visually

### Error Recovery Features
- **Graceful failure handling**: Failed files are logged and skipped
- **Memory management**: Automatic cleanup (`onCleanup`) prevents memory leaks
- **Log file safety**: Logs are guaranteed to close even on error

### Validation Workflow
1. **Process test files** with both Model 2 and Model 3
2. **Run comparison analysis** to validate effectiveness
3. **Review quality metrics** in generated logs
4. **Adjust thresholds** based on findings using the Optimization Tool
