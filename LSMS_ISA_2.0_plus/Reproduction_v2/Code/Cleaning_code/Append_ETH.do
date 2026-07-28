/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Append all Ethiopia code						          *
 * Date: January 2023                                                            *
 * -------------------------------------------------------------------------------*
*/


global paths "ETH\ESS11 ETH\ESS13 ETH\ESS15 ETH\ESS18 ETH\ESS21"

global hh "household_id household_id2 household_id2 household_id household_id"

global indiv "individual_id individual_id2 individual_id2 ID ID"



**********************************************************
**** A) Harmonize IDs
**********************************************************
use "${Temp}\\ETH\ESS11\\hh_frame.dta", clear
gen wave = 1
forvalues wave=2/5{
global temppath: word `wave' of $paths
append using "${Temp}\\${temppath}\\hh_frame.dta", gen(append)
replace wave = `wave' if append==1
drop append
}
	
	// Create trackable unit
	gen hh_id_obs_temp = household_id2 
	replace hh_id_obs_temp = household_id if wave >3
	bys household_id (household_id2): assert hh_id_obs_temp == hh_id_obs_temp[_N] |  missing(hh_id_obs_temp) | inlist(wave, 2 , 3 ,4, 5) // check
	bys household_id (household_id2): replace hh_id_obs_temp = hh_id_obs_temp[_N] if missing(hh_id_obs_temp) & wave==1
	replace hh_id_obs_temp = household_id if missing(hh_id_obs_temp) & wave==1 // a few households have not been tracked after wave 1
	egen hh_id_obs = group(hh_id_obs_temp)
	replace hh_id_obs = hh_id_obs + 1000000 
	
	// Create mergeable unit
	gen hh_id_merge = household_id if wave ==1 | wave >3
	replace hh_id_merge = household_id2 if wave==2 | wave ==3
	
	// unify weights
	replace pw = pw2 if wave==2
	forvalues v=3/5 {
	replace pw = pw_w`v'	if wave ==`v'
	}
	
keep hh_id_obs hh_id_merge  household_id2 household_id wave pw
save "${Temp}\\ETH\\Frame_hhIDs.dta", replace

use "${Temp}\\ETH\ESS11\\plot_crop_frame.dta", clear
gen wave = 1
gen hh_id_merge = household_id
forvalues wave=2/5{
global temppath: word `wave' of $paths
local hhd: word `wave' of $hh
append using "${Temp}\\${temppath}\\plot_crop_frame.dta", gen(append)
replace wave = `wave' if append==1
replace hh_id_merge = `hhd' if append==1
drop append
}

	// cannot track plots
	egen plot_id_temp = concat(wave plot_id ), punct("-")
	egen plot_id_obs = group(plot_id_temp)
	replace plot_id_obs = plot_id_obs + 1000000 
	gen plot_id_merge=  plot_id 
		
	// can track parcels
	gen parcel_id_merge=  parcel_id 
	merge m:1 wave hh_id_merge using "${Temp}\\ETH\\Frame_hhIDs.dta", keep(master match)
	tostring hh_id_obs, gen(hh_id_obs_str)
	replace hh_id_obs_str = "" if hh_id_obs_str=="."
	replace parcel_id = "" if parcel_id=="-." | hh_id_obs_str==""
	replace parcel_id = reverse(subinstr(reverse(parcel_id),substr(reverse(parcel_id), strpos(reverse(parcel_id), "-" ) + 1, .), reverse(hh_id_obs_str),1)) if parcel_id!=""
	gen parcel_id_temp = parcel_id
	egen parcel_id_obs = group(parcel_id_temp) if parcel_id_temp!=""
	replace parcel_id_obs = parcel_id_obs + 1000000 
	
	// change parcel_id to merge later
	gen parcel_id_num = substr(parcel_id, strpos(parcel_id, "-")+1, .)
	rename  parcel_id parcel_id_temp2
	destring parcel_id_num, gen(parcel_id)

keep plot_id plot_id_obs plot_id_merge  household_id2 household_id wave crop_code crop_name parcel_id_merge parcel_id_obs parcel_id
duplicates drop
save "${Temp}\\ETH\\Frame_plotcrop.dta", replace

