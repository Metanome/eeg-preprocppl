import plotly.graph_objs as go
import mne
import numpy as np

# Plot the raw EEG signal (first 5 channels, first 10 seconds)
def plot_raw_signal(raw, out_html_path, duration=10, n_channels=5):
    # Extract data and times for the first n_channels and duration seconds
    data, times = raw[:n_channels, :int(duration * raw.info['sfreq'])]
    fig = go.Figure()
    for i in range(n_channels):
        # Offset each channel for visibility
        fig.add_trace(go.Scatter(x=times, y=data[i] + i * 100, mode='lines', name=raw.ch_names[i]))
    fig.update_layout(title='Raw EEG Signal (first 5 channels, 10s)',
                     xaxis_title='Time (s)', yaxis_title='Amplitude + offset',
                     height=400, width=900)
    fig.write_html(out_html_path)

# Plot the cleaned EEG signal (first 5 channels, first 10 seconds)
def plot_cleaned_signal(cleaned, out_html_path, duration=10, n_channels=5):
    # Extract data and times for the first n_channels and duration seconds
    data, times = cleaned[:n_channels, :int(duration * cleaned.info['sfreq'])]
    fig = go.Figure()
    for i in range(n_channels):
        # Offset each channel for visibility
        fig.add_trace(go.Scatter(x=times, y=data[i] + i * 100, mode='lines', name=cleaned.ch_names[i]))
    fig.update_layout(title='Cleaned EEG Signal (first 5 channels, 10s)',
                     xaxis_title='Time (s)', yaxis_title='Amplitude + offset',
                     height=400, width=900)
    fig.write_html(out_html_path)

# Plot ICA components (first 10 components)
def plot_ica_components(ica, raw, out_html_path, n_components=10):
    # Get ICA sources (time series of components)
    sources = ica.get_sources(raw).get_data()
    fig = go.Figure()
    offset = 200  # vertical offset for visibility
    for i in range(min(n_components, sources.shape[0])):
        # Offset each component for visibility
        fig.add_trace(go.Scatter(y=sources[i] + i * offset, mode='lines', name=f'ICA {i+1}'))
    fig.update_layout(title='ICA Components (first 10)',
                     xaxis_title='Samples', yaxis_title='Amplitude + offset',
                     height=400, width=900)
    fig.write_html(out_html_path)
