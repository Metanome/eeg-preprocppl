import mne
import os
import numpy as np

def preprocess_eeg(input_path, fif_out_path, csv_out_path, l_freq=1.0, h_freq=40.0, n_components=15, epoch=False, epoch_length=2.0):
    """
    Preprocess EEG data: bandpass filter, ICA artifact removal, (optional) epoching.
    Supports .edf and .fif files only.
    Saves cleaned data as .fif and .csv.
    Returns (raw, cleaned, ica, ica.exclude)
    """
    ext = os.path.splitext(input_path)[1].lower()
    if ext == '.edf':
        raw = mne.io.read_raw_edf(input_path, preload=True)
    elif ext == '.fif':
        raw = mne.io.read_raw_fif(input_path, preload=True)
    else:
        raise ValueError('Unsupported file format')

    # Bandpass filter (1–40 Hz)
    raw.filter(l_freq, h_freq, fir_design='firwin')

    # ICA for artifact removal
    n_chan = len(raw.ch_names)
    n_ica = min(n_components, n_chan)  # ICA components cannot exceed channel count
    ica = mne.preprocessing.ICA(n_components=n_ica, random_state=97, max_iter='auto')
    ica.fit(raw)
    # Try to auto-detect EOG artifacts if EOG channels exist
    eog_chs = mne.pick_types(raw.info, eog=True)
    if len(eog_chs) > 0:
        try:
            eog_inds, scores = ica.find_bads_eog(raw)
            ica.exclude = eog_inds
        except Exception:
            ica.exclude = []
    else:
        ica.exclude = []
    cleaned = ica.apply(raw.copy())

    # Optional epoching (not used by default)
    if epoch:
        events = mne.make_fixed_length_events(cleaned, duration=epoch_length)
        epochs = mne.Epochs(cleaned, events, tmin=0, tmax=epoch_length, baseline=None, preload=True)
        cleaned = epochs

    # Save cleaned data (.fif and .csv)
    if isinstance(cleaned, mne.io.BaseRaw):
        cleaned.set_meas_date(None)  # Fix for MNE date bug
        cleaned.save(fif_out_path, overwrite=True)
        # Save to CSV (channels x time)
        data = cleaned.get_data()
        np.savetxt(csv_out_path, data, delimiter=',')
    elif isinstance(cleaned, mne.epochs.BaseEpochs):
        cleaned.set_meas_date(None)  # Fix for MNE date bug
        cleaned.save(fif_out_path, overwrite=True)
        # Save mean across epochs to CSV
        data = cleaned.get_data().mean(axis=0)
        np.savetxt(csv_out_path, data, delimiter=',')

    # Return raw, cleaned, ICA object, and excluded components
    return raw, cleaned, ica, ica.exclude
