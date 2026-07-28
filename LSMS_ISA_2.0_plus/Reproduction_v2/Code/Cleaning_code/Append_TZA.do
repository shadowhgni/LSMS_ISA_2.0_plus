/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Append all Tanzania code						                  *
 * Date: January 2024                                                             *
 * -------------------------------------------------------------------------------*
*/
clear 

global paths "TZA\NPS08 TZA\NPS10 TZA\NPS12 TZA\NPS14 TZA\NPS14 TZA\NPS19 TZA\NPS19"

global hhids "hhid y2_hhid y3_hhid y4_hhid y4_hhid sdd_hhid y5_hhid"

global cropid "zaocode zaocode zaocode zaocode zaocode cropid cropid"


**********************************************************
**** A) Harmonize IDs
**********************************************************

// HOUSEHOLD IDs


use "${Input}\Tanzania\NPS 08\SEC_B_C_D_E1_F_G1_U.dta", clear 

keep hhid sbmemno sbq5
tempfile wave1_indiv
save `wave1_indiv', replace

keep if sbq5==1 // keep heads

keep hhid sbmemno
tempfile wave1_heads
save `wave1_heads', replace


// wave 2
use "${Input}\Tanzania\NPS 10\HH_SEC_B.dta", clear 

bys  hhid_2008 (y2_hhid): gen tag = y2_hhid!=y2_hhid[_n-1] & _n!=1
bys hhid_2008 : egen tag_hh = total(tag)
tab tag_hh

rename hhid_2008 hhid

gen sbmemno = hh_b06
replace sbmemno = indidy2 + 100 if hh_b06==99 | hh_b06==. 

merge m:1 sbmemno hhid using `wave1_heads', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_head)

bys y2_hhid: egen parent = max(tracked_head)

gen id_2 = hhid if  tag_hh==0
replace id_2 = hhid if parent==1 & tag_hh>0
replace id_2 = y2_hhid if parent==0 & tag_hh>0
mdesc id_2 // no missing

bys  id_2 (y2_hhid): gen tag_check1 = y2_hhid!=y2_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check1_hh = total(tag_check1)
tab tag_check1_hh // all 0, stop here

gen hh_id_merge = y2_hhid

isid id_2 indidy2
preserve
keep hh_id_merge id_2 y2_hhid
gen wave = 2
duplicates drop
tempfile Ids_wave2
save `Ids_wave2', replace
restore

//wave 3

use "${Input}\Tanzania\NPS 10\HH_SEC_B.dta", clear 

keep  y2_hhid indidy2 hh_b05
tempfile wave2_indiv
save `wave2_indiv', replace

keep if hh_b05==1 // keep heads

keep y2_hhid indidy2
tempfile wave2_heads
save `wave2_heads', replace

use "${Input}\Tanzania\NPS 12\HH_SEC_B.dta", clear 

bys y3_hhid (y2_hhid): replace y2_hhid = y2_hhid[_N] 
mdesc y2_hhid // still a few missing - cannot trace to a previous household

bys  y2_hhid (y3_hhid): gen tag = y3_hhid!=y3_hhid[_n-1] & _n!=1
bys y2_hhid : egen tag_hh = total(tag)
tab tag_hh

rename (hh_b06) ( indidy2) 

merge m:1  y2_hhid using `Ids_wave2', keep(master match) 
rename _merge _merge_prev_wave

merge m:1 indidy2 y2_hhid using `wave2_heads', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_head)

bys y3_hhid: egen parent = max(tracked_head)

replace id_2 = y3_hhid if  _merge_prev_wave==1 // new hh not linked to prev wave
replace id_2 = y3_hhid if parent==0 & tag_hh>0 // non parent split offs
mdesc id_2 // no missing

bys  id_2 (y3_hhid): gen tag_check1 = y3_hhid!=y3_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check1_hh = total(tag_check1)
tab tag_check1_hh // still some duplicates 
replace parent = 0 if tag_check1_hh>0

drop _merge
merge m:1 indidy2 y2_hhid using `wave2_indiv', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_indiv)
bys y3_hhid: egen nb_tracked = total(tracked_indiv)

bys y2_hhid: egen max_nb_tracked = max(nb_tracked)
replace parent = 1 if tag_check1_hh>0 & max_nb_tracked==nb_tracked

replace id_2 = y3_hhid if parent==0 & tag_check1_hh>0 // non parent split offs
mdesc id_2 // no missing


bys  id_2 (y3_hhid): gen tag_check2 = y3_hhid!=y3_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check2_hh = total(tag_check2)
tab tag_check2_hh // no more 

replace id_2 = y3_hhid if tag_check2_hh>0 // if any remaining duplicates

replace hh_id_merge = y3_hhid

isid id_2 indidy3
preserve
keep hh_id_merge id_2 y3_hhid
gen wave = 3
duplicates drop
tempfile Ids_wave3
save `Ids_wave3', replace
restore


