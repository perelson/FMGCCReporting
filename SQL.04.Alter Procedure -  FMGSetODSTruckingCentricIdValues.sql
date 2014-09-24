USE [VCI]
GO

/****** Object:  StoredProcedure [dbo].[FMGSetODSTruckingCentricIdValues]    Script Date: 16/09/2014 12:10:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER procedure [dbo].[FMGSetODSTruckingCentricIdValues] as

/* -- !!! This is the temp procedure for Testing the New ODS Trucking Import Process !!!!
V2.0	TK 29-Aug-2013	Added Nulling of CentricSourceBU in Quarantine in case Source was refreshed
						Modifed Spoyyed OreblockName so it is always updated
						
		MK 29-Aug-2013	Adding Nulling to all remaining fields
						Removed section which explicitly set IsValidRehandle = 0
						where the Source and Destination was the same
		TK 35-09-2013   Added Section to disabled InAcive BUJ
		MK 24-01-2014   Added handling of AC-->AC and AC-->OPF
		MK 16-03-2014	Added handling of CC(and other 'WAG' AC Types) AC-->AC and AC-->OPF
		TK 30-04-2014   Added ODSEquipID to Join for Centric Load and Haul Equip ID updates to Quarantibe
		AP 8-08-2014    Added Dig Zone setting
		AP 13-08-2014   Added Dig Zone BUJ ATTRIB setting
*/

begin

declare @ProcName nvarchar(255) = OBJECT_NAME(@@ProcId)
exec LogTask @ProcName, 'Start'

/*
	Reset all Centric Id Values for 'Required' records
	which will allow all values to be remapped using
	most current data
*/

-- Reset CentricSource BUID if it has previously been populated
exec LogTask @ProcName, 'Start Nulling Centric Fields'

update q
set CentricSourceBUId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricSourceBUId IS NOT null

update q
set CentricDestinationBUId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricDestinationBUId IS NOT null

update q
set CentricLoadEquipId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricLoadEquipId IS NOT null

update q
set CentricLoadEquipAttrId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricLoadEquipAttrId IS NOT null

update q
set CentricHaulEquipId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricHaulEquipId IS NOT null

update q
set CentricSMEXAttrId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricSMEXAttrId IS NOT null

update q
set CentricShiftId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricShiftId IS NOT null

update q
set CentricCrusherBUId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricCrusherBUId IS NOT null

update q
set CentricSourceCategoryAttrId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricSourceCategoryAttrId IS NOT null

update q
set CentricDestinationCategoryAttrId =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.CentricDestinationCategoryAttrId IS NOT null

update q
set ShiftDate =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.ShiftDate IS NOT null

update q
set ShiftTypeName =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.ShiftTypeName IS NOT null

update q
set DigZoneID =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.DigZoneID IS NOT null

update q
set DigZoneBUJATTID =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.DigZoneBUJATTID IS NOT null

update q
set OreWasteBUJATTID =  NULL
from QuarantineODSTrucking q
where q.RequiredInQuarantine =1 and q.OreWasteBUJATTID IS NOT null

exec LogTask @ProcName, 'End Nulling Centric Fields'

exec LogTask @ProcName, 'Start Set Shift Date'
update q
set ShiftDate = s.DefaultDate
from QuarantineODSTrucking q
	outer apply dbo.FMGDefaultDateShiftEffective(q.RecordDate) s
where q.ShiftDate is null


exec LogTask @ProcName, 'Start Set Shift Name'
update q
set ShiftTypeName = sh.SHIFT
from QuarantineODSTrucking q
	outer apply dbo.FMGDefaultDateShiftFromRecordDate(q.RecordDate) s
inner join SHIFT sh
	on s.DefaultShift = sh.SHIFT_ID
where q.ShiftTypeName is null


exec LogTask @ProcName, 'Start Auto Mapping'
--Automatically add data to Mapping, based on the presence of '~'
insert into QuarantineODSStockpileMapping (ODSName, CentricName)
select ODSName, CentricName
from 
(
select distinct 
	SourceLocation as ODSName, 
	LEFT(SourceLocation, charindex('~',SourceLocation,0) -1) as CentricName
from QuarantineODSTrucking
where SourceLocation like '%~%'
union
select distinct 
	DestinationLocation as ODSName, 
	LEFT(DestinationLocation, charindex('~',DestinationLocation,0) -1) as CentricName
from QuarantineODSTrucking
where DestinationLocation like '%~%'
) Sub
where not exists (select 'x' from QuarantineODSStockpileMapping mapping
					where Sub.ODSName = mapping.ODSName
					and Sub.CentricName = mapping.CentricName)
