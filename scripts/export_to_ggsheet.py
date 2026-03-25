"""
Export data từ DuckDB lên Google Sheets cho Tableau connection
(Tableau bản free không connect trực tiếp được với DB)
"""

import gspread
from google.oauth2.service_account import Credentials
import duckdb
import time
import pandas as pd
import numpy as np
from config import *
 
 
class GoogleSheetsExporter:
    def __init__(self, credentials_file=CREDENTIALS_FILE, sheet_id=SHEET_ID):
        self.credentials_file = credentials_file
        self.client = self.authenticate()
        self.sheet_id = sheet_id
 
    def authenticate(self):
        """Authenticate với Google Sheets API"""
        try:
            scopes = [
                "https://www.googleapis.com/auth/spreadsheets",
                "https://www.googleapis.com/auth/drive",
            ]
            creds = Credentials.from_service_account_file(
                str(self.credentials_file), scopes=scopes
            )
            client = gspread.authorize(creds)
            print("[INFO] Google Sheets API authenticated")
            return client
        except Exception as e:
            print(f"[WARN] Lỗi Authenticate: {e}")
            raise
 
    def create_or_get_worksheet(self, sheet_name, rows=10000, cols=10):
        """Tạo Worksheet mới hoặc lấy Worksheet đã có, luôn resize đúng kích thước"""
        sheet = self.client.open_by_key(self.sheet_id)
        try:
            worksheet = sheet.worksheet(sheet_name)
            # Resize để đảm bảo đủ chỗ cho dữ liệu mới
            worksheet.resize(rows=rows, cols=cols)
            print(f"[INFO] Đã mở & resize Worksheet: {sheet_name} ({rows} rows × {cols} cols)")
        except gspread.WorksheetNotFound:
            print(f"[WARN] Không tồn tại Worksheet: {sheet_name} → Tạo mới")
            worksheet = sheet.add_worksheet(
                title=sheet_name,
                rows=rows,
                cols=cols,
            )
            print(f"[INFO] Đã tạo Worksheet: {sheet_name} ({rows} rows × {cols} cols)")
        return worksheet
 
    def export_to_sheet(self, db_conn, schema, table_name, sheet_name=None, chunk_size=3000):
        """
        Export DuckDB table lên Google Sheets theo từng chunk.
 
        Args:
            db_conn    : DuckDB connection
            schema     : Database schema
            table_name : Tên bảng cần export
            sheet_name : Tên sheet trên Google Sheets (mặc định = table_name)
            chunk_size : Số dòng mỗi lần upload (default 3000)
        """
        if sheet_name is None:
            sheet_name = table_name
 
        try:
            print(f"\n[INFO] Bắt đầu export: {schema}.{table_name}")
 
            # - Lấy dữ liệu từ DuckDB
            query = f"SELECT * FROM {schema}.{table_name}"
            df = db_conn.execute(query).df()
		    
            df = df.replace(np.nan, None)
 
            if df.empty:
                print("[WARN] Dataframe rỗng, bỏ qua!")
                return None
 
            num_rows = len(df)
            num_cols = len(df.columns)
            # Chuyển số cột sang ký tự cột
            col_letter = chr(64 + num_cols) if num_cols <= 26 else "Z"
 
            print(f"[INFO] Fetched {num_rows:,} dòng × {num_cols} cột từ {table_name}")
 
            # - Fix datetime: convert sang string để tránh lỗi serialize ─
            for col in df.columns:
                if pd.api.types.is_datetime64_any_dtype(df[col]):
                    df[col] = df[col].dt.strftime("%Y-%m-%d %H:%M:%S")
 
            # - Tạo / lấy worksheet, resize đúng kích thước, rồi clear ─
            # rows = num_rows (data) + 1 (header) + 10 (buffer)
            # cols = num_cols + 1 (buffer)
            worksheet = self.create_or_get_worksheet(
                sheet_name, rows=num_rows + 11, cols=num_cols + 1
            )
            worksheet.clear()
 
            # - Upload header
            header_range = f"A1:{col_letter}1"
            worksheet.update(
                range_name=header_range,
                values=[df.columns.tolist()],
                value_input_option="RAW",
            )
            worksheet.format(header_range, {"textFormat": {"bold": True}})
            print(f"[INFO] Đã upload header ({num_cols} cột)")
 
            # - Upload data theo chunk với retry logic
            current_row = 2  # bắt đầu sau header
 
            for i in range(0, num_rows, chunk_size):
                chunk     = df.iloc[i : i + chunk_size]
                end_row   = current_row + len(chunk) - 1
                rng       = f"A{current_row}:{col_letter}{end_row}"
                values    = chunk.values.tolist()
 
                # Retry tối đa 3 lần khi gặp rate limit hoặc server error
                for attempt in range(3):
                    try:
                        worksheet.update(
                            range_name=rng,
                            values=values,
                            value_input_option="RAW",
                        )
                        print(f"[INFO] ✓ Chunk {i+1:,} → {i+len(chunk):,} / {num_rows:,} dòng")
                        break
                    except gspread.exceptions.APIError as e:
                        err_str = str(e)
                        if any(code in err_str for code in ["429", "500", "quota"]):
                            wait = 5 * (attempt + 1)
                            print(f"[WARN] Rate limit / Server error → chờ {wait}s, retry (lần {attempt+1}/3)...")
                            time.sleep(wait)
                            if attempt == 2:
                                raise
                        else:
                            raise
 
                current_row = end_row + 1
                time.sleep(1.5)  # delay an toàn giữa các chunk
 
            print(f"[SUCCESS] ✅ Export xong {num_rows:,} dòng → Sheet '{sheet_name}'")
            return worksheet
 
        except Exception as e:
            print(f"[ERROR] Lỗi upload {schema}.{table_name}: {e}")
            raise
 
    def export_table(self, db_path=DUCKDB_PATH, tables_to_export=None):
        """Export danh sách tables từ DuckDB lên Google Sheets"""
        if tables_to_export is None:
            tables_to_export = []
 
        print("=" * 40)
        print("[INFO] START EXPORTING DATA (CHUNK MODE)...")
        print("=" * 40)
 
        conn = duckdb.connect(str(db_path))
 
        if not tables_to_export:
            print("[WARN] Không có bảng nào được chỉ định để export!")
            conn.close()
            return
 
        for table in tables_to_export:
            schema = "main_marts"
            try:
                exists = conn.execute(
                    f"""
                    SELECT COUNT(*) FROM information_schema.tables
                    WHERE table_schema = '{schema}' AND table_name = '{table}'
                    """
                ).fetchone()[0]
 
                if exists:
                    self.export_to_sheet(
                        conn, schema, table, sheet_name=table, chunk_size=3000
                    )
                else:
                    print(f"[WARN] Table {schema}.{table} không tồn tại → skip!")
 
            except Exception as e:
                print(f"[ERROR] Export {table} thất bại: {e}")
 
        conn.close()
 
        print("=" * 40)
        print("[INFO] EXPORT COMPLETED! 🎉")
        print("=" * 40)
 
 
def main():
    """Main execution"""
    try:
        exporter = GoogleSheetsExporter()
        tables_to_export = [
	        "mart_engagement",
            "mart_acquisition",
            "mart_support",
            "mart_retention",
            "mart_revenue"
        ]
        exporter.export_table(tables_to_export=tables_to_export)
    except Exception as e:
        print(f"[ERROR] Export failed: {e}")
 
 
if __name__ == "__main__":
    main()