//wave 4

use "${Input}\Tanzania\NPS 12\HH_SEC_B.dta", clear 

keep  y3_hhid indidy3 hh_b05
tempfile wave3_indiv
save `wave3_indiv', replace

keep if hh_b05==1 // keep heads

keep y3_hhid indidy3
tempfile wave3_heads
save `wave3_heads', replace

use "${Input}\Tanzania\NPS 14 - extended\HH_SEC_A.dta", clear 
rename hh_a09 y3_hhid
keep y3_hhid y4_hhid
merge 1:m y4_hhid using "${Input}\Tanzania\NPS 14 - extended\HH_SEC_B.dta", nogen 

mdesc y3_hhid // no missing

bys  y3_hhid (y4_hhid): gen tag = y4_hhid!=y4_hhid[_n-1] & _n!=1
bys y3_hhid : egen tag_hh = total(tag)
tab tag_hh

rename (hh_b06) ( indidy3) 

merge m:1  y3_hhid using `Ids_wave3', keep(master match) 
rename _merge _merge_prev_wave

merge m:1 indidy3 y3_hhid using `wave3_heads', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_head)

bys y4_hhid: egen parent = max(tracked_head)

replace id_2 = y4_hhid if  _merge_prev_wave==1 // new hh not linked to prev wave
replace id_2 = y4_hhid if parent==0 & tag_hh>0 // non parent split offs
mdesc id_2 // no missing

bys  id_2 (y4_hhid): gen tag_check1 = y4_hhid!=y4_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check1_hh = total(tag_check1)
tab tag_check1_hh // still some duplicates 
replace parent = 0 if tag_check1_hh>0

drop _merge
merge m:1 indidy3 y3_hhid using `wave3_indiv', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_indiv)
bys y4_hhid: egen nb_tracked = total(tracked_indiv)

bys y3_hhid: egen max_nb_tracked = max(nb_tracked)
replace parent = 1 if tag_check1_hh>0 & max_nb_tracked==nb_tracked

replace id_2 = y4_hhid if parent==0 & tag_check1_hh>0 // non parent split offs
mdesc id_2 // no missing

bys  id_2 (y4_hhid): gen tag_check2 = y4_hhid!=y4_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check2_hh = total(tag_check2)
tab tag_check2_hh // still some duplicates 

replace id_2 = y4_hhid if tag_check2_hh>0

replace hh_id_merge = y4_hhid

isid id_2 indidy4
preserve
keep hh_id_merge id_2 y4_hhid
gen wave = 4
duplicates drop
tempfile Ids_wave4
save `Ids_wave4', replace
restore


//wave 6

use "${Input}\Tanzania\NPS 14 - extended\HH_SEC_B.dta", clear 

keep  y4_hhid indidy4 hh_b05
tempfile wave4_indiv
save `wave4_indiv', replace

keep if hh_b05==1 // keep heads

keep y4_hhid indidy4
tempfile wave4_heads
save `wave4_heads', replace

use "${Input}\Tanzania\NPS 19 - extended\HH_SEC_B.dta", clear 

mdesc y4_hhid // no missing

capture assertnested y4_hhid sdd_hhid // some households merged
bys  sdd_hhid (y4_hhid): gen tag_merge = y4_hhid!=y4_hhid[_n-1] & _n!=1
bys sdd_hhid : egen tag_hh_merge = total(tag_merge)
tab tag_hh_merge
replace sdd_hhid = y4_hhid if tag_hh_merge>0 // keep them separate

bys  y4_hhid (sdd_hhid): gen tag = sdd_hhid!=sdd_hhid[_n-1] & _n!=1
bys y4_hhid : egen tag_hh = total(tag)
tab tag_hh

rename (hh_b06) ( indidy4) 

merge m:1  y4_hhid using `Ids_wave4', keep(master match) 
rename _merge _merge_prev_wave

merge m:1 indidy4 y4_hhid using `wave4_heads', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_head)

bys sdd_hhid: egen parent = max(tracked_head)

replace id_2 = sdd_hhid  if  _merge_prev_wave==1 // new hh not linked to prev wave
replace id_2 = sdd_hhid  if parent==0 & tag_hh>0 // non parent split offs
mdesc id_2 // no missing

bys  id_2 (sdd_hhid): gen tag_check1 = sdd_hhid!=sdd_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check1_hh = total(tag_check1)
tab tag_check1_hh // still some duplicates 
replace parent = 0 if tag_check1_hh>0

