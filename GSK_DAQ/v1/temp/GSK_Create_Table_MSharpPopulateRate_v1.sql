
/*
created by: Juanito.Quinlog
date: 12/27/2017
purpose: GSK rate population through SQL
ticket: AC-2266

server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
*/



USE [Multiclient01_Snap_Test]



CREATE TABLE [rate].[GSK_KN_MSharp_Populate_Rate_FREIGHT]
(
	[version] varchar(150) NOT NULL,
	[valid_from] varchar(50) NOT NULL,
	[valid_to] varchar(50) NOT NULL,
	[rate_code] varchar(20) NOT NULL,
	[orig_city] varchar(230),
	[orig_country_code] varchar(115),
	[dest_city] varchar(230),
	[dest_country_code] varchar(115),
	[equipment_load_size] varchar(125),
	[rate] varchar(50),
	[currency] varchar(15),
	[rate_base_uom] varchar(100),
	[minimum_charge] varchar(50),
	[rate_type] varchar(100)
)
CREATE CLUSTERED INDEX ix_version_date_ratecode on [rate].[GSK_KN_MSharp_Populate_Rate_FREIGHT]([version], [valid_from], [valid_to], [rate_code])




