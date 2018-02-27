

/*
server: globalSql.traxtech.com
database: CentralConfigRepl
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use CentralConfigRepl


select count(*) from rate.GSK_KN_AIR_OCEAN_MASTER_RATES with (nolock)


select distinct trax_filename, count(*) as [count]
from 
rate.GSK_KN_AIR_OCEAN_MASTER_RATES
group by trax_filename
order by 1

select distinct Mode, port_to_port_rate_uom, count(*) as [count] 
from 
rate.GSK_KN_AIR_OCEAN_MASTER_RATES
group by Mode, port_to_port_rate_uom
order by mode



select *
from 
rate.GSK_KN_AIR_OCEAN_MASTER_RATES
WHERE
trax_filename like '%v64%'
--and rate_code = 'K52914'


/*
GSK K+N Air - Ocean Rate Table 2017 V1.xlsx
GSK K+N Air - Ocean Rate Table Elavon V137.xlsx
*/

/*
GSK_K+N_Air_-_Ocean_Rate_Table_Elavon_2017 V53 (3).xlsx		- NOT CRITICAL -	1 row of rate code K54490 not populated - DUPLICATE
GSK K+N Air - Ocean Rate Table Elavon 2017 V55.xlsx			- NOT CRITICAL -	1 row of rate code K54490 not populated - DUPLICATE; loaded twice
GSK K+N Air - Ocean Rate Table Elavon 2017 V56 (1).xlsx		- NOT CRITICAL -	1 row of rate code K54490 not populated - DUPLICATE; loaded twice	
GSK K+N Air - Ocean Rate Table Elavon 2017 V57 (1).xlsx		- NOT CRITICAL -	1 row of rate code K54490 not populated - DUPLICATE

GSK K+N Air - Ocean Rate Table Elavon 2017 V58 (1).xlsx		- NOT CRITICAL -	1 row of rate code K54490 not populated - DUPLICATE; 
															  CRITICAL	   -	for Analyst - incorrect data populated in GRT (row 10312 - 10321) starting column BU
*/




select DISTINCT * from rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
--trax_filename = 'GSK K+N Air - Ocean Rate Table Elavon 2017 V57 (1).xlsx'
--and 
rate_code = 'K60064'


