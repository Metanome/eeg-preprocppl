% USER CONFIGURATION
% Hospital EEG standard channels (19-channel montage + reference):
% Required: Fp1, Fp2, F3, F4, C3, C4, P3, P4, O1, O2, F7, F8, T3, T4, T5, T6, Fz, Cz, Pz
% Remove: A1, A2 (reference channels), veog (vertical EOG if present)
% This script is designed to work with both test data and hospital EEG data

input_folder = fullfile(pwd, 'eeg_files');
output_folder = fullfile(pwd, 'output');
log_folder = fullfile(pwd, 'logs');

% Create folders if they don't exist
if ~exist(output_folder, 'dir'), mkdir(output_folder); end
if ~exist(log_folder, 'dir'), mkdir(log_folder); end

% Get .cnt, .edf, and .gdf files from input folder
cnt_files = dir(fullfile(input_folder, '*.cnt'));
edf_files = dir(fullfile(input_folder, '*.edf'));
gdf_files = dir(fullfile(input_folder, '*.gdf'));
eeg_files = [cnt_files; edf_files; gdf_files];

% Start EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Process each EEG file
for i = 1:length(eeg_files)

    filename = eeg_files(i).name;
    filepath = fullfile(eeg_files(i).folder, filename);
    [~, name_no_ext, ext] = fileparts(filename);

    % Create log file
    log_file = fullfile(log_folder, [name_no_ext '_log.txt']);
    logID = fopen(log_file, 'w');
    fprintf(logID, 'Processing: %s\n\n', filename);    
    
    % Step 1: Import file with time range 0–180 sec
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
                continue;
        end
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
        
        % Log import results
        fprintf(logID, 'Step 1 - Import: %d channels, %d events, %.3f sec, %d frames, %.1f Hz\n', ...
            EEG.nbchan, length(EEG.event), EEG.xmax, EEG.pnts, EEG.srate);
    catch ME
        fprintf(logID, 'ERROR during import: %s\n', ME.message);
        fclose(logID);
        continue;
    end    
    
    % Step 2: Remove reference and unwanted channels if present
    % Standard channels to remove: A1, A2 (reference channels)
    % Optional channels to remove: veog (vertical EOG if present)
    channels_to_remove = {'A1', 'A2', 'veog', 'VEOG'};    
    toRemove = intersect({EEG.chanlocs.labels}, channels_to_remove);
    if ~isempty(toRemove)
        EEG = pop_select(EEG, 'nochannel', toRemove);
        fprintf(logID, 'Step 2 - Removed channels: %s (%d channels remaining)\n', strjoin(toRemove, ', '), EEG.nbchan);
    else
        fprintf(logID, 'Step 2 - No channels removed (A1/A2/VEOG not found)\n');
    end    
    
    % Step 3: Downsample to 125 Hz
    if EEG.srate ~= 125
        EEG = pop_resample(EEG, 125);
        fprintf(logID, 'Step 3 - Downsampled to 125 Hz\n');
    else
        fprintf(logID, 'Step 3 - Already at 125 Hz, no resampling needed\n');    
    end
    
    % Step 4: Bandpass filter: 0.5–40 Hz
    EEG = pop_eegfiltnew(EEG, 0.5, 40, [], 0, [], 1);
    fprintf(logID, 'Step 4 - Applied bandpass filter: 0.5–40 Hz\n');    
    
    % Step 5: Clean raw data with parameters matching manual process
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
    fprintf(logID, 'Step 5 - Applied clean_rawdata (%d events after cleaning)\n', length(EEG.event));    
    
    % Step 6: Re-reference to average
    if ~strcmpi(EEG.ref, 'averef')
        EEG = pop_reref(EEG, []);
        fprintf(logID, 'Step 6 - Re-referenced to average\n');
    else
        fprintf(logID, 'Step 6 - Already average referenced, no change needed\n');
    end
    
    % Step 7: Save as EDF
    try
        EEG = eeg_checkset(EEG);
        out_file = fullfile(output_folder, [name_no_ext '_preprocessed.edf']);
        pop_writeeeg(EEG, out_file, 'TYPE', 'EDF');
        fprintf(logID, 'Step 7 - Saved preprocessed EDF: %s\n', [name_no_ext '_preprocessed.edf']);
        
        % Final summary
        fprintf(logID, '\n=== PROCESSING COMPLETE ===\n');
        fprintf(logID, 'Final: %d channels, %d events, %.3f sec, %d frames, %.1f Hz\n', ...
            EEG.nbchan, length(EEG.event), EEG.xmax, EEG.pnts, EEG.srate);
        fprintf(logID, '============================\n');
    catch ME
        fprintf(logID, 'ERROR saving EDF: %s\n', ME.message);
    end

    fclose(logID);
end

fprintf('\n Done. EDF files saved in: %s\nLogs saved in: %s\n', output_folder, log_folder);