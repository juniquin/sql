


/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use Multiclient01_Snap_Test


--select top 10 * from rate.GSK_KN_AIR_OCEAN_MASTER_RATES

if object_id('tempdb..#rates') is not null drop table #rates
select distinct
	[input_date],
	[date_of_submission],
	[trax_filename],
	[version] = trax_filename,
	[action],
	[mode],
	[rate_code],
	[valid_from],
	[valid_to],
	[status],
	[orig_country_code],
	[orig_city],
	[dest_country_code],
	[dest_city],
	[service_type],
	[temp_type],
	[equipment_load_size],
	[currency1],
	[port_to_port_rate] as [FREIGHT],
	[port_to_port_rate_uom] as [FREIGHT_UOM],
	[lhl_min] as [FREIGHT_MIN],
	[lhl_min_uom] as [FREIGHT_MIN_UOM],
	[orig_transport_cost] as [PUC],
	[orig_transport_cost_uom] as [PUC_UOM],
	[OTC] as [PUC_MIN],
	[OTC_UOM] as [PUC_MIN_UOM],
	[fixed_orig_acc_charges] as [ATF],
	[fixed_orig_acc_charges_uom] as [ATF_UOM],
	[var_orig_acc_charges] as [ATV],
	[var_orig_acc_charges_UOM] as [ATV_UOM],
	[DNT_MIN] as [DNT],
	[DNT_MIN_UOM] as [DNT_UOM],
	[DNT] as [DNT_MIN],
	[DNT_UOM] as [DNT_MIN_UOM],
	[DNF],
	[DNF_UOM],
	[DNV],
	[DNV_UOM],
	[DNS],
	[DNS_UOM],
	[DOH],
	[DOH_UOM],
	[240],
	[240_UOM],
	[CF1],
	[CF1_UOM],
	[762],
	[762_UOM],
	[PKL],
	[PKL_UOM],
	[CRS],
	[CRS_UOM],
	[470],
	[470_UOM],
	[SRG],
	[SRG_UOM]
into #rates
from rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
	rate_code in ('K50252','K25279')








Update #rates
set
	[version] = 
			case when [version] like '%2017%' 
				then replace(substring([version], charindex('2017', [version], 1), len([version])-(charindex('2017', [version], 1)-1)), '.xlsx', '')
				 when [version] not like '%2017%'
				then concat('2016', replace(substring([version], charindex(' V', [version], 1), len([version])-(charindex('Elavon', [version], 1)-1)), '.xlsx', ''))
			end


select * from #rates
order by 
	rate_code, [version] desc, valid_from desc, valid_to, orig_city

