/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Append all Tanzania code						                  *
 * Date: January 2024                                                             *
 * -------------------------------------------------------------------------------*
*/
clear 

global paths "UGA\UNPS09 UGA\UNPS10 UGA\UNPS11 UGA\UNPS13 UGA\UNPS15 x UGA\UNPS18 UGA\UNPS19"

global hhids "Hhid HHID HHID hhid hhid x hhid hhid"


**********************************************************
**** A) Harmonize IDs
**********************************************************

// HOUSEHOLD IDs
use "${Input}\Uganda\UNPS 19\GSEC1.dta", clear
recast str32 hhidold
tempfile GSEC1
save `GSEC1', replace 

use "${Input}\Uganda\UNPS 13\GSEC1.dta", clear
keep hhid HHID_old 
tostring HHID_old, replace format("%30.0f")
gen hhid_2 = HHID_old if HHID_old!="."
replace hhid_2 = hhid if HHID_old=="."
rename hhid HHID_temp
rename HHID_old HHID
merge m:1 HHID using "${Temp}\\UGA\UNPS11\\strataid.dta", keep(master match)  nogen
merge m:1 HHID using "${Temp}\\UGA\UNPS11\\ea_id.dta", keep(master match) nogen
drop HHID 
rename HHID_temp  hhid
gen wave=4
keep wave hhid hhid_2  strataid ea_id
tempfile Ids_wave4
save `Ids_wave4', replace

replace hhid = subinstr(hhid, "-04-", "", 1)
merge 1:1 hhid using "${Input}\Uganda\UNPS 15\GSEC1.dta", keep(match) // no match if refresh, or split-offs (unlike malawi, for example)
replace wave=5
keep wave hhid hhid_2 strataid ea_id
tempfile Ids_wave5
save `Ids_wave5', replace

rename hhid t0_hhid
merge 1:m t0_hhid using "${Input}\Uganda\UNPS 18\GSEC1.dta", keep(match using) // we keep the using data here because wave 6 split offs are also in the data 
bys t0_hhid: egen count = count(t0_hhid)
replace hhid_2 = hhid if count>1 | _merge==2
replace wave=7
recast str32 hhid
keep hhid hhid_2 wave strataid ea_id
tempfile Ids_wave7
save `Ids_wave7', replace

rename hhid hhidold 
merge 1:m hhidold using `GSEC1', keep(match) nogen // We use the household data because old HHIDs are not present in the agriculural data
recast str32 hhid
replace wave=8
keep hhid hhid_2 wave strataid ea_id
tempfile Ids_wave8
save `Ids_wave8', replace
	
use "${Temp}\\UGA\UNPS19\\hh_frame.dta", clear
append using "${Temp}\\UGA\UNPS19\\_S2hh_frame.dta"
gen wave = 8 
gen hh_id_merge = hhid
append using "${Temp}\\UGA\UNPS18\\hh_frame.dta"
append using "${Temp}\\UGA\UNPS18\\_S2hh_frame.dta"
replace wave = 7 if wave==.
replace hh_id_merge = hhid if wave==7
append using "${Temp}\\UGA\UNPS15\\hh_frame.dta"
append using "${Temp}\\UGA\UNPS15\\_S2hh_frame.dta"
replace wave = 5 if wave==.
replace hh_id_merge = hhid if wave==5
append using "${Temp}\\UGA\UNPS13\\hh_frame.dta"
append using "${Temp}\\UGA\UNPS13\\_S2hh_frame.dta"
replace wave = 4 if wave==.
replace hh_id_merge = hhid if wave==4
append using "${Temp}\\UGA\UNPS11\\hh_frame.dta"
append using "${Temp}\\UGA\UNPS11\\_S2hh_frame.dta"
replace wave = 3 if wave==.
replace hh_id_merge = HHID if wave==3
gen hh_id_obs = HHID if wave==3
append using "${Temp}\\UGA\UNPS10\\hh_frame.dta"
append using "${Temp}\\UGA\UNPS10\\_S2hh_frame.dta"
replace wave = 2 if wave==.
replace hh_id_merge = HHID if wave==2
replace hh_id_obs = HHID if wave==2
append using "${Temp}\\UGA\UNPS09\\hh_frame.dta"
append using "${Temp}\\UGA\UNPS09\\_S2hh_frame.dta"
replace wave = 1 if wave==.
replace hh_id_merge = Hhid if wave==1
replace hh_id_obs = Hhid if wave==1

