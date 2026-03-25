"""
Script để load nhiều files vào database
"""

import duckdb
import time
from config import *


class Load_Data:
    def __init__(self, conn, file_pattern, target_schema):
        self.conn = conn
        self.file_pattern = file_pattern
        self.target_schema = target_schema

    def load_data(self, function_read_file):
        """
        Load multiple files matching file pattern to DB

        Args:
            file_pattern: Pattern to match files (e.g., "*.csv")
            target_schema: Schema to load data into
            table_prefix: Prefix for table names
            function_read_file: lambda hoặc string SQL read
        """
        try:
            files = list(DATA_DIR.glob(self.file_pattern))
            if not files:
                print(
                    f"[WARN] Không tìm thấy file nào match pattern: {self.file_pattern}"
                )
                return

            # Tạo schema nếu không tồn tại
            self.conn.execute(f"CREATE SCHEMA IF NOT EXISTS {self.target_schema}")

            for file in files:
                # Tạo tên table từ tên file
                table_name = file.stem.lower()
                full_table_name = f"{self.target_schema}.{table_name}"
                start_time = time.time()
                read_sql = function_read_file(str(file))
                self.conn.execute(
                    f"""
                    CREATE OR REPLACE TABLE {full_table_name}
                    AS {read_sql};
                """
                )
                end_time = time.time()

                # Kết quả
                row_count = self.conn.execute(
                    f"SELECT COUNT(*) FROM {self.target_schema}.{table_name}"
                ).fetchone()[0]
                print(
                    f"[INFO] Đã load dữ liệu từ {file.name} -> {table_name} ({row_count:,} dòng), {end_time-start_time:.2f}s"
                )
        except Exception as e:
            print(f"[WARN] LỖI KHI LOAD DATA!: {e}")
            raise


class DBLoader:
    def __init__(self, db_path=DUCKDB_PATH):
        self.db_path = db_path
        self.conn = None
        self.setup_database()

    def setup_database(self):
        """Setup database và Schema"""

        # Connect to DuckDB
        self.conn = duckdb.connect(str(self.db_path))
        print("Đã kết nối với DuckDB")

    def create_loader(self, file_pattern, target_schema):
        """
        Tạo một instance loader với cấu hình cụ thể.
        """
        return Load_Data(
            conn=self.conn,
            file_pattern=file_pattern,
            target_schema=target_schema,
        )

    def load_all(self, loaders_config):
        """
        Load nhiều nhóm dữ liệu theo config

        Args:
            loaders_config: list of dict, mỗi dict chứa:
                - file_pattern
                - target_schema
                - function_read_file
        """
        print("=" * 20)
        print("[INFO] START LOADING DATA...")
        print("=" * 20)

        for config in loaders_config:
            loader = self.create_loader(
                file_pattern=config["file_pattern"],
                target_schema=config["target_schema"],
            )
            loader.load_data(config["function_read_file"])
        # Log summary
        self.log_database_summary()

        print("=" * 20)
        print("[INFO] DATA LOAD COMPLETED SUCCESSFULLY!")
        print("=" * 20)

    def log_database_summary(self):
        """Log summary of loaded data"""
        print("\n📊 DATABASE SUMMARY:")

        # Get all tables
        tables = self.conn.execute(
            """
            SELECT table_schema, table_name 
            FROM information_schema.tables 
            WHERE table_type = 'BASE TABLE'
            ORDER BY table_schema, table_name
        """
        ).fetchall()

        for schema, table in tables:
            count = self.conn.execute(
                f"SELECT COUNT(*) FROM {schema}.{table}"
            ).fetchone()[0]
            print(f"{schema}.{table}: {count:,} dòng")

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("[INFO] Database connection closed!")


def main():
    """Main execution function"""
    db_loader = None
    loaders_config = [
        {
            "file_pattern": "*.csv",
            "target_schema": "raw",
            "function_read_file": lambda p: f"SELECT * FROM read_csv_auto('{p}')",
        },
        {
            "file_pattern": "*.parquet",
            "target_schema": "raw",
            "function_read_file": lambda p: f"SELECT * FROM read_parquet('{p}')",
        },
    ]
    try:
        db_loader = DBLoader()
        db_loader.load_all(loaders_config=loaders_config)
    except Exception as e:
        print(f"[WARN] Pipeline lỗi: {e}")
    finally:
        if db_loader:
            db_loader.close()


if __name__ == "__main__":
    main()