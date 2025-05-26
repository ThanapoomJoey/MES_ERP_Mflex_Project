import psycopg2
import random
from datetime import datetime, timedelta, date
from decimal import Decimal # เพิ่มบรรทัดนี้ ถ้ายังไม่มี

# ============== การตั้งค่าการเชื่อมต่อฐานข้อมูล ==============
DB_HOST = "localhost"
DB_NAME = "mflex_mes_erp_sim"
DB_USER = "admin"
DB_PASSWORD = "admin123"
DB_PORT = "5432"
DB_SCHEMA = "public"

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

def execute_query(query, params=None, fetch_one=False, fetch_all=False, commit=False):
    conn = None
    cursor = None
    result = None
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            if fetch_one:
                result = cursor.fetchone()
            elif fetch_all:
                result = cursor.fetchall()
            if commit:
                conn.commit()
    except psycopg2.Error as e:
        print(f"เกิดข้อผิดพลาดในการ Query: {query[:100]}... Error: {e}") # แสดง Query ที่ error ด้วย
        if conn and commit:
            conn.rollback()
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
    return result

# ============== ดึงข้อมูล Master Data ที่จำเป็น ==============
def get_master_data():
    master_data = {}
    master_data['customers'] = execute_query(f"SELECT CustomerID FROM {DB_SCHEMA}.Customers;", fetch_all=True)
    master_data['products_fg'] = execute_query(f"SELECT ProductID, ProductName, SalesUnitPrice, StandardCycleTime_Seconds, TargetYield FROM {DB_SCHEMA}.Products WHERE ProductType IN ('FPC', 'Assembled_FPC', 'Module');", fetch_all=True)
    master_data['machines'] = execute_query(f"SELECT MachineID, ProcessArea FROM {DB_SCHEMA}.Machines;", fetch_all=True)
    master_data['operators'] = execute_query(f"SELECT OperatorID FROM {DB_SCHEMA}.Operators;", fetch_all=True)
    master_data['defect_codes'] = {}
    defect_data = execute_query(f"SELECT DefectCodeID, ProcessAreaAffected FROM {DB_SCHEMA}.DefectCodes;", fetch_all=True)
    if defect_data:
        for dc_id, area in defect_data:
            area_key = area if area else 'General' # Handle NULL ProcessAreaAffected
            if area_key not in master_data['defect_codes']:
                master_data['defect_codes'][area_key] = []
            master_data['defect_codes'][area_key].append(dc_id)
            
    master_data['boms'] = {}
    bom_data = execute_query(f"SELECT Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent FROM {DB_SCHEMA}.BillOfMaterials ORDER BY Parent_ProductID_FK;", fetch_all=True)
    if bom_data:
        for parent_pid, comp_mid, qty in bom_data:
            if parent_pid not in master_data['boms']:
                master_data['boms'][parent_pid] = []
            master_data['boms'][parent_pid].append({'component_id': comp_mid, 'quantity': float(qty)})

    master_data['routings'] = {
        'FPC_SL_PI18': ['LAMINATE01', 'ETCH01', 'AOI_FPC01', 'TEST_E_FPC01'],
        'FPC_DL_PI35': ['LAMINATE01', 'ETCH01', 'DRILL_LASER01', 'AOI_FPC01', 'TEST_E_FPC01'],
        'FPC_ML4_MPI12': ['LAMINATE01', 'ETCH01', 'DRILL_LASER01', 'AOI_FPC01', 'TEST_E_FPC01'],
        'FPC_SL_LCP9_HF': ['LAMINATE01', 'ETCH01', 'AOI_FPC01', 'TEST_E_FPC01'],
        'ASSY01_FPC_SL_PI18': ['SMT_LINE1_PLACE', 'SMT_LINE1_REFLOW', 'AOI_ASSY01', 'TEST_FUNC_ASSY01'],
        'ASSY02_FPC_ML4_MPI12': ['SMT_LINE1_PLACE', 'BOND_ACF01','SMT_LINE1_REFLOW', 'AOI_ASSY01', 'TEST_FUNC_ASSY01'], # เพิ่ม Reflow หลัง Bond
        'MODULE_SENSOR_A': ['SMT_LINE1_PLACE','SMT_LINE1_REFLOW', 'AOI_ASSY01','TEST_FUNC_ASSY01'] # สมมติ Module มี SMT และ Test
    }
    print("Master Data Loaded.")
    return master_data