and exists (select 'x' from BUSINESS_UNIT bu
			where Sub.CentricName = bu.BUSINESS_UNIT)
order by 1



exec LogTask @ProcName, 'Start CentricSourceBUId Mapping'
--Use Stockpile Mapping first to determine the BU
update q
set CentricSourceBUId = bu.business_unit_id
from QuarantineODSTrucking q
	inner join dbo.QuarantineODSStockpileMapping map
		on q.SourceLocation = map.ODSName
	inner join BUSINESS_UNIT bu
		on map.CentricName = bu.BUSINESS_UNIT
where q.CentricSourceBUId is null
and q.RequiredInQuarantine = 1

	
exec LogTask @ProcName, 'Start CentricSourceBUId Non Mapping'	
update q
set CentricSourceBUId = bu.business_unit_id
from QuarantineODSTrucking q
inner join BUSINESS_UNIT bu
	on q.SourceLocation = bu.BUSINESS_UNIT
where q.CentricSourceBUId is null
and q.RequiredInQuarantine = 1

--Apply Ore Spotting Matrix
--select distinct top 10000 

-- first reset all Required records in case the ODS trucking record was updated
exec LogTask @ProcName, 'Start Null SourceAfterOreSpotApplied'
update q
set SourceAfterOreSpotApplied = NULL
from QuarantineODSTrucking q
where RequiredInQuarantine = 1 and q.SourceAfterOreSpotApplied is not null


-- Now Apply Matrix
exec LogTask @ProcName, 'Start SourceAfterOreSpotApplied'
update q
set SourceAfterOreSpotApplied = REPLACE(q.SourceLocation, osm.ConvertedMaterialType, osm.OriginalMaterialType)
from QuarantineODSTrucking q
	outer apply dbo.Split(q.SourceLocation, '_') q1
	inner join QuarantineODSOreSpottingMatrix osm
		on left(q1.Data,2) = osm.ConvertedMaterialType
where q.SourceSite='Christmas Creek'
and q1.Id=4
and osm.Site = 'CC'
and q.RequiredInQuarantine = 1


exec LogTask @ProcName, 'Start CentricSourceBUId using Spotted'
update q
set CentricSourceBUId = bu.business_unit_id
from QuarantineODSTrucking q
inner join BUSINESS_UNIT bu
	on q.SourceAfterOreSpotApplied = bu.BUSINESS_UNIT
where q.CentricSourceBUId is null
and q.RequiredInQuarantine = 1

	

--Use Stockpile Mapping first to determine the BU	
exec LogTask @ProcName, 'Start CentricDestinationBUId using Mapping'
update q
set CentricDestinationBUId = bu.business_unit_id
from QuarantineODSTrucking q
	inner join dbo.QuarantineODSStockpileMapping map
		on q.DestinationLocation = map.ODSName
	inner join BUSINESS_UNIT bu
		on map.CentricName = bu.BUSINESS_UNIT
where q.CentricDestinationBUId is null
and bu.BUSINESS_UNIT_TYPE_ID in (5,6,7,12,13,20,28,33) --Valid Dest Types
and q.RequiredInQuarantine = 1


exec LogTask @ProcName, 'Start CentricDestinationBUId not using Mapping'
update q
set CentricDestinationBUId = bu.business_unit_id
from QuarantineODSTrucking q
inner join BUSINESS_UNIT bu
	on q.DestinationLocation = bu.BUSINESS_UNIT
where q.CentricDestinationBUId is null
and bu.BUSINESS_UNIT_TYPE_ID in (5,6,7,12,13,20,28,33) --Valid Dest Types
and q.RequiredInQuarantine = 1


-- Centric equipe ID now on join with ODSEquipId attribute
exec LogTask @ProcName, 'Start CentricHaulEquipId'
update q
set CentricHaulEquipId = e.EQUIPID
from QuarantineODSTrucking q
	inner join EQUIP e
		on q.HaulEquipName = e.EQUIP
		inner join dbo.EQUIPCMTVAL ODSEquipId
			on e.EQUIPID = ODSEquipId.EQUIPID and ODSEquipId.EQUIPCMTID = 1 --ODSEquipId
				and cast(ODSEquipId.EQUIPCMTVAL as int) = q.HaulEquipId
