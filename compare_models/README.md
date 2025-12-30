# EEG Preprocessing Comparison Tool

Automated comparison analysis to evaluate differences between processing methods: Model 2 vs Model 3, and Script vs Manual processing.

## Quick Start

1. **Set up your folder structure** (see below)
2. **Place your EDF files** in the appropriate folders
3. **Run the script**: `compare_models.m`
4. **Choose from the interactive menu**

## Folder Structure

```
compare_models/
├── script/
│   ├── model2/     # Script-processed Model 2 files (*.edf)
│   └── model3/     # Script-processed Model 3 files (*.edf)
├── manual/
│   ├── model2/     # Manually-processed Model 2 files (*.edf)
│   └── model3/     # Manually-processed Model 3 files (*.edf)
├── results/        # Comparison results (generated automatically)
└── logs/           # Comparison logs (generated automatically)
```

## Features

- **Interactive menu system** with 6 comparison options
- **Batch mode** for automated processing
- **Statistical significance testing** with p-values
- **Enhanced visualizations** and quality metrics
- **Robust error handling** with clear feedback
- **Automatic file matching** by base name

## Interactive Menu Options

```
=== INTERACTIVE COMPARISON MENU ===
1. Script vs Manual (Model 2)
2. Script vs Manual (Model 3)
3. Model 2 vs Model 3 (Script-processed)
4. Model 2 vs Model 3 (Manually-processed)
5. All comparisons (1-4)
6. Custom selection
7. Exit
```

### Comparison Types
- **Script vs Manual**: Validate automated processing against manual EEGLAB workflow
- **Model 2 vs Model 3**: Evaluate ICA effectiveness and processing differences
- **All comparisons**: Run complete analysis suite automatically
- **Custom selection**: Choose multiple specific comparisons (e.g., "1 3 4")

## File Requirements

- **File format**: EDF files (*.edf)
- **File naming**: Consistent base names across folders for automatic matching
- **Example structure**:
  ```
  script/model2/subject001_model2_processed.edf
  script/model3/subject001_model3_processed.edf
  manual/model2/subject001_manual_model2.edf
  manual/model3/subject001_manual_model3.edf
  ```

## Output & Results

All results saved in `results/` folder with unique timestamps:
- **Comparison plots**: Statistical visualizations showing before/after differences
- **Analysis data**: Quality metrics, statistical tests, and processing effectiveness
- **Processing logs**: Detailed analysis information saved in `logs/` folder

**File naming**: `[comparison_type]_[details]_[timestamp].[ext]`  
**Example**: `script_vs_manual_model2_20241201_143022.png`

### Generated Analysis
- **Signal Quality Plots**: Amplitude, variability, and SNR comparisons
- **Power Spectral Density**: Frequency domain analysis across EEG bands
- **Statistical Reports**: P-values, effect sizes, and significance testing
- **Channel Correlation**: Signal preservation and consistency metrics
- **Processing Summary**: Detailed logs with performance metrics

## Status Messages

- ✓ **Folders exist with files**: Ready to compare
- ⚠ **Folders exist but no EDF files found**: Check file placement
- ✗ **Missing folders**: Set up folder structure correctly

## Configuration

At the top of `compare_models.m`, you can modify:

```matlab
RUN_MODE = 'interactive';  % 'interactive' or 'batch_all'
SHOW_EEGLAB_GUI = false;   % Set to true to show EEGLAB GUI
```

## Batch Mode

For automated processing without interaction:
```matlab
% In compare_models.m, change:
RUN_MODE = 'batch_all';  % Instead of 'interactive'
```

## Requirements

- **EEGLAB** installed and in MATLAB path
- **Signal Processing Toolbox** (for PSD calculations)
- **Proper folder structure** as described above
- **Matching files** between comparison groups
- **EDF file format** for all processed files

## Tips for Best Results

1. **File Organization**: Use consistent base names across all comparison folders
2. **Processing Order**: Process with scripts first, then place manual results in manual folders
3. **Batch Processing**: Use "All comparisons" option for comprehensive analysis
4. **Quality Check**: Review generated logs for processing warnings or issues
5. **Statistical Validation**: Pay attention to p-values and effect sizes in results

## Troubleshooting

- **No files found**: Check that EDF files are in the correct folders
- **Mismatched files**: Ensure file base names are consistent across folders
- **Missing results**: Verify EEGLAB is properly initialized before running
- **Error messages**: Check comparison logs in `logs/` folder for detailed error information