gen ea_id_temp = ""
gen strataid_temp  = .
merge m:1 hhid using `Ids_wave4', keep(master match)
replace hh_id_obs = hhid_2 if wave==4 & _merge==3 
replace strataid_temp = strataid if wave==4 & _merge==3 
replace ea_id_temp = ea_id if wave==4 & _merge==3 
drop hhid_2 _merge strataid ea_id
	
merge m:1 hhid using `Ids_wave5', keep(master match) 
replace hh_id_obs = hhid_2 if wave==5 & _merge==3
count if hh_id_obs=="" & wave==5
replace hh_id_obs = hh_id_merge if hh_id_obs=="" & wave==5
replace strataid_temp = strataid if wave==5 & _merge==3 
replace ea_id_temp = ea_id if wave==5 & _merge==3 
drop hhid_2 _merge strataid  ea_id

merge m:1 hhid using `Ids_wave7', keep(master match) 
replace hh_id_obs = hhid_2 if wave==7  & _merge==3
replace strataid_temp = strataid if wave==7 & _merge==3 
replace ea_id_temp = ea_id if wave==7 & _merge==3 
count if hh_id_obs=="" & wave==7
drop hhid_2 _merge strataid ea_id

merge m:1 hhid using `Ids_wave8', keep(master match) 
replace hh_id_obs = hhid_2 if wave==8  & _merge==3
replace strataid_temp = strataid if wave==8 & _merge==3 
replace ea_id_temp = ea_id if wave==8 & _merge==3 
count if hh_id_obs=="" & wave==8
replace hh_id_obs = hh_id_merge if hh_id_obs=="" & wave==8
drop hhid_2 _merge  strataid ea_id

rename strataid_temp strataid
rename ea_id_temp ea_id
rename hh_id_obs hh_id_obs_temp
egen hh_id_obs = group(hh_id_obs_temp)
replace hh_id_obs = hh_id_obs + 7000000 

keep hh_id_obs hh_id_merge wave 
duplicates drop
save "${Temp}\\UGA\\Frame_hhIDs.dta", replace

// INDIV IDs

// WAVE 4
use "${Input}\Uganda\UNPS 13\GSEC2.dta", clear
gen hh_id = hhid
gen id_2 = PID_Old
replace id_2 = pid if PID_Old=="" 
gen wave=4
egen indiv_id_merge = concat(hh_id pid), punct("-")
keep hh_id wave id_2 pid  indiv_id_merge
tempfile Indiv_Ids_wave4
save `Indiv_Ids_wave4', replace
replace hh_id = subinstr(hh_id, "-04-", "", 1)
tempfile Merge_wave4
save `Merge_wave4', replace

// WAVE 5 
use "${Input}\Uganda\UNPS 15\GSEC2.dta", clear
gen hh_id = hhid 
merge m:1 hh_id pid using `Merge_wave4', keepusing(id_2) keep(master match)
replace id_2 = pid if _merge==1
gen wave=5 
egen indiv_id_merge = concat(hh_id pid), punct("-")
keep hh_id wave id_2 pid  	indiv_id_merge
tempfile Indiv_Ids_wave5
save `Indiv_Ids_wave5', replace

// WAVE 7
use "${Input}\Uganda\UNPS 18\GSEC2.dta", clear
gen hh_id = t0_hhid
tostring pid, replace
rename pid pid_wave7
rename pid_unps pid
drop if pid==""
merge m:1 hh_id pid using `Indiv_Ids_wave5', keepusing(id_2) keep(master match)
replace pid = pid_wave7
replace hh_id = hhid
replace id_2 = pid_wave7 if _merge==1 & pid_wave7!=""
gen wave=7 
egen indiv_id_merge = concat(hh_id pid), punct("-")
recast str32 hhid
keep hh_id wave id_2 pid indiv_id_merge
duplicates drop
tempfile Indiv_Ids_wave7
save `Indiv_Ids_wave7', replace

