% USER CONFIGURATION
% Required: Fp1, Fp2, F3, F4, C3, C4, P3, P4, O1, O2, F7, F8, T3, T4, T5, T6, Fz, Cz, Pz
% Remove: A1, A2 (reference channels), veog (vertical EOG if present)

input_folder = fullfile(pwd, 'eeg_files');
output_folder = fullfile(pwd, 'output');
log_folder = fullfile(pwd, 'logs');

% Create folders if they don't exist
if ~exist(input_folder, 'dir'), mkdir(input_folder); end
if ~exist(output_folder, 'dir'), mkdir(output_folder); end
if ~exist(log_folder, 'dir'), mkdir(log_folder); end

% Get .cnt, .edf, and .gdf files from input folder
cnt_files = dir(fullfile(input_folder, '*.cnt'));
edf_files = dir(fullfile(input_folder, '*.edf'));
gdf_files = dir(fullfile(input_folder, '*.gdf'));
eeg_files = [cnt_files; edf_files; gdf_files];

% Check if any EEG files were found
if isempty(eeg_files)
    fprintf('\nERROR: No EEG files found in %s\n', input_folder);
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

% Start EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

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
        log_file = fullfile(log_folder, [name_no_ext '_log.txt']);
    else
        log_file = fullfile(log_folder, 'Batch_log.txt');
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
    
    fprintf(logID, '=== Processing: %s ===\n', filename);
    fprintf(logID, 'Started: %s\n', datestr(now));
    fprintf(logID, 'File size: %.2f MB\n\n', file_info.bytes/1024/1024);
    
    %% Step 1: Import file with time range 0–180 sec
    step_start = tic;
    try
        switch lower(ext)
            case '.cnt'
                EEG = pop_biosig(filepath, 'blockrange', [0 180], ...
                    'importevent', 'on', 'rmeventchan', 'on', 'importannot', 'on', ...
                    'bdfeventmode', 4, 'blockepoch', 'on');
                fprintf(logID, 'Imported CNT file using pop_biosig() with time 0–180 sec.\n');            
            case '.edf'
                EEG = pop_biosig(filepath, 'blockrange', [0 180], ...
                    'importevent', 'on', 'rmeventchan', 'on', 'importannot', 'on', ...
                    'bdfeventmode', 4, 'blockepoch', 'on');
                fprintf(logID, 'Imported EDF file using pop_biosig() with time 0–180 sec.\n');
            case '.gdf'
                EEG = pop_biosig(filepath, 'blockrange', [0 180], ...
                    'importevent', 'on', 'rmeventchan', 'on', 'importannot', 'on', ...
                    'bdfeventmode', 4, 'blockepoch', 'on');
                fprintf(logID, 'Imported GDF file using pop_biosig() with time 0–180 sec.\n');            
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
            EEG.nbchan, length(EEG.event), EEG.xmax, EEG.pnts, EEG.srate, step_time);    catch ME
        fprintf(logID, 'ERROR during import: %s\n', ME.message);
        fprintf('[ERROR] Import failed for %s: %s\n', filename, ME.message);
        if logID ~= 1, fclose(logID); end
        batch_stats.failed = batch_stats.failed + 1;
        
        % Clean up any partial EEG data
        if exist('EEG', 'var') && ~isempty(EEG)
            clear EEG;
        end
        continue;
    end
    
    %% Step 2: Remove reference and unwanted channels if present
    step_start = tic;
    % Standard channels to remove: A1, A2 (reference channels)
    % Optional channels to remove: veog (vertical EOG if present)
    channels_to_remove = {'A1', 'A2', 'veog', 'VEOG'};    
    toRemove = intersect({EEG.chanlocs.labels}, channels_to_remove);
    if ~isempty(toRemove)
        EEG = pop_select(EEG, 'nochannel', toRemove);
        step_time = toc(step_start);
        fprintf(logID, 'Step 2 - Removed channels: %s (%d channels remaining, %.2fs)\n', ...
            strjoin(toRemove, ', '), EEG.nbchan, step_time);
    else
        step_time = toc(step_start);
        fprintf(logID, 'Step 2 - No channels removed (A1/A2/VEOG not found, %.2fs)\n', step_time);
    end    
    
    %% Step 3: Downsample to 125 Hz
    step_start = tic;
    if EEG.srate ~= 125
        EEG = pop_resample(EEG, 125);
        step_time = toc(step_start);
        fprintf(logID, 'Step 3 - Downsampled to 125 Hz (%.2fs)\n', step_time);
    else
        step_time = toc(step_start);
        fprintf(logID, 'Step 3 - Already at 125 Hz, no resampling needed (%.2fs)\n', step_time);    
    end
    
    %% Step 4: Bandpass filter: 0.5–40 Hz
    step_start = tic;
    EEG = pop_eegfiltnew(EEG, 0.5, 40, [], 0, [], 1);
    step_time = toc(step_start);
    fprintf(logID, 'Step 4 - Applied bandpass filter: 0.5–40 Hz (%.2fs)\n', step_time);    
    
    %% Step 5: Clean raw data with parameters matching manual process
    step_start = tic;
    data_before_cleaning = size(EEG.data, 2);
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion', 'off', ...
        'ChannelCriterion', 'off', ...
        'LineNoiseCriterion', 'off', ...
        'Highpass', 'off', ...
        'BurstCriterion', 20, ...
        'WindowCriterion', 0.25, ...
        'BurstRejection', 'on', ...
        'Distance', 'Euclidian', ...
        'WindowCriterionTolerances', [-Inf 7]);
    data_after_cleaning = size(EEG.data, 2);
    data_retention = (data_after_cleaning / data_before_cleaning) * 100;
    step_time = toc(step_start);
    fprintf(logID, 'Step 5 - Applied clean_rawdata (%d events after cleaning, %.1f%% data retained, %.2fs)\n', ...
        length(EEG.event), data_retention, step_time);    
    
    %% Step 6: Re-reference to average
    step_start = tic;
    if ~strcmpi(EEG.ref, 'averef')
        EEG = pop_reref(EEG, []);
        step_time = toc(step_start);
        fprintf(logID, 'Step 6 - Re-referenced to average (%.2fs)\n', step_time);
    else
        step_time = toc(step_start);
        fprintf(logID, 'Step 6 - Already average referenced, no change needed (%.2fs)\n', step_time);
    end
    
    %% Step 7: Save as EDF
    step_start = tic;
    try
        EEG = eeg_checkset(EEG);
        out_file = fullfile(output_folder, [name_no_ext '_preprocessed.edf']);
        pop_writeeeg(EEG, out_file, 'TYPE', 'EDF');
        step_time = toc(step_start);
        fprintf(logID, 'Step 7 - Saved preprocessed EDF: %s (%.2fs)\n', [name_no_ext '_preprocessed.edf'], step_time);
        
        % Calculate total processing time and quality metrics
        total_processing_time = toc(file_start_time);
        processing_times(end+1) = total_processing_time;
        
        % Calculate final signal statistics
        final_mean_amplitude = mean(abs(EEG.data(:)));
        final_std_amplitude = std(EEG.data(:));
        amplitude_ratio = final_mean_amplitude / initial_mean_amplitude;
        
        % Final summary with enhanced quality metrics
        fprintf(logID, '\n=== PROCESSING COMPLETE ===\n');
        fprintf(logID, 'Total processing time: %.2f seconds\n', total_processing_time);
        fprintf(logID, 'Quality metrics:\n');
        fprintf(logID, '  Channels: %d → %d\n', initial_channels, EEG.nbchan);
        fprintf(logID, '  Events: %d → %d\n', initial_events, length(EEG.event));
        fprintf(logID, '  Duration: %.3f → %.3f sec\n', initial_duration, EEG.xmax);
        fprintf(logID, '  Data retention: %.1f%%\n', data_retention);
        fprintf(logID, '  Signal amplitude: %.2f → %.2f µV (%.2fx)\n', ...
            initial_mean_amplitude, final_mean_amplitude, amplitude_ratio);
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

    if logID ~= 1, fclose(logID); end
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
    fprintf('\nLog file created: %s_log.txt\n', eeg_files(1).name(1:end-4));
else
    fprintf('\nBatch log file created: Batch_log.txt\n');
end

fprintf('EDF files saved in: %s\nLogs saved in: %s\n', output_folder, log_folder);