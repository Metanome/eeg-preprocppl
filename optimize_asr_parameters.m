% ========================================================================
% OPTIMIZE ASR PARAMETERS - Find Best Settings for Data Retention
% ========================================================================
% Tests multiple ASR parameter combinations on sample files to find the
% optimal settings that maximize data retention while maintaining quality.
%
% Usage: Run this script, then check the results table and recommendation.
% ========================================================================

%% ========================================================================
%  USER CONFIGURATION
%% ========================================================================

%% PARAMETER RANGES TO TEST
% Define the values to test for each parameter
BURST_VALUES = [20, 30, 40, 50];           % ASR burst criterion values
WINDOW_VALUES = {0.25, 0.5, 0.75, 'off'};  % ASR window criterion values

%% TARGET METRICS
TARGET_RETENTION = 0.90;                   % Target 90% retention (162 sec)
MIN_ACCEPTABLE_SNR = 3.0;                  % Minimum acceptable SNR improvement (dB)

%% PROCESSING PARAMETERS (same as model3_eeg_prep.m)
IMPORT_TIME_RANGE_SEC = 180;
TARGET_SAMPLE_RATE_HZ = 125;
FILTER_LOW_HZ = 0.5;
FILTER_HIGH_HZ = 40;

%% FOLDER CONFIGURATION
INPUT_FOLDER = fullfile(pwd, 'eeg_files');
LOG_FOLDER = fullfile(pwd, 'logs');

%% FILE SUBSET OPTION
% Set to a number to test only that many files (randomly selected)
% Set to 'all' to test all files in the folder
MAX_FILES_TO_TEST = 5;                 % e.g., 5 or 'all'

%% ========================================================================
%  INITIALIZATION
%% ========================================================================

% Initialize EEGLAB without GUI
if ~exist('ALLCOM','var')
    eeglab('nogui');
end

% Get EEG files
cnt_files = dir(fullfile(INPUT_FOLDER, '*.cnt'));
edf_files = dir(fullfile(INPUT_FOLDER, '*.edf'));
gdf_files = dir(fullfile(INPUT_FOLDER, '*.gdf'));
eeg_files = [cnt_files; edf_files; gdf_files];

if isempty(eeg_files)
    error('No EEG files found in %s', INPUT_FOLDER);
end

% Apply file subset if specified
total_files_available = length(eeg_files);
if isnumeric(MAX_FILES_TO_TEST) && MAX_FILES_TO_TEST < total_files_available
    % Randomly select files
    rng('shuffle');  % Seed random number generator
    selected_idx = randperm(total_files_available, MAX_FILES_TO_TEST);
    eeg_files = eeg_files(selected_idx);
    fprintf('\nRandomly selected %d of %d files for testing.\n', MAX_FILES_TO_TEST, total_files_available);
end

fprintf('\n========================================\n');
fprintf('ASR PARAMETER OPTIMIZATION\n');
fprintf('========================================\n');
fprintf('Files to test: %d\n', length(eeg_files));
fprintf('Burst values: %s\n', mat2str(BURST_VALUES));
fprintf('Window values: %d options\n', length(WINDOW_VALUES));
fprintf('Total combinations: %d\n', length(BURST_VALUES) * length(WINDOW_VALUES));
fprintf('Target retention: %.0f%%\n', TARGET_RETENTION * 100);
fprintf('========================================\n\n');

%% ========================================================================
%  RUN PARAMETER SWEEP
%% ========================================================================

% Initialize results storage
num_burst = length(BURST_VALUES);
num_window = length(WINDOW_VALUES);
num_files = length(eeg_files);
num_combos = num_burst * num_window;

% Results structure
results = struct();
results.burst = [];
results.window = {};
results.avg_retention = [];
results.avg_snr = [];
results.files_passing = [];
results.min_retention = [];
% Quality validation metrics
results.avg_kurtosis = [];      % Should be ~3-5 for clean EEG
results.avg_alpha_power = [];   % Should be positive (alpha should be present)
results.quality_score = [];     % Combined quality metric
% Per-file results storage (for breakdown report)
results.per_file_retention = cell(num_combos, 1);  % Retention per file for each combo
file_names = cell(num_files, 1);
for fn = 1:num_files
    file_names{fn} = eeg_files(fn).name;
