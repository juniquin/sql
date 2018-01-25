/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use Multiclient01_Snap_Test


------------------- All OceanLCL Rate ------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#OceanLCL') is not null drop table #OceanLCL
select * into #OceanLCL
from rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
	mode like '%LCL%'
/*
select top 5 * from #OceanLCL
select count(*) as [rowcount] from #OceanLCL
*/



------------------- All OceanLCL FREIGHT Rate ----------------------------------------------------------
---------------------------------------------------------------------------------------------------


if object_id('tempdb..#OceanLCLFreightRaw') is not null drop table #OceanLCLFreightRaw
select distinct 
	comment = trax_filename,
	[version] = trax_filename,
	valid_from,
	valid_to,
	rate_code,
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	equipment_load_size,
	rate = port_to_port_rate,
	currency1,
	rate_base_uom = port_to_port_rate_uom,
	minimum_charge = lhl_min,
	orig_port = NULL,
	orig_region = NULL,
	dest_port = NULL,
	dest_region = NULL,
	service_type = NULL,
	temp_type = NULL,
	weight_range_from = NULL,
	weight_range_thru = NULL,
	qualifier = NULL,
	identifier = NULL,
	quantity_range_from = NULL,
	quantity_range_thru = NULL,
	rate_type = port_to_port_rate_uom,
	maximum_charge = NULL,
	stepped_add_on = NULL,
	flat_add_on = NULL,
	rate_basis = port_to_port_rate_uom,
	rate_basis_quantity = NULL,
	rounding_type = NULL,
	scalar = NULL,
	stepped_threshold = NULL,
	dim_factor = NULL
into #OceanLCLFreightRaw 
from #OceanLCL
--where
--rate_code = 'K51123'


Update #OceanLCLFreightRaw
set
	[version] = 
			case when [version] like '%2017%' 
				then replace(substring([version], charindex('2017', [version], 1), len([version])-(charindex('2017', [version], 1)-1)), '.xlsx', '')
				 when [version] not like '%2017%'
				then concat('2016', replace(substring([version], charindex(' V', [version], 1), len([version])-(charindex('Elavon', [version], 1)-1)), '.xlsx', ''))
			end

--select * from #OceanLCLFreightRaw
--order by
--	rate_code, [version] desc, valid_from desc, valid_to, rate, orig_city, equipment_load_size





--------------------- Distinct OceanLCL FREIGHT Rate (Used Latest Version) ---------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#OceanLCLFreightRaw_version') is not null drop table #OceanLCLFreightRaw_version
select distinct
	max([version]) as [version], 
	--max(comment) as [comment],
	--[status],
	valid_from,
	valid_to,
	rate_code,
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	equipment_load_size,
	rate,
	currency1,
	rate_base_uom,
	minimum_charge,
	orig_port,
	orig_region,
	--dest_city,
	--dest_country_code,
	dest_port,
	dest_region,
	service_type,
	temp_type,
	--equipment_load_size,
	weight_range_from,
	weight_range_thru,
	qualifier,
	identifier,
	quantity_range_from,
	quantity_range_thru,
	--rate = port_to_port_rate,
	--currency1,
	rate_type,
	--minimum_charge = lhl_min,
	maximum_charge,
	stepped_add_on,
	flat_add_on,
	rate_basis,
	--rate_base_uom = port_to_port_rate_uom,
	rate_basis_quantity,
	rounding_type,
	scalar,
	stepped_threshold,
	dim_factor
into #OceanLCLFreightRaw_version 
from #OceanLCLFreightRaw
group by 
 	--[status],
	valid_from,
	valid_to,
	rate_code,
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	equipment_load_size,
	rate,
	currency1,
	rate_base_uom,
	minimum_charge,
	orig_port,
	orig_region,
	--dest_city,
	--dest_country_code,
	dest_port,
	dest_region,
	service_type,
	temp_type,
	--equipment_load_size,
	weight_range_from,
	weight_range_thru,
	qualifier,
	identifier,
	quantity_range_from,
	quantity_range_thru,
	--rate = port_to_port_rate,
	--currency1,
	rate_type,
	--minimum_charge = lhl_min,
	maximum_charge,
	stepped_add_on,
	flat_add_on,
	rate_basis,
	--rate_base_uom = port_to_port_rate_uom,
	rate_basis_quantity,
	rounding_type,
	scalar,
	stepped_threshold,
	dim_factor


select * from #OceanLCLFreightRaw_version
order by rate_code, [version] desc, valid_from desc, valid_to, rate, orig_city, equipment_load_size

















/*


select * from #temp1
order by [version] desc



select comment, charindex('2017', [comment], 1),len(comment)-(charindex('2017', [comment], 1)-1) as [charindex],
	replace(substring(comment, charindex('2017', [comment], 1), len(comment)-(charindex('2017', [comment], 1)-1)), '.xlsx', '') as [2017],
	concat('2016', replace(substring(comment, charindex(' V', [comment], 1), len(comment)-(charindex('Elavon', [comment], 1)-1)), '.xlsx', '')) as [2016]
from #temp1
order by comment



Update #temp1
set
	[version] = 
			case when [version] like '%2017%' 
				then replace(substring([version], charindex('2017', [version], 1), len([version])-(charindex('2017', [version], 1)-1)), '.xlsx', '')
				 when [version] not like '%2017%'
				then concat('2016', replace(substring(comment, charindex(' V', [comment], 1), len(comment)-(charindex('Elavon', [comment], 1)-1)), '.xlsx', ''))
			end


*/