
/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/

Use Multiclient01_Snap_Test


-- @mode, @cat, @accgroup, @displayWithIssue

/*
exec rate.usp_GSK_KN_SourceRates_v1 
		'air',							-- 'Air', 'Ocean FCL', 'Ocean LCL'
		'accessorial',					-- 'Freight', 'Accessorial'
		'others2',						-- [for ACCESSORIAL ONLY, not required for FREIGHT (any value or empty)] 
											--> expected input [['Origin', 'Destination', 'Others1', 'Others2']]	||	Origin-[PUC, ATV, ATF] | Destination-[DNT, DNF, DNV, DOH, 240] | Others1-[470, 762, CF1] | Others2-[CRS, PKL, SRG]
		1								-- 1-[display rows not populated on separate grid]	0-[will not display rows not populated on separate grid]
*/


exec rate.usp_GSK_KN_SourceRates_v1 'Air', 'freight', '', 1