end

combo_idx = 0;
total_tests = num_combos * num_files;
test_count = 0;

fprintf('Starting parameter sweep...\n');
sweep_start = tic;

for b = 1:num_burst
    burst_val = BURST_VALUES(b);

    for w = 1:num_window
        window_val = WINDOW_VALUES{w};
        combo_idx = combo_idx + 1;

        % Display current combination
        if isnumeric(window_val)
            window_str = sprintf('%.2f', window_val);
        else
            window_str = window_val;
        end

        fprintf('\n[Combo %d/%d] BURST=%d, WINDOW=%s\n', ...
            combo_idx, num_combos, burst_val, window_str);

        % Store parameters
        results.burst(combo_idx) = burst_val;
        results.window{combo_idx} = window_val;

        % Test on all files
        retention_vals = [];
        snr_vals = [];
        kurtosis_vals = [];
        alpha_power_vals = [];

        for f = 1:num_files
            test_count = test_count + 1;
            filename = eeg_files(f).name;
            filepath = fullfile(eeg_files(f).folder, filename);
            [~, ~, ext] = fileparts(filename);

            fprintf('  Testing %s... ', filename);

            try
                % Import file
                EEG = pop_biosig(filepath, 'blockrange', [0 IMPORT_TIME_RANGE_SEC]);
                initial_duration = EEG.xmax;
                initial_amp = mean(abs(EEG.data(:)));

                % Remove non-EEG channels (simplified)
                eeg_channels = {};
                for ch = 1:EEG.nbchan
                    label = EEG.chanlocs(ch).labels;
                    if ~contains(lower(label), {'eog', 'ecg', 'ekg', 'emg', 'event', 'a1', 'a2'})
                        eeg_channels{end+1} = label;
                    end
                end
                if length(eeg_channels) < EEG.nbchan
                    EEG = pop_select(EEG, 'channel', eeg_channels);
                end

                % Downsample
                if EEG.srate ~= TARGET_SAMPLE_RATE_HZ
                    EEG = pop_resample(EEG, TARGET_SAMPLE_RATE_HZ);
                end

                % Bandpass filter
                EEG = pop_eegfiltnew(EEG, FILTER_LOW_HZ, FILTER_HIGH_HZ, [], 0, [], 0);

                % Apply ASR with current parameters
                EEG = pop_clean_rawdata(EEG, ...
                    'FlatlineCriterion', 'off', ...
                    'ChannelCriterion', 'off', ...
                    'LineNoiseCriterion', 'off', ...
                    'Highpass', 'off', ...
                    'BurstCriterion', burst_val, ...
                    'WindowCriterion', window_val, ...
                    'BurstRejection', 'on', ...
                    'Distance', 'Euclidian', ...
                    'WindowCriterionTolerances', [-Inf 7]);

                % Calculate metrics
                final_duration = EEG.xmax;
                final_amp = mean(abs(EEG.data(:)));

                retention = final_duration / initial_duration;
                snr_improvement = 20 * log10(initial_amp / final_amp);

                % Quality validation metrics
                % 1. Kurtosis - should be ~3-5 for clean EEG (not too spiky)
                all_kurtosis = kurtosis(EEG.data, 0, 2);
                avg_kurt = mean(all_kurtosis);

                % 2. Alpha power check - compute power spectrum
                try
                    [pxx, freq] = pwelch(EEG.data', EEG.srate*2, [], [], EEG.srate);
                    alpha_idx = freq >= 8 & freq <= 13;
                    total_idx = freq >= 0.5 & freq <= 40;
                    alpha_pwr = mean(10*log10(mean(pxx(alpha_idx, :), 2)));
                    total_pwr = mean(10*log10(mean(pxx(total_idx, :), 2)));
                    alpha_rel = alpha_pwr - total_pwr;  % Relative alpha power
                catch
                    alpha_rel = 0;
                end

                retention_vals(end+1) = retention;
                snr_vals(end+1) = snr_improvement;
                kurtosis_vals(end+1) = avg_kurt;
                alpha_power_vals(end+1) = alpha_rel;

                fprintf('%.1f%% retention, %.1f dB SNR\n', retention*100, snr_improvement);

            catch ME
                fprintf('ERROR: %s\n', ME.message);
                retention_vals(end+1) = NaN;
                snr_vals(end+1) = NaN;
                kurtosis_vals(end+1) = NaN;
                alpha_power_vals(end+1) = NaN;
            end
        end

        % Calculate summary statistics for this combination
        valid_idx = ~isnan(retention_vals);
        results.avg_retention(combo_idx) = mean(retention_vals(valid_idx));
        results.avg_snr(combo_idx) = mean(snr_vals(valid_idx));
        results.files_passing(combo_idx) = sum(retention_vals >= TARGET_RETENTION);
        results.min_retention(combo_idx) = min(retention_vals(valid_idx));

        % Store per-file retention for breakdown report
        results.per_file_retention{combo_idx} = retention_vals;

        % Quality metrics
        results.avg_kurtosis(combo_idx) = mean(kurtosis_vals(valid_idx));
        results.avg_alpha_power(combo_idx) = mean(alpha_power_vals(valid_idx));

        % Combined quality score: penalize if kurtosis too high (>6) or alpha too low
        kurt_penalty = max(0, results.avg_kurtosis(combo_idx) - 5) * 0.5;
        quality_score = results.avg_snr(combo_idx) + results.avg_alpha_power(combo_idx) - kurt_penalty;
        results.quality_score(combo_idx) = quality_score;
    end
end

sweep_time = toc(sweep_start);

%% ========================================================================
%  DISPLAY RESULTS
%% ========================================================================

fprintf('\n========================================\n');
fprintf('OPTIMIZATION RESULTS\n');
fprintf('========================================\n');
sweep_minutes = floor(sweep_time / 60);
sweep_seconds = mod(sweep_time, 60);
if sweep_minutes > 0
    fprintf('Sweep completed in %d minutes %.0f seconds (%.1fs total)\n\n', sweep_minutes, sweep_seconds, sweep_time);
else
    fprintf('Sweep completed in %.1f seconds\n\n', sweep_time);
end

% Create results table
fprintf('%-7s %-8s %-10s %-8s %-10s %-10s %-8s %-10s\n', ...
    'BURST', 'WINDOW', 'Retention', 'SNR', 'Pass≥90%', 'Kurtosis', 'Quality', 'Rating');
fprintf('%s\n', repmat('-', 1, 85));

best_combo = 0;
best_score = -Inf;

for i = 1:num_combos
    if isnumeric(results.window{i})
        window_str = sprintf('%.2f', results.window{i});
    else
        window_str = results.window{i};
    end

    % Score: balance passing files, retention, AND quality
    % Prioritize: (1) files passing (2) quality score (3) retention
    score = results.files_passing(i) * 50 + results.quality_score(i) * 10 + results.avg_retention(i) * 5;

    % Only consider if SNR is acceptable AND kurtosis is reasonable
    if results.avg_snr(i) >= MIN_ACCEPTABLE_SNR && results.avg_kurtosis(i) < 8 && score > best_score
        best_score = score;
        best_combo = i;
    end

    % Determine quality rating
    if results.quality_score(i) >= 8 && results.avg_kurtosis(i) < 4
        rating = 'GOOD';
    elseif results.quality_score(i) >= 5 && results.avg_kurtosis(i) < 6
        rating = 'OK';
    else
        rating = 'POOR';
    end

    % Mark best combo
    marker = '';
    if i == best_combo
        marker = ' ← BEST';
        rating = [rating marker];
    end

    fprintf('%-7d %-8s %-10.1f %-8.1f %-10s %-10.1f %-8.1f %-10s\n', ...
        results.burst(i), window_str, ...
        results.avg_retention(i) * 100, ...
        results.avg_snr(i), ...
        sprintf('%d/%d', results.files_passing(i), num_files), ...
        results.avg_kurtosis(i), ...
        results.quality_score(i), ...
        rating);
end

%% ========================================================================
%  RECOMMENDATION
%% ========================================================================

fprintf('\n========================================\n');
fprintf('RECOMMENDATION\n');
fprintf('========================================\n');

if best_combo > 0
    if isnumeric(results.window{best_combo})
        rec_window = sprintf('%.2f', results.window{best_combo});
    else
        rec_window = sprintf('''%s''', results.window{best_combo});
    end

    fprintf('Optimal settings for your data:\n\n');
    fprintf('  ASR_BURST_CRITERION = %d;\n', results.burst(best_combo));
    fprintf('  ASR_WINDOW_CRITERION = %s;\n\n', rec_window);
    fprintf('Expected results:\n');
    fprintf('  - Average retention: %.1f%%\n', results.avg_retention(best_combo) * 100);
    fprintf('  - Files passing ≥90%%: %d/%d (%.0f%%)\n', ...
        results.files_passing(best_combo), num_files, ...
        results.files_passing(best_combo)/num_files * 100);
    fprintf('  - Average SNR improvement: %.1f dB\n', results.avg_snr(best_combo));
    fprintf('  - Minimum retention: %.1f%%\n', results.min_retention(best_combo) * 100);
    fprintf('\nQuality validation:\n');
    fprintf('  - Average kurtosis: %.2f (ideal: 3-5)\n', results.avg_kurtosis(best_combo));
    fprintf('  - Quality score: %.1f\n', results.quality_score(best_combo));

    if results.avg_kurtosis(best_combo) < 4
        fprintf('  - Kurtosis check: PASSED (clean signal)\n');
    elseif results.avg_kurtosis(best_combo) < 6
        fprintf('  - Kurtosis check: ACCEPTABLE (minor artifacts)\n');
    else
        fprintf('  - Kurtosis check: WARNING (may contain artifacts)\n');
    end

    % Per-file breakdown
    fprintf('\n--- Per-File Breakdown ---\n');
    best_retention = results.per_file_retention{best_combo};
    failed_files = {};
    for pf = 1:num_files
        if best_retention(pf) >= TARGET_RETENTION
            status = 'PASS';
            marker = '✓';
        else
            status = 'FAIL';
            marker = '✗';
            failed_files{end+1} = file_names{pf};
        end
        fprintf('  %s %s: %.1f%% (%s)\n', marker, file_names{pf}, best_retention(pf)*100, status);
    end

    if ~isempty(failed_files)
        fprintf('\nFiles requiring attention (%d):\n', length(failed_files));
        for ff = 1:length(failed_files)
            fprintf('  - %s\n', failed_files{ff});
        end
    end
else
    fprintf('No combination met the minimum quality requirements.\n');
    fprintf('Consider:\n');
    fprintf('  - Relaxing SNR requirements (current: %.1f dB)\n', MIN_ACCEPTABLE_SNR);
    fprintf('  - Checking data quality at recording level\n');
end

fprintf('========================================\n');

%% ========================================================================
%  SAVE RESULTS
%% ========================================================================

% Save results to CSV
results_file = fullfile(LOG_FOLDER, 'asr_optimization_results.csv');
fid = fopen(results_file, 'w');
fprintf(fid, 'Burst,Window,AvgRetention,AvgSNR,FilesPassing,MinRetention,AvgKurtosis,QualityScore\n');
for i = 1:num_combos
    if isnumeric(results.window{i})
        window_str = sprintf('%.2f', results.window{i});
    else
        window_str = results.window{i};
    end
    fprintf(fid, '%d,%s,%.3f,%.2f,%d,%.3f,%.2f,%.2f\n', ...
        results.burst(i), window_str, ...
        results.avg_retention(i), results.avg_snr(i), ...
        results.files_passing(i), results.min_retention(i), ...
        results.avg_kurtosis(i), results.quality_score(i));
end
fclose(fid);
fprintf('\nResults saved to: %s\n', results_file);

fprintf('\n--- Quality Rating Legend ---\n');
fprintf('GOOD: High quality, clean signal (kurtosis < 4, quality score >= 8)\n');
fprintf('OK:   Acceptable quality (kurtosis < 6, quality score >= 5)\n');
fprintf('POOR: Lower quality, may contain artifacts\n');

