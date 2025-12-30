% PREPARE EXTERNAL EEG DATA FOR VALIDATION
% ==========================================
% This script standardizes external EEG datasets to a specific 19-channel montage.
% Supports file formats: .cnt, .edf, .gdf
%
% PIPELINE STEPS:
% 1. Import EEG file
% 2. Clean channel labels (remove reference suffixes)
% 3. Rename channels to match target montage (e.g., T7 -> T3)
% 4. Select only target channels (remove extras)
% 5. Validate final channel set
% 6. Save standardized data as EDF
%
% This is useful for preparing external validation data to match a model's
% required input format.

%% ========================================================================
%  USER CONFIGURATION - Modify these settings as needed
%% ========================================================================

%% TARGET CHANNEL CONFIGURATION
% =================================
% These are the 19 channels that the final dataset should contain.
TARGET_CHANNELS = {'Fp1', 'Fp2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', ...
    'O1', 'O2', 'F7', 'F8', 'T3', 'T4', 'T5', 'T6', ...
    'Fz', 'Cz', 'Pz'};

%% CHANNEL RENAMING MAP
% =================================
% Define equivalent channel names here. The script will rename the 'Original'
% channel to the 'Target' name. This is case-sensitive.
% Format: rename_map('OriginalName') = 'TargetName';
rename_map = containers.Map();
rename_map('T7') = 'T3';
rename_map('T8') = 'T4';
rename_map('P7') = 'T5';
rename_map('P8') = 'T6';
% Add more renaming rules as needed for other datasets
% rename_map('Oz') = 'POz'; % Example for another potential rename

%% CHANNEL NAME CLEANING
% =================================
STRIP_CHANNEL_SUFFIXES = true;       % Remove reference suffixes from channel names
CHANNEL_SUFFIX_PATTERN = '-(AA|Ref)$';  % Regex pattern for suffixes to remove (e.g., Fp1-AA -> Fp1)

%% DISPLAY CONFIGURATION
% =================================
SHOW_EEGLAB_GUI = false;             % Set to true to show EEGLAB GUI during processing

%% FOLDER CONFIGURATION
% =================================
INPUT_FOLDER = fullfile(pwd, 'eeg_files'); % Folder for raw external data
OUTPUT_FOLDER = fullfile(pwd, 'output');    % Folder for standardized data
LOG_FOLDER = fullfile(pwd, 'logs');         % Folder for processing logs

%% ========================================================================
%  END OF USER CONFIGURATION - Do not modify below unless you know what you're doing
%% ========================================================================

%% SCRIPT INITIALIZATION
% =================================

% Create folders if they don't exist
if ~exist(INPUT_FOLDER, 'dir'), mkdir(INPUT_FOLDER); end
if ~exist(OUTPUT_FOLDER, 'dir'), mkdir(OUTPUT_FOLDER); end
if ~exist(LOG_FOLDER, 'dir'), mkdir(LOG_FOLDER); end

% Get .cnt, .edf, and .gdf files from input folder
cnt_files = dir(fullfile(INPUT_FOLDER, '*.cnt'));
edf_files = dir(fullfile(INPUT_FOLDER, '*.edf'));
gdf_files = dir(fullfile(INPUT_FOLDER, '*.gdf'));
eeg_files = [cnt_files; edf_files; gdf_files];

% Check if any EEG files were found
if isempty(eeg_files)
    fprintf('\nERROR: No EEG files found in %s\n', INPUT_FOLDER);
    fprintf('Please add external EEG files to the input folder and run again.\n\n');
    return;
end

fprintf('Found %d EEG file(s) to process in ''%s'':\n', length(eeg_files), INPUT_FOLDER);
for i = 1:length(eeg_files)
    fprintf('  %d. %s\n', i, eeg_files(i).name);
end
fprintf('\n');

% Initialize batch tracking
batch_start_time = tic;
batch_stats = struct('processed', 0, 'failed', 0, 'total', length(eeg_files));
log_file = fullfile(LOG_FOLDER, 'prepare_external_data_log.txt');
logID = fopen(log_file, 'w');
if logID == -1
    fprintf('[ERROR] Could not create log file. Aborting.\n');
    return;
end

% Guarantee log file is closed even if an error occurs
logCleanup = onCleanup(@() fclose(logID));

fprintf(logID, '=== Batch Processing Started: %s ===\n', datestr(now));
fprintf(logID, 'Target Channels: %s\n', strjoin(TARGET_CHANNELS, ', '));
fprintf(logID, 'Renaming Rules (%d): %s\n\n', rename_map.Count, strjoin(rename_map.keys, ', '));

% Start EEGLAB (with or without GUI based on configuration)
if SHOW_EEGLAB_GUI
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
else
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');
end

%% PROCESSING LOOP
% =================================

