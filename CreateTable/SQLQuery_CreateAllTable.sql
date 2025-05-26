-- #####################################################################
-- # โปรเจกต์: ระบบจำลองการจัดการกระบวนการผลิตแบบครบวงจร               #
-- # Script: สร้างตารางทั้งหมด และเพิ่มข้อมูล Master Data เริ่มต้น       #
-- # ฐานข้อมูล: SQL Server                                             #
-- #####################################################################

-- =====================================================================
-- ส่วนที่ 0: สร้างตารางทั้งหมด (ถ้ายังไม่ได้สร้าง)
-- =====================================================================
PRINT 'Creating all tables...';

-- ===== ตาราง: Customers (ลูกค้า) =====
IF OBJECT_ID('dbo.Customers', 'U') IS NULL
BEGIN
    CREATE TABLE Customers (
        CustomerID NVARCHAR(50) PRIMARY KEY,
        CustomerName NVARCHAR(255) NOT NULL,
        ContactPerson NVARCHAR(150),
        Email NVARCHAR(255),
        Phone NVARCHAR(50),
        Address NVARCHAR(MAX)
    );
    PRINT 'Table Customers created.';
END
GO

-- ===== ตาราง: Products (ผลิตภัณฑ์ - Finished Goods และอาจรวม Sub-Assemblies ที่ MES ผลิต) =====
IF OBJECT_ID('dbo.Products', 'U') IS NULL
BEGIN
    CREATE TABLE Products (
        ProductID NVARCHAR(50) PRIMARY KEY,
        ProductName NVARCHAR(255) NOT NULL,
        ProductType NVARCHAR(100) NOT NULL,
        TargetYield DECIMAL(5, 4) DEFAULT 0.9500,
        StandardCycleTime_Seconds INT,
        FPC_Layers INT,
        FPC_CopperThickness_um INT,
        FPC_Dielectric NVARCHAR(100),
        SalesUnitPrice DECIMAL(18, 2) DEFAULT 0.00
    );
    PRINT 'Table Products created.';
END
GO

-- ===== ตาราง: Materials (วัตถุดิบ/ชิ้นส่วน และ Sub-Assemblies) =====
IF OBJECT_ID('dbo.Materials', 'U') IS NULL
BEGIN
    CREATE TABLE Materials (
        MaterialID NVARCHAR(50) PRIMARY KEY,
        MaterialName NVARCHAR(255) NOT NULL,
        MaterialType NVARCHAR(100),
        UnitOfMeasure NVARCHAR(20),
        StandardCost DECIMAL(18, 4) DEFAULT 0.0000
    );
    PRINT 'Table Materials created.';
END
GO

-- ===== ตาราง: BillOfMaterials (BOM - รายการวัตถุดิบต่อผลิตภัณฑ์) =====
IF OBJECT_ID('dbo.BillOfMaterials', 'U') IS NULL
BEGIN
    CREATE TABLE BillOfMaterials (
        BOM_ID BIGINT PRIMARY KEY IDENTITY(1,1),
        Parent_ProductID_FK NVARCHAR(50) NOT NULL,
        Component_MaterialID_FK NVARCHAR(50) NOT NULL,
        QuantityPerParent DECIMAL(10, 4) NOT NULL,
        BOM_Level INT DEFAULT 1,
        EffectiveDate DATETIME2 DEFAULT GETDATE(),
        Version NVARCHAR(20) DEFAULT '1.0',
        CONSTRAINT FK_BOM_ParentProduct FOREIGN KEY (Parent_ProductID_FK) REFERENCES Products(ProductID),
        CONSTRAINT FK_BOM_ComponentMaterial FOREIGN KEY (Component_MaterialID_FK) REFERENCES Materials(MaterialID),
        CONSTRAINT UQ_BOM_Parent_Component_Version UNIQUE (Parent_ProductID_FK, Component_MaterialID_FK, Version)
    );
    PRINT 'Table BillOfMaterials created.';
END
GO

-- ===== ตาราง: Inventory (สินค้าคงคลัง - ทั้งวัตถุดิบและสินค้าสำเร็จรูป) =====
IF OBJECT_ID('dbo.Inventory', 'U') IS NULL
BEGIN
    CREATE TABLE Inventory (
        InventoryItemID NVARCHAR(50) PRIMARY KEY,
        ItemDescription NVARCHAR(255) NOT NULL,
        ItemType NVARCHAR(50) NOT NULL,
        QuantityOnHand INT NOT NULL DEFAULT 0,
        QuantityOnOrder INT DEFAULT 0,
        QuantityAllocated INT DEFAULT 0,
        ReorderLevel INT DEFAULT 0,
        LastStocktakeDate DATETIME2,
        StorageLocation NVARCHAR(100)
    );
    PRINT 'Table Inventory created.';
