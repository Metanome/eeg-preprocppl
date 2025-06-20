# EEG Preprocessing Pipeline

**Enhanced MATLAB script for automated EEG preprocessing using EEGLAB** - Designed for hospital EEG data with 19-channel montage, featuring comprehensive monitoring, validation, and reporting.

## Features

### Core Processing Pipeline
- **Multi-format support**: CNT, EDF, and GDF file formats
- **7-step preprocessing pipeline**:
  1. Import with time range (0-180 sec)
  2. Remove reference channels (A1, A2) and EOG
  3. Downsample to 125 Hz
  4. Bandpass filter (0.5-40 Hz)
  5. Clean raw data (artifact removal with ASR)
  6. Re-reference to average
  7. Save as preprocessed EDF

### Enhanced Monitoring & Validation
- **Processing Time Logging**: Individual step timing and total processing time per file
- **Progress Indicators**: Real-time progress with estimated time remaining for batch processing
- **File Validation**: Automatic validation of file existence, size, and format
- **Quality Metrics**: Data retention percentage, signal amplitude analysis, channel/event tracking
- **Smart Logging System**:
  - Single file: Creates `FileName_log.txt`
  - Multiple files: Creates consolidated `Batch_log.txt`
- **Comprehensive Error Handling**: Graceful failure recovery with detailed error reporting

### Quality Assessment
- **Signal amplitude tracking**: Before/after processing comparison
- **Data retention analysis**: Percentage of data preserved after cleaning
- **Processing efficiency metrics**: Performance statistics and benchmarking
- **Batch summary reports**: Success rates, processing times, quality metrics

## Usage

### Basic Usage
1. Place EEG files in `eeg_files/` folder
2. Run `model2_eeg_prep.m` in MATLAB with EEGLAB installed
3. Processed files saved to `output/` folder
4. Processing logs saved to `logs/` folder

## Quality Metrics & Logging

### Individual File Logs
Each processing session generates detailed logs with:
- Step-by-step timing and results
- Quality metrics (channels, events, data retention)
- Signal amplitude analysis
- Error tracking and diagnostics

### Batch Summary Reports
- Processing time statistics
- Success/failure rates
- Quality metric aggregation
- Performance benchmarking

## Requirements

- **MATLAB** (R2018b or later recommended)
- **EEGLAB toolbox** (latest version)
- **Supported EEG file formats**: CNT, EDF, GDF
- **System**: Windows/macOS/Linux compatible

## Directory Structure
```
Model2-EEG-Pipeline/
├── model2_eeg_prep.m          # Main processing script
├── eeg_files/                 # Input EEG files
├── output/                    # Processed EDF files
├── logs/                      # Processing logs and reports
└── README.md                  # This file
```

## Key Enhancements

- **Professional-grade error handling** with graceful failure recovery
- **Real-time progress tracking** with time estimation
- **Comprehensive quality assessment** for validation
- **Production-ready monitoring** and reporting
- **Smart batch processing** with consolidated logging
- **Signal quality metrics** for processing verification