drop _merge
merge m:1 indidy4 y4_hhid using `wave4_indiv', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_indiv)
bys sdd_hhid: egen nb_tracked = total(tracked_indiv)

bys y4_hhid: egen max_nb_tracked = max(nb_tracked)
replace parent = 1 if tag_check1_hh>0 & max_nb_tracked==nb_tracked

replace id_2 = sdd_hhid if parent==0 & tag_check1_hh>0 // non parent split offs
mdesc id_2 // no missing

bys  id_2 (sdd_hhid): gen tag_check2 = sdd_hhid!=sdd_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check2_hh = total(tag_check2)
tab tag_check2_hh  

duplicates report sdd_hhid 
replace id_2 = sdd_hhid if tag_check2_hh>0

replace hh_id_merge = sdd_hhid

isid id_2 sdd_indid
preserve
keep hh_id_merge id_2 sdd_hhid
gen wave = 6
duplicates drop
tempfile Ids_wave6
save `Ids_wave6', replace
restore

// wave 7

use "${Input}\Tanzania\NPS 14 - refresh\HH_SEC_B.dta", clear 

keep y4_hhid indidy4 hh_b05
tempfile wave5_indiv
save `wave5_indiv', replace

keep if hh_b05==1 // keep heads

keep y4_hhid indidy4
tempfile wave5_heads
save `wave5_heads', replace

use "${Input}\Tanzania\NPS 19 - refresh\HH_SEC_B.dta", clear 


bys y5_hhid (y4_hhid): replace y4_hhid = y4_hhid[_N] 
mdesc y4_hhid // still a few missing - cannot trace to a previous household

bys  y4_hhid (y5_hhid): gen tag = y5_hhid!=y5_hhid[_n-1] & _n!=1
bys y4_hhid : egen tag_hh = total(tag)
tab tag_hh

rename hh_b06 indidy4

merge m:1 indidy4 y4_hhid using `wave5_heads', keep(master match)

recode _merge (1 = 0) (3 = 1), gen(tracked_head)

bys y5_hhid: egen parent = max(tracked_head)

gen id_2 = y4_hhid if  tag_hh==0
replace id_2 = y4_hhid if parent==1 & tag_hh>0
replace id_2 = y5_hhid if parent==0 & tag_hh>0
mdesc id_2 // no missing

bys  id_2 (y5_hhid): gen tag_check1 = y5_hhid!=y5_hhid[_n-1] & _n!=1
bys id_2 : egen tag_check1_hh = total(tag_check1)
tab tag_check1_hh // all 0, stop here

gen hh_id_merge = y5_hhid

isid id_2 indidy5
preserve
keep hh_id_merge id_2 y5_hhid
gen wave = 7
duplicates drop
tempfile Ids_wave7
save `Ids_wave7', replace
restore




use "${Temp}\\TZA\NPS08\\hh_frame.dta", clear
gen wave = 1 
gen hh_id_merge = hhid
gen hh_id_obs = hhid
append using "${Temp}\\TZA\NPS10\\hh_frame.dta"
replace wave = 2 if wave==.
replace hh_id_merge = y2_hhid if wave==2
append using "${Temp}\\TZA\NPS12\\hh_frame.dta"
replace wave = 3 if wave==.
replace hh_id_merge = y3_hhid if wave==3
append using "${Temp}\\TZA\NPS14\\hh_frame_extended.dta"
replace wave = 4 if wave==.
replace hh_id_merge = y4_hhid if wave==4
drop y4_hhid
append using "${Temp}\\TZA\NPS14\\hh_frame_refresh.dta"
replace wave = 5 if wave==.
replace hh_id_merge = y4_hhid if wave==5
append using "${Temp}\\TZA\NPS19\\hh_frame_extended.dta"
replace wave = 6 if wave==.
replace hh_id_merge = sdd_hhid if wave==6
append using "${Temp}\\TZA\NPS19\\hh_frame_refresh.dta"
replace wave = 7 if wave==.
replace hh_id_merge = y5_hhid if wave==7

merge m:1 hh_id_merge wave using `Ids_wave2', keep(master match) 
replace hh_id_obs = id_2 if wave==2 & _merge==3 
replace hh_id_obs = hh_id_merge if wave==2 & _merge==1
mdesc hh_id_obs if wave==2
rename (_merge id_2) (_merge_w2 hhid_2_w2) 

merge m:1 hh_id_merge wave using `Ids_wave3', keep(master match ) 
replace hh_id_obs = id_2 if wave==3 & _merge==3
replace hh_id_obs = hh_id_merge if wave==3 & _merge==1
mdesc hh_id_obs if wave==3
rename (_merge id_2) (_merge_w3 hhid_2_w3) 

merge m:1 hh_id_merge wave using `Ids_wave4', keep(master match ) 
replace hh_id_obs = id_2 if wave==4 & _merge==3
replace hh_id_obs = hh_id_merge if wave==4 & _merge==1
mdesc hh_id_obs if wave==4
rename (_merge id_2) (_merge_w4 hhid_2_w4) 

replace hh_id_obs = y4_hhid if wave==5

merge m:1 hh_id_merge wave using `Ids_wave6', keep(master match ) 
replace hh_id_obs = id_2 if wave==6 & _merge==3
replace hh_id_obs = hh_id_merge if wave==6 & _merge==1
mdesc hh_id_obs if wave==6
rename (_merge id_2) (_merge_w6 hhid_2_w6) 
	
	// some IDs are equivalent across refresh and extended panels
	duplicates tag hh_id_obs  if wave==4| wave==5, gen(t) // 3 households
	replace hh_id_obs = hh_id_merge if t==1
	

