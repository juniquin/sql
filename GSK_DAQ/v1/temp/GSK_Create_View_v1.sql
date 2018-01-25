/*
server: ENVIDBSNAPSHOTSSQL.TRAXTECH.COM
database: Multiclient01_Snap_Test
table: rate.GSK_KN_AIR_OCEAN_MASTER_RATES
*/
Use Multiclient01_Snap_Test


------------------- create view -------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

create view rate.vw_GSK_KN_Air_Ocean_Master_Rates_v1
as

select
distinct
	[version] = trax_filename,
	[rate_code],
	[valid_from],
	[valid_to],
	[orig_country_code],
	[orig_city],
	[dest_country_code],
	[dest_city],
	[service_type],
	[temp_type],
	[equipment_load_size],
	[currency1],
	[FREIGHT] = try_cast([port_to_port_rate] as money),
	[FREIGHT_UOM] = [port_to_port_rate_uom],
	[FREIGHT_MIN] = try_cast([lhl_min] as money),
	[FREIGHT_MIN_UOM] = [lhl_min_uom],
	[PUC] = try_cast([orig_transport_cost] as money),
	[PUC_UOM] = [orig_transport_cost_uom],
	[OTC] as try_cast([PUC_MIN] as money),
	[PUC_MIN_UOM] = [OTC_UOM],
	[ATF] = try_cast([fixed_orig_acc_charges] as money),
	[ATF_UOM] = [fixed_orig_acc_charges_uom],
	[ATV] = try_cast([var_orig_acc_charges] as money),
	[var_orig_acc_charges_UOM] as [ATV_UOM],
	[DNT] = try_cast([DNT_MIN] as money,
	[DNT_UOM] = [DNT_MIN_UOM],
	[DNT_MIN] = try_cast([DNT] as money),
	[DNT_MIN_UOM] = [DNT_UOM],
	[DNF] = try_cast([DNF] as money),
	[DNF_UOM],
	[DNV] = try_cast([DNV] as money),
	[DNV_UOM],
	[DNS] = try_cast([DNS] as money),
	[DNS_UOM],
	[DOH] = try_cast([DOH] as money),
	[DOH_UOM],
	[240] = try_cast([240] as money),
	[240_UOM],
	[CF1] = try_cast([CF1] as money),
	[CF1_UOM],
	[762] = try_cast([762] as money),
	[762_UOM],
	[PKL] = try_cast([PKL] as money),
	[PKL_UOM],
	[CRS] = try_cast([CRS] as money),
	[CRS_UOM],
	[470] = try_cast([470] as money),
	[470_UOM],
	[SRG] = try_cast([240] as money),
	[SRG_UOM]
from rate.GSK_KN_AIR_OCEAN_MASTER_RATES