use "${Temp}\\ETH\ESS11\\indiv_frame.dta", clear
rename individual_id individual_id_w1
gen wave = 1
forvalues wave=2/5{
global temppath: word `wave' of $paths
append using "${Temp}\\${temppath}\\indiv_frame.dta", gen(append)
replace wave = `wave' if append==1
drop append
}
	// Create trackable unit
	gen indiv_id_obs_temp = individual_id2 if wave>1 & wave<4
	replace indiv_id_obs_temp = ID if wave>3
	bys individual_id_w1 (individual_id2): assert indiv_id_obs_temp == indiv_id_obs_temp[_N] |  missing(indiv_id_obs_temp) | inlist(wave, 2 , 3 ,4, 5) // check
	bys individual_id_w1 (individual_id2): replace indiv_id_obs_temp = indiv_id_obs_temp[_N] if missing(indiv_id_obs_temp) & wave==1
	replace indiv_id_obs_temp = individual_id_w1 if wave == 1 & indiv_id_obs_temp==""
	egen indiv_id_obs = group(indiv_id_obs_temp)
	replace indiv_id_obs = indiv_id_obs + 1000000 
	
	// Create mergeable unit
	tostring individual_id, replace 
	gen indiv_id_merge = individual_id_w1 if wave ==1 | wave >3
	replace indiv_id_merge = individual_id2 if wave==2 | wave ==3
	replace indiv_id_merge = ID if wave>3

replace individual_id = individual_id_w1 if wave==1 
keep indiv_id_merge indiv_id_obs  household_id2 household_id wave  individual_id individual_id2
duplicates drop
save "${Temp}\\ETH\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
forvalues wave = 1/5 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\Resp_characteristics1.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep plot_id  respondent_id_obs respondent_id_merge 
save "${Temp}\\${temppath}\\Resp_characteristics1_ID.dta", replace
restore
}
rename respondent_id manager_id
forvalues wave = 1/5 {
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

use "${Temp}\\ETH\ESS11\\Coords.dta", clear
append using "${Temp}\\ETH\ESS13\\Coords.dta", 
append using "${Temp}\\ETH\ESS15\\Coords.dta", 
append using "${Temp}\\ETH\ESS18\\Coords.dta", 
append using "${Temp}\\ETH\ESS21\\Coords.dta", 

keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 1000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\ETH\\geocoords_id.dta", replace


use "${Temp}\\ETH\ESS11\\ea_id.dta", clear
gen hh_id_merge = household_id
gen wave =1
append using "${Temp}\\ETH\ESS13\\ea_id.dta", 
replace hh_id_merge = household_id2 if hh_id_merge==""
replace  wave =2 if wave==.
append using "${Temp}\\ETH\ESS15\\ea_id.dta", 
replace hh_id_merge = household_id2 if hh_id_merge==""
replace  wave =3 if wave==.
append using "${Temp}\\ETH\ESS18\\ea_id.dta", 
replace hh_id_merge = household_id if hh_id_merge==""
replace  wave =4 if wave==.
append using "${Temp}\\ETH\ESS21\\ea_id.dta", 
replace hh_id_merge = household_id if hh_id_merge==""
replace  wave =5 if wave==.
merge m:1 hh_id_merge wave using "${Temp}\\ETH\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 1000000
bys hh_id_obs: assert ea_id_obs == ea_id_obs[1]

rename ea_id ea_id_merge

keep hh_id_merge ea_id_obs  ea_id_merge
duplicates drop
isid hh_id_merge
save "${Temp}\\ETH\\ea_id_obs.dta", replace



**********************************************************
**** B) Create plot-crop datasets
**********************************************************


forvalues wave = 1/5 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh


use "${Temp}\\${temppath}\\plot_crop_frame.dta", clear

duplicates drop
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin_1_name.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\ETH\\geocoords_id.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_kg.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_value.dta", keep(master match) nogen
drop main_crop // added later
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_end_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\planting_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_kg_merge.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_value.dta" , keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\improved.dta" , keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\used_pesticides.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\crop_shock.dta", keep(master match) nogen