where q.CentricHaulEquipId is null
and q.RequiredInQuarantine = 1


exec LogTask @ProcName, 'Start CentricLoadEquipId'
update q
set CentricLoadEquipId = e.EQUIPID
from QuarantineODSTrucking q
	inner join EQUIP e
		on q.LoadEquipName = e.EQUIP
		inner join dbo.EQUIPCMTVAL ODSEquipId
			on e.EQUIPID = ODSEquipId.EQUIPID and ODSEquipId.EQUIPCMTID = 1 --ODSEquipId
				and cast(ODSEquipId.EQUIPCMTVAL as int) = q.LoadEquipId
where q.CentricLoadEquipId is null
and q.RequiredInQuarantine = 1



exec LogTask @ProcName, 'Start CentricLoadEquipAttrId'	
update q
set CentricLoadEquipAttrId = bujal.BUJATTLKUPID
from QuarantineODSTrucking q
	inner join EQUIP e
		on q.CentricLoadEquipId = e.EQUIPID
	inner join BUJATTLKUP bujal
		on e.EQUIP = bujal.BUJATTLKUP
where q.CentricLoadEquipAttrId is null
and q.RequiredInQuarantine = 1
	
		
exec LogTask @ProcName, 'Start CentricSMEXAttrId'			
update q
set CentricSMEXAttrId = bujal.BUJATTLKUPID
from QuarantineODSTrucking q
	inner join EQUIP e
		on q.CentricLoadEquipId = e.EQUIPID
	inner join EQUIPTYPE et
		on e.EQUIPTYPEID = et.EQUIPTYPEID
	inner join EQUIPTYPEATTVAL etav
		on et.EQUIPTYPEID = etav.EQUIPTYPEID
	inner join EQUIPTYPEATTLKUP etal
		on etav.EQUIPTYPEATTLKUPID = etal.EQUIPTYPEATTLKUPID
	inner join BUJATTLKUP bujal
		on etal.EQUIPTYPEATTLKUP = bujal.BUJATTLKUP		
where etav.EQUIPTYPEATTID = 1
and bujal.BUJATTID = 7
and q.CentricSMEXAttrId is null
and q.RequiredInQuarantine = 1


exec LogTask @ProcName, 'Start CentricShiftId'
update q
set CentricShiftId = s.DefaultShift--, RequiredInQuarantine = 1
from QuarantineODSTrucking q
	outer apply dbo.FMGDefaultDateShiftFromRecordDate(q.RecordDate) s
--where q.CentricShiftId <> s.DefaultShift
where q.CentricShiftId is null
and q.RequiredInQuarantine = 1


--NULL all the IsMining, IsValidMining etc for all Required data
exec LogTask @ProcName, 'Start Nulling Is Fields'
update QuarantineODSTrucking
set 
	IsMining = null,
	IsRehandle = null,
	IsDirectFeed = null,
	IsReclaim = null,
	IsACRehandle = null,
	ISACtoOPF = null,
	IsValidMining = null,
	IsValidRehandle = null,
	IsValidDirectFeed = null,
	IsValidReclaim = null,
	IsValidACRehandle = null,
	IsValidACtoOPF = null
where RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsMining'
update q
set IsMining = 1
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT SourceBU
		on q.CentricSourceBUId = SourceBU.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT DestBU
		on q.CentricDestinationBUId = DestBU.BUSINESS_UNIT_ID
where SourceBU.BUSINESS_UNIT_TYPE_ID = 4 --OreBlock
and DestBU.BUSINESS_UNIT_TYPE_ID in (6,7) --SP
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsDirectFeed'
update q
set IsDirectFeed = 1
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT SourceBU
		on q.CentricSourceBUId = SourceBU.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT DestBU
		on q.CentricDestinationBUId = DestBU.BUSINESS_UNIT_ID
where SourceBU.BUSINESS_UNIT_TYPE_ID = 4 --OreBlock
and DestBU.BUSINESS_UNIT_TYPE_ID in (20) --Hopper
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsRehandle'
update q
set IsRehandle = 1
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT SourceBU
		on q.CentricSourceBUId = SourceBU.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT DestBU
		on q.CentricDestinationBUId = DestBU.BUSINESS_UNIT_ID