for i = 1:length(eeg_files)
    file_start_time = tic;
    filename = eeg_files(i).name;
    filepath = fullfile(eeg_files(i).folder, filename);
    [~, name_no_ext, ext] = fileparts(filename);

    fprintf('\n[%d/%d] Processing: %s\n', i, length(eeg_files), filename);
    fprintf(logID, '--- Processing file: %s ---\n', filename);

    try
        %% Step 1: Import EEG file
        fprintf(logID, 'Step 1: Importing file...\n');
        switch lower(ext)
            case {'.cnt', '.edf', '.gdf'}
                EEG = pop_biosig(filepath);
            otherwise
                fprintf(logID, '  [ERROR] Unsupported file format: %s\n', ext);
                error('Unsupported file format.');
        end
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
        fprintf(logID, '  Imported %d channels.\n', EEG.nbchan);

        %% Step 1b: Clean channel labels (remove reference suffixes)
        if STRIP_CHANNEL_SUFFIXES
            suffix_cleaned = 0;
            for ch = 1:length(EEG.chanlocs)
                original_label = EEG.chanlocs(ch).labels;
                new_label = regexprep(original_label, CHANNEL_SUFFIX_PATTERN, '');
                if ~strcmp(original_label, new_label)
                    EEG.chanlocs(ch).labels = new_label;
                    suffix_cleaned = suffix_cleaned + 1;
                end
            end
            EEG = eeg_checkset(EEG);
            if suffix_cleaned > 0
                fprintf(logID, '  Cleaned %d channel labels (removed suffixes matching: %s)\n', ...
                    suffix_cleaned, CHANNEL_SUFFIX_PATTERN);
            end
        end

        %% Step 2: Rename Channels
        fprintf(logID, 'Step 2: Renaming channels...\n');
        original_labels = {EEG.chanlocs.labels};
        renamed_count = 0;
        for ch_idx = 1:EEG.nbchan
            original_label = EEG.chanlocs(ch_idx).labels;
            if isKey(rename_map, original_label)
                new_label = rename_map(original_label);
                EEG.chanlocs(ch_idx).labels = new_label;
                fprintf(logID, '  Renamed ''%s'' -> ''%s''\n', original_label, new_label);
                renamed_count = renamed_count + 1;
            end
        end
        fprintf(logID, '  Finished renaming. %d channels were renamed.\n', renamed_count);

        %% Step 3: Remove Unwanted Channels
        fprintf(logID, 'Step 3: Selecting target channels...\n');
        current_labels = {EEG.chanlocs.labels};

        % Find which of the target channels are available in the current data
        channels_to_keep = intersect(TARGET_CHANNELS, current_labels);

        % Find channels that are not in the target list
        channels_to_remove = setdiff(current_labels, TARGET_CHANNELS);

        fprintf(logID, '  Found %d of %d target channels.\n', length(channels_to_keep), length(TARGET_CHANNELS));

        if isempty(channels_to_keep)
            error('No target channels found in the file after renaming. Cannot proceed.');
        end

        % Perform the channel selection
        EEG = pop_select(EEG, 'channel', channels_to_keep);
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

        fprintf(logID, '  Removed %d channels. Kept %d channels: %s\n', ...
            length(channels_to_remove), EEG.nbchan, strjoin(channels_to_keep, ', '));

        %% Step 4: Final Validation
        fprintf(logID, 'Step 4: Validating final channel set...\n');
        final_labels = {EEG.chanlocs.labels};
        missing_channels = setdiff(TARGET_CHANNELS, final_labels);

        if EEG.nbchan ~= length(TARGET_CHANNELS)
            fprintf(logID, '  [WARNING] Final channel count is %d, expected %d.\n', EEG.nbchan, length(TARGET_CHANNELS));
            if ~isempty(missing_channels)
                fprintf(logID, '  Missing target channels: %s\n', strjoin(missing_channels, ', '));
            end
        else
            fprintf(logID, '  Validation successful. Dataset contains all 19 target channels.\n');
        end

        %% Step 5: Save Processed File
        fprintf(logID, 'Step 5: Saving preprocessed file...\n');
        out_file = fullfile(OUTPUT_FOLDER, [name_no_ext '_prepared.edf']);
        pop_writeeeg(EEG, out_file, 'TYPE', 'EDF');

        total_time = toc(file_start_time);
        fprintf(logID, '  Saved standardized file to: %s (%.2fs)\n\n', out_file, total_time);
        fprintf('[SUCCESS] %s processed in %.2f seconds\n', filename, total_time);
        batch_stats.processed = batch_stats.processed + 1;

    catch ME
        fprintf(logID, '  [ERROR] Processing failed for %s: %s\n\n', filename, ME.message);
        fprintf('[ERROR] Failed to process %s: %s\n', filename, ME.message);
        batch_stats.failed = batch_stats.failed + 1;
    end
end

%% FINAL BATCH SUMMARY
% =================================
total_batch_time = toc(batch_start_time);
fprintf('\n========================================\n');
fprintf('BATCH PROCESSING SUMMARY\n');
fprintf('========================================\n');
fprintf('Completed: %s\n', datestr(now));
fprintf('Total files: %d\n', batch_stats.total);
fprintf('Successfully processed: %d\n', batch_stats.processed);
fprintf('Failed: %d\n', batch_stats.failed);
fprintf('Success rate: %.1f%%\n', (batch_stats.processed/batch_stats.total)*100);
fprintf('Total batch time: %.2f seconds (%.2f minutes)\n', total_batch_time, total_batch_time/60);
fprintf('\nLog file saved to: %s\n', log_file);
fprintf('Prepared files saved in: %s\n', OUTPUT_FOLDER);

% onCleanup handles fclose automatically
clear logCleanup;

% Refresh EEGLAB GUI if it was shown
if SHOW_EEGLAB_GUI
    eeglab redraw;
end