-- #####################################################################
-- # โปรเจกต์: ระบบจำลองการจัดการกระบวนการผลิตแบบครบวงจร               #
-- # Script: สร้างตารางทั้งหมด และเพิ่มข้อมูล Master Data เริ่มต้น       #
-- # ฐานข้อมูล: PostgreSQL                                            #
-- #####################################################################

-- =====================================================================
-- ส่วนที่ 0: สร้างตารางทั้งหมด
-- =====================================================================
-- PRINT 'Creating all tables...'; -- This is just a comment in PostgreSQL

-- ===== ตาราง: Customers (ลูกค้า) =====
CREATE TABLE IF NOT EXISTS Customers (
    CustomerID VARCHAR(50) PRIMARY KEY,
    CustomerName VARCHAR(255) NOT NULL,
    ContactPerson VARCHAR(150),
    Email VARCHAR(255),
    Phone VARCHAR(50),
    Address TEXT
);
-- \echo 'Table Customers checked/created.'; -- REMOVED or COMMENTED OUT

-- ===== ตาราง: Products (ผลิตภัณฑ์ - Finished Goods และอาจรวม Sub-Assemblies ที่ MES ผลิต) =====
CREATE TABLE IF NOT EXISTS Products (
    ProductID VARCHAR(50) PRIMARY KEY,
    ProductName VARCHAR(255) NOT NULL,
    ProductType VARCHAR(100) NOT NULL,
    TargetYield DECIMAL(5, 4) DEFAULT 0.9500,
    StandardCycleTime_Seconds INT,
    FPC_Layers INT,
    FPC_CopperThickness_um INT,
    FPC_Dielectric VARCHAR(100),
    SalesUnitPrice DECIMAL(18, 2) DEFAULT 0.00
);
-- \echo 'Table Products checked/created.'; -- REMOVED or COMMENTED OUT

-- ... (ทำเช่นเดียวกันสำหรับตารางอื่นๆ ทั้งหมด โดยลบ หรือ Comment Out บรรทัด `\echo`) ...

-- ตัวอย่างการ Comment Out:
-- -- \echo 'Table Materials checked/created.';

-- ===== ตาราง: Materials (วัตถุดิบ/ชิ้นส่วน และ Sub-Assemblies) =====
CREATE TABLE IF NOT EXISTS Materials (
    MaterialID VARCHAR(50) PRIMARY KEY,
    MaterialName VARCHAR(255) NOT NULL,
    MaterialType VARCHAR(100),
    UnitOfMeasure VARCHAR(20),
    StandardCost DECIMAL(18, 4) DEFAULT 0.0000
);

-- ===== ตาราง: BillOfMaterials (BOM - รายการวัตถุดิบต่อผลิตภัณฑ์) =====
CREATE TABLE IF NOT EXISTS BillOfMaterials (
    BOM_ID BIGSERIAL PRIMARY KEY,
    Parent_ProductID_FK VARCHAR(50) NOT NULL,
    Component_MaterialID_FK VARCHAR(50) NOT NULL,
    QuantityPerParent DECIMAL(10, 4) NOT NULL,
    BOM_Level INT DEFAULT 1,
    EffectiveDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Version VARCHAR(20) DEFAULT '1.0',
    CONSTRAINT FK_BOM_ParentProduct FOREIGN KEY (Parent_ProductID_FK) REFERENCES Products(ProductID),
    CONSTRAINT FK_BOM_ComponentMaterial FOREIGN KEY (Component_MaterialID_FK) REFERENCES Materials(MaterialID),
    CONSTRAINT UQ_BOM_Parent_Component_Version UNIQUE (Parent_ProductID_FK, Component_MaterialID_FK, Version)
);

-- ===== ตาราง: Inventory (สินค้าคงคลัง - ทั้งวัตถุดิบและสินค้าสำเร็จรูป) =====
CREATE TABLE IF NOT EXISTS Inventory (
    InventoryItemID VARCHAR(50) PRIMARY KEY,
    ItemDescription VARCHAR(255) NOT NULL,
    ItemType VARCHAR(50) NOT NULL,
    QuantityOnHand INT NOT NULL DEFAULT 0,
    QuantityOnOrder INT DEFAULT 0,
    QuantityAllocated INT DEFAULT 0,
    ReorderLevel INT DEFAULT 0,
    LastStocktakeDate TIMESTAMP,
    StorageLocation VARCHAR(100)
);

