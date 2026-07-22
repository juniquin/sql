--use hpiprod

--exec sp_helptext '[HpAms].[usp_GetMatchingDetails_S4GlobalAFM]'




--Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------








-- exec HpAms.usp_GetMatchingDetails_S4Global 'FBLL1000681003972450001',1,1,1,0
-- exec HpAms.usp_GetMatchingDetails_S4Global 'FBLL1000681005011380004',1,1,1,0
-- exec HpAms.usp_GetMatchingDetails_S4Global 'FBLL1000681005067000144',1,1,1,0
-- exec HpAms.usp_GetMatchingDetails_S4Global 'FBLL1000681005036160256',1,1,1,0
--FBLL1000671011018620001


--	   drop procedure HpAms.usp_GetMatchingDetails_S4GlobalAFM
 --CREATE procedure [HpAms].[usp_GetMatchingDetails_S4GlobalAFM]
  -- 			 @masterFbId varchar(23),
	--		 @AFMFlag bit = 0,
   	--		 @includeDebugInformation bit = 0,
   	--		 @returnCaLines bit = 1,
   	--		 @updateMatchMetrics bit = 1,
   	--		 @returnInvalidResults bit = 0
 --  as
  -- begin

 --  set nocount on

/*******************************************************************************
** Software Development
** Trax Holdings, Inc.
**
** Version:		1.0
** Author:		Rolando Vargas
**
** Overview:
**
** Revision History:
** When:		Who:  				What:
** 12/11/2014	Rolando Vargas		Creation
** 12/23/2014	Rolando Vargas		Update behavior completely. Do look based on values instead of Sql Emitted Ids.
** 12/23/2014	Rolando Vargas		When matched to a BOL, then pull all the DeliveryIDs for that BOL
** 01/06/2015	Rolando Vargas		Including CA Config Tab winner and line.
**									If there are more than 99 CA lines, then the Tab winner and line are removed and CA lines are regrouped.
** 01/07/2015	Rolando Vargas		Exclude Internal Orders whenever there are other DESADV that are not Internal Orders.
**									If there are only internal orders, then internal orders are used.
** 01/07/2015	Rolando Vargas		If there are Delivery IDs that are not Internal Orders, then exclude the Internal Orders (even if the Internal Order is the most recent DESADV).
** 02/10/2015	Rolando Vargas		Consider IC as internal order as well - to be excluded
** 02/11/2015	Rolando Vargas		Flag results as invalid when the Product Line (ca_elem_7) is different than 2 characters
** 02/17/2015	Rolando Vargas		Persist into dbo.HP_AMS_Desadv_Matched_Desadv_FbIds
** 03/16/2015	Rolando Vargas		removing "is null" when querying against the CA config tables for required fields. much fewer logical reads (issue caught by Daniel.Montero)
** 03/20/2015	Rolando Vargas		Always persist into dbo.HP_AMS_Desadv_Matched_Desadv_FbIds - not only when the CA results are valid
** 03/20/2015	Rolando Vargas		Remove return shipments
** 03/25/2015	Rolando Vargas		added optional parameter @updateMatchMetrics. Including matches to ACE
** 04/15/2015	Rolando Vargas		Prevent match for LA/DMCQ and US/DHLM using Inv Key to BOL
** 05/04/2015	Rolando Vargas		vendors DMCQ and DHLA for HP LA will have CA lines always invalid. These are the be used for matching but not for CA
** 05/05/2015	Rolando Vargas		when matched to a Sales Org CN09, remove the CN09 lines
**									When there are only Sales CN09, then flag results as invalid and let T003 be Match Missing CA
** 05/11/2015	Rolando Vargas		Updated to support to split (HPi)
** 06/03/2015	Rolando Vargas		ICS 561175: For DHLM US, do not allow match to be made with the InvKeyToAltShipId correlation.
** 09/08/2015	Rolando Vargas		Remove matches when using the qualifier 2I for SCACs 'SCIN' and 'FDEI'
** 10/06/2015	Rolando Vargas		Remove CR values for matching when they are a date of current year +/- 1
** 10/16/2015	Rolando Vargas		Update some temp tables to table variable
**									Added indexes to #documentInfo1 and #documentInfo
** 10/22/2015	Rolando Vargas		Including ASN Ship Date (requested by Dimi to see if the shipment is pre-split)
** 01/11/2016	Rolando Vargas		Removing metrics when not expected to match
** 01/12/2016	Rolando Vargas		Added columns at the end so it can be added as part of the standard CA methods
** 01/12/2016	Rolando Vargas		Populating CA_ELEM_9 and CA_ELEM_11
** 01/12/2016	Rolando Vargas		Adding General Validations just like the rest of other CA Methods
** 01/13/2016	Rolando Vargas		Split the weight of the lines evenly where there's no weight in the ASN
** 02/11/2016	Rolando Vargas		Update the new columns that were added for consistency with the rest of CA methods: [Results Error Message] and [Results Valid]
** 02/11/2016	Rolando Vargas		Updated so it can run from the environment database (such as HPiProd) instead of running it from HPiAmsDesadvMatching.
**                                  This is because of issues when generating multiple snapshot databases but sharing one single HPiAmsDesadvMatching database
** 02/11/2016	Rolando Vargas		Applying Entity Override template and making the results valid for LA for scacs DMCQ and DHLA
** 03/21/2016	Rolando Vargas		Adding use of PL in CA Config Templates
** 04/15/2016	Rolando Vargas		Adding tax line for LA region
** 04/15/2016	Rolando Vargas		Removing lines when they have no weight
** 04/17/2016	Rolando Vargas		Addressing issue where the line percentage was not being split evenly
** 04/26/2016	Rolando Vargas		Allowing BillToAccount to have optional values in HpAms.Desadv_Matched_Excluded
** 04/26/2016	Rolando Vargas		Using a function for Entity Override instead of a stored procedure to allow simulations (by avoiding the nested insert into exec issue)
** 04/26/2016	Rolando Vargas		Move on to next method when a CA configuration was not found
** 05/24/2016	Rolando Vargas		For HPi, exclude ASNs before 2015.08.01 (HP Split Date) - ICS 626904
** 07/15/2016	Rolando Vargas		When looking into the ASN table, use the matched value from MatchConceptString. Issue when mathced using normalized value CKG78000040 but actual value CKG-78000040 is not found
** 08/24/2016	Rolando Vargas		Add parameter @returnInvalidResults to return results even if no CA config was found - to enable CA winner: Matched needing CA config
** 09/29/2016	Rolando.Vargas		removing qualifer CN for SCAC DDAG - ICS 642023
** 10/04/2016	Rolando.Vargas		removing qualifer FR for SCAC DDAG - ICS 642023
** 03/28/2018	Alex.Rueda			Removing qualifer PO for SCAC EXDO - (https://helpcenter.traxtech.com/browse/FCS-9258)
** 04/05/2018	Alex.Rueda			Removing qualifer FBkeyto for SCAC DDAG - (https://helpcenter.traxtech.com/browse/FCS-9369)
** 04/16/2018	Rolando.Vargas		Using OwnCA.DocumentCorrelations_Excluded_Accounts instead of HpAms.Desadv_Matched_Excluded - to use the same name across all methods (https://jira.traxtech.com/browse/PD-81)
** 05/01/2018	Alex.Rueda			Removing qualifer InvKeyToBOL for SCAC DDAG - (https://jira.traxtech.com/browse/FCS-10288)
** 08/03/2018	Rolando.Vargas		Remove CN09 sales orgs when there are other non-CN09 records. Leave CN09 if they're all CN09 records (https://helpcenter.traxtech.com/browse/PD-282)
** 08/13/2018	Rolando.Vargas		Re-implemented for S4 files (https://jira.traxtech.com/browse/PD-280)
** 10/29/2018	Rolando.Vargas		Sold to/Ship From template field update (https://jira.traxtech.com/browse/PD-471)
** 11/04/2018	Alexander Rueda		Remove FR values for matching when SCAC COT9 (https://jira.traxtech.com/browse/FCS-15907)
** 11/29/2018	Rolando.Vargas		Removing qualifier PO for EWCF Canada (https://jira.traxtech.com/browse/PD-632)
** 12/07/2018	Rolando.Vargas		Reading from new match exlusion table: Match.FbExclusionConfig (https://jira.traxtech.com/browse/PD-644)
** 12/21/2018	Rolando.Vargas		Fixed issue where ASNs were not being retrieved when matched to pattern value - now search is being done via original value (https://jira.traxtech.com/browse/PD-745)
** 01/10/2019	Clayton.Gifford		Adding [Bill To Country] (https://jira.traxtech.com/browse/FCS-14621)
** 02/08/2019	Rolando.Vargas		Adding restruction to keep only matches within 120 days (https://jira.traxtech.com/browse/PD-871)
** 02/14/2019	Rolando.Vargas		Updated issue with updating match metrics
** 02/25/2019	Rolando Vargas		Adding match exclusion message (https://jira.traxtech.com/browse/PD-643)
** 03/01/2019	Rolando.Vargas		Removing match precedence - allowing matching on multiple concepts (https://jira.traxtech.com/browse/PD-642)
** 03/05/2019	Rolando.Vargas		when figuring out most recent ASNs per ShipmentId, lower the score for excluded ASNs
** 03/14/2019	Rolando.Vargas		fixed issue with some RE persisting match metrics when matched to the same document on multiple fields
** 07/24/2019	Rolando.Vargas		Adding new column "Sales Office" (https://jira.traxtech.com/browse/MANC-239)
** 09/18/2019	Kelvin.Jones		Corrected rules error related to line numbers being out of order by adding "order by CA_Line_num asc" to Return the final results section. FCS-25270
** 01/10/2020	Kelvin.Jones		Corrected rules error related to [Exclusion_Message] being set to a bit and should have been varchar(255). FCS-32152
** 05/07/2020	Clayton.Gifford		Creating Global based on AMS GetMatchingDetails_S4. Adding EMEA CA.
** 05/20/2020	Clayton.Gifford		adding 3PLTMS and trailer Number (Dates are off)
** 06/20/2020	Clayton.Gifford		Joining on Edi856 for Trailer Number to match on values with a dash
** 07/01/2020	Clayton.Gifford		Change 3PLTMS to Qualifier AND Service Rate condition. Also remove LTL from this condition (https://jira.traxtech.com/browse/CAP-111)
** 08/10/2020	Francis.Te			Added Parcel Tracking Nummber and Tracking Number Pack as Valid Match Correlation (https://helpcenter.traxtech.com/browse/MANC-475)
** 08/11/2020	Francis.Te			Fix the issue on Trailer Number only partial match to 1 ASN (https://helpcenter.traxtech.com/browse/MANC-538)
** 08/11/2020	Francis.Te			Added logic to include asn dup logic result exclusion (https://helpcenter.traxtech.com/browse/MANC-444)
** 08/15/2020	Francis.Te			Added Removal of Invalid Pattern Match and Lane Precedence
** 08/18/2020	Francis.Te			Update Lane Precedence to exclused asn with Exclussion message
** 09/02/2020	Francis.Te			Exclude ASNs with specific carrier from matching as it’s a dummy record - (https://jira.traxtech.com/browse/MANC-565)
**									Include Shipment_Id in CA_ELEM_12 as part of the Global match class (https://jira.traxtech.com/browse/MANC-564)
**									S4 Match Precedence Persisting on the table  [dbo].[Matched_Document_FbIds] (https://jira.traxtech.com/browse/MANC-544)
** 09/09/2020	Francis.Te			Change Table from [hpams].[CostAllocationConfiguration] to [ownca].[CostAllocationConfiguration]
** 10/15/2020	Francis.Te			Sync the #CA_Lines and #CA_Lines_99(https://helpcenter.traxtech.com/browse/PD-1719,https://helpcenter.traxtech.com/browse/MANC-619)
** 10/05/2020	Clayton.Gifford		Global Match Method Implementation (https://jira.traxtech.com/browse/CAP-100)
** 01/20/2021	Clayton.Gifford		Add US Domestic Exclusion Message (https://jira.traxtech.com/browse/MANC-612)
** 01/27/2021   Francis.Te			Remove Match Concept InvKeyTo (https://jira.traxtech.com/browse/PDV-7123)
** 02/17/2021	Clayton.Gifford		Fix GlobalMatch where clause (Sales Office was evaluating Sales Org)
** 02/18/2021	Clayton.Gifford		index on OwnCa.CostAlllocationConfiguraiton should be OwnCa and not HpAms
** 04/14/2021	Clayton.Gifford		Excluding APAC from 99 line validation (https://jira.traxtech.com/browse/CAO-8880)
** 07/22/2021	Clayton.Gifford		Adding AFM Flag to Global Match method / Move PL from CA_ELEM_7 to CA_ELEM_6 ()
** 07/26/2021	Clayton.Gifford		New SCAC based CA method (https://helpcenter.traxtech.com/browse/CAP-1113)
** 08/24/2021	Decery.Alterado		Add abs() function to check difference of fbshipdate & ASN shipdate > 120 days (https://jira.traxtech.com/browse/PDV-8879)
** 11/12/2021	Clayton.Gifford		Update tax line exclusion to include S4 ownerkeys (AFM Activities)
** 12/06/2021	Clayton.Gifford		Use @ownerkey variable for all CA methods (AFM Activities)
** 02/03/2022	Decery.Alterado		Remove 120 day diff for vend_labl: IHUB (temporary)
** 05/04/2022	Decery.Alterado		Change from OwnCA.GlobalMatchSCAC to OwnCA.GlobalMatchSCAC_V2 (no datetime validations yet)
** 05/20/2022	Decery.Alterado		Remove 99 line validation for all regions
** 06/06/2022	Decery.Alterado		Removed Legacy CA tables (https://jira.traxtech.com/browse/PDV-10523)
** 07/20/2022	Emilio.Castro		'Apply CA_ELEM Override' statements added for LA region (https://helpcenter.traxtech.com/browse/CAP-1685)
** 07/20/2022	Emilio.Castro		Using functions for CA ELEM Override instead of a stored procedure to allow simulations (to avoiding nested insert into exec issue)
** 09/23/2022	Francis.Te			Not all lines found CA config records is the higher precedence compare to other exclusion (https://helpcenter.traxtech.com/browse/PDV-11160)
** 3/21/2023	joselito.medina		Override CA_ELEM 1 - 12 if CA_ELEM 1 - 12 is not null PDV-11588
** 08/14/2023	Francis.Te			Updated 120 day logic to lookup on a table. If no record exist, use default 365 (https://helpcenter.traxtech.com/browse/PDV-12128)
** 09/23/2024	Decery.Alterado		Override ASN Duplicate Logic for valid BOL_Number matches (BLUE-14093)
** 05/18/2026	Francis Te			Prevailing Rule from Global SCAC Match - Hpi EMEA - DMCQ Initial Pilot (https://traxtechnologies.atlassian.net/browse/FSE-1145)
********************************************************************************/

------------------------------------------------------------------------------------------------------------------
--	Set General Parameters
------------------------------------------------------------------------------------------------------------------



----------------------------------- PART 1 -------------------------------------------------------------------------------

   declare @masterFbNId bigint ,

      		 @masterFbId varchar(23) = 'FBLL1000681011856830005 ',		--FPS
			 @AFMFlag bit = 1,											--FPS
   			 @includeDebugInformation bit = 1,							--DEBUG
   			 @returnCaLines bit = 1,
   			 @updateMatchMetrics bit = 1,
   			 @returnInvalidResults bit = 0



	   set @masterFbNId = dbo.fn_getNumId(@masterFbId)

	--SELECT @masterFbNId

	declare @vendLabl varchar(55),
			@fbTaxAmt float,
			@fbAmt float,
			@accoutNumber varchar(55),
			@ownerKey varchar(13),
			@taxRegKeyBlng nvarchar(50),
			@alCntryCodeOrig nvarchar(30),
			@alCntryCodeDest nvarchar(30),
			@fbCurrencyQual nvarchar(50),
			@fbShipDate datetime,
			@alCntryCodeBlng nvarchar(30),
			@exclusionMessage varchar(255),
			@vend_rate_scale varchar(55),
			@serviceLevel varchar(8)

	 select @vendLabl = fb.vend_labl,
			@ownerKey = fb.owner_key,
			@accoutNumber = fb.acct_num_vend_blng,
			@taxRegKeyBlng = oix.tax_reg_key_blng,
			@alCntryCodeOrig = fb.al_cntry_code_orig,
			@alCntryCodeDest = fb.al_cntry_code_dest,
			@alCntryCodeBlng = oi.al_cntry_code_blng,
			@fbCurrencyQual = fb.fb_currency_qual,
			@fbTaxAmt = fb.fb_tax_amt,
			@fbAmt = fb.fb_amt,
			@fbShipDate = fb.lm_pkup_actual_dtm,
			@vend_rate_scale = vend_rate_scale
	  from dbo.outfrght_bl fb with(nolock)
inner join dbo.outinvoice oi with(nolock)
		on fb.inv_id = oi.inv_id
inner join dbo.outinvoice_ext oix with(nolock)
		on oi.inv_id = oix.inv_id
	 where fb.fb_id = @masterFbId

	 If @AFMFlag = 1
		begin
			set @ownerKey = @ownerKey+'_S4'
		end

	  if ( @includeDebugInformation =  1 )
	  begin
			 select @ownerkey as 'AFM Ownerkey Check', @AFMFlag as 'AFMFlag'
		end



----------------------------------- PART 1 -------------------------------------------------------------------------------


----------------------------------- PART 2 -------------------------------------------------------------------------------

   declare @varchar255 varchar(255)
   declare @bit bit
   declare @int int

------------------------------------------------------------------------------------------------------------------
--	Common table used by CA to report validations
------------------------------------------------------------------------------------------------------------------
	declare @inputValidationResult table(
			Input varchar(150),
			Value nvarchar(500),
			Valid bit,
			[Validation Result] varchar(255))

--	=================================================================================
--	Determine if the FB is a 3PLTMS FB
--	=================================================================================
	declare @isFb3plTms bit = 0

		 if (
				exists(select 1 from KeyIdent (nolock) where UntNId = dbo.fn_getNumId(@masterFbId) and KeyVal = '3PLTMS' and KeyQual in ('FI','FLOW','CA', 'IN', 'PL')
														and isnull(@vend_rate_scale,'') in ('FTL,DIRECT', 'FTL,XDOCK') ) -- Condition on both and remove LTL -- CAP-111
			--  and isnull(@vend_rate_scale,'') not like '%ltl%'  -- ICS 653157
			--  and isnull(@vend_rate_scale,'') not like '%ltl%'  -- ICS 653157 -- Removing LTL from the 3PL definition (ICS 667503) -- removing ICS:680056
			-- REMOVE LTL,DIRECT AND LTL,XDOCK AND MERGE THE TWO CONDITIONS
			)
	  begin
			set @isFb3plTms = 1
		end

		 -- if (@isFb3plTms = 0 and isnull(@vend_rate_scale,'') in ('FTL,DIRECT', 'FTL,XDOCK', 'LTL,DIRECT', 'LTL,XDOCK') ) -- ICS 653157
		 -- if (@isFb3plTms = 0 and isnull(@vend_rate_scale,'') in ('FTL,DIRECT', 'FTL,XDOCK') ) -- Removing LTL from the 3PL definition (ICS 667503)
		 --if (@isFb3plTms = 0 and isnull(@vend_rate_scale,'') in ('FTL,DIRECT', 'FTL,XDOCK', 'LTL,DIRECT', 'LTL,XDOCK') ) -- ICS 680056

	  --begin
		--	set @isFb3plTms = 1
		--end

		 if ( @includeDebugInformation =  1 )
	  begin
			 --print '@serviceLevel: ' + isnull(@serviceLevel,'<null>')
			 --print '@isFb3plTms: ' + convert(varchar,@isFb3plTms)
			 select @isFb3plTms as '@isFb3plTms'
		end


