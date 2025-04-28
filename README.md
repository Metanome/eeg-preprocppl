# EEG Preprocessing Pipeline

A web-based EEG preprocessing and visualization tool built with Flask, MNE-Python, and Plotly.

## Features
- **Upload EEG files** in `.edf` or `.fif` format
- **Preprocessing pipeline**:
  - Bandpass filtering (1–40 Hz)
  - ICA for artifact removal (automatic exclusion of EOG-related components if detected)
  - Optional epoching (can be extended)
- **Interactive visualizations**:
  - Raw EEG signal (first 5 channels, first 10 seconds)
  - Cleaned EEG signal (after ICA)
  - ICA components (first 10, vertically offset)
- **Download cleaned data** as `.fif` (MNE format) or `.csv`
- **User feedback** on ICA artifact removal and error handling

## Supported File Formats
- `.edf` (European Data Format, recommended for EEG)
- `.fif` (MNE native format)

## Folder Structure
```
├── app.py                  # Main Flask app
├── config.py               # App configuration (optional)
├── requirements.txt        # Python dependencies
├── preprocessing/          # Preprocessing and visualization modules
│   ├── pipeline.py         # EEG loading, filtering, ICA, saving
│   └── visualizer.py       # Plotly visualizations
├── templates/              # Jinja2 HTML templates
├── static/                 # Static files
├── uploads/                # Uploaded EEG files
├── output/                 # Processed/cleaned files and generated plots
```

## Getting Started

### 1. Install dependencies
```
pip install -r requirements.txt
```

### 2. Run the app
```
python app.py
```

### 3. Use the app
- Open your browser and go to [http://127.0.0.1:5000/](http://127.0.0.1:5000/)
- Upload an EEG file (`.edf` or `.fif`)
- View preprocessing results and interactive plots
- Download the cleaned data

## Notes
- The app uses MNE-Python for EEG processing and Plotly for interactive plots.
- ICA artifact removal is automatic; if no EOG channels or artifacts are detected, no components are excluded.
- Large EEG files may take time to process and generate large output files.
- Error messages and feedback are provided for unsupported files or processing issues.

## Improvements & TODO
- Manual ICA component selection for artifact removal
- Progress bar or spinner during processing
- More granular error messages and logging
- User help/documentation page

## License
This project is licensed under the GNU General Public License v3.0.

See [LICENSE](https://github.com/Metanome/eeg-preprocppl/blob/main/LICENSE) for details.