-- ===== ตาราง: SalesOrders (คำสั่งซื้อจากลูกค้า) =====
CREATE TABLE IF NOT EXISTS SalesOrders (
    SalesOrderID VARCHAR(50) PRIMARY KEY,
    CustomerID_FK VARCHAR(50) NOT NULL,
    OrderDate TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    RequiredDeliveryDate TIMESTAMP,
    OrderStatus VARCHAR(50) NOT NULL DEFAULT 'Pending',
    ShippingAddress TEXT,
    TotalAmount DECIMAL(18, 2) DEFAULT 0.00,
    CONSTRAINT FK_SalesOrders_Customers FOREIGN KEY (CustomerID_FK) REFERENCES Customers(CustomerID)
);

-- ===== ตาราง: SalesOrderLines (รายการสินค้าในคำสั่งซื้อ) =====
CREATE TABLE IF NOT EXISTS SalesOrderLines (
    SalesOrderLineID BIGSERIAL PRIMARY KEY,
    SalesOrderID_FK VARCHAR(50) NOT NULL,
    ProductID_FK VARCHAR(50) NOT NULL,
    QuantityOrdered INT NOT NULL,
    UnitPrice DECIMAL(18, 2) NOT NULL,
    LineTotalAmount DECIMAL(18,2) GENERATED ALWAYS AS (QuantityOrdered * UnitPrice) STORED,
    LineStatus VARCHAR(50) NOT NULL DEFAULT 'Open',
    CONSTRAINT FK_SalesOrderLines_SalesOrders FOREIGN KEY (SalesOrderID_FK) REFERENCES SalesOrders(SalesOrderID),
    CONSTRAINT FK_SalesOrderLines_Products FOREIGN KEY (ProductID_FK) REFERENCES Products(ProductID)
);

-- ===== ตาราง: WorkOrders (คำสั่งผลิต) =====
CREATE TABLE IF NOT EXISTS WorkOrders (
    WorkOrderID VARCHAR(50) PRIMARY KEY,
    SalesOrderLineID_FK BIGINT NULL,
    ProductID_FK VARCHAR(50) NOT NULL,
    QuantityToProduce INT NOT NULL,
    QuantityProducedGood INT DEFAULT 0,
    QuantityScrapped INT DEFAULT 0,
    ScheduledStartDate TIMESTAMP,
    ScheduledEndDate TIMESTAMP,
    ActualStartDate TIMESTAMP,
    ActualEndDate TIMESTAMP,
    WorkOrderStatus VARCHAR(50) NOT NULL DEFAULT 'Planned',
    BatchID_Assigned VARCHAR(100) NULL UNIQUE,
    Notes TEXT,
    CONSTRAINT FK_WorkOrders_SalesOrderLines FOREIGN KEY (SalesOrderLineID_FK) REFERENCES SalesOrderLines(SalesOrderLineID),
    CONSTRAINT FK_WorkOrders_Products FOREIGN KEY (ProductID_FK) REFERENCES Products(ProductID)
);

-- ===== ตาราง: Machines (เครื่องจักร/สถานีงาน) - (MES) =====
CREATE TABLE IF NOT EXISTS Machines (
    MachineID VARCHAR(50) PRIMARY KEY,
    MachineName VARCHAR(255) NOT NULL,
    ProcessArea VARCHAR(100) NOT NULL,
    Location VARCHAR(100),
    Description TEXT
);

-- ===== ตาราง: DefectCodes (รหัสสาเหตุของเสีย) - (MES) =====
CREATE TABLE IF NOT EXISTS DefectCodes (
    DefectCodeID VARCHAR(20) PRIMARY KEY,
    DefectDescription VARCHAR(255) NOT NULL,
    ProcessAreaAffected VARCHAR(100),
    Severity VARCHAR(50)
);

-- ===== ตาราง: Operators (ผู้ปฏิบัติงาน) - (MES) =====
CREATE TABLE IF NOT EXISTS Operators (
    OperatorID VARCHAR(50) PRIMARY KEY,
    OperatorName VARCHAR(150) NOT NULL
);

