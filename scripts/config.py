# Cấu hình global cho dự án
import os
from pathlib import Path

# Base paths
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"

# Database paths
DUCKDB_PATH = BASE_DIR / "datawarehouse.duckdb"

# Google Sheets config
GOOGLE_SHEETS_DIR = BASE_DIR / "google_sheets"
CREDENTIALS_FILE = GOOGLE_SHEETS_DIR / "credentials.json"
# Điền sheet_id vào đây
SHEET_ID="................"

# dbt paths
DBT_PROJECT_DIR = BASE_DIR / "dbt_project"

# Tableau config
TABLEAU_DIR = BASE_DIR / "tableau"