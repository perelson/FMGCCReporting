USE [VCI]
GO

/****** Object:  Table [dbo].[QuarantineODSTrucking]    Script Date: 16/09/2014 3:11:59 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

ALTER TABLE [dbo].[QuarantineODSTrucking]
ADD	[Shot] [varchar](50) NULL,
	[DigZoneID] [int] NULL,
	[DigZoneBUJATTID] [int] NULL,
	[OreWasteBUJATTID] [int] NULL

GO