merge m:1 hh_id_merge wave using `Ids_wave7', keep(master match ) 
replace hh_id_obs = id_2 if wave==7 & _merge==3
replace hh_id_obs = hh_id_merge if wave==7 & _merge==1
mdesc hh_id_obs if wave==7
rename (_merge id_2) (_merge_w7 hhid_2_w7) 

	duplicates tag hh_id_obs  if wave==6| wave==7, gen(t2)
	replace hh_id_obs = hh_id_merge if t2==1

rename hh_id_obs hh_id_obs_temp
egen hh_id_obs = group(hh_id_obs_temp)
replace hh_id_obs = hh_id_obs + 6000000 

keep hh_id_obs hh_id_merge wave
duplicates drop
save "${Temp}\\TZA\\Frame_hhIDs.dta", replace


// INDIV IDs
	// WAVE 2
use "${Input}\Tanzania\NPS 10\HH_SEC_B.dta", clear 
gen hh_id = y2_hhid 

gen id_2 = hh_b06 
replace id_2 = indidy2 + 100 if hh_b06==99 | hh_b06==. 

gen wave=2
keep hh_id wave id_2 y2_hhid indidy2
egen indiv_id_merge = concat (hh_id indidy2), punct("-")
tempfile Indiv_Ids_wave2
save `Indiv_Ids_wave2', replace

	// WAVE 3 
use "${Input}\Tanzania\NPS 12\HH_SEC_B.dta", clear 
gen hh_id = y3_hhid

rename (hh_b06) ( indidy2) 
merge m:1 y2_hhid indidy2 using `Indiv_Ids_wave2', keepusing(id_2) keep(master match) // we keep match AND MASTER because the variable plot_2 doesn't exist in the final dataset. New plots would therefore be left out if we only kept match

replace id_2 = indidy3 + 200 if _merge==1 // this includes the pots coded as "99"
gen wave=3
keep hh_id wave id_2 y3_hhid indidy3
egen indiv_id_merge = concat (hh_id indidy3), punct("-")

	// a few duplicates - given new numebrs
	duplicates tag y3_hhid id_2, gen(T)
	replace id_2 = 3000 + indidy3 if T>0 

tempfile Indiv_Ids_wave3
save `Indiv_Ids_wave3', replace

	// WAVE 4 
use "${Input}\Tanzania\NPS 14 - extended\HH_SEC_B.dta", clear
merge m:1 y4_hhid using "${Input}\Tanzania\NPS 14 - extended\hh_sec_a.dta", keep(match) nogen
gen hh_id = y4_hhid

rename (hh_b06 hh_a09) ( indidy3 y3_hhid)  
merge m:1 y3_hhid indidy3 using `Indiv_Ids_wave3', keepusing(id_2) keep(master match)

replace id_2 = indidy4 + 400 if _merge==1
gen wave=4
keep id_2 wave hh_id y4_hhid indidy4 
egen indiv_id_merge = concat (hh_id indidy4), punct("-")

	// a few duplicates - given new numebrs
	duplicates tag y4_hhid id_2, gen(T)
	replace id_2 = 4000 + indidy4 if T>0 
	
tempfile Indiv_Ids_wave4
save `Indiv_Ids_wave4', replace

	// WAVE 5 
use "${Input}\Tanzania\NPS 19 - extended\HH_SEC_B.dta", clear
gen hh_id = sdd_hhid

rename (hh_b06) ( indidy4)  
merge m:1 y4_hhid indidy4 using `Indiv_Ids_wave4', keepusing(id_2) keep(master match)

replace id_2 = sdd_indid + 500 if _merge==1 
gen wave=6
keep id_2 wave hh_id  sdd_indid
egen indiv_id_merge = concat (hh_id sdd_indid), punct("-")

	// a few duplicates - given new numebrs
	duplicates tag hh_id id_2, gen(T)
	replace id_2 = 5000 + sdd_indid if T>0 
	
tempfile Indiv_Ids_wave6
save `Indiv_Ids_wave6', replace

// WAVE 7
use "${Input}\Tanzania\NPS 19 - refresh\HH_SEC_B.dta", clear
gen hh_id = y5_hhid

rename (hh_b06) ( indidy4)  
merge m:1 y4_hhid indidy4 using "${Input}\Tanzania\NPS 14 - refresh\HH_SEC_B.dta",  keep(master match)