# ============== ส่วนที่ 1: สร้าง Sales Order (จำลอง) - ปรับปรุง QuantityOrdered ==============
def create_sales_order(customer_id, products_fg, simulated_current_time):
    sales_order_id = f"SO-{simulated_current_time.strftime('%Y%m%d%H%M%S')}-{random.randint(100,999)}"
    order_date = simulated_current_time
    required_delivery_date = order_date + timedelta(days=random.randint(10, 45)) # ขยายช่วง delivery
    order_status = 'Pending'
    
    so_query = f"INSERT INTO {DB_SCHEMA}.SalesOrders (SalesOrderID, CustomerID_FK, OrderDate, RequiredDeliveryDate, OrderStatus) VALUES (%s, %s, %s, %s, %s) RETURNING SalesOrderID;"
    inserted_so_id_tuple = execute_query(so_query, (sales_order_id, customer_id, order_date, required_delivery_date, order_status), fetch_one=True, commit=True)
    
    if not inserted_so_id_tuple:
        # print(f"ไม่สามารถสร้าง Sales Order: {sales_order_id}")
        return None
    
    sales_order_id = inserted_so_id_tuple[0]
    # print(f"สร้าง Sales Order: {sales_order_id} สำหรับลูกค้า: {customer_id} ณ วันที่: {order_date.strftime('%Y-%m-%d')}")

    num_lines = random.randint(1, 3)
    total_order_amount = 0
    
    for _ in range(num_lines):
        product_info = random.choice(products_fg)
        product_id = product_info[0]
        unit_price = float(product_info[2])
        
        # --- ปรับการสุ่ม QuantityOrdered ---
        if random.random() < 0.7: # 70% โอกาสเป็น Low Volume
            quantity_ordered = random.randint(50, 500)
        else: # 30% โอกาสเป็น High Volume
            quantity_ordered = random.randint(1000, 10000)
        # --- สิ้นสุดการปรับ ---
        
        sol_query = f"INSERT INTO {DB_SCHEMA}.SalesOrderLines (SalesOrderID_FK, ProductID_FK, QuantityOrdered, UnitPrice, LineStatus) VALUES (%s, %s, %s, %s, %s) RETURNING SalesOrderLineID;"
        inserted_sol_id_tuple = execute_query(sol_query, (sales_order_id, product_id, quantity_ordered, unit_price, 'Open'), fetch_one=True, commit=True)
        
        if inserted_sol_id_tuple:
            # print(f"  - เพิ่มรายการสินค้า: {product_id}, จำนวน: {quantity_ordered}")
            total_order_amount += quantity_ordered * unit_price

    if total_order_amount > 0:
        update_so_total_query = f"UPDATE {DB_SCHEMA}.SalesOrders SET TotalAmount = %s WHERE SalesOrderID = %s;"
        execute_query(update_so_total_query, (total_order_amount, sales_order_id), commit=True)
        
    return sales_order_id

# ============== ส่วนที่ 2: สร้าง Work Orders (เหมือนเดิม Logic หลัก) ==============
def create_work_orders_from_sales_orders(master_data, simulated_current_time):
    open_sales_order_lines_query = f"""
        SELECT sol.SalesOrderLineID, sol.ProductID_FK, sol.QuantityOrdered, so.OrderDate 
        FROM {DB_SCHEMA}.SalesOrderLines sol 
        JOIN {DB_SCHEMA}.SalesOrders so ON sol.SalesOrderID_FK = so.SalesOrderID 
        WHERE sol.LineStatus = 'Open' AND so.OrderDate <= %s;
    """
    open_lines = execute_query(open_sales_order_lines_query, (simulated_current_time,), fetch_all=True)
    
    if not open_lines:
        return

    for sol_id, product_id, qty_ordered, order_date_db in open_lines:
        if product_id not in master_data['boms'] and product_id not in master_data['routings']:
             continue

        work_order_id = f"WO-{simulated_current_time.strftime('%y%m%d%H%M%S')}-{random.randint(100,999)}"
        
        if isinstance(order_date_db, str):
            order_date_obj_from_db = datetime.fromisoformat(order_date_db)
        else:
            order_date_obj_from_db = order_date_db

        buffer_days = random.randint(3,7) # เพิ่ม buffer day เล็กน้อย
        production_lead_time_days = 7 + int(qty_ordered / 1000) # Lead time เพิ่มขึ้นตามจำนวนสั่งผลิต (คร่าวๆ)
        
        scheduled_start_date = order_date_obj_from_db + timedelta(days=buffer_days)
        scheduled_end_date = scheduled_start_date + timedelta(days=production_lead_time_days)
        batch_id_assigned = work_order_id

        wo_query = f"INSERT INTO {DB_SCHEMA}.WorkOrders (WorkOrderID, SalesOrderLineID_FK, ProductID_FK, QuantityToProduce, ScheduledStartDate, ScheduledEndDate, WorkOrderStatus, BatchID_Assigned) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);"
        execute_query(wo_query, (work_order_id, sol_id, product_id, qty_ordered, scheduled_start_date, scheduled_end_date, 'Planned', batch_id_assigned), commit=True)
        
        update_sol_status_query = f"UPDATE {DB_SCHEMA}.SalesOrderLines SET LineStatus = 'Processing' WHERE SalesOrderLineID = %s;"
        execute_query(update_sol_status_query, (sol_id,), commit=True)
        # print(f"สร้าง Work Order: {work_order_id} สำหรับสินค้า: {product_id} จาก SOL_ID: {sol_id}")