// WAVE 8
use "${Input}\Uganda\UNPS 19\GSEC2.dta", clear 
recast str32 hhid
tempfile GSEC2
save `GSEC2', replace

use "${Input}\Uganda\UNPS 19\GSEC1.dta", clear
recast str32 hhid

merge 1:m hhid using `GSEC2', keep(match) nogen // almost all matched
gen hh_id = hhidold
tostring pid, replace
rename pid pid_wave8 
rename pid_unps_wave7 pid
merge m:1 hh_id pid using `Indiv_Ids_wave7', keepusing(id_2) keep(master match)
replace hh_id = hhid
replace pid = pid_wave8
replace id_2 = pid_wave8 if _merge==1 & pid_wave8!=""
egen indiv_id_merge = concat(hh_id pid), punct("-")
keep hh_id wave id_2 pid indiv_id_merge
tempfile Indiv_Ids_wave8
save `Indiv_Ids_wave8', replace

	
use "${Temp}\\UGA\UNPS19\\indiv_frame.dta", clear
append using "${Temp}\\UGA\UNPS19\\_S2indiv_frame.dta"
gen wave = 8 
gen hh_id_merge = hhid
gen indiv_id_obs = ID
gen indiv_id_merge = ID
drop ID
append using "${Temp}\\UGA\UNPS18\\indiv_frame.dta"
append using "${Temp}\\UGA\UNPS18\\_S2indiv_frame.dta"
replace wave = 7 if wave==.
replace hh_id_merge = hhid if wave==7
replace indiv_id_obs = ID if wave==7
replace indiv_id_merge = ID if wave==7
drop ID
append using "${Temp}\\UGA\UNPS15\\indiv_frame.dta"
append using "${Temp}\\UGA\UNPS15\\_S2indiv_frame.dta"
replace wave = 5 if wave==.
replace hh_id_merge = hhid if wave==5
replace indiv_id_obs = ID if wave==5
replace indiv_id_merge = ID if wave==5
drop ID
append using "${Temp}\\UGA\UNPS13\\indiv_frame.dta"
append using "${Temp}\\UGA\UNPS13\\_S2indiv_frame.dta"
replace wave = 4 if wave==.
replace hh_id_merge = hhid if wave==4
replace indiv_id_obs = ID if wave==4
replace indiv_id_merge = ID if wave==4
drop ID
append using "${Temp}\\UGA\UNPS11\\indiv_frame.dta"
append using "${Temp}\\UGA\UNPS11\\_S2indiv_frame.dta"
replace wave = 3 if wave==.
replace hh_id_merge = HHID if wave==3
replace indiv_id_obs = ID if wave==3
replace indiv_id_merge = ID if wave==3
append using "${Temp}\\UGA\UNPS10\\indiv_frame.dta"
append using "${Temp}\\UGA\UNPS10\\_S2indiv_frame.dta"
replace wave = 2 if wave==.
replace hh_id_merge = HHID if wave==2
replace indiv_id_obs = ID if wave==2
replace indiv_id_merge = ID if wave==2
drop ID
append using "${Temp}\\UGA\UNPS09\\indiv_frame.dta"
append using "${Temp}\\UGA\UNPS09\\_S2indiv_frame.dta"
replace wave = 1 if wave==.
replace indiv_id_obs = ID if wave==1
replace indiv_id_merge = ID if wave==1
drop ID

merge m:1 hh_id_merge wave using "${Temp}\\UGA\\Frame_hhIDs.dta", keep(master match) nogen
tostring hh_id_obs, gen(hh_id_obs_str)

gen dash_ID = length(indiv_id_merge) - length(subinstr(indiv_id_merge, "-", "", .))

replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==1  & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==1  & dash_ID>1


replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==2  & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==2 & dash_ID>1


replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==3  & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==3  & dash_ID>1



merge m:1 indiv_id_merge using `Indiv_Ids_wave4', keep(master match) keepusing(id_2) 

replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==4 & _merge==3 & dash_ID==1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==4 & _merge==3 & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==4 & _merge==3 & dash_ID>1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "P"), .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==4 & _merge==3 & dash_ID>1
drop _merge id_2

merge m:1 indiv_id_merge using `Indiv_Ids_wave5', keep(master match) keepusing(id_2) 

replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==5 & _merge==3 & dash_ID==1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==5 & _merge==3 & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==5 & _merge==3 & dash_ID>1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "P"), .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==5 & _merge==3 & dash_ID>1
drop _merge id_2

merge m:1 indiv_id_merge using `Indiv_Ids_wave7', keep(master match) keepusing(id_2) 

gen indiv_id_obs_temp7 = indiv_id_obs
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==7 & _merge==3 & dash_ID==1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==7 & _merge==3 & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==7 & _merge==3 & dash_ID>1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "P"), .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==7 & _merge==3 & dash_ID>1
drop _merge id_2

merge m:1 indiv_id_merge using `Indiv_Ids_wave8', keep(master match) keepusing(id_2) 