gen id_2 = indidy4 if _merge==3
replace id_2 = indidy5 + 600 if _merge==1
gen wave=7
keep id_2 wave hh_id  indidy5
egen indiv_id_merge = concat (hh_id indidy5), punct("-")

	// a few duplicates - given new numebrs
	duplicates tag hh_id id_2, gen(T)
	replace id_2 = 7000 + indidy5 if T>0 
	
tempfile Indiv_Ids_wave7
save `Indiv_Ids_wave7', replace


use "${Temp}\\TZA\NPS08\\indiv_frame.dta", clear
gen wave = 1 
gen hh_id_merge = hhid
gen indiv_id_obs = ID
gen indiv_id_merge = ID
drop ID
append using "${Temp}\\TZA\NPS10\\indiv_frame.dta"
replace wave = 2 if wave==.
replace hh_id_merge = y2_hhid  if wave==2
replace indiv_id_obs = ID if wave==2
replace indiv_id_merge = ID if wave==2
drop ID
append using "${Temp}\\TZA\NPS12\\indiv_frame.dta"
replace wave = 3 if wave==.
replace hh_id_merge = y3_hhid if wave==3
replace indiv_id_obs = ID if wave==3
replace indiv_id_merge = ID if wave==3
drop ID
append using "${Temp}\\TZA\NPS14\\indiv_frame_extended.dta"
replace wave = 4 if wave==.
replace hh_id_merge = y4_hhid if wave==4
replace indiv_id_obs = ID if wave==4
replace indiv_id_merge = ID if wave==4
drop ID y4_hhid
append using "${Temp}\\TZA\NPS14\\indiv_frame_refresh.dta"
replace wave = 5 if wave==.
replace hh_id_merge = y4_hhid if wave==5
replace indiv_id_obs = ID if wave==5
replace indiv_id_merge = ID if wave==5
drop ID y4_hhid
append using "${Temp}\\TZA\NPS19\\indiv_frame_extended.dta"
replace wave = 6 if wave==.
replace hh_id_merge = sdd_hhid if wave==6
replace indiv_id_obs = ID if wave==6
replace indiv_id_merge = ID if wave==6
drop ID 
append using "${Temp}\\TZA\NPS19\\indiv_frame_refresh.dta"
replace wave = 7 if wave==.
replace hh_id_merge = y5_hhid if wave==7
replace indiv_id_obs = ID if wave==7
replace indiv_id_merge = ID if wave==7
drop ID 

merge m:1 hh_id_merge wave using "${Temp}\\TZA\\Frame_hhIDs.dta", keep(master match) nogen
tostring hh_id_obs, gen(hh_id_obs_str)

replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==1  


merge m:1 indiv_id_merge wave using `Indiv_Ids_wave2', keep(master match)
tostring id_2, replace
gen X = substr(indiv_id_obs, strrpos(indiv_id_obs, "-")+1, .)
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(X), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==2 & _merge==3 
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strrpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 )  if indiv_id_obs!="" & wave==2 & _merge==3 
tab _merge if wave==2
rename (_merge id_2) (_merge_w2 id_2_w2) 

merge m:1 indiv_id_merge wave using `Indiv_Ids_wave3', keep(master match ) 
tostring id_2, replace
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs),  strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==3 & _merge==3 
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strrpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 )  if indiv_id_obs!="" & wave==3 & _merge==3 
tab _merge if wave==3
rename (_merge id_2) (_merge_w3 id_2_w3) 

merge m:1 indiv_id_merge wave using `Indiv_Ids_wave4', keep(master match ) 
tostring id_2, replace
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==4 & _merge==3 
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strrpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 )  if indiv_id_obs!="" & wave==4 & _merge==3 
tab _merge if wave==4
rename (_merge id_2) (_merge_w4 id_2_w4) 

merge m:1 indiv_id_merge wave using `Indiv_Ids_wave6', keep(master match ) 
tostring id_2, replace
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==6 & _merge==3 
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strrpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 )  if indiv_id_obs!="" & wave==6 & _merge==3 
tab _merge if wave==6
rename (_merge id_2) (_merge_w6 id_2_w6) 
	
merge m:1 indiv_id_merge wave using `Indiv_Ids_wave7', keep(master match ) 
tostring id_2, replace
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==7 & _merge==3 
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strrpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 )  if indiv_id_obs!="" & wave==7 & _merge==3 
tab _merge if wave==7
rename (_merge id_2) (_merge_w7 id_2_w7) 
	
	
keep indiv_id_obs indiv_id_merge  wave hh_id_merge
duplicates drop

rename indiv_id_obs indiv_id_obs_temp
egen indiv_id_obs = group(indiv_id_obs_temp)
replace indiv_id_obs = indiv_id_obs + 6000000 

