/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Append all Niger code						          *
* Date: January 2024                                                            *
* -------------------------------------------------------------------------------*
*/
clear 

global paths "NER\ECVMA11 NER\ECVMA14"

global hh "hid hhid"


**********************************************************
**** A) Harmonize IDs
**********************************************************


use "${Temp}\\NER\ECVMA11\\hh_frame.dta", clear
gen wave = 1
append using "${Temp}\\NER\ECVMA14\\hh_frame.dta", gen(append)
replace wave = 2 if append==1

tostring hid, gen(hid_str)
gen hh_id_merge = hid_str if wave == 1
replace hh_id_merge = hhid if wave == 2
gen hhid_nograppe = substr(hhid, strpos(hhid, "-") + 1,.) if wave==2
gen extension = substr(hhid_nograppe, strpos(hhid_nograppe, "-") + 1,.) if wave==2
gen grappe = substr(hhid, 1,strpos(hhid, "-") - 1) if wave==2 // we extract the grappe number
gen menage = substr(substr(hhid, strpos(hhid, "-") + 1,.), 1, strpos(substr(hhid, strpos(hhid, "-") + 1,.), "-") - 1) if wave==2 // we extract the menage number
tostring menage, replace
replace menage = "0" + menage if strlen(menage)==1
tostring grappe, replace

egen hh_id2 = concat(grappe menage) // the hhid in wave 2 is now constructed the same way as in wave 1
gen hh_id_obs_temp = hid_str
replace hh_id_obs_temp = hh_id2 if extension=="0" & wave==2 | extension=="1" & wave==2 

egen hh_id_splitoff = concat(hh_id2 extension), punct("-")
replace hh_id_obs_temp = hh_id_splitoff if extension=="2" & wave==2
egen hh_id_obs = group(hh_id_obs_temp)
replace hh_id_obs = hh_id_obs + 4000000 

keep hh_id_obs hh_id_merge wave hh_id_obs_temp
duplicates drop
save "${Temp}\\NER\\Frame_hhIDs.dta", replace

use "${Temp}\\NER\\ECVMA11\\plot_crop_frame.dta", clear
gen wave = 1
append using "${Temp}\\NER\ECVMA14\\plot_crop_frame.dta", gen(append)
replace wave = 2 if append==1

// cannot track plots
egen plot_id_temp = concat(wave plot_id ), punct("-")
egen plot_id_obs = group(plot_id_temp)
replace plot_id_obs = plot_id_obs + 4000000 
gen plot_id_merge=  plot_id 

// assume we cannot track plots
egen parcel_id_temp = concat(wave parcel_id ), punct("-")
egen parcel_id_obs = group(parcel_id_temp)
replace parcel_id_obs = parcel_id_obs + 4000000 
gen parcel_id_merge=  parcel_id 

keep plot_id plot_id_obs plot_id_merge  crop_code crop_name wave parcel_id_merge parcel_id_obs
duplicates drop
save "${Temp}\\NER\\Frame_plotcrop.dta", replace

use "${Temp}\\NER\\ECVMA11\\indiv_frame.dta", clear
gen wave = 1
append using "${Temp}\\NER\\ECVMA14\\indiv_frame.dta", gen(append)
replace wave = 2 if append==1

gen indiv_id_obs_temp = ID
gen indiv_id_merge = ID

tostring hid, gen(hid_str)
gen hh_id_merge = hid_str if wave == 1
replace hh_id_merge = hhid if wave == 2

merge m:1 hh_id_merge wave using "${Temp}\\NER\\Frame_hhIDs.dta",
replace indiv_id_obs_temp = subinstr(indiv_id_obs_temp, substr(indiv_id_obs_temp, 1, strrpos(indiv_id_obs_temp, "-") - 1),hh_id_obs_temp , 1  )
egen indiv_id_obs = group(indiv_id_obs_temp)
replace indiv_id_obs = indiv_id_obs + 4000000

	//individuals in split off households cannot be tracked
	gen extension = substr(hhid,-1, 1)  if wave ==2
	sum indiv_id_obs, d
	replace indiv_id_obs = indiv_id_obs + 50000 if extension=="2"
	
keep ID indiv_id_obs indiv_id_merge  wave hh_id_merge
duplicates drop
save "${Temp}\\NER\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
forvalues wave = 1/2 {
preserve
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\Respondent_characteristics1.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep $hhd  respondent_id_obs respondent_id_merge 
save "${Temp}\\${temppath}\\Respondent_characteristics1_ID.dta", replace
restore
}
rename respondent_id manager_id
forvalues wave = 1/2 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  manager_id using "${Temp}\\${temppath}\\Manager_characteristics1.dta", keep(match)
rename manager_id manager_id_merge
gen manager_id_obs = indiv_id_obs
keep plot_id  manager_id_obs manager_id_merge 
save "${Temp}\\${temppath}\\Manager_characteristics1_ID.dta", replace
restore
}