END
GO

-- ===== ตาราง: SalesOrders (คำสั่งซื้อจากลูกค้า) =====
IF OBJECT_ID('dbo.SalesOrders', 'U') IS NULL
BEGIN
    CREATE TABLE SalesOrders (
        SalesOrderID NVARCHAR(50) PRIMARY KEY,
        CustomerID_FK NVARCHAR(50) NOT NULL,
        OrderDate DATETIME2 NOT NULL DEFAULT GETDATE(),
        RequiredDeliveryDate DATETIME2,
        OrderStatus NVARCHAR(50) NOT NULL DEFAULT 'Pending',
        ShippingAddress NVARCHAR(MAX),
        TotalAmount DECIMAL(18, 2) DEFAULT 0.00,
        CONSTRAINT FK_SalesOrders_Customers FOREIGN KEY (CustomerID_FK) REFERENCES Customers(CustomerID)
    );
    PRINT 'Table SalesOrders created.';
END
GO

-- ===== ตาราง: SalesOrderLines (รายการสินค้าในคำสั่งซื้อ) =====
IF OBJECT_ID('dbo.SalesOrderLines', 'U') IS NULL
BEGIN
    CREATE TABLE SalesOrderLines (
        SalesOrderLineID BIGINT PRIMARY KEY IDENTITY(1,1),
        SalesOrderID_FK NVARCHAR(50) NOT NULL,
        ProductID_FK NVARCHAR(50) NOT NULL,
        QuantityOrdered INT NOT NULL,
        UnitPrice DECIMAL(18, 2) NOT NULL,
        LineTotalAmount AS (QuantityOrdered * UnitPrice),
        LineStatus NVARCHAR(50) NOT NULL DEFAULT 'Open',
        CONSTRAINT FK_SalesOrderLines_SalesOrders FOREIGN KEY (SalesOrderID_FK) REFERENCES SalesOrders(SalesOrderID),
        CONSTRAINT FK_SalesOrderLines_Products FOREIGN KEY (ProductID_FK) REFERENCES Products(ProductID)
    );
    PRINT 'Table SalesOrderLines created.';
END
GO

-- ===== ตาราง: WorkOrders (คำสั่งผลิต) =====
IF OBJECT_ID('dbo.WorkOrders', 'U') IS NULL
BEGIN
    CREATE TABLE WorkOrders (
        WorkOrderID NVARCHAR(50) PRIMARY KEY,
        SalesOrderLineID_FK BIGINT NULL,
        ProductID_FK NVARCHAR(50) NOT NULL,
        QuantityToProduce INT NOT NULL,
        QuantityProducedGood INT DEFAULT 0,
        QuantityScrapped INT DEFAULT 0,
        ScheduledStartDate DATETIME2,
        ScheduledEndDate DATETIME2,
        ActualStartDate DATETIME2,
        ActualEndDate DATETIME2,
        WorkOrderStatus NVARCHAR(50) NOT NULL DEFAULT 'Planned',
        BatchID_Assigned NVARCHAR(100) NULL UNIQUE,
        Notes NVARCHAR(MAX),
        CONSTRAINT FK_WorkOrders_SalesOrderLines FOREIGN KEY (SalesOrderLineID_FK) REFERENCES SalesOrderLines(SalesOrderLineID),
        CONSTRAINT FK_WorkOrders_Products FOREIGN KEY (ProductID_FK) REFERENCES Products(ProductID)
    );
    PRINT 'Table WorkOrders created.';
END
GO

-- ===== ตาราง: Machines (เครื่องจักร/สถานีงาน) - (MES) =====
IF OBJECT_ID('dbo.Machines', 'U') IS NULL
BEGIN
    CREATE TABLE Machines (
        MachineID NVARCHAR(50) PRIMARY KEY,
        MachineName NVARCHAR(255) NOT NULL,
        ProcessArea NVARCHAR(100) NOT NULL,
        Location NVARCHAR(100),
        Description NVARCHAR(MAX)
    );
    PRINT 'Table Machines created.';
END
GO

