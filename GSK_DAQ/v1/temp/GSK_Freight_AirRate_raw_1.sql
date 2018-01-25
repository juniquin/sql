/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use Multiclient01_Snap_Test


------------------- All Air Rate ------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#Air') is not null drop table #Air
select * into #Air
from rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
	mode = 'Air'

--select * from #Air
select count(*) as [rowcount_air] from #Air




------------------- All Air FREIGHT Rate ----------------------------------------------------------
---------------------------------------------------------------------------------------------------


if object_id('tempdb..#AirFreightRaw') is not null drop table #AirFreightRaw
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
	equipment_load_size = NULL,
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
into #AirFreightRaw 
from #Air
--where
--rate_code = 'K51123'


Update #AirFreightRaw
set
	[version] = 
			case when [version] like '%2017%' 
				then replace(substring([version], charindex('2017', [version], 1), len([version])-(charindex('2017', [version], 1)-1)), '.xlsx', '')
				 when [version] not like '%2017%'
				then concat('2016', replace(substring([version], charindex(' V', [version], 1), len([version])-(charindex('Elavon', [version], 1)-1)), '.xlsx', ''))
			end

--select * from #AirFreightRaw
--order by
--	rate_code, [version] desc, valid_from desc, valid_to, rate, orig_city

select count(*) as [rowcount_AirFreight] from #AirFreightRaw 



--------------------- Distinct Air FREIGHT Rate (Used Latest Version) ---------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#AirFreightRaw_version') is not null drop table #AirFreightRaw_version
select distinct
	max([version]) as [version], 
	valid_from,
	valid_to,
	rate_code,
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	rate,
	currency1,
	rate_base_uom,
	minimum_charge,
	orig_port,
	orig_region,
	dest_port,
	dest_region,
	service_type,
	temp_type,
	equipment_load_size,
	weight_range_from,
	weight_range_thru,
	qualifier,
	identifier,
	quantity_range_from,
	quantity_range_thru,
	rate_type,
	maximum_charge,
	stepped_add_on,
	flat_add_on,
	rate_basis,
	rate_basis_quantity,
	rounding_type,
	scalar,
	stepped_threshold,
	dim_factor
into #AirFreightRaw_version 
from #AirFreightRaw
group by 
	valid_from,
	valid_to,
	rate_code,
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	rate,
	currency1,
	rate_base_uom,
	minimum_charge,
	orig_port,
	orig_region,
	dest_port,
	dest_region,
	service_type,
	temp_type,
	equipment_load_size,
	weight_range_from,
	weight_range_thru,
	qualifier,
	identifier,
	quantity_range_from,
	quantity_range_thru,
	rate_type,
	maximum_charge,
	stepped_add_on,
	flat_add_on,
	rate_basis,
	rate_basis_quantity,
	rounding_type,
	scalar,
	stepped_threshold,
	dim_factor


select count(*) as [rowcount_version] from #AirFreightRaw_version


select * from #AirFreightRaw_version
where
	rate_code in ('K25279','K25283','K50066','K50184','K50401','K50419')
order by rate_code, [version] desc, valid_from desc, valid_to, rate, orig_city
















