

/*
server: globalSql.traxtech.com
database: CentralConfigRepl
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use CentralConfigRepl


select count(*) as [Count] from rate.GSK_KN_AIR_OCEAN_MASTER_RATES with (nolock)


select distinct trax_filename, count(*) as [count]
from 
rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
--trax_filename in ('GSK K+N Air - Ocean Rate Table Elavon 2019 V001.xlsx','GSK K+N Air - Ocean Rate Table Elavon 2019 V234.xlsx')
trax_filename like '%2020%'
group by trax_filename
order by 1


--as discussed with Loued V., GSK K+N Air - Ocean Rate Table Elavon 2019 V234.xlsx to be updated as V233 
--and GSK K+N Air - Ocean Rate Table Elavon 2019 V001.xlsx is to be updated to v234
--SUP-168947

--begin tran
--update rate.GSK_KN_AIR_OCEAN_MASTER_RATES
--set trax_filename = 'GSK K+N Air - Ocean Rate Table Elavon 2019 V234.xlsx'
--where
--trax_filename = 'GSK K+N Air - Ocean Rate Table Elavon 2019 V001.xlsx'

--commit tran

select distinct Mode, port_to_port_rate_uom, count(*) as [count] 
from 
rate.GSK_KN_AIR_OCEAN_MASTER_RATES
group by Mode, port_to_port_rate_uom
order by mode

if object_id('tempdb..#grtraw') is not null drop table #grtraw

select *
into #grtraw
from 
rate.GSK_KN_AIR_OCEAN_MASTER_RATES
WHERE
trax_filename like '%00%'

--and 
rate_code = 'K25283'


select distinct try_parse(valid_from as date using 'en-gb'), valid_from,
	 [TEST] = 
		case	when try_parse(valid_from as date using 'en-gb') < '2018-08-01' then 'valid_from < 8/1'
				when try_parse(valid_from as date using 'en-gb') >='2018-08-01' then 'valid_from >= 8/1'
				when try_parse(valid_from as date using 'en-gb') ='2018-08-01' then 'valid_from = 8/1'
			end, 
			*	
from #grtraw
where
status = 'ACTIVE' 
and NOT (try_parse(valid_from as date using 'en-gb') < '2018-08-01')
order by trax_created desc



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
rate_code = 'K63402'
order by 2 desc