-- ===== ตาราง: DefectCodes (รหัสสาเหตุของเสีย) - (MES) =====
IF OBJECT_ID('dbo.DefectCodes', 'U') IS NULL
BEGIN
    CREATE TABLE DefectCodes (
        DefectCodeID NVARCHAR(20) PRIMARY KEY,
        DefectDescription NVARCHAR(255) NOT NULL,
        ProcessAreaAffected NVARCHAR(100),
        Severity NVARCHAR(50)
    );
    PRINT 'Table DefectCodes created.';
END
GO

-- ===== ตาราง: Operators (ผู้ปฏิบัติงาน) - (MES) =====
IF OBJECT_ID('dbo.Operators', 'U') IS NULL
BEGIN
    CREATE TABLE Operators (
        OperatorID NVARCHAR(50) PRIMARY KEY,
        OperatorName NVARCHAR(150) NOT NULL
    );
    PRINT 'Table Operators created.';
END
GO

-- ===== ตาราง: ProductionLog (บันทึกข้อมูลการผลิต MES) =====
IF OBJECT_ID('dbo.ProductionLog', 'U') IS NULL
BEGIN
    CREATE TABLE ProductionLog (
        LogID BIGINT PRIMARY KEY IDENTITY(1,1),
        Timestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
        WorkOrderID_FK NVARCHAR(50) NOT NULL,
        ProductID_FK NVARCHAR(50) NOT NULL,
        MachineID_FK NVARCHAR(50) NOT NULL,
        OperatorID_FK NVARCHAR(50) NULL,
        InputQuantity INT DEFAULT 0,
        OutputGoodQuantity INT NOT NULL DEFAULT 0,
        OutputDefectQuantity INT NOT NULL DEFAULT 0,
        MachineStatus NVARCHAR(50),
        ReworkFlag BIT DEFAULT 0,
        Notes NVARCHAR(MAX),
        CONSTRAINT FK_ProductionLog_WorkOrders FOREIGN KEY (WorkOrderID_FK) REFERENCES WorkOrders(WorkOrderID),
        CONSTRAINT FK_ProductionLog_Products_MES FOREIGN KEY (ProductID_FK) REFERENCES Products(ProductID),
        CONSTRAINT FK_ProductionLog_Machines_MES FOREIGN KEY (MachineID_FK) REFERENCES Machines(MachineID),
        CONSTRAINT FK_ProductionLog_Operators_MES FOREIGN KEY (OperatorID_FK) REFERENCES Operators(OperatorID)
    );
    PRINT 'Table ProductionLog created.';

    CREATE INDEX IX_ProductionLog_WorkOrderID ON ProductionLog(WorkOrderID_FK);
    CREATE INDEX IX_ProductionLog_Timestamp_MES ON ProductionLog(Timestamp);
    PRINT 'Indexes for ProductionLog created.';
END
GO

-- ===== ตาราง: DefectLog (บันทึกข้อมูลของเสียโดยละเอียด MES) =====
IF OBJECT_ID('dbo.DefectLog', 'U') IS NULL
BEGIN
    CREATE TABLE DefectLog (
        DefectLogID BIGINT PRIMARY KEY IDENTITY(1,1),
        ProductionLogID_FK BIGINT NOT NULL,
        DefectCodeID_FK NVARCHAR(20) NOT NULL,
        DefectInstanceQuantity INT NOT NULL DEFAULT 1,
        DefectLocation NVARCHAR(100),
        DefectTimestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_DefectLog_ProductionLog_MES FOREIGN KEY (ProductionLogID_FK) REFERENCES ProductionLog(LogID),
        CONSTRAINT FK_DefectLog_DefectCodes_MES FOREIGN KEY (DefectCodeID_FK) REFERENCES DefectCodes(DefectCodeID)
    );
    PRINT 'Table DefectLog created.';

    CREATE INDEX IX_DefectLog_ProductionLogID_MES ON DefectLog(ProductionLogID_FK);
    PRINT 'Index for DefectLog created.';
END
GO
PRINT 'All tables checked/created.';
GO

-- =====================================================================
-- ส่วนที่ 1: การเพิ่มข้อมูล Master Data เริ่มต้น
-- (แนะนำให้ Clear ข้อมูลเก่าในตาราง Master เหล่านี้ก่อน หากต้องการรัน Script นี้ซ้ำ)
-- DELETE FROM BillOfMaterials; DELETE FROM Inventory; DELETE FROM Materials; DELETE FROM Products; DELETE FROM Customers;
-- DELETE FROM Machines; DELETE FROM DefectCodes; DELETE FROM Operators;
-- =====================================================================