-- ===== ตาราง: ProductionLog (บันทึกข้อมูลการผลิต MES) =====
CREATE TABLE IF NOT EXISTS ProductionLog (
    LogID BIGSERIAL PRIMARY KEY,
    Timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    WorkOrderID_FK VARCHAR(50) NOT NULL,
    ProductID_FK VARCHAR(50) NOT NULL,
    MachineID_FK VARCHAR(50) NOT NULL,
    OperatorID_FK VARCHAR(50) NULL,
    InputQuantity INT DEFAULT 0,
    OutputGoodQuantity INT NOT NULL DEFAULT 0,
    OutputDefectQuantity INT NOT NULL DEFAULT 0,
    MachineStatus VARCHAR(50),
    ReworkFlag BOOLEAN DEFAULT FALSE,
    Notes TEXT,
    CONSTRAINT FK_ProductionLog_WorkOrders FOREIGN KEY (WorkOrderID_FK) REFERENCES WorkOrders(WorkOrderID),
    CONSTRAINT FK_ProductionLog_Products_MES FOREIGN KEY (ProductID_FK) REFERENCES Products(ProductID),
    CONSTRAINT FK_ProductionLog_Machines_MES FOREIGN KEY (MachineID_FK) REFERENCES Machines(MachineID),
    CONSTRAINT FK_ProductionLog_Operators_MES FOREIGN KEY (OperatorID_FK) REFERENCES Operators(OperatorID)
);

CREATE INDEX IF NOT EXISTS IX_ProductionLog_WorkOrderID ON ProductionLog(WorkOrderID_FK);
CREATE INDEX IF NOT EXISTS IX_ProductionLog_Timestamp_MES ON ProductionLog(Timestamp);

-- ===== ตาราง: DefectLog (บันทึกข้อมูลของเสียโดยละเอียด MES) =====
CREATE TABLE IF NOT EXISTS DefectLog (
    DefectLogID BIGSERIAL PRIMARY KEY,
    ProductionLogID_FK BIGINT NOT NULL,
    DefectCodeID_FK VARCHAR(20) NOT NULL,
    DefectInstanceQuantity INT NOT NULL DEFAULT 1,
    DefectLocation VARCHAR(100),
    DefectTimestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_DefectLog_ProductionLog_MES FOREIGN KEY (ProductionLogID_FK) REFERENCES ProductionLog(LogID),
    CONSTRAINT FK_DefectLog_DefectCodes_MES FOREIGN KEY (DefectCodeID_FK) REFERENCES DefectCodes(DefectCodeID)
);

CREATE INDEX IF NOT EXISTS IX_DefectLog_ProductionLogID_MES ON DefectLog(ProductionLogID_FK);


-- =====================================================================
-- ส่วนที่ 1: การเพิ่มข้อมูล Master Data เริ่มต้น
-- =====================================================================

-- ===== Customers =====
INSERT INTO Customers (CustomerID, CustomerName, ContactPerson, Email, Phone, Address) VALUES
('CUST001', 'Global Tech Solutions', 'Alice Wonderland', 'alice@globaltech.com', '555-0101', '123 Innovation Drive, Tech City'),
('CUST002', 'Future Devices Inc.', 'Bob The Builder', 'bob@futuredevices.com', '555-0102', '456 Silicon Avenue, Gadget Town'),
('CUST003', 'AeroSpace Dynamics', 'Carol Danvers', 'carol@aerodynamics.com', '555-0103', '789 Sky High Rd, Flight Ville'),
('CUST004', 'MediEquip Corp.', 'David Banner', 'david@mediequip.com', '555-0104', '101 Health St, Wellness City'),
('CUST005', 'Automotive Innovations Ltd.', 'Eve Moneypenny', 'eve@autoinnovate.com', '555-0105', '202 Fast Lane, Motorburg');