use "${Temp}\\NER\ECVMA11\\Coords.dta", clear
append using "${Temp}\\NER\ECVMA14\\Coords.dta"

keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 4000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\NER\\geocoords_id.dta", replace


use "${Temp}\\NER\ECVMA11\\ea_id.dta", clear
tostring hid, gen(hid_str)
gen hh_id_merge = hid_str
gen wave =1
append using "${Temp}\\NER\ECVMA14\\ea_id.dta", 
replace hh_id_merge = hhid if hh_id_merge==""
replace  wave =2 if wave==.

merge m:1 hh_id_merge wave using "${Temp}\\NER\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 4000000
sort hh_id_obs (ea_id_obs)
bys hh_id_obs: replace ea_id_obs = ea_id_obs[1] // 5 errors

rename ea_id ea_id_merge

keep hh_id_merge ea_id_obs  ea_id_merge wave
duplicates drop
isid hh_id_merge wave
sort hh_id_merge wave
save "${Temp}\\NER\\ea_id_obs.dta", replace


**********************************************************
**** B) Create plot-crop datasets
**********************************************************

forvalues wave = 1/2 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh

use "${Temp}\\${temppath}\\plot_crop_frame.dta", clear
duplicates drop
merge m:1 $hhd using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NER\\geocoords_id.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_kg.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_value.dta", keep(master match) nogen
drop main_crop // added later
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\pct_area_planted.dta", keep(master match) nogen
if `wave'==2 {
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_end_month.dta", keep(master match) nogen
}
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\planting_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_kg_merge.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_value.dta" , keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\improved.dta" , keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\used_pesticides.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\crop_shock.dta", keep(master match) nogen

gen wave = `wave'





// harmonise IDS
if `wave'==1 {
gen hh_id_merge = string($hhd )	
}
else {
gen hh_id_merge = $hhd
}
merge m:1 hh_id_merge wave using "${Temp}\\NER\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\NER\\ea_id_obs.dta", keep(master match) nogen
merge 1:1 plot_id crop_code wave using "${Temp}\\NER\\Frame_plotcrop.dta", keep(master match) nogen

preserve
foreach var in  parcel_id _merge n_nitrogen_kg n_NPK_kg n_DAP_kg n_UREA_kg UREA_kg DAP_kg NPK_kg  harvest_sold_kg year_planting month_planting  {
capture drop `var'
}  
define_labels
save "${Final}\\NER_FINAL_plotcrop`wave'.dta", replace
restore

// drop obs with no plot id
gen substr = substr(plot_id_merge, 1, 7)
drop if substr=="missing"


**********************************************************
**** C) Create plot datasets
**********************************************************

collapse (sum) harvest_kg harvest_value  seed_kg  seed_value (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value n_seed_kg = seed_kg  n_seed_value =seed_value (max) improved used_pesticides *_shock , by(plot_id ea_id ea_id_merge ea_id_obs  pw strataid admin_1 admin_1_name admin_2  admin_3 parcel_id_obs parcel_id_merge wave plot_id_obs plot_id_merge hh_id_obs hh_id_merge )


foreach var in  harvest_kg harvest_value seed_kg  seed_value {
	replace `var' = . if n_`var'==0
}



merge 1:1 plot_id  using "${Temp}\\${temppath}\\intercropped.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\nb_seasonal_crop.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\main_crop.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_area.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\labor_days.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\inorganic_fertilizer.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\organic_fertilizer.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics1.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics1_ID.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics2.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Respondent_characteristics1.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Respondent_characteristics1_ID.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Resp_characteristics2.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\irrigated.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\erosion_protection.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\tractor.dta", keep(master match) nogen
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen	
merge m:1 $hhd  using "${Temp}\\${temppath}\\livestock.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\harvest_interview_month.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\planting_interview_month.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\ag_asset_index.dta", keep(master match) nogen
if `wave'==1 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\aez.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\dist_popcenter.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\elevation.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\twi.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\soil.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NER\\geocoords_id.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\plot_slope.dta", keep(master match) nogen
}

// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
foreach var in parcel_id passage grappe menage ms00q01 ms00q02 ms00q03aj ms00q03am ms00q03aa ms00q03bh ms00q03bm ms00q04aj ms00q04am ms00q04aa ms00q04bh ms00q04bm ms00q05 ms00q06 ms00q07j ms00q07m ms00q07a ms00q08 ms00q09j ms00q09m ms00q09a ms00q10 ms00q11 ms00q12 ms00q13 ms00q14 ms00q15 ms00q16 ms00q17 ms00q22 ms00q23 ms00q24 ms00q25 ms00q26 ms00q27 ms00q28 as00q01 as00q02 as00q03aj as00q03am as00q03aa as00q03bh as00q03bm as00q04aj as00q04am as00q04aa as00q04bh as00q04bm as00q05 as00q06 as00q07j as00q07m as00q07a as00q08 as00q09j as00q09m as00q09a PASSAGE GRAPPE MENAGE EXTENSION MS00Q01 MS00Q02 MS00Q03A MS00Q03B MS00Q04A MS00Q04B MS00Q05 MS00Q06 MS00Q07 MS00Q08 MS00Q09 MS00Q10 MS00Q11 MS00Q12 MS00Q14 MS00Q15 MS00Q16 MS00Q17 MS00Q22 MS00Q23 MS00Q24 MS00Q25 MS00Q26 MS00Q59 MS00Q60 MS00Q61 hid  harvest_sold_kg n_harvest_kg n_harvest_value n_seed_value n_seed_kg UREA_kg DAP_kg NPK_kg n_nitrogen_kg n_NPK_kg n_DAP_kg n_UREA_kg respondent_id manager_ID ea_id  year_planting month_planting {
capture drop `var'
}
order hh_id_merge hh_id_obs plot_id_obs plot_id_merge

