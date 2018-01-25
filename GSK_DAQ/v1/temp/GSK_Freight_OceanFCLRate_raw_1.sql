/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use Multiclient01_Snap_Test


------------------- All OceanFCL Rate ------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#OceanFCL') is not null drop table #OceanFCL
select * into #OceanFCL
from rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
	mode like '%FCL%'
/*
select top 5 * from #OceanFCL
select count(*) as [rowcount] from #OceanFCL
*/



------------------- All OceanFCL FREIGHT Rate ----------------------------------------------------------
---------------------------------------------------------------------------------------------------


if object_id('tempdb..#OceanFCLFreightRaw') is not null drop table #OceanFCLFreightRaw
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
into #OceanFCLFreightRaw 
from #OceanFCL
--where
--rate_code = 'K51123'


Update #OceanFCLFreightRaw
set
	[version] = 
			case when [version] like '%2017%' 
				then replace(substring([version], charindex('2017', [version], 1), len([version])-(charindex('2017', [version], 1)-1)), '.xlsx', '')
				 when [version] not like '%2017%'
				then concat('2016', replace(substring([version], charindex(' V', [version], 1), len([version])-(charindex('Elavon', [version], 1)-1)), '.xlsx', ''))
			end

--select * from #OceanFCLFreightRaw
--order by
--	rate_code, [version] desc, valid_from desc, valid_to, rate, orig_city, equipment_load_size





--------------------- Distinct OceanFCL FREIGHT Rate (Used Latest Version) ---------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#OceanFCLFreightRaw_version') is not null drop table #OceanFCLFreightRaw_version
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
into #OceanFCLFreightRaw_version 
from #OceanFCLFreightRaw
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


select * from #OceanFCLFreightRaw_version
where
rate_code in ('K25279','K25283','K50066','K50184','K50401','K50419')
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