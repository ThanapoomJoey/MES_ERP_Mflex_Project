import streamlit as st
import pandas as pd
import psycopg2
import plotly.express as px
from datetime import datetime, timedelta

# ============== การตั้งค่าการเชื่อมต่อฐานข้อมูล (เหมือนเดิม) ==============
DB_HOST = "localhost"
DB_NAME = "mflex_mes_erp_sim" # ชื่อฐานข้อมูลของคุณ
DB_USER = "admin"             # User ของคุณ
DB_PASSWORD = "admin123"      # Password ของคุณ
DB_PORT = "5432"
DB_SCHEMA = "public"         # Schema ที่ View Tables อยู่

# ============== ฟังก์ชันช่วยในการเชื่อมต่อฐานข้อมูล (แก้ไข decorator) ==============
@st.cache_resource(ttl=600) # Cache resource for 10 minutes, and manage its lifecycle
def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD, port=DB_PORT
        )
        # For cache_resource, you might need a cleanup function if the resource needs explicit closing
        # In this simple case, the connection is closed in fetch_data_from_view
        # but for more complex resources, a cleanup function is good practice.
        # yield conn # If using a cleanup function with yield
        return conn
    except psycopg2.Error as e:
        st.error(f"เกิดข้อผิดพลาดในการเชื่อมต่อฐานข้อมูล: {e}")
        return None

# ฟังก์ชัน fetch_data_from_view ยังคงใช้ @st.cache_data ได้ เพราะมัน return DataFrame ซึ่ง pickle ได้
@st.cache_data(ttl=600)
def fetch_data_from_view(view_name, schema=DB_SCHEMA, date_filter_col=None, start_date=None, end_date=None):
    conn = get_db_connection() # This will now use the cached connection managed by cache_resource
    if not conn:
        return pd.DataFrame()

    query = f"SELECT * FROM {schema}.{view_name}"
    params = []
    conditions = []

    if date_filter_col and start_date and end_date:
        conditions.append(f"{date_filter_col} >= %s AND {date_filter_col} < %s") # < end_date + 1 day
        params.extend([start_date, end_date + timedelta(days=1)])

    if conditions:
        query += " WHERE " + " AND ".join(conditions)

    try:
        df = pd.read_sql_query(query, conn, params=params)
        return df
    except Exception as e:
        st.error(f"เกิดข้อผิดพลาดในการดึงข้อมูลจาก View {view_name}: {e}")
        return pd.DataFrame()
    # finally:
    #     if conn:
    #         conn.close() # การ close connection ควรจะจัดการโดย cache_resource หรือถ้าไม่ใช้ cache_resource ก็ทำในแต่ละครั้งที่เรียกใช้
                         # ในกรณีนี้ fetch_data_from_view ไม่ควร close connection ที่ได้จาก cache_resource เอง
                         # cache_resource จะจัดการ lifecycle ของ connection

# ... ส่วนที่เหลือของโค้ดเหมือนเดิม ...

# ============== ส่วนหัวของ Dashboard ==============
st.set_page_config(layout="wide", page_title="ภาพรวมระบบ MES/ERP Mflex (จำลอง)")
st.title("📊 ภาพรวมระบบ MES/ERP Mflex (จำลอง)")
st.markdown("แดชบอร์ดนี้แสดงภาพรวมข้อมูลการผลิตและคุณภาพจากระบบจำลอง")

# ============== Date Range Filter (ตัวกรองช่วงวันที่) ==============
st.sidebar.header("ตัวกรองข้อมูล")
default_end_date = datetime.now().date()
default_start_date = default_end_date - timedelta(days=30)

start_date_input = st.sidebar.date_input("วันที่เริ่มต้น", default_start_date)
end_date_input = st.sidebar.date_input("วันที่สิ้นสุด", default_end_date)

if start_date_input > end_date_input:
    st.sidebar.error("วันที่เริ่มต้นต้องมาก่อนวันที่สิ้นสุด")
    st.stop()


# ============== โหลดข้อมูลจาก Views โดยใช้ Date Filter ==============
st.header("1. สรุปประสิทธิภาพ Work Order")
# เนื่องจาก get_db_connection ถูกเรียกภายใน fetch_data_from_view
# และ fetch_data_from_view return DataFrame ซึ่ง cache ด้วย cache_data ได้ถูกต้อง
# ปัญหาหลักคือการ cache connection object เอง
df_wo_summary = fetch_data_from_view(
    "vw_workorder_performance_summary",
    date_filter_col="actualstartdate", # หรือ scheduledstartdate ขึ้นอยู่กับว่าอยาก filter ด้วยอะไร
    start_date=start_date_input,
    end_date=end_date_input
)

st.header("2. ภาพรวมของเสีย")
df_defect_analysis = fetch_data_from_view(
    "vw_defect_analysis",
    date_filter_col="defectdate",
    start_date=start_date_input,
    end_date=end_date_input
)

st.header("3. สรุปการผลิตรายวัน (ตามเครื่องจักร)")
df_prod_agg = fetch_data_from_view(
    "vw_productionlog_aggregated_daily_by_machine_product",
    date_filter_col="productiondate",
    start_date=start_date_input,
    end_date=end_date_input
)


