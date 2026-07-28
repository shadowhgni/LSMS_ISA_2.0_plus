/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Append all Mali code						          *
 * Date: January 2024                                                            *
 * -------------------------------------------------------------------------------*
*/
clear 

global paths "MLI\EACI14 MLI\EACI17"

**********************************************************
**** A) Harmonize IDs
**********************************************************
 
use "${Temp}\\MLI\EACI14\\hh_frame.dta", clear
gen wave = 1
append using "${Temp}\\MLI\EACI17\\hh_frame.dta", gen(append)
replace wave = 2 if append==1


	// cannot track plots
	egen hhid_temp = concat(wave hhid ), punct("-")
	egen hh_id_obs = group(hhid_temp)
	replace hh_id_obs = hh_id_obs + 3000000 
	gen hh_id_merge=  hhid 

keep hhid hh_id_obs hh_id_merge wave
duplicates drop
save "${Temp}\\MLI\\Frame_hhIDs.dta", replace

use "${Temp}\\MLI\\EACI14\\plot_crop_frame.dta", clear
gen wave = 1
append using "${Temp}\\MLI\EACI17\\plot_crop_frame.dta", gen(append)
replace wave = 2 if append==1

	// cannot track plots
	egen plot_id_temp = concat(wave plot_id ), punct("-")
	egen plot_id_obs = group(plot_id_temp)
	replace plot_id_obs = plot_id_obs + 3000000 
	gen plot_id_merge=  plot_id 
	
	// cannot track parcels
	egen parcel_id_temp = concat(wave parcel_id ), punct("-")
	egen parcel_id_obs = group(parcel_id_temp)
	replace parcel_id_obs = parcel_id_obs + 3000000 
	gen parcel_id_merge=  parcel_id 


keep plot_id plot_id_obs plot_id_merge  crop_code crop_name wave parcel_id_merge parcel_id_obs
duplicates drop
save "${Temp}\\MLI\\Frame_plotcrop.dta", replace

use "${Temp}\\MLI\\EACI14\\indiv_frame.dta", clear
gen wave = 1
append using "${Temp}\\MLI\\EACI17\\indiv_frame.dta", gen(append)
replace wave = 2 if append==1

// cannot track individuals
egen indiv_id_obs_temp = concat(wave ID ), punct("-")
egen indiv_id_obs = group(indiv_id_obs_temp)
replace indiv_id_obs = indiv_id_obs + 3000000 

gen indiv_id_merge = ID

gen hh_id_merge = hhid

keep ID indiv_id_obs indiv_id_merge  wave hh_id_merge
duplicates drop
save "${Temp}\\MLI\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
forvalues wave = 1/2 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\Respondent_characteristics1.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep plot_id  respondent_id_obs respondent_id_merge 
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

use "${Temp}\\MLI\\EACI14\\Coords.dta", clear
append using "${Temp}\\MLI\\EACI17\\Coords.dta", 

keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 3000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\MLI\\geocoords_id.dta", replace


use "${Temp}\\MLI\EACI14\\ea_id.dta", clear
gen hh_id_merge = hhid
gen wave =1
append using "${Temp}\\MLI\EACI17\\ea_id.dta", 
replace hh_id_merge = hhid if hh_id_merge==""
replace  wave =2 if wave==.

merge m:1 hh_id_merge wave using "${Temp}\\MLI\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 3000000
bys hh_id_obs: assert ea_id_obs == ea_id_obs[1]

tostring ea_id, gen(ea_id_merge)

keep hh_id_merge ea_id_obs  ea_id_merge wave
duplicates drop
isid hh_id_merge wave
save "${Temp}\\MLI\\ea_id_obs.dta", replace


**********************************************************
**** B) Create plot-crop datasets
**********************************************************

forvalues wave = 1/2 {
global temppath: word `wave' of $paths

use "${Temp}\\${temppath}\\plot_crop_frame.dta", clear
duplicates drop
merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MLI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_kg.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_value.dta", keep(master match) nogen
drop main_crop // added later
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\pct_area_planted.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_end_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\planting_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_kg_merge.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_value.dta" , keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\improved.dta" , keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\used_pesticides.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\crop_shock.dta", keep(master match) nogen

gen wave = `wave'


define_labels

 
// harmonise IDS
gen hh_id_merge = hhid
merge m:1 hh_id_merge wave using "${Temp}\\MLI\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\MLI\\ea_id_obs.dta", keep(master match) nogen
merge 1:1 plot_id crop_code wave using "${Temp}\\MLI\\Frame_plotcrop.dta", keep(master match) nogen
preserve
foreach var in _merge   harvest_sold_kg ea_id parcel_id {
capture drop `var'
}  
save "${Final}\\MLI_FINAL_plotcrop`wave'.dta", replace
restore

// drop obs with no plot id
gen substr = substr(plot_id_merge, 1, 7)
drop if substr=="missing"

**********************************************************
**** C) Create plot datasets
**********************************************************

collapse (sum) harvest_kg harvest_value   seed_kg  seed_value (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value n_seed_kg = seed_kg  n_seed_value =seed_value (max) improved used_pesticides *_shock , by(plot_id ea_id ea_id_obs ea_id_merge  pw strataid admin_1 admin_1_name admin_2  admin_3   wave plot_id_obs plot_id_merge hh_id_obs hh_id_merge parcel_id_obs parcel_id_merge)


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
merge m:1 plot_id  using "${Temp}\\${temppath}\\Respondent_characteristics1.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\Respondent_characteristics1_ID.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\Resp_characteristics2.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\irrigated.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\erosion_protection.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\tractor.dta", keep(master match) nogen
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen	
merge m:1 hhid  using "${Temp}\\${temppath}\\livestock.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\harvest_interview_month.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\planting_interview_month.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\ag_asset_index.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\aez.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\dist_popcenter.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\elevation.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\twi.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\soil.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MLI\\geocoords_id.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\plot_slope.dta", keep(master match) nogen

foreach var in  x  {
capture drop `var'
}

// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
foreach var in  n_nitrogen_kg n_NPK_kg n_DAP_kg n_UREA_kg n_other_kg n_inorganic_fertilizer_value UREA_kg DAP_kg NPK_kg other_kg _merge  harvest_sold_kg  n_harvest_kg n_harvest_value n_seed_value n_seed_kg manager_id respondent_id ea_id {
capture drop `var'
}  
order hh_id_merge hh_id_obs plot_id_obs plot_id_merge

define_labels

save "${Final}\\MLI_FINAL_plotw`wave'.dta", replace
}


**********************************************************
**** D) Create household datasets
**********************************************************