save "${Temp}\\TZA\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
forvalues wave = 1/5 { // none in 2019
if `wave'==4 |  `wave'==6 {
global suffix _extended
}
if `wave' == 5|  `wave'==7 {
global suffix _refresh	
}
if `wave' <4 {
global suffix 	
}
global hhd: word `wave' of $hhids
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\respondent_characteristics1${suffix}.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep $hhd  respondent_id_obs respondent_id_merge 
save "${Temp}\\${temppath}\\respondent_characteristics1_ID${suffix}.dta", replace
restore
}
rename respondent_id manager_id
forvalues wave = 1/7 {
if `wave'==4 |  `wave'==6 {
global suffix _extended
}
if `wave' == 5|  `wave'==7 {
global suffix _refresh	
}
if `wave' <4 {
global suffix 	
}
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  manager_id using "${Temp}\\${temppath}\\Manager_characteristics1${suffix}.dta", keep(match)
rename manager_id manager_id_merge
gen manager_id_obs = indiv_id_obs
keep plot_id  manager_id_obs manager_id_merge 
save "${Temp}\\${temppath}\\Manager_characteristics1_ID${suffix}.dta", replace
restore
}


use "${Temp}\\TZA\\NPS08\\plot_crop_frame.dta", clear
gen wave = 1
append using "${Temp}\\TZA\\NPS10\\plot_crop_frame.dta", gen(append)
replace wave = 2 if append==1
drop append
append using "${Temp}\\TZA\\NPS12\\plot_crop_frame.dta", gen(append)
replace wave = 3 if append==1
drop append
append using "${Temp}\\TZA\\NPS14\\plot_crop_frame_extended.dta", gen(append)
replace wave = 4 if append==1
drop append
append using "${Temp}\\TZA\\NPS14\\plot_crop_frame_refresh.dta", gen(append)
replace wave = 5 if append==1
drop append
append using "${Temp}\\TZA\\NPS19\\plot_crop_frame_extended.dta", gen(append)
replace wave = 6 if append==1
drop append
append using "${Temp}\\TZA\\NPS19\\plot_crop_frame_refresh.dta", gen(append)
replace wave = 7 if append==1
drop append

	// cannot track plots
	egen plot_id_temp = concat(wave plot_id ), punct("-")
	egen plot_id_obs = group(plot_id_temp)
	replace plot_id_obs = plot_id_obs + 6000000 
	gen plot_id_merge=  plot_id 

keep plot_id plot_id_obs plot_id_merge  zaocode cropid crop_name wave
duplicates drop
save "${Temp}\\TZA\\Frame_plotcrop.dta", replace

use "${Temp}\\TZA\\NPS08\\Coords.dta", clear
append using "${Temp}\\TZA\\NPS10\\Coords.dta"
append using "${Temp}\\TZA\\NPS12\\Coords.dta"
append using "${Temp}\\TZA\\NPS14\\Coords_extended.dta"
append using "${Temp}\\TZA\\NPS14\\Coords_refresh.dta"
append using "${Temp}\\TZA\\NPS19\\Coords_extended.dta"
keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 6000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\TZA\\geocoords_id.dta", replace


use "${Temp}\\TZA\NPS08\\ea_id.dta", clear
gen hh_id_merge = hhid
gen wave =1
append using "${Temp}\\TZA\NPS10\\ea_id.dta", 
replace hh_id_merge = y2_hhid if hh_id_merge==""
replace  wave =2 if wave==.
append using "${Temp}\\TZA\NPS12\\ea_id.dta", 
replace hh_id_merge = y3_hhid if hh_id_merge==""
replace  wave =3 if wave==.
append using "${Temp}\\TZA\NPS14\\ea_id_extended.dta", 
replace hh_id_merge = y4_hhid if hh_id_merge==""
replace  wave =4 if wave==.
append using "${Temp}\\TZA\NPS14\\ea_id_refresh.dta", 
replace hh_id_merge = y4_hhid if hh_id_merge==""
replace  wave =5 if wave==.
append using "${Temp}\\TZA\NPS19\\ea_id_extended.dta", 
replace hh_id_merge = sdd_hhid if hh_id_merge==""
replace  wave =6 if wave==.
append using "${Temp}\\TZA\NPS19\\ea_id_refresh.dta", 
replace hh_id_merge = y5_hhid if hh_id_merge==""
replace  wave =7 if wave==.
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 6000000
bys hh_id_obs (ea_id_obs) : replace ea_id_obs = ea_id_obs[1] //  30 errors
rename ea_id ea_id_merge

keep hh_id_merge ea_id_obs  ea_id_merge wave
duplicates drop
isid hh_id_merge wave
save "${Temp}\\TZA\\ea_id_obs.dta", replace



	
**********************************************************
**** B) Create plot-crop datasets
**********************************************************

forvalues wave = 1/7 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hhids
global cropvar: word `wave' of $cropid