# ============== ส่วนที่ 3: ปล่อย Work Order (เหมือนเดิม Logic หลัก) ==============
def release_work_orders_to_mes(simulated_current_time):
    release_wo_query = f"UPDATE {DB_SCHEMA}.WorkOrders SET WorkOrderStatus = 'Released' WHERE WorkOrderStatus = 'Planned' AND ScheduledStartDate <= %s;"
    planned_wos_to_release_query = f"SELECT WorkOrderID FROM {DB_SCHEMA}.WorkOrders WHERE WorkOrderStatus = 'Planned' AND ScheduledStartDate <= %s;"
    planned_wos = execute_query(planned_wos_to_release_query, (simulated_current_time,), fetch_all=True)
    
    if planned_wos:
        execute_query(release_wo_query, (simulated_current_time,), commit=True)
        # print(f"ปล่อย Work Orders จำนวน {len(planned_wos)} รายการเข้าสู่ MES ณ วันที่จำลอง: {simulated_current_time.strftime('%Y-%m-%d')}")

# ============== ส่วนที่ 4: ดำเนินการผลิตใน MES - ปรับปรุง Yield และ Machine Down ==============
def simulate_mes_production(master_data, base_simulated_time_for_wo_start):
    released_wos_query = f"SELECT WorkOrderID, ProductID_FK, QuantityToProduce, BatchID_Assigned, ActualStartDate FROM {DB_SCHEMA}.WorkOrders WHERE WorkOrderStatus = 'Released';"
    wos_to_produce = execute_query(released_wos_query, fetch_all=True)

    if not wos_to_produce:
        return

    for wo_id, product_id, qty_to_produce, batch_id, actual_start_date_db in wos_to_produce:
        current_production_time = actual_start_date_db 
        if current_production_time is None:
            current_production_time = base_simulated_time_for_wo_start + timedelta(minutes=random.randint(0, 59*2), seconds=random.randint(0,59)) # เพิ่มช่วงเวลาสุ่มเริ่มผลิต
            execute_query(f"UPDATE {DB_SCHEMA}.WorkOrders SET WorkOrderStatus = 'In Progress', ActualStartDate = %s WHERE WorkOrderID = %s;", (current_production_time, wo_id), commit=True)
        else:
             execute_query(f"UPDATE {DB_SCHEMA}.WorkOrders SET WorkOrderStatus = 'In Progress' WHERE WorkOrderID = %s AND WorkOrderStatus = 'Released';", (wo_id,), commit=True)

        total_produced_good_for_wo_run = 0
        total_scrapped_for_wo_run = 0
        
        if product_id not in master_data['routings']:
            execute_query(f"UPDATE {DB_SCHEMA}.WorkOrders SET WorkOrderStatus = 'Error_NoRouting', Notes = 'No routing defined for product' WHERE WorkOrderID = %s;", (wo_id,), commit=True)
            continue

        routing_steps = master_data['routings'][product_id]
        current_good_qty_in_process = qty_to_produce

        for i, machine_id in enumerate(routing_steps):
            if current_good_qty_in_process <= 0:
                break

            operator_id = random.choice(master_data['operators'])[0] if master_data['operators'] else None
            
            product_details = next((p for p in master_data['products_fg'] if p[0] == product_id), None)
            cycle_time_per_unit = product_details[3] if product_details and product_details[3] else 60
            
            # ทำให้ cycle time สมจริงขึ้นสำหรับ high volume (อาจจะสั้นลง)
            effective_cycle_time = cycle_time_per_unit
            if qty_to_produce > 1000 and cycle_time_per_unit > 10: # ถ้า high volume และ cycle time ไม่ได้สั้นมากอยู่แล้ว
                effective_cycle_time = cycle_time_per_unit * random.uniform(0.7, 0.9) # ลด cycle time ลง

            time_at_station_seconds = int(current_good_qty_in_process * effective_cycle_time * random.uniform(0.85, 1.15)) # แกว่งเวลามากขึ้นเล็กน้อย
            current_production_time += timedelta(seconds=time_at_station_seconds)

            # --- ดึง TargetYield และแปลงเป็น float ---
            target_yield_decimal = product_details[4] if product_details and product_details[4] else decimal.Decimal('0.95') # default 95%
            target_yield_float = float(target_yield_decimal) # แปลงเป็น float ตรงนี้
            # --- สิ้นสุดการแก้ไข ---
            
            # --- ปรับการสุ่ม Yield ---
            # --- ใช้ target_yield_float ในการคำนวณ ---
            actual_yield_at_station = max(0.80, min(0.998, random.normalvariate(target_yield_float, 0.02)))
            # --- สิ้นสุดการแก้ไข ---
            # --- สิ้นสุดการปรับ ---
            
            output_good = int(current_good_qty_in_process * actual_yield_at_station)
            output_defect = current_good_qty_in_process - output_good
            
            machine_status = 'RUNNING'
            # --- ปรับความถี่ Machine Down ---
            if random.random() < 0.015: # 1.5% โอกาสที่เครื่องจะ Down
                machine_status = 'DOWN'
                downtime_seconds = random.randint(300, 3600) # สุ่ม Down 5 นาที - 1 ชั่วโมง
                current_production_time += timedelta(seconds=downtime_seconds) # เพิ่มเวลา Down เข้าไป
            # --- สิ้นสุดการปรับ ---

            prod_log_query = f"INSERT INTO {DB_SCHEMA}.ProductionLog (Timestamp, WorkOrderID_FK, ProductID_FK, MachineID_FK, OperatorID_FK, InputQuantity, OutputGoodQuantity, OutputDefectQuantity, MachineStatus) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING LogID;"
            log_id_tuple = execute_query(prod_log_query, (current_production_time, wo_id, product_id, machine_id, operator_id, current_good_qty_in_process, output_good, output_defect, machine_status), fetch_one=True, commit=True)
            
            # print(f"  - MES Log: WO={wo_id}, Mch={machine_id}, In={current_good_qty_in_process}, Good={output_good}, Def={output_defect}, TS={current_production_time.strftime('%H:%M')}")

            if i == len(routing_steps) - 1:
                total_produced_good_for_wo_run = output_good
            total_scrapped_for_wo_run += output_defect

            if output_defect > 0 and log_id_tuple:
                production_log_id = log_id_tuple[0]
                machine_info = next((m for m in master_data['machines'] if m[0] == machine_id), None)
                process_area_for_defect = machine_info[1] if machine_info else 'General'
                
                possible_defects = master_data['defect_codes'].get(process_area_for_defect, master_data['defect_codes'].get('General', []))
                if not possible_defects and any(master_data['defect_codes'].values()):
                    possible_defects = list(random.choice(list(master_data['defect_codes'].values())))

                for _ in range(output_defect):
                    if possible_defects:
                        defect_code_id = random.choice(possible_defects)
                        defect_log_query = f"INSERT INTO {DB_SCHEMA}.DefectLog (ProductionLogID_FK, DefectCodeID_FK, DefectInstanceQuantity, DefectTimestamp) VALUES (%s, %s, %s, %s);"
                        execute_query(defect_log_query, (production_log_id, defect_code_id, 1, current_production_time), commit=True)
            current_good_qty_in_process = output_good

        final_good_qty = total_produced_good_for_wo_run
        final_scrapped_qty = total_scrapped_for_wo_run
        wo_status_final = 'Completed'
        if qty_to_produce > 0 and final_good_qty < (qty_to_produce * 0.5): # ถ้าผลิตได้ดีน้อยกว่า 50% ของเป้า
             wo_status_final = 'Partially_Completed_LowYield'
        elif final_good_qty == 0 and qty_to_produce > 0 :
            wo_status_final = 'Failed'
        
        update_wo_final_query = f"UPDATE {DB_SCHEMA}.WorkOrders SET WorkOrderStatus = %s, ActualEndDate = %s, QuantityProducedGood = %s, QuantityScrapped = %s WHERE WorkOrderID = %s;"
        execute_query(update_wo_final_query, (wo_status_final, current_production_time, final_good_qty, final_scrapped_qty, wo_id), commit=True)

        if final_good_qty > 0:
            # อัปเดต Inventory (เหมือนเดิม)
            check_inv_query = f"SELECT QuantityOnHand FROM {DB_SCHEMA}.Inventory WHERE InventoryItemID = %s;"
            current_inv = execute_query(check_inv_query, (product_id,), fetch_one=True)
            if current_inv is not None:
                update_inv_query = f"UPDATE {DB_SCHEMA}.Inventory SET QuantityOnHand = QuantityOnHand + %s WHERE InventoryItemID = %s;"
                execute_query(update_inv_query, (final_good_qty, product_id), commit=True)
            else:
                product_type_info = execute_query(f"SELECT ProductType, ProductName FROM {DB_SCHEMA}.Products WHERE ProductID = %s;", (product_id,), fetch_one=True)
                item_type_inv = product_type_info[0] if product_type_info else 'FinishedGood'
                item_desc_inv = product_type_info[1] if product_type_info else product_id
                insert_inv_query = f"INSERT INTO {DB_SCHEMA}.Inventory (InventoryItemID, ItemDescription, ItemType, QuantityOnHand) VALUES (%s, %s, %s, %s);"
                execute_query(insert_inv_query, (product_id, item_desc_inv, f"FinishedGood_{item_type_inv}", final_good_qty), commit=True)
            # print(f"  อัปเดต Inventory สำหรับ {product_id}, เพิ่ม: {final_good_qty}")

