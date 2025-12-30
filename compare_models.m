% ========================================================================
% COMPARE MODELS - EEG Preprocessing Comparison Tool
% ========================================================================
% Compares Model 2 (basic) vs Model 3 (ICA), and Script vs Manual processing.
% See README.md for folder structure and detailed documentation.
% ========================================================================

%% ========================================================================
%  USER CONFIGURATION - Modify these settings as needed
%% ========================================================================

%% RUN MODE
% 'interactive' - Menu-driven selection (recommended)
% 'batch_all'   - Run all possible comparisons automatically
RUN_MODE = 'interactive';

%% DISPLAY
SHOW_EEGLAB_GUI = false;   % Set to true to show EEGLAB GUI during comparison

%% ========================================================================
%  INITIALIZATION - Do not modify below unless you know what you're doing
%% ========================================================================

% Initialize EEGLAB (with or without GUI based on configuration)
if ~exist('ALLCOM','var')
    if SHOW_EEGLAB_GUI
        eeglab;
    else
        eeglab('nogui');
    end
end

% Setup paths
script_dir = fileparts(mfilename('fullpath'));
compare_models_dir = fullfile(script_dir, 'compare_models');

% Verify directory exists
if ~exist(compare_models_dir, 'dir')
    error('Compare models directory not found: %s\nPlease ensure the folder structure is set up correctly.', compare_models_dir);
end

% Create results and logs directories if needed
results_dir = fullfile(compare_models_dir, 'results');
logs_dir = fullfile(compare_models_dir, 'logs');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(logs_dir, 'dir'), mkdir(logs_dir); end

% === AUTOMATED COMPARISON HANDLING ===
comparisons_to_run = {};

switch RUN_MODE
    case 'interactive'
        % Interactive menu system
        fprintf('\n=== INTERACTIVE COMPARISON MENU ===\n');
        fprintf('Select which comparisons to run:\n');
        fprintf('1. Script vs Manual (Model 2)\n');
        fprintf('2. Script vs Manual (Model 3)\n');
        fprintf('3. Model 2 vs Model 3 (Script-processed)\n');
        fprintf('4. Model 2 vs Model 3 (Manually-processed)\n');
        fprintf('5. All comparisons (1-4)\n');
        fprintf('6. Custom selection\n');
        fprintf('7. Exit\n');

        choice = input('Enter your choice (1-7): ');

        switch choice
            case 1
                comparisons_to_run = {{'script_vs_manual', 'model2'}};
            case 2
                comparisons_to_run = {{'script_vs_manual', 'model3'}};
            case 3
                comparisons_to_run = {{'model2_vs_model3', 'script'}};
            case 4
                comparisons_to_run = {{'model2_vs_model3', 'manual'}};
            case 5
                comparisons_to_run = {
                    {'script_vs_manual', 'model2'}
                    {'script_vs_manual', 'model3'}
                    {'model2_vs_model3', 'script'}
                    {'model2_vs_model3', 'manual'}
                    };
            case 6
                % Custom multi-selection
                fprintf('\nCustom selection (enter multiple numbers separated by spaces, e.g., "1 3 4"): ');
                custom_input = input('', 's');
                custom_choices = str2num(custom_input);

                comparisons_to_run = {};
                for i = 1:length(custom_choices)
                    switch custom_choices(i)
                        case 1, comparisons_to_run{end+1} = {'script_vs_manual', 'model2'};
                        case 2, comparisons_to_run{end+1} = {'script_vs_manual', 'model3'};
                        case 3, comparisons_to_run{end+1} = {'model2_vs_model3', 'script'};
                        case 4, comparisons_to_run{end+1} = {'model2_vs_model3', 'manual'};
                    end
                end
            case 7
                % Exit
                fprintf('Exiting comparison script.\n');
                return;
            otherwise
                error('Invalid choice. Please run the script again and select 1-7.');
        end

    case 'batch_all'
        % Run all possible comparisons
        fprintf('\n=== BATCH MODE: RUNNING ALL COMPARISONS ===\n');
        comparisons_to_run = {
            {'script_vs_manual', 'model2'}
            {'script_vs_manual', 'model3'}
            {'model2_vs_model3', 'script'}
            {'model2_vs_model3', 'manual'}
            };

    otherwise
        error('Invalid RUN_MODE. Use: interactive or batch_all');
end

% Check if any folders exist before proceeding
valid_comparisons = {};
for i = 1:length(comparisons_to_run)
    comp = comparisons_to_run{i};
    comp_type = comp{1};

    if strcmp(comp_type, 'script_vs_manual')
        model = comp{2};
        folder1 = fullfile(compare_models_dir, 'script', model);
        folder2 = fullfile(compare_models_dir, 'manual', model);
        desc = sprintf('Script vs Manual (%s)', upper(model));
    else % model2_vs_model3
        method = comp{2};
        folder1 = fullfile(compare_models_dir, method, 'model2');
        folder2 = fullfile(compare_models_dir, method, 'model3');
        desc = sprintf('Model 2 vs Model 3 (%s)', upper(method));
    end

    % Check if both folders exist and contain files
    if exist(folder1, 'dir') && exist(folder2, 'dir')
        files1 = dir(fullfile(folder1, '*.edf'));
        files2 = dir(fullfile(folder2, '*.edf'));

        if ~isempty(files1) && ~isempty(files2)
            valid_comparisons{end+1} = comp;
            fprintf('✓ %s: Ready (%d vs %d files)\n', desc, length(files1), length(files2));
        else
            fprintf('⚠ %s: Folders exist but no EDF files found\n', desc);
        end
    else
        fprintf('✗ %s: Missing folders\n', desc);
    end
end

if isempty(valid_comparisons)
    error('No valid comparisons found. Please ensure your folder structure is set up correctly and contains EDF files.');
end

fprintf('\nProceeding with %d valid comparison(s)...\n\n', length(valid_comparisons));

% === RUN COMPARISONS ===
all_results = {};
all_logs = {};

