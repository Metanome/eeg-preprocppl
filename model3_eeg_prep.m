% EEG PREPROCESSING PIPELINE WITH ICA (Model 3)
% ===============================================
% Automated preprocessing pipeline including ICA artifact removal
% Supports flexible channel montages: 19, 21, 25, 32, 64, 128 channels
% Required: Standard EEG channels (Fp1, Fp2, F3, F4, C3, C4, P3, P4, O1, O2, F7, F8, T3, T4, T5, T6, Fz, Cz, Pz)
%
% PIPELINE STEPS:
% 1. Import EEG data (configurable time range)
% 2. Remove unwanted channels (configurable)
% 3. Resample to target Hz
% 4. Bandpass filter
% 5. Clean raw data (ASR artifact removal)
% 6. Add channel locations (Dynamic montage detection)
% 7. Run ICA decomposition
% 8. Classify components using ICLabel
% 9. Remove artifact components (non-brain components)
% 10. Re-reference to average
% 11. Save as EDF

%% ========================================================================
%  USER CONFIGURATION - Modify these settings as needed
%% ========================================================================

%% PROCESSING PARAMETERS
% =================================
IMPORT_TIME_RANGE_SEC = 180;         % Import first N seconds (set to Inf to import all data)
TARGET_SAMPLE_RATE_HZ = 125;         % Target sample rate after downsampling
FILTER_LOW_HZ = 0.5;                 % Bandpass filter low cutoff (Hz)
FILTER_HIGH_HZ = 40;                 % Bandpass filter high cutoff (Hz)

%% ICA PARAMETERS (Model 3 specific)
% =================================
BRAIN_THRESHOLD = 0.7;               % ICLabel: min brain probability to keep component (0.0-1.0)

%% ASR (ARTIFACT SUBSPACE RECONSTRUCTION) PARAMETERS
% =================================
ASR_BURST_CRITERION = 20;            % Threshold for ASR burst removal (lower = more aggressive)
ASR_WINDOW_CRITERION = 0.25;         % Proportion of bad channels to trigger window rejection
ASR_WINDOW_TOLERANCES = [-Inf 7];    % Tolerance range for window rejection

%% CHANNEL REMOVAL CONFIGURATION
% =================================
% Configure which types of channels to remove automatically
REMOVE_REFERENCE_CHANNELS = true;    % Remove reference electrodes (A1, A2, M1, M2, etc.)
REMOVE_EOG_CHANNELS = true;          % Remove EOG channels (VEOG, HEOG, EOG1, EOG2, etc.)
REMOVE_EMG_CHANNELS = false;         % Remove EMG channels (EMG, Chin, etc.)
REMOVE_ECG_CHANNELS = false;         % Remove ECG/EKG channels

% Manual channel specification (use exact channel names from your data)
MANUAL_CHANNELS_TO_REMOVE = {};      % e.g., {'BadChannel1', 'Artifact2'}

% Safety: Channels that should NEVER be removed (protection list)
CHANNELS_TO_NEVER_REMOVE = {'Fp1', 'Fp2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', ...
    'O1', 'O2', 'F7', 'F8', 'T3', 'T4', 'T5', 'T6', ...
    'Fz', 'Cz', 'Pz', 'Oz'};

%% DISPLAY CONFIGURATION
% =================================
SHOW_EEGLAB_GUI = false;             % Set to true to show EEGLAB GUI during processing

%% CHANNEL NAME CLEANING
% =================================
STRIP_CHANNEL_SUFFIXES = true;       % Remove reference suffixes from channel names
CHANNEL_SUFFIX_PATTERN = '-(AA|Ref)$';  % Regex pattern for suffixes to remove (e.g., Fp1-AA -> Fp1)

%% FOLDER CONFIGURATION
% =================================
INPUT_FOLDER = fullfile(pwd, 'eeg_files');
OUTPUT_FOLDER = fullfile(pwd, 'output');
LOG_FOLDER = fullfile(pwd, 'logs');

%% ========================================================================
%  END OF USER CONFIGURATION - Do not modify below unless you know what you're doing
%% ========================================================================

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
    fprintf('Expected file types: .cnt, .edf, .gdf\n');
    fprintf('Please add EEG files to the input folder and run again.\n\n');
    return;
end

fprintf('Found %d EEG file(s) to process:\n', length(eeg_files));
for i = 1:length(eeg_files)
    fprintf('  %d. %s\n', i, eeg_files(i).name);
end
fprintf('\n');

% Initialize batch tracking
batch_start_time = tic;
processing_times = [];
batch_stats = struct('processed', 0, 'failed', 0, 'total', length(eeg_files));

% Start EEGLAB (with or without GUI based on configuration)
if SHOW_EEGLAB_GUI
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
else
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');
end