gen indiv_id_obs_temp8 = indiv_id_obs
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "-")-1), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==8 & _merge==3 & dash_ID==1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strpos(indiv_id_obs, "-")+1, .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==8 & _merge==3 & dash_ID==1
replace indiv_id_obs = subinstr(indiv_id_obs, substr(indiv_id_obs, 1, strpos(indiv_id_obs, "P")-2), hh_id_obs_str, 1 ) if indiv_id_obs!="" & wave==8 & _merge==3 & dash_ID>1
replace indiv_id_obs = strreverse(subinstr(strreverse(indiv_id_obs), strreverse(substr(indiv_id_obs, strrpos(indiv_id_obs, "P"), .)), strreverse(id_2), 1 )) if indiv_id_obs!="" & wave==8 & _merge==3 & dash_ID>1

drop _merge id_2 


keep indiv_id_obs indiv_id_merge  wave hh_id_merge indiv_id_obs_temp8 indiv_id_obs_temp7
duplicates drop

	// rectify some duplicates - they will be treated as new observations
	duplicates tag  wave indiv_id_obs , gen(t2)
	replace indiv_id_obs = indiv_id_obs_temp8 if t2>0 & wave ==8
	replace indiv_id_obs = indiv_id_obs_temp7 if t2>0 & wave ==7


rename  indiv_id_obs indiv_id_obs_temp
egen indiv_id_obs = group(indiv_id_obs_temp)
replace indiv_id_obs = indiv_id_obs + 7000000 

	
drop indiv_id_obs_temp t2

save "${Temp}\\UGA\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
foreach season in "" "_S2" {
foreach wave in 3 4 5 7 8 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\`season'respondent_characteristics1.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep parcel_id  respondent_id_obs respondent_id_merge 
save "${Temp}\\${temppath}\\`season'respondent_characteristics1_ID.dta", replace
restore
}
}

rename respondent_id manager_id
foreach season in "" "_S2" {
foreach wave in 1 2 3 4 5 7 8 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  manager_id using "${Temp}\\${temppath}\\`season'Manager_characteristics1.dta", keep(match)
rename manager_id manager_id_merge
gen manager_id_obs = indiv_id_obs
keep parcel_id  manager_id_obs manager_id_merge 
sort parcel_id  manager_id_obs manager_id_merge 
save "${Temp}\\${temppath}\\`season'Manager_characteristics1_ID.dta", replace
restore
}
}


use "${Temp}\\UGA\\UNPS09\\plot_crop_frame.dta", clear
gen season = 1
append using "${Temp}\\UGA\\UNPS09\\_S2plot_crop_frame.dta"
gen wave = 1
replace season = 2 if season==.
append using "${Temp}\\UGA\\UNPS10\\plot_crop_frame.dta"
replace season = 1 if season==.
append using "${Temp}\\UGA\\UNPS10\\_S2plot_crop_frame.dta"
replace wave = 2 if wave==.
replace season = 2 if season==.
append using "${Temp}\\UGA\\UNPS11\\plot_crop_frame.dta"
replace season = 1 if season==.
append using "${Temp}\\UGA\\UNPS11\\_S2plot_crop_frame.dta"
replace wave = 3 if wave==.
replace season = 2 if season==.
append using "${Temp}\\UGA\\UNPS13\\plot_crop_frame.dta"
replace season = 1 if season==.
append using "${Temp}\\UGA\\UNPS13\\_S2plot_crop_frame.dta"
replace wave = 4 if wave==.
replace season = 2 if season==.
append using "${Temp}\\UGA\\UNPS15\\plot_crop_frame.dta"
replace season = 1 if season==.
append using "${Temp}\\UGA\\UNPS15\\_S2plot_crop_frame.dta"
replace wave = 5 if wave==.
replace season = 2 if season==.
append using "${Temp}\\UGA\\UNPS18\\plot_crop_frame.dta"
replace season = 1 if season==.
append using "${Temp}\\UGA\\UNPS18\\_S2plot_crop_frame.dta"
replace wave = 7 if wave==.
replace season = 2 if season==.
append using "${Temp}\\UGA\\UNPS19\\plot_crop_frame.dta"
replace season = 1 if season==.
append using "${Temp}\\UGA\\UNPS19\\_S2plot_crop_frame.dta"
replace wave = 8 if wave==.
replace season = 2 if season==.


	// cannot track plots
	egen plot_id_temp = concat(wave season plot_id  ), punct("-")
	egen plot_id_obs = group(plot_id_temp)
	replace plot_id_obs = plot_id_obs + 7000000 
	gen plot_id_merge=  plot_id 
	
	egen parcel_id_temp = concat(wave parcel_id ), punct("-")
	egen parcel_id_obs= group(parcel_id_temp)
	replace parcel_id_obs = parcel_id_obs + 7000000 
	gen parcel_id_merge=  parcel_id


