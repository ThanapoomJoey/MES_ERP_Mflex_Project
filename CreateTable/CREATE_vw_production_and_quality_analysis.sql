CREATE OR REPLACE VIEW vw_Production_And_Quality_Analysis AS
SELECT
    wo.WorkOrderID,
    wo.ProductID_FK AS ProductID,
    p.ProductName,
    p.ProductType,
    p.TargetYield AS ProductTargetYield,
    p.StandardCycleTime_Seconds AS ProductStandardCycleTime,
    wo.QuantityToProduce,
    wo.QuantityProducedGood AS WO_QuantityProducedGood, -- จำนวนดีทั้งหมดของ WO
    wo.QuantityScrapped AS WO_QuantityScrapped,       -- จำนวนเสียทั้งหมดของ WO
    DATE(wo.ScheduledStartDate) AS ScheduledStartDate,
    DATE(wo.ScheduledEndDate) AS ScheduledEndDate,
    DATE(wo.ActualStartDate) AS ActualStartDate,
    DATE(wo.ActualEndDate) AS ActualEndDate,
    wo.WorkOrderStatus,
    wo.BatchID_Assigned,

    pl.LogID AS ProductionLogID,
    pl.Timestamp AS ProductionTimestamp,
    pl.MachineID_FK AS MachineID,
    m.MachineName,
    m.ProcessArea AS MachineProcessArea,
    pl.OperatorID_FK AS OperatorID,
    op.OperatorName, -- Join กับ Operators
    pl.InputQuantity AS Log_InputQuantity,
    pl.OutputGoodQuantity AS Log_OutputGoodQuantity,
    pl.OutputDefectQuantity AS Log_OutputDefectQuantity,
    pl.MachineStatus AS Log_MachineStatus,
    (EXTRACT(EPOCH FROM (pl.Timestamp - LAG(pl.Timestamp, 1, pl.Timestamp) OVER (PARTITION BY wo.WorkOrderID, pl.MachineID_FK ORDER BY pl.Timestamp))) / NULLIF(pl.InputQuantity, 0))::DECIMAL(10,2) AS ActualCycleTimePerUnit_Seconds_AtStation, -- คำนวณ Cycle time คร่าวๆ ที่สถานีนั้นๆ

    dl.DefectLogID,
    dl.DefectCodeID_FK AS DefectCodeID,
    dc.DefectDescription,
    dc.ProcessAreaAffected AS DefectProcessAreaAffected,
    dc.Severity AS DefectSeverity,
    dl.DefectInstanceQuantity,
    dl.DefectTimestamp
FROM WorkOrders wo
JOIN Products p ON wo.ProductID_FK = p.ProductID
LEFT JOIN ProductionLog pl ON wo.WorkOrderID = pl.WorkOrderID_FK -- LEFT JOIN เผื่อ WO ที่ยังไม่มี Log การผลิต
LEFT JOIN Machines m ON pl.MachineID_FK = m.MachineID
LEFT JOIN Operators op ON pl.OperatorID_FK = op.OperatorID
LEFT JOIN DefectLog dl ON pl.LogID = dl.ProductionLogID_FK
LEFT JOIN DefectCodes dc ON dl.DefectCodeID_FK = dc.DefectCodeID
ORDER BY wo.WorkOrderID, pl.Timestamp, dl.DefectTimestamp;