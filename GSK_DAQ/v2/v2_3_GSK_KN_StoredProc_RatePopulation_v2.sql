
/*
server: globalSql.traxtech.com
database: CentralConfigRepl
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/

Use CentralConfigRepl


-- @mode, @cat, @accgroup, @ratecode, @displaynotpopulated

/*
exec rate.usp_GSK_KN_SourceRates_v2 
		'air',						-- 'Air', 'Ocean FCL', 'Ocean LCL'
		'accessorial',				-- 'Freight', 'Accessorial'
		'others2',					-- [for ACCESSORIAL ONLY, not required for FREIGHT (any value or empty)] 
								--> expected input [['Origin', 'Destination', 'Others1', 'Others2']]	||	Origin-[PUC, ATV, ATF] | Destination-[DNT, DNF, DNV, DOH, 240] | Others1-[470, 762, CF1] | Others2-[CRS, PKL, SRG]
		'K51123'					-- [Rate Code] ex. 'K51123' or 'K51123,K53092' or leave it empty parameter '' if you don't want to specify rate code/s
		1							-- 1-[display rows not populated on separate grid]	0-[will not display rows not populated on separate grid]
*/


exec rate.usp_GSK_KN_SourceRates_v2 'Air', 'freight', '', '', 1