# ============== ส่วนที่ 5: อัปเดตสถานะ Sales Order (เหมือนเดิม Logic หลัก) ==============
def update_sales_order_fulfillment():
    query = f"""
        SELECT sol.SalesOrderLineID, sol.SalesOrderID_FK, wo.QuantityProducedGood, sol.QuantityOrdered, so.OrderStatus
        FROM {DB_SCHEMA}.SalesOrderLines sol
        JOIN {DB_SCHEMA}.WorkOrders wo ON sol.SalesOrderLineID = wo.SalesOrderLineID_FK
        JOIN {DB_SCHEMA}.SalesOrders so ON sol.SalesOrderID_FK = so.SalesOrderID
        WHERE wo.WorkOrderStatus IN ('Completed', 'Partially_Completed_LowYield') AND sol.LineStatus = 'Processing'
          AND wo.QuantityProducedGood > 0; 
    """
    lines_to_update = execute_query(query, fetch_all=True)

    if not lines_to_update:
        return

    updated_so_ids = set() # เก็บ SalesOrderID ที่มีการอัปเดต Line

    for sol_id, so_id, qty_produced, qty_ordered, current_so_status in lines_to_update:
        # สมมติว่าถ้าผลิตได้บ้าง ก็ถือว่าพร้อมส่งส่วนนั้น (Partial Shipment Logic)
        # ในที่นี้ จะเปลี่ยน LineStatus เป็น Shipped ถ้า QuantityProducedGood >= QuantityOrdered
        # หรือเป็น Partially_Shipped ถ้า QuantityProducedGood < QuantityOrdered แต่ > 0
        
        new_line_status = 'Shipped' # Default
        if qty_produced < qty_ordered:
            new_line_status = 'Partially_Shipped' # หรืออาจจะยังคงเป็น Processing จนกว่าจะครบ

        # เพื่อความง่าย จะเปลี่ยนเป็น Shipped ถ้าผลิตได้ดี
        # ในระบบจริง อาจจะต้องมี Logic การ Allocate Inventory ที่ผลิตได้ให้กับ SO Line
        if qty_produced >= qty_ordered :
             new_line_status = 'Shipped'
        elif qty_produced > 0:
             new_line_status = 'Partially_Shipped' #ถ้าผลิตได้บางส่วน
        else: #ผลิตไม่ได้เลย
             new_line_status = 'Backordered' # หรือ Failed_Production


        update_sol_query = f"UPDATE {DB_SCHEMA}.SalesOrderLines SET LineStatus = %s WHERE SalesOrderLineID = %s;"
        execute_query(update_sol_query, (new_line_status, sol_id,), commit=True)
        # print(f"Sales Order Line ID: {sol_id} (ของ SO: {so_id}) เปลี่ยนสถานะเป็น '{new_line_status}'")
        updated_so_ids.add(so_id)

    # ตรวจสอบสถานะ SalesOrder โดยรวมหลังจากอัปเดต Lines
    for so_id_to_check in updated_so_ids:
        check_all_lines_shipped_query = f"SELECT COUNT(*) FROM {DB_SCHEMA}.SalesOrderLines WHERE SalesOrderID_FK = %s AND LineStatus NOT IN ('Shipped', 'Cancelled');"
        remaining_lines_count_tuple = execute_query(check_all_lines_shipped_query, (so_id_to_check,), fetch_one=True)
        
        new_so_status = None
        if remaining_lines_count_tuple and remaining_lines_count_tuple[0] == 0:
            new_so_status = 'Shipped'
        else:
            # ตรวจสอบว่ามี Line ไหน Partially Shipped หรือยัง Processing อยู่หรือไม่
            check_partial_processing_q = f"SELECT EXISTS (SELECT 1 FROM {DB_SCHEMA}.SalesOrderLines WHERE SalesOrderID_FK = %s AND LineStatus IN ('Partially_Shipped', 'Processing', 'Backordered'));"
            has_partial_or_processing = execute_query(check_partial_processing_q, (so_id_to_check,), fetch_one=True)
            if has_partial_or_processing and has_partial_or_processing[0]:
                # ตรวจสอบสถานะ SO ปัจจุบันก่อน ถ้าเป็น Pending หรือ Confirmed ถึงเปลี่ยนเป็น Partially Shipped
                current_so_status_q = f"SELECT OrderStatus FROM {DB_SCHEMA}.SalesOrders WHERE SalesOrderID = %s;"
                current_so_status_tuple = execute_query(current_so_status_q, (so_id_to_check,), fetch_one=True)
                if current_so_status_tuple and current_so_status_tuple[0] in ['Pending', 'Confirmed', 'Processing']:
                    new_so_status = 'Partially Shipped'
        
        if new_so_status:
            update_so_query = f"UPDATE {DB_SCHEMA}.SalesOrders SET OrderStatus = %s WHERE SalesOrderID = %s;"
            execute_query(update_so_query, (new_so_status, so_id_to_check,), commit=True)
            # print(f"Sales Order ID: {so_id_to_check} เปลี่ยนสถานะเป็น '{new_so_status}'")


