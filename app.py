import os
import time
from flask import Flask, render_template, request, redirect, url_for, send_from_directory, flash
from werkzeug.utils import secure_filename
from preprocessing.pipeline import preprocess_eeg
from preprocessing.visualizer import plot_raw_signal, plot_cleaned_signal, plot_ica_components

# Configuration
UPLOAD_FOLDER = 'uploads'
OUTPUT_FOLDER = 'output'
ALLOWED_EXTENSIONS = {'edf', 'fif'}

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['OUTPUT_FOLDER'] = OUTPUT_FOLDER
app.secret_key = 'supersecretkey'  # For session and flash messages

# Ensure necessary folders exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if the uploaded file has an allowed extension."""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def cleanup_old_files(folder, max_age_hours=0.05):  # 0.05 hours ≈ 3 minutes
    """Delete files older than max_age_hours in the given folder."""
    now = time.time()
    max_age = max_age_hours * 3600
    deleted_files = []
    for fname in os.listdir(folder):
        fpath = os.path.join(folder, fname)
        if os.path.isfile(fpath):
            if now - os.path.getmtime(fpath) > max_age:
                try:
                    os.remove(fpath)
                    deleted_files.append(fname)
                except Exception:
                    pass
    return deleted_files

@app.route('/', methods=['GET', 'POST'])
def index():
    """Homepage: upload EEG file form."""
    if request.method == 'POST':
        # Cleanup old files before processing new upload
        deleted_uploads = cleanup_old_files(app.config['UPLOAD_FOLDER'])
        deleted_outputs = cleanup_old_files(app.config['OUTPUT_FOLDER'])
        deleted_files = deleted_uploads + deleted_outputs
        if deleted_files:
            flash(f"Cleanup: {len(deleted_files)} old file(s) removed from uploads/output.")
        else:
            flash("Cleanup: No old files were removed. All files are within the retention period.")
        if 'file' not in request.files:
            flash('No file part')
            return redirect(request.url)
        file = request.files['file']
        if file.filename == '':
            flash('No selected file')
            return redirect(request.url)
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            return redirect(url_for('results', filename=filename))
        else:
            flash('Invalid file type. Please upload .edf or .fif files.')
            return redirect(request.url)
    # Show any flashed messages on the homepage
    return render_template('index.html')

@app.route('/results/<filename>')
def results(filename):
    """Results page: run preprocessing, generate plots, and display results."""
    # Cleanup old files before processing results
    deleted_uploads = cleanup_old_files(app.config['UPLOAD_FOLDER'])
    deleted_outputs = cleanup_old_files(app.config['OUTPUT_FOLDER'])
    deleted_files = deleted_uploads + deleted_outputs

    upload_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    output_basename = os.path.splitext(filename)[0]
    cleaned_fif = os.path.join(app.config['OUTPUT_FOLDER'], output_basename + '_cleaned.fif')
    cleaned_csv = os.path.join(app.config['OUTPUT_FOLDER'], output_basename + '_cleaned.csv')
    raw_plot_path = os.path.join('output', f'{output_basename}_raw.html')
    cleaned_plot_path = os.path.join('output', f'{output_basename}_cleaned.html')
    ica_plot_path = os.path.join('output', f'{output_basename}_ica.html')

    error_message = None
    raw_plot_exists = cleaned_plot_exists = ica_plot_exists = False
    try:
        # Preprocess EEG file (returns raw, cleaned, ICA object, and excluded components)
        raw, cleaned, ica, ica_exclude = preprocess_eeg(upload_path, cleaned_fif, cleaned_csv)
        # Generate plots for raw, cleaned, and ICA components
        plot_raw_signal(raw, raw_plot_path)
        plot_cleaned_signal(cleaned, cleaned_plot_path)
        plot_ica_components(ica, raw, ica_plot_path)
        # Check if plot files exist and are non-empty
        raw_plot_exists = os.path.exists(raw_plot_path)
        cleaned_plot_exists = os.path.exists(cleaned_plot_path)
        ica_plot_exists = os.path.exists(ica_plot_path) and os.path.getsize(ica_plot_path) > 500  # crude check for non-empty plot
    except Exception as e:
        # Catch and display any error during processing
        error_message = f"An error occurred during processing: {str(e)}"

    return render_template(
        'results.html',
        raw_plot=url_for('serve_output_file', filename=f'{output_basename}_raw.html'),
        cleaned_plot=url_for('serve_output_file', filename=f'{output_basename}_cleaned.html'),
        ica_plot=url_for('serve_output_file', filename=f'{output_basename}_ica.html'),
        fif_file=url_for('download_file', filename=os.path.basename(cleaned_fif)),
        csv_file=url_for('download_file', filename=os.path.basename(cleaned_csv)),
        n_ica_excluded=len(ica_exclude) if 'ica_exclude' in locals() else 0,
        error_message=error_message,
        raw_plot_exists=raw_plot_exists,
        cleaned_plot_exists=cleaned_plot_exists,
        ica_plot_exists=ica_plot_exists,
        cleanup_message=(f"Cleanup: {len(deleted_files)} old file(s) removed from uploads/output." if deleted_files else None),
    )

@app.route('/output/<filename>')
def serve_output_file(filename):
    """Serve generated HTML plot files from the output folder."""
    return send_from_directory(app.config['OUTPUT_FOLDER'], filename)

@app.route('/download/<filename>')
def download_file(filename):
    """Download endpoint for cleaned files."""
    return send_from_directory(app.config['OUTPUT_FOLDER'], filename, as_attachment=True)

if __name__ == '__main__':
    app.run(debug=True)