# ============== ส่วนที่ 1: สรุปประสิทธิภาพ Work Order ==============
if not df_wo_summary.empty:
    st.subheader("ภาพรวมสถานะ Work Order")
    wo_status_counts = df_wo_summary['workorderstatus'].value_counts().reset_index()
    wo_status_counts.columns = ['สถานะ Work Order', 'จำนวน']
    fig_wo_status = px.bar(wo_status_counts, x='สถานะ Work Order', y='จำนวน', title="จำนวน Work Order ตามสถานะ")
    st.plotly_chart(fig_wo_status, use_container_width=True)

    st.subheader("Work Orders ล่าสุด (ที่เริ่มผลิตในช่วงวันที่เลือก)")
    st.dataframe(df_wo_summary[['workorderid', 'productname', 'quantitytoproduce', 'quantityproducedgood', 'actualyield', 'workorderstatus', 'actualstartdate', 'actualenddate']].sort_values(by="actualstartdate", ascending=False).head(10))

    col1, col2 = st.columns(2)
    with col1:
        avg_yield = df_wo_summary['actualyield'].mean() if 'actualyield' in df_wo_summary.columns and df_wo_summary['actualyield'].notna().any() else 0
        st.metric("Yield เฉลี่ยของ Work Orders", f"{avg_yield:.2%}" if avg_yield else "N/A")
    with col2:
        on_time_wos = df_wo_summary['isontime'].sum() if 'isontime' in df_wo_summary.columns else 0
        total_completed_wos = df_wo_summary[df_wo_summary['workorderstatus'].isin(['Completed', 'Partially_Completed_LowYield'])].shape[0]
        on_time_percentage = (on_time_wos / total_completed_wos * 100) if total_completed_wos > 0 else 0
        st.metric("Work Orders ที่เสร็จตรงเวลา", f"{on_time_percentage:.1f}%" if total_completed_wos > 0 else "N/A")

else:
    st.warning("ไม่พบข้อมูล Work Order ในช่วงวันที่ที่เลือก")

st.markdown("---")
# ============== ส่วนที่ 2: ภาพรวมของเสีย ==============
if not df_defect_analysis.empty:
    st.subheader("ประเภทของเสียที่พบบ่อยที่สุด (Top 5)")
    top_defects = df_defect_analysis['defectdescription'].value_counts().nlargest(5).reset_index()
    top_defects.columns = ['รายละเอียดของเสีย', 'จำนวนครั้งที่พบ']
    fig_top_defects = px.bar(top_defects, x='รายละเอียดของเสีย', y='จำนวนครั้งที่พบ', title="5 ประเภทของเสียที่พบบ่อยที่สุด")
    st.plotly_chart(fig_top_defects, use_container_width=True)

    st.subheader("จำนวนของเสียตาม Process Area ของเครื่องจักร")
    defects_by_machine_area = df_defect_analysis.groupby('machineprocessarea')['defectinstancequantity'].sum().reset_index()
    defects_by_machine_area.columns = ['Process Area เครื่องจักร', 'จำนวนของเสีย']
    fig_defects_area = px.pie(defects_by_machine_area, values='จำนวนของเสีย', names='Process Area เครื่องจักร', title="สัดส่วนของเสียตาม Process Area ของเครื่องจักร")
    st.plotly_chart(fig_defects_area, use_container_width=True)

else:
    st.warning("ไม่พบข้อมูลของเสียในช่วงวันที่ที่เลือก")

st.markdown("---")
# ============== ส่วนที่ 3: สรุปการผลิตรายวัน ==============
if not df_prod_agg.empty:
    st.subheader("แนวโน้มการผลิตรวม (Good vs. Defect) รายวัน")
    daily_prod_sum = df_prod_agg.groupby('productiondate').agg(
        TotalGood=('totaloutputgoodquantity', 'sum'),
        TotalDefect=('totaloutputdefectquantity', 'sum')
    ).reset_index()
    daily_prod_sum['productiondate'] = pd.to_datetime(daily_prod_sum['productiondate']) # Convert to datetime if not already

    fig_daily_prod = px.line(daily_prod_sum, x='productiondate', y=['TotalGood', 'TotalDefect'],
                             title="ปริมาณการผลิต (ดี vs เสีย) รายวัน", labels={'value':'จำนวน', 'variable':'ประเภท'})
    st.plotly_chart(fig_daily_prod, use_container_width=True)


    st.subheader("ปริมาณการผลิตตามเครื่องจักร (Good Units)")
    prod_by_machine = df_prod_agg.groupby('machinename')['totaloutputgoodquantity'].sum().sort_values(ascending=False).reset_index()
    prod_by_machine.columns = ['ชื่อเครื่องจักร', 'จำนวนที่ผลิตได้ (ดี)']
    fig_prod_machine = px.bar(prod_by_machine.head(10), x='ชื่อเครื่องจักร', y='จำนวนที่ผลิตได้ (ดี)', title="เครื่องจักรที่ผลิตสินค้าดีได้มากที่สุด (Top 10)")
    st.plotly_chart(fig_prod_machine, use_container_width=True)
else:
    st.warning("ไม่พบข้อมูลสรุปการผลิตรายวันในช่วงวันที่ที่เลือก")

st.sidebar.markdown("---")
st.sidebar.info("Dashboard นี้สร้างขึ้นเพื่อแสดงภาพรวมข้อมูลจากระบบ MES/ERP จำลอง")