keep plot_id plot_id_obs plot_id_merge cropID crop_name wave parcel_id_merge parcel_id_obs
duplicates drop
save "${Temp}\\UGA\\Frame_plotcrop.dta", replace


use "${Temp}\\UGA\\UNPS09\\Coords.dta", clear
append using "${Temp}\\UGA\\UNPS10\\Coords.dta"
append using "${Temp}\\UGA\\UNPS11\\Coords.dta"
keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 7000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\UGA\\geocoords_id.dta", replace



use  "${Temp}\\UGA\UNPS19\\ea_id.dta", clear
append using "${Temp}\\UGA\UNPS19\\_S2ea_id.dta"
gen wave = 8
gen hh_id_merge = hhid
append using "${Temp}\\UGA\UNPS18\\ea_id.dta"
append using "${Temp}\\UGA\UNPS18\\_S2ea_id.dta"
replace wave = 7 if wave==.
replace hh_id_merge = hhid if wave==7
append using "${Temp}\\UGA\UNPS15\\ea_id.dta"
append using "${Temp}\\UGA\UNPS15\\_S2ea_id.dta"
replace wave = 5 if wave==.
replace hh_id_merge = hhid if wave==5
append using "${Temp}\\UGA\UNPS13\\ea_id.dta"
append using "${Temp}\\UGA\UNPS13\\_S2ea_id.dta"
replace wave = 4 if wave==.
replace hh_id_merge = hhid if wave==4
append using "${Temp}\\UGA\UNPS11\\ea_id.dta"
append using "${Temp}\\UGA\UNPS11\\_S2ea_id.dta"
replace wave = 3 if wave==.
replace hh_id_merge = HHID if wave==3
append using "${Temp}\\UGA\UNPS10\\ea_id.dta"
append using "${Temp}\\UGA\UNPS10\\_S2ea_id.dta"
replace wave = 2 if wave==.
replace hh_id_merge = HHID if wave==2
append using "${Temp}\\UGA\UNPS09\\ea_id.dta"
append using "${Temp}\\UGA\UNPS09\\_S2ea_id.dta"
replace wave = 1 if wave==.
replace hh_id_merge = Hhid if wave==1
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 7000000
bys hh_id_obs (ea_id_obs): replace ea_id_obs = ea_id_obs[1] //  30 errors
rename ea_id ea_id_merge

keep hh_id_merge ea_id_obs  ea_id_merge wave
duplicates drop
save "${Temp}\\UGA\\ea_id_obs.dta", replace


	
	
**********************************************************
**** B) Create plot-crop datasets
**********************************************************


foreach season in "" "_S2" {
foreach wave in 1 2 3 4 5 7 8 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hhids

use "${Temp}\\${temppath}\\`season'plot_crop_frame.dta", clear
duplicates drop
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'admin3.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'urban.dta", keep(master match) nogen
if `wave'<4 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\UGA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'harvest_kg.dta", keep(master match) nogen
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'harvest_value_plot.dta",  keep(master match) nogen
drop main_crop // added later
if `wave'>1 {
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'harvest_end_month.dta", keep(master match) nogen
}
if `wave'>2 {
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'planting_month.dta", keep(master match) nogen
}
if `wave'>3 {
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'seed_kg_merge.dta", keep(master match) nogen
}
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'seed_value.dta" , keep(master match) nogen
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'improved.dta" , keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\`season'used_pesticides.dta", keep(master match) nogen
merge 1:1 plot_id cropID using "${Temp}\\${temppath}\\`season'crop_shock.dta", keep(master match) nogen