% Process each EEG file
for i = 1:length(eeg_files)
    file_start_time = tic;

    filename = eeg_files(i).name;
    filepath = fullfile(eeg_files(i).folder, filename);
    [~, name_no_ext, ext] = fileparts(filename);

    % Progress indicator with estimated time remaining
    if i > 1 && ~isempty(processing_times)
        avg_time = mean(processing_times);
        remaining_files = length(eeg_files) - i + 1;
        est_remaining_time = avg_time * remaining_files;
        fprintf('\n[%d/%d] Processing: %s (Est. %.1f min remaining)\n', ...
            i, length(eeg_files), filename, est_remaining_time/60);
    else
        fprintf('\n[%d/%d] Processing: %s\n', i, length(eeg_files), filename);
    end

    % File validation
    if ~exist(filepath, 'file')
        fprintf('[ERROR] File not found: %s\n', filepath);
        batch_stats.failed = batch_stats.failed + 1;
        continue;
    end

    file_info = dir(filepath);
    if file_info.bytes == 0
        fprintf('[ERROR] Empty file: %s\n', filename);
        batch_stats.failed = batch_stats.failed + 1;
        continue;
    end

    % Smart logging: single file gets individual log, multiple files get batch log
    if length(eeg_files) == 1
        log_file = fullfile(LOG_FOLDER, [name_no_ext '_model3_log.txt']);
    else
        log_file = fullfile(LOG_FOLDER, 'Batch_model3_log.txt');
    end

    % Open log file (append mode for batch, write mode for single file)
    if length(eeg_files) == 1
        logID = fopen(log_file, 'w');
    else
        if i == 1
            logID = fopen(log_file, 'w');
        else
            logID = fopen(log_file, 'a');
        end
    end

    if logID == -1
        fprintf('[WARNING] Could not create log file for %s, continuing without logging\n', filename);
        logID = 1; % Use stdout as fallback
    end

    % Guarantee log file is closed even if an error occurs
    if logID ~= 1
        logCleanup = onCleanup(@() fclose(logID));
    end

    fprintf(logID, '=== Processing: %s ===\n', filename);
    fprintf(logID, 'Started: %s\n', datestr(now));
    fprintf(logID, 'File size: %.2f MB\n\n', file_info.bytes/1024/1024);

    %% Step 1: Import file with time range
    step_start = tic;
    try
        % Build import options based on configuration
        if isinf(IMPORT_TIME_RANGE_SEC)
            import_opts = {}; % Import all data
            time_range_str = 'all';
        else
            import_opts = {'blockrange', [0 IMPORT_TIME_RANGE_SEC]};
            time_range_str = sprintf('0–%d sec', IMPORT_TIME_RANGE_SEC);
        end

        switch lower(ext)
            case '.cnt'
                EEG = pop_biosig(filepath, import_opts{:}, ...
                    'importevent', 'on', 'rmeventchan', 'on', 'importannot', 'on', ...
                    'bdfeventmode', 4, 'blockepoch', 'on');
                fprintf(logID, 'Imported CNT file using pop_biosig() with time %s.\n', time_range_str);
            case '.edf'
                EEG = pop_biosig(filepath, import_opts{:}, ...
                    'importevent', 'on', 'rmeventchan', 'on', 'importannot', 'on', ...
                    'bdfeventmode', 4, 'blockepoch', 'off');
                fprintf(logID, 'Imported EDF file using pop_biosig() with time %s.\n', time_range_str);
            case '.gdf'
                EEG = pop_biosig(filepath, import_opts{:}, ...
                    'importevent', 'on', 'rmeventchan', 'on', 'importannot', 'on', ...
                    'bdfeventmode', 4, 'blockepoch', 'on');
                fprintf(logID, 'Imported GDF file using pop_biosig() with time %s.\n', time_range_str);
            otherwise
                fprintf(logID, 'Unsupported file format: %s\n', ext);
                fclose(logID);
                batch_stats.failed = batch_stats.failed + 1;
                continue;
        end
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);

        % Store initial metrics including signal statistics
        initial_channels = EEG.nbchan;
        initial_events = length(EEG.event);
        initial_duration = EEG.xmax;
        initial_mean_amplitude = mean(abs(EEG.data(:)));
        initial_std_amplitude = std(EEG.data(:));

        % Log import results with timing
        step_time = toc(step_start);
        fprintf(logID, 'Step 1 - Import: %d channels, %d events, %.3f sec, %d frames, %.1f Hz (%.2fs)\n', ...
            EEG.nbchan, length(EEG.event), EEG.xmax, EEG.pnts, EEG.srate, step_time);
    catch ME
        fprintf(logID, 'ERROR during import: %s\n', ME.message);
        fprintf('[ERROR] Import failed for %s: %s\n', filename, ME.message);
        batch_stats.failed = batch_stats.failed + 1;

        % Clean up any partial EEG data
        if exist('EEG', 'var') && ~isempty(EEG)
            clear EEG;
        end
        clear logCleanup; % Triggers onCleanup to close log file
        continue;
    end

    %% Step 1b: Clean channel labels (remove reference suffixes)
    if STRIP_CHANNEL_SUFFIXES
        channels_renamed = 0;
        for ch = 1:length(EEG.chanlocs)
            original_label = EEG.chanlocs(ch).labels;
            new_label = regexprep(original_label, CHANNEL_SUFFIX_PATTERN, '');
            if ~strcmp(original_label, new_label)
                EEG.chanlocs(ch).labels = new_label;
                channels_renamed = channels_renamed + 1;
            end
        end
        EEG = eeg_checkset(EEG);
        if channels_renamed > 0
            fprintf(logID, 'Step 1b - Cleaned %d channel labels (removed suffixes matching: %s)\n', ...
                channels_renamed, CHANNEL_SUFFIX_PATTERN);
        end
    end

    %% Step 2: Remove unwanted channels (configurable)
    step_start = tic;

    % Build comprehensive list of channels to potentially remove
    channels_to_remove = {};

    % Reference channels (various naming conventions)
    if REMOVE_REFERENCE_CHANNELS
        ref_channels = {'A1', 'A2', 'M1', 'M2', 'TP9', 'TP10', 'REF', 'Ref', 'ref', ...
            'LM', 'RM', 'LEFT_EAR', 'RIGHT_EAR', 'LE', 'RE'};
        channels_to_remove = [channels_to_remove, ref_channels];
    end

    % EOG channels (various naming conventions)
    if REMOVE_EOG_CHANNELS
        eog_channels = {'VEOG', 'veog', 'HEOG', 'heog', 'EOG1', 'EOG2', 'EOG', 'eog', ...
            'EOGH', 'EOGV', 'LEOG', 'REOG', 'UPEOG', 'LOWEOG', 'vEOG', 'hEOG', ...
            'EOG_L', 'EOG_R', 'EOG_U', 'EOG_D', 'VEOG+', 'VEOG-', 'HEOG+', 'HEOG-'};
        channels_to_remove = [channels_to_remove, eog_channels];
    end

    % EMG channels
    if REMOVE_EMG_CHANNELS
        emg_channels = {'EMG', 'emg', 'EMG1', 'EMG2', 'Chin', 'chin', 'CHIN', ...
            'EMG_CHIN', 'EMG_L', 'EMG_R', 'EMG_LT', 'EMG_RT'};
        channels_to_remove = [channels_to_remove, emg_channels];
    end

    % ECG channels
    if REMOVE_ECG_CHANNELS
        ecg_channels = {'ECG', 'ecg', 'EKG', 'ekg', 'ECG1', 'ECG2', 'HEART', 'heart', ...
            'ECG_L', 'ECG_R', 'EKG1', 'EKG2', 'CARD'};
        channels_to_remove = [channels_to_remove, ecg_channels];
    end

    % Add manual channels
    channels_to_remove = [channels_to_remove, MANUAL_CHANNELS_TO_REMOVE];

    % Get available channels in the data
    available_channels = {EEG.chanlocs.labels};

    % Find channels that actually exist in the data and should be removed
    toRemove = intersect(available_channels, channels_to_remove);

    % Apply safety filter: remove any protected channels from removal list
    if ~isempty(CHANNELS_TO_NEVER_REMOVE)
        protected_found = intersect(toRemove, CHANNELS_TO_NEVER_REMOVE);
        if ~isempty(protected_found)
            fprintf(logID, '  SAFETY: Protected channels found in removal list: %s - keeping these channels\n', ...
                strjoin(protected_found, ', '));
            toRemove = setdiff(toRemove, CHANNELS_TO_NEVER_REMOVE);
        end
    end

    % Log what was found and what will be removed
    fprintf(logID, 'Channel removal configuration:\n');
    fprintf(logID, '  Reference channels: %s, EOG channels: %s\n', ...
        string(REMOVE_REFERENCE_CHANNELS), string(REMOVE_EOG_CHANNELS));
    fprintf(logID, '  EMG channels: %s, ECG channels: %s\n', ...
        string(REMOVE_EMG_CHANNELS), string(REMOVE_ECG_CHANNELS));
    if ~isempty(MANUAL_CHANNELS_TO_REMOVE)
        fprintf(logID, '  Manual removal list: %s\n', strjoin(MANUAL_CHANNELS_TO_REMOVE, ', '));
    end
    fprintf(logID, '  Available channels (%d): %s\n', length(available_channels), strjoin(available_channels, ', '));

    % Perform channel removal
    if ~isempty(toRemove)
        EEG = pop_select(EEG, 'nochannel', toRemove);
        step_time = toc(step_start);
        fprintf(logID, 'Step 2 - Removed channels: %s (%d channels remaining, %.2fs)\n', ...
            strjoin(toRemove, ', '), EEG.nbchan, step_time);
    else
        step_time = toc(step_start);
        fprintf(logID, 'Step 2 - No channels removed (no matching channels found, %.2fs)\n', step_time);
    end

    %% Step 3: Downsample to target sample rate
    step_start = tic;
    if EEG.srate ~= TARGET_SAMPLE_RATE_HZ
        EEG = pop_resample(EEG, TARGET_SAMPLE_RATE_HZ);
        step_time = toc(step_start);
        fprintf(logID, 'Step 3 - Downsampled to %d Hz (%.2fs)\n', TARGET_SAMPLE_RATE_HZ, step_time);
    else
        step_time = toc(step_start);
        fprintf(logID, 'Step 3 - Already at %d Hz, no resampling needed (%.2fs)\n', TARGET_SAMPLE_RATE_HZ, step_time);
    end

    %% Step 4: Bandpass filter
    step_start = tic;
    EEG = pop_eegfiltnew(EEG, FILTER_LOW_HZ, FILTER_HIGH_HZ, [], 0, [], 0);
    step_time = toc(step_start);
    fprintf(logID, 'Step 4 - Applied bandpass filter: %.1f–%d Hz (%.2fs)\n', FILTER_LOW_HZ, FILTER_HIGH_HZ, step_time);

    %% Step 5: Clean raw data with ASR
    step_start = tic;
    data_before_cleaning = size(EEG.data, 2);
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion', 'off', ...
        'ChannelCriterion', 'off', ...
        'LineNoiseCriterion', 'off', ...
        'Highpass', 'off', ...
        'BurstCriterion', ASR_BURST_CRITERION, ...
        'WindowCriterion', ASR_WINDOW_CRITERION, ...
        'BurstRejection', 'on', ...
        'Distance', 'Euclidian', ...
        'WindowCriterionTolerances', ASR_WINDOW_TOLERANCES);
    data_after_cleaning = size(EEG.data, 2);
    data_retention = (data_after_cleaning / data_before_cleaning) * 100;
    step_time = toc(step_start);
    fprintf(logID, 'Step 5 - Applied clean_rawdata (%d events after cleaning, %.1f%% data retained, %.2fs)\n', ...
        length(EEG.event), data_retention, step_time);

    %% Step 6: Add channel locations (Dynamic selection based on channel count)
    step_start = tic;
    channel_locations_added = false;

    % Determine appropriate channel location file based on number of channels
    num_channels = EEG.nbchan;
    fprintf(logID, 'Detected %d channels, selecting appropriate channel location file...\n', num_channels);

    % Channel location file priority list based on channel count
    if num_channels <= 19
        chan_files = {'Standard-10-20-Cap19.ced'};
        montage_type = '19-channel Standard 10-20';
    elseif num_channels <= 21
        chan_files = {'Standard-10-20-Cap21.ced', 'Standard-10-20-Cap19.ced'};
        montage_type = '21-channel Standard 10-20';
    elseif num_channels <= 25
        chan_files = {'Standard-10-20-Cap25.ced', 'Standard-10-10-Cap25.ced', 'Standard-10-20-Cap21.ced'};
        montage_type = '25-channel montage';
    elseif num_channels <= 32
        chan_files = {'Standard-10-20-Cap32.ced', 'Standard-10-10-Cap32.ced', 'Standard-10-20-Cap25.ced'};
        montage_type = '32-channel montage';
    elseif num_channels <= 64
        chan_files = {'Standard-10-5-Cap64.ced', 'Standard-10-10-Cap64.ced', 'Standard-10-20-Cap32.ced'};
        montage_type = '64-channel montage';
    elseif num_channels <= 128
        chan_files = {'Standard-10-5-Cap128.ced', 'Standard-10-5-Cap64.ced'};
        montage_type = '128-channel montage';
    else
        chan_files = {'Standard-10-5-Cap128.ced'};
        montage_type = 'high-density montage';
    end

    % Try each channel location file in order of preference
    for file_idx = 1:length(chan_files)
        current_file = chan_files{file_idx};
        try
            % Try direct lookup first
            EEG = pop_chanedit(EEG, 'lookup', current_file);
            channel_locations_added = true;
            step_time = toc(step_start);
            fprintf(logID, 'Step 6 - Added channel locations using %s for %s (%.2fs)\n', current_file, montage_type, step_time);
            break;
        catch ME1
            try
                % Try full path construction as fallback
                eeglab_path = which('eeglab');
                if ~isempty(eeglab_path)
                    eeglab_dir = fileparts(eeglab_path);
                    chan_file_path = fullfile(eeglab_dir, 'functions', 'supportfiles', 'channel_location_files', 'eeglab', current_file);
                    if exist(chan_file_path, 'file')
                        EEG = pop_chanedit(EEG, 'lookup', chan_file_path);
                        channel_locations_added = true;
                        step_time = toc(step_start);
                        fprintf(logID, 'Step 6 - Added channel locations using full path %s for %s (%.2fs)\n', current_file, montage_type, step_time);
                        break;
                    end
                end
            catch ME2
                % Continue to next file
            end
        end

        % Log attempt if not the last file
        if file_idx < length(chan_files)
            fprintf(logID, '  %s not found, trying next option...\n', current_file);
        end
    end

    % Final fallback and warning if no channel locations were added
    if ~channel_locations_added
        step_time = toc(step_start);
        fprintf(logID, 'Step 6 - WARNING: Could not add channel locations for %d channels (%.2fs)\n', num_channels, step_time);
        fprintf(logID, '  >>> ICA ARTIFACT REMOVAL WILL BE SKIPPED FOR THIS FILE <<<\n');
        fprintf(logID, '  ICLabel requires channel locations to classify components.\n');
        fprintf('\n');
        fprintf('  *************************************************************\n');
        fprintf('  * WARNING: Channel locations not added for %s\n', filename);
        fprintf('  * ICA ARTIFACT REMOVAL WILL BE SKIPPED FOR THIS FILE\n');
        fprintf('  * Channels: %d | Files searched: %s\n', num_channels, strjoin(chan_files, ', '));
        fprintf('  *************************************************************\n');
        fprintf('\n');
    end

    % Store initial PSD for before/after ICA comparison (after basic preprocessing)
    try
        fs_initial = EEG.srate;
        nfft_initial = min(2^nextpow2(EEG.pnts), 2048);

        % Calculate PSD for each channel separately, then average the PSDs
        % This preserves frequency content better than averaging signals first
        channel_psds = [];
        for ch = 1:EEG.nbchan
            [psd_ch, freqs_initial] = pwelch(EEG.data(ch, :), hann(nfft_initial/4), nfft_initial/8, nfft_initial, fs_initial);
            channel_psds(ch, :) = psd_ch;
        end
        % Average the PSDs across channels (not the raw signals)
        psd_initial = mean(channel_psds, 1);

        % Calculate initial band powers (after basic preprocessing, before ICA)
        delta_initial = freqs_initial >= 0.5 & freqs_initial <= 4;
        theta_initial = freqs_initial >= 4 & freqs_initial <= 8;
        alpha_initial = freqs_initial >= 8 & freqs_initial <= 13;
        beta_initial = freqs_initial >= 13 & freqs_initial <= 30;
        gamma_initial = freqs_initial >= 30 & freqs_initial <= 40;

        % Use mean instead of sum for band powers, convert to dB
        initial_delta_power = 10*log10(mean(psd_initial(delta_initial)));
        initial_theta_power = 10*log10(mean(psd_initial(theta_initial)));
        initial_alpha_power = 10*log10(mean(psd_initial(alpha_initial)));
        initial_beta_power = 10*log10(mean(psd_initial(beta_initial)));
        initial_gamma_power = 10*log10(mean(psd_initial(gamma_initial)));
        initial_total_power = 10*log10(mean(psd_initial(freqs_initial >= 0.5 & freqs_initial <= 40)));
    catch
        initial_delta_power = NaN; initial_theta_power = NaN; initial_alpha_power = NaN;
        initial_beta_power = NaN; initial_gamma_power = NaN; initial_total_power = NaN;
    end

    %% Step 7: Run ICA decomposition
    step_start = tic;
    try
        % Run ICA using runica algorithm (Extended Infomax by default)
        EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1);
        step_time = toc(step_start);
        fprintf(logID, 'Step 7 - ICA decomposition completed (%d components, %.2fs)\n', size(EEG.icaweights,1), step_time);
    catch ME
        step_time = toc(step_start);
        fprintf(logID, 'Step 7 - ERROR: ICA decomposition failed: %s (%.2fs)\n', ME.message, step_time);
        fprintf('[ERROR] ICA failed for %s: %s\n', filename, ME.message);
        % Continue without ICA if it fails
    end

    %% Step 8: Classify components using ICLabel
    step_start = tic;
    components_removed = [];

    % Check if ICA was successful and channel locations are available
    if ~exist('EEG', 'var') || isempty(EEG.icaweights)
        step_time = toc(step_start);
        fprintf(logID, 'Step 8 - SKIPPED: No ICA decomposition available (%.2fs)\n', step_time);
    elseif ~channel_locations_added || isempty([EEG.chanlocs.theta])
        step_time = toc(step_start);
        fprintf(logID, 'Step 8 - SKIPPED: Channel locations required for ICLabel (%.2fs)\n', step_time);
        fprintf('[WARNING] ICLabel requires channel locations for %s\n', filename);
    else
        try
            % Run ICLabel to classify ICA components
            EEG = pop_iclabel(EEG, 'default');

            % Get ICLabel classifications
            % Use configurable threshold for brain components
            classifications = EEG.etc.ic_classification.ICLabel.classifications;

            % Simple logic: Keep only components where Brain > threshold, remove all others
            components_to_remove = [];

            for comp = 1:size(classifications, 1)
                % classifications columns: [Brain, Muscle, Eye, Heart, Line Noise, Channel Noise, Other]
                brain_prob = classifications(comp, 1);

                % Find the dominant classification for proper labeling
                [max_prob, max_idx] = max(classifications(comp, :));
                component_types = {'Brain', 'Muscle', 'Eye', 'Heart', 'Line Noise', 'Channel Noise', 'Other'};
                dominant_type = component_types{max_idx};

                % Remove if brain probability <= threshold
                if brain_prob <= BRAIN_THRESHOLD
                    components_to_remove(end+1) = comp;
                    fprintf(logID, '  Component %d: %s %.1f%% (Brain %.1f%% <= %.0f%%) - marked for removal\n', ...
                        comp, dominant_type, max_prob*100, brain_prob*100, BRAIN_THRESHOLD*100);
                else
                    fprintf(logID, '  Component %d: %s %.1f%% (Brain %.1f%% > %.0f%%) - retained\n', ...
                        comp, dominant_type, max_prob*100, brain_prob*100, BRAIN_THRESHOLD*100);
                end
            end

            step_time = toc(step_start);
            fprintf(logID, 'Step 8 - ICLabel classification completed, %d components marked for removal (%.2fs)\n', ...
                length(components_to_remove), step_time);
            components_removed = components_to_remove;

        catch ME
            step_time = toc(step_start);
            fprintf(logID, 'Step 8 - WARNING: ICLabel classification failed: %s (%.2fs)\n', ME.message, step_time);
            fprintf('[WARNING] ICLabel failed for %s: %s\n', filename, ME.message);
            % Continue without ICLabel if it fails
        end
    end

    %% Step 9: Remove artifact components
    step_start = tic;
    if ~isempty(components_removed) && exist('classifications', 'var')
        try
            % Remove the identified artifact components
            EEG = pop_subcomp(EEG, components_removed, 0);
            step_time = toc(step_start);
            fprintf(logID, 'Step 9 - Removed %d artifact components: [%s] (%.2fs)\n', ...
                length(components_removed), num2str(components_removed), step_time);

            % Log details of removed components
            total_components = size(classifications, 1);
            brain_components = total_components - length(components_removed);
            fprintf(logID, '  Total components: %d, Brain components retained: %d (%.1f%%)\n', ...
                total_components, brain_components, (brain_components/total_components)*100);
        catch ME
            step_time = toc(step_start);
            fprintf(logID, 'Step 9 - ERROR: Component removal failed: %s (%.2fs)\n', ME.message, step_time);
            fprintf('[ERROR] Component removal failed for %s: %s\n', filename, ME.message);
        end
    else
        step_time = toc(step_start);
        if ~exist('classifications', 'var')
            fprintf(logID, 'Step 9 - No components removed (ICLabel classification not available, %.2fs)\n', step_time);
        else
            fprintf(logID, 'Step 9 - No artifact components identified for removal (%.2fs)\n', step_time);
        end
    end

    %% Step 10: Re-reference to average
    step_start = tic;
    if ~strcmpi(EEG.ref, 'averef')
        EEG = pop_reref(EEG, []);
        step_time = toc(step_start);
        fprintf(logID, 'Step 10 - Re-referenced to average (%.2fs)\n', step_time);
    else
        step_time = toc(step_start);
        fprintf(logID, 'Step 10 - Already average referenced, no change needed (%.2fs)\n', step_time);
    end

    %% Step 11: Save as EDF
    step_start = tic;
    try
        EEG = eeg_checkset(EEG);
        out_file = fullfile(OUTPUT_FOLDER, [name_no_ext '_model3_preprocessed.edf']);
        pop_writeeeg(EEG, out_file, 'TYPE', 'EDF');
        step_time = toc(step_start);
        fprintf(logID, 'Step 11 - Saved preprocessed EDF: %s (%.2fs)\n', [name_no_ext '_model3_preprocessed.edf'], step_time);

        % Calculate total processing time and quality metrics
        total_processing_time = toc(file_start_time);
        processing_times(end+1) = total_processing_time;

        % Calculate final signal statistics
        final_mean_amplitude = mean(abs(EEG.data(:)));
        final_std_amplitude = std(EEG.data(:));
        amplitude_ratio = final_mean_amplitude / initial_mean_amplitude;
        std_ratio = final_std_amplitude / initial_std_amplitude;

        % Enhanced quality validation metrics

        % 1. Signal-to-Noise Ratio calculation (simplified estimate)
        % Use the ratio of signal variance to estimate noise reduction
        if initial_std_amplitude > 0 && final_std_amplitude > 0
            snr_improvement = 20 * log10(initial_std_amplitude / final_std_amplitude);
        else
            snr_improvement = NaN;
        end

        % 2. Power Spectral Density Analysis
        try
            % Calculate PSD for key frequency bands
            fs = EEG.srate;
            nfft = min(2^nextpow2(EEG.pnts), 2048); % Limit FFT size for efficiency

            % Calculate PSD for each channel separately, then average the PSDs
            % This preserves frequency content better than averaging signals first
            channel_psds = [];
            for ch = 1:EEG.nbchan
                [psd_ch, freqs] = pwelch(EEG.data(ch, :), hann(nfft/4), nfft/8, nfft, fs);
                channel_psds(ch, :) = psd_ch;
            end
            % Average the PSDs across channels (not the raw signals)
            psd = mean(channel_psds, 1);

            % Define frequency bands
            delta_band = freqs >= 0.5 & freqs <= 4;
            theta_band = freqs >= 4 & freqs <= 8;
            alpha_band = freqs >= 8 & freqs <= 13;
            beta_band = freqs >= 13 & freqs <= 30;
            gamma_band = freqs >= 30 & freqs <= 40;

            % Calculate band power (log scale for better interpretation)
            delta_power = 10*log10(mean(psd(delta_band)));
            theta_power = 10*log10(mean(psd(theta_band)));
            alpha_power = 10*log10(mean(psd(alpha_band)));
            beta_power = 10*log10(mean(psd(beta_band)));
            gamma_power = 10*log10(mean(psd(gamma_band)));

            % Total power and relative band powers
            total_power = 10*log10(mean(psd(freqs >= 0.5 & freqs <= 40)));
            alpha_beta_ratio = alpha_power - beta_power; % Alpha dominance indicator

            % Calculate power changes from initial to final
            if ~isnan(initial_delta_power)
                delta_change = delta_power - initial_delta_power;
                theta_change = theta_power - initial_theta_power;
                alpha_change = alpha_power - initial_alpha_power;
                beta_change = beta_power - initial_beta_power;
                gamma_change = gamma_power - initial_gamma_power;
                total_power_change = total_power - initial_total_power;
            else
                delta_change = NaN; theta_change = NaN; alpha_change = NaN;
                beta_change = NaN; gamma_change = NaN; total_power_change = NaN;
            end

        catch
            delta_power = NaN; theta_power = NaN; alpha_power = NaN;
            beta_power = NaN; gamma_power = NaN; total_power = NaN;
            alpha_beta_ratio = NaN;
            delta_change = NaN; theta_change = NaN; alpha_change = NaN;
            beta_change = NaN; gamma_change = NaN; total_power_change = NaN;
        end

        % 3. Advanced Statistical Measures
        try
            % Kurtosis and skewness for artifact detection
            data_kurtosis = mean(kurtosis(EEG.data, 1, 2)); % Average across channels
            data_skewness = mean(skewness(EEG.data, 1, 2));

            % Channel-wise signal quality
            channel_std = std(EEG.data, 0, 2); % Standard deviation per channel
            channel_quality = std(channel_std) / mean(channel_std); % Coefficient of variation

            % Temporal stability (sliding window variance)
            window_size = round(fs * 2); % 2-second windows
            if EEG.pnts > window_size * 2
                num_windows = floor(EEG.pnts / window_size);
                window_vars = zeros(num_windows, 1);
                for w = 1:num_windows
                    start_idx = (w-1) * window_size + 1;
                    end_idx = min(w * window_size, EEG.pnts);
                    window_data = EEG.data(:, start_idx:end_idx);
                    window_vars(w) = mean(var(window_data, 0, 2));
                end
                temporal_stability = std(window_vars) / mean(window_vars);
            else
                temporal_stability = NaN;
            end

        catch
            data_kurtosis = NaN; data_skewness = NaN;
            channel_quality = NaN; temporal_stability = NaN;
        end

        % 4. Artifact reduction estimate (with division by zero guard)
        if final_std_amplitude > 0
            artifact_reduction_estimate = initial_std_amplitude / final_std_amplitude;
        else
            artifact_reduction_estimate = NaN;
            fprintf(logID, '  WARNING: Final signal has zero variability - possible over-processing\n');
        end

        % 5. Component classification summary and ICA consistency metrics
        if exist('classifications', 'var')
            % Count ALL components by their dominant classification
            total_components = size(classifications, 1);
            [~, all_dominant_classes] = max(classifications, [], 2);

            % Create mask for retained components (not in removal list)
            retained_mask = true(total_components, 1);
            if ~isempty(components_removed)
                retained_mask(components_removed) = false;
            end

            % Count RETAINED components by dominant class
            brain_components = sum(all_dominant_classes == 1 & retained_mask);
            muscle_components = sum(all_dominant_classes == 2 & retained_mask);
            eye_components = sum(all_dominant_classes == 3 & retained_mask);
            heart_components = sum(all_dominant_classes == 4 & retained_mask);
            line_noise_components = sum(all_dominant_classes == 5 & retained_mask);
            channel_noise_components = sum(all_dominant_classes == 6 & retained_mask);
            other_components = sum(all_dominant_classes == 7 & retained_mask);

            % Count REMOVED components by dominant class for detailed reporting
            removed_brain = sum(all_dominant_classes == 1 & ~retained_mask);
            removed_muscle = sum(all_dominant_classes == 2 & ~retained_mask);
            removed_eye = sum(all_dominant_classes == 3 & ~retained_mask);
            removed_heart = sum(all_dominant_classes == 4 & ~retained_mask);
            removed_line_noise = sum(all_dominant_classes == 5 & ~retained_mask);
            removed_channel_noise = sum(all_dominant_classes == 6 & ~retained_mask);
            removed_other = sum(all_dominant_classes == 7 & ~retained_mask);

            % Group non-brain categories for summary display
            other_artifacts = heart_components + line_noise_components + channel_noise_components + other_components;
            total_artifacts_removed = removed_muscle + removed_eye + removed_heart + ...
                removed_line_noise + removed_channel_noise + ...
                removed_other + removed_brain;

            % Classification consistency score (how confident ICLabel was)
            max_probs = max(classifications, [], 2);
            classification_confidence = mean(max_probs);

            % ICA consistency metrics
            brain_probs = classifications(:,1);
            brain_consistency = std(brain_probs(brain_probs > 0.7)); % Variability in brain component confidence
            if isempty(brain_probs(brain_probs > 0.7)) || length(brain_probs(brain_probs > 0.7)) < 2
                brain_consistency = 0; % Perfect consistency if only one or no brain components
            end

            % Component separation quality (how well separated are the classes)
            prob_entropy = -sum(classifications .* log2(classifications + eps), 2); % Information entropy per component
            avg_component_entropy = mean(prob_entropy); % Lower = better separation

        else
            brain_components = NaN; muscle_components = NaN; eye_components = NaN;
            heart_components = NaN; line_noise_components = NaN; channel_noise_components = NaN;
            other_components = NaN; other_artifacts = NaN; classification_confidence = NaN;
            brain_consistency = NaN; avg_component_entropy = NaN;
            removed_brain = 0; removed_muscle = 0; removed_eye = 0; removed_heart = 0;
            removed_line_noise = 0; removed_channel_noise = 0; removed_other = 0;
            total_artifacts_removed = 0;
        end

        % Final summary with enhanced quality metrics
        fprintf(logID, '\n=== PROCESSING COMPLETE ===\n');
        fprintf(logID, 'Total processing time: %.2f seconds\n', total_processing_time);
        fprintf(logID, 'Quality metrics:\n');
        fprintf(logID, '  Channels: %d → %d\n', initial_channels, EEG.nbchan);
        fprintf(logID, '  Events: %d → %d\n', initial_events, length(EEG.event));
        fprintf(logID, '  Duration: %.3f → %.3f sec\n', initial_duration, EEG.xmax);
        fprintf(logID, '  Data retention: %.1f%%\n', data_retention);
        if exist('components_removed', 'var') && ~isempty(components_removed)
            fprintf(logID, '  ICA components removed: %d (%s)\n', length(components_removed), num2str(components_removed));
        else
            fprintf(logID, '  ICA components removed: 0 (no artifacts identified)\n');
        end
        % Signal amplitude and variability with adjusted over-processing warnings
        % Normal EEG preprocessing can reduce amplitude by 3-10x and variability by 20-100x
        % Only warn if reductions are truly extreme (>20x amplitude or >200x variability)
        amplitude_warning = amplitude_ratio < 0.05; % Less than 1/20th
        variability_warning = std_ratio < 0.005; % Less than 1/200th

        if amplitude_warning || variability_warning
            if amplitude_warning
                fprintf(logID, '  Signal amplitude: %.2f → %.2f µV (%.2fx) - WARNING: Extreme reduction (>20x)\n', ...
                    initial_mean_amplitude, final_mean_amplitude, amplitude_ratio);
            else
                fprintf(logID, '  Signal amplitude: %.2f → %.2f µV (%.2fx)\n', ...
                    initial_mean_amplitude, final_mean_amplitude, amplitude_ratio);
            end

            if variability_warning
                fprintf(logID, '  Signal variability: %.2f → %.2f µV (%.2fx) - WARNING: Possible over-processing (>200x)\n', ...
                    initial_std_amplitude, final_std_amplitude, std_ratio);
            else
                fprintf(logID, '  Signal variability: %.2f → %.2f µV (%.2fx)\n', ...
                    initial_std_amplitude, final_std_amplitude, std_ratio);
            end
        else
            fprintf(logID, '  Signal amplitude: %.2f → %.2f µV (%.2fx)\n', ...
                initial_mean_amplitude, final_mean_amplitude, amplitude_ratio);
            fprintf(logID, '  Signal variability: %.2f → %.2f µV (%.2fx)\n', ...
                initial_std_amplitude, final_std_amplitude, std_ratio);
        end

        % Enhanced quality metrics (only print if valid)
        if ~isnan(snr_improvement)
            fprintf(logID, '  SNR improvement: %.1f dB\n', snr_improvement);
        end
        if ~isnan(artifact_reduction_estimate)
            % High values (>20x) are normal when removing many artifact components
            if artifact_reduction_estimate > 100
                fprintf(logID, '  Artifact reduction estimate: %.2fx (very aggressive cleaning)\n', artifact_reduction_estimate);
            else
                fprintf(logID, '  Artifact reduction estimate: %.2fx\n', artifact_reduction_estimate);
            end
        end

        % Power Spectral Density metrics
        if ~isnan(total_power)
            fprintf(logID, '  Spectral Analysis:\n');
            fprintf(logID, '    Total power (0.5-40 Hz): %.1f dB\n', total_power);
            fprintf(logID, '    Delta (0.5-4 Hz): %.1f dB, Theta (4-8 Hz): %.1f dB\n', delta_power, theta_power);
            fprintf(logID, '    Alpha (8-13 Hz): %.1f dB, Beta (13-30 Hz): %.1f dB\n', alpha_power, beta_power);
            fprintf(logID, '    Gamma (30-40 Hz): %.1f dB\n', gamma_power);
            if ~isnan(alpha_beta_ratio)
                fprintf(logID, '    Alpha/Beta ratio: %.1f dB\n', alpha_beta_ratio);
            end

            % Before/after power comparison with validation
            if ~isnan(total_power_change)
                % Flag unrealistic power changes (likely calculation error)
                % Normal EEG preprocessing typically shows 2-10 dB changes, up to 15 dB is reasonable
                if abs(total_power_change) > 30
                    fprintf(logID, '  Power Changes (Before vs After) - WARNING: Very large change (likely error):\n');
                    fprintf(logID, '    Total power change: %+.1f dB (check for calculation error)\n', total_power_change);
                elseif abs(total_power_change) > 15
                    fprintf(logID, '  Power Changes (Before vs After) - NOTE: Substantial change:\n');
                    fprintf(logID, '    Total power change: %+.1f dB\n', total_power_change);
                else
                    fprintf(logID, '  Power Changes (Before vs After):\n');
                    fprintf(logID, '    Total power change: %+.1f dB\n', total_power_change);
                end
                fprintf(logID, '    Delta: %+.1f dB, Theta: %+.1f dB\n', delta_change, theta_change);
                fprintf(logID, '    Alpha: %+.1f dB, Beta: %+.1f dB, Gamma: %+.1f dB\n', ...
                    alpha_change, beta_change, gamma_change);
            end
        end

        % Advanced statistical measures
        if ~isnan(data_kurtosis)
            fprintf(logID, '  Statistical Quality:\n');
            fprintf(logID, '    Kurtosis: %.2f, Skewness: %.2f\n', data_kurtosis, data_skewness);
            if ~isnan(channel_quality)
                fprintf(logID, '    Channel consistency: %.3f\n', channel_quality);
            end
            if ~isnan(temporal_stability)
                fprintf(logID, '    Temporal stability: %.3f\n', temporal_stability);
            end
        end

        % ICA and component metrics
        if ~isnan(classification_confidence)
            fprintf(logID, '  ICA Quality:\n');
            fprintf(logID, '    ICLabel confidence: %.1f%% (avg)\n', classification_confidence*100);
            fprintf(logID, '    RETAINED components: Brain=%d, Muscle=%d, Eye=%d, Other=%d\n', ...
                brain_components, muscle_components, eye_components, other_artifacts);
            if other_artifacts > 0
                fprintf(logID, '    RETAINED other artifacts: Heart=%d, LineNoise=%d, ChannelNoise=%d, Other=%d\n', ...
                    heart_components, line_noise_components, channel_noise_components, other_components);
            end
            if exist('total_artifacts_removed', 'var') && total_artifacts_removed > 0
                fprintf(logID, '    REMOVED components: Brain=%d, Muscle=%d, Eye=%d, Heart=%d, LineNoise=%d, ChannelNoise=%d, Other=%d\n', ...
                    removed_brain, removed_muscle, removed_eye, removed_heart, removed_line_noise, removed_channel_noise, removed_other);
            end
            if ~isnan(brain_consistency)
                fprintf(logID, '    Brain component consistency: %.3f\n', brain_consistency);
            end
            if ~isnan(avg_component_entropy)
                fprintf(logID, '    Component separation quality: %.2f bits\n', avg_component_entropy);
            end
        end
        fprintf(logID, 'Final: %d channels, %d events, %.3f sec, %d frames, %.1f Hz\n', ...
            EEG.nbchan, length(EEG.event), EEG.xmax, EEG.pnts, EEG.srate);
        fprintf(logID, '============================\n\n');

        batch_stats.processed = batch_stats.processed + 1;
        fprintf('[SUCCESS] %s processed in %.2f seconds\n', filename, total_processing_time);
    catch ME
        fprintf(logID, 'ERROR saving EDF: %s\n', ME.message);
        fprintf('[ERROR] Failed to save %s: %s\n', filename, ME.message);
        batch_stats.failed = batch_stats.failed + 1;
    end

    % onCleanup handles fclose automatically when logCleanup goes out of scope
    clear logCleanup;
end

% Display final batch summary
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

if ~isempty(processing_times)
    fprintf('Average processing time per file: %.2f ± %.2f seconds\n', ...
        mean(processing_times), std(processing_times));
    fprintf('Processing time range: %.2f - %.2f seconds\n', ...
        min(processing_times), max(processing_times));
end

% Show which log file was created
if length(eeg_files) == 1
    fprintf('\nLog file created: %s_model3_log.txt\n', eeg_files(1).name(1:end-4));
else
    fprintf('\nBatch log file created: Batch_model3_log.txt\n');
end

fprintf('EDF files saved in: %s\nLogs saved in: %s\n', OUTPUT_FOLDER, LOG_FOLDER);

% Refresh EEGLAB GUI if it was shown
if SHOW_EEGLAB_GUI
    eeglab redraw;
end