-- ===== Products (Finished Goods and Produced Sub-Assemblies) =====
INSERT INTO Products (ProductID, ProductName, ProductType, TargetYield, StandardCycleTime_Seconds, FPC_Layers, FPC_CopperThickness_um, FPC_Dielectric, SalesUnitPrice) VALUES
('FPC_SL_PI18', 'FPC Single Layer Polyimide 18um Cu', 'FPC', 0.9850, 120, 1, 18, 'Polyimide', 2.50),
('FPC_DL_PI35', 'FPC Double Layer Polyimide 35um Cu', 'FPC', 0.9780, 200, 2, 35, 'Polyimide', 5.75),
('FPC_ML4_MPI12', 'FPC Multi-Layer (4L) Mod-PI 12um Cu, HDI', 'FPC', 0.9650, 450, 4, 12, 'Modified Polyimide', 15.20),
('FPC_SL_LCP9_HF', 'FPC Single Layer LCP 9um Cu, High-Freq', 'FPC', 0.9800, 150, 1, 9, 'LCP', 8.90),
('ASSY01_FPC_SL_PI18', 'Assembled FPC SL PI18 with SMT 01005', 'Assembled_FPC', 0.9920, 180, NULL, NULL, NULL, 7.80),
('ASSY02_FPC_ML4_MPI12', 'Assembled FPC ML4 MPI12 with Fine Pitch IC (ACF)', 'Assembled_FPC', 0.9880, 300, NULL, NULL, NULL, 25.50),
('MODULE_SENSOR_A', 'Sensor Module with FPC_DL_PI35 & Housing', 'Module', 0.9950, 600, NULL, NULL, NULL, 45.00);

-- ===== Materials (Raw Materials, Components, Consumables) =====
INSERT INTO Materials (MaterialID, MaterialName, MaterialType, UnitOfMeasure, StandardCost) VALUES
('MAT_PI_FILM_25U', 'Polyimide Film 25um', 'RawMaterial', 'Roll (m2)', 10.50),
('MAT_MPI_FILM_20U', 'Modified Polyimide Film 20um', 'RawMaterial', 'Roll (m2)', 12.75),
('MAT_LCP_FILM_30U', 'LCP Film 30um', 'RawMaterial', 'Roll (m2)', 25.00),
('MAT_CU_FOIL_18U', 'Copper Foil RA 18um', 'RawMaterial', 'Roll (m2)', 5.20),
('MAT_CU_FOIL_35U', 'Copper Foil ED 35um', 'RawMaterial', 'Roll (m2)', 7.80),
('MAT_CU_FOIL_12U', 'Copper Foil ED 12um', 'RawMaterial', 'Roll (m2)', 9.50),
('MAT_CU_FOIL_9U', 'Copper Foil RA 9um (for HF)', 'RawMaterial', 'Roll (m2)', 11.50),
('MAT_ADH_ACRYLIC', 'Acrylic Adhesive Sheet', 'RawMaterial', 'Sheet', 2.10),
('MAT_COVERLAY_PI', 'Polyimide Coverlay Film', 'RawMaterial', 'Roll (m2)', 8.50),
('MAT_STIFF_FR4_02', 'FR4 Stiffener 0.2mm', 'RawMaterial', 'Sheet', 1.50),
('COMP_RES_01005_1K', 'Resistor 01005 1K Ohm', 'Component', 'Pieces', 0.0050),
('COMP_CAP_0201_10NF', 'Capacitor 0201 10nF', 'Component', 'Pieces', 0.0080),
('COMP_IC_FINEPITCH_A', 'IC Fine Pitch Type A (for ACF)', 'Component', 'Pieces', 1.2500),
('COMP_CONNECTOR_ZIF', 'ZIF Connector 10pin', 'Component', 'Pieces', 0.1500),
('MAT_SOLDER_PASTE_SAC', 'Solder Paste SAC305', 'Consumable', 'Gram', 0.0200),
('MAT_ACF_FILM', 'Anisotropic Conductive Film (ACF)', 'Consumable', 'Meter', 3.50),
('MAT_PLASTIC_HOUSING_A', 'Plastic Housing Type A', 'Component', 'Pieces', 0.7500);

-- ===== Materials (Sub-Assemblies - from Products table) =====
INSERT INTO Materials (MaterialID, MaterialName, MaterialType, UnitOfMeasure, StandardCost)
SELECT p.ProductID, p.ProductName,
       CASE
           WHEN p.ProductType = 'FPC' THEN 'SubAssembly_FPC'
           WHEN p.ProductType = 'Assembled_FPC' THEN 'SubAssembly_AssembledFPC'
           ELSE 'IntermediateProduct'
       END,
       'Pieces',
       p.SalesUnitPrice * 0.65