gen wave = `wave'

define_labels

 
// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\ea_id_obs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\Frame_hhIDs.dta", keep(master match) nogen
merge 1:m plot_id cropID wave  using "${Temp}\\UGA\\Frame_plotcrop.dta", keep(master match) nogen
drop if cropID == .
preserve
foreach var in A5aq1 A5aq3 n_harvest_kg A5bq1 A5bq3  n_harvest_sold_kg   harvest_sold_kg  parcel_id {
capture drop `var'
}  
save "${Final}\\`season'UGA_FINAL_plotcrop`wave'.dta", replace
restore



**********************************************************
**** C) Create plot datasets
**********************************************************

if `wave'>3 {
global temp3 seed_kg seed_value
global n_temp3 n_seed_kg=seed_kg n_seed_value=seed_value

}
else { 
global temp3	
global n_temp3
}
collapse (sum) harvest_kg harvest_value  $temp3 (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value $n_temp3 (max) used_pesticides *_shock  , by(  pw   wave parcel_id parcel_id_obs parcel_id_merge hh_id_obs hh_id_merge ea_id_merge ea_id_obs strataid )

foreach var in  harvest_kg harvest_value $temp3 {
	replace `var' = . if n_`var'==0
}


global hhd: word `wave' of $hhids

merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'intercropped.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'nb_seasonal_crop.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'main_crop.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'plot_area.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'labor_days.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'inorganic_fertilizer.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'nitrogen_kg.dta", keep(master match) nogen keepusing(nitrogen_kg)
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'inorganic_fertilizer_value.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'organic_fertilizer.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'Manager_characteristics1.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'Manager_characteristics1_ID.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'Manager_characteristics2.dta", keep(master match) nogen
if `wave'> 2 {
merge m:1 parcel_id  using "${Temp}\\${temppath}\\`season'respondent_characteristics1.dta", keep(master match) nogen
merge m:1 parcel_id  using "${Temp}\\${temppath}\\`season'respondent_characteristics1_ID.dta", keep(master match) nogen
merge m:1 parcel_id  using "${Temp}\\${temppath}\\`season'Resp_characteristics2.dta", keep(master match) nogen	
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'tractor.dta", keep(master match) nogen
}
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'irrigated.dta", keep(master match) nogen
merge 1:1 parcel_id  using "${Temp}\\${temppath}\\`season'erosion_protection.dta", keep(master match) nogen
merge m:1 parcel_id   using "${Temp}\\${temppath}\\`season'plot_owned.dta", keep(master match) nogen	
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'livestock.dta", keep(master match) nogen
if `wave'!=7 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'harvest_interview_month.dta", keep(master match) nogen
}
// merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'planting_interview_month.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'urban.dta", keep(master match) nogen
if `wave'>1 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'ag_asset_index.dta", keep(master match) nogen
}
if `wave'<4 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'aez.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'dist_popcenter.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'elevation.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'twi.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'soil_fertility_index.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\UGA\\geocoords_id.dta", keep(master match) nogen
// merge 1:1 plot_id  using "${Temp}\\${temppath}\\`season'plot_distance.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'plot_slope.dta", keep(master match) nogen
}


// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
foreach var in   harvest_sold_kg n_harvest_kg n_harvest_value n_seed_value n_seed_kg Hhid HHID Ntotal_labor_days Ntotal_family_labor_days Ntotal_hired_labor_days Nhired_labor_value {
capture drop `var'
}  
rename (parcel_id_obs parcel_id_merge) (plot_id_obs plot_id_merge)
order hh_id_merge hh_id_obs  

define_labels

save "${Final}\\`season'UGA_FINAL_plotw`wave'.dta", replace
}
}

**********************************************************
**** D) Create household datasets
**********************************************************

foreach season in "" "_S2" {
foreach wave in 1 2 3 4 5 7 8 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hhids

use "${Temp}\\${temppath}\\`season'hh_frame.dta", clear
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'strataid.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'admin1.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'admin2.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'admin3.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'urban.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'weights.dta", keep(master match) nogen
if `wave'<4 {
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\UGA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'hh_primary_education.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'hh_electricity_access.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'hh_dependency_ratio.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'cons_quint.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'totcons.dta", keep(master match) nogen	
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'shock.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'hh_asset_index.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\`season'hh_size.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\`season'hh_asset_index.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'nfe.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'HDDS.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\`season'harvest_sold_kg_hh.dta", keep(master match) nogen

gen wave = `wave'



// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\ea_id_obs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\Frame_hhIDs.dta", keep(master match) nogen
foreach var in  Hhid HHID Ntotal_labor_days Ntotal_family_labor_days Ntotal_hired_labor_days Nhired_labor_value {
capture drop `var'
} 
order hh_id_merge hh_id_obs 
define_labels

save "${Final}\\`season'UGA_FINAL_hhw`wave'.dta", replace
}
}