# ============== Main Simulation Loop (เหมือนเดิม Logic หลัก) ==============
def run_simulation_over_period(start_date_str, simulation_days, orders_per_day_avg):
    print(f"===== เริ่มต้นการจำลองระบบ ERP-MES สำหรับช่วงเวลา {simulation_days} วัน =====")
    master_data = get_master_data()

    if not master_data['customers'] or not master_data['products_fg']:
        print("ข้อมูล Master Customers หรือ Products ไม่เพียงพอ, หยุดการจำลอง")
        return

    try:
        simulation_start_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
    except ValueError:
        print("รูปแบบวันที่เริ่มต้นไม่ถูกต้อง กรุณาใช้ YYYY-MM-DD")
        return

    for day_offset in range(simulation_days):
        current_sim_date = simulation_start_date + timedelta(days=day_offset)
        print(f"\n===== วันที่จำลอง: {current_sim_date.strftime('%Y-%m-%d')} =====")

        num_so_today = max(0, int(random.normalvariate(orders_per_day_avg, max(1, orders_per_day_avg / 3)))) # ป้องกัน std dev เป็น 0
        print(f"  [วันนี้จะสร้าง Sales Orders ประมาณ: {num_so_today} รายการ]")

        for i in range(num_so_today):
            simulated_order_time = datetime.combine(current_sim_date, datetime.min.time()) + \
                                   timedelta(hours=random.randint(8, 16), 
                                             minutes=random.randint(0,59), 
                                             seconds=random.randint(0,59))
            
            customer_id = random.choice(master_data['customers'])[0]
            created_so_id = create_sales_order(customer_id, master_data['products_fg'], simulated_order_time)
        
        processing_sim_time_today = datetime.combine(current_sim_date, datetime.min.time()) + timedelta(hours=random.randint(17, 18)) # สุ่มเวลาประมวลผลเล็กน้อย

        create_work_orders_from_sales_orders(master_data, processing_sim_time_today)
        release_work_orders_to_mes(processing_sim_time_today)
        simulate_mes_production(master_data, processing_sim_time_today)
        update_sales_order_fulfillment()

    print("\n===== สิ้นสุดการจำลองระบบ ERP-MES =====")