-- ===== Customers =====
PRINT 'Inserting data into Customers...';
INSERT INTO Customers (CustomerID, CustomerName, ContactPerson, Email, Phone, Address) VALUES
('CUST001', 'Global Tech Solutions', 'Alice Wonderland', 'alice@globaltech.com', '555-0101', '123 Innovation Drive, Tech City'),
('CUST002', 'Future Devices Inc.', 'Bob The Builder', 'bob@futuredevices.com', '555-0102', '456 Silicon Avenue, Gadget Town'),
('CUST003', 'AeroSpace Dynamics', 'Carol Danvers', 'carol@aerodynamics.com', '555-0103', '789 Sky High Rd, Flight Ville'),
('CUST004', 'MediEquip Corp.', 'David Banner', 'david@mediequip.com', '555-0104', '101 Health St, Wellness City'),
('CUST005', 'Automotive Innovations Ltd.', 'Eve Moneypenny', 'eve@autoinnovate.com', '555-0105', '202 Fast Lane, Motorburg');
GO

-- ===== Products (Finished Goods and Produced Sub-Assemblies) =====
PRINT 'Inserting data into Products...';
INSERT INTO Products (ProductID, ProductName, ProductType, TargetYield, StandardCycleTime_Seconds, FPC_Layers, FPC_CopperThickness_um, FPC_Dielectric, SalesUnitPrice) VALUES
('FPC_SL_PI18', 'FPC Single Layer Polyimide 18um Cu', 'FPC', 0.9850, 120, 1, 18, 'Polyimide', 2.50),
('FPC_DL_PI35', 'FPC Double Layer Polyimide 35um Cu', 'FPC', 0.9780, 200, 2, 35, 'Polyimide', 5.75),
('FPC_ML4_MPI12', 'FPC Multi-Layer (4L) Mod-PI 12um Cu, HDI', 'FPC', 0.9650, 450, 4, 12, 'Modified Polyimide', 15.20),
('FPC_SL_LCP9_HF', 'FPC Single Layer LCP 9um Cu, High-Freq', 'FPC', 0.9800, 150, 1, 9, 'LCP', 8.90),
('ASSY01_FPC_SL_PI18', 'Assembled FPC SL PI18 with SMT 01005', 'Assembled_FPC', 0.9920, 180, NULL, NULL, NULL, 7.80),
('ASSY02_FPC_ML4_MPI12', 'Assembled FPC ML4 MPI12 with Fine Pitch IC (ACF)', 'Assembled_FPC', 0.9880, 300, NULL, NULL, NULL, 25.50),
('MODULE_SENSOR_A', 'Sensor Module with FPC_DL_PI35 & Housing', 'Module', 0.9950, 600, NULL, NULL, NULL, 45.00);
GO

-- ===== Materials (Raw Materials, Components, Consumables) =====
PRINT 'Inserting data into Materials (Raw, Components, Consumables)...';
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
('MAT_PLASTIC_HOUSING_A', 'Plastic Housing Type A', 'Component', 'Pieces', 0.7500); -- Added this one
GO

-- ===== Materials (Sub-Assemblies - from Products table) =====
PRINT 'Inserting data into Materials (SubAssemblies from Products)...';
INSERT INTO Materials (MaterialID, MaterialName, MaterialType, UnitOfMeasure, StandardCost)
SELECT p.ProductID, p.ProductName,
       CASE
           WHEN p.ProductType = 'FPC' THEN 'SubAssembly_FPC'
           WHEN p.ProductType = 'Assembled_FPC' THEN 'SubAssembly_AssembledFPC'
           ELSE 'IntermediateProduct' -- Default for other types like 'Module' if used as component
       END,
       'Pieces',
       p.SalesUnitPrice * 0.65 -- Estimated cost for sub-assembly
FROM Products p
WHERE p.ProductID IN (
    'FPC_SL_PI18', 'FPC_DL_PI35', 'FPC_ML4_MPI12', 'FPC_SL_LCP9_HF', -- FPCs
    'ASSY01_FPC_SL_PI18' -- Assembled FPCs that might be used in a module
);
GO


-- ===== BillOfMaterials (BOM) =====
PRINT 'Inserting data into BillOfMaterials...';
-- BOM for FPC_SL_PI18 (Parent Product) - uses Raw Materials
INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('FPC_SL_PI18', 'MAT_PI_FILM_25U', 0.0100, '1.0'),
('FPC_SL_PI18', 'MAT_CU_FOIL_18U', 0.0100, '1.0'),
('FPC_SL_PI18', 'MAT_ADH_ACrylic', 0.0090, '1.0'),
('FPC_SL_PI18', 'MAT_COVERLAY_PI', 0.0080, '1.0');

