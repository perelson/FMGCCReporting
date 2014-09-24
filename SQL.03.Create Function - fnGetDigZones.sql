USE [VCI]
GO

/****** Object:  UserDefinedFunction [dbo].[fnGetDigZone]    Script Date: 16/09/2014 8:23:31 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




/***********************************************************************************************************/
/*
Name:		[fnGetDigZone]
Version:	1.0
Created By: Andrew Perelson
Date:		Aug 8, 2014
Purpose:	Return the Dig Zone (Ore Zone or Over Burden Zone) based on a supplied Oreblock BU ID and Shot

################################## Modifications: ###############################
[This is where modifications to the object are tracked]

Version:	1.x
Programmer:	Andrew Perelson
Date:		August 2014		
Reason:		Initial Creation

*/
/***********************************************************************************************************/

CREATE function  [dbo].[fnGetDigZone] (
	@SourceOreBlockBUID int , 
	@Shot varchar(5))
returns int
AS
BEGIN
	DECLARE @PRODATTLKUPID INT

	SET @PRODATTLKUPID = NULL

	IF (ISNUMERIC(@Shot) = 1) 
	BEGIN
		SELECT	@PRODATTLKUPID = DigZone.PRODUCTIONATTLKUPID
					FROM 
					(SELECT BUSINESS_UNIT_ID, LINEITEMID
					 FROM LINEITEM
					 WHERE LINEITEMTYPEID = 19   ---<<<--- UPDATE THIS TO "Dig Zone Range" Line Item Type ID - DEV:13 UAT:19
					 AND ENABLED <> 0 
					 AND BUSINESS_UNIT_ID = (SELECT pitbu.RELATED_TO_BU_ID AS OperationBUID
 											FROM BUSINESS_UNIT pitbu
 											LEFT JOIN
 											BUSINESS_UNIT benchbu
 											ON benchbu.RELATED_TO_BU_ID = pitbu.BUSINESS_UNIT_ID
											LEFT JOIN
											BUSINESS_UNIT oreblockbu
											ON oreblockbu.RELATED_TO_BU_ID = benchbu.BUSINESS_UNIT_ID
											where oreblockbu.BUSINESS_UNIT_ID = @SourceOreBlockBUID)) LI

					LEFT JOIN

					(SELECT PRODUCTION_ID, BUSINESS_UNIT_ID, LINEITEMID, QUANTITY AS START_SHOT
					 FROM PRODUCTION
					 WHERE PRODUCTION_UNIT_ID = 35) STP   ---<<<--- UPDATE THIS TO "Dig Zone Start Shot" ProdAttVal (Measure Type) - DEV:16 UAT:35

					ON LI.LINEITEMID = STP.LINEITEMID

					LEFT JOIN

					(SELECT LINEITEMID, QUANTITY AS END_SHOT
					 FROM PRODUCTION
					 WHERE PRODUCTION_UNIT_ID = 36) ESP   ---<<<--- UPDATE THIS TO "Dig Zone End Shot" ProdAttVal (Measure Type) - DEV:17 UAT:36 

					ON LI.LINEITEMID = ESP.LINEITEMID

					LEFT JOIN

					(SELECT *
					 FROM PRODUCTIONATTVAL
					 WHERE PRODUCTIONATTID = 7) DigZone  ---<<<--- UPDATE THIS TO "Dig Zone" ProductionAtt (Measure Point Attribute) - DEV:3 UAT:7 

					ON STP.PRODUCTION_ID = DigZone.PRODUCTION_ID

					WHERE STP.BUSINESS_UNIT_ID = (SELECT pitbu.BUSINESS_UNIT_ID AS OperationBUID
 													FROM BUSINESS_UNIT pitbu
 													LEFT JOIN
 													BUSINESS_UNIT benchbu
 													ON benchbu.RELATED_TO_BU_ID = pitbu.BUSINESS_UNIT_ID
													LEFT JOIN
													BUSINESS_UNIT oreblockbu
													ON oreblockbu.RELATED_TO_BU_ID = benchbu.BUSINESS_UNIT_ID
													where oreblockbu.BUSINESS_UNIT_ID = @SourceOreBlockBUID)

					AND CAST(@Shot AS int) BETWEEN START_SHOT AND END_SHOT
	END

	return @PRODATTLKUPID
END


GO