gen wave = `wave'
drop parcel_id
merge 1:1 plot_id crop_code wave using "${Temp}\\ETH\\Frame_plotcrop.dta", keep(master match) nogen keepusing(parcel_id )

// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge using "${Temp}\\ETH\\ea_id_obs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\ETH\\Frame_hhIDs.dta", keep(master match) nogen
merge 1:1 plot_id crop_code wave using "${Temp}\\ETH\\Frame_plotcrop.dta", keep(master match) nogen
preserve
define_labels
drop plot_id household_id  crop_code  
save "${Final}\\ETH_FINAL_plotcrop`wave'.dta", replace
restore


**********************************************************
**** C) Create plot datasets
**********************************************************


collapse (sum) harvest_kg harvest_value seed_kg  seed_value (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value n_seed_kg = seed_kg  n_seed_value =seed_value (max) improved used_pesticides *_shock , by(plot_id  ea_id_obs ea_id_merge pw strataid admin_1 admin_1_name admin_2 admin_3  parcel_id parcel_id_merge parcel_id_obs holder_id wave plot_id_obs plot_id_merge hh_id_obs hh_id_merge )

foreach var in  harvest_kg harvest_value seed_kg  seed_value {
	replace `var' = . if n_`var'==0
}


global hhd: word `wave' of $hh

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
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Resp_characteristics1.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Resp_characteristics1_ID.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Resp_characteristics2.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\irrigated.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\erosion_protection.dta", keep(master match) nogen
if `wave'>1{ 
merge m:1 plot_id  using "${Temp}\\${temppath}\\tractor.dta", keep(master match) nogen
}
merge m:1 holder_id parcel_id  using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen
merge m:1 holder_id parcel_id  using "${Temp}\\${temppath}\\plot_certificate.dta", keep(master match) nogen
merge m:1 holder_id  using "${Temp}\\${temppath}\\livestock.dta", keep(master match) nogen
merge m:1 holder_id  using "${Temp}\\${temppath}\\harvest_interview_month.dta", keep(master match) nogen
merge m:1 holder_id  using "${Temp}\\${temppath}\\planting_interview_month.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\ag_asset_index.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\aez.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\dist_popcenter.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\dist_market.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\elevation.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\twi.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\soil.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\ETH\\geocoords_id.dta", keep(master match) nogen

if `wave'<5{ 
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_dist_household.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_slope.dta", keep(master match) nogen
}

foreach var in  DAP_kg UREA_kg NPS_kg saq14 pw_w5 saq01 saq02 saq03 saq04 saq05 saq06 saq07 saq08 saq09 saq10 saq11 saq12 saq13 saq15 saq16 saq17 saq18 saq19__Latitude saq19__Longitude saq19__Accuracy saq19__Altitude saq19__Timestamp InterviewDate saq21 _merge   n_harvest_kg n_harvest_value n_seed_value n_seed_kg manager_id respondent_id  {
capture drop `var'
}

// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
drop plot_id household_id holder_id parcel_id
order hh_id_merge hh_id_obs plot_id_obs plot_id_merge

define_labels

save "${Final}\\ETH_FINAL_plotw`wave'.dta", replace
}

**********************************************************
**** D) Create household datasets
**********************************************************


forvalues wave = 1/5 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh

use "${Temp}\\${temppath}\\hh_frame.dta", clear

merge 1:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin_1_name.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\ETH\\geocoords_id.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_primary_education.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_electricity_access.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_dependency_ratio.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\cons_quint.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\totcons.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_shock.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_size.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\nonfarm_enterprise.dta", keep(master match) nogen
merge 1:1 $hhd  using "${Temp}\\${temppath}\\HDDS.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nb_fallow_plots.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nb_plots.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", keep(master match) 

if `wave'>1 {
merge m:1 $hhd  using "${Temp}\\${temppath}\\popdensity.dta", keep(master match) nogen	
}


gen wave = `wave'

define_labels


// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge using "${Temp}\\ETH\\ea_id_obs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\ETH\\Frame_hhIDs.dta", keep(master match) nogen
foreach var in plot_id household_id  crop_code parcel_id field_id  _merge holder_id crop_name household_id2 pw2 pw_w3 pw_w4 pw_w5  {
capture drop `var'
} 
order hh_id_merge hh_id_obs 
save "${Final}\\ETH_FINAL_hhw`wave'.dta", replace
}