----------------------------------- PART 2 -------------------------------------------------------------------------------



----------------------------------- PART 3 -------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------
--	Collect the match metrics
------------------------------------------------------------------------------------------------------------------
   declare @matchMetrics table(
		   MatchNumberPrevailResultId int,
		   Qualifier varchar(55),
		   PrevailResultMatchedCorrelations varchar(255),
		   ArgsNumberPatternBase varchar(255),
		   ArgsKeyNumber varchar(255),
		   PrevailResultMatchedNumber varchar(255),
		   PrevailResultMatchedUntNId bigint,
		   SCAC varchar(55),
		   ArgsKeySystemName varchar(55),
		   IsRefValueDate bit,
		   Exclude_From_Cost_Allocation bit,
		   Exclude_From_Match bit,
		   Exclusion_Message varchar(255),
           PrevailResultArgsPatternIsIncluded bit)
		   --primary key(PrevailResultMatchedCorrelations))

insert into @matchMetrics(
			MatchNumberPrevailResultId,
			Qualifier,
			PrevailResultMatchedCorrelations,
			ArgsNumberPatternBase,
			ArgsKeyNumber,
			PrevailResultMatchedNumber,
			PrevailResultMatchedUntNId,
			ArgsKeySystemName,
			IsRefValueDate,
			Exclude_From_Cost_Allocation,
			Exclude_From_Match,
            PrevailResultArgsPatternIsIncluded)
	 select p.MatchNumberPrevailResultId,
			p.ArgsKeyConceptName,
			p.PrevailResultMatchedCorrelations,
			mcs.Value, -- original value received in the ASN
			mcp.BaseValue, -- pattern value received in the ASN
			p.PrevailResultMatchedNumber,
			p.PrevailResultMatchedUntNId,
			p.ArgsKeySystemName,
			case when len(p.PrevailResultMatchedNumber) = 8
				 and try_parse(substring(p.PrevailResultMatchedNumber,1,4) + '-' +
					 substring(p.PrevailResultMatchedNumber,5,2) + '-' +
					 substring(p.PrevailResultMatchedNumber,7,2) as date) is not null then 1 else 0 end as IsRefValueDate,
			0 as Exclude_From_Cost_Allocation,
			0 as Exclude_From_Match,
            p.PrevailResultArgsPatternIsIncluded
	  -- select top 100 *
	   from HpAms.HP_AMS_viewflatMatchNumberPrevailResult p with(nolock) -- FB match metrics
 inner join HPiAmsDesadvMatching.dbo.viewFlatMatchConceptString mcs with(nolock) -- ASN match concept string
		 on p.PrevailResultMatchedUntNId = mcs.UntNId
		and OwnCA.fn_GetNthField(substring(PrevailResultMatchedCorrelations, charindex(PrevailResultArgsKeyConceptName, PrevailResultMatchedCorrelations) + len(PrevailResultArgsKeyConceptName) + 2, 100), ',', 1) = mcs.NameCompleteName
  left join HPiAmsDesadvMatching.dbo.viewMatchConceptPattern mcp with(nolock) -- ASN match concept pattern
		 on mcs.MatchConceptStringId = mcp.MatchConceptId
	  where p.ArgsKeyUntNId = @masterFbNId
	   	and p.HasPrevailing =  1
		and (p.PrevailResultMatchedNumber = mcs.Value or p.PrevailResultMatchedNumber = mcp.BaseValue)

		 if (@includeDebugInformation = 1)
	  begin
			 select '@matchMetrics' as [@matchMetrics], * from @matchMetrics
		end


----------------------------------- PART 3 -------------------------------------------------------------------------------




----------------------------------- PART 4 -------------------------------------------------------------------------------


	 delete m
	   from @matchMetrics m
	  where m.ArgsKeySystemName not like '%_S4%' or m.ArgsKeySystemName in ('MatchConfigHpiGlobalS4TestToRefFilesS4')


	   if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - post removing not S4' as [@matchMetrics - post removing not S4], * from @matchMetrics
	   end

----------------------------------- PART 4 -------------------------------------------------------------------------------



----------------------------------- PART 5 -------------------------------------------------------------------------------

    delete m
	   from @matchMetrics m
	 	  where PrevailResultArgsPatternIsIncluded = 0

	   if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - post removing match config Invalid Pattern' as [@matchMetrics - post removing not S4], * from @matchMetrics
	   end

----------------------------------- PART 5 -------------------------------------------------------------------------------




----------------------------------- PART 6 -------------------------------------------------------------------------------

--	Pull the vend_labl for the ASN
--	---------------------------------------------------------------------------------------------------------------------
	update m
	   set m.SCAC = mc.[Value]
	  from @matchMetrics m
inner join HpAms.HP_AMS_viewFlatMatchConceptString mc with(nolock)
		on m.PrevailResultMatchedUntNId = mc.UntNId
	   and mc.NameCompleteName = 'VendLabl'
	 where m.SCAC is null

	   if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - post updating SCAC 1' as [@matchMetrics - post updating SCAC 1], * from @matchMetrics
	   end

----------------------------------- PART 6 -------------------------------------------------------------------------------




----------------------------------- PART 7 -------------------------------------------------------------------------------

--	Pull the vend_labl for the ASN
--	---------------------------------------------------------------------------------------------------------------------
	update m
	   set m.SCAC = h.[Carrier_Code]
	  from @matchMetrics m
 inner join HPiASN.[Match].[DocumentHeader_Edi856FbId] asnFb with(nolock)
		 on m.PrevailResultMatchedUntNId = asnFb.FbNId
 inner join HPiASN.[Match].[HPI_ASN_FlatHeader] h with(nolock)
		 on asnFb.Document_Id = h.Document_Id
	 where m.SCAC is null

	   if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - post updating SCAC 2' as [@matchMetrics - post updating SCAC 2], * from @matchMetrics
	   end

----------------------------------- PART 7 -------------------------------------------------------------------------------





----------------------------------- PART 8 -------------------------------------------------------------------------------


--	For ASAF drop trailing 3 digits
--	---------------------------------------------------------------------------------------------------------------------
	 update m
		set m.ArgsNumberPatternBase = left(h.[Shipment_Id], (len(h.[Shipment_Id]) - 3))
	   from @matchMetrics m
 inner join [Match].[DocumentHeader_Edi856FbId] f with(nolock)
		 on m.[PrevailResultMatchedUntNId] = f.[FbNId]
 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
		 on f.[Document_Id] = h.[Document_Id]
	  where m.SCAC = 'ASAF'
		and m.PrevailResultMatchedCorrelations like '%ToShipment_Id%'

	   if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - ASAF - drop trailing 3 digits' as [@matchMetrics - ASAF - drop trailing 3 digits], * from @matchMetrics
	   end

-- select top 100 * from [dbo].[Matched_Document_FbIds] i with(nolock)
-- select top 100 * from hpiasn.match.documentheader

----------------------------------- PART 8 -------------------------------------------------------------------------------




----------------------------------- PART 9 START -------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------
--	Remove metrics for those not expected to match
------------------------------------------------------------------------------------------------------------------
	 update m
		set Exclude_From_Match = Match.fn_GetFbExclusionConfig('Match', @ownerKey, @vendLabl, @accoutNumber, Qualifier, PrevailResultMatchedCorrelations, @fbShipDate),
			Exclude_From_Cost_Allocation = Match.fn_GetFbExclusionConfig('CostAllocation', @ownerKey, @vendLabl, @accoutNumber, Qualifier, PrevailResultMatchedCorrelations, @fbShipDate)
	   from @matchMetrics m

	 update m
		set m.Exclusion_Message = case when Exclude_From_Match = 1 then 'Excluded from match based on exclusion configuration'
									   when Exclude_From_Cost_Allocation = 1 then 'Excluded from cost allocation based on exclusion configuration'
									   end,
			@exclusionMessage = case when exists(select 1 from @matchMetrics where Exclude_From_Match = 1) then 'Match excluded from match exclusion config'
									 when exists(select 1 from @matchMetrics where Exclude_From_Cost_Allocation = 1) then 'CA excluded from match exclusion config' end
	   from @matchMetrics m

		 if (@includeDebugInformation = 1)
	  begin
		   select '@matchMetrics - post updating exclusion values' as [@matchMetrics - post updating exclusion values], * from @matchMetrics
		end

----------------------------------- PART 9 END -------------------------------------------------------------------------------



----------------------------------- PART 10 START -------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
--	Remove invalid metrics
------------------------------------------------------------------------------------------------------------------
-- remove CR metrics that are dates
	 update m
		set m.Exclusion_Message = isnull(m.Exclusion_Message, 'Excluded Qualifier CR that are dates'),
			@exclusionMessage = isnull(@exclusionMessage, 'Excluded  Qualifier CR that are dates')
	   from @matchMetrics m
	  where PrevailResultMatchedCorrelations like '%CRto%'
		and len(PrevailResultMatchedNumber) = 8
		and IsRefValueDate = 1
		-- include only +/- 1 from current year
		and abs(datepart(year,getdate()) - datepart(year, try_parse(substring(PrevailResultMatchedNumber,1,4) + '-' +
																	substring(PrevailResultMatchedNumber,5,2) + '-' +
																	substring(PrevailResultMatchedNumber,7,2) as date) ) ) <= 1

	   if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - post removing CR values that are dates' as [@matchMetrics - post removing CR values that are dates], * from @matchMetrics
	   end

----------------------------------- PART 10 END -------------------------------------------------------------------------------




----------------------------------- PART 11 START -------------------------------------------------------------------------------


-- remove records that have an exclusion message
	 delete d from @matchMetrics d where (Exclusion_Message is not null) and (Exclusion_Message not like '%configuration%')

--	Delete Non3pl
--	---------------------------------------------------------------------------------------------------------------------
-- Remove all records that are not trailer number if @isFb3plTms -- MANC-538
if @isFb3plTms = 1
begin
	delete
	from @matchMetrics
	where PrevailResultMatchedCorrelations not like '%TMS_Trailer_Number%'

	if (@includeDebugInformation = 1)
	begin
		   select '@matchMetrics - post removing Non 3plTMS values' as [@matchMetrics - post removing CR values that are dates], * from @matchMetrics
	 end
end

----------------------------------- PART 11 END -------------------------------------------------------------------------------





----------------------------------- PART 12 START -------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------
--    Remove Excluded Match Concepts - PDV-7123
------------------------------------------------------------------------------------------------------------------
    delete
    from @matchMetrics
    where PrevailResultMatchedCorrelations like 'InvKeyTo%'


    if (@includeDebugInformation = 1)
    begin
           select '@matchMetrics - post removing InvKeyTo' as [@matchMetrics - post removing InvKeyTo], * from @matchMetrics
    end



----------------------------------- PART 12 END -------------------------------------------------------------------------------