where SourceBU.BUSINESS_UNIT_TYPE_ID in (6,7) --SP
and DestBU.BUSINESS_UNIT_TYPE_ID in (6,7) --SP
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsReclaim'
update q
set IsReclaim = 1
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT SourceBU
		on q.CentricSourceBUId = SourceBU.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT DestBU
		on q.CentricDestinationBUId = DestBU.BUSINESS_UNIT_ID
where SourceBU.BUSINESS_UNIT_TYPE_ID in (6,7) --SP
and DestBU.BUSINESS_UNIT_TYPE_ID in (20) --Hopper
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsACRehandle'
update q
set IsACRehandle = 1
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT SourceBU
		on q.CentricSourceBUId = SourceBU.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT DestBU
		on q.CentricDestinationBUId = DestBU.BUSINESS_UNIT_ID
where SourceBU.BUSINESS_UNIT_TYPE_ID in (33,41) --AC SP
and DestBU.BUSINESS_UNIT_TYPE_ID in (33,41) --AC SP
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start ISACtoOPF'
update q
set ISACtoOPF = 1
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT SourceBU
		on q.CentricSourceBUId = SourceBU.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT DestBU
		on q.CentricDestinationBUId = DestBU.BUSINESS_UNIT_ID
where SourceBU.BUSINESS_UNIT_TYPE_ID in (33,41) --AC SP
and DestBU.BUSINESS_UNIT_TYPE_ID in (12,13,28) --OPF
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsValidMining'
update q
set IsValidMining = 1
from QuarantineODSTrucking q
where IsMining = 1
and CentricSourceBUId is not null
and CentricDestinationBUId is not null
and CentricLoadEquipAttrId is not null
and CentricHaulEquipId is not null
and CentricSMEXAttrId is not null
and CentricShiftId is not null
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsValidDirectFeed'
update q
set IsValidDirectFeed = 1
from QuarantineODSTrucking q
where IsDirectFeed = 1
and CentricSourceBUId is not null
and CentricDestinationBUId is not null
and CentricLoadEquipAttrId is not null
and CentricHaulEquipId is not null
and CentricSMEXAttrId is not null
and CentricShiftId is not null
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsValidRehandle'
update q
set IsValidRehandle = 1
from QuarantineODSTrucking q
where IsRehandle = 1
and CentricSourceBUId is not null
and CentricDestinationBUId is not null
and CentricLoadEquipAttrId is not null
and CentricHaulEquipId is not null
and CentricSMEXAttrId is not null
and CentricShiftId is not null
and q.RequiredInQuarantine = 1


--Removing this section in order to allow Movements
--where Source = Destination to pass through to Centric
/*
update q
set IsValidRehandle = 0, 
	RequiredInQuarantine = 0
from QuarantineODSTrucking q
where IsRehandle = 1
and IsValidRehandle = 1
and CentricSourceBUId = CentricDestinationBUId
*/
exec LogTask @ProcName, 'Start IsValidReclaim'
update q
set IsValidReclaim = 1
from QuarantineODSTrucking q
where IsReclaim = 1
and CentricSourceBUId is not null
and CentricDestinationBUId is not null
and CentricHaulEquipId is not null
and CentricShiftId is not null
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsValidACRehandle'
update q
set IsValidACRehandle = 1
from QuarantineODSTrucking q
where IsACRehandle = 1
and CentricSourceBUId is not null
and CentricDestinationBUId is not null
and CentricHaulEquipId is not null
and CentricShiftId is not null
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start IsValidACtoOPF'
update q
set IsValidACtoOPF = 1
from QuarantineODSTrucking q
where ISACtoOPF = 1
and CentricSourceBUId is not null
and CentricDestinationBUId is not null
and CentricHaulEquipId is not null
and CentricShiftId is not null
and q.RequiredInQuarantine = 1




--Get Crusher associated with Hopper
exec LogTask @ProcName, 'Start CentricCrusherBUId'
update q
set CentricCrusherBUId = buCrusher.BUSINESS_UNIT_ID
from QuarantineODSTrucking q
	inner join BUSINESS_UNIT bu
		on q.CentricDestinationBUId = bu.BUSINESS_UNIT_ID
	inner join BUSINESS_UNIT buCrusher
		on bu.RELATED_TO_BU_ID = buCrusher.RELATED_TO_BU_ID
