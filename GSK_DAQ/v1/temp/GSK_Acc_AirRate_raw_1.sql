/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use Multiclient01_Snap_Test


------------------- [1] All Air Rate --------------------------------------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#AirAcc') is not null drop table #AirAcc
select * into #AirAcc
from rate.GSK_KN_AIR_OCEAN_MASTER_RATES
where
	mode = 'Air'

--select top 10 * from #AirAcc
--select count(*) as [rowcount] from #AirAcc



------------------- [2] ALL Air Accessorial Rate --------------------------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#AirAccRaw') is not null drop table #AirAccRaw
select distinct
	trax_filename,
	[version] = trax_filename,
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
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
	[762] = try_cast([762] as varchar(200)),
	[762_UOM],
	[PKL],
	[PKL_UOM],
	[CRS],
	[CRS_UOM],
	[470] = try_cast([470] as varchar(200)),
	[470_UOM],
	[SRG],
	[SRG_UOM]
into #AirAccRaw
from #AirAcc
--where
--	rate_code in ('K50252','K25279')

	
Update #AirAccRaw
set
	[version] = 
			case when [version] like '%2017%' 
				then replace(substring([version], charindex('2017', [version], 1), len([version])-(charindex('2017', [version], 1)-1)), '.xlsx', '')
				 when [version] not like '%2017%'
				then concat('2016', replace(substring([version], charindex(' V', [version], 1), len([version])-(charindex('Elavon', [version], 1)-1)), '.xlsx', ''))
			end

--select * from #AirAccRaw
--order by
--	rate_code, [version] desc, valid_from desc, valid_to, orig_city



------------------- [3] Distinct Air Accessorial Rate (Used Latest Version) ---------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#AirAccRaw_Version') is not null drop table #AirAccRaw_Version
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	[PUC],
	[PUC_UOM],
	[PUC_MIN],
	[PUC_MIN_UOM],
	[ATF],
	[ATF_UOM],
	[ATV],
	[ATV_UOM],
	[DNT],
	[DNT_UOM],
	[DNT_MIN],
	[DNT_MIN_UOM],
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
into #AirAccRaw_Version
from #AirAccRaw
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	[PUC],
	[PUC_UOM],
	[PUC_MIN],
	[PUC_MIN_UOM],
	[ATF],
	[ATF_UOM],
	[ATV],
	[ATV_UOM],
	[DNT],
	[DNT_UOM],
	[DNT_MIN],
	[DNT_MIN_UOM],
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


--select * from #AirAccRaw_Version
--order by
--	rate_code, [version] desc, valid_from desc, valid_to, orig_city


------------------- [4.1.1] RAW UNPIVOT ORIGIN Air Accessorial Rate -------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#OrigAirAccRawUnpivot') is not null drop table #OrigAirAccRawUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	puc_uom,
	atf_uom,
	atv_uom,
	uom = 
		case when charge_code = 'PUC' then puc_uom
			 when charge_code = 'ATF' then atf_uom
			 when charge_code = 'ATV' then atv_uom
			 else ''
		end,
	puc_min,
	minimum = 
		case when charge_code = 'PUC' then puc_min
			 else ''
		end
into #OrigAirAccRawUnpivot
from #AirAccRaw_Version
	unpivot
	(	
		rate
		for charge_code in ([PUC], [ATF], [ATV])
	) as o
where
	rate <> '0'
	and rate is not NULL
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	puc_uom,
	atf_uom,
	atv_uom,
	puc_min

	
------------------- [4.1.2] UNPIVOT ORIGIN Air Accessorial Rate -----------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#OrigAirAccUnpivot') is not null drop table #OrigAirAccUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum
into #OrigAirAccUnpivot
from #OrigAirAccRawUnpivot
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum


-- [DISPLAY]

select * from #OrigAirAccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, orig_city