for comp_idx = 1:length(valid_comparisons)
    comp = valid_comparisons{comp_idx};
    comparison_type = comp{1};

    fprintf('========================================\n');
    fprintf('RUNNING COMPARISON %d/%d\n', comp_idx, length(valid_comparisons));
    fprintf('========================================\n');


    % Define folder paths and labels based on comparison type
    switch comparison_type
        case 'model2_vs_model3'
            % Comparing Model 2 vs Model 3 (within same processing method)
            processing_method = comp{2};
            model2_output_folder = fullfile(compare_models_dir, processing_method, 'model2');
            model3_output_folder = fullfile(compare_models_dir, processing_method, 'model3');
            comparison_label_1 = 'Model 2 (Basic)';
            comparison_label_2 = 'Model 3 (ICA)';
            comparison_suffix = sprintf('%s_model2_vs_model3', processing_method);

        case 'script_vs_manual'
            % Comparing script vs manual processing (same model)
            model_to_compare = comp{2};
            model2_output_folder = fullfile(compare_models_dir, 'script', model_to_compare);
            model3_output_folder = fullfile(compare_models_dir, 'manual', model_to_compare);
            comparison_label_1 = 'Script Processed';
            comparison_label_2 = 'Manual Processed';
            comparison_suffix = sprintf('script_vs_manual_%s', model_to_compare);

        otherwise
            error('Invalid comparison_type: %s', comparison_type);
    end

    % Folders are already validated in the automated section above
    % Create timestamp for this comparison run
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    comparison_id = sprintf('%s_%s', comparison_suffix, timestamp);

    % Setup output paths - save directly in results directory
    log_file = fullfile(logs_dir, sprintf('comparison_%s.log', comparison_id));
    % All results will be saved directly in results_dir with unique filenames

    % Display detected configuration
    fprintf('\n=== COMPARISON CONFIGURATION ===\n');
    fprintf('Comparison Type: %s\n', comparison_type);
    fprintf('%s folder: %s\n', comparison_label_1, model2_output_folder);
    fprintf('%s folder: %s\n', comparison_label_2, model3_output_folder);
    fprintf('Results will be saved to: %s\n', results_dir);
    fprintf('=====================================\n\n');

    % Start EEGLAB quietly for file loading
    if SHOW_EEGLAB_GUI
        [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
    else
        [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');
    end

    % Get processed files from both models
    model2_files = dir(fullfile(model2_output_folder, '*_preprocessed.edf'));
    model3_files = dir(fullfile(model3_output_folder, '*_preprocessed.edf'));

    % Enhanced file detection with alternative patterns
    if isempty(model2_files)
        % Try alternative naming patterns
        alt_patterns = {'*.edf', '*_processed.edf', '*_clean.edf', '*_ICA.edf', '*_manual.edf'};
        for pattern = alt_patterns
            model2_files = dir(fullfile(model2_output_folder, pattern{1}));
            if ~isempty(model2_files)
                fprintf('Found %s files with pattern: %s\n', comparison_label_1, pattern{1});
                break;
            end
        end
    end

    if isempty(model3_files)
        % Try alternative naming patterns
        alt_patterns = {'*.edf', '*_processed.edf', '*_clean.edf', '*_ICA.edf', '*_manual.edf'};
        for pattern = alt_patterns
            model3_files = dir(fullfile(model3_output_folder, pattern{1}));
            if ~isempty(model3_files)
                fprintf('Found %s files with pattern: %s\n', comparison_label_2, pattern{1});
                break;
            end
        end
    end

    % Check if files exist
    if isempty(model2_files)
        fprintf('\nERROR: No %s files found in %s\n', comparison_label_1, model2_output_folder);
        fprintf('Please process files first or adjust the folder path.\n');
        fprintf('Looking for patterns: *_preprocessed.edf, *.edf, *_processed.edf, *_clean.edf, *_ICA.edf, *_manual.edf\n\n');

        % Offer manual file selection
        manual_select = input('Would you like to manually select files? (y/n): ', 's');
        if strcmpi(manual_select, 'y')
            [filename, pathname] = uigetfile('*.edf', sprintf('Select %s EDF file(s)', comparison_label_1), 'MultiSelect', 'on');
            if ~isequal(filename, 0)
                if iscell(filename)
                    for i = 1:length(filename)
                        model2_files(i).name = filename{i};
                        model2_files(i).folder = pathname;
                    end
                else
                    model2_files(1).name = filename;
                    model2_files(1).folder = pathname;
                end
                model2_output_folder = pathname;
            else
                return;
            end
        else
            return;
        end
    end

    if isempty(model3_files)
        fprintf('\nERROR: No %s files found in %s\n', comparison_label_2, model3_output_folder);
        fprintf('Please process files first or adjust the folder path.\n');
        fprintf('Looking for patterns: *_preprocessed.edf, *.edf, *_processed.edf, *_clean.edf, *_ICA.edf, *_manual.edf\n\n');

        % Offer manual file selection
        manual_select = input('Would you like to manually select files? (y/n): ', 's');
        if strcmpi(manual_select, 'y')
            [filename, pathname] = uigetfile('*.edf', sprintf('Select %s EDF file(s)', comparison_label_2), 'MultiSelect', 'on');
            if ~isequal(filename, 0)
                if iscell(filename)
                    for i = 1:length(filename)
                        model3_files(i).name = filename{i};
                        model3_files(i).folder = pathname;
                    end
                else
                    model3_files(1).name = filename;
                    model3_files(1).folder = pathname;
                end
                model3_output_folder = pathname;
            else
                return;
            end
        else
            return;
        end
    end

    % Find matching files between groups
    fprintf('=== COMPARING %s vs %s RESULTS ===\n', upper(comparison_label_1), upper(comparison_label_2));
    fprintf('%s files: %d, %s files: %d\n', comparison_label_1, length(model2_files), comparison_label_2, length(model3_files));

    % Extract base names for matching with flexible naming
    model2_names = cell(length(model2_files), 1);
    model3_names = cell(length(model3_files), 1);

    % Enhanced name extraction to handle various naming patterns
    for i = 1:length(model2_files)
        [~, base_name, ~] = fileparts(model2_files(i).name);
        % Remove common suffixes including manual/script indicators
        base_name = regexprep(base_name, '_(preprocessed|processed|clean|ICA|manual|script)', '');
        model2_names{i} = base_name;
    end

    for i = 1:length(model3_files)
        [~, base_name, ~] = fileparts(model3_files(i).name);
        % Remove common suffixes including manual/script indicators
        base_name = regexprep(base_name, '_(preprocessed|processed|clean|ICA|manual|script)', '');
        model3_names{i} = base_name;
    end

    % Find common files
    [common_names, idx_m2, idx_m3] = intersect(model2_names, model3_names);

    if isempty(common_names)
        fprintf('\nERROR: No matching files found between %s and %s outputs.\n', comparison_label_1, comparison_label_2);
        fprintf('%s files: %s\n', comparison_label_1, strjoin(model2_names, ', '));
        fprintf('%s files: %s\n', comparison_label_2, strjoin(model3_names, ', '));
        fprintf('\nTroubleshooting:\n');
        fprintf('1. Ensure both groups processed the same input files\n');
        fprintf('2. Check file naming patterns match\n');
        fprintf('3. Verify files are in correct folders\n\n');

        % Offer to proceed with closest matches
        if length(model2_names) == 1 && length(model3_names) == 1
            proceed = input('Found 1 file in each folder. Proceed with comparison anyway? (y/n): ', 's');
            if strcmpi(proceed, 'y')
                common_names = {model2_names{1}};
                idx_m2 = 1;
                idx_m3 = 1;
                fprintf('Proceeding with single file comparison...\n\n');
            else
                return;
            end
        else
            return;
        end
    else
        fprintf('Found %d matching file pairs for comparison.\n\n', length(common_names));
    end

    % Determine processing mode
    processing_mode = 'batch';
    if length(common_names) == 1
        processing_mode = 'single';
        fprintf('=== SINGLE FILE COMPARISON MODE ===\n');
    else
        fprintf('=== BATCH COMPARISON MODE ===\n');
    end

    % Initialize comparison results
    comparison_results = struct();
    comparison_log = fullfile(logs_dir, sprintf('%s_vs_%s_Comparison_Log.txt', ...
        regexprep(comparison_label_1, '\W', '_'), regexprep(comparison_label_2, '\W', '_')));
    logID = fopen(comparison_log, 'w');

    if logID == -1
        fprintf('[WARNING] Could not create comparison log file, continuing without logging\n');
        logID = 1; % Use stdout as fallback
        logCleanup = []; % No cleanup needed for stdout
    else
        % Guarantee log file is closed even if an error occurs
        logCleanup = onCleanup(@() fclose(logID));
    end

    fprintf(logID, '=== %s vs %s COMPARISON ANALYSIS ===\n', upper(comparison_label_1), upper(comparison_label_2));
    fprintf(logID, 'Comparison Type: %s\n', comparison_type);
    fprintf(logID, 'Generated: %s\n', datestr(now));
    fprintf(logID, 'Files compared: %d\n\n', length(common_names));

    % Process each matching pair
    for i = 1:length(common_names)
        file_base = common_names{i};

        fprintf('Processing comparison %d/%d: %s\n', i, length(common_names), file_base);
        fprintf(logID, '=== File: %s ===\n', file_base);

        % Load files from both groups
        model2_file = fullfile(model2_output_folder, model2_files(idx_m2(i)).name);
        model3_file = fullfile(model3_output_folder, model3_files(idx_m3(i)).name);

        try
            % Load both datasets
            EEG_m2 = pop_biosig(model2_file);
            EEG_m3 = pop_biosig(model3_file);

            % Basic comparison metrics
            fprintf(logID, 'Basic Metrics:\n');
            fprintf(logID, '  Channels: %s=%d, %s=%d, Difference=%d\n', ...
                comparison_label_1, EEG_m2.nbchan, comparison_label_2, EEG_m3.nbchan, EEG_m3.nbchan - EEG_m2.nbchan);
            fprintf(logID, '  Duration: %s=%.3fs, %s=%.3fs, Difference=%.3fs\n', ...
                comparison_label_1, EEG_m2.xmax, comparison_label_2, EEG_m3.xmax, EEG_m3.xmax - EEG_m2.xmax);
            fprintf(logID, '  Data points: %s=%d, %s=%d, Difference=%d\n', ...
                comparison_label_1, EEG_m2.pnts, comparison_label_2, EEG_m3.pnts, EEG_m3.pnts - EEG_m2.pnts);

            % Enhanced signal amplitude comparison
            m2_mean_amp = mean(abs(EEG_m2.data(:)));
            m3_mean_amp = mean(abs(EEG_m3.data(:)));
            m2_std_amp = std(EEG_m2.data(:));
            m3_std_amp = std(EEG_m3.data(:));

            % Additional statistical measures
            m2_max_amp = max(abs(EEG_m2.data(:)));
            m3_max_amp = max(abs(EEG_m3.data(:)));
            m2_kurtosis = mean(kurtosis(EEG_m2.data, 1, 2));
            m3_kurtosis = mean(kurtosis(EEG_m3.data, 1, 2));
            m2_skewness = mean(skewness(EEG_m2.data, 1, 2));
            m3_skewness = mean(skewness(EEG_m3.data, 1, 2));

            amp_reduction = (m2_mean_amp - m3_mean_amp) / m2_mean_amp * 100;
            var_reduction = (m2_std_amp - m3_std_amp) / m2_std_amp * 100;
            max_amp_reduction = (m2_max_amp - m3_max_amp) / m2_max_amp * 100;

            % Signal-to-noise ratio improvement estimate
            snr_improvement = 20 * log10(m2_std_amp / m3_std_amp);

            fprintf(logID, 'Enhanced Signal Quality Analysis:\n');
            fprintf(logID, '  Mean amplitude: %s=%.2f µV, %s=%.2f µV (%.1f%% reduction)\n', ...
                comparison_label_1, m2_mean_amp, comparison_label_2, m3_mean_amp, amp_reduction);
            fprintf(logID, '  Signal variability: %s=%.2f µV, %s=%.2f µV (%.1f%% reduction)\n', ...
                comparison_label_1, m2_std_amp, comparison_label_2, m3_std_amp, var_reduction);
            fprintf(logID, '  Max amplitude: %s=%.2f µV, %s=%.2f µV (%.1f%% reduction)\n', ...
                comparison_label_1, m2_max_amp, comparison_label_2, m3_max_amp, max_amp_reduction);
            fprintf(logID, '  SNR improvement: %.1f dB\n', snr_improvement);
            fprintf(logID, '  Kurtosis: %s=%.2f, %s=%.2f (change: %.2f)\n', ...
                comparison_label_1, m2_kurtosis, comparison_label_2, m3_kurtosis, m3_kurtosis - m2_kurtosis);
            fprintf(logID, '  Skewness: %s=%.2f, %s=%.2f (change: %.2f)\n', ...
                comparison_label_1, m2_skewness, comparison_label_2, m3_skewness, m3_skewness - m2_skewness);

            % Enhanced Power Spectral Density comparison
            try
                fs = EEG_m2.srate; % Should be same for both
                nfft = min(2^nextpow2(EEG_m2.pnts), 2048);

                % Calculate PSDs for both models using channel-wise averaging
                % Model 2 PSD calculation
                m2_channel_psds = [];
                for ch = 1:EEG_m2.nbchan
                    [psd_ch, freqs] = pwelch(EEG_m2.data(ch, :), hann(nfft/4), nfft/8, nfft, fs);
                    m2_channel_psds(ch, :) = psd_ch;
                end
                psd_m2 = mean(m2_channel_psds, 1);

                % Model 3 PSD calculation
                m3_channel_psds = [];
                for ch = 1:EEG_m3.nbchan
                    [psd_ch, ~] = pwelch(EEG_m3.data(ch, :), hann(nfft/4), nfft/8, nfft, fs);
                    m3_channel_psds(ch, :) = psd_ch;
                end
                psd_m3 = mean(m3_channel_psds, 1);

                % Define frequency bands
                delta_band = freqs >= 0.5 & freqs <= 4;
                theta_band = freqs >= 4 & freqs <= 8;
                alpha_band = freqs >= 8 & freqs <= 13;
                beta_band = freqs >= 13 & freqs <= 30;
                gamma_band = freqs >= 30 & freqs <= 40;

                % Calculate band powers (in dB)
                m2_delta = 10*log10(mean(psd_m2(delta_band)));
                m2_theta = 10*log10(mean(psd_m2(theta_band)));
                m2_alpha = 10*log10(mean(psd_m2(alpha_band)));
                m2_beta = 10*log10(mean(psd_m2(beta_band)));
                m2_gamma = 10*log10(mean(psd_m2(gamma_band)));
                m2_total = 10*log10(mean(psd_m2(freqs >= 0.5 & freqs <= 40)));

                m3_delta = 10*log10(mean(psd_m3(delta_band)));
                m3_theta = 10*log10(mean(psd_m3(theta_band)));
                m3_alpha = 10*log10(mean(psd_m3(alpha_band)));
                m3_beta = 10*log10(mean(psd_m3(beta_band)));
                m3_gamma = 10*log10(mean(psd_m3(gamma_band)));
                m3_total = 10*log10(mean(psd_m3(freqs >= 0.5 & freqs <= 40)));

                % Calculate statistical significance of power differences
                % Using Wilcoxon signed-rank test for paired comparisons
                if exist('signrank', 'file') && size(m2_channel_psds, 1) > 5
                    % Test each band for significant differences
                    [p_delta, ~] = signrank(10*log10(mean(m2_channel_psds(:, delta_band), 2)), ...
                        10*log10(mean(m3_channel_psds(:, delta_band), 2)));
                    [p_theta, ~] = signrank(10*log10(mean(m2_channel_psds(:, theta_band), 2)), ...
                        10*log10(mean(m3_channel_psds(:, theta_band), 2)));
                    [p_alpha, ~] = signrank(10*log10(mean(m2_channel_psds(:, alpha_band), 2)), ...
                        10*log10(mean(m3_channel_psds(:, alpha_band), 2)));
                    [p_beta, ~] = signrank(10*log10(mean(m2_channel_psds(:, beta_band), 2)), ...
                        10*log10(mean(m3_channel_psds(:, beta_band), 2)));
                    [p_gamma, ~] = signrank(10*log10(mean(m2_channel_psds(:, gamma_band), 2)), ...
                        10*log10(mean(m3_channel_psds(:, gamma_band), 2)));

                    sig_tests_available = true;
                else
                    p_delta = NaN; p_theta = NaN; p_alpha = NaN; p_beta = NaN; p_gamma = NaN;
                    sig_tests_available = false;
                end

                fprintf(logID, 'Enhanced Power Spectral Density Analysis (dB):\n');
                fprintf(logID, '  Delta (0.5-4 Hz): %s=%.1f, %s=%.1f, Change=%+.1f', ...
                    comparison_label_1, m2_delta, comparison_label_2, m3_delta, m3_delta - m2_delta);
                if sig_tests_available
                    if p_delta < 0.05
                        fprintf(logID, ' (p=%.3f*)', p_delta);
                    else
                        fprintf(logID, ' (p=%.3f)', p_delta);
                    end
                end
                fprintf(logID, '\n');

                fprintf(logID, '  Theta (4-8 Hz): %s=%.1f, %s=%.1f, Change=%+.1f', ...
                    comparison_label_1, m2_theta, comparison_label_2, m3_theta, m3_theta - m2_theta);
                if sig_tests_available
                    if p_theta < 0.05
                        fprintf(logID, ' (p=%.3f*)', p_theta);
                    else
                        fprintf(logID, ' (p=%.3f)', p_theta);
                    end
                end
                fprintf(logID, '\n');

                fprintf(logID, '  Alpha (8-13 Hz): %s=%.1f, %s=%.1f, Change=%+.1f', ...
                    comparison_label_1, m2_alpha, comparison_label_2, m3_alpha, m3_alpha - m2_alpha);
                if sig_tests_available
                    if p_alpha < 0.05
                        fprintf(logID, ' (p=%.3f*)', p_alpha);
                    else
                        fprintf(logID, ' (p=%.3f)', p_alpha);
                    end
                end
                fprintf(logID, '\n');

                fprintf(logID, '  Beta (13-30 Hz): %s=%.1f, %s=%.1f, Change=%+.1f', ...
                    comparison_label_1, m2_beta, comparison_label_2, m3_beta, m3_beta - m2_beta);
                if sig_tests_available
                    if p_beta < 0.05
                        fprintf(logID, ' (p=%.3f*)', p_beta);
                    else
                        fprintf(logID, ' (p=%.3f)', p_beta);
                    end
                end
                fprintf(logID, '\n');

                fprintf(logID, '  Gamma (30-40 Hz): %s=%.1f, %s=%.1f, Change=%+.1f', ...
                    comparison_label_1, m2_gamma, comparison_label_2, m3_gamma, m3_gamma - m2_gamma);
                if sig_tests_available
                    if p_gamma < 0.05
                        fprintf(logID, ' (p=%.3f*)', p_gamma);
                    else
                        fprintf(logID, ' (p=%.3f)', p_gamma);
                    end
                end
                fprintf(logID, '\n');

                fprintf(logID, '  Total Power: %s=%.1f, %s=%.1f, Change=%+.1f\n', ...
                    comparison_label_1, m2_total, comparison_label_2, m3_total, m3_total - m2_total);

                if sig_tests_available
                    fprintf(logID, '  Statistical significance: * indicates p < 0.05\n');
                end

                % Calculate relative power changes
                rel_delta_change = ((m3_delta - m2_delta) / abs(m2_delta)) * 100;
                rel_alpha_change = ((m3_alpha - m2_alpha) / abs(m2_alpha)) * 100;
                rel_beta_change = ((m3_beta - m2_beta) / abs(m2_beta)) * 100;

                fprintf(logID, '  Relative Power Changes: Delta=%.1f%%, Alpha=%.1f%%, Beta=%.1f%%\n', ...
                    rel_delta_change, rel_alpha_change, rel_beta_change);

                % Store enhanced results for summary
                comparison_results(i).filename = file_base;
                comparison_results(i).amp_reduction = amp_reduction;
                comparison_results(i).var_reduction = var_reduction;
                comparison_results(i).max_amp_reduction = max_amp_reduction;
                comparison_results(i).snr_improvement = snr_improvement;
                comparison_results(i).power_change = m3_total - m2_total;
                comparison_results(i).delta_change = m3_delta - m2_delta;
                comparison_results(i).theta_change = m3_theta - m2_theta;
                comparison_results(i).alpha_change = m3_alpha - m2_alpha;
                comparison_results(i).beta_change = m3_beta - m2_beta;
                comparison_results(i).gamma_change = m3_gamma - m2_gamma;
                comparison_results(i).rel_delta_change = rel_delta_change;
                comparison_results(i).rel_alpha_change = rel_alpha_change;
                comparison_results(i).rel_beta_change = rel_beta_change;
                comparison_results(i).kurtosis_change = m3_kurtosis - m2_kurtosis;
                comparison_results(i).skewness_change = m3_skewness - m2_skewness;

                % Store significance test results
                if sig_tests_available
                    comparison_results(i).p_delta = p_delta;
                    comparison_results(i).p_theta = p_theta;
                    comparison_results(i).p_alpha = p_alpha;
                    comparison_results(i).p_beta = p_beta;
                    comparison_results(i).p_gamma = p_gamma;
                    comparison_results(i).sig_tests = true;
                else
                    comparison_results(i).p_delta = NaN;
                    comparison_results(i).p_theta = NaN;
                    comparison_results(i).p_alpha = NaN;
                    comparison_results(i).p_beta = NaN;
                    comparison_results(i).p_gamma = NaN;
                    comparison_results(i).sig_tests = false;
                end

            catch ME
                fprintf(logID, 'Enhanced PSD calculation failed: %s\n', ME.message);
                comparison_results(i).filename = file_base;
                comparison_results(i).amp_reduction = amp_reduction;
                comparison_results(i).var_reduction = var_reduction;
                comparison_results(i).max_amp_reduction = max_amp_reduction;
                comparison_results(i).snr_improvement = snr_improvement;
                comparison_results(i).power_change = NaN;
                comparison_results(i).kurtosis_change = m3_kurtosis - m2_kurtosis;
                comparison_results(i).skewness_change = m3_skewness - m2_skewness;
                comparison_results(i).sig_tests = false;
            end

            % Channel-wise comparison
            if EEG_m2.nbchan == EEG_m3.nbchan
                try
                    % Calculate correlation between corresponding channels
                    correlations = zeros(EEG_m2.nbchan, 1);
                    for ch = 1:EEG_m2.nbchan
                        % Use minimum length for comparison
                        min_len = min(length(EEG_m2.data(ch,:)), length(EEG_m3.data(ch,:)));
                        if min_len > 100  % Ensure sufficient data
                            corr_coef = corrcoef(EEG_m2.data(ch,1:min_len), EEG_m3.data(ch,1:min_len));
                            correlations(ch) = corr_coef(1,2);
                        else
                            correlations(ch) = NaN;
                        end
                    end

                    avg_correlation = mean(correlations, 'omitnan');
                    min_correlation = min(correlations, [], 'omitnan');

                    fprintf(logID, 'Channel Correlation:\n');
                    fprintf(logID, '  Average correlation: %.3f\n', avg_correlation);
                    fprintf(logID, '  Minimum correlation: %.3f\n', min_correlation);

                    comparison_results(i).avg_correlation = avg_correlation;
                    comparison_results(i).min_correlation = min_correlation;

                catch ME
                    fprintf(logID, 'Channel correlation calculation failed: %s\n', ME.message);
                    comparison_results(i).avg_correlation = NaN;
                    comparison_results(i).min_correlation = NaN;
                end
            else
                fprintf(logID, 'Channel correlation: Cannot compare (different channel counts)\n');
                comparison_results(i).avg_correlation = NaN;
                comparison_results(i).min_correlation = NaN;
            end

            % Create enhanced comparison plots
            try
                % Create figure for this comparison with more subplots
                fig = figure('Visible', 'off', 'Position', [100, 100, 1400, 1000]);

                % Subplot 1: Power spectral comparison
                subplot(3, 3, 1);
                if exist('psd_m2', 'var') && exist('psd_m3', 'var')
                    semilogy(freqs, psd_m2, 'b-', 'LineWidth', 1.5, 'DisplayName', comparison_label_1);
                    hold on;
                    semilogy(freqs, psd_m3, 'r-', 'LineWidth', 1.5, 'DisplayName', comparison_label_2);
                    xlim([0.5 40]);
                    xlabel('Frequency (Hz)');
                    ylabel('Power Spectral Density');
                    title('PSD Comparison');
                    legend('Location', 'best');
                    grid on;
                end

                % Subplot 2: Signal amplitude comparison (first 1000 samples)
                subplot(3, 3, 2);
                max_samples = min(1000, min(EEG_m2.pnts, EEG_m3.pnts));
                time_vec = (0:max_samples-1) / fs;
                plot(time_vec, mean(EEG_m2.data(:, 1:max_samples), 1), 'b-', 'LineWidth', 1, 'DisplayName', comparison_label_1);
                hold on;
                plot(time_vec, mean(EEG_m3.data(:, 1:max_samples), 1), 'r-', 'LineWidth', 1, 'DisplayName', comparison_label_2);
                xlabel('Time (s)');
                ylabel('Amplitude (µV)');
                title('Signal Comparison (Average)');
                legend('Location', 'best');
                grid on;

                % Subplot 3: Band power comparison
                subplot(3, 3, 3);
                if exist('m2_delta', 'var')
                    bands = {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'};
                    m2_powers = [m2_delta, m2_theta, m2_alpha, m2_beta, m2_gamma];
                    m3_powers = [m3_delta, m3_theta, m3_alpha, m3_beta, m3_gamma];

                    x = 1:length(bands);
                    width = 0.35;
                    bar(x - width/2, m2_powers, width, 'DisplayName', comparison_label_1);
                    hold on;
                    bar(x + width/2, m3_powers, width, 'DisplayName', comparison_label_2);
                    set(gca, 'XTick', x, 'XTickLabel', bands);
                    ylabel('Power (dB)');
                    title('Band Power Comparison');
                    legend('Location', 'best');
                    grid on;
                end

                % Subplot 4: Amplitude reduction metrics
                subplot(3, 3, 4);
                amp_metrics = [amp_reduction, var_reduction, max_amp_reduction];
                amp_labels = {'Mean Amp', 'Variability', 'Max Amp'};
                bar(amp_metrics);
                set(gca, 'XTickLabel', amp_labels);
                ylabel('Reduction (%)');
                title('Amplitude Reduction Metrics');
                grid on;

                % Subplot 5: Power change by frequency band
                subplot(3, 3, 5);
                if exist('m2_delta', 'var')
                    power_changes = [m3_delta - m2_delta, m3_theta - m2_theta, ...
                        m3_alpha - m2_alpha, m3_beta - m2_beta, m3_gamma - m2_gamma];
                    bars = bar(power_changes);
                    set(gca, 'XTickLabel', bands);
                    ylabel('Power Change (dB)');
                    title('Power Changes by Band');
                    grid on;

                    % Color bars based on increase/decrease
                    for j = 1:length(power_changes)
                        if power_changes(j) > 0
                            bars.FaceColor = 'flat';
                            bars.CData(j,:) = [0 0.7 0]; % Green for increase
                        else
                            bars.FaceColor = 'flat';
                            bars.CData(j,:) = [0.7 0 0]; % Red for decrease
                        end
                    end
                end

                % Subplot 6: Statistical measures comparison
                subplot(3, 3, 6);
                stat_m2 = [m2_kurtosis, abs(m2_skewness)];
                stat_m3 = [m3_kurtosis, abs(m3_skewness)];
                stat_labels = {'Kurtosis', '|Skewness|'};

                x = 1:length(stat_labels);
                width = 0.35;
                bar(x - width/2, stat_m2, width, 'DisplayName', comparison_label_1);
                hold on;
                bar(x + width/2, stat_m3, width, 'DisplayName', comparison_label_2);
                set(gca, 'XTick', x, 'XTickLabel', stat_labels);
                ylabel('Value');
                title('Statistical Measures');
                legend('Location', 'best');
                grid on;

                % Subplot 7: SNR improvement
                subplot(3, 3, 7);
                bar(snr_improvement, 'FaceColor', [0.2 0.6 0.8]);
                ylabel('SNR Improvement (dB)');
                title('Signal-to-Noise Ratio Improvement');
                set(gca, 'XTickLabel', {'SNR'});
                grid on;

                % Subplot 8: Channel correlation heatmap (if available)
                subplot(3, 3, 8);
                if exist('correlations', 'var') && length(correlations) > 1
                    imagesc(reshape(correlations, 1, length(correlations)));
                    colorbar;
                    colormap('jet');
                    title('Channel Correlations');
                    xlabel('Channel');
                    ylabel('Correlation');
                    caxis([0 1]);
                else
                    text(0.5, 0.5, 'Channel correlation\nnot available', ...
                        'HorizontalAlignment', 'center', 'Units', 'normalized');
                    title('Channel Correlations');
                end

                % Subplot 9: Summary metrics
                subplot(3, 3, 9);
                if ~isnan(comparison_results(i).avg_correlation)
                    summary_metrics = [amp_reduction, var_reduction, snr_improvement, ...
                        (comparison_results(i).avg_correlation)*100];
                    summary_labels = {'Amp Red %', 'Var Red %', 'SNR dB', 'Corr %'};
                else
                    summary_metrics = [amp_reduction, var_reduction, snr_improvement];
                    summary_labels = {'Amp Red %', 'Var Red %', 'SNR dB'};
                end
                bar(summary_metrics);
                set(gca, 'XTickLabel', summary_labels);
                ylabel('Value');
                title('Summary Metrics');
                grid on;

                % Save figure with unique filename
                sgtitle(sprintf('%s vs %s Comparison: %s', comparison_label_1, comparison_label_2, file_base), 'FontSize', 14, 'FontWeight', 'bold');
                plot_filename = sprintf('%s_%s_comparison.png', comparison_id, file_base);
                saveas(fig, fullfile(results_dir, plot_filename));
                close(fig);

            catch ME
                fprintf(logID, 'Plot generation failed: %s\n', ME.message);
            end

            fprintf(logID, '\n');

        catch ME
            fprintf(logID, 'ERROR processing %s: %s\n\n', file_base, ME.message);
            fprintf('Error processing %s: %s\n', file_base, ME.message);
        end
    end

    % Generate enhanced summary statistics
    if ~isempty(comparison_results) && isfield(comparison_results, 'amp_reduction')
        fprintf(logID, '=== ENHANCED SUMMARY STATISTICS ===\n');

        % Extract all metrics
        amp_reductions = [comparison_results.amp_reduction];
        var_reductions = [comparison_results.var_reduction];
        max_amp_reductions = [comparison_results.max_amp_reduction];
        snr_improvements = [comparison_results.snr_improvement];
        power_changes = [comparison_results.power_change];
        delta_changes = [comparison_results.delta_change];
        theta_changes = [comparison_results.theta_change];
        alpha_changes = [comparison_results.alpha_change];
        beta_changes = [comparison_results.beta_change];
        gamma_changes = [comparison_results.gamma_change];
        kurtosis_changes = [comparison_results.kurtosis_change];
        skewness_changes = [comparison_results.skewness_change];

        % Remove NaN values for statistics
        valid_amp = amp_reductions(~isnan(amp_reductions));
        valid_var = var_reductions(~isnan(var_reductions));
        valid_max_amp = max_amp_reductions(~isnan(max_amp_reductions));
        valid_snr = snr_improvements(~isnan(snr_improvements));
        valid_power = power_changes(~isnan(power_changes));
        valid_delta = delta_changes(~isnan(delta_changes));
        valid_theta = theta_changes(~isnan(theta_changes));
        valid_alpha = alpha_changes(~isnan(alpha_changes));
        valid_beta = beta_changes(~isnan(beta_changes));
        valid_gamma = gamma_changes(~isnan(gamma_changes));
        valid_kurtosis = kurtosis_changes(~isnan(kurtosis_changes));
        valid_skewness = skewness_changes(~isnan(skewness_changes));

        % Amplitude and signal quality metrics
        fprintf(logID, 'SIGNAL QUALITY IMPROVEMENTS (%s vs %s):\n', comparison_label_2, comparison_label_1);
        fprintf(logID, '  Mean Amplitude Reduction: %.1f%% ± %.1f%% (range: %.1f%% to %.1f%%)\n', ...
            mean(valid_amp), std(valid_amp), min(valid_amp), max(valid_amp));
        fprintf(logID, '  Variability Reduction: %.1f%% ± %.1f%% (range: %.1f%% to %.1f%%)\n', ...
            mean(valid_var), std(valid_var), min(valid_var), max(valid_var));
        fprintf(logID, '  Max Amplitude Reduction: %.1f%% ± %.1f%% (range: %.1f%% to %.1f%%)\n', ...
            mean(valid_max_amp), std(valid_max_amp), min(valid_max_amp), max(valid_max_amp));
        fprintf(logID, '  SNR Improvement: %.1f dB ± %.1f dB (range: %.1f to %.1f dB)\n', ...
            mean(valid_snr), std(valid_snr), min(valid_snr), max(valid_snr));

        % Power spectral changes
        if ~isempty(valid_power)
            fprintf(logID, '\nSPECTRAL POWER CHANGES:\n');
            fprintf(logID, '  Total Power Change: %+.1f dB ± %.1f dB (range: %+.1f to %+.1f dB)\n', ...
                mean(valid_power), std(valid_power), min(valid_power), max(valid_power));
            fprintf(logID, '  Delta Band Change: %+.1f dB ± %.1f dB (range: %+.1f to %+.1f dB)\n', ...
                mean(valid_delta), std(valid_delta), min(valid_delta), max(valid_delta));
            fprintf(logID, '  Theta Band Change: %+.1f dB ± %.1f dB (range: %+.1f to %+.1f dB)\n', ...
                mean(valid_theta), std(valid_theta), min(valid_theta), max(valid_theta));
            fprintf(logID, '  Alpha Band Change: %+.1f dB ± %.1f dB (range: %+.1f to %+.1f dB)\n', ...
                mean(valid_alpha), std(valid_alpha), min(valid_alpha), max(valid_alpha));
            fprintf(logID, '  Beta Band Change: %+.1f dB ± %.1f dB (range: %+.1f to %+.1f dB)\n', ...
                mean(valid_beta), std(valid_beta), min(valid_beta), max(valid_beta));
            fprintf(logID, '  Gamma Band Change: %+.1f dB ± %.1f dB (range: %+.1f to %+.1f dB)\n', ...
                mean(valid_gamma), std(valid_gamma), min(valid_gamma), max(valid_gamma));
        end

        % Statistical measures
        if ~isempty(valid_kurtosis)
            fprintf(logID, '\nSTATISTICAL MEASURE CHANGES:\n');
            fprintf(logID, '  Kurtosis Change: %+.2f ± %.2f (range: %+.2f to %+.2f)\n', ...
                mean(valid_kurtosis), std(valid_kurtosis), min(valid_kurtosis), max(valid_kurtosis));
            fprintf(logID, '  Skewness Change: %+.2f ± %.2f (range: %+.2f to %+.2f)\n', ...
                mean(valid_skewness), std(valid_skewness), min(valid_skewness), max(valid_skewness));
        end

        % Statistical significance summary
        sig_count = 0;
        total_tests = 0;
        for i = 1:length(comparison_results)
            if isfield(comparison_results(i), 'sig_tests') && comparison_results(i).sig_tests
                total_tests = total_tests + 5; % 5 frequency bands
                if comparison_results(i).p_delta < 0.05, sig_count = sig_count + 1; end
                if comparison_results(i).p_theta < 0.05, sig_count = sig_count + 1; end
                if comparison_results(i).p_alpha < 0.05, sig_count = sig_count + 1; end
                if comparison_results(i).p_beta < 0.05, sig_count = sig_count + 1; end
                if comparison_results(i).p_gamma < 0.05, sig_count = sig_count + 1; end
            end
        end

        if total_tests > 0
            fprintf(logID, '\nSTATISTICAL SIGNIFICANCE:\n');
            fprintf(logID, '  Significant changes (p < 0.05): %d/%d (%.1f%%)\n', ...
                sig_count, total_tests, (sig_count/total_tests)*100);
        end

        % Create enhanced summary plots
        try
            fig = figure('Visible', 'off', 'Position', [100, 100, 1400, 900]);

            % Plot 1: Amplitude metrics distribution
            subplot(2, 4, 1);
            histogram(valid_amp, max(5, floor(length(valid_amp)/2)));
            xlabel('Amplitude Reduction (%)');
            ylabel('Count');
            title('Amplitude Reduction Distribution');
            grid on;

            % Plot 2: Variability metrics distribution
            subplot(2, 4, 2);
            histogram(valid_var, max(5, floor(length(valid_var)/2)));
            xlabel('Variability Reduction (%)');
            ylabel('Count');
            title('Variability Reduction Distribution');
            grid on;

            % Plot 3: SNR improvement distribution
            subplot(2, 4, 3);
            if ~isempty(valid_snr)
                histogram(valid_snr, max(5, floor(length(valid_snr)/2)));
                xlabel('SNR Improvement (dB)');
                ylabel('Count');
                title('SNR Improvement Distribution');
                grid on;
            end

            % Plot 4: Total power change distribution
            subplot(2, 4, 4);
            if ~isempty(valid_power)
                histogram(valid_power, max(5, floor(length(valid_power)/2)));
                xlabel('Power Change (dB)');
                ylabel('Count');
                title('Total Power Change Distribution');
                grid on;
            end

            % Plot 5: Band-wise power changes
            subplot(2, 4, 5);
            if ~isempty(valid_delta)
                band_means = [mean(valid_delta), mean(valid_theta), mean(valid_alpha), ...
                    mean(valid_beta), mean(valid_gamma)];
                band_stds = [std(valid_delta), std(valid_theta), std(valid_alpha), ...
                    std(valid_beta), std(valid_gamma)];
                bands = {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'};

                bar(band_means);
                hold on;
                errorbar(1:5, band_means, band_stds, 'k.', 'LineWidth', 1.5);
                set(gca, 'XTickLabel', bands);
                ylabel('Mean Power Change (dB)');
                title('Band Power Changes');
                grid on;
            end

            % Plot 6: Correlation between metrics
            subplot(2, 4, 6);
            if length(valid_amp) > 3 && length(valid_snr) > 3
                scatter(valid_amp, valid_snr, 50, 'filled');
                xlabel('Amplitude Reduction (%)');
                ylabel('SNR Improvement (dB)');
                title('Amplitude vs SNR');
                grid on;

                % Add correlation coefficient
                if length(valid_amp) == length(valid_snr)
                    corr_coef = corr(valid_amp', valid_snr');
                    text(0.05, 0.95, sprintf('r = %.3f', corr_coef), ...
                        'Units', 'normalized', 'FontWeight', 'bold');
                end
            end

            % Plot 7: Statistical measures changes
            subplot(2, 4, 7);
            if ~isempty(valid_kurtosis) && ~isempty(valid_skewness)
                changes = [mean(valid_kurtosis), mean(abs(valid_skewness))];
                change_labels = {'Kurtosis', '|Skewness|'};
                bars = bar(changes);
                set(gca, 'XTickLabel', change_labels);
                ylabel('Mean Change');
                title('Statistical Measure Changes');
                grid on;

                % Color bars based on improvement (reduction in absolute values is good)
                for j = 1:length(changes)
                    if changes(j) < 0
                        bars.FaceColor = 'flat';
                        bars.CData(j,:) = [0 0.7 0]; % Green for improvement
                    else
                        bars.FaceColor = 'flat';
                        bars.CData(j,:) = [0.7 0.7 0]; % Yellow for increase
                    end
                end
            end

            % Plot 8: Processing effectiveness summary
            subplot(2, 4, 8);
            if strcmp(processing_mode, 'single')
                % Single file summary
                summary_metrics = [amp_reduction, var_reduction, snr_improvement];
                summary_labels = {'Amp Red %', 'Var Red %', 'SNR dB'};
                bar(summary_metrics);
                set(gca, 'XTickLabel', summary_labels);
                ylabel('Value');
                title('Single File Summary');
            else
                % Batch processing effectiveness
                effectiveness_scores = valid_amp + valid_var; % Combined reduction score
                histogram(effectiveness_scores, max(5, floor(length(effectiveness_scores)/2)));
                xlabel('Combined Reduction Score');
                ylabel('Count');
                title('Processing Effectiveness');
            end
            grid on;

            sgtitle(sprintf('Enhanced Comparison Summary: %s vs %s (%s)', comparison_label_1, comparison_label_2, processing_mode), ...
                'FontSize', 14, 'FontWeight', 'bold');
            summary_filename = sprintf('%s_Enhanced_Summary_Statistics.png', comparison_id);
            saveas(fig, fullfile(results_dir, summary_filename));
            close(fig);

        catch ME
            fprintf(logID, 'Enhanced summary plot generation failed: %s\n', ME.message);
        end
    end

    if logID ~= 1, fclose(logID); end

    % Enhanced final summary
    fprintf('\n========================================\n');
    fprintf('ENHANCED MODEL COMPARISON COMPLETE\n');
    fprintf('========================================\n');
    fprintf('Processing mode: %s\n', upper(processing_mode));
    fprintf('Compared %d file pairs\n', length(common_names));
    fprintf('Results saved to: %s\n', results_dir);
    fprintf('Comparison plots: Individual files + Enhanced_Summary_Statistics.png\n');
    fprintf('Detailed log: %s\n', comparison_log);

    % Display enhanced key findings
    if ~isempty(comparison_results) && isfield(comparison_results, 'amp_reduction')
        fprintf('\n=== KEY FINDINGS ===\n');

        % Signal quality improvements
        fprintf('SIGNAL QUALITY IMPROVEMENTS:\n');
        fprintf('• Average amplitude reduction: %.1f%% ± %.1f%%\n', ...
            mean(valid_amp), std(valid_amp));
        fprintf('• Average variability reduction: %.1f%% ± %.1f%%\n', ...
            mean(valid_var), std(valid_var));

        if ~isempty(valid_snr)
            fprintf('• Average SNR improvement: %.1f ± %.1f dB\n', ...
                mean(valid_snr), std(valid_snr));
        end

        % Power spectral changes
        if ~isempty(valid_power)
            fprintf('\nSPECTRAL CHANGES:\n');
            if mean(valid_power) > 0
                fprintf('• Average total power increase: +%.1f dB\n', mean(valid_power));
            else
                fprintf('• Average total power decrease: %.1f dB\n', mean(valid_power));
            end

            % Most affected frequency bands
            band_changes = [mean(valid_delta), mean(valid_theta), mean(valid_alpha), ...
                mean(valid_beta), mean(valid_gamma)];
            band_names = {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'};

            [max_change, max_idx] = max(abs(band_changes));
            [min_change, min_idx] = min(abs(band_changes));

            fprintf('• Most affected band: %s (%+.1f dB)\n', ...
                band_names{max_idx}, band_changes(max_idx));
            fprintf('• Least affected band: %s (%+.1f dB)\n', ...
                band_names{min_idx}, band_changes(min_idx));
        end

        % Processing effectiveness assessment
        fprintf('\nPROCESSING EFFECTIVENESS:\n');

        % Effectiveness criteria
        good_amp_reduction = sum(valid_amp > 10) / length(valid_amp) * 100;
        good_var_reduction = sum(valid_var > 20) / length(valid_var) * 100;

        fprintf('• Files with substantial amplitude reduction (>10%%): %.0f%%\n', good_amp_reduction);
        fprintf('• Files with substantial variability reduction (>20%%): %.0f%%\n', good_var_reduction);

        if ~isempty(valid_snr)
            good_snr_improvement = sum(valid_snr > 3) / length(valid_snr) * 100;
            fprintf('• Files with good SNR improvement (>3dB): %.0f%%\n', good_snr_improvement);
        end

        % Statistical significance
        if total_tests > 0
            fprintf('• Statistically significant changes: %.0f%% of tests\n', ...
                (sig_count/total_tests)*100);
        end

        % Overall assessment
        fprintf('\nOVERALL ASSESSMENT:\n');
        overall_effectiveness = (good_amp_reduction + good_var_reduction) / 2;

        % Create dynamic processing assessment based on comparison type
        if strcmp(comparison_type, 'model2_vs_model3')
            processing_desc = 'ICA processing';
        elseif strcmp(comparison_type, 'script_vs_manual')
            processing_desc = sprintf('%s processing', comparison_label_2);
        else
            processing_desc = sprintf('%s vs %s comparison', comparison_label_2, comparison_label_1);
        end

        if overall_effectiveness > 75
            fprintf('• %s is HIGHLY EFFECTIVE for your data\n', processing_desc);
        elseif overall_effectiveness > 50
            fprintf('• %s is MODERATELY EFFECTIVE for your data\n', processing_desc);
        elseif overall_effectiveness > 25
            fprintf('• %s shows LIMITED EFFECTIVENESS for your data\n', processing_desc);
        else
            fprintf('• %s shows MINIMAL EFFECTIVENESS for your data\n', processing_desc);
        end

        fprintf('\n=== USAGE RECOMMENDATIONS ===\n');
        if mean(valid_amp) > 30 || mean(valid_var) > 50
            fprintf('⚠️  WARNING: Very high reduction values detected.\n');
            if strcmp(comparison_type, 'model2_vs_model3')
                fprintf('   This may indicate over-processing. Consider:\n');
                fprintf('   - Reviewing ICA component selection criteria\n');
                fprintf('   - Checking if too many components are being removed\n');
                fprintf('   - Validating that remaining signal is still physiologically relevant\n');
            else
                fprintf('   This may indicate significant differences in processing methods.\n');
                fprintf('   - Review processing parameters and methods\n');
                fprintf('   - Verify that processing steps are equivalent\n');
                fprintf('   - Check for systematic differences in processing pipelines\n');
            end
        elseif mean(valid_amp) < 5 && mean(valid_var) < 10
            fprintf('ℹ️  INFO: Low reduction values detected.\n');
            if strcmp(comparison_type, 'model2_vs_model3')
                fprintf('   This may indicate:\n');
                fprintf('   - Clean input data with minimal artifacts\n');
                fprintf('   - Conservative ICA component removal\n');
                fprintf('   - Potential for more aggressive artifact removal if needed\n');
            else
                fprintf('   This may indicate:\n');
                fprintf('   - Very similar processing methods\n');
                fprintf('   - Consistent processing between groups\n');
                fprintf('   - Minimal systematic differences detected\n');
            end
        else
            fprintf('✅ GOOD: Reduction values are in a reasonable range.\n');
            if strcmp(comparison_type, 'model2_vs_model3')
                fprintf('   ICA processing appears to be working effectively.\n');
            else
                fprintf('   Processing comparison shows reasonable differences.\n');
            end
        end
    end

    fprintf('\n=== FILES GENERATED ===\n');
    fprintf('📊 Individual comparison plots for each file pair\n');
    fprintf('📈 Enhanced_Summary_Statistics.png (comprehensive overview)\n');
    fprintf('📝 Model_Comparison_Log.txt (detailed numerical results)\n');
    fprintf('\nAll results saved in: %s\n', results_dir);

    % Store this comparison's results for overall summary
    all_results{comp_idx} = struct();
    all_results{comp_idx}.type = comparison_type;
    all_results{comp_idx}.label1 = comparison_label_1;
    all_results{comp_idx}.label2 = comparison_label_2;
    all_results{comp_idx}.results_dir = results_dir;
    all_results{comp_idx}.comparison_id = comparison_id;
    all_results{comp_idx}.log_file = comparison_log;
    all_results{comp_idx}.file_count = length(common_names);
    if exist('comparison_results', 'var') && ~isempty(comparison_results)
        all_results{comp_idx}.summary_stats = comparison_results;
    end

    fprintf('\n--- COMPARISON %d/%d COMPLETE ---\n', comp_idx, length(valid_comparisons));
end

% === OVERALL SUMMARY ===
fprintf('\n\n==========================================\n');
fprintf('ALL COMPARISONS COMPLETE\n');
fprintf('==========================================\n');
fprintf('Total comparisons run: %d\n', length(valid_comparisons));
fprintf('Results saved in: %s\n', results_dir);

fprintf('\n=== COMPARISON SUMMARY ===\n');
for i = 1:length(all_results)
    result = all_results{i};
    fprintf('%d. %s vs %s\n', i, result.label1, result.label2);
    fprintf('   Files compared: %d\n', result.file_count);
    fprintf('   Results: %s (ID: %s)\n', result.results_dir, result.comparison_id);
    fprintf('   Log: %s\n', result.log_file);
    fprintf('\n');
end

fprintf('=== QUICK ACCESS ===\n');
fprintf('All result files are saved with unique timestamped filenames in:\n');
fprintf('📁 %s\n', results_dir);
fprintf('📁 %s\n', logs_dir);
fprintf('\nEach comparison generates uniquely named plots and detailed logs.\n');