if `wave'==4 | `wave' ==6  {
global suffix _extended
}
if `wave' == 5 | `wave' ==7 {
global suffix _refresh	
}
if `wave' <4  {
global suffix 	
}

use "${Temp}\\${temppath}\\plot_crop_frame${suffix}.dta", clear
duplicates drop
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban${suffix}.dta", keep(master match) nogen
if `wave'<7 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\Coords${suffix}.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\TZA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\harvest_kg${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\harvest_value${suffix}.dta", keep(master match) nogen
drop main_crop // added later
	
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\harvest_end_month${suffix}.dta", keep(master match) nogen
//merge 1:1 plot_id zaocode using "${Temp}\\${temppath}\\planting_month${suffix}.dta", keep(master match) nogen
if `wave'>2 {
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\seed_kg_merge${suffix}.dta", keep(master match) nogen
}
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\seed_value${suffix}.dta" , keep(master match) nogen
if `wave'>2 {
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\improved${suffix}.dta" , keep(master match) nogen
}
merge m:1 plot_id  using "${Temp}\\${temppath}\\used_pesticides${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id $cropvar using "${Temp}\\${temppath}\\crop_shock${suffix}.dta", keep(master match) nogen

gen wave = `wave'




define_labels

 
// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\Frame_hhIDs.dta", keep(master match) nogen
merge 1:m plot_id $cropvar wave using "${Temp}\\TZA\\Frame_plotcrop.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\ea_id_obs.dta", keep(master match) nogen
drop if $cropvar == .
preserve
foreach var in  harvest_sold_kg   {
capture drop `var'
}  
save "${Final}\\TZA_FINAL_plotcrop`wave'.dta", replace
restore



**********************************************************
**** C) Create plot datasets
**********************************************************
if `wave'>2 {
global temp1 seed_kg
global temp2 improved
global n_temp1   n_seed_kg=seed_kg
}
else {
global temp1 
global temp2 
global n_temp1
}	
if `wave'!=2 {
global admin_1_name admin_1_name
}
else {
global admin_1_name 	
}
if `wave'>2 {
global admin_2_name admin_2_name
}
else {
global admin_2_name 	
}


collapse (sum) harvest_kg harvest_value    $temp1  seed_value (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value $n_temp1  n_seed_value =seed_value (max) $temp2 used_pesticides *_shock , by(plot_id ea_id_obs ea_id_merge pw strataid admin_1 $admin_1_name $admin_2_name admin_2  admin_3   wave plot_id_obs plot_id_merge hh_id_obs hh_id_merge)

foreach var in  harvest_kg harvest_value $temp1 seed_value {
	replace `var' = . if n_`var'==0
}


global hhd: word `wave' of $hhids

merge 1:1 plot_id  using "${Temp}\\${temppath}\\intercropped${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\nb_seasonal_crop${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\main_crop${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_area${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\labor_days${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\inorganic_fertilizer${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\nitrogen_kg${suffix}.dta", keep(master match) nogen keepusing(nitrogen_kg)
merge 1:1 plot_id  using "${Temp}\\${temppath}\\inorganic_fertilizer_value${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\organic_fertilizer${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics1${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics1_ID${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics2${suffix}.dta", keep(master match) nogen
if `wave'<6 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\respondent_characteristics1${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\respondent_characteristics1_ID${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Resp_characteristics2${suffix}.dta", keep(master match) nogen	
}
merge 1:1 plot_id  using "${Temp}\\${temppath}\\irrigated${suffix}.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\erosion_protection${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\tractor${suffix}.dta", keep(master match) nogen
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned${suffix}.dta", keep(master match) nogen	
merge m:1 $hhd  using "${Temp}\\${temppath}\\livestock${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\harvest_interview_month${suffix}.dta", keep(master match) nogen
//merge m:1 $hhd  using "${Temp}\\${temppath}\\planting_interview_month${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\ag_asset_index${suffix}.dta", keep(master match) nogen
if `wave'<4 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\aez${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\dist_popcenter${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\elevation${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\twi${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\soil${suffix}.dta", keep(master match) nogen
if `wave'<7 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\Coords${suffix}.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\TZA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_distance${suffix}.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\plot_slope${suffix}.dta", keep(master match) nogen
}


// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
foreach var in   harvest_sold_kg  n_harvest_kg n_harvest_value n_seed_value n_seed_kg   {
capture drop `var'
}  
order hh_id_merge hh_id_obs plot_id_obs plot_id_merge

define_labels

save "${Final}\\TZA_FINAL_plotw`wave'.dta", replace
}

**********************************************************
**** D) Create household datasets
**********************************************************

forvalues wave = 1/7 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hhids

