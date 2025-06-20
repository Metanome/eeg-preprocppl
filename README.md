# EEG Preprocessing Pipeline

MATLAB script for preprocessing EEG data using EEGLAB, designed for hospital EEG data with 19-channel montage.

## Features

- Supports CNT, EDF, and GDF file formats
- 7-step preprocessing pipeline:
  1. Import with time range (0-180 sec)
  2. Remove reference channels (A1, A2) and EOG
  3. Downsample to 125 Hz
  4. Bandpass filter (0.5-40 Hz)
  5. Clean raw data (artifact removal)
  6. Re-reference to average
  7. Save as preprocessed EDF

## Usage

1. Place EEG files in `eeg_files/` folder
2. Run `model2_eeg_prep.m` in MATLAB with EEGLAB installed
3. Processed files saved to `output/` folder
4. Processing logs saved to `logs/` folder

## Requirements

- MATLAB
- EEGLAB toolbox
- EEG files in supported formats (CNT, EDF, GDF)