**********************************************************
**** E) Create individual level datasets
**********************************************************

foreach season in "" "_S2" {
foreach wave in 1 2 3 4 5 7 8 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hhids

use "${Temp}\\${temppath}\\`season'indiv_frame.dta", clear
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'admin3.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'urban.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'weights.dta", keep(master match) nogen
if `wave'<4 {
merge m:1 $hhd using "${Temp}\\${temppath}\\`season'Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\UGA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\`season'indiv_chars.dta", keep(master match) nogen
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\`season'wasting.dta", keep(master match) nogen

merge 1:1 $hhd ID using "${Temp}\\${temppath}\\`season'labor.dta", keep(master match) nogen
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\`season'educ_indiv.dta", keep(master match) nogen

gen wave = `wave'

gen hh_id_merge = $hhd
gen indiv_id_merge = ID
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\ea_id_obs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\UGA\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\UGA\\Frame_indiv.dta", keep(master match) nogen
foreach var in Hhid HHID Ntotal_labor_days Ntotal_family_labor_days Ntotal_hired_labor_days Nhired_labor_value {
capture drop `var'
} 
order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
define_labels
save "${Final}\\`season'UGA_FINAL_indivw`wave'.dta", replace
}
}

**********************************************************
**** F) Append all
**********************************************************


use "${Final}\\UGA_FINAL_plotcrop1.dta",  clear
gen season = 1
append using "${Final}\\_S2UGA_FINAL_plotcrop1.dta"
replace season = 2 if season ==.
foreach wave in 2 3 4 5 7 8 {
append using "${Final}\\UGA_FINAL_plotcrop`wave'.dta",
replace season = 1 if season==.
append using "${Final}\\_S2UGA_FINAL_plotcrop`wave'.dta",
replace season = 2 if season==.
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
save "${Final}\\UGA_FINAL_plotcrop.dta", replace


use "${Final}\\UGA_FINAL_plotw1.dta",  clear
gen season = 1
append using "${Final}\\_S2UGA_FINAL_plotw1.dta"
replace season = 2 if season ==.
foreach wave in 2 3 4 5 7 8 {
append using "${Final}\\UGA_FINAL_plotw`wave'.dta",
replace season = 1 if season==.
append using "${Final}\\_S2UGA_FINAL_plotw`wave'.dta",
replace season = 2 if season==.
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
save "${Final}\\UGA_FINAL_plot.dta", replace


use "${Final}\\UGA_FINAL_hhw1.dta",  clear
gen season = 1
append using "${Final}\\_S2UGA_FINAL_hhw1.dta"
replace season = 2 if season ==.
foreach wave in 2 3 4 5 7 8 {
append using "${Final}\\UGA_FINAL_hhw`wave'.dta",
replace season = 1 if season==.
append using "${Final}\\_S2UGA_FINAL_hhw`wave'.dta",
replace season = 2 if season==.
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

save "${Final}\\UGA_FINAL_hh.dta", replace

use "${Final}\\UGA_FINAL_indivw1.dta",  clear
gen season = 1
append using "${Final}\\_S2UGA_FINAL_indivw1.dta"
replace season = 2 if season ==.
foreach wave in 2 3 4 5 7 8 {
append using "${Final}\\UGA_FINAL_indivw`wave'.dta",
replace season = 1 if season==.
append using "${Final}\\_S2UGA_FINAL_indivw`wave'.dta",
replace season = 2 if season==.
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
save "${Final}\\UGA_FINAL_indiv.dta", replace

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

wbopendata, language(en - English) country(UGA) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2009
replace wave = 2 if year == 2010
replace wave = 3 if year == 2011
replace wave = 4 if year == 2013
replace wave = 5 if year == 2015
replace wave = 7 if year == 2018
replace wave = 8 if year == 2019
drop if wave==. 

merge 1:m wave using "${Final}\\UGA_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\UGA_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 


merge 1:m wave using "${Final}\\UGA_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\UGA_FINAL_plotcrop.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\UGA_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\UGA_FINAL_hh.dta", replace