FROM Products p
WHERE p.ProductID IN (
    'FPC_SL_PI18', 'FPC_DL_PI35', 'FPC_ML4_MPI12', 'FPC_SL_LCP9_HF',
    'ASSY01_FPC_SL_PI18'
)
ON CONFLICT (MaterialID) DO NOTHING;

-- ===== BillOfMaterials (BOM) =====
INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('FPC_SL_PI18', 'MAT_PI_FILM_25U', 0.0100, '1.0'),
('FPC_SL_PI18', 'MAT_CU_FOIL_18U', 0.0100, '1.0'),
('FPC_SL_PI18', 'MAT_ADH_ACRYLIC', 0.0090, '1.0'),
('FPC_SL_PI18', 'MAT_COVERLAY_PI', 0.0080, '1.0');

INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('FPC_DL_PI35', 'MAT_PI_FILM_25U', 0.0200, '1.0'),
('FPC_DL_PI35', 'MAT_CU_FOIL_35U', 0.0200, '1.0'),
('FPC_DL_PI35', 'MAT_ADH_ACRYLIC', 0.0180, '1.0'),
('FPC_DL_PI35', 'MAT_COVERLAY_PI', 0.0160, '1.0');

INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('ASSY01_FPC_SL_PI18', 'FPC_SL_PI18', 1.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'COMP_RES_01005_1K', 5.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'COMP_CAP_0201_10NF', 2.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'COMP_CONNECTOR_ZIF', 1.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'MAT_SOLDER_PASTE_SAC', 0.5000, '1.0');

INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('ASSY02_FPC_ML4_MPI12', 'FPC_ML4_MPI12', 1.0000, '1.0'),
('ASSY02_FPC_ML4_MPI12', 'COMP_IC_FINEPITCH_A', 1.0000, '1.0'),
('ASSY02_FPC_ML4_MPI12', 'MAT_ACF_FILM', 0.0050, '1.0');

INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('MODULE_SENSOR_A', 'ASSY01_FPC_SL_PI18', 1.0000, '1.0'),
('MODULE_SENSOR_A', 'MAT_PLASTIC_HOUSING_A', 1.0000, '1.0');

-- ===== Inventory (Initial Stock) =====
INSERT INTO Inventory (InventoryItemID, ItemDescription, ItemType, QuantityOnHand, StorageLocation, ReorderLevel)
SELECT MaterialID, MaterialName, MaterialType,
       CASE MaterialType
           WHEN 'RawMaterial' THEN 1000
           WHEN 'Component' THEN 5000
           WHEN 'Consumable' THEN 200
           ELSE 100
       END,
       CASE MaterialType
           WHEN 'RawMaterial' THEN 'Warehouse A - RM'
           WHEN 'Component' THEN 'Warehouse B - Comp'
           ELSE 'Production Store'
       END,
       CASE MaterialType
           WHEN 'RawMaterial' THEN 200
           WHEN 'Component' THEN 1000
           ELSE 50
       END
FROM Materials
WHERE MaterialType NOT LIKE 'SubAssembly%' AND MaterialType <> 'IntermediateProduct'
ON CONFLICT (InventoryItemID) DO NOTHING;

INSERT INTO Inventory (InventoryItemID, ItemDescription, ItemType, QuantityOnHand, StorageLocation, ReorderLevel)
SELECT ProductID, ProductName,
       CASE ProductType
            WHEN 'FPC' THEN 'FinishedGood_FPC'
            WHEN 'Assembled_FPC' THEN 'FinishedGood_AssembledFPC'
            WHEN 'Module' THEN 'FinishedGood_Module'
            ELSE ProductType
       END,
       CASE ProductID
            WHEN 'FPC_SL_PI18' THEN 50
            WHEN 'ASSY01_FPC_SL_PI18' THEN 20
            ELSE 10
       END,
       'Finished Goods Store - Bay 1',
       5
FROM Products
ON CONFLICT (InventoryItemID) DO NOTHING;