if `wave'==4 | `wave' ==6  {
global suffix _extended
}
if `wave' == 5 | `wave' ==7 {
global suffix _refresh	
}
if `wave' <4{
global suffix 	
}

use "${Temp}\\${temppath}\\hh_frame${suffix}.dta", clear
merge 1:1 $hhd using "${Temp}\\${temppath}\\strataid${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin1${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin2${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin3${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\urban${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\weights${suffix}.dta", keep(master match) nogen
if `wave'<7 {
merge m:1 $hhd using "${Temp}\\${temppath}\\Coords${suffix}.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\TZA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_primary_education${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_electricity_access${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_dependency_ratio${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\cons_quint${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\totcons${suffix}.dta", keep(master match) nogen	
merge 1:1 $hhd using "${Temp}\\${temppath}\\shock${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_asset_index${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\size${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_asset_index${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\nfe${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\HDDS${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\nb_fallow_plots${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\nb_plots${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\harvest_sold_kg_hh${suffix}.dta", keep(master match) nogen
if `wave'==3 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\popdensity${suffix}.dta", keep(master match) nogen
}

gen wave = `wave'



// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\ea_id_obs.dta", keep(master match) nogen
duplicates report hh_id_obs wave
foreach var in  x {
capture drop `var'
} 
order hh_id_merge hh_id_obs 
define_labels

save "${Final}\\TZA_FINAL_hhw`wave'.dta", replace
}

**********************************************************
**** E) Create individual level datasets
**********************************************************

forvalues wave = 1/7 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hhids

if `wave'==4 | `wave' ==6  {
global suffix _extended
}
if `wave' == 5 | `wave' ==7 {
global suffix _refresh	
}
if `wave' <4  {
global suffix 	
}

use "${Temp}\\${temppath}\\indiv_frame${suffix}.dta", clear
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\urban${suffix}.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights${suffix}.dta", keep(master match) nogen
if `wave'<7 {
merge m:1 $hhd using "${Temp}\\${temppath}\\Coords${suffix}.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\TZA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\indiv_chars${suffix}.dta", keep(master match) nogen
if `wave'<4 {
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\wasting${suffix}.dta", keep(master match) nogen
}
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\labor${suffix}.dta", keep(master match) nogen
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\educ_indiv${suffix}.dta", keep(master match) nogen

gen wave = `wave'



gen hh_id_merge = $hhd
gen indiv_id_merge = ID
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\TZA\\Frame_indiv.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\TZA\\ea_id_obs.dta", keep(master match) nogen
foreach var in id_code birth_month   {
capture drop `var'
} 
order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
define_labels
save "${Final}\\TZA_FINAL_indivw`wave'.dta", replace
}


**********************************************************
**** F) Append all
**********************************************************


use "${Final}\\TZA_FINAL_plotcrop1.dta",  clear
forvalues wave=2/7{
append using "${Final}\\TZA_FINAL_plotcrop`wave'.dta",
}
replace wave = 4 if wave==5 
replace wave = 5 if wave==6 
replace wave = 5 if wave==7
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
 foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
drop admin_`admin'_str
}
save "${Final}\\TZA_FINAL_plotcrop.dta", replace


use "${Final}\\TZA_FINAL_plotw1.dta",  clear
forvalues wave=2/7{
append using "${Final}\\TZA_FINAL_plotw`wave'.dta",
}
replace wave = 4 if wave==5 
replace wave = 5 if wave==6 
replace wave = 5 if wave==7
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
  foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
drop admin_`admin'_str
}
save "${Final}\\TZA_FINAL_plot.dta", replace


use "${Final}\\TZA_FINAL_hhw1.dta",  clear
forvalues wave=2/7{
append using "${Final}\\TZA_FINAL_hhw`wave'.dta",
}
replace wave = 4 if wave==5 
replace wave = 5 if wave==6 
replace wave = 5 if wave==7
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
   foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
drop admin_`admin'_str
}
save "${Final}\\TZA_FINAL_hh.dta", replace

use "${Final}\\TZA_FINAL_indivw1.dta",  clear
forvalues wave=2/7{
append using "${Final}\\TZA_FINAL_indivw`wave'.dta",
}
replace wave = 4 if wave==5 
replace wave = 5 if wave==6 
replace wave = 5 if wave==7
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]  
foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
drop admin_`admin'_str
}
save "${Final}\\TZA_FINAL_indiv.dta", replace



**********************************************************
**** G) Create variables for USD values
**********************************************************

wbopendata, language(en - English) country(USA) topics() indicator(FP.CPI.TOTL) clear long
keep year fp_cpi_totl
gen fp_cpi_totl_2020_line = fp_cpi_totl if year==2020
egen fp_cpi_totl_2020 = max(fp_cpi_totl_2020_line)
gen deflator = fp_cpi_totl/fp_cpi_totl_2020
keep deflator year
tempfile deflator
save `deflator', replace

wbopendata, language(en - English) country(TZA) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2008
replace wave = 2 if year == 2010
replace wave = 3 if year == 2012
replace wave = 4 if year == 2014
replace wave = 5 if year == 2019
drop if wave==. 

merge 1:m wave using "${Final}\\TZA_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\TZA_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\TZA_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\TZA_FINAL_plotcrop.dta", replace


keep pa_nus_atls deflator wave 
duplicates drop 


merge 1:m wave using "${Final}\\TZA_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\TZA_FINAL_hh.dta", replace