-- BOM for FPC_DL_PI35 (Example)
INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('FPC_DL_PI35', 'MAT_PI_FILM_25U', 0.0200, '1.0'),
('FPC_DL_PI35', 'MAT_CU_FOIL_35U', 0.0200, '1.0'),
('FPC_DL_PI35', 'MAT_ADH_ACrylic', 0.0180, '1.0'),
('FPC_DL_PI35', 'MAT_COVERLAY_PI', 0.0160, '1.0');


-- BOM for ASSY01_FPC_SL_PI18 (Parent Product) - uses an FPC (now in Materials as SubAssembly) and other Components
INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('ASSY01_FPC_SL_PI18', 'FPC_SL_PI18', 1.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'COMP_RES_01005_1K', 5.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'COMP_CAP_0201_10NF', 2.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'COMP_CONNECTOR_ZIF', 1.0000, '1.0'),
('ASSY01_FPC_SL_PI18', 'MAT_SOLDER_PASTE_SAC', 0.5000, '1.0');

-- BOM for ASSY02_FPC_ML4_MPI12
INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('ASSY02_FPC_ML4_MPI12', 'FPC_ML4_MPI12', 1.0000, '1.0'),
('ASSY02_FPC_ML4_MPI12', 'COMP_IC_FINEPITCH_A', 1.0000, '1.0'),
('ASSY02_FPC_ML4_MPI12', 'MAT_ACF_FILM', 0.0050, '1.0');

-- BOM for MODULE_SENSOR_A
INSERT INTO BillOfMaterials (Parent_ProductID_FK, Component_MaterialID_FK, QuantityPerParent, Version) VALUES
('MODULE_SENSOR_A', 'ASSY01_FPC_SL_PI18', 1.0000, '1.0'), -- Uses an Assembled FPC (now in Materials)
('MODULE_SENSOR_A', 'MAT_PLASTIC_HOUSING_A', 1.0000, '1.0');
GO

-- ===== Inventory (Initial Stock) =====
PRINT 'Inserting data into Inventory...';
-- Raw Materials, Components, Consumables
INSERT INTO Inventory (InventoryItemID, ItemDescription, ItemType, QuantityOnHand, StorageLocation, ReorderLevel)
SELECT MaterialID, MaterialName, MaterialType, 
       CASE MaterialType 
           WHEN 'RawMaterial' THEN 1000 
           WHEN 'Component' THEN 5000 
           WHEN 'Consumable' THEN 200 
           ELSE 100 -- Default for other types like SubAssemblies if any are directly stocked
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
WHERE MaterialType NOT LIKE 'SubAssembly%' AND MaterialType <> 'IntermediateProduct'; -- Exclude sub-assemblies for now, they are "made"

-- Finished Goods / Producible Items (Products Table) - Start with some stock or zero
INSERT INTO Inventory (InventoryItemID, ItemDescription, ItemType, QuantityOnHand, StorageLocation, ReorderLevel)
SELECT ProductID, ProductName, 
       CASE ProductType 
            WHEN 'FPC' THEN 'FinishedGood_FPC' -- Or 'SubAssembly_FPC' if mostly used internally
            WHEN 'Assembled_FPC' THEN 'FinishedGood_AssembledFPC' -- Or 'SubAssembly_AssembledFPC'
            WHEN 'Module' THEN 'FinishedGood_Module'
            ELSE ProductType
       END, 
       CASE ProductID -- Set initial stock for some finished goods
            WHEN 'FPC_SL_PI18' THEN 50
            WHEN 'ASSY01_FPC_SL_PI18' THEN 20
            ELSE 10 -- Default low stock for other finished goods
       END, 
       'Finished Goods Store - Bay 1',
       5 -- Reorder level for finished goods
FROM Products;
GO


-- ===== Machines (MES) =====
PRINT 'Inserting data into Machines...';
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
GO

-- ===== DefectCodes (MES) =====
PRINT 'Inserting data into DefectCodes...';
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
GO

-- ===== Operators (MES) =====
PRINT 'Inserting data into Operators...';
INSERT INTO Operators (OperatorID, OperatorName) VALUES
('OP001', 'Somsak Jaidee'),
('OP002', 'Malee Rungruang'),
('OP003', 'Pipat Pornprasert'),
('OP004', 'Wilai Suksawat'),
('OP005', 'Somchai Automation');
GO

PRINT 'All tables created and master data inserted successfully.';