**********************************************************
**** E) Create individual level datasets
**********************************************************


forvalues wave = 1/5 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh
global ind: word `wave' of $indiv

use "${Temp}\\${temppath}\\indiv_frame.dta", clear
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin_1_name.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\ETH\\geocoords_id.dta", keep(master match) nogen
merge 1:1 $hhd $ind using "${Temp}\\${temppath}\\indiv_chars.dta", keep(master match) nogen
merge 1:1 $hhd $ind using "${Temp}\\${temppath}\\wasting.dta", keep(master match) nogen
merge 1:1 $hhd $ind using "${Temp}\\${temppath}\\labor.dta", keep(master match) nogen
merge 1:1 $hhd $ind using "${Temp}\\${temppath}\\educ_indiv.dta", keep(master match) nogen

gen wave = `wave'
define_labels
gen hh_id_merge = $hhd
gen indiv_id_merge = $ind
foreach var in individual_id individual_id2 pw2 pw_w3 household_id2 household_id pw_w4 pw_w5 ID  {
capture drop `var'
} 
merge m:1 hh_id_merge using "${Temp}\\ETH\\ea_id_obs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\ETH\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\ETH\\Frame_indiv.dta", keep(master match) nogen

order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
save "${Final}\\ETH_FINAL_indivw`wave'.dta", replace
}


**********************************************************
**** F) Append all
**********************************************************


use "${Final}\\ETH_FINAL_plotcrop1.dta",  clear
forvalues wave=2/5{
append using "${Final}\\ETH_FINAL_plotcrop`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
bys ea_id_merge (strataid): replace strataid = strataid[1] if strataid==.
foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
}
save "${Final}\\ETH_FINAL_plotcrop.dta", replace


use "${Final}\\ETH_FINAL_plotw1.dta",  clear
forvalues wave=2/5{
append using "${Final}\\ETH_FINAL_plotw`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
bys ea_id_merge (strataid): replace strataid = strataid[1] if strataid==.
foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
}
save "${Final}\ETH_FINAL_plot.dta", replace


use "${Final}\\ETH_FINAL_hhw1.dta",  clear
forvalues wave=2/5{
append using "${Final}\\ETH_FINAL_hhw`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
bys ea_id_merge (strataid): replace strataid = strataid[1] if strataid==.
foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
}
save "${Final}\\ETH_FINAL_hh.dta", replace

use "${Final}\\ETH_FINAL_indivw1.dta",  clear
forvalues wave=2/5{
append using "${Final}\\ETH_FINAL_indivw`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
bys ea_id_merge (strataid): replace strataid = strataid[1] if strataid==.
foreach admin in 2 3 {
rename admin_`admin' admin_`admin'_str
replace admin_`admin'_str = subinstr(admin_`admin'_str, "-", "",.) 
destring admin_`admin'_str, gen(admin_`admin')
}
save "${Final}\\ETH_FINAL_indiv.dta", replace


**********************************************************
**** G) Create variables for USD values
**********************************************************

wbopendata, language(en - English) country(USA) topics() indicator(FP.CPI.TOTL) clear long
keep year fp_cpi_totl
gen fp_cpi_totl_2020_line = fp_cpi_totl if year==2020 // set base to 2020
egen fp_cpi_totl_2020 = max(fp_cpi_totl_2020_line)
gen deflator = fp_cpi_totl/fp_cpi_totl_2020
keep deflator year
tempfile deflator
save `deflator', replace

wbopendata, language(en - English) country(ETH) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2011
replace wave = 2 if year == 2013
replace wave = 3 if year == 2015
replace wave = 4 if year == 2018
replace wave = 5 if year == 2021
drop if wave==. 

merge 1:m wave using "${Final}\\ETH_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\ETH_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 


merge 1:m wave using "${Final}\\ETH_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\ETH_FINAL_plotcrop.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 


merge 1:m wave using "${Final}\\ETH_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\ETH_FINAL_hh.dta", replace


