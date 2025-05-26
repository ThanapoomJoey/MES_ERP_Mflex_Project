**ตารางที่มีข้อมูลแล้ว (Master Data):**

1.  **`Customers`**: มีข้อมูลลูกค้า 5 ราย
2.  **`Products`**: มีข้อมูลผลิตภัณฑ์หลักๆ 7 ประเภท (FPC, Assembled FPC, Module)
3.  **`Materials`**:
    *   มีข้อมูลวัตถุดิบ, ชิ้นส่วน, วัสดุสิ้นเปลือง (Raw Materials, Components, Consumables) ประมาณ 17 รายการ (รวม `MAT_PLASTIC_HOUSING_A`)
    *   มีข้อมูล Sub-Assemblies (ที่ดึงมาจาก `Products`) อีก 5 รายการ (`FPC_SL_PI18`, `FPC_DL_PI35`, `FPC_ML4_MPI12`, `FPC_SL_LCP9_HF`, `ASSY01_FPC_SL_PI18`)
    *   รวมแล้วในตาราง `Materials` จะมีข้อมูลประมาณ 22 รายการ
4.  **`BillOfMaterials` (BOM)**: มีข้อมูล BOM สำหรับผลิตภัณฑ์ 5 ตัว (`FPC_SL_PI18`, `FPC_DL_PI35`, `ASSY01_FPC_SL_PI18`, `ASSY02_FPC_ML4_MPI12`, `MODULE_SENSOR_A`) โดยแต่ละ BOM มีส่วนประกอบหลายรายการ
5.  **`Inventory`**:
    *   มีข้อมูล Stock เริ่มต้นสำหรับ Raw Materials, Components, และ Consumables (จากตาราง `Materials`)
    *   มีข้อมูล Stock เริ่มต้นสำหรับ Finished Goods/Producible Items (จากตาราง `Products`)
6.  **`Machines`**: มีข้อมูลเครื่องจักร/สถานีงาน 10 เครื่อง
7.  **`DefectCodes`**: มีข้อมูลรหัสสาเหตุของเสีย 15 รหัส
8.  **`Operators`**: มีข้อมูลผู้ปฏิบัติงาน 5 คน

**ตารางที่ยังไม่มีข้อมูล (Transaction Data - จะถูก Populate โดย Script Python จำลองการทำงาน):**

1.  **`SalesOrders`**: ยังไม่มีคำสั่งซื้อจากลูกค้า
2.  **`SalesOrderLines`**: ยังไม่มีรายการสินค้าในคำสั่งซื้อ
3.  **`WorkOrders`**: ยังไม่มีคำสั่งผลิต
4.  **`ProductionLog`**: ยังไม่มีบันทึกข้อมูลการผลิตจาก MES
5.  **`DefectLog`**: ยังไม่มีบันทึกข้อมูลของเสียโดยละเอียดจาก MES

**สรุป:**

ตอนนี้เรามี "ฉากหลัง" หรือ "ข้อมูลพื้นฐาน" ที่มั่นคงพร้อมแล้วครับ ข้อมูล Master เหล่านี้จะเป็นเหมือน "ตัวละคร" และ "กฎกติกา" ในโรงงานจำลองของเรา

ขั้นตอนต่อไปคือการเขียน Script Python เพื่อสร้าง "เรื่องราว" หรือ "เหตุการณ์" ที่จะเกิดขึ้นในโรงงานนี้ โดยเริ่มจากการจำลองการสร้าง `SalesOrders`, แล้ว Flow ไปสู่การสร้าง `WorkOrders`, การดำเนินการผลิตใน `ProductionLog` และ `DefectLog`, และสุดท้ายคือการอัปเดตสถานะต่างๆ กลับมายังส่วน ERP (เช่น `Inventory`, `WorkOrderStatus`, `SalesOrderStatus`)