----------------------------------- PART 13 START -------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------
--	Collect the DESADV info
------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------
--	Declare table for DESADV info
------------------------------------------------------------------------------------------------------------------

		if object_id('tempdb..#documentInfo1') is null
	 begin
		-- drop table #documentInfo1
		 create table #documentInfo1(
				[Document_Id] uniqueidentifier,
				[Ranked] int,
				[OwnerKey] varchar(8),
				[Document_Type] varchar(55),
				[Source_System] varchar(55),
				[Shipment_Id] varchar(55),
				[PO_Number] varchar(55),
				[BOL_Number] varchar(55),
				[Tracking_Number] varchar(55),
				[MAWB_Number] varchar(55),
				[HAWB_Number] varchar(55),
				[Container_Number] varchar(55),
				[Consolidation_Number] varchar(55),
				[Carrier_Code] varchar(10),
				[Mode] varchar(55),
				[Service_Level] varchar(55),
				[SAP Delivery Number] varchar(55),
				[TMS Trailer Number] varchar(55),
				[Ship_Date] datetime,
				[Total_Weight] real,
				[Total_Weight_UOM] varchar(10),
				[Leg_Number] int,
				[Segment Customer Order Number] varchar(55),
				[Sales Organization] varchar(55),
				[Plant ID] varchar(55),
				[Shipping Point] varchar(55),
				[Ship_From_Location_Id] varchar(55) null,
				[Ship_From_City] varchar(55) null,
				[Ship_From_State] varchar(55) null,
				[Ship_From_Post_Code] varchar(55) null,
				[Ship_From_Country] varchar(55) null,
				[Ship_To_Location_Id] varchar(55) null,
				[Ship_To_City] varchar(55) null,
				[Ship_To_State] varchar(55) null,
				[Ship_To_Post_Code] varchar(55) null,
				[Ship_To_Country] varchar(55) null,
				[Sold_To_Location_Id] varchar(55) null,
				[Sales Office] varchar(55),
				[Distribution_Channel] varchar(55),
				[Line_Id] uniqueidentifier,
				[Line_Number] int,
				[Line_Weight] real,
				[Line_Weight_UOM] varchar(10),
				[Part_Number] varchar(55),
				[Part_Description] nvarchar(255),
				[Quantity] real,
				[Box ID] varchar(55),
				[Profit Center] varchar(55),
				[Product Line] varchar(55),
				[CA Updated] bit,
				[CA_ConfigTemplate_RecordId] int,
				[WinningMethod] varchar(255) null,
				[CA_ELEM_1] varchar(255) null,
				[CA_ELEM_2] varchar(255) null,
				[CA_ELEM_3] varchar(255) null,
				[CA_ELEM_4] varchar(255) null,
				[CA_ELEM_5] varchar(255) null,
				[CA_ELEM_6] varchar(255) null,
				[CA_ELEM_7] varchar(255) null,
				[CA_ELEM_8] varchar(255) null,
				[CA_ELEM_9] varchar(255) null,
				[CA_ELEM_10] varchar(255) null,
				[CA_ELEM_11] varchar(255) null,
				[CA_ELEM_12] varchar(255) null,
				[Match Concept] varchar(255) null,
				[Match Value] varchar(50) null,
				[Document Correlations] varchar(500),
				[Exclude_From_Match] bit,
				[Exclude_From_Cost_Allocation] bit,
				[Exclusion_Message] varchar(255))

		--  create nonclustered index [#documentInfo1:Document_Id] on #documentInfo1(Document_Id) with(data_compression=page)
		 create nonclustered index [#documentInfo1:Shipment_Id] on #documentInfo1(Shipment_Id) with(data_compression=page)
		 create nonclustered index [#documentInfo1:Tracking_Number] on #documentInfo1(Tracking_Number) with(data_compression=page)
		 create nonclustered index [#documentInfo1:SAP Delivery Number] on #documentInfo1([SAP Delivery Number]) with(data_compression=page)
		 create nonclustered index [#documentInfo1:PO_Number] on #documentInfo1(PO_Number) with(data_compression=page)
		 create nonclustered index [#documentInfo1:Container_Number] on #documentInfo1(Container_Number) with(data_compression=page)
		 create nonclustered index [#documentInfo1:Consolidation_Number] on #documentInfo1(Consolidation_Number) with(data_compression=page)
		 create nonclustered index [#documentInfo1:BOL_Number] on #documentInfo1(BOL_Number) with(data_compression=page)

	   end
	  else
		   truncate table #documentInfo1

   declare @maxLookupAttempts int

--/
-- If there's a match to TMS_Trailer_Number, then pull all the DESADV records for that TMS_Trailer_Number match
------------------------------------------------------------------------------------------------------------------
		   if ( @isFb3pltms = 1 )
		 begin
					declare @TMS_Trailer_Number table(
							[PrevailResultMatchedUntNId] varchar(28),
							[TMS Trailer Number] varchar(255),
							[Document Correlations] varchar(500),
							[Exclude_From_Match] bit,
							[Exclude_From_Cost_Allocation] bit,
							[Exclusion_Message] varchar(55))

				insert into @TMS_Trailer_Number
					 select top 1 [PrevailResultMatchedUntNId], -- MANC-538
							[ArgsNumberPatternBase] as [TMS Trailer Number],
					 		[PrevailResultMatchedCorrelations] as [Document Correlations],
							[Exclude_From_Match],
							[Exclude_From_Cost_Allocation],
							[Exclusion_Message]
					   from @matchMetrics
					  where PrevailResultMatchedCorrelations like '%TMS_Trailer_Number%'
					  	order by [PrevailResultMatchedUntNId] -- MANC-538

						set @maxLookupAttempts = 4
					  while (@maxLookupAttempts >= 0 and exists(select 1 from @TMS_Trailer_Number))
					  begin
							 if (@includeDebugInformation = 1)
						  begin
							   select '@TMS_Trailer_Number' as [@TMS_Trailer_Number], *, abs(@maxLookupAttempts - 5) as [iteration] from @TMS_Trailer_Number
							end

					insert into #documentInfo1(
								[Document_Id],
								[Ranked],
								[OwnerKey],
								[Document_Type],
								[Source_System],
								[Shipment_Id],
								[PO_Number],
								[BOL_Number],
								[Tracking_Number],
								[MAWB_Number],
								[HAWB_Number],
								[Container_Number],
								[Consolidation_Number],
								[Carrier_Code],
								[Mode],
								[Service_Level],
								[SAP Delivery Number],
								[TMS Trailer Number],
								[Ship_Date],
								[Total_Weight],
								[Total_Weight_UOM],
								[Leg_Number],
								[Segment Customer Order Number],
								[Sales Organization],
								[Plant ID],
								[Shipping Point],
								[Ship_From_Location_Id],
								[Ship_From_City],
								[Ship_From_State],
								[Ship_From_Post_Code],
								[Ship_From_Country],
								[Ship_To_Location_Id],
								[Ship_To_City],
								[Ship_To_State],
								[Ship_To_Post_Code],
								[Ship_To_Country],
								[Sold_To_Location_Id],
								[Sales Office],
								[Distribution_Channel],
								[Line_Id],
								[Line_Number],
								[Line_Weight],
								[Line_Weight_UOM],
								[Part_Number],
								[Part_Description],
								[Quantity],
								[Box ID],
								[Profit Center],
								[Product Line],
								[CA Updated],
								[CA_ConfigTemplate_RecordId],
								[WinningMethod],
								[Match Concept],
								[Document Correlations],
								[Exclude_From_Match],
								[Exclude_From_Cost_Allocation],
								[Exclusion_Message])
						 select --top 1 -- Remove for MANC-538
								d.[Document_Id], -- should be d to get the document id for same trailer number
								rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
								substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
								h.[Document_Type],
								h.[Source_System],
								h.[Shipment_Id],
								h.[PO_Number],
								h.[BOL_Number],
								h.[Tracking_Number],
								h.[MAWB_Number],
								h.[HAWB_Number],
								h.[Container_Number],
								h.[Consolidation_Number],
								h.[Carrier_Code],
								h.[Mode],
								h.[Service_Level],
								h.[SAP Delivery Number],
								h.[TMS Trailer Number],
								h.[Ship_Date],
								h.[Total_Weight],
								h.[Total_Weight_UOM],
								h.[Leg_Number],
								h.[Seg. Customer Order Number],
								h.[Sales Organization],
								h.[Plant ID],
								h.[Shipping Point],
								h.[Ship_From_Location_Id],
								h.[Ship_From_City],
								h.[Ship_From_State],
								h.[Ship_From_Post_Code],
								h.[Ship_From_Country],
								h.[Ship_To_Location_Id],
								h.[Ship_To_City],
								h.[Ship_To_State],
								h.[Ship_To_Post_Code],
								h.[Ship_To_Country],
								h.[Sold_To_Location_Id],
								h.[Sales Office],
								h.[Distribution_Channel],
								d.[Line_Id],
								d.[Line_Number],
								d.[Line_Weight],
								d.[Line_Weight_UOM],
								d.[Part_Number],
								d.[Part_Description],
								d.[Quantity],
								d.[Box ID],
								d.[Profit Center],
								d.[Product Line],
								0 as [CA Updated],
								null as [CA_ConfigTemplate_RecordId],
								null as [WinningMethod],
								'TMS_Trailer_Number' [Match Concept],
								b.[Document Correlations],
								b.[Exclude_From_Match],
								b.[Exclude_From_Cost_Allocation],
								b.[Exclusion_Message]
						   from @TMS_Trailer_Number b
					 inner join match.DocumentHeader_Edi856FbId I (nolock) on b.[PrevailResultMatchedUntNId] = I.FbNId
					 --inner join [HPiASN].match.DocumentHeaderExtraValues (nolock) DH on DH.Document_ID = I.Document_ID and Concept = 'TMS Trailer Number'
					 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock) on I.Document_Id = h.Document_Id--DH.Value  = H.[TMS Trailer Number]--/*'2030369-2'*/b.[TMS Trailer Number] = h.[TMS Trailer Number]
					 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] hOther with(nolock) on h.[TMS Trailer Number] = hOther.[TMS Trailer Number]  -- MANC-538 ??? Include Leg Condition...
					 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
							 on hOther.Document_Id = d.Document_Id -- -- MANC-538
							order by PrevailResultMatchedUntNId desc

							if (@includeDebugInformation = 1)
						  begin
							   select '#documentinfo1 - Post TMS Trailer Number' as [#documentinfo1 - Post TMS Trailer Number], * from #documentInfo1
							end



----------------------------------- PART 13 END -------------------------------------------------------------------------------




----------------------------------- PART 14 START -------------------------------------------------------------------------------




					-- remove those TMS_Trailer_Numbers that already pulled data
				 delete b
				   from @TMS_Trailer_Number b
				  where exists(select 1 from #documentInfo1 bm where b.[TMS Trailer Number] = bm.[TMS Trailer Number])

					-- because of patterns applied, the leading zeroes may have been dropped...
				 --update @TMS_Trailer_Number
					--set TMS_Trailer_Number = '0' + Shipment_Id

				set @maxLookupAttempts = @maxLookupAttempts - 1
		   end -- end while


			-- Remove all records that are not trailer number if @isFb3plTms
	if @isFb3plTms = 1
	 begin
		delete
		  from @matchMetrics
		 where PrevailResultMatchedCorrelations not like '%TMS_Trailer_Number%'
	 end
		end -- end if TMS_Trailer_Number
--/



-- If there's a match to Shipment_Id, then pull all the DESADV records for that Shipment_Id match
------------------------------------------------------------------------------------------------------------------
		   if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToShipment_Id%') )
		 begin
					declare @shipmentId table(
							[PrevailResultMatchedUntNId] varchar(28),
							[Shipment_Id] varchar(255),
							[Document Correlations] varchar(500),
							[Exclude_From_Match] bit,
							[Exclude_From_Cost_Allocation] bit,
							[Exclusion_Message] varchar(55))

				insert into @shipmentId
					 select [PrevailResultMatchedUntNId],
					 		[ArgsNumberPatternBase] as [Shipment_Id],
					 		[PrevailResultMatchedCorrelations] as [Document Correlations],
							[Exclude_From_Match],
							[Exclude_From_Cost_Allocation],
							[Exclusion_Message]
					   from @matchMetrics
					  where PrevailResultMatchedCorrelations like '%ToShipment_Id%'

						set @maxLookupAttempts = 4
					  while (@maxLookupAttempts >= 0 and exists(select 1 from @shipmentId))
					  begin
							 if (@includeDebugInformation = 1)
						  begin
							   select '@shipmentId' as [@shipmentId], *, abs(@maxLookupAttempts - 5) as [iteration] from @shipmentId
							end

					insert into #documentInfo1(
								[Document_Id],
								[Ranked],
								[OwnerKey],
								[Document_Type],
								[Source_System],
								[Shipment_Id],
								[PO_Number],
								[BOL_Number],
								[Tracking_Number],
								[MAWB_Number],
								[HAWB_Number],
								[Container_Number],
								[Consolidation_Number],
								[Carrier_Code],
								[Mode],
								[Service_Level],
								[SAP Delivery Number],
								[Ship_Date],
								[Total_Weight],
								[Total_Weight_UOM],
								[Leg_Number],
								[Segment Customer Order Number],
								[Sales Organization],
								[Plant ID],
								[Shipping Point],
								[Ship_From_Location_Id],
								[Ship_From_City],
								[Ship_From_State],
								[Ship_From_Post_Code],
								[Ship_From_Country],
								[Ship_To_Location_Id],
								[Ship_To_City],
								[Ship_To_State],
								[Ship_To_Post_Code],
								[Ship_To_Country],
								[Sold_To_Location_Id],
								[Sales Office],
								[Distribution_Channel],
								[Line_Id],
								[Line_Number],
								[Line_Weight],
								[Line_Weight_UOM],
								[Part_Number],
								[Part_Description],
								[Quantity],
								[Box ID],
								[Profit Center],
								[Product Line],
								[CA Updated],
								[CA_ConfigTemplate_RecordId],
								[WinningMethod],
								[Match Concept],
								[Match Value], -- tiny
								[Document Correlations],
								[Exclude_From_Match],
								[Exclude_From_Cost_Allocation],
								[Exclusion_Message])
						 select h.[Document_Id],
								rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
								substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
								h.[Document_Type],
								h.[Source_System],
								h.[Shipment_Id],
								h.[PO_Number],
								h.[BOL_Number],
								h.[Tracking_Number],
								h.[MAWB_Number],
								h.[HAWB_Number],
								h.[Container_Number],
								h.[Consolidation_Number],
								h.[Carrier_Code],
								h.[Mode],
								h.[Service_Level],
								h.[SAP Delivery Number],
								h.[Ship_Date],
								h.[Total_Weight],
								h.[Total_Weight_UOM],
								h.[Leg_Number],
								h.[Seg. Customer Order Number],
								h.[Sales Organization],
								h.[Plant ID],
								h.[Shipping Point],
								h.[Ship_From_Location_Id],
								h.[Ship_From_City],
								h.[Ship_From_State],
								h.[Ship_From_Post_Code],
								h.[Ship_From_Country],
								h.[Ship_To_Location_Id],
								h.[Ship_To_City],
								h.[Ship_To_State],
								h.[Ship_To_Post_Code],
								h.[Ship_To_Country],
								h.[Sold_To_Location_Id],
								h.[Sales Office],
								h.[Distribution_Channel],
								d.[Line_Id],
								d.[Line_Number],
								d.[Line_Weight],
								d.[Line_Weight_UOM],
								d.[Part_Number],
								d.[Part_Description],
								d.[Quantity],
								d.[Box ID],
								d.[Profit Center],
								d.[Product Line],
								0 as [CA Updated],
								null as [CA_ConfigTemplate_RecordId],
								null as [WinningMethod],
								'Shipment_Id' [Match Concept],
								b.Shipment_Id,
								b.[Document Correlations],
								b.[Exclude_From_Match],
								b.[Exclude_From_Cost_Allocation],
								b.[Exclusion_Message]
						   from @shipmentId b
						   --inner join match.DocumentHeader_Edi856FbId I (nolock) on b.[PrevailResultMatchedUntNId] = I.FbNId
					 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
							 on b.shipment_id = h.shipment_id
					 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
							 on h.Document_Id = d.Document_Id

					-- remove those DeliveryIDs that already pulled data
				 delete b
				   from @shipmentId b
				  where exists(select 1 from #documentInfo1 bm where b.Shipment_Id = bm.Shipment_Id)

					-- because of patterns applied, the leading zeroes may have been dropped...
				 update @shipmentId
					set Shipment_Id = '0' + Shipment_Id

				set @maxLookupAttempts = @maxLookupAttempts - 1
		   end -- end while

		delete
		  from @matchMetrics
		 where PrevailResultMatchedCorrelations like '%ToShipment_Id%'

		end -- end if Shipment_Id

-- If there's a match to Tracking_Number, then pull all the DESADV records for that Tracking_Number match
------------------------------------------------------------------------------------------------------------------
		 if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToTracking_Number%') )
	  begin
		declare @trackingNumber table(
				[PrevailResultMatchedUntNId] varchar(28),
				[Tracking_Number] varchar(255),
			    [Document Correlations] varchar(500),
				[Exclude_From_Match] bit,
				[Exclude_From_Cost_Allocation] bit,
				[Exclusion_Message] varchar(255))

	insert into @trackingNumber
		 select PrevailResultMatchedUntNId,
		 		ArgsNumberPatternBase as Tracking_Number,
				PrevailResultMatchedCorrelations,
				Exclude_From_Match,
				Exclude_From_Cost_Allocation,
				[Exclusion_Message]
		   from @matchMetrics
		  where PrevailResultMatchedCorrelations like '%ToTracking_Number%'

			set @maxLookupAttempts = 4
		  while (@maxLookupAttempts >= 0 and exists(select 1 from @trackingNumber))
		  begin
				 if (@includeDebugInformation = 1)
			  begin
					 select '@trackingNumber' as [@trackingNumber], *, abs(@maxLookupAttempts - 5) as [iteration] from @trackingNumber
				end


----------------------------------- PART 14 END -------------------------------------------------------------------------------




----------------------------------- PART 15 START -------------------------------------------------------------------------------




		insert into #documentInfo1(
					[Document_Id],
					[Ranked],
					[OwnerKey],
					[Document_Type],
					[Source_System],
					[Shipment_Id],
					[PO_Number],
					[BOL_Number],
					[Tracking_Number],
					[MAWB_Number],
					[HAWB_Number],
					[Container_Number],
					[Consolidation_Number],
					[Carrier_Code],
					[Mode],
					[Service_Level],
					[SAP Delivery Number],
					[Ship_Date],
					[Total_Weight],
					[Total_Weight_UOM],
					[Leg_Number],
					[Segment Customer Order Number],
					[Sales Organization],
					[Plant ID],
					[Shipping Point],
					[Ship_From_Location_Id],
					[Ship_From_City],
					[Ship_From_State],
					[Ship_From_Post_Code],
					[Ship_From_Country],
					[Ship_To_Location_Id],
					[Ship_To_City],
					[Ship_To_State],
					[Ship_To_Post_Code],
					[Ship_To_Country],
					[Sold_To_Location_Id],
					[Sales Office],
					[Distribution_Channel],
					[Line_Id],
					[Line_Number],
					[Line_Weight],
					[Line_Weight_UOM],
					[Part_Number],
					[Part_Description],
					[Quantity],
					[Box ID],
					[Profit Center],
					[Product Line],
					[CA Updated],
					[CA_ConfigTemplate_RecordId],
					[WinningMethod],
					[Match Concept],
					[Match Value],
					[Document Correlations],
					[Exclude_From_Match],
					[Exclude_From_Cost_Allocation],
					[Exclusion_Message])
			 select h.[Document_Id],
					rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
					substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
					h.[Document_Type],
					h.[Source_System],
					h.[Shipment_Id],
					h.[PO_Number],
					h.[BOL_Number],
					h.[Tracking_Number],
					h.[MAWB_Number],
					h.[HAWB_Number],
					h.[Container_Number],
					h.[Consolidation_Number],
					h.[Carrier_Code],
					h.[Mode],
					h.[Service_Level],
					h.[SAP Delivery Number],
					h.[Ship_Date],
					h.[Total_Weight],
					h.[Total_Weight_UOM],
					h.[Leg_Number],
					h.[Seg. Customer Order Number],
					h.[Sales Organization],
					h.[Plant ID],
					h.[Shipping Point],
					h.[Ship_From_Location_Id],
					h.[Ship_From_City],
					h.[Ship_From_State],
					h.[Ship_From_Post_Code],
					h.[Ship_From_Country],
					h.[Ship_To_Location_Id],
					h.[Ship_To_City],
					h.[Ship_To_State],
					h.[Ship_To_Post_Code],
					h.[Ship_To_Country],
					h.[Sold_To_Location_Id],
					h.[Sales Office],
					h.[Distribution_Channel],
					d.[Line_Id],
					d.[Line_Number],
					d.[Line_Weight],
					d.[Line_Weight_UOM],
					d.[Part_Number],
					d.[Part_Description],
					d.[Quantity],
					d.[Box ID],
					d.[Profit Center],
					d.[Product Line],
					0 as [CA Updated],
					null as [CA_ConfigTemplate_RecordId],
					null as [WinningMethod],
					'Tracking_Number' [Match Concept],
					b.Tracking_Number,
					b.[Document Correlations],
					b.[Exclude_From_Match],
					b.[Exclude_From_Cost_Allocation],
					b.[Exclusion_Message]
			   from @trackingNumber b
		 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
				 on b.Tracking_Number = h.Tracking_Number
		 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
				 on h.Document_Id = d.Document_Id

		-- remove those DeliveryIDs that already pulled data
			 delete b
			   from @trackingNumber b
			  where exists(select 1 from #documentInfo1 bm where b.Tracking_Number = bm.Tracking_Number)

		-- because of patterns applied, the leading zeroes may have been dropped...
				update @trackingNumber
				set Tracking_Number = '0' + Tracking_Number

				set @maxLookupAttempts = @maxLookupAttempts - 1
		   end -- end while

		delete
		  from @matchMetrics
		 where PrevailResultMatchedCorrelations like '%ToTracking_Number%'

		end -- end if Tracking_Number

-- If there's a match to BOL_Number, then pull all the DESADV records for that BOL_Number match
------------------------------------------------------------------------------------------------------------------
		 if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToBOL_Number%') )
	  begin
		declare @BOL table(
				[BOL] varchar(255) primary key with(ignore_dup_key=on),
				[Document Correlations] varchar(500),
				[Exclude_From_Match] bit,
				[Exclude_From_Cost_Allocation] bit,
				[Exclusion_Message] varchar(255),
				[PrevailResultMatchedUntNId] varchar(28))

	insert into @BOL
		 select distinct ArgsNumberPatternBase as [BOL],
				[PrevailResultMatchedCorrelations] as [Document Correlations],
				[Exclude_From_Match],
				[Exclude_From_Cost_Allocation],
				[Exclusion_Message],
				[PrevailResultMatchedUntNId]
		   from @matchMetrics
		  where [PrevailResultMatchedCorrelations] like '%ToBOL_Number%'

			set @maxLookupAttempts = 4
		  while (@maxLookupAttempts >= 0 and exists(select 1 from @BOL))
		  begin
				 if (@includeDebugInformation = 1)
			  begin
				   select '@BOL' as [@BOL], *, abs(@maxLookupAttempts - 5) as [iteration] from @BOL
				end

		insert into #documentInfo1(
					[Document_Id],
					[Ranked],
					[OwnerKey],
					[Document_Type],
					[Source_System],
					[Shipment_Id],
					[PO_Number],
					[BOL_Number],
					[Tracking_Number],
					[MAWB_Number],
					[HAWB_Number],
					[Container_Number],
					[Consolidation_Number],
					[Carrier_Code],
					[Mode],
					[Service_Level],
					[SAP Delivery Number],
					[Ship_Date],
					[Total_Weight],
					[Total_Weight_UOM],
					[Leg_Number],
					[Segment Customer Order Number],
					[Sales Organization],
					[Plant ID],
					[Shipping Point],
					[Ship_From_Location_Id],
					[Ship_From_City],
					[Ship_From_State],
					[Ship_From_Post_Code],
					[Ship_From_Country],
					[Ship_To_Location_Id],
					[Ship_To_City],
					[Ship_To_State],
					[Ship_To_Post_Code],
					[Ship_To_Country],
					[Sold_To_Location_Id],
					[Sales Office],
					[Distribution_Channel],
					[Line_Id],
					[Line_Number],
					[Line_Weight],
					[Line_Weight_UOM],
					[Part_Number],
					[Part_Description],
					[Quantity],
					[Box ID],
					[Profit Center],
					[Product Line],
					[CA Updated],
					[CA_ConfigTemplate_RecordId],
					[WinningMethod],
					[Match Concept],
					[Match Value],
					[Document Correlations],
					[Exclude_From_Match],
					[Exclude_From_Cost_Allocation],
					[Exclusion_Message])
			 select h.[Document_Id],
					rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
					substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
					h.[Document_Type],
					h.[Source_System],
					h.[Shipment_Id],
					h.[PO_Number],
					h.[BOL_Number],
					h.[Tracking_Number],
					h.[MAWB_Number],
					h.[HAWB_Number],
					h.[Container_Number],
					h.[Consolidation_Number],
					h.[Carrier_Code],
					h.[Mode],
					h.[Service_Level],
					h.[SAP Delivery Number],
					h.[Ship_Date],
					h.[Total_Weight],
					h.[Total_Weight_UOM],
					h.[Leg_Number],
					h.[Seg. Customer Order Number],
					h.[Sales Organization],
					h.[Plant ID],
					h.[Shipping Point],
					h.[Ship_From_Location_Id],
					h.[Ship_From_City],
					h.[Ship_From_State],
					h.[Ship_From_Post_Code],
					h.[Ship_From_Country],
					h.[Ship_To_Location_Id],
					h.[Ship_To_City],
					h.[Ship_To_State],
					h.[Ship_To_Post_Code],
					h.[Ship_To_Country],
					h.[Sold_To_Location_Id],
					h.[Sales Office],
					h.[Distribution_Channel],
					d.[Line_Id],
					d.[Line_Number],
					d.[Line_Weight],
					d.[Line_Weight_UOM],
					d.[Part_Number],
					d.[Part_Description],
					d.[Quantity],
					d.[Box ID],
					d.[Profit Center],
					d.[Product Line],
					0 as [CA Updated],
					null as [CA_ConfigTemplate_RecordId],
					null as [WinningMethod],
					'BOL_Number' [Match Concept],
					b.BOL as [Match Value],
					b.[Document Correlations],
					b.[Exclude_From_Match],
					b.[Exclude_From_Cost_Allocation],
					b.[Exclusion_Message]
			   from @BOL b
		 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
				 on b.BOL = h.BOL_Number
		 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
				 on h.Document_Id = d.Document_Id

		-- remove those BOLs that already pulled data
			delete b
			  from @BOL b
			 where exists(select 1 from #documentInfo1 bm where b.BOL = bm.BOL_Number)

			-- because of patterns applied, the leading zeroes may have been dropped...
			update @BOL
			   set BOL = '0' + BOL

				set @maxLookupAttempts = @maxLookupAttempts - 1
			end -- end while
		end -- BOL match exists

-- If there's a match to SAP_Delivery_Number, then pull all the DESADV records for that SAP_Delivery_Number match
------------------------------------------------------------------------------------------------------------------
		 if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToSAP_Delivery_Number%') )
	  begin
		declare @sapDeliveryNumber table(
				[PrevailResultMatchedUntNId] varchar(28),
				[SAP Delivery Number] varchar(255),
				[Document Correlations] varchar(500),
				[Exclude_From_Match] bit,
				[Exclude_From_Cost_Allocation] bit,
				[Exclusion_Message] varchar(255))

	insert into @sapDeliveryNumber
		 select PrevailResultMatchedUntNId,
		 		ArgsNumberPatternBase as [SAP Delivery Number],
				PrevailResultMatchedCorrelations,
				Exclude_From_Match,
				Exclude_From_Cost_Allocation,
				Exclusion_Message
		   from @matchMetrics
		  where PrevailResultMatchedCorrelations like '%ToSAP_Delivery_Number%'

			set @maxLookupAttempts = 4
		  while (@maxLookupAttempts >= 0 and exists(select 1 from @sapDeliveryNumber))
		  begin
				 if (@includeDebugInformation = 1)
			  begin
				 select '@sapDeliveryNumber' as [@sapDeliveryNumber], *, abs(@maxLookupAttempts - 5) as [iteration] from @sapDeliveryNumber
				end







		insert into #documentInfo1(
					[Document_Id],
					[Ranked],
					[OwnerKey],
					[Document_Type],
					[Source_System],
					[Shipment_Id],
					[PO_Number],
					[BOL_Number],
					[Tracking_Number],
					[MAWB_Number],
					[HAWB_Number],
					[Container_Number],
					[Consolidation_Number],
					[Carrier_Code],
					[Mode],
					[Service_Level],
					[SAP Delivery Number],
					[Ship_Date],
					[Total_Weight],
					[Total_Weight_UOM],
					[Leg_Number],
					[Segment Customer Order Number],
					[Sales Organization],
					[Plant ID],
					[Shipping Point],
					[Ship_From_Location_Id],
					[Ship_From_City],
					[Ship_From_State],
					[Ship_From_Post_Code],
					[Ship_From_Country],
					[Ship_To_Location_Id],
					[Ship_To_City],
					[Ship_To_State],
					[Ship_To_Post_Code],
					[Ship_To_Country],
					[Sold_To_Location_Id],
					[Sales Office],
					[Distribution_Channel],
					[Line_Id],
					[Line_Number],
					[Line_Weight],
					[Line_Weight_UOM],
					[Part_Number],
					[Part_Description],
					[Quantity],
					[Box ID],
					[Profit Center],
					[Product Line],
					[CA Updated],
					[CA_ConfigTemplate_RecordId],
					[WinningMethod],
					[Match Concept],
					[Match Value],
					[Document Correlations],
					[Exclude_From_Match],
					[Exclude_From_Cost_Allocation],
					[Exclusion_Message])
			 select h.[Document_Id],
					rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
					substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
					h.[Document_Type],
					h.[Source_System],
					h.[Shipment_Id],
					h.[PO_Number],
					h.[BOL_Number],
					h.[Tracking_Number],
					h.[MAWB_Number],
					h.[HAWB_Number],
					h.[Container_Number],
					h.[Consolidation_Number],
					h.[Carrier_Code],
					h.[Mode],
					h.[Service_Level],
					h.[SAP Delivery Number],
					h.[Ship_Date],
					h.[Total_Weight],
					h.[Total_Weight_UOM],
					h.[Leg_Number],
					h.[Seg. Customer Order Number],
					h.[Sales Organization],
					h.[Plant ID],
					h.[Shipping Point],
					h.[Ship_From_Location_Id],
					h.[Ship_From_City],
					h.[Ship_From_State],
					h.[Ship_From_Post_Code],
					h.[Ship_From_Country],
					h.[Ship_To_Location_Id],
					h.[Ship_To_City],
					h.[Ship_To_State],
					h.[Ship_To_Post_Code],
					h.[Ship_To_Country],
					h.[Sold_To_Location_Id],
					h.[Sales Office],
					h.[Distribution_Channel],
					d.[Line_Id],
					d.[Line_Number],
					d.[Line_Weight],
					d.[Line_Weight_UOM],
					d.[Part_Number],
					d.[Part_Description],
					d.[Quantity],
					d.[Box ID],
					d.[Profit Center],
					d.[Product Line],
					0 as [CA Updated],
					null as [CA_ConfigTemplate_RecordId],
					null as [WinningMethod],
					'SAP_Delivery_Number' [Match Concept],
					b.[SAP Delivery Number],
					b.[Document Correlations],
					b.[Exclude_From_Match],
					b.[Exclude_From_Cost_Allocation],
					b.[Exclusion_Message]
			   from @sapDeliveryNumber b
		 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
				 on b.[SAP Delivery Number] = h.[SAP Delivery Number]
		 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
				 on h.Document_Id = d.Document_Id

-- remove those DeliveryIDs that already pulled data
			 delete b
			   from @sapDeliveryNumber b
			  where exists(select 1 from #documentInfo1 bm where b.[SAP Delivery Number] = bm.[SAP Delivery Number])

-- because of patterns applied, the leading zeroes may have been dropped...
			 update @sapDeliveryNumber
				set [SAP Delivery Number] = '0' + [SAP Delivery Number]

				set @maxLookupAttempts = @maxLookupAttempts - 1
			end -- end while

		 delete
		   from @matchMetrics
		  where PrevailResultMatchedCorrelations like '%ToSAP_Delivery_Number%'

		end -- end if SAP_Delivery_Number

-- If there's a match to Container_Number, then pull all the DESADV records for that Container_Number match
------------------------------------------------------------------------------------------------------------------
		 if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToContainer_Number%') )
	  begin
		declare @containerNumber table(
				[Container_Number] varchar(255) primary key with(ignore_dup_key=on),
				[Document Correlations] varchar(500),
				[Exclude_From_Match] bit,
				[Exclude_From_Cost_Allocation] bit,
				[Exclusion_Message] varchar(255),
				[PrevailResultMatchedUntNId] varchar(28))

	insert into @containerNumber
		 select ArgsNumberPatternBase as Container_Number,
				PrevailResultMatchedCorrelations,
				Exclude_From_Match,
				Exclude_From_Cost_Allocation,
				Exclusion_Message,
				PrevailResultMatchedUntNId
		   from @matchMetrics
		  where PrevailResultMatchedCorrelations like '%ToContainer_Number%'

			set @maxLookupAttempts = 4
		  while (@maxLookupAttempts >= 0 and exists(select 1 from @containerNumber))
		  begin
			 if (@includeDebugInformation = 1)
		  begin
			 select '@containerNumber' as [@containerNumber], *, abs(@maxLookupAttempts - 5) as [iteration] from @containerNumber
			end

	insert into #documentInfo1(
				[Document_Id],
				[Ranked],
				[OwnerKey],
				[Document_Type],
				[Source_System],
				[Shipment_Id],
				[PO_Number],
				[BOL_Number],
				[Tracking_Number],
				[MAWB_Number],
				[HAWB_Number],
				[Container_Number],
				[Consolidation_Number],
				[Carrier_Code],
				[Mode],
				[Service_Level],
				[SAP Delivery Number],
				[Ship_Date],
				[Total_Weight],
				[Total_Weight_UOM],
				[Leg_Number],
				[Segment Customer Order Number],
				[Sales Organization],
				[Plant ID],
				[Shipping Point],
				[Ship_From_Location_Id],
				[Ship_From_City],
				[Ship_From_State],
				[Ship_From_Post_Code],
				[Ship_From_Country],
				[Ship_To_Location_Id],
				[Ship_To_City],
				[Ship_To_State],
				[Ship_To_Post_Code],
				[Ship_To_Country],
				[Sold_To_Location_Id],
				[Sales Office],
				[Distribution_Channel],
				[Line_Id],
				[Line_Number],
				[Line_Weight],
				[Line_Weight_UOM],
				[Part_Number],
				[Part_Description],
				[Quantity],
				[Box ID],
				[Profit Center],
				[Product Line],
				[CA Updated],
				[CA_ConfigTemplate_RecordId],
				[WinningMethod],
				[Match Concept],
				[Match Value],
				[Document Correlations],
				[Exclude_From_Match],
				[Exclude_From_Cost_Allocation],
				[Exclusion_Message])
		 select h.[Document_Id],
				rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
				substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
				h.[Document_Type],
				h.[Source_System],
				h.[Shipment_Id],
				h.[PO_Number],
				h.[BOL_Number],
				h.[Tracking_Number],
				h.[MAWB_Number],
				h.[HAWB_Number],
				h.[Container_Number],
				h.[Consolidation_Number],
				h.[Carrier_Code],
				h.[Mode],
				h.[Service_Level],
				h.[SAP Delivery Number],
				h.[Ship_Date],
				h.[Total_Weight],
				h.[Total_Weight_UOM],
				h.[Leg_Number],
				h.[Seg. Customer Order Number],
				h.[Sales Organization],
				h.[Plant ID],
				h.[Shipping Point],
				h.[Ship_From_Location_Id],
				h.[Ship_From_City],
				h.[Ship_From_State],
				h.[Ship_From_Post_Code],
				h.[Ship_From_Country],
				h.[Ship_To_Location_Id],
				h.[Ship_To_City],
				h.[Ship_To_State],
				h.[Ship_To_Post_Code],
				h.[Ship_To_Country],
				h.[Sold_To_Location_Id],
				h.[Sales Office],
				h.[Distribution_Channel],
				d.[Line_Id],
				d.[Line_Number],
				d.[Line_Weight],
				d.[Line_Weight_UOM],
				d.[Part_Number],
				d.[Part_Description],
				d.[Quantity],
				d.[Box ID],
				d.[Profit Center],
				d.[Product Line],
				0 as [CA Updated],
				null as [CA_ConfigTemplate_RecordId],
				null as [WinningMethod],
				'Container_Number' [Match Concept],
				b.Container_Number,
				b.[Document Correlations],
				b.[Exclude_From_Match],
				b.[Exclude_From_Cost_Allocation],
				b.[Exclusion_Message]
		   from @containerNumber b
	 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
			 on b.Container_Number = h.Container_Number
	 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
			 on h.Document_Id = d.Document_Id

		-- remove those DeliveryIDs that already pulled data
		 delete b
		   from @containerNumber b
		  where exists(select 1 from #documentInfo1 bm where b.Container_Number = bm.Container_Number)

	-- because of patterns applied, the leading zeroes may have been dropped...
		 update @containerNumber
			set Container_Number = '0' + Container_Number

			set @maxLookupAttempts = @maxLookupAttempts - 1
			end -- end while

		delete
		  from @matchMetrics
		 where PrevailResultMatchedCorrelations like '%ToContainer_Number%'

		end -- end if Container_Number

-- If there's a match to TrackingNumberPack
------------------------------------------------------------------------------------------------------------------
		 if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToTrackingNumberPack%') )
		 begin
					declare @TrackingNumberPack table(
							[PrevailResultMatchedUntNId] varchar(28),
							[TrackingNumberPack] varchar(255),
							[Document Correlations] varchar(500),
							[Exclude_From_Match] bit,
							[Exclude_From_Cost_Allocation] bit,
							[Exclusion_Message] varchar(55),
							[Document_Id] uniqueidentifier)

				insert into @TrackingNumberPack
					 select [PrevailResultMatchedUntNId],
							[ArgsNumberPatternBase] as [TrackingNumberPack],
					 		[PrevailResultMatchedCorrelations] as [Document Correlations],
							[Exclude_From_Match],
							[Exclude_From_Cost_Allocation],
							[Exclusion_Message],
							i.Document_Id
					   from @matchMetrics m
					   left join match.DocumentHeader_Edi856FbId I (nolock) on m.[PrevailResultMatchedUntNId] = I.FbNId
					  where PrevailResultMatchedCorrelations like '%ToTrackingNumberPack%'

						set @maxLookupAttempts = 4
					  while (@maxLookupAttempts >= 0 and exists(select 1 from @TrackingNumberPack))
					  begin
							 if (@includeDebugInformation = 1)
 						  begin
							   select '@TrackingNumberPack' as [@TrackingNumberPack], *, abs(@maxLookupAttempts - 5) as [iteration] from @TrackingNumberPack
   							end

					insert into #documentInfo1(
								[Document_Id],
								[Ranked],
								[OwnerKey],
								[Document_Type],
								[Source_System],
								[Shipment_Id],
								[PO_Number],
								[BOL_Number],
								[Tracking_Number],
								[MAWB_Number],
								[HAWB_Number],
								[Container_Number],
								[Consolidation_Number],
								[Carrier_Code],
								[Mode],
								[Service_Level],
								[SAP Delivery Number],
								[Ship_Date],
								[Total_Weight],
								[Total_Weight_UOM],
								[Leg_Number],
								[Segment Customer Order Number],
								[Sales Organization],
								[Plant ID],
								[Shipping Point],
								[Ship_From_Location_Id],
								[Ship_From_City],
								[Ship_From_State],
								[Ship_From_Post_Code],
								[Ship_From_Country],
								[Ship_To_Location_Id],
								[Ship_To_City],
								[Ship_To_State],
								[Ship_To_Post_Code],
								[Ship_To_Country],
								[Sold_To_Location_Id],
								[Sales Office],
								[Distribution_Channel],
								[Line_Id],
								[Line_Number],
								[Line_Weight],
								[Line_Weight_UOM],
								[Part_Number],
								[Part_Description],
								[Quantity],
								[Box ID],
								[Profit Center],
								[Product Line],
								[CA Updated],
								[CA_ConfigTemplate_RecordId],
								[WinningMethod],
								[Match Concept],
								[Document Correlations],
								[Exclude_From_Match],
								[Exclude_From_Cost_Allocation],
								[Exclusion_Message])
						 select
								h.[Document_Id],
								rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
								substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
								h.[Document_Type],
								h.[Source_System],
								h.[Shipment_Id],
								h.[PO_Number],
								h.[BOL_Number],
								h.[Tracking_Number],
								h.[MAWB_Number],
								h.[HAWB_Number],
								h.[Container_Number],
								h.[Consolidation_Number],
								h.[Carrier_Code],
								h.[Mode],
								h.[Service_Level],
								h.[SAP Delivery Number],
								h.[Ship_Date],
								h.[Total_Weight],
								h.[Total_Weight_UOM],
								h.[Leg_Number],
								h.[Seg. Customer Order Number],
								h.[Sales Organization],
								h.[Plant ID],
								h.[Shipping Point],
								h.[Ship_From_Location_Id],
								h.[Ship_From_City],
								h.[Ship_From_State],
								h.[Ship_From_Post_Code],
								h.[Ship_From_Country],
								h.[Ship_To_Location_Id],
								h.[Ship_To_City],
								h.[Ship_To_State],
								h.[Ship_To_Post_Code],
								h.[Ship_To_Country],
								h.[Sold_To_Location_Id],
								h.[Sales Office],
								h.[Distribution_Channel],
								d.[Line_Id],
								d.[Line_Number],
								d.[Line_Weight],
								d.[Line_Weight_UOM],
								d.[Part_Number],
								d.[Part_Description],
								d.[Quantity],
								d.[Box ID],
								d.[Profit Center],
								d.[Product Line],
								0 as [CA Updated],
								null as [CA_ConfigTemplate_RecordId],
								null as [WinningMethod],
								'TrackingNumberPack' [Match Concept],
								b.[Document Correlations],
								b.[Exclude_From_Match],
								b.[Exclude_From_Cost_Allocation],
								b.[Exclusion_Message]
						   from @TrackingNumberPack b
					 inner join match.DocumentHeader_Edi856FbId I (nolock) on b.[PrevailResultMatchedUntNId] = I.FbNId
					 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock)
							on I.Document_Id = h.Document_Id
					 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
							 on h.Document_Id = d.Document_Id

							if (@includeDebugInformation = 1)
						  begin
							   select '#documentinfo1 - Post TrackingNumberPack' as [#documentinfo1 - ParcelTrackingNumber], * from #documentInfo1
							end

					-- remove those ParcelTrackingNumber that already pulled data
				 delete b
				   from @TrackingNumberPack b
				  where exists(select 1 from #documentInfo1 bm where b.Document_Id = bm.Document_Id)

				set @maxLookupAttempts = @maxLookupAttempts - 1
		   end -- end while

		end -- end TrackingNumberPack

-- If there's a match to ParcelTrackingNumber
------------------------------------------------------------------------------------------------------------------
		 if ( exists(select 1 from @matchMetrics where PrevailResultMatchedCorrelations like '%ToParcelTrackingNumber%') )
		 begin
					declare @ParcelTrackingNumber table(
							[PrevailResultMatchedUntNId] varchar(28),
							[TrackingNumberPack] varchar(255),
							[Document Correlations] varchar(500),
							[Exclude_From_Match] bit,
							[Exclude_From_Cost_Allocation] bit,
							[Exclusion_Message] varchar(55),
							[Document_Id] uniqueidentifier)

				insert into @ParcelTrackingNumber
					 select [PrevailResultMatchedUntNId],
							[ArgsNumberPatternBase] as [TrackingNumberPack],
					 		[PrevailResultMatchedCorrelations] as [Document Correlations],
							[Exclude_From_Match],
							[Exclude_From_Cost_Allocation],
							[Exclusion_Message],
							i.Document_Id
					   from @matchMetrics m
					   left join match.DocumentHeader_Edi856FbId I (nolock) on m.[PrevailResultMatchedUntNId] = I.FbNId
					  where PrevailResultMatchedCorrelations like '%ToParcelTrackingNumber%'

						set @maxLookupAttempts = 4
					  while (@maxLookupAttempts >= 0 and exists(select 1 from @ParcelTrackingNumber))
					  begin
							 if (@includeDebugInformation = 1)
						  begin
							   select '@ParcelTrackingNumber' as [@ParcelTrackingNumber], *, abs(@maxLookupAttempts - 5) as [iteration] from @ParcelTrackingNumber
							end

					insert into #documentInfo1(
								[Document_Id],
								[Ranked],
								[OwnerKey],
								[Document_Type],
								[Source_System],
								[Shipment_Id],
								[PO_Number],
								[BOL_Number],
								[Tracking_Number],
								[MAWB_Number],
								[HAWB_Number],
								[Container_Number],
								[Consolidation_Number],
								[Carrier_Code],
								[Mode],
								[Service_Level],
								[SAP Delivery Number],
								[Ship_Date],
								[Total_Weight],
								[Total_Weight_UOM],
								[Leg_Number],
								[Segment Customer Order Number],
								[Sales Organization],
								[Plant ID],
								[Shipping Point],
								[Ship_From_Location_Id],
								[Ship_From_City],
								[Ship_From_State],
								[Ship_From_Post_Code],
								[Ship_From_Country],
								[Ship_To_Location_Id],
								[Ship_To_City],
								[Ship_To_State],
								[Ship_To_Post_Code],
								[Ship_To_Country],
								[Sold_To_Location_Id],
								[Sales Office],
								[Distribution_Channel],
								[Line_Id],
								[Line_Number],
								[Line_Weight],
								[Line_Weight_UOM],
								[Part_Number],
								[Part_Description],
								[Quantity],
								[Box ID],
								[Profit Center],
								[Product Line],
								[CA Updated],
								[CA_ConfigTemplate_RecordId],
								[WinningMethod],
								[Match Concept],
								[Document Correlations],
								[Exclude_From_Match],
								[Exclude_From_Cost_Allocation],
								[Exclusion_Message])
						 select
								h.[Document_Id],
								rank() over (partition by h.[Shipment_Id] order by h.[Ship_Date] desc) as [Ranked],
								substring(@masterFbId,5,3) + '-' + substring(@masterFbId,8,4) as [OwnerKey],
								h.[Document_Type],
								h.[Source_System],
								h.[Shipment_Id],
								h.[PO_Number],
								h.[BOL_Number],
								h.[Tracking_Number],
								h.[MAWB_Number],
								h.[HAWB_Number],
								h.[Container_Number],
								h.[Consolidation_Number],
								h.[Carrier_Code],
								h.[Mode],
								h.[Service_Level],
								h.[SAP Delivery Number],
								h.[Ship_Date],
								h.[Total_Weight],
								h.[Total_Weight_UOM],
								h.[Leg_Number],
								h.[Seg. Customer Order Number],
								h.[Sales Organization],
								h.[Plant ID],
								h.[Shipping Point],
								h.[Ship_From_Location_Id],
								h.[Ship_From_City],
								h.[Ship_From_State],
								h.[Ship_From_Post_Code],
								h.[Ship_From_Country],
								h.[Ship_To_Location_Id],
								h.[Ship_To_City],
								h.[Ship_To_State],
								h.[Ship_To_Post_Code],
								h.[Ship_To_Country],
								h.[Sold_To_Location_Id],
								h.[Sales Office],
								h.[Distribution_Channel],
								d.[Line_Id],
								d.[Line_Number],
								d.[Line_Weight],
								d.[Line_Weight_UOM],
								d.[Part_Number],
								d.[Part_Description],
								d.[Quantity],
								d.[Box ID],
								d.[Profit Center],
								d.[Product Line],
								0 as [CA Updated],
								null as [CA_ConfigTemplate_RecordId],
								null as [WinningMethod],
								'ParcelTrackingNumber' [Match Concept],
								b.[Document Correlations],
								b.[Exclude_From_Match],
								b.[Exclude_From_Cost_Allocation],
								b.[Exclusion_Message]
						   from @ParcelTrackingNumber b
					 inner join match.DocumentHeader_Edi856FbId I (nolock) on b.[PrevailResultMatchedUntNId] = I.FbNId
					 inner join [HPiASN].[Match].[HPI_ASN_FlatHeader] h with(nolock) on I.Document_Id = h.Document_Id
					 inner join [HPiASN].[Match].[HPI_ASN_FlatDetail] d with(nolock)
							 on h.Document_Id = d.Document_Id

							if (@includeDebugInformation = 1)
						  begin
							   select '#documentinfo1 - Post ParcelTrackingNumber' as [#documentinfo1 - ParcelTrackingNumber], * from #documentInfo1
							end



					-- remove those ParcelTrackingNumber that already pulled data
				 delete b
				   from @ParcelTrackingNumber b
				  where exists(select 1 from #documentInfo1 bm where b.Document_Id = bm.Document_Id)

				set @maxLookupAttempts = @maxLookupAttempts - 1
		   end -- end while

		end -- end ParcelTrackingNumber

	if (@includeDebugInformation = 1)
 begin
		select '#documentInfo1' as [#documentInfo1], * from #documentInfo1
   end


----------------------------------- PART 15 END -------------------------------------------------------------------------------



----------------------------------- PART 16 START -------------------------------------------------------------------------------




------------------------------------------------------------------------------------------------------------------
--	if matched to sales org CN09 (but there are other sales orgs) then remove CN09
------------------------------------------------------------------------------------------------------------------
	if (exists(select 1 from #documentInfo1 where [Sales Organization] <> 'CN09'))
 begin
		delete
		  from #documentInfo1
		 where [Sales Organization] = 'CN09'
   end

	if (@includeDebugInformation = 1)
 begin
		select '#documentInfo1 - post removing CN09 records' as [#documentInfo1 - post removing CN09 records], * from #documentInfo1
   end


----------------------------------- PART 16 END -------------------------------------------------------------------------------





----------------------------------- PART 17 START -------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------
--	Remove ASNs matched older than 356 days default and if it is configured for parcel scac's
--  PDV-12128 - Added logic to lookup into a Table config, If no record exist, use default 365.
------------------------------------------------------------------------------------------------------------------
	declare @asnMatchDateDaysValid int = 365

	-- Lookup Config Table for custom ASN Match Date Valid
	select @asnMatchDateDaysValid = isnull([Days Valid],@asnMatchDateDaysValid)
	from [ownca].[GlobalMatchASNDaysValid]
	where [Active] = 1 and [Customer Code] = @ownerKey and [SCAC (FB)] = @vendLabl

	 update d
		set d.Exclusion_Message = isnull(d.Exclusion_Message, 'Diff between FB and ASN ship date is over ' + CAST(@asnMatchDateDaysValid as varchar(20)) + ' days'),
			@exclusionMessage = isnull(@exclusionMessage, 'Diff between FB and ASN ship date is over ' + CAST(@asnMatchDateDaysValid as varchar(20)) + ' days')
	   from #documentInfo1 d
	  where abs(datediff(day, d.[Ship_Date], @fbShipDate)) > @asnMatchDateDaysValid	-- if either date is interchanged, will still show a positive number
	  and @vendlabl not in ('IHUB')

	if (@includeDebugInformation = 1)
 begin
		select 'ASN Matched Days Valid' as [ASN Matched Days Valid], @asnMatchDateDaysValid
		select '#documentInfo1 - post removing ASNs matches older than ' + CAST(@asnMatchDateDaysValid as varchar(20)) + ' days' as [#documentInfo1 - post removing ASNs matches older than valid days], @asnMatchDateDaysValid
   end


----------------------------------- PART 17 END -------------------------------------------------------------------------------



----------------------------------- PART 18 START -------------------------------------------------------------------------------



-- remove records that have an exclusion message
	 delete d from #documentInfo1 d where (Exclusion_Message is not null) and (d.Exclusion_Message not like '%configuration%')

------------------------------------------------------------------------------------------------------------------
--	Exclude ASNs with specific carrier from matching as it’s a dummy record - MANC-565
------------------------------------------------------------------------------------------------------------------
	 update d
		set d.Exclusion_Message = isnull(d.Exclusion_Message, 'Exclude Carrier (POA,POX,SPE) from matching as its dummy record'),
			@exclusionMessage = isnull(@exclusionMessage, 'Exclude Carrier (POA,POX,SPE) from matching as its dummy record')
	   from #documentInfo1 d
	  where Carrier_Code in ('POA','POX','SPE')

	if (@includeDebugInformation = 1)
 begin
		select 'Exclude Carrier (POA,POX,SPE) from matching as its dummy record' as [#documentInfo1 - Exclude Carrier (POA,POX,SPE) from matching as its dummy record], Exclusion_Message, Carrier_Code, * from #documentInfo1
   end





-- remove records that have an exclusion message
	 delete d from #documentInfo1 d where (Exclusion_Message is not null) and (d.Exclusion_Message not like '%configuration%')


----------------------------------- PART 18 END -------------------------------------------------------------------------------



----------------------------------- PART 19 START -------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
--	Remove the ASNs that were flagged as invalid in Accruals
------------------------------------------------------------------------------------------------------------------
/* Remove For now since we have not complete run the Duplicate validation */
/*
-- adding special step for duplicate since writing into the final table is very slow and this needs to be validated first
-- remove ASNs that haven't run through the duplicate validation logic
	 update m
		set m.Exclusion_Message = 'ASN not in accruals report',
			@exclusionMessage = isnull(@exclusionMessage, 'ASN not in accruals report')
	   from #documentInfo1 m
	  where not exists(
	  			 select 1
	  			   from HpiASN.Match.HPI_ASN_DuplicateValidation d with(nolock)
	  			  where m.Document_Id = d.ASN_Document_Id)

		 if ( @includeDebugInformation =  1 )
	  begin
			 select '#documentInfo1 - post removing ASNs not refreshed in Accruals report' as [#documentInfo1 - post removing ASNs not refreshed in Accruals report], * from #documentInfo1
		end

-- remove records that have an exclusion message
	 delete rf from #documentInfo1 rf where (rf.Exclusion_Message is not null) and (rf.Exclusion_Message not like '%configuration%')
*/

-- remove ASNs that ran through the duplicate validation logic and were flagged as not valid
	 update m
		set m.Exclusion_Message = 'ASN removed because flagged as duplicate',
			@exclusionMessage = isnull(@exclusionMessage, 'ASN removed because flagged as duplicate')
	   from #documentInfo1 m
	  where exists(
	  			 select 1
	  			   from HpiASN.Match.HPI_ASN_DuplicateValidation d with(nolock)
	  			  where m.document_id = d.ASN_Document_Id
					and IsValid = 0)

		 if ( @includeDebugInformation =  1 )
	  begin
			 select '#documentInfo1 - post removing ASNs flagged as duplicate' as [#documentInfo1 - post removing ASNs flagged as duplicate], Document_Id, [Match Concept], [Match Value], Ship_From_Country, Ship_To_Country, Leg_Number, Exclusion_Message, * from #documentInfo1
		end

----------------------------------- PART 19 END -------------------------------------------------------------------------------


----------------------------------- PART 20 START -------------------------------------------------------------------------------



-- delete records flagged as invalid in the accruals report
	 update m
		set m.Exclusion_Message = 'ASN not valid in accruals report',
			@exclusionMessage = isnull(@exclusionMessage, 'ASN not valid in accruals report')
	   from #documentInfo1 m
	  where exists(
	  			 select 1
	  			   from HpiASN.match.HPI_ASN_MatchReport r with(nolock)
	  			  where m.Document_id = r.ASN_Document_Id
	  			  	and r.[Most_Recent_Validation] = 0
	  		)

		 if ( @includeDebugInformation =  1 )
	  begin
			 select '#documentInfo1 - post deleting invalid in accruals' as [#documentInfo1 - post deleting invalid in accruals], Document_Id, [Match Concept], [Match Value], Ship_From_Country, Ship_To_Country, Leg_Number, Exclusion_Message, * from #documentInfo1



		end

----------------------------------- PART 20 END -------------------------------------------------------------------------------



----------------------------------- PART 21 START -------------------------------------------------------------------------------


-- Overriding if it's a valid match but flagged ASN Document is flagged as duplicate

	update m
		set m.Exclusion_Message = null,
			@exclusionMessage = null
	   from #documentInfo1 m
	   where m.[Match Concept] in ('BOL_Number')
			and m.Exclusion_Message in ('ASN removed because flagged as duplicate','ASN not valid in accruals report')

		 if ( @includeDebugInformation =  1 )
	  begin
			 select '#documentInfo1 - post overriding ASN Duplicate Logic' as [#documentInfo1 - post deleting invalid in accruals], Document_Id, [Match Concept], [Match Value], Ship_From_Country, Ship_To_Country, Leg_Number, Exclusion_Message, * from #documentInfo1
		end


----------------------------------- PART 21 END -------------------------------------------------------------------------------




----------------------------------- PART 22 START -------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
--	Lane Precendence Order
------------------------------------------------------------------------------------------------------------------
 if object_id('tempdb..#documentInfo1Ranked') is not null
	   drop table #documentInfo1Ranked

-- remove asn that has exclusion message for ranking
delete
from #documentInfo1
where exclusion_message is not null

if ( @includeDebugInformation =  1 )
	  begin
			select '#documentInfo1 - post deleting asn with exclusion message before lane precedence' as [#documentInfo1 - post deleting asn with exclusion message before lane precedence], Document_Id, [Match Concept], [Match Value], Ship_From_Country, Ship_To_Country, Leg_Number, * from #documentInfo1
      END


----------------------------------- PART 22 END -------------------------------------------------------------------------------



----------------------------------- PART 23 START -------------------------------------------------------------------------------



select *,
	rank() over (partition by [Match Concept],[Match Value] order by case when @alCntryCodeOrig = [Ship_From_Country] and @alCntryCodeDest = [Ship_To_Country] then 1 else 2 end asc) as [RankedRecords]
into #documentInfo1Ranked
from #documentInfo1


DELETE d1
from #documentInfo1 d1
where exists (select 1 from #documentInfo1Ranked ranked where ranked.document_id = d1.document_id and ranked.[RankedRecords] > 1)

--select * from #documentInfo1Ranked


if ( @includeDebugInformation =  1 )
	  begin
			 select 'Fb Origin = ' + @alCntryCodeOrig + ' and Destination = ' +  @alCntryCodeDest as [Fb Origin and Destination]
			 
			 select '#documentInfo1Ranked' as [#documentInfo1Ranked - document lane ranking]
                , Document_Id, [Match Concept], [Match Value], Ship_From_Country, Ship_To_Country, Leg_Number, [RankedRecords] as LaneRanking
                , *
             from #documentInfo1Ranked
             order by [LaneRanking] asc

             select '#documentInfo1 ' as [#documentInfo1 - post deleting after lane precedence],  * from #documentInfo1
		end


----------------------------------- PART 23 END -------------------------------------------------------------------------------




----------------------------------- PART 24 START -------------------------------------------------------------------------------


set @includeDebugInformation = 0

------------------------------------------------------------------------------------------------------------------
--	Keep only the most recent Delivery IDs
------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#documentInfo') is not null drop table #documentInfo

	-- drop table #documentInfo
	
	 create table #documentInfo(
		 	[UniqueRecordId] uniqueidentifier,
			[Document_Id] uniqueidentifier,
			[Ranked] int,
			[OwnerKey] varchar(8),
			[Document_Type] varchar(55),
			[Source_System] varchar(55),
			[Shipment_Id] varchar(55),
			[PO_Number] varchar(55),
			[BOL_Number] varchar(55),
			[Tracking_Number] varchar(55),
			[MAWB_Number] varchar(55),
			[HAWB_Number] varchar(55),
			[Container_Number] varchar(55),
			[Consolidation_Number] varchar(55),
			[Carrier_Code] varchar(10),
			[Mode] varchar(55),
			[Service_Level] varchar(55),
			[SAP Delivery Number] varchar(55),
			[Ship_Date] datetime,
			[Total_Weight] real,
			[Total_Weight_UOM] varchar(10),
			[Leg_Number] int,
			[Segment Customer Order Number] varchar(55),
			[Sales Organization] varchar(55),
			[Plant ID] varchar(55),
			[Shipping Point] varchar(55),
			[Ship_From_Location_Id] varchar(55) null,
			[Ship_From_City] varchar(55) null,
			[Ship_From_State] varchar(55) null,
			[Ship_From_Post_Code] varchar(55) null,
			[Ship_From_Country] varchar(55) null,
			[Ship_To_Location_Id] varchar(55) null,
			[Ship_To_City] varchar(55) null,
			[Ship_To_State] varchar(55) null,
			[Ship_To_Post_Code] varchar(55) null,
			[Ship_To_Country] varchar(55) null,
			[Sold_To_Location_Id] varchar(55) null,
			[Sales Office] varchar(55),
			[Distribution_Channel] varchar(55) null,
			[Line_Id] uniqueidentifier,
			[Line_Number] int,
			[Line_Weight] real,
			[Line_Weight_UOM] varchar(10),
			[Part_Number] varchar(55),
			[Part_Description] nvarchar(255),
			[Quantity] real,
			[Box ID] varchar(55),
			[Profit Center] varchar(55),
			[Product Line] varchar(55),
			[CA Updated] bit,
			[CA_ConfigTemplate_RecordId] int,
			[WinningMethod] varchar(255) null,
			[CA_ELEM_1] varchar(255) null,
			[CA_ELEM_2] varchar(255) null,
			[CA_ELEM_3] varchar(255) null,
			[CA_ELEM_4] varchar(255) null,
			[CA_ELEM_5] varchar(255) null,
			[CA_ELEM_6] varchar(255) null,
			[CA_ELEM_7] varchar(255) null,
			[CA_ELEM_8] varchar(255) null,
			[CA_ELEM_9] varchar(255) null,
			[CA_ELEM_10] varchar(255) null,
			[CA_ELEM_11] varchar(255) null,
			[CA_ELEM_12] varchar(255) null,
			[Match Concept] varchar(255) null,
			[Document Correlations] varchar(500),
			[Exclude_From_Match] bit,
			[Exclude_From_Cost_Allocation] bit,
			[Exclusion_Message] varchar(255))
	 create nonclustered index [#documentInfo:CA_ELEM_7] on #documentInfo([CA_ELEM_7]) include ([UniqueRecordId],[Product Line])

	-- create nonclustered index [#documentInfo:OwnerKey,SenderIdentification,Sales Org] on #documentInfo([OwnerKey],[SenderIdentification],[Sales Organization]) include ([UniqueRecordId],[Sold To Party Identifier],[Ship To Party Identifier],[CA Updated])

	if object_id('tempdb..#uniqueDocumentIds') is not null drop table #uniqueDocumentIds

	 select distinct
	 		[Document_Id],
			[Shipment_Id],
			[Ship_Date],
			[Document Correlations],
			[Exclude_From_Match],
			[Exclude_From_Cost_Allocation],
			[Exclusion_Message]
	   into #uniqueDocumentIds
	   from #documentInfo1

		 if(@includeDebugInformation = 1)
	  begin
			 select '#uniqueDocumentIds' as [#uniqueDocumentIds], * from #uniqueDocumentIds
		end

		 if object_id('tempdb..#mostRecentDocumentIds') is not null drop table #mostRecentDocumentIds
		 select [Document_Id],
			[Shipment_Id],
			[Ship_Date],
			Rank() over (partition by [Shipment_Id] order by Ship_Date desc, case when Exclude_From_Match = 1 then 1 else 0 end asc, case when Exclude_From_Cost_Allocation = 1 then 1 else 0 end asc, case when Exclusion_Message is not null then 1 else 0 end asc, [Document Correlations] desc) as Ranked
	   into #mostRecentDocumentIds
	   from #uniqueDocumentIds

		 if(@includeDebugInformation = 1)
	  begin
			 select '#mostRecentDocumentIds' as [#mostRecentDocumentIds], * from #mostRecentDocumentIds
		end

	 delete
	   from #mostRecentDocumentIds
	  where Ranked > 1

		 if(@includeDebugInformation = 1)
	  begin
			 select '#mostRecentDocumentIds - post deleting' as [#mostRecentDocumentIds - post deleting], * from #mostRecentDocumentIds
		end



--Select '#uniqueDocumentIds' as [#uniqueDocumentIds], * from #uniqueDocumentIds

--select '#mostRecentDocumentIds' as [#mostRecentDocumentIds], * from #mostRecentDocumentIds

--select '#mostRecentDocumentIds - post deleting' as [#mostRecentDocumentIds - post deleting], * from #mostRecentDocumentIds

--set @includeDebugInformation = 1


----------------------------------- PART 24 END -------------------------------------------------------------------------------



----------------------------------- PART 25 START -------------------------------------------------------------------------------




------------------------------------------------------------------------------------------------------------------
--	Populate the final desadv info records
------------------------------------------------------------------------------------------------------------------
insert into #documentInfo(
			[UniqueRecordId],
			[Document_Id],
			[Ranked],
			[OwnerKey],
			[Document_Type],
			[Source_System],
			[Shipment_Id],
			[PO_Number],
			[BOL_Number],
			[Tracking_Number],
			[MAWB_Number],
			[HAWB_Number],
			[Container_Number],
			[Consolidation_Number],
			[Carrier_Code],
			[Mode],
			[Service_Level],
			[SAP Delivery Number],
			[Ship_Date],
			[Total_Weight],
			[Total_Weight_UOM],
			[Leg_Number],
			[Segment Customer Order Number],
			[Sales Organization],
			[Plant ID],
			[Shipping Point],
			[Ship_From_Location_Id],
			[Ship_From_City],
			[Ship_From_State],
			[Ship_From_Post_Code],
			[Ship_From_Country],
			[Ship_To_Location_Id],
			[Ship_To_City],
			[Ship_To_State],
			[Ship_To_Post_Code],
			[Ship_To_Country],
			[Sold_To_Location_Id],
			[Sales Office],
			[Distribution_Channel],
			[Line_Id],
			[Line_Number],
			[Line_Weight],
			[Line_Weight_UOM],
			[Part_Number],
			[Part_Description],
			[Quantity],
			[Box ID],
			[Profit Center],
			[Product Line],
			[CA Updated],
			[CA_ConfigTemplate_RecordId],
			[WinningMethod],
			[CA_ELEM_1],
			[CA_ELEM_2],
			[CA_ELEM_3],
			[CA_ELEM_4],
			[CA_ELEM_5],
			[CA_ELEM_6],
			[CA_ELEM_7],
			[CA_ELEM_8],
			[CA_ELEM_9],
			[CA_ELEM_10],
			[CA_ELEM_11],
			[CA_ELEM_12],
			[Match Concept],
			[Document Correlations],
			[Exclude_From_Match],
			[Exclude_From_Cost_Allocation],
			[Exclusion_Message])
	 select newid() as [UniqueRecordId],
			[Document_Id],
			[Ranked],
			[OwnerKey],
			[Document_Type],
			[Source_System],
			[Shipment_Id],
			[PO_Number],
			[BOL_Number],
			[Tracking_Number],
			[MAWB_Number],
			[HAWB_Number],
			[Container_Number],
			[Consolidation_Number],
			[Carrier_Code],
			[Mode],
			[Service_Level],
			[SAP Delivery Number],
			[Ship_Date],
			[Total_Weight],
			[Total_Weight_UOM],
			[Leg_Number],
			[Segment Customer Order Number],
			[Sales Organization],
			[Plant ID],
			[Shipping Point],
			[Ship_From_Location_Id],
			[Ship_From_City],
			[Ship_From_State],
			[Ship_From_Post_Code],
			[Ship_From_Country],
			[Ship_To_Location_Id],
			[Ship_To_City],
			[Ship_To_State],
			[Ship_To_Post_Code],
			[Ship_To_Country],
			[Sold_To_Location_Id],
			[Sales Office],
			[Distribution_Channel],
			[Line_Id],
			[Line_Number],
			[Line_Weight],
			[Line_Weight_UOM],
			[Part_Number],
			[Part_Description],
			[Quantity],
			[Box ID],
			[Profit Center],
			[Product Line],
			[CA Updated],
			[CA_ConfigTemplate_RecordId],
			[WinningMethod],
			[CA_ELEM_1],
			[CA_ELEM_2],
			[CA_ELEM_3],
			[CA_ELEM_4],
			[CA_ELEM_5],
			[CA_ELEM_6],
			[CA_ELEM_7],
			[CA_ELEM_8],
			[CA_ELEM_9],
			[CA_ELEM_10],
			[CA_ELEM_11],
			[CA_ELEM_12],
			[Match Concept],
			[Document Correlations],
			[Exclude_From_Match],
			[Exclude_From_Cost_Allocation],
			[Exclusion_Message]
	   from #documentInfo1 d
	  where exists(
			 select 1
			   from #mostRecentDocumentIds r
			  where d.Document_Id = r.Document_Id)

	if (@includeDebugInformation = 1)
 begin
		select '#documentInfo' as [#documentInfo], * from #documentInfo
   end



----------------------------------- PART 25 END -------------------------------------------------------------------------------




----------------------------------- PART 26 START -------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------
--	For HPi, exclude ASNs before 2015.08.01 (HP Split Date) - ICS 626904
------------------------------------------------------------------------------------------------------------------
		 if (@ownerKey in ('100-0616', '100-0671', '100-0678'))
	  begin
			delete
			  from #documentInfo
			  where [Ship_Date] < '20150801'
		end


	if (@includeDebugInformation = 1)
 begin
		select '#documentInfo - post delete ASNs pre-split' as [#documentInfo - post delete ASNs pre-split], * from #documentInfo
   end



----------------------------------- PART 26 END -------------------------------------------------------------------------------




----------------------------------- PART 27 START -------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Match to US domestic shipment. Requires manual review – MANC-612
------------------------------------------------------------------------------------------------------------------
	if (@ownerKey in ('100-0681','100-0691'))
	  begin
			update d
			  set d.Exclusion_Message =isnull(d.Exclusion_Message, 'configuration - Match to US domestic shipment. Requires manual review'),
			  @exclusionMessage = isnull(@exclusionMessage, 'configuration- Match to US domestic shipment. Requires manual review')
			from #documentInfo d
			where Ship_From_Country ='US'and Ship_To_Country ='US'
	  end

		 if( exists( select 1 from #documentInfo where Exclusion_Message like '%Match to US Domestic Shipment%' ) )
	 begin
	 	insert into dbo.HPi_US_Domestic_Exclusions
		Select Document_Id,@masterFbId as FbId, @exclusionMessage as Exclusion_Messsage
		from #documentInfo
		where Exclusion_Message like '%Match to US domestic shipment%'
		and not exists(
						select FBID, us.Document_ID
						from #documentinfo d
						join dbo.HPi_US_Domestic_Exclusions (nolock) us
						on us.FbId = @MasterFbId
						and d.Document_ID = us.Document_ID)
	 end

		if (@includeDebugInformation =1)
	  begin
		select'#documentInfo - Match to US domestic shipment. Requires manual review' as [documentInfo - post delete ASNs pre-split], * from #documentInfo
	  end




----------------------------------- PART 27 END -------------------------------------------------------------------------------





----------------------------------- PART 28 START -------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
--	Update Cost Allocation
------------------------------------------------------------------------------------------------------------------

begin -- region Do CA

------------------------------------------------------------------------------------------------------------------
--	update CA records -- Precedence 1
------------------------------------------------------------------------------------------------------------------

-- select * from [HPiCostAllocationProd]. [ownca].[GlobalMatch]
-- select * from [HPiCostAllocationProd]. [ownca].[GlobalMatchSCAC]
-- select * from [HPiCostAllocationProd]. [ownca].[GlobalMatchSCAC_V2]

if( exists( select 1 from #documentInfo where isnull([CA Updated],0) = 0 ) )
begin

------------------------------------------------------------------------------------------------------------------
--	Determine the winning CA config record
------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#CaInfo_GlobalMatchSCAC_V2') is not null
	drop table #CaInfo_GlobalMatchSCAC_V2;

	  with cte_CaInfo_GlobalMatchSCAC_V2 as (
			 select [UniqueRecordId],
					@ownerkey as [OwnerKey],
					[Source_System], -- SenderIdentification,
					@VendLabl as [SCAC],
					[Sales Organization],
					[Ship_From_Country],
					[Ship_To_Country],
					@fbCurrencyQual as [Currency_Qual],
					isnull([CA Updated],0) as [CA Updated]
			   from #documentInfo
			  where isnull([CA Updated],0) = 0
				and Exclude_From_Match = 0
				and Exclude_From_Cost_Allocation = 0
   )


	select *,
		   rank() over (partition by UniqueRecordId order by Score desc) as Ranked
	  into #CaInfo_GlobalMatchSCAC_V2
	  from (
					select m.UniqueRecordId,
						   r.*,
						   -- adds a score for being there. Score so high so records with more fields populated win (more specific)
						   case when r.[Customer Code] is not null then 100 else 0 end +
						   case when r.[Sender Id (ASN)] is not null then 100 else 0 end +
						   case when r.[SCAC (FB)] is not null then 100 else 0 end +
						   case when r.[Sales Org (ASN)] is not null then 100 else 0 end +
						   case when r.[Ship from Cntry (ASN)] is not null then 100 else 0 end +
						   case when r.[Ship from Cntry (ASN)] is not null then 100 else 0 end +
						   case when r.[Currency (FB)] is not null then 100 else 0 end +
						   -- adds a score for precedence of columns order (to break the tie between those with the same amount of fields populated)
						   case when m.[OwnerKey] = r.[Customer Code] then 16 else 0 end +
						   case when m.[Source_System] = r.[Sender Id (ASN)] then 15 else 0 end +
						   case when m.[SCAC] = r.[SCAC (FB)] then 14 else 0 end +
						   case when m.[Sales Organization] = r.[Sales Org (ASN)] then 13 else 0 end +
						   case when m.[Ship_To_Country] = r.[Ship To Cntry (ASN)] then 12 else 0 end +
						   case when m.[Ship_From_Country] = r.[Ship from Cntry (ASN)] then 11 else 0 end +
						   case when m.[Currency_Qual] = r.[Currency (FB)] then 10 else 0 end as Score
						   -- select *
					  --from #documentInfo m with(index([#documentInfo:GlobalMatch]))
					  from cte_CaInfo_GlobalMatchSCAC_V2 m
				inner join OwnCa.GlobalMatchSCAC_V2 r with(nolock, index([GlobalMatchSCACCI]))
					   on  (m.[OwnerKey] = r.[Customer Code])
					   and (m.[Source_System] = r.[Sender Id (ASN)])
					   and (m.[SCAC] = r.[SCAC (FB)])
					   and (m.[Sales Organization] = r.[Sales Org (ASN)] or r.[Sales Org (ASN)] is null)
					   and (m.[Ship_From_Country] = r.[Ship from Cntry (ASN)] or r.[Ship from Cntry (ASN)] is null)
					   and (m.[Ship_To_Country] = r.[Ship To Cntry (ASN)] or r.[Ship To Cntry (ASN)] is null)
					   and (m.[Currency_Qual] = r.[Currency (FB)] or r.[Currency (FB)] is null)
					 where r.Active = 1
		   )x
	

	SET @includeDebugInformation = 1

		 if @includeDebugInformation = 1
	 select '#CaInfo_GlobalMatchSCAC_V2' as [#CaInfo_GlobalMatchSCAC_V2], * from #CaInfo_GlobalMatchSCAC_V2

		if @includeDebugInformation = 1
	 select '#GlobalMatchSCAC_V2 - *' as [#GlobalMatchSCAC_V2 - *],* from ownca.GlobalMatchSCAC_V2 where [Customer Code] = @ownerkey

		if @includeDebugInformation = 1
	 select '#GlobalMatchSCAC_V2 Variable Check' as [#GlobalMatchSCAC_V2 Variable Check],
					@ownerkey as [OwnerKey],
					[Source_System], -- SenderIdentification,
					@VendLabl as [SCAC],
					[Sales Organization],
					[Ship_From_Country],
					[Ship_To_Country],
					@fbCurrencyQual as [Curency_Qual],
					isnull([CA Updated],0) as [CA Updated]
			   from #documentInfo
			  where isnull([CA Updated],0) = 0
				and Exclude_From_Match = 0
				and Exclude_From_Cost_Allocation = 0



----------------------------------- PART 28 END -------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------
--	Remove those records that are not the winning ones
------------------------------------------------------------------------------------------------------------------
	delete
	  from #CaInfo_GlobalMatchSCAC_V2
	 where Ranked <> 1

------------------------------------------------------------------------------------------------------------------
--	Update the results back to the main control table
------------------------------------------------------------------------------------------------------------------
	update m
	   set m.CA_Elem_1 = ca.[CA Elem 1],
		   m.CA_Elem_2 = ca.[CA Elem 2],
		   m.CA_Elem_3 = ca.[CA Elem 3],
		   m.CA_Elem_4 = ca.[CA Elem 4],
		   m.CA_Elem_5 = ca.[CA Elem 5],
		   m.CA_Elem_6 = ca.[CA Elem 6],
		   m.CA_Elem_7 = ca.[CA Elem 7],
		   m.CA_Elem_8 = ca.[CA Elem 8],
		   m.CA_Elem_9 = ca.[CA Elem 9],
		   m.CA_Elem_10 = ca.[CA Elem 10],
		   m.CA_Elem_11 = ca.[CA Elem 11],
		   m.CA_Elem_12 = m.Shipment_id, --ca.[CA Elem 12], -- MANC-564
		   m.CA_ConfigTemplate_RecordId = ca.[Record ID],
		   m.[CA Updated] = 1,
		   m.WinningMethod = '[OwnCa].[CaInfo_GlobalMatchSCAC_V2]'
	  from #documentInfo m
inner join #CaInfo_GlobalMatchSCAC_V2 ca
		on m.UniqueRecordId = ca.UniqueRecordId

end

------------------------------------------------------------------------------------------------------------------
-- FSE-1145 - prevailing rule from Global SCAC Match if one existed for the same shipment id with different legs
-- Initial rollout will be limited to the HPI EMEA - DMCQ lane to validate behavior before broader enablement.
------------------------------------------------------------------------------------------------------------------
if @ownerKey = '100-0681_S4' and @vendLabl = 'DMCQ'
begin
	if @includeDebugInformation = 1
		select 'Before update CA records -- Precedence 2', * from #documentInfo

	-- Store into temp table for those shipment id that already have the winner
	if OBJECT_ID('tempdb..#asnGlobalSCACMatch') is not null drop table #asnGlobalSCACMatch
	select document_id, carrier_code, Shipment_Id, [CA Updated], CA_ConfigTemplate_RecordId, WinningMethod
	into #asnGlobalSCACMatch
	from #documentInfo
	where [CA Updated]=1

	if @includeDebugInformation = 1
		select '#asnGlobalSCACMatch - Get Shipment Ids that were already allocated', * from #asnGlobalSCACMatch

	-- Exclude from CA for ASN's already have prevailing rule from Global SCAC Match not yet allocated
	update d
	set 
		d.Exclude_From_Cost_Allocation = 1,
		d.Exclusion_Message = 'prevailing rule from Global SCAC Match'
	from #documentInfo d
	inner join #asnGlobalSCACMatch a on d.shipment_id = a.shipment_id
	where d.[CA Updated]=0

	if @includeDebugInformation = 1
	select 'Post #asnGlobalSCACMatch - Get Shipment Ids that were already allocated', * from #documentInfo
end 

------------------------------------------------------------------------------------------------------------------
--	update CA records -- Precedence 2
------------------------------------------------------------------------------------------------------------------

if( exists( select 1 from #documentInfo where isnull([CA Updated],0) = 0 ) )
begin

------------------------------------------------------------------------------------------------------------------
--	Determine the winning CA config record
------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#CaInfo_GlobalMatch') is not null
	drop table #CaInfo_GlobalMatch;

	  with cte_CaInfo_GlobalMatch as (
			 select [UniqueRecordId],
					@ownerkey as [OwnerKey],
					[Source_System], -- SenderIdentification,
					@VendLabl as [SCAC],
					[Distribution_Channel],
					[Sales Organization],
					[Sales Office],
					[Segment Customer Order Number],
					[Ship_From_Country],
					[Plant ID],
					[Shipping Point],
					[Ship_To_Country],
					[Ship_To_Location_Id],
					[Sold_To_Location_Id],
					[Product Line],
					[Mode],
					[Leg_Number],
					isnull([CA Updated],0) as [CA Updated]
			   from #documentInfo
			  where isnull([CA Updated],0) = 0
				and Exclude_From_Match = 0
				and Exclude_From_Cost_Allocation = 0
   )
   --select top 100 * from cte_CaInfo_SoldToId_ShipToId

	select *,
		   rank() over (partition by UniqueRecordId order by Score desc) as Ranked
	  into #CaInfo_GlobalMatch
	  from (
					select m.UniqueRecordId,
						   r.*,
						   -- adds a score for being there. Score so high so records with more fields populated win (more specific)
						   case when r.[Customer Code] is not null then 100 else 0 end +
						   case when r.[Sender Id] is not null then 100 else 0 end +
						   case when r.[SCAC] is not null then 100 else 0 end +
						   case when r.[Distribution Channel] is not null then 100 else 0 end +
						   case when r.[Sales Org] is not null then 100 else 0 end +
						   case when r.[Sales Office] is not null then 100 else 0 end +
						   case when r.[Segment Customer Order Number] is not null then 100 else 0 end +
						   case when r.[Ship from Cntry] is not null then 100 else 0 end +
						   case when r.[Plant Code] is not null then 100 else 0 end +
						   case when r.[Shipping Point] is not null then 100 else 0 end +
						   case when r.[Ship to Cntry] is not null then 100 else 0 end +
						   case when r.[Sold To Party ID] is not null then 100 else 0 end +
						   case when r.[Ship To Party ID] is not null then 100 else 0 end +
						   case when r.[PL] is not null then 100 else 0 end +
						   case when r.[Mode (ASN)] is not null then 100 else 0 end +
						   case when r.[Leg Number (ASN)] is not null then 100 else 0 end +
						   -- adds a score for precedence of columns order (to break the tie between those with the same amount of fields populated)
						   case when m.[OwnerKey] = r.[Customer Code] then 16 else 0 end +
						   case when m.[Source_System] = r.[Sender Id] then 15 else 0 end +
						   case when m.[SCAC] = r.[SCAC] then 14 else 0 end +
						   case when m.[Distribution_Channel] = r.[Distribution Channel] then 13 else 0 end +
						   case when m.[Sales Organization] = r.[Sales Org] then 12 else 0 end +
						   case when m.[Sales Office] = r.[Sales Office] then 11 else 0 end +
						   case when m.[Segment Customer Order Number] = r.[Segment Customer Order Number] then 10 else 0 end +
						   case when m.[Ship_From_Country] = r.[Ship from Cntry] then 9 else 0 end +
						   case when m.[Plant ID] = r.[Plant Code] then 8 else 0 end +
						   case when m.[Shipping Point] = r.[Shipping Point] then 7 else 0 end +
						   case when m.[Ship_To_Country] = r.[Ship to Cntry] then 6 else 0 end +
						   case when m.[Ship_To_Location_Id] = r.[Sold To Party ID] then 5 else 0 end +
						   case when m.[Sold_To_Location_Id] = r.[Ship To Party ID] then 4 else 0 end +
						   case when m.[Product Line] = r.[PL] then 3 else 0 end +
						   case when m.[Mode] = r.[Mode (ASN)] then 2 else 0 end +
						   case when m.[Leg_Number] = r.[Leg Number (ASN)] then 1 else 0 end as Score
						   -- select *
					  --from #documentInfo m with(index([#documentInfo:GlobalMatch]))
					  from cte_CaInfo_GlobalMatch m
				inner join OwnCa.GlobalMatch r with(nolock, index([OwnCa.GlobalMatch:Customer Code]))
					   on  (m.[OwnerKey] = r.[Customer Code])
					   and (m.[Source_System] = r.[Sender Id])
					   and (m.[SCAC] = r.[SCAC] or r.[SCAC] is null)
					   and (m.[Distribution_Channel] = r.[Distribution Channel] or r.[Distribution Channel] is null)
					   and (m.[Sales Organization] = r.[Sales Org] or r.[Sales Org] is null)
					   and (m.[Sales Office] = r.[Sales Office] or r.[Sales Office] is null)
					   and (m.[Segment Customer Order Number] = r.[Segment Customer Order Number] or r.[Segment Customer Order Number] is null)
					   and (m.[Ship_From_Country] = r.[Ship from Cntry] or r.[Ship from Cntry] is null)
					   and (m.[Plant ID] = r.[Plant Code] or r.[Plant Code] is null)
					   and (m.[Shipping Point] = r.[Shipping Point] or r.[Shipping Point] is null)
					   and (m.[Ship_To_Country] = r.[Ship To Cntry] or r.[Ship To Cntry] is null)
					   and (m.[Ship_To_Location_Id] = r.[Ship To Party ID] or r.[Ship To Party ID] is null)
					   and (m.[Sold_To_Location_Id] = r.[Sold To Party ID] or r.[Sold To Party ID] is null)
					   and (m.[Product Line] = r.[PL] or r.[PL] is null)
					   and (m.[Mode] = r.[Mode (ASN)] or r.[Mode (ASN)] is null)
					   and (m.[Leg_Number] = r.[Leg Number (ASN)] or r.[Leg Number (ASN)] is null)
					 where r.Active = 1
		   )x

		 if @includeDebugInformation = 1
	 select '#CaInfo_GlobalMatch' as [#CaInfo_GlobalMatch], * from #CaInfo_GlobalMatch

		if @includeDebugInformation = 1
	 select '#GlobalMatch - *' as [#GlobalMatch - *],* from ownca.GLobalMatch where [Customer Code] = @ownerkey

		if @includeDebugInformation = 1
	 select			'#GlobalMatch Variable Check' as [#GlobalMatch Variable Check],
					@ownerkey as [OwnerKey],
					[Source_System], -- SenderIdentification,
					@VendLabl as [SCAC],
					[Distribution_Channel],
					[Sales Organization],
					[Sales Office],
					[Segment Customer Order Number],
					[Ship_From_Country],
					[Plant ID],
					[Shipping Point],
					[Ship_To_Country],
					[Ship_To_Location_Id],
					[Sold_To_Location_Id],
					[Product Line],
					[Mode],
					[Leg_Number],
					isnull([CA Updated],0) as [CA Updated]
			   from #documentInfo
			  where isnull([CA Updated],0) = 0
				and Exclude_From_Match = 0
				and Exclude_From_Cost_Allocation = 0

------------------------------------------------------------------------------------------------------------------
--	Remove those records that are not the winning ones
------------------------------------------------------------------------------------------------------------------
	delete
	  from #CaInfo_GlobalMatch
	 where Ranked <> 1

------------------------------------------------------------------------------------------------------------------
--	Update the results back to the main control table
------------------------------------------------------------------------------------------------------------------
	update m
	   set m.CA_Elem_1 = ca.[CA Elem 1],
		   m.CA_Elem_2 = ca.[CA Elem 2],
		   m.CA_Elem_3 = ca.[CA Elem 3],
		   m.CA_Elem_4 = ca.[CA Elem 4],
		   m.CA_Elem_5 = ca.[CA Elem 5],
		   m.CA_Elem_6 = ca.[CA Elem 6],
		   m.CA_Elem_7 = ca.[CA Elem 7],
		   m.CA_Elem_8 = ca.[CA Elem 8],
		   m.CA_Elem_9 = ca.[CA Elem 9],
		   m.CA_Elem_10 = ca.[CA Elem 10],
		   m.CA_Elem_11 = ca.[CA Elem 11],
		   m.CA_Elem_12 = m.Shipment_id, --ca.[CA Elem 12], -- MANC-564
		   m.CA_ConfigTemplate_RecordId = ca.[Record ID],
		   m.[CA Updated] = 1,
		   m.WinningMethod = '[OwnCa].[CaInfo_GlobalMatch]'
	  from #documentInfo m
inner join #CaInfo_GlobalMatch ca
		on m.UniqueRecordId = ca.UniqueRecordId

end

------------------------------------------------------------------------------------------------------------------
--	update CA records -- Precedence 3
------------------------------------------------------------------------------------------------------------------

-- select * from HPiCostAllocationProd.OwnCa.CostAllocationConfiguration

if( exists( select 1 from #documentInfo where isnull([CA Updated],0) = 0 ) )
begin

------------------------------------------------------------------------------------------------------------------
--	Determine the winning CA config record
------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#CaInfo_CostAllocationConfiguration_S4') is not null
	drop table #CaInfo_CostAllocationConfiguration_S4;

	  with cte_CaInfo_CostAllocationConfiguration_S4 as (
			 select UniqueRecordId,
					@ownerkey as [OwnerKey],
					[Source_System], -- SenderIdentification,
					Null as [ASNBU],
					[Product Line],
					isnull([CA Updated],0) as [CA Updated]
			   from #documentInfo
			  where isnull([CA Updated],0) = 0
				and Exclude_From_Match = 0
				and Exclude_From_Cost_Allocation = 0
   )
   --select top 100 * from cte_CaInfo_SalesOrg


	select *,
		   rank() over (partition by UniqueRecordId order by Score desc) as Ranked
	  into #CaInfo_CostAllocationConfiguration_S4
	  from (
					select m.UniqueRecordId,
						   r.*,
						   -- adds a score for being there. Score so high so records with more fields populated win (more specific)
						   case when r.[Customer Code] is not null then 100 else 0 end +
						   case when r.[Sender Id] is not null then 100 else 0 end +
						   case when r.[ASNBU] is not null then 100 else 0 end +
						   case when r.[ASNPL] is not null then 100 else 0 end +
						   -- adds a score for precedence of columns order (to break the tie between those with the same amount of fields populated)
						   case when r.[Customer Code] is not null then 4 else 0 end +
						   case when r.[Sender Id] is not null then 3 else 0 end +
						   case when r.[ASNBU] is not null then 2 else 0 end +
						   case when r.[ASNPL] is not null then 1 else 0 end as Score
						   -- select *
					  --from #documentInfo m with(index([#documentInfo:SalesOrg]))
					  from cte_CaInfo_CostAllocationConfiguration_S4 m
				inner join HPiCostAllocationProd.OwnCa.CostAllocationConfiguration r with(nolock, index([OwnCa.CostAllocationConfiguratio:Customer Code,ASN Source,ASNBU,ASNPL,Active]))
					   on  (m.[OwnerKey] = r.[Customer Code])
					   and (m.[Source_System] = r.[Sender Id])
					   and (m.[ASNBU] = r.[ASNBU] or r.[ASNBU] is null)
					   and (m.[Product Line] = r.[ASNPL] or r.[ASNPL] is null)
					 where r.Active = 1
		   )x

		 if @includeDebugInformation = 1
	 select '#CaInfo_CostAllocationConfiguration_S4' as [#CaInfo_CostAllocationConfiguration_S4], * from #CaInfo_CostAllocationConfiguration_S4

------------------------------------------------------------------------------------------------------------------
--	Remove those records that are not the winning ones
------------------------------------------------------------------------------------------------------------------
	delete
	  from #CaInfo_CostAllocationConfiguration_S4
	 where Ranked <> 1

------------------------------------------------------------------------------------------------------------------
--	Update the results back to the main control table
------------------------------------------------------------------------------------------------------------------
	update m
	   set m.CA_Elem_1 = ca.[CA Elem 1],
		   m.CA_Elem_2 = ca.[CA Elem 2],
		   m.CA_Elem_3 = ca.[CA Elem 3],
		   m.CA_Elem_4 = ca.[CA Elem 4],
		   m.CA_Elem_5 = ca.[CA Elem 5],
		   m.CA_Elem_6 = ca.[CA Elem 6],
		   m.CA_Elem_7 = ca.[CA Elem 7],
		   m.CA_Elem_8 = ca.[CA Elem 8],
		   m.CA_Elem_9 = ca.[CA Elem 9],
		   m.CA_Elem_10 = ca.[CA Elem 10],
		   m.CA_Elem_11 = ca.[CA Elem 11],
		   m.CA_Elem_12 = m.Shipment_id, --ca.[CA Elem 12], -- MANC-564
		   m.CA_ConfigTemplate_RecordId = ca.[Record ID],
		   m.[CA Updated] = 1,
		   m.WinningMethod = '[hpemea].[CostAllocationConfiguration]'
	  from #documentInfo m
inner join #CaInfo_CostAllocationConfiguration_S4 ca
		on m.UniqueRecordId = ca.UniqueRecordId

end

------------------------------------------------------------------------------------------------------------------
--	Update CA_Elem_6
------------------------------------------------------------------------------------------------------------------
	update #documentInfo
	   set CA_ELEM_6 = [Profit Center]
	 where CA_Elem_6 = 'ASN PL'
		or CA_ELEM_6 = 'ASNPL'

end -- region Do CA


	if (@includeDebugInformation = 1)
 begin
		select '#documentInfo - post CA' as [#documentInfo - post CA], * from #documentInfo
   end

------------------------------------------------------------------------------------------------------------------
--	Collapse all the CA Lines
------------------------------------------------------------------------------------------------------------------
   declare @allCAlinesOK bit = 1
		if (exists(select 1 from #documentInfo where isnull([CA Updated],0) = 0 and Exclude_From_Match = 0 and Exclude_From_Cost_Allocation = 0))
	 begin
		   set @allCAlinesOK = 0
	   end

------------------------------------------------------------------------------------------------------------------
--	At this point, all CN09 records were removed by => if matched to sales org CN09 (but there are other sales orgs) then remove CN09
--	If there are remaining records, then flag results are invalid.
--	There should only be remaining records when CN09 is the only sales org
-- ** 08/03/2018	Rolando.Vargas		Remove CN09 sales orgs when there are other non-CN09 records. Leave CN09 if they're all CN09 records (https://helpcenter.traxtech.com/browse/PD-282)

-- 	if (exists(select 1 from #documentInfo1 where [Sales Organization] = 'CN09'))
--  begin
-- 		   set @allCAlinesOK = 0
--    end

   declare @caLinesCount int

		 if object_id('tempdb..#CA_Lines') is not null
	   drop table #CA_Lines

   -- drop table #CA_Lines
	 create table #CA_Lines(
			[LinePct] float null,
			[CA_Pcnt] float null,
			[CA_Line_Num] int,
			[Line_Weight] decimal(18,5),
			[CA_ELEM_1] varchar(255),
			[CA_ELEM_2] varchar(255),
			[CA_ELEM_3] varchar(255),
			[CA_ELEM_4] varchar(255),
			[CA_ELEM_5] varchar(255),
			[CA_ELEM_6] varchar(255),
			[CA_ELEM_7] varchar(255),
			[CA_ELEM_8] varchar(255),
			[CA_ELEM_9] varchar(255),
			[CA_ELEM_10] varchar(255),
			[CA_ELEM_11] varchar(255),
			[CA_ELEM_12] varchar(255),
			[ShipmentDispatchEventDate] datetime,
			[All CA Lines OK] bit,
			[WinningCaConfigurationConfig] varchar(255),
			[WinningCaConfigurationConfig_RecordId] int,
			-- fields added because they're used by the stored procedure
			[SCS_String] varchar(255) null,
			[Rule_Key_CA] varchar(255) null,
			[CA Combination Validation] varchar(255) null,
			[Is CA Combination Valid] bit null,
			[Results Error Message] varchar(500) null,
			[Results Valid] bit default 1,
			[Exclude_From_Match] bit,
			[Exclude_From_Cost_Allocation] bit,
			[Exclusion_Message] varchar(255))

insert into #CA_Lines(
			[LinePct],
			[CA_Pcnt],
			[CA_Line_Num],
			[Line_Weight],
			[CA_ELEM_1],
			[CA_ELEM_2],
			[CA_ELEM_3],
			[CA_ELEM_4],
			[CA_ELEM_5],
			[CA_ELEM_6],
			[CA_ELEM_7],
			[CA_ELEM_8],
			[CA_ELEM_9],
			[CA_ELEM_10],
			[CA_ELEM_11],
			[CA_ELEM_12],
			[ShipmentDispatchEventDate],
			[All CA Lines OK],
			[WinningCaConfigurationConfig],
			[WinningCaConfigurationConfig_RecordId],
			[Exclude_From_Match],
			[Exclude_From_Cost_Allocation],
			[Exclusion_Message])
	 select null as [LinePct],
			null as [CA_Pcnt],
			row_number() over(order by sum([Line_Weight]) desc, CA_ConfigTemplate_RecordId asc) as [CA_Line_Num],
			sum([Line_Weight]) as [Line_Weight],
			[CA_ELEM_1],
			[CA_ELEM_2],
			[CA_ELEM_3],
			[CA_ELEM_4],
			[CA_ELEM_5],
			[CA_ELEM_6],
			[CA_ELEM_7],
			[CA_ELEM_8],
			isnull(replace(replace(WinningMethod,'[',''),']',''),'')+'.'+isnull(convert(varchar,CA_ConfigTemplate_RecordId),'') as CA_ELEM_9,
			[CA_ELEM_10],
			'FREIGHT' as [CA_ELEM_11],
			[CA_ELEM_12],
			min([Ship_Date]) as [Ship_Date],
			@allCAlinesOK as [All CA Lines OK],
			[WinningMethod] as [WinningCaConfigurationConfig],
			[CA_ConfigTemplate_RecordId] as [WinningCaConfigurationConfig_RecordId],
			[Exclude_From_Match],
			[Exclude_From_Cost_Allocation],
			[Exclusion_Message]
	  -- select *
	   from #documentInfo
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0
   group by [CA_ELEM_1],
			[CA_ELEM_2],
			[CA_ELEM_3],
			[CA_ELEM_4],
			[CA_ELEM_5],
			[CA_ELEM_6],
			[CA_ELEM_7],
			[CA_ELEM_8],
			[CA_ELEM_9],
			[CA_ELEM_10],
			[CA_ELEM_11],
			[CA_ELEM_12],
			[WinningMethod],
			[CA_ConfigTemplate_RecordId],
			[Exclude_From_Match],
			[Exclude_From_Cost_Allocation],
			[Exclusion_Message]

/* -- removing
---------------------------------------------------------------------------------------------------------------------
--	Re-Group the CA lines when they exceed the 99 lines records because of including the winning CA line
---------------------------------------------------------------------------------------------------------------------
	select @caLinesCount = count(1)
	  from #CA_Lines

		if ((@caLinesCount > 99 and Left(@masterfbid,11) <> 'FBLL1000691') or (Left(@masterfbid,11) = 'FBLL1000691' and @caLinesCount>9999))
	 begin

			 if object_id('tempdb..#CA_Lines_99') is not null
		   drop table #CA_Lines_99

		 -- Added columns to have same as #CA_Lines
		 create table #CA_Lines_99(
				[LinePct] float null,
				[CA_Pcnt] float null,
				[CA_Line_Num] int,
				[Line_Weight] decimal(18,5),
				[CA_ELEM_1] varchar(255),
				[CA_ELEM_2] varchar(255),
				[CA_ELEM_3] varchar(255),
				[CA_ELEM_4] varchar(255),
				[CA_ELEM_5] varchar(255),
				[CA_ELEM_6] varchar(255),
				[CA_ELEM_7] varchar(255),
				[CA_ELEM_8] varchar(255),
				[CA_ELEM_9] varchar(255),
				[CA_ELEM_10] varchar(255),
				[CA_ELEM_11] varchar(255),
				[CA_ELEM_12] varchar(255),
				[Ship_Date] datetime,
				[All CA Lines OK] bit,
				[WinningCaConfigurationConfig] varchar(255),
				[WinningCaConfigurationConfig_RecordId] int,
				-- fields added because they're used by the stored procedure
				[SCS_String] varchar(255) null,
				[Rule_Key_CA] varchar(255) null,
				[CA Combination Validation] varchar(255) null,
				[Is CA Combination Valid] bit null,
				[Results Error Message] varchar(500) null,
				[Results Valid] bit default 1,
				[Exclude_From_Match] bit,
				[Exclude_From_Cost_Allocation] bit,
				[Exclusion_Message] varchar(255))

	insert into #CA_Lines_99
		 select *
		   from #CA_Lines

		update #CA_Lines_99
		   set WinningCaConfigurationConfig_RecordId = null,
			   WinningCaConfigurationConfig = 'Winning config not available because it would exceed 99 records'

	   truncate table #CA_Lines

	insert into #CA_Lines(
				[LinePct],
				[CA_Pcnt],
				[Line_Weight],
				[CA_ELEM_1],
				[CA_ELEM_2],
				[CA_ELEM_3],
				[CA_ELEM_4],
				[CA_ELEM_5],
				[CA_ELEM_6],
				[CA_ELEM_7],
				[CA_ELEM_8],
				[CA_ELEM_9],
				[CA_ELEM_10],
				[CA_ELEM_11],
				[CA_ELEM_12],
				[ShipmentDispatchEventDate],
				[All CA Lines OK],
				[WinningCaConfigurationConfig],
				[WinningCaConfigurationConfig_RecordId],
				[Exclude_From_Cost_Allocation],
				[Exclude_From_Match])
		 select null as [LinePct],
				null as [CA_Pcnt],
				sum([Line_Weight]) as [Line_Weight],
				[CA_ELEM_1],
				[CA_ELEM_2],
				[CA_ELEM_3],
				[CA_ELEM_4],
				[CA_ELEM_5],
				[CA_ELEM_6],
				[CA_ELEM_7],
				[CA_ELEM_8],
				[CA_ELEM_9],
				[CA_ELEM_10],
				[CA_ELEM_11],
				[CA_ELEM_12],
				min([Ship_Date]) as [Ship_Date],
				@allCAlinesOK as [All CA Lines OK],
				[WinningCaConfigurationConfig],
				[WinningCaConfigurationConfig_RecordId],
				[Exclude_From_Cost_Allocation],
				[Exclude_From_Match]
		   from #CA_Lines_99
		  where Exclude_From_Match = 0
			and Exclude_From_Cost_Allocation = 0
	   group by [CA_ELEM_1],
				[CA_ELEM_2],
				[CA_ELEM_3],
				[CA_ELEM_4],
				[CA_ELEM_5],
				[CA_ELEM_6],
				[CA_ELEM_7],
				[CA_ELEM_8],
				[CA_ELEM_9],
				[CA_ELEM_10],
				[CA_ELEM_11],
				[CA_ELEM_12],
				[WinningCaConfigurationConfig],
				[WinningCaConfigurationConfig_RecordId],
				[Exclude_From_Cost_Allocation],
				[Exclude_From_Match]
	   end

	   -- remove the brackets
	update #CA_Lines
	   set WinningCaConfigurationConfig = replace(replace(WinningCaConfigurationConfig,'[',''),']','')
*/

------------------------------------------------------------------------------------------------------------------
--	Calculate the line percentage
------------------------------------------------------------------------------------------------------------------
	declare @sumWeights float
	 select @sumWeights = sum([Line_Weight])
	   from #CA_Lines
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0

	 update #CA_Lines
		set LinePct = case when isnull(@sumWeights, 0) = 0 then 0 else isnull([Line_Weight], 0) / @sumWeights end

	 update #CA_Lines
		set CA_Pcnt = LinePct

------------------------------------------------------------------------------------------------------------------
--	Validate DMCQ,DHLA for HP LA -> Set lines as invalid
------------------------------------------------------------------------------------------------------------------
	-- if LA Freight Bill
 --    if @masterFbId like 'FBLL1000616%' or @masterFbId like 'FBLL1000617%'
 -- begin
 --        if ( @vendLabl in ('DMCQ','DHLA') )
 --     begin
 --            update #CA_Lines
 --               set [All CA Lines OK] = 0,
 --                   [Results Error Message] = 'SCAC ' + @vendLabl + ' is removed for LA.',
 --                   [Results Valid] = 0
 --       end
 --   end


------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_1 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_1_Override varchar(150)
	 select @CA_ELEM_1_Override = OwnCA.fn_CA_ELEM_1_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_1_Override is not null
		update #CA_Lines
		   set CA_Elem_1 = @CA_ELEM_1_Override
		   where CA_Elem_1 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_1_Override ' + isnull(@CA_ELEM_1_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_2 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_2_Override varchar(150)
	 select @CA_ELEM_2_Override = OwnCA.fn_CA_ELEM_2_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_2_Override is not null
		update #CA_Lines
		   set CA_Elem_2 = @CA_ELEM_2_Override
		   where CA_Elem_2 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_2_Override ' + isnull(@CA_ELEM_2_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_3 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_3_Override varchar(150)
	 select @CA_ELEM_3_Override = OwnCA.fn_CA_ELEM_3_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_3_Override is not null
		update #CA_Lines
		   set CA_Elem_3 = @CA_ELEM_3_Override
		   where CA_Elem_3 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_3_Override ' + isnull(@CA_ELEM_3_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_4 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_4_Override varchar(150)
	 select @CA_ELEM_4_Override = OwnCA.fn_CA_ELEM_4_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_4_Override is not null
		update #CA_Lines
		   set CA_Elem_4 = @CA_ELEM_4_Override
		   where CA_Elem_4 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_4_Override ' + isnull(@CA_ELEM_4_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_5 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_5_Override varchar(150)
	 select @CA_ELEM_5_Override = OwnCA.fn_CA_ELEM_5_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_5_Override is not null
		update #CA_Lines
		   set CA_Elem_5 = @CA_ELEM_5_Override
		   where CA_Elem_5 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_5_Override ' + isnull(@CA_ELEM_5_Override, 'null')
		end


------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_6 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_6_Override varchar(150)
	 select @CA_ELEM_6_Override = OwnCA.fn_CA_ELEM_6_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_6_Override is not null
		update #CA_Lines
		   set CA_Elem_6 = @CA_ELEM_6_Override
		   where CA_Elem_6 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_6_Override ' + isnull(@CA_ELEM_6_Override, 'null')
		end


------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_7 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_7_Override varchar(150)
	 select @CA_ELEM_7_Override = OwnCA.fn_CA_ELEM_7_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_7_Override is not null
		update #CA_Lines
		   set CA_Elem_7 = @CA_ELEM_7_Override
		   where CA_Elem_7 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_7_Override ' + isnull(@CA_ELEM_7_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_8 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_8_Override varchar(150)
	 select @CA_ELEM_8_Override = OwnCA.fn_CA_ELEM_8_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_8_Override is not null
		update #CA_Lines
		   set CA_Elem_8 = @CA_ELEM_8_Override
		   where CA_Elem_8 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_8_Override ' + isnull(@CA_ELEM_8_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_9 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_9_Override varchar(150)
	 select @CA_ELEM_9_Override = OwnCA.fn_CA_ELEM_9_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_9_Override is not null
		update #CA_Lines
		   set CA_Elem_9 = @CA_ELEM_9_Override
		   where CA_Elem_9 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_9_Override ' + isnull(@CA_ELEM_9_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_10 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_10_Override varchar(150)
	 select @CA_ELEM_10_Override = OwnCA.fn_CA_ELEM_10_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_10_Override is not null
		update #CA_Lines
		   set CA_Elem_10 = @CA_ELEM_10_Override
		   where CA_Elem_10 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_10_Override ' + isnull(@CA_ELEM_10_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_11 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_11_Override varchar(150)
	 select @CA_ELEM_11_Override = OwnCA.fn_CA_ELEM_11_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_11_Override is not null
		update #CA_Lines
		   set CA_Elem_11 = @CA_ELEM_11_Override
		   where CA_Elem_11 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_11_Override ' + isnull(@CA_ELEM_11_Override, 'null')
		end

------------------------------------------------------------------------------------------------------------------
--	Apply CA_ELEM_12 Override
------------------------------------------------------------------------------------------------------------------
	declare @CA_ELEM_12_Override varchar(150)
	 select @CA_ELEM_12_Override = OwnCA.fn_CA_ELEM_12_Override(@ownerKey, @vendLabl, @fbCurrencyQual, @taxRegKeyBlng, @alCntryCodeOrig, @alCntryCodeDest, @alCntryCodeBlng)

		if @CA_ELEM_12_Override is not null
		update #CA_Lines
		   set CA_Elem_12 = @CA_ELEM_12_Override
		   where CA_Elem_12 is not null

		 if @includeDebugInformation = 1
	  begin
			  print '@CA_ELEM_12_Override ' + isnull(@CA_ELEM_12_Override, 'null')
		end


------------------------------------------------------------------------------------------------------------------
--	Split the weight of the lines evenly where there's no wait in the ASN
------------------------------------------------------------------------------------------------------------------
   declare @totalCaPct float
	select @totalCaPct = sum(isnull(CA_Pcnt,0))
	  from #CA_Lines
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0

		if @totalCaPct = 0
	 begin
		 select @caLinesCount = count(1)
		   from #CA_Lines
		  where Exclude_From_Cost_Allocation = 0
			and Exclude_From_Match = 0

			 if @caLinesCount > 0
		  begin
				set @totalCaPct = 1

			 update #CA_Lines
				set LinePct = convert(float,@totalCaPct/convert(float,@caLinesCount)),
					CA_Pcnt = convert(float,@totalCaPct/convert(float,@caLinesCount))
			  where Exclude_From_Cost_Allocation = 0
				and Exclude_From_Match = 0
			end
		end

		 if @includeDebugInformation = 1
	  begin
			select 'post even ca line percentage' as [post even ca line percentage], * from #CA_Lines
		end

------------------------------------------------------------------------------------------------------------------
--	Remove lines if they have a CA_Pcnt = 0
------------------------------------------------------------------------------------------------------------------
	 update ca
		set ca.Exclusion_Message = isnull(ca.Exclusion_Message, 'Excluded Lines with CA_Pcnt = 0'),
			@exclusionMessage = isnull(@exclusionMessage, 'Excluded Lines with CA_Pcnt = 0')
	   from #CA_Lines ca
	  where ca.CA_Pcnt = 0
		and ca.Exclude_From_Cost_Allocation = 0
		and ca.Exclude_From_Match = 0

		 if @includeDebugInformation = 1
	  begin
			select 'lines with CA_Pcnt = 0 identified' as [lines with CA_Pcnt = 0 identified], * from #CA_Lines
		end

-- remove records that have an exclusion message
	 delete #CA_Lines where (Exclusion_Message is not null) and (Exclusion_Message not like '%configuration%')

--	Re-Calculate the line percentage
	 select @sumWeights = sum([Line_Weight])
	   from #CA_Lines
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0

	 update #CA_Lines
		set LinePct = case when isnull(@sumWeights,0) = 0 then 0 else isnull([Line_Weight], 0) / @sumWeights end
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0

	 update #CA_Lines
		set CA_Pcnt = LinePct
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0

	 update #CA_Lines
		set SCS_String = isnull(CA_Elem_1,'') + isnull(CA_Elem_3,'') + isnull(CA_Elem_6,'')+'00' + isnull(CA_Elem_7,'') +'00'

		 if @includeDebugInformation = 1
	  begin
			select 'Remove lines if they have a CA_Pcnt = 0' as [Remove lines if they have a CA_Pcnt = 0], * from #CA_Lines
		end

------------------------------------------------------------------------------------------------------------------
--	Split the weight of the lines evenly where there's no weight in the ASN
------------------------------------------------------------------------------------------------------------------
	 select @totalCaPct = sum(isnull(CA_Pcnt,0))
	   from #CA_Lines
	  where Exclude_From_Cost_Allocation = 0
		and Exclude_From_Match = 0

		 if @totalCaPct = 0
	  begin
			 select @caLinesCount = count(1)
			   from #CA_Lines
			  where Exclude_From_Cost_Allocation = 0
				and Exclude_From_Match = 0

				 if @caLinesCount > 0
			  begin
					set @totalCaPct = 1

				 update #CA_Lines
					set LinePct = convert(float,@totalCaPct/convert(float,@caLinesCount)),
						CA_Pcnt = convert(float,@totalCaPct/convert(float,@caLinesCount))
				  where Exclude_From_Cost_Allocation = 0
					and Exclude_From_Match = 0
				end
		end

		 if @includeDebugInformation = 1
	  begin
			select 'post even ca line percentage 2' as [post even ca line percentage 2], * from #CA_Lines
		end

------------------------------------------------------------------------------------------------------------------
--	Define table for final results
------------------------------------------------------------------------------------------------------------------
		if object_id('tempdb..#CA_RecordsValidationResults') is not null
	  drop table #CA_RecordsValidationResults

	 select *
	   into #CA_RecordsValidationResults
	   from #CA_Lines
	  where 1=0
	 create clustered index [#CA_RecordsValidationResults:SCS_String] on #CA_RecordsValidationResults(SCS_String)

------------------------------------------------------------------------------------------------------------------
--	Populate tax line
------------------------------------------------------------------------------------------------------------------
	declare @taxLinePercentage float = case when isnull(@fbAmt,0) = 0 then 0 else convert(float,@fbTaxAmt) / convert(float,@fbAmt) end
	declare @lineOffset smallint = 0

		 if @includeDebugInformation = 1
	  begin
			print '@taxLinePercentage: ' + isnull(convert(varchar,@taxLinePercentage),'<null>')
			print '@lineOffset: ' + isnull(convert(varchar,@lineOffset),'<null>')
			print '@ownerKey: ' + isnull(@ownerKey,'<null>')
			print '@fbAmt: ' + isnull(convert(varchar,@fbAmt),'<null>')
			print '@fbTaxAmt: ' + isnull(convert(varchar,@fbTaxAmt),'<null>')
			print '@fbShipDate: ' + isnull(convert(varchar,@fbShipDate),'<null>')
		end

		 if( @taxLinePercentage <> 0 and @ownerKey not in ('100-0671','100-0671_S4','100-0678','100-0678_S4') )
	  begin
				set @lineOffset = 1
		insert into #CA_RecordsValidationResults(
					[LinePct],
					[CA_Pcnt],
					[CA_Line_Num],
					[Line_Weight],
					[CA_ELEM_1],
					[CA_ELEM_2],
					[CA_ELEM_3],
					[CA_ELEM_4],
					[CA_ELEM_5],
					[CA_ELEM_6],
					[CA_ELEM_7],
					[CA_ELEM_8],
					[CA_ELEM_9],
					[CA_ELEM_10],
					[CA_ELEM_11],
					[CA_ELEM_12],
					[ShipmentDispatchEventDate],
					[All CA Lines OK],
					[WinningCaConfigurationConfig],
					[WinningCaConfigurationConfig_RecordId],
					[SCS_String],
					[Rule_Key_CA],
					[CA Combination Validation],
					[Is CA Combination Valid],
					[Results Error Message],
					[Results Valid],
					[Exclude_From_Cost_Allocation],
					[Exclude_From_Match],
					[Exclusion_Message])
			 select top 1
					@taxLinePercentage as LinePct,
					@taxLinePercentage as CA_Pcnt,
					1 as CA_Line_Num,
					[Line_Weight],
					CA_ELEM_1,
					CA_ELEM_2,
					CA_ELEM_3,
					CA_ELEM_4,
					CA_ELEM_5,
					CA_ELEM_6,
					CA_ELEM_7,
					CA_ELEM_8,
					CA_ELEM_9,
					CA_ELEM_10,
					'TAX' as CA_ELEM_11,
					CA_ELEM_12,
					ShipmentDispatchEventDate,
					[All CA Lines OK],
					WinningCaConfigurationConfig,
					WinningCaConfigurationConfig_RecordId,
					SCS_String,
					Rule_Key_CA,
					[CA Combination Validation],
					[Is CA Combination Valid],
					[Results Error Message],
					[Results Valid],
					[Exclude_From_Cost_Allocation],
					[Exclude_From_Match],
					[Exclusion_Message]
			   from #CA_Lines
			  where [Exclude_From_Cost_Allocation] = 0
				and [Exclude_From_Match] = 0
		   order by [CA_Pcnt] desc

		end
	   else
	  begin
			-- if tax line is not applicable then it should be set to 0
			set @taxLinePercentage = 0
		end

------------------------------------------------------------------------------------------------------------------
--	Convert final results into temp table for CA Combination validation and tax replacement logic
------------------------------------------------------------------------------------------------------------------
insert into #CA_RecordsValidationResults
	 select (1 - @taxLinePercentage) * LinePct as LinePct,
			(1 - @taxLinePercentage) * CA_Pcnt as CA_Pcnt,
			@lineOffset + row_number() over (order by CA_Pcnt desc) CA_Line_Num,
			[Line_Weight],
			CA_ELEM_1,
			CA_ELEM_2,
			CA_ELEM_3,
			CA_ELEM_4,
			CA_ELEM_5,
			CA_ELEM_6,
			CA_ELEM_7,
			CA_ELEM_8,
			CA_ELEM_9,
			CA_ELEM_10,
			CA_ELEM_11,
			CA_ELEM_12,
			ShipmentDispatchEventDate,
			[All CA Lines OK],
			WinningCaConfigurationConfig,
			WinningCaConfigurationConfig_RecordId,
			SCS_String,
			Rule_Key_CA,
			[CA Combination Validation],
			[Is CA Combination Valid],
			[Results Error Message],
			[Results Valid],
			[Exclude_From_Cost_Allocation],
			[Exclude_From_Match],
			[Exclusion_Message]
	   from #CA_Lines
	  where [Exclude_From_Cost_Allocation] = 0
		and [Exclude_From_Match] = 0
   order by CA_Pcnt desc

------------------------------------------------------------------------------------------------------------------
--	Validate Results were found in the CA Config Templates
------------------------------------------------------------------------------------------------------------------
		 if ( @returnInvalidResults = 0
			and exists(
				 select 1
				   from #CA_RecordsValidationResults
				  where WinningCaConfigurationConfig_RecordId is null
					and Exclude_From_Match = 0
					and Exclude_From_Cost_Allocation = 0) )
	  begin
-- treat results as invalid when a CA configuration was not found
		 delete #CA_RecordsValidationResults
			set @exclusionMessage = 'Not all lines found CA config records' -- PDV-11160 - Override all other exclusion
		end

------------------------------------------------------------------------------------------------------------------
--	Do CA Tax Replacement logic
------------------------------------------------------------------------------------------------------------------
	  exec OwnCa.usp_CA_TaxReplacementLogic @ownerKey

------------------------------------------------------------------------------------------------------------------
--	Do [CA Combination Validation] / Populate Company Code (CA_Elem_8)
------------------------------------------------------------------------------------------------------------------
		exec ownca.usp_CA_HPi_S4Validation

------------------------------------------------------------------------------------------------------------------
--	Do Validation on result set
------------------------------------------------------------------------------------------------------------------
	  exec OwnCa.usp_CA_GeneralValidation


------------------------------------------------------------------------------------------------------------------
--	Return the final results
------------------------------------------------------------------------------------------------------------------
		if (@returnCaLines = 1)
	 begin
			 if object_id('tempdb..#final_finalResults') is not null
		   drop table #final_finalResults

		 select @masterFbId as MasterFbId, *
		   into #final_finalResults
		   from #CA_RecordsValidationResults
		  where Exclude_From_Cost_Allocation = 0
			and Exclude_From_Match = 0
	   order by CA_Line_Num asc

		 select * from #final_finalResults order by CA_Line_num asc

		-- return exclusion message if there were no results
			 if not exists(select 1 from #final_finalResults)
		  begin
		  	-- return validation results because are expected by rules
			 select * from @inputValidationResult

			-- return exclusion message if there were no results
			 select @exclusionMessage as [Exclusion_Message]
			end

			 if @includeDebugInformation = 1
		  begin
			-- return exclusion message if there were no results
			 select @exclusionMessage as [Exclusion_Message]
			end
		end

------------------------------------------------------------------------------------------------------------------
--	Update matched desadv table
------------------------------------------------------------------------------------------------------------------
		if (@updateMatchMetrics = 1)
	 begin

-- delete any previous results to avoid mixed data
		 delete
		   from [dbo].[Matched_Document_FbIds]
		  where FbNId = dbo.fn_GetNumId(@masterFbId)

	insert into [dbo].[Matched_Document_FbIds](
				[FbNId],
				[Document_Id],
				[UpdateDtmUtc],
				[MatchingCorrelations],
				[WinningPrecedenceStep])
		 select FbNId,
					[Document_Id],
					getutcdate(),
					[MatchingCorrelations],
					[WinningPrecedenceStep]
			   from (
 				 select dbo.fn_GetNumId(@masterFbId) as [FbNId],
						[Document_Id],
						[Document Correlations] as [MatchingCorrelations],
						[Match Concept] as [WinningPrecedenceStep],
						--rank() over (partition by [Document_Id] order by Ship_Date desc, [Document Correlations] desc, UniqueRecordId asc) as [Ranked_Match_Metrics] -- original
					rank() over (
						partition by [Document_Id] order by
						CASE
						    WHEN [Document Correlations] like '%TMS_Trailer_Number%' then 1
							WHEN [Document Correlations] like '%ParcelTrackingNumber%' then 3
							WHEN [Document Correlations] like '%BOL_Number%' then 5
							WHEN [Document Correlations] like '%Tracking_Number%' then 7
							WHEN [Document Correlations] like '%Container_Number%' then 9
							WHEN [Document Correlations] like '%Shipment_Id%' then 11
							WHEN [Document Correlations] like '%SAP_Delivery_Number%' then 13
							ELSE 15 end asc -- others???
						, Ship_Date desc
						, UniqueRecordId asc
					) as [Ranked_Match_Metrics]
				   from #documentInfo
				  where Exclude_From_Match = 0
					) x
			  where x.Ranked_Match_Metrics = 1
			end


-- persist the matched results -- moving this out from the if (@updateMatchMetrics = 1) so that we can see the result on debug mode - MANC-544
			if @includeDebugInformation = 1
		begin
			select 'Pre Matched_Document_FbIds - #documentInfo where Exclude_From_Match = 0 ', [Document_Id],[Document Correlations], Ship_Date, UniqueRecordId, * from #documentInfo where Exclude_From_Match = 0

			select 'Matched_Document_FbIds' as [Matched_Document_FbIds],
			 	FbNId,
				[Document_Id],
				getutcdate(),
				[MatchingCorrelations],
				[WinningPrecedenceStep],
				x.Ranked_Match_Metrics
		   from (
			 select dbo.fn_GetNumId(@masterFbId) as [FbNId],
					[Document_Id],
					[Document Correlations] as [MatchingCorrelations],
					[Match Concept] as [WinningPrecedenceStep],
					rank() over (
						partition by [Document_Id] order by
						CASE
						    WHEN [Document Correlations] like '%TMS_Trailer_Number%' then 1
							WHEN [Document Correlations] like '%ParcelTrackingNumber%' then 3
							WHEN [Document Correlations] like '%BOL_Number%' then 5
							WHEN [Document Correlations] like '%Tracking_Number%' then 7
							WHEN [Document Correlations] like '%Container_Number%' then 9
							WHEN [Document Correlations] like '%Shipment_Id%' then 11
							WHEN [Document Correlations] like '%SAP_Delivery_Number%' then 13
							ELSE 15 end asc -- others???
						, [Document Correlations] asc
						, Ship_Date desc
						, UniqueRecordId asc
					) as [Ranked_Match_Metrics]
			   from #documentInfo
			  where Exclude_From_Match = 0
				) x
		  where x.Ranked_Match_Metrics = 1



		end

end