forvalues wave = 1/2 {
global temppath: word `wave' of $paths

use "${Temp}\\${temppath}\\hh_frame.dta", clear
gen wave = `wave'
merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 ea_id using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MLI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_primary_education.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_electricity_access.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_dependency_ratio.dta", keep(master match) nogen
if `wave'==1 {
merge 1:1 hhid using "${Temp}\\${temppath}\\cons_quint.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\totcons.dta", keep(master match) nogen			
}
merge 1:1 hhid using "${Temp}\\${temppath}\\shock.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\size.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\nfe.dta", keep(master match) nogen
if `wave'==1 {
merge 1:1 hhid  using "${Temp}\\${temppath}\\HDDS.dta", keep(master match) nogen
}
merge m:1 hhid using "${Temp}\\${temppath}\\nb_fallow_plots.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\nb_plots.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\popdensity.dta", keep(master match) nogen

// harmonise IDS
gen hh_id_merge = hhid
merge m:1 hh_id_merge wave using "${Temp}\\MLI\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\MLI\\ea_id_obs.dta", keep(master match) nogen
foreach var in ea_id {
capture drop `var'
} 
define_labels
order hh_id_merge hh_id_obs 
save "${Final}\\MLI_FINAL_hhw`wave'.dta", replace
}

**********************************************************
**** E) Create individual level datasets
**********************************************************


forvalues wave = 1/2 {
global temppath: word `wave' of $paths

use "${Temp}\\${temppath}\\indiv_frame.dta", clear
merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 ea_id  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MLI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 hhid ID using "${Temp}\\${temppath}\\indiv_chars.dta", keep(master match) nogen
if `wave'>2 { // missing
merge 1:1 hhid ID using "${Temp}\\${temppath}\\wasting.dta", keep(master match) nogen
}
merge 1:1 hhid ID using "${Temp}\\${temppath}\\labor.dta", keep(master match) nogen
merge 1:1 hhid ID using "${Temp}\\${temppath}\\educ_indiv.dta", keep(master match) nogen

gen wave = `wave'
define_labels

gen hh_id_merge = hhid
gen indiv_id_merge = ID
merge m:1 hh_id_merge wave using "${Temp}\\MLI\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\MLI\\Frame_indiv.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\MLI\\ea_id_obs.dta", keep(master match) nogen
foreach var in s01q04b s1q04b ea_id {
capture drop `var'
} 
order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
save "${Final}\\MLI_FINAL_indivw`wave'.dta", replace
}


**********************************************************
**** F) Append all
**********************************************************

use "${Final}\\MLI_FINAL_plotcrop1.dta",  clear
append using "${Final}\\MLI_FINAL_plotcrop2.dta",
bys hh_id_obs(ea_id_obs): assert ea_id_obs == ea_id_obs[_n]
bys hh_id_obs(ea_id_obs): assert strataid == strataid[_n]
save "${Final}\\MLI_FINAL_plotcrop.dta", replace

use "${Final}\\MLI_FINAL_plotw1.dta",  clear
append using "${Final}\\MLI_FINAL_plotw2.dta",
bys hh_id_obs(ea_id_obs): assert ea_id_obs == ea_id_obs[_n]
bys hh_id_obs(ea_id_obs): assert strataid == strataid[_n]
save "${Final}\\MLI_FINAL_plot.dta", replace

use "${Final}\\MLI_FINAL_hhw1.dta",  clear
append using "${Final}\\MLI_FINAL_hhw2.dta",
bys hh_id_obs(ea_id_obs): assert ea_id_obs == ea_id_obs[_n]
bys hh_id_obs(ea_id_obs): assert strataid == strataid[_n]
save "${Final}\\MLI_FINAL_hh.dta", replace

use "${Final}\\MLI_FINAL_indivw1.dta",  clear
append using "${Final}\\MLI_FINAL_indivw2.dta",
bys hh_id_obs(ea_id_obs): assert ea_id_obs == ea_id_obs[_n]
bys hh_id_obs(ea_id_obs): assert strataid == strataid[_n]
save "${Final}\\MLI_FINAL_indiv.dta", replace


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

wbopendata, language(en - English) country(MLI) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2014
replace wave = 2 if year == 2017
drop if wave==. 

merge 1:m wave using "${Final}\\MLI_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\MLI_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\MLI_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\MLI_FINAL_plotcrop.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\MLI_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\MLI_FINAL_hh.dta", replace

