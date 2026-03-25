# 🔭 Customer 360 Lifecycle Dashboard

> **End-to-end analytics pipeline** theo dõi toàn bộ vòng đời khách hàng - từ lần đầu đăng ký đến churn - thông qua một hệ thống dữ liệu hoàn chỉnh: **Python → DuckDB → dbt → Tableau**.

> **Lưu ý:** Dữ liệu sử dụng trong dự án được tạo ra từ Python code, không có ý nghĩa thực tế, chỉ có ý nghĩa trong dự án này. Không sử dụng dữ liệu này vào thực tế!!!
---

## 📌 Mục Lục

- [Giới Thiệu](#-giới-thiệu)
- [Kiến Trúc Hệ Thống](#-kiến-trúc-hệ-thống)
- [Dashboard Preview](#-dashboard-preview)
- [Tech Stack](#-tech-stack)
- [Cấu Trúc Dự Án](#-cấu-trúc-dự-án)
- [Data Model](#-data-model)
- [Cài Đặt & Chạy](#-cài-đặt--chạy)
- [Các Module Phân Tích](#-các-module-phân-tích)
- [Tài Liệu](#-tài-liệu)

---

## ✨ Giới Thiệu

**Customer 360 Lifecycle Dashboard** là một dự án phân tích dữ liệu end-to-end, mô phỏng hệ thống BI cho một sản phẩm SaaS. Dự án xây dựng toàn bộ pipeline từ sinh dữ liệu thô, transform bằng dbt, lưu trữ trên DuckDB, đến trực quan hóa trên Tableau - phủ đầy đủ 5 chiều phân tích của một Customer Lifecycle:

| Module | Mục tiêu |
|---|---|
| 🟢 **Acquisition** | Theo dõi tăng trưởng đăng ký & hiệu quả onboarding |
| 🔵 **Engagement** | Đo lường DAU/MAU, session, stickiness |
| 🟠 **Retention & Churn** | Phân tích tỷ lệ giữ chân và rời bỏ khách hàng |
| 🟣 **Revenue** | MRR, ARPU, phân phối gói subscription |
| 🔴 **Support & Health** | CSAT, ticket resolution, customer health |

---

## 🏗 Kiến Trúc Hệ Thống

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA PIPELINE                           │
│                                                             │
│  generate_data.py   →   load_to_db.py   →   DuckDB         │
│  (Synthetic Data)        (Raw Ingestion)     (Warehouse)    │
│                                                ↓            │
│                          dbt (Transform)                    │
│                   ┌──────────────────────┐                  │
│                   │  Staging → Intermediate → Marts         │
│                   └──────────────────────┘                  │
│                                ↓                            │
│              Tableau (.twbx)   │   Google Sheets            │
│              (Visualization)   │   (Export/Sharing)         │
└─────────────────────────────────────────────────────────────┘
```

**Data Flow chi tiết:**
1. `load_to_db.py` - nạp raw data vào **DuckDB** (`datawarehouse.duckdb`)
2. **dbt** transform qua 3 lớp: `staging → intermediate → marts`
3. Marts được export lên **Google Sheets**, sau đó kết nối trực tiếp vào **Tableau**

---

## 📊 Dashboard Preview

> Dashboard được xây dựng trên Tableau với 5 tab tương ứng với 5 module phân tích.

| Acquisition | Engagement |
|---|---|
| ![Acquisition](https://github.com/hoan110102/customer360-lifecycle-dashboard/blob/main/tableau/example%20dashboard%20image/DB%20acquisition.png) | ![Engagement](https://github.com/hoan110102/customer360-lifecycle-dashboard/blob/main/tableau/example%20dashboard%20image/DB%20engagement.png) |

| Retention | Revenue |
|---|---|
| ![Retention](https://github.com/hoan110102/customer360-lifecycle-dashboard/blob/main/tableau/example%20dashboard%20image/DB%20retention.png) | ![Revenue](https://github.com/hoan110102/customer360-lifecycle-dashboard/blob/main/tableau/example%20dashboard%20image/DB%20revenue.png) |

| Support |  |
|---|---|
| ![Support](https://github.com/hoan110102/customer360-lifecycle-dashboard/blob/main/tableau/example%20dashboard%20image/DB%20support.png) | |

---

## 🛠 Tech Stack

| Layer | Tool | Vai trò |
|---|---|---|
| **Data Warehouse** | DuckDB | In-process OLAP database |
| **Transform** | dbt Core | Staging → Intermediate → Marts |
| **Visualization** | Tableau Desktop/Public | Interactive dashboards |
| **Export** | Google Sheets API + `gspread` | Chia sẻ dữ liệu |
| **Orchestration** | `pipeline.py` | Chạy toàn bộ pipeline |

---

## 📁 Cấu Trúc Dự Án

```
customer360-lifecycle-dashboard/
│
├── pipeline.py                  # 🚀 Entry point — chạy toàn bộ pipeline
├── datawarehouse.duckdb         # 🦆 DuckDB data warehouse
├── requirements.txt
│
├── scripts/                     # Python scripts
│   ├── load_to_db.py            # Load raw data vào DuckDB
│   ├── export_to_ggsheet.py     # Export lên Google Sheets
│   ├── config.py                # Cấu hình chung
│   └── logs/
│       └── dbt.log
│
├── dbt/                         # dbt project
│   ├── customer_360_lifecycle/  # dbt project chính
│       └── models/
│           ├── staging/         # stg_user, stg_subscription, ...
│           ├── intermediate/    # int_* (fill null, enrich)
│           └── marts/
│               ├── core/        # dim_*, fact_*
│               └── analytics/   # mart_acquisition, mart_retention, ...
│
├── tableau/
│   ├── customer360_lifecycle_dashboard.twbx   # Tableau workbook
│   ├── example dashboard image/               # Screenshot từng tab
│   └── icons/                                 # Custom icons theo module
│
├── google_sheets/
│   └── google_sheet_example_credentials.json  # Template credentials
│
└── docs/
    ├── BRD Customer360 Lifecycle Dashboard.pdf
    ├── Customer360 Lifecycle Dashboard.pdf
    └── Customer360 Lifecycle Report.pdf
```

---

## 🗂 Data Model

### dbt Layers

```
Raw (DuckDB)
    └── Staging          stg_user, stg_subscription, stg_transaction
          └── Intermediate   int_user_get_account_tier, int_product_usage_fillna, ...
                └── Core Marts     dim_user, dim_subscription, fact_transaction, ...
                      └── Analytics Marts
                              mart_acquisition
                              mart_engagement
                              mart_retention
                              mart_revenue
                              mart_support
```

### Fact & Dimension Tables

| Table | Mô tả |
|---|---|
| `dim_user` | Thông tin users, account tier |
| `dim_subscription` | Subscription plan, status |
| `dim_date` | Date dimension |
| `fact_transaction` | Lịch sử thanh toán |
| `fact_product_usage` | Sự kiện sử dụng tính năng |
| `fact_support` | Support ticket |

### Analytics Marts

| Mart | Phục vụ Dashboard |
|---|---|
| `mart_acquisition` | Acquisition tab |
| `mart_engagement` | Engagement tab |
| `mart_retention` | Retention tab |
| `mart_revenue` | Revenue tab |
| `mart_support` | Support tab |

---

## ⚙️ Cài Đặt & Chạy

### Yêu Cầu

- Python 3.10+
- Tableau Desktop hoặc Tableau Public (2026.1 trở lên để xem đầy đủ tính năng) (để xem `.twbx`)
- (Tuỳ chọn) Google account để export Sheets

### Cài Đặt

```bash
# Clone repository
git clone https://github.com/hoan110102/customer360-lifecycle-dashboard.git
cd customer360-lifecycle-dashboard

# Tạo virtual environment
python -m venv .venv
# Windows
.venv\Scripts\activate
# Mac/Linux
source .venv/bin/activate

# Cài đặt dependencies
pip install -r requirements.txt

# Cài dbt adapter cho DuckDB
pip install dbt-duckdb
```

### Chạy Pipeline

```bash
# Chạy toàn bộ pipeline (load → dbt run → export)
python pipeline.py
```

Hoặc chạy từng bước thủ công:

```bash
# Bước 1: Load vào DuckDB
python scripts/load_to_db.py

# Bước 2: Transform với dbt
cd dbt/customer_360_lifecycle
dbt run
dbt test

# Bước 3: Export lên Google Sheets (tuỳ chọn)
python scripts/export_to_ggsheet.py
```

### Cấu Hình Google Sheets (Tuỳ Chọn)

1. Tạo project trên [Google Cloud Console](https://console.cloud.google.com/)
2. Kích hoạt **Google Sheets API** và **Google Drive API**
3. Tạo **Service Account** và download file JSON
4. Đặt file vào `google_sheets/credentials.json`
5. Chia sẻ Google Sheet với email của service account

---

## 📐 Các Module Phân Tích

### 🟢 Acquisition & Onboarding
Theo dõi nguồn tăng trưởng người dùng và hiệu quả giai đoạn onboarding.

**KPIs:** New Signups · Activation Rate · Time to First Action · Top Lead Source

### 🔵 Engagement
Đo mức độ gắn kết người dùng với sản phẩm theo thời gian.

**KPIs:** DAU · MAU · Stickiness (DAU/MAU) · Avg Session Duration · Avg Events/Session

### 🟠 Retention & Churn
Phân tích tỷ lệ giữ chân và các dấu hiệu rời bỏ của khách hàng.

**KPIs:** Retention Rate · User Churn Rate · Revenue Churn · Customer Lifespan

### 🟣 Revenue
Theo dõi sức khỏe doanh thu subscription.

**KPIs:** MRR · ARPU · Plan Distribution · Refund Rate · Payment Failure Rate

### 🔴 Support & Customer Health
Đánh giá chất lượng hỗ trợ và chỉ số hài lòng của khách hàng.

**KPIs:** CSAT · Total Tickets · First Reply Time · Full Resolution Time · Resolved Rate

---

## 📄 Tài Liệu

Tài liệu đầy đủ được lưu trong thư mục `docs/`:

| Tài liệu | Mô tả |
|---|---|
| `BRD Customer360 Lifecycle Dashboard.pdf` | Business Requirements Document |
| `Customer360 Lifecycle Dashboard.pdf` | Mẫu báo cáo |
| `Customer360 Lifecycle Report.pdf` | Báo cáo phân tích |

---

## 📬 Liên Hệ

**Author:** [hoan110102](https://github.com/hoan110102)

**Project:** [github.com/hoan110102/customer360-lifecycle-dashboard](https://github.com/hoan110102/customer360-lifecycle-dashboard)

---

> ⭐ Nếu dự án hữu ích với bạn, hãy để lại một star nhé!