where buCrusher.BUSINESS_UNIT_TYPE_ID = 8 --Crusher 
and bu.BUSINESS_UNIT_TYPE_ID = 20 --Hopper
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start CentricSourceCategoryAttrId'
update q
set CentricSourceCategoryAttrId = bujal.BUJATTLKUPID
from BUSINESSUNITATT bua 
	inner join BUSINESSUNITATTVAL buav 
		on bua.BUSINESSUNITATTID = buav.BUSINESSUNITATTID 
	inner join BUSINESSUNITATTLKUP bualk 
		on buav.BUSINESSUNITATTLKUPID = bualk.BUSINESSUNITATTLKUPID 
	inner join BUJATTLKUP bujal 
		on bualk.BUSINESSUNITATTLKUP = bujal.BUJATTLKUP 
	inner join BUJATT buja 
		on bujal.BUJATTID = buja.BUJATTID 
	inner join BUSINESS_UNIT bu 
		on buav.BUSINESS_UNIT_ID = bu.BUSINESS_UNIT_ID 
	inner join QuarantineODSTrucking q
		on bu.BUSINESS_UNIT_ID = q.CentricSourceBUId
where  
	bua.BUSINESSUNITATT='Designated Category' 
and buja.BUJATT='Source Category'
and q.RequiredInQuarantine = 1

exec LogTask @ProcName, 'Start CentricDestinationCategoryAttrId'
update q
set CentricDestinationCategoryAttrId = bujal.BUJATTLKUPID
from BUSINESSUNITATT bua 
	inner join BUSINESSUNITATTVAL buav 
		on bua.BUSINESSUNITATTID = buav.BUSINESSUNITATTID 
	inner join BUSINESSUNITATTLKUP bualk 
		on buav.BUSINESSUNITATTLKUPID = bualk.BUSINESSUNITATTLKUPID 
	inner join BUJATTLKUP bujal 
		on bualk.BUSINESSUNITATTLKUP = bujal.BUJATTLKUP 
	inner join BUJATT buja 
		on bujal.BUJATTID = buja.BUJATTID 
	inner join BUSINESS_UNIT bu 
		on buav.BUSINESS_UNIT_ID = bu.BUSINESS_UNIT_ID 
	inner join QuarantineODSTrucking q
		on bu.BUSINESS_UNIT_ID = q.CentricDestinationBUId
where  
	bua.BUSINESSUNITATT='Designated Category' 
and buja.BUJATT='Destination Category'
and q.RequiredInQuarantine = 1

-- New Section for Setting ScenarioID and Enabled Flag
-- Enabld Flag is imported from DumpIsActive Field

exec LogTask @ProcName, 'Start ScenarioID 6'
update q
set q.ScenarioID = 6 -- Disabled Scenario
from QuarantineODSTrucking q
where  q.RequiredInQuarantine = 1
	and q.DumpIsActive = 0 

exec LogTask @ProcName, 'Start ScenarioID 1'
update q
set q.ScenarioID = 1 -- Actuals Scenario
from QuarantineODSTrucking q
where  q.RequiredInQuarantine = 1
	and q.DumpIsActive = 1 
	
		

exec LogTask @ProcName, 'Start SourceKey'
update 	QuarantineODSTrucking
set SourceKey = 'ODS Trucking ' + CAST(ODSTruckingID as varchar)	
where SourceKey is null
and RequiredInQuarantine = 1



exec LogTask @ProcName, 'Start Dig Zone'

UPDATE QuarantineODSTrucking
set Shot = NULL
where DigZoneID is null
and RequiredInQuarantine = 1
and Shot IS NOT NULL
and ISNUMERIC(Shot) = 0

update 	QuarantineODSTrucking
set DigZoneID = dbo.fnGetDigZone (CentricSourceBUId,Shot)
where DigZoneID is null
and RequiredInQuarantine = 1
and Shot IS NOT NULL


exec LogTask @ProcName, 'Start Dig Zone BUJ ATT ID'

UPDATE QOT
 SET QOT.[DigZoneBUJATTID] = LKUP.BUJATTLKUPID
 FROM
  [QuarantineODSTrucking] QOT
  LEFT JOIN 
  (SELECT PAL.PRODUCTIONATTLKUPID, PAL.PRODUCTIONATTLKUP,
         BAL.BUJATTLKUPID, BAL.BUJATTLKUP 
  FROM
  (SELECT PRODUCTIONATTLKUPID, PRODUCTIONATTLKUP 
   FROM [PRODUCTIONATTLKUP]) PAL
  JOIN
  (SELECT BUJATTLKUPID, BUJATTLKUP 
   FROM [BUJATTLKUP]
   WHERE BUJATTID = 14) BAL					--<<-- Dig Zone BUJATT - DEV: 14 UAT: 14
  ON PAL.PRODUCTIONATTLKUP = BAL.BUJATTLKUP) LKUP
  ON QOT.DigZoneID = LKUP.PRODUCTIONATTLKUPID
  WHERE QOT.DigZoneID IS NOT NULL
  AND QOT.[DigZoneBUJATTID] IS NULL
  AND QOT.RequiredInQuarantine = 1