define_labels

save "${Final}\\NER_FINAL_plotw`wave'.dta", replace
}

**********************************************************
**** D) Create household datasets
**********************************************************


forvalues wave = 1/2 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh

use "${Temp}\\${temppath}\\hh_frame.dta", clear
gen wave = `wave'

merge 1:1 $hhd using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 ea_id using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NER\\geocoords_id.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_primary_education.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_electricity_access.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_dependency_ratio.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\cons_quint.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\totcons.dta", keep(master match) nogen			
merge 1:1 $hhd using "${Temp}\\${temppath}\\shock.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\size.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\nfe.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\HDDS.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nb_fallow_plots.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nb_plots.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", keep(master match) nogen

// harmonise IDS
if `wave'==1 {
gen hh_id_merge = string($hhd )	
}
else {
gen hh_id_merge = $hhd
}
merge m:1 hh_id_merge wave using "${Temp}\\NER\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\NER\\ea_id_obs.dta", keep(master match) nogen
foreach var in EXTENSION hid ea_id {
capture drop `var'
} 
define_labels
order hh_id_merge hh_id_obs 
save "${Final}\\NER_FINAL_hhw`wave'.dta", replace
}

**********************************************************
**** E) Create individual level datasets
**********************************************************


forvalues wave = 1/2 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh

use "${Temp}\\${temppath}\\indiv_frame.dta", clear
merge m:1 $hhd using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NER\\geocoords_id.dta", keep(master match) nogen
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\indiv_chars.dta", keep(master match) nogen
// merge 1:1 $hhd ID using "${Temp}\\${temppath}\\wasting.dta", keep(master match) nogen
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\labor.dta", keep(master match) nogen
merge 1:1 $hhd ID using "${Temp}\\${temppath}\\educ_indiv.dta", keep(master match) nogen

gen wave = `wave'
define_labels

if `wave'==1 {
gen hh_id_merge = string($hhd )	
}
else {
gen hh_id_merge = $hhd
}
gen indiv_id_merge = ID
merge m:1 hh_id_merge wave using "${Temp}\\NER\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\NER\\ea_id_obs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\NER\\Frame_indiv.dta", keep(master match) nogen
foreach var in hid MS01Q06B ms01q06b ea_id {
capture drop `var'
} 
order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
save "${Final}\\NER_FINAL_indivw`wave'.dta", replace
}


**********************************************************
**** F) Append all
**********************************************************


use "${Final}\\NER_FINAL_plotcrop1.dta",  clear
append using "${Final}\\NER_FINAL_plotcrop2.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

bys ea_id_merge (strataid): replace  strataid = strataid[1] if strataid==.
save "${Final}\\NER_FINAL_plotcrop.dta", replace


use "${Final}\\NER_FINAL_plotw1.dta",  clear
append using "${Final}\\NER_FINAL_plotw2.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

bys ea_id_merge (strataid): replace  strataid = strataid[1] if strataid==.
save "${Final}\\NER_FINAL_plot.dta", replace


use "${Final}\\NER_FINAL_hhw1.dta",  clear
append using "${Final}\\NER_FINAL_hhw2.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

bys ea_id_merge (strataid): replace  strataid = strataid[1] if strataid==.
save "${Final}\\NER_FINAL_hh.dta", replace

use "${Final}\\NER_FINAL_indivw1.dta",  clear
append using "${Final}\\NER_FINAL_indivw2.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

bys ea_id_merge (strataid): replace  strataid = strataid[1] if strataid==.
save "${Final}\\NER_FINAL_indiv.dta", replace



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

wbopendata, language(en - English) country(NER) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2011
replace wave = 2 if year == 2014
drop if wave==. 

merge 1:m wave using "${Final}\\NER_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\NER_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\NER_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\NER_FINAL_plotcrop.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\NER_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\NER_FINAL_hh.dta", replace

