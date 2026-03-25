import subprocess
import os
import sys

def run_generate_script(scripts_python_dir):
    print("[INFO] Running generate script...")
    try:
        os.chdir(scripts_python_dir)
        subprocess.check_call([sys.executable, 'generate_data.py'])
        print("[SUCCESS] Generate completed.")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Generate failed: {e}")
        sys.exit(1)

def run_load_script(scripts_python_dir):
    print("[INFO] Running load script...")
    try:
        os.chdir(scripts_python_dir)
        subprocess.check_call([sys.executable, 'load_to_db.py'])
        print("[SUCCESS] Load completed.")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Load failed: {e}")
        sys.exit(1)

def run_dbt_models(dbt_project_dir):
    print("[INFO] Running dbt models...")
    try:
        original_dir = os.getcwd()
        os.chdir(dbt_project_dir)
        
        # Tìm dbt.exe trong venv\Scripts
        venv_scripts = os.path.dirname(sys.executable)
        dbt_exe = os.path.join(venv_scripts, 'dbt.exe')
        
        if not os.path.exists(dbt_exe):
            raise FileNotFoundError(f"Không tìm thấy dbt.exe trong {venv_scripts}")
        
        subprocess.check_call([dbt_exe, 'run'])
        
        os.chdir(original_dir)
        print("[SUCCESS] dbt transform completed.")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] dbt failed: {e}")
        sys.exit(1)

def run_export_script(scripts_python_dir):
    print("[INFO] Running export script...")
    try:
        os.chdir(scripts_python_dir)
        subprocess.check_call([sys.executable, 'export_to_ggsheet.py'])
        print("[SUCCESS] Export completed.")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Export failed: {e}")
        sys.exit(1)

def main():
    dbt_dir = os.path.join(os.path.dirname(__file__), "dbt_project")
    scripts_python_dir= os.path.join(os.path.dirname(__file__), "scripts")
    run_generate_script(scripts_python_dir)
    run_load_script(scripts_python_dir)
    run_dbt_models(dbt_dir)
    run_export_script(scripts_python_dir)
    print("[INFO] Pipeline completed successfully!")

if __name__ == "__main__":
    main()