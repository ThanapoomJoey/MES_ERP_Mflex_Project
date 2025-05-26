import psycopg2
import csv
import os
from datetime import datetime

# ============== การตั้งค่าการเชื่อมต่อฐานข้อมูล ==============
DB_HOST = "localhost"
DB_NAME = "mflex_mes_erp_sim"  # ชื่อฐานข้อมูลของคุณ
DB_USER = "admin"              # User ของคุณ
DB_PASSWORD = "admin123"       # Password ของคุณ
DB_PORT = "5432"
DB_SCHEMA = "public"           # Schema ที่ต้องการ Export (ส่วนใหญ่คือ public)

# ============== การตั้งค่าสำหรับ Export ==============
OUTPUT_DIRECTORY = "exported_csv_data" # โฟลเดอร์ที่จะเก็บไฟล์ CSV
FILE_TIMESTAMP_FORMAT = "%Y%m%d_%H%M%S" # รูปแบบ Timestamp สำหรับชื่อไฟล์ (ถ้าต้องการ)
INCLUDE_TIMESTAMP_IN_FILENAME = True   # True ถ้าต้องการใส่ Timestamp ในชื่อไฟล์

# ============== ฟังก์ชันช่วยในการเชื่อมต่อฐานข้อมูล ==============
def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD, port=DB_PORT
        )
        return conn
    except psycopg2.Error as e:
        print(f"เกิดข้อผิดพลาดในการเชื่อมต่อฐานข้อมูล: {e}")
        return None

# ============== ฟังก์ชันในการดึงชื่อตารางทั้งหมดใน Schema ==============
def get_all_table_names(conn, schema_name):
    table_names = []
    try:
        with conn.cursor() as cur:
            cur.execute(f"""
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = %s
                AND table_type = 'BASE TABLE';
            """, (schema_name,))
            rows = cur.fetchall()
            for row in rows:
                table_names.append(row[0])
    except psycopg2.Error as e:
        print(f"เกิดข้อผิดพลาดในการดึงชื่อตาราง: {e}")
    return table_names

# ============== ฟังก์ชันในการ Export ข้อมูลตารางไปยัง CSV ==============
def export_table_to_csv(conn, table_name, schema_name, output_filepath):
    try:
        with conn.cursor() as cur:
            # ดึงข้อมูลทั้งหมดจากตาราง
            cur.execute(f'SELECT * FROM "{schema_name}"."{table_name}";') # ใช้ Double Quotes ป้องกันชื่อที่มีตัวพิมพ์ใหญ่หรืออักขระพิเศษ
            rows = cur.fetchall()

            # ดึงชื่อคอลัมน์ (Header)
            column_names = [desc[0] for desc in cur.description]

            # เขียนไปยังไฟล์ CSV
            with open(output_filepath, 'w', newline='', encoding='utf-8') as csvfile:
                csv_writer = csv.writer(csvfile)
                # เขียน Header
                csv_writer.writerow(column_names)
                # เขียนข้อมูล
                for row in rows:
                    # แปลง datetime objects เป็น string ก่อนเขียน (ถ้าจำเป็น)
                    # csv_writer.writerow([str(item) if isinstance(item, datetime) else item for item in row])
                    csv_writer.writerow(row) # ส่วนใหญ่ psycopg2 จะ handle ประเภทข้อมูลพื้นฐานได้ดี

            print(f"ข้อมูลจากตาราง '{schema_name}.{table_name}' ถูก Export ไปยัง '{output_filepath}' เรียบร้อยแล้ว")
            return True

    except psycopg2.Error as e:
        print(f"เกิดข้อผิดพลาดในการ Export ตาราง '{schema_name}.{table_name}': {e}")
        return False
    except IOError as e:
        print(f"เกิดข้อผิดพลาด I/O ในการเขียนไฟล์ CSV สำหรับตาราง '{schema_name}.{table_name}': {e}")
        return False

# ============== Main Script ==============
def main():
    # สร้างโฟลเดอร์ Output ถ้ายังไม่มี
    if not os.path.exists(OUTPUT_DIRECTORY):
        try:
            os.makedirs(OUTPUT_DIRECTORY)
            print(f"สร้างโฟลเดอร์ '{OUTPUT_DIRECTORY}' เรียบร้อยแล้ว")
        except OSError as e:
            print(f"เกิดข้อผิดพลาดในการสร้างโฟลเดอร์ '{OUTPUT_DIRECTORY}': {e}")
            return

    conn = get_db_connection()
    if not conn:
        return

    try:
        # DB_SCHEMA ถูกใช้ในการดึงชื่อตาราง
        table_names_to_export = get_all_table_names(conn, DB_SCHEMA)

        if not table_names_to_export:
            print(f"ไม่พบตารางใน Schema '{DB_SCHEMA}'")
            return

        print(f"พบตารางทั้งหมด {len(table_names_to_export)} ตารางใน Schema '{DB_SCHEMA}': {', '.join(table_names_to_export)}")

        exported_count = 0
        failed_count = 0

        for table_name in table_names_to_export:
            timestamp_str = ""
            if INCLUDE_TIMESTAMP_IN_FILENAME:
                timestamp_str = f"_{datetime.now().strftime(FILE_TIMESTAMP_FORMAT)}"

            # ใช้ DB_SCHEMA ในการสร้างชื่อไฟล์
            output_filename = f"{DB_SCHEMA}_{table_name}{timestamp_str}.csv"
            output_filepath = os.path.join(OUTPUT_DIRECTORY, output_filename)

            # แก้ไข: ใช้ DB_SCHEMA ในการ print
            print(f"\nกำลัง Export ตาราง: {DB_SCHEMA}.{table_name}...")
            # DB_SCHEMA ถูกส่งเข้าไปใน export_table_to_csv เป็น argument ที่ 3
            if export_table_to_csv(conn, table_name, DB_SCHEMA, output_filepath):
                exported_count += 1
            else:
                failed_count += 1

        print(f"\n===== สรุปการ Export =====")
        print(f"Export สำเร็จ: {exported_count} ตาราง")
        print(f"Export ล้มเหลว: {failed_count} ตาราง")

    finally:
        if conn:
            conn.close()
            print("\nปิดการเชื่อมต่อฐานข้อมูลเรียบร้อยแล้ว")

if __name__ == "__main__":
    main()