exec LogTask @ProcName, 'Start OreWaste Zone BUJ ATT ID'

UPDATE QOT
 SET QOT.[OreWasteBUJATTID] = LKUP.BUJATTLKUPID
 FROM
  [QuarantineODSTrucking] QOT
  LEFT JOIN 
  (SELECT DumpID, OreWaste, BAL.BUJATTLKUPID
		FROM
		(
		SELECT SourceBits.DumpID, SourceBits.[CentricSourceCategoryAttrId], SourceBits.BUJATTLKUPID, SourceBits.SourceCategoryDescription,
		SpottedBits.SpottedCategory, SpottedBits.SpottedCategoryDescription,

		(case when SourceCategoryDescription IS NOT NULL THEN
				COALESCE (case when SpottedCategoryDescription  like '%waste%' then  'Waste' 
								when SpottedCategory not like '%waste%'  then 'Ore' else NULL  end 
					, case when SourceCategoryDescription like '%Waste%' then 'Waste' else 'Ore' end) 
			else
			null
			end)  AS OreWaste

		FROM

		(SELECT QOT1.DumpID, QOT1.[CentricSourceCategoryAttrId], bujatt1.BUJATTLKUPID, bujatt1.[DESCRIPTION] AS SourceCategoryDescription,
				QOT1.[OreWasteBUJATTID], QOT1.RequiredInQuarantine 
		 FROM 
		 (SELECT DumpID, [CentricSourceCategoryAttrId], [OreWasteBUJATTID], RequiredInQuarantine
		  FROM [QuarantineODSTrucking]) QOT1
		 LEFT JOIN 
		 (SELECT BUJATTLKUPID, [Description] 
		  FROM BUJATTLKUP
		  WHERE BUJATTID = 1) bujatt1									--<<-- Source Category BUJATT - DEV: 1 UAT: 1
		 ON QOT1.CentricSourceCategoryAttrId = bujatt1.BUJATTLKUPID
		 ) AS SourceBits

		LEFT JOIN

		--  SpottedCategory 
		(SELECT DumpID, SpottedCategory,
		 CASE WHEN SpottedCategory IN ('WS','SU') THEN 'Waste' ELSE [Description] END AS SpottedCategoryDescription
		 FROM
		(
		SELECT q.DumpId, osm.SpottedMaterialType AS SpottedCategory
		from [QuarantineODSTrucking] q
			outer apply dbo.Split(q.SourceAfterOreSpotApplied, '_') q1
			inner join QuarantineODSOreSpottingMatrix osm
				on left(q1.Data,2) = osm.ConvertedMaterialType
		where q.SourceSite like 'Christmas Creek%'
		and q1.Id=4
		and osm.Site = 'CC'
		and q.SourceAfterOreSpotApplied IS NOT NULL
		) a
		LEFT JOIN
		(SELECT BUJATTLKUP, [Description] 
		 FROM BUJATTLKUP
		 WHERE BUJATTID = 1) b									--<<-- Source Category BUJATT - DEV: 1 UAT: 1
		ON a.SpottedCategory = b.BUJATTLKUP
		WHERE CASE WHEN SpottedCategory IN ('WS','SU') THEN 'Waste' ELSE [Description] END IS NOT NULL
		) AS SpottedBits

		ON SourceBits.DumpId = SpottedBits.DumpId
		WHERE [OreWasteBUJATTID] IS NULL
		  AND RequiredInQuarantine = 1) AS OWDeterminator

		LEFT JOIN 

		(SELECT BUJATTLKUPID, BUJATTLKUP
		   FROM [BUJATTLKUP]
		   WHERE BUJATTID = 15) BAL									--<<-- OreWaste Category BUJATT - DEV: 15 UAT: 15

		ON OreWaste = BAL.BUJATTLKUP) LKUP
  ON QOT.DumpID = LKUP.DumpID
  WHERE QOT.[OreWasteBUJATTID] IS NULL
  AND QOT.RequiredInQuarantine = 1


exec LogTask @ProcName, 'End'

end










GO


