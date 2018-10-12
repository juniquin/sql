

/*
server: globalSql.traxtech.com
database: CentralConfigRepl
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
--Use CentralConfigRepl


--[2]

-- TEST
-- exec rate.usp_GSK_KN_SourceRates_v2 'Ocean LCL', 'Accessorial', 'Origin', 'K50401'


ALTER PROCEDURE rate.usp_GSK_KN_SourceRates_v2
	(
	 @mode nvarchar(50),		-- 'Air', 'Ocean FCL', 'Ocean LCL'
	 @cat nvarchar(50),			-- 'Freight', 'Accessorial'
	 @accgroup nvarchar(50),	-- 'Origin', 'Destination', 'Others1', 'Others2'	=>	Origin-[PUC, ATV, ATF] | Destination-[DNT, DNF, DNV, DOH, 240] | Others1-[470, 762, CF1] | Others2-[CRS, PKL, SRG] | Freight-[Freight]
	 @ratecode nvarchar(230),	-- 'K12345'
	 @displaynotpopulated bit			-- 1-[display rows not populated]	0-[will not display rows not populated]
	)

AS
BEGIN

set @mode = ltrim(rtrim(@mode))
set @cat = ltrim(rtrim(@cat))
set @accgroup = ltrim(rtrim(@accgroup))
set @ratecode = replace(@ratecode, ' ', '')

print @ratecode

declare @query nvarchar(max)
set @query = N'EXEC rate.usp_GSK_KN_Rates_Create_View_v2 '''+@mode+''', '''+@cat+''', '''+@accgroup+''', '''+@ratecode+''' '
exec sp_executesql @query


if object_id('tempdb..#newratesRaw') is not null drop table #newratesRaw
select * into #newratesRaw from rate.vw_GSK_KN_SourceRates_Temp_v2

--select * from #newratesRaw



-------[AC-9195: Added version_year, version_sequence, version_num, effective date update]---------
---------------------------------------------------------------------------------------------------

if object_id('tempdb..#newratesVersion') is not null drop table #newratesVersion
select
[version_year] = cast(left([version], 4) as int),
[version_sequence] = cast(substring([version], charindex(' ', [version], 1) + 2, charindex(' ', reverse([version]), 1) - 2) as int),
	--[len] = len([version]),
	--[charindex] = charindex(' ', [version], 1) + 2,
	--[reverse] = reverse([version]),
	--[reversechar] = charindex(' ', reverse([version]), 1) - 2,
* into #newratesVersion 
from #newratesRaw

--select * from #newratesVersion


if object_id('tempdb..#newrates') is not null drop table #newrates
select
[version_num] = ([version_year] * 1000) + [version_sequence],
* into #newrates
from #newratesVersion


--update valid_from
update	#newrates
set valid_from = case	when [version_num] = 2018169 and try_parse(valid_to as date using 'en-gb') > '2018-08-01'
							then '2018-08-01'
						else valid_from
						end

--update valid_to
update	#newrates
set valid_to = case	when [version_num] < 2018169 and try_parse(valid_to as date using 'en-gb') >= '2018-08-01'
							then '2018-07-31'
						else valid_to
						end

--select * from #newrates
--order by  
--	rate_code, [version_year] desc, [version_sequence] desc, [version] desc, valid_from desc, valid_to, orig_city

---------------------------------------------------------------------------------------------------


if object_id('tempdb..##preparePopulateMSharp') is not null drop table ##preparePopulateMSharp
if object_id('tempdb..##overriden') is not null drop table ##overriden


------------------- [REFINE Source Rate for MSharp Rate Population] -------------------------------
---------------------------------------------------------------------------------------------------
if(@cat = 'FREIGHT') 
begin
declare @selectFreight nvarchar(max) = N'
if object_id(''tempdb..#forRank'') is not null drop table #forRank
SELECT distinct
max([version_num]) as [version], 
valid_from, valid_to, rate_code, orig_city, orig_country_code,
dest_city, dest_country_code, equipment_load_size, rate, currency, rate_base_uom as [uom], 
[minimum] = 
		case when minimum_charge = ''0'' then ''''
			 else minimum_charge
		end,
rate_type,
[rate_basis] = rate_base_uom
into #forRank
from 
	#newrates
where
	rate <> ''0''
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code,
	equipment_load_size, rate, currency, rate_base_uom, minimum_charge, rate_type


--select * from #forRank


------------------- [DISPLAY FREIGHT RATE] [RANK PARTITION] ---------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#rank1'') is not null drop table #rank1
select [rowrank] = ROW_NUMBER() OVER (PARTITION BY
valid_from, rate_code order by [version] desc, valid_from desc, valid_to desc, rate_code), *
into #rank1
from #forRank

------------------- [DISPLAY UNFILTERED RECORDS] --------------------------------------------------
select * from #rank1
order by 
	rate_code, [version] desc, valid_from desc, valid_to desc, orig_city
---------------------------------------------------------------------------------------------------

if object_id(''tempdb..##overriden'') is not null drop table ##overriden
select * 
INTO ##overriden
from #rank1
where
	rowrank > 1
order by 
	rate_code, [version] desc, valid_from desc, valid_to desc, orig_city


if object_id(''tempdb..##preparePopulateMSharp'') is not null drop table ##preparePopulateMSharp
select * 
INTO ##preparePopulateMSharp
from #rank1
where
	rowrank = 1
	'
end



if(@cat = 'ACCESSORIAL' and @accgroup = 'ORIGIN')
begin
declare @selectOrigAcc nvarchar(max) = N'
------------------- [1.1] RAW UNPIVOT ORIGIN Accessorial Rate -------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#OrigAccRawUnpivot'') is not null drop table #OrigAccRawUnpivot
select distinct
	max([version_num]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code,
	dest_city, dest_country_code,
	equipment_load_size, charge_code, rate, currency, puc_uom, atf_uom, atv_uom,
	uom = 
		case when charge_code = ''PUC'' then puc_uom
			 when charge_code = ''ATF'' then atf_uom
			 when charge_code = ''ATV'' then atv_uom
			 else ''''
		end,
	puc_min,
	minimum = 
		case when charge_code = ''PUC'' then puc_min
			 else ''''
		end
into #OrigAccRawUnpivot
from #newrates
	unpivot
	(	
		rate
		for charge_code in ([PUC], [ATF], [ATV])
	) as o
where
	rate <> ''0''
	and rate is not NULL
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, puc_uom, atf_uom, atv_uom, puc_min

	
------------------- [1.2] UNPIVOT ORIGIN Accessorial Rate -----------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#OrigAccUnpivot'') is not null drop table #OrigAccUnpivot
select distinct
	max([version]) as [version], valid_from
	, valid_to, rate_code, orig_city, orig_country_code,
	dest_city, dest_country_code, equipment_load_size, charge_code, rate, currency, uom,
	minimum =
		case when minimum = ''0'' then ''''
			else minimum
		end,
	rate_type = uom,
	rate_basis = uom,
	charge_desc = charge_code
into #OrigAccUnpivot
from #OrigAccRawUnpivot
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, uom, minimum


------------------- [1.3] [DISPLAY ORIGIN Accessorial Rate] [RANK PARTITION]-----------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#rank1'') is not null drop table #rank1
select [rowrank] = ROW_NUMBER() OVER (PARTITION BY
	valid_from, rate_code, charge_code order by rate_code, charge_code, [version] desc, valid_from desc, valid_to desc
	), * 
into #rank1
from #OrigAccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city


------------------- [DISPLAY UNFILTERED RECORDS] --------------------------------------------------
select * from #rank1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city
---------------------------------------------------------------------------------------------------


if object_id(''tempdb..##overriden'') is not null drop table ##overriden
select * 
INTO ##overriden
from #rank1
where
	rowrank > 1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city


if object_id(''tempdb..##preparePopulateMSharp'') is not null drop table ##preparePopulateMSharp
select * 
INTO ##preparePopulateMSharp
from #rank1
where
	rowrank = 1
'
end





if(@cat = 'ACCESSORIAL' and @accgroup = 'DESTINATION')
begin
declare @selectDestAcc nvarchar(max) = N'
------------------- [2.1] RAW UNPIVOT DESTINATION Accessorial Rate --------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#DestAccRawUnpivot'') is not null drop table #DestAccRawUnpivot
select distinct
	max([version_num]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, dnt_uom, dnf_uom, dnv_uom, dns_uom, doh_uom, [240_uom],
	uom = 
		case when charge_code = ''DNT'' then dnt_uom
			 when charge_code = ''DNF'' then dnf_uom
			 when charge_code = ''DNV'' then dnv_uom
			 when charge_code = ''DNS'' then dns_uom
			 when charge_code = ''DOH'' then doh_uom
			 when charge_code = ''240'' then [240_uom]
			 else ''''
		end,
	dnt_min,
	minimum = 
		case when charge_code = ''DNT'' then dnt_min
			 else ''''
		end
into #DestAccRawUnpivot
from #newrates
	unpivot
	(	
		rate
		for charge_code in ([DNT], [DNF], [DNV], [DNS], [DOH], [240])
	) as d
where
	rate <> ''0''
	and rate is not NULL
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, dnt_uom, dnf_uom, dnv_uom, dns_uom, doh_uom, [240_uom], dnt_min
	

------------------- [2.2] UNPIVOT DESTINATION Accessorial Rate ------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#DestAccUnpivot'') is not null drop table #DestAccUnpivot
select distinct
	max([version]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city,
	dest_country_code, equipment_load_size,	charge_code, rate, currency, uom,
	minimum =
		case when minimum = ''0'' then ''''
			else minimum
		end,
	rate_type = uom,
	rate_basis = uom,
	charge_desc = charge_code
into #DestAccUnpivot
from #DestAccRawUnpivot
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, uom, minimum


------------------- [2.3] [DISPLAY DESTINATION Accessorial Rate] [RANK PARTITION]------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#rank1'') is not null drop table #rank1
select [rowrank] = ROW_NUMBER() OVER (PARTITION BY
	valid_from, rate_code, charge_code order by rate_code, charge_code, [version] desc, valid_from desc, valid_to desc
	), * 
into #rank1
from #DestAccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city


------------------- [DISPLAY UNFILTERED RECORDS] --------------------------------------------------
select * from #rank1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city
---------------------------------------------------------------------------------------------------


if object_id(''tempdb..##overriden'') is not null drop table ##overriden
select * 
INTO ##overriden
from #rank1
where
	rowrank > 1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city

	
if object_id(''tempdb..##preparePopulateMSharp'') is not null drop table ##preparePopulateMSharp
select * 
INTO ##preparePopulateMSharp
from #rank1
where
	rowrank = 1
	'
end



if(@cat = 'ACCESSORIAL' and @accgroup = 'Others1')
begin
declare @selectOthers1Acc nvarchar(max) = N'
------------------- [3.1] RAW UNPIVOT OTHER_1 Accessorial Rate ------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#Others1AccRawUnpivot'') is not null drop table #Others1AccRawUnpivot
select distinct
	max([version_num]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, [470_uom], [762_uom], cf1_uom,
	uom = 
		case when charge_code = ''470'' then [470_uom]
			 when charge_code = ''762'' then [762_uom]
			 when charge_code = ''CF1'' then cf1_uom
			 else ''''
		end,
	minimum = ''''
into #Others1AccRawUnpivot
from #newrates
	unpivot
	(	
		rate
		for charge_code in ([470], [762], [CF1])
	) as o1
where
	rate <> ''0''
	and rate is not NULL
	and rate not like ''%pass%''
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, [470_uom], [762_uom], cf1_uom

	
------------------- [3.2] UNPIVOT OTHER_1 Accessorial Rate ----------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#Others1AccUnpivot'') is not null drop table #Others1AccUnpivot
select distinct
	max([version]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, uom, minimum,
	rate_type = uom,
	rate_basis = uom,
	charge_desc = charge_code
into #Others1AccUnpivot
from #Others1AccRawUnpivot
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, uom, minimum


------------------- [3.3] [DISPLAY OTHERS_1 Accessorial Rate] [RANK PARTITION]---------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#rank1'') is not null drop table #rank1
select [rowrank] = ROW_NUMBER() OVER (PARTITION BY
	valid_from, rate_code, charge_code order by rate_code, charge_code, [version] desc, valid_from desc, valid_to desc
	), * 
into #rank1
from #Others1AccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city

------------------- [DISPLAY UNFILTERED RECORDS] --------------------------------------------------
select * from #rank1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city
---------------------------------------------------------------------------------------------------


if object_id(''tempdb..##overriden'') is not null drop table ##overriden
select * 
INTO ##overriden
from #rank1
where
	rowrank > 1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city


if object_id(''tempdb..##preparePopulateMSharp'') is not null drop table ##preparePopulateMSharp
select * 
INTO ##preparePopulateMSharp
from #rank1
where
	rowrank = 1
	'
end



if(@cat = 'ACCESSORIAL' and @accgroup = 'Others2')
begin
declare @selectOthers2Acc nvarchar(max) = N'
------------------- [4.1] RAW UNPIVOT OTHER_2 Accessorial Rate ------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#Others2AccRawUnpivot'') is not null drop table #Others2AccRawUnpivot
select distinct
	max([version_num]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, CRS_uom, PKL_uom, SRG_uom,
	uom = 
		case when charge_code = ''CRS'' then CRS_uom
			 when charge_code = ''PKL'' then PKL_uom
			 when charge_code = ''SRG'' then SRG_uom
			 else ''''
		end,
	minimum = ''''
into #Others2AccRawUnpivot
from #newrates
	unpivot
	(	
		rate
		for charge_code in ([CRS], [PKL], [SRG])
	) as o1
where
	rate <> ''0''
	and rate is not NULL
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, CRS_uom, PKL_uom, SRG_uom

	
------------------- [4.2] UNPIVOT OTHER_2 Accessorial Rate ----------------------------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#Others2AccUnpivot'') is not null drop table #Others2AccUnpivot
select distinct
	max([version]) as [version], valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, uom, minimum,
	rate_type = uom,
	rate_basis = uom,
	charge_desc = charge_code
into #Others2AccUnpivot
from #Others2AccRawUnpivot
group by
	valid_from, valid_to, rate_code, orig_city, orig_country_code, dest_city, dest_country_code, equipment_load_size,
	charge_code, rate, currency, uom, minimum


------------------- [4.3] [DISPLAY OTHERS_2 Accessorial Rate] [RANK PARTITION]---------------------
---------------------------------------------------------------------------------------------------
if object_id(''tempdb..#rank1'') is not null drop table #rank1
select [rowrank] = ROW_NUMBER() OVER (PARTITION BY
	valid_from, rate_code, charge_code order by rate_code, charge_code, [version] desc, valid_from desc, valid_to desc
	), * 
into #rank1
from #Others2AccUnpivot
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city


------------------- [DISPLAY UNFILTERED RECORDS] --------------------------------------------------
select * from #rank1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city
---------------------------------------------------------------------------------------------------


if object_id(''tempdb..##overriden'') is not null drop table ##overriden
select * 
INTO ##overriden
from #rank1
where
	rowrank > 1
order by 
	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city


if object_id(''tempdb..##preparePopulateMSharp'') is not null drop table ##preparePopulateMSharp
select * 
INTO ##preparePopulateMSharp
from #rank1
where
	rowrank = 1
	'
end


------------------- [SELECT EXECUTION] ------------------------------------------------------------
---------------------------------------------------------------------------------------------------
if(@cat = 'Freight')
	begin exec sp_executesql @selectFreight end
if(@cat = 'Accessorial' and @accgroup = 'Origin')
	begin exec sp_executesql @selectOrigAcc end
if(@cat = 'Accessorial' and @accgroup = 'Destination')
	begin exec sp_executesql @selectDestAcc end
if(@cat = 'Accessorial' and @accgroup = 'Others1')
	begin exec sp_executesql @selectOthers1Acc end	 
if(@cat = 'Accessorial' and @accgroup = 'Others2')
	begin exec sp_executesql @selectOthers2Acc end


------------------- [ROWS NOT POPULATED | WITH ISSUE/s] -------------------------------------------
---------------------------------------------------------------------------------------------------
if object_id('tempdb..#notPopulated_withIssue') is not null drop table #notPopulated_withIssue
select * into #notPopulated_withIssue from ##preparePopulateMSharp
where
	isdate(valid_from) = 0
	or isdate(valid_to) = 0
	or try_parse(valid_from as date using 'en-gb') > try_parse(valid_to as date using 'en-gb')


if object_id('tempdb..#notPopulated_overriden') is not null drop table #notPopulated_overriden
select * into #notPopulated_overriden from ##overriden
	

declare @notPopulated nvarchar(max) = N'
	select
		[remarks] = 
			case when isdate(valid_from) = 0 and isdate(valid_to) = 1 then ''invalid format [VALID_FROM] date''
				 when isdate(valid_to) = 0 and isdate(valid_from) = 1 then ''invalid format [VALID_TO] date''
				 when isdate(valid_from) = 0 and isdate(valid_to) = 0 then ''invalid format [VALID_TO] and [VALID_FROM] date''
				 when try_parse(valid_from as date using ''en-gb'') > try_parse(valid_to as date using ''en-gb'') then ''[VALID_FROM] is greater than [VALID_TO]''
			end,
			*
	from #notPopulated_withIssue
	--order by
	--	[version] desc, rate_code, valid_from desc, valid_to desc, orig_city
	
	UNION

	select
		[remarks] = ''Overriden by the latest version/s'',
		*
	from #notPopulated_overriden
		--order by
		--[version] desc, rate_code, valid_from desc, valid_to desc, orig_city
	'


delete from ##preparePopulateMSharp
where
	isdate(valid_from) = 0
	or isdate(valid_to) = 0
	or try_parse(valid_from as date using 'en-gb') > try_parse(valid_to as date using 'en-gb')


------------------- [DISPLAY ROWS NOT FOR POPULATED | WITH ISSUE/s] -------------------------------
---------------------------------------------------------------------------------------------------
if(@cat = 'FREIGHT')
	begin set @notPopulated = @notPopulated + N'
		order by
			rate_code, [version] desc, valid_from desc, valid_to desc, orig_city
			'
	end

if(@cat = 'ACCESSORIAL')
	begin set @notPopulated = @notPopulated + N'
		order by
			rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city
			'
	end

if(@displaynotpopulated = 1)
	begin exec sp_executesql @notPopulated end


------------------- [1st REFINE columns] ----------------------------------------------------------
---------------------------------------------------------------------------------------------------
update ##preparePopulateMSharp
set equipment_load_size = 
		case when equipment_load_size like '%40%' then '40'
			 when equipment_load_size like '%20%' then '20'
			 when equipment_load_size like '%road%' then ''
			 when equipment_load_size like '%Weight%' then ''
			 when equipment_load_size like '%45%' then '45'
			 when equipment_load_size like '%LCL%' then 'LCL'
			 when equipment_load_size is NULL then ''
			 else equipment_load_size
			end

update ##preparePopulateMSharp
set rate_type = 
		case when uom like '%KG%' then 'Per'
			 when uom like '%CNTR%' then 'Per'
			 when uom like '%CBM%' then 'Per'
			 when uom like '%SHIPMENT%' then 'Flat'
			 when uom like '%Freight%' then 'Per'
			 when uom like '%HR%' then 'Per'
			 when uom like '%PACK%' then 'Per'
			 when uom like '%DOC%' then 'Flat'
			 when uom like '%PLT%' then 'Per'
			 when uom like '%PALLET%' then 'Per'
			 else ''
		end

update ##preparePopulateMSharp
set rate_basis = 
		case when uom like '%KG%' then 'Financial Weight'
			 when uom like '%CNTR%' then 'Container'
			 when uom like '%CBM%' then 'Volume'
			 when uom like '%SHIPMENT%' then 'None'
			 when uom like '%Freight%' then 'Freight Charge'
			 when uom like '%HR%' then 'Unit Quantity'
			 when uom like '%PACK%' then 'Unit Quantity'
			 when uom like '%DOC%' then 'None'
			 when uom like '%PLT%' then 'Pallet'
			 when uom like '%PALLET%' then 'Pallet'
			 else ''
		end


update ##preparePopulateMSharp
set uom = ''

update ##preparePopulateMSharp
set minimum = 
		case when minimum is NULL then ''
			 when minimum = '0' then ''
			 when minimum like '%/%' then ''
			 else minimum
		end
	
if (@cat = 'ACCESSORIAL')
begin
update ##preparePopulateMSharp
set charge_desc =  
		case when charge_code = 'PUC' then 'ORIGIN TRANSPORT COST'
			 when charge_code = 'ATF' then 'FIXED ORIGIN ACCESSORIAL CHARGES'
			 when charge_code = 'ATV' then 'VARIABLE ORIGIN ACCESSORIAL CHARGES'
			 when charge_code = 'DNT' then 'DESTITION TRANSPORT COST'
			 when charge_code = 'DNF' then 'TOTAL FIXED DESTITION ACCESSORIAL CHARGES'
			 when charge_code = 'DNV' then 'VARIABLE DESTITION ACCESSORIAL CHARGES'
			 when charge_code = 'DNS' then 'DESTITION SECURITY CHARGES'
			 when charge_code = 'DOH' then 'DOCUMENTATION HANDOVER FEE'
			 when charge_code = '240' then 'DESTITION CUSTOMS BROKAGE CHARGES'
			 when charge_code = '470' then 'LETTER OF CREDIT'
			 when charge_code = '762' then 'X-RAY'
			 when charge_code = 'CF1' then 'CAF/RISK CHARGES'
			 when charge_code = 'CRS' then 'COURIER'
			 when charge_code = 'PKL' then 'Packing Labour'
			 when charge_code = 'SRG' then 'STORAGE E9'
		end
end



--select * from ##preparePopulateMSharp

------------------- [PREPARE FOR MSHARP RATE POPULATION] ------------------------------------------
---------------------------------------------------------------------------------------------------
if(@cat = 'FREIGHT')
begin
if object_id('tempdb..#populateFreightRate') is not null drop table #populateFreightRate
select distinct 
	--comment = [version],
	valid_from, valid_to, rate_code, 
	orig_city = '',
	orig_country_code,
	orig_port = '',
	orig_region = '',
	dest_city = '',
	dest_country_code,
	dest_port = '',
	dest_region = '',
	service_type = '',
	temperature_type = '',
	equipment_load_size = '',
	weight_from = '',
	weight_to = '',
	qualifier = '',
	identifier = '',
	quantity_from = '',
	quantity_to = '',
	rate,
	currency,
	rate_type,
	minimum,
	maximum_charge = '',
	stepped_addon = '',
	flat_addon = '',
	rate_basis,
	uom,
	rate_base_quantity = '',
	rounding_type = '',
	scalar = '',
	stepped_threshold = '',
	dim_factor = '',
	comment = [version]
into #populateFreightRate
from ##preparePopulateMSharp
where
	rate not like '%/%'

select * from #populateFreightRate
order by 
	rate_code, comment desc, valid_from desc, valid_to desc
end

if(@cat = 'ACCESSORIAL')
begin
if object_id('tempdb..#populateAccRate') is not null drop table #populateAccRate
select distinct 
	--comment = [version], 
	valid_from, valid_to, rate_code, charge_code,
	orig_city = '',
	orig_country_code,
	orig_port = '',
	orig_region = '',
	dest_city = '',
	dest_country_code,
	dest_port = '',
	dest_region = '',
	service_type = '',
	temperature_type = '',
	equipment_load_size = '',
	weight_from = '',
	weight_to = '',
	qualifier = '',
	identifier = '',
	quantity_from = '',
	quantity_to = '',
	charge_desc,
	rate,
	currency,
	rate_type,
	minimum,
	maximum_charge = '',
	stepped_addon = '',
	flat_addon = '',
	rate_basis,
	uom,
	rate_base_quantity = '',
	rounding_type = '',
	scalar = '',
	stepped_threshold = '',
	dim_factor = '',
	comment = [version]
into #populateAccRate
from ##preparePopulateMSharp
where
	rate not like '%/%'


------------------- [2nd REFINE columns [CUSTOM]] -------------------------------------------------
---------------------------------------------------------------------------------------------------
update #populateAccRate
set rate_type = 
		case when charge_code = '240' and rate_type = '' then 'Flat'
			 when charge_code = 'CF1' and rate_type = '' then 'Per'
			 else rate_type
		end

update #populateAccRate
set rate_basis = 
		case when charge_code = '240' and rate_basis = '' then 'None'
			 when charge_code = 'CF1' and rate_basis = '' then 'Freight Charge'
			 else rate_basis
		end
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


select * from #populateAccRate
order by 
	rate_code, charge_code, comment desc, valid_from desc, valid_to desc


--select * from ##overriden
--order by 
--	rate_code, charge_code, [version] desc, valid_from desc, valid_to desc, orig_city

end



--be sure to execute below drop tables when altering the sproc.

if object_id('tempdb..##preparePopulateMSharp') is not null drop table ##preparePopulateMSharp
if object_id('tempdb..##overriden') is not null drop table ##overriden


END
GO