------------------- [4.2.1] RAW UNPIVOT DESTINATION Air Accessorial Rate --------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#DestAirAccRawUnpivot') is not null drop table #DestAirAccRawUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	dnt_uom,
	dnf_uom,
	dnv_uom,
	dns_uom,
	doh_uom,
	[240_uom],
	uom = 
		case when charge_code = 'DNT' then dnt_uom
			 when charge_code = 'DNF' then dnf_uom
			 when charge_code = 'DNV' then dnv_uom
			 when charge_code = 'DOH' then doh_uom
			 when charge_code = '240' then [240_uom]
			 else ''
		end,
	dnt_min,
	minimum = 
		case when charge_code = 'DNT' then dnt_min
			 else ''
		end
into #DestAirAccRawUnpivot
from #AirAccRaw_Version
	unpivot
	(	
		rate
		for charge_code in ([DNT], [DNF], [DNV], [DNS], [DOH], [240])
	) as d
where
	rate <> '0'
	and rate is not NULL
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	dnt_uom,
	dnf_uom,
	dnv_uom,
	dns_uom,
	doh_uom,
	[240_uom],
	dnt_min

------------------- [4.2.2] UNPIVOT DESTINATION Air Accessorial Rate ------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#DestAirAccUnpivot') is not null drop table #DestAirAccUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum =
		case when minimum = '0' then ''
			else minimum
		end
into #DestAirAccUnpivot
from #DestAirAccRawUnpivot
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum


-- [DISPLAY]
select * from #DestAirAccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, orig_city



------------------- [4.3.1] RAW UNPIVOT OTHER_1 Air Accessorial Rate ------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#Other1AirAccRawUnpivot') is not null drop table #Other1AirAccRawUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	[470_uom],
	[762_uom],
	cf1_uom,
	uom = 
		case when charge_code = '470' then [470_uom]
			 when charge_code = '762' then [762_uom]
			 when charge_code = 'CF1' then cf1_uom
			 else ''
		end,
	minimum = ''
into #Other1AirAccRawUnpivot
from #AirAccRaw_Version
	unpivot
	(	
		rate
		for charge_code in ([470], [762], [CF1])
	) as o1
where
	rate <> '0'
	and rate is not NULL
	and rate not like '%pass%'
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	[470_uom],
	[762_uom],
	cf1_uom

	
------------------- [4.3.2] UNPIVOT OTHER_1 Air Accessorial Rate ----------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#Other1AirAccUnpivot') is not null drop table #Other1AirAccUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum
into #Other1AirAccUnpivot
from #Other1AirAccRawUnpivot
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum


-- [DISPLAY]

select * from #Other1AirAccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, orig_city


------------------- [4.4.1] RAW UNPIVOT OTHER_2 Air Accessorial Rate ------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#Other2AirAccRawUnpivot') is not null drop table #Other2AirAccRawUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	CRS_uom,
	PKL_uom,
	SRG_uom,
	uom = 
		case when charge_code = 'CRS' then CRS_uom
			 when charge_code = 'PKL' then PKL_uom
			 when charge_code = 'SRG' then SRG_uom
			 else ''
		end,
	minimum = ''
into #Other2AirAccRawUnpivot
from #AirAccRaw_Version
	unpivot
	(	
		rate
		for charge_code in ([CRS], [PKL], [SRG])
	) as o1
where
	rate <> '0'
	and rate is not NULL
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	CRS_uom,
	PKL_uom,
	SRG_uom

	
------------------- [4.4.2] UNPIVOT OTHER_2 Air Accessorial Rate ----------------------------------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#Other2AirAccUnpivot') is not null drop table #Other2AirAccUnpivot
select distinct
	max([version]) as [version],
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum
into #Other2AirAccUnpivot
from #Other2AirAccRawUnpivot
group by
	valid_from,
	valid_to,
	rate_code,  
	orig_city,
	orig_country_code,
	dest_city,
	dest_country_code,
	charge_code,
	rate,
	uom,
	minimum


-- [DISPLAY]

select * from #Other2AirAccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, orig_city







--if object_id('tempdb..#AirAcc') is not null drop table #AirAcc
--select * into #AirAcc from (
--select * from #OrigAirAccUnpivot
--union
--select * from #DestAirAccUnpivot
--union
--select * from #Other1AirAccUnpivot
--union
--select * from #Other2AirAccUnpivot
--) as t

--select * from #AirAcc
--order by rate_code, charge_code, [version] desc, valid_from desc, orig_city



