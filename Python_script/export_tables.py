import pandas as pd
import psycopg2 # หรือ import connector อื่นๆ ตามฐานข้อมูลที่คุณใช้
from datetime import datetime

# ============== การตั้งค่าการเชื่อมต่อฐานข้อมูล ==============
# --- กรุณาแก้ไขค่าเหล่านี้ให้ตรงกับระบบของคุณ ---
DB_HOST = "localhost"
DB_NAME = "mflex_mes_erp_sim" # ชื่อฐานข้อมูลที่คุณสร้าง View ไว้
DB_USER = "admin"
DB_PASSWORD = "admin123"
DB_PORT = "5432"
DB_SCHEMA = "public" # สกีมาที่ View ของคุณอยู่

# ============== ชื่อ View และชื่อไฟล์ Output ==============
VIEW_NAME = "vw_production_and_quality_analysis"

# สร้างชื่อไฟล์ output พร้อม timestamp
timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
CSV_OUTPUT_FILENAME = f"{VIEW_NAME}_{timestamp_str}.csv"
EXCEL_OUTPUT_FILENAME = f"{VIEW_NAME}_{timestamp_str}.xlsx"

def get_db_connection():
    """สร้างและคืนค่า connection object ของฐานข้อมูล"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT
        )
        print("เชื่อมต่อฐานข้อมูลสำเร็จ!")
        return conn
    except psycopg2.Error as e:
        print(f"เกิดข้อผิดพลาดในการเชื่อมต่อฐานข้อมูล: {e}")
        return None

def fetch_data_from_view(view_name):
    """ดึงข้อมูลทั้งหมดจาก View ที่ระบุ และคืนค่าเป็น Pandas DataFrame"""
    conn = None
    df = None
    query = f"SELECT * FROM {DB_SCHEMA}.{view_name};"

    try:
        conn = get_db_connection()
        if conn:
            print(f"กำลังดึงข้อมูลจาก View: {DB_SCHEMA}.{view_name}...")
            df = pd.read_sql_query(query, conn)
            print(f"ดึงข้อมูลสำเร็จ! จำนวน {len(df)} แถว")
    except Exception as e:
        print(f"เกิดข้อผิดพลาดในการดึงข้อมูลจาก View: {e}")
    finally:
        if conn:
            conn.close()
            print("ปิดการเชื่อมต่อฐานข้อมูลแล้ว")
    return df

def export_dataframe(df, csv_filename, excel_filename):
    """Export DataFrame เป็นไฟล์ CSV และ Excel"""
    if df is not None and not df.empty:
        try:
            # Export to CSV
            df.to_csv(csv_filename, index=False, encoding='utf-8-sig') # utf-8-sig สำหรับ Excel อ่านภาษาไทยได้ถูกต้อง
            print(f"Export ข้อมูลเป็น CSV สำเร็จ: {csv_filename}")

            # Export to Excel
            df.to_excel(excel_filename, index=False, engine='openpyxl')
            print(f"Export ข้อมูลเป็น Excel สำเร็จ: {excel_filename}")
        except Exception as e:
            print(f"เกิดข้อผิดพลาดในการ Export ข้อมูล: {e}")
    else:
        print("ไม่มีข้อมูลให้ Export (DataFrame is None or empty)")

if __name__ == "__main__":
    print("===== เริ่มต้นกระบวนการ Export ข้อมูลจาก View =====")

    # 1. ดึงข้อมูลจาก View
    dataframe_from_view = fetch_data_from_view(VIEW_NAME)

    # 2. Export ข้อมูล
    if dataframe_from_view is not None:
        export_dataframe(dataframe_from_view, CSV_OUTPUT_FILENAME, EXCEL_OUTPUT_FILENAME)
    else:
        print("ไม่สามารถดึงข้อมูลจาก View ได้, ไม่มีการ Export ข้อมูล")

    print("===== สิ้นสุดกระบวนการ Export ข้อมูล =====")