if __name__ == "__main__":
    start_simulation_date_str = (date.today() - timedelta(days=180)).strftime("%Y-%m-%d")
    days_to_simulate = 180 
    avg_orders_per_day = 3 # <<< ปรับค่านี้เพื่อควบคุมจำนวนข้อมูลโดยรวม

    print(f"จะเริ่มจำลองข้อมูลตั้งแต่: {start_simulation_date_str} เป็นเวลา {days_to_simulate} วัน, เฉลี่ย {avg_orders_per_day} SOs/วัน")
    
    # --- คำแนะนำ: ก่อนรันเพื่อสร้างข้อมูลชุดใหญ่ ให้ลองรันด้วยจำนวนวันน้อยๆ และ orders_per_day น้อยๆ ก่อน ---
    # --- เพื่อทดสอบว่า Logic ทั้งหมดทำงานถูกต้อง และไม่เกิด Error ที่ไม่คาดคิด ---
    # --- เช่น run_simulation_over_period(start_date_str, 5, 1) ---

    # --- ถ้าต้องการล้างข้อมูล Transaction เก่าก่อนรัน (ทำด้วยความระมัดระวัง) ---
    # print("!!! คำเตือน: กำลังจะล้างข้อมูล Transaction เก่าใน 10 วินาที กด Ctrl+C เพื่อยกเลิก !!!")
    # import time
    # time.sleep(10)
    # print("กำลังล้างข้อมูล Transaction...")
    # tables_to_truncate_transaction = ["DefectLog", "ProductionLog", "WorkOrders", "SalesOrderLines", "SalesOrders"]
    # for table in tables_to_truncate_transaction:
    #     try:
    #         # การ TRUNCATE ที่มี FK อาจจะต้องทำ CASCADE หรือจัดการลำดับ
    #         # เพื่อความง่าย อาจจะใช้ DELETE ก่อน แล้วค่อยจัดการเรื่อง Sequence ถ้าจำเป็น
    #         execute_query(f"DELETE FROM {DB_SCHEMA}.{table};", commit=True)
    #         # สำหรับ PostgreSQL ถ้าต้องการ Reset IDENTITY/SERIAL columns:
    #         # if table in ["DefectLog", "ProductionLog", "WorkOrders", "SalesOrderLines", "BillOfMaterials"]: # ตารางที่มี SERIAL
    #         #     execute_query(f"ALTER SEQUENCE {DB_SCHEMA}.{table.lower()}_{table.replace('Lines','line').replace('Orders','order').lower() if table != 'BillOfMaterials' else 'bom'}_id_seq RESTART WITH 1;", commit=True)
    #         #     # หมายเหตุ: ชื่อ Sequence อาจจะต้องตรวจสอบให้ถูกต้องตามที่ PostgreSQL สร้างขึ้น
    #         print(f"ข้อมูลในตาราง {table} ถูกล้างแล้ว")
    #     except Exception as e:
    #         print(f"เกิดปัญหาในการล้างตาราง {table}: {e}")

    # print("กำลัง Reset Inventory...")
    # # Reset Inventory (ควรจะซับซ้อนกว่านี้ คือกลับไปเป็นค่า Master Data เริ่มต้น)
    # # ลบ Inventory เก่า แล้ว Insert ใหม่จาก Master Data
    # execute_query(f"DELETE FROM {DB_SCHEMA}.Inventory;", commit=True)
    # # (จากนั้นรันส่วน Insert Inventory จาก Master Data ที่อยู่ใน Script สร้างตารางอีกครั้ง หรือทำ Function แยก)
    # print("Inventory ถูก Reset (เบื้องต้น).")
    # --- จบส่วนล้างข้อมูล ---

    run_simulation_over_period(
        start_date_str=start_simulation_date_str,
        simulation_days=days_to_simulate,
        orders_per_day_avg=avg_orders_per_day
    )