-- ===== Machines (MES) =====
INSERT INTO Machines (MachineID, MachineName, ProcessArea, Location, Description) VALUES
('LAMINATE01', 'Lamination Press A', 'FPC_Fabrication', 'Zone 1 Fab', 'Polyimide lamination for FPC base'),
('ETCH01', 'Chemical Etching Line - Alpha', 'FPC_Fabrication', 'Zone 1 Fab', 'Copper etching for circuit patterns'),
('DRILL_LASER01', 'Laser Via Drilling Xylon-5', 'FPC_Fabrication', 'Zone 2 Fab', 'Micro-via and blind/buried via formation'),
('AOI_FPC01', 'AOI for FPC Inspection', 'FPC_Fabrication', 'QA Fab', 'Optical inspection of FPC layers'),
('TEST_E_FPC01', 'FPC Electrical Tester K1', 'FPC_Fabrication', 'QA Fab', 'Final FPC electrical continuity and isolation test'),
('SMT_LINE1_PLACE', 'SMT Placement Fuji AIMEX III - Line 1', 'FPC_Assembly', 'Assembly Line 1', 'High-density SMT component placement'),
('SMT_LINE1_REFLOW', 'Reflow Oven Nitrogen - Line 1', 'FPC_Assembly', 'Assembly Line 1', 'Solder reflow process'),
('BOND_ACF01', 'ACF Bonder - Fine Pitch', 'FPC_Assembly', 'Special Assembly Area', 'Anisotropic Conductive Film bonding for fine pitch ICs'),
('AOI_ASSY01', 'AOI for Assembled Boards - Line 1', 'FPC_Assembly', 'QA Assembly', 'Post-SMT and post-soldering inspection'),
('TEST_FUNC_ASSY01', 'Functional Tester - Assembled Units', 'FPC_Assembly', 'QA Assembly', 'Functional test for assembled FPC/Modules');

-- ===== DefectCodes (MES) =====
INSERT INTO DefectCodes (DefectCodeID, DefectDescription, ProcessAreaAffected, Severity) VALUES
('FPC_ETCH_OPN', 'Open Circuit (Etching)', 'FPC_Fabrication_Etching', 'Critical'),
('FPC_ETCH_SHT', 'Short Circuit (Etching)', 'FPC_Fabrication_Etching', 'Critical'),
('FPC_DRILL_MSA', 'Misaligned Via', 'FPC_Fabrication_Drilling', 'Major'),
('FPC_LAMIN_DEL', 'Delamination', 'FPC_Fabrication_Lamination', 'Critical'),
('FPC_AOI_CONTAM', 'Contamination Detected (FPC)', 'FPC_Fabrication_AOI', 'Minor'),
('ASSY_SMT_MSS', 'Missing SMT Component', 'FPC_Assembly_SMT', 'Critical'),
('ASSY_SMT_WRP', 'Wrong Polarity/Orientation SMT', 'FPC_Assembly_SMT', 'Major'),
('ASSY_SMT_ALG', 'Misaligned SMT Component', 'FPC_Assembly_SMT', 'Major'),
('ASSY_SOLD_BRG', 'Solder Bridge', 'FPC_Assembly_Soldering', 'Critical'),
('ASSY_SOLD_INS', 'Insufficient Solder', 'FPC_Assembly_Soldering', 'Major'),
('ASSY_SOLD_COLD', 'Cold Solder Joint', 'FPC_Assembly_Soldering', 'Major'),
('ASSY_BOND_FAIL', 'ACF Bonding Failure', 'FPC_Assembly_Bonding', 'Critical'),
('ASSY_MECH_DMG', 'Mechanical Damage during Assembly', 'FPC_Assembly_Handling', 'Minor'),
('TEST_FAIL_FUNC', 'Functional Test Failure', 'Testing_Functional', 'Critical'),
('TEST_FAIL_ELEC', 'Electrical Test Failure (FPC)', 'Testing_Electrical_FPC', 'Critical');

-- ===== Operators (MES) =====
INSERT INTO Operators (OperatorID, OperatorName) VALUES
('OP001', 'Somsak Jaidee'),
('OP002', 'Malee Rungruang'),
('OP003', 'Pipat Pornprasert'),
('OP004', 'Wilai Suksawat'),
('OP005', 'Somchai Automation');

-- All tables created and master data inserted successfully.