/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for MWI3          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Malawi
global wave  IHPS 16
global cover  HH_MOD_A_FILT_16.dta
global household_roster hh_mod_b_16.dta
global indiv_roster  hh_mod_c_16.dta
global health  hh_mod_v_16.dta
global lab_roster  hh_mod_e_16.dta
global shocks hh_mod_u_16.dta
global housing  hh_mod_f_16.dta
global assets hh_mod_l_16.dta
global nfe hh_mod_n1_16.dta
global ag_meta ag_meta_16.dta
global cover_pc_pp  ag_mod_a_16.dta
global planting_rwdta  ag_mod_b_16.dta
global plot_roster_2  ag_mod_b2_16.dta
global plot_roster  ag_mod_c_16.dta
global plot_inputs ag_mod_d_16.dta
global seeds ag_mod_h_16.dta
global ferts ag_mod_f_16.dta
global items hh_mod_m_16.dta
global harvest_rwdta  ag_mod_g_16.dta
global perennial_roster_garden  ag_mod_o1_16.dta
global perennial_roster  ag_mod_o2_16.dta
global perennial  ag_mod_p_16.dta
global perennial_sale  ag_mod_q_16.dta
global harvest_sale_rwdta  ag_mod_i_16.dta
global geovars_hh HouseholdGeovariablesIHPSY3.dta
global geovars_plot PlotGeovariablesIHPSY3_16.dta
global livestock ag_mod_r1_16.dta
global HDDS  hh_mod_g1_16.dta

global conversions_land ET_local_area_unit_conversion
global conversions_crop ihs_seasonalcropconversion_factor_2020
global conversions_tree ihs_treeconversion_factor_2020


global temppath MWI\IHPS16


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen parcel_id = concat(y3_hhid gardenid), punct("-")
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
keep y3_hhid plot_id crop_code parcel_id
duplicates drop
drop if crop_code==.
rename crop_code crop_code2
decode crop_code2, generate(crop_name2) 
rename crop_code2 crop_code
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
decode crop_code, generate(crop_name) 

egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
egen parcel_id = concat(y3_hhid gardenid ), punct("-")

merge m:1 y3_hhid plot_id crop_code using `perennial', 
replace crop_name = crop_name2 if _merge==2

keep y3_hhid plot_id crop_name crop_code   parcel_id

duplicates drop
duplicates report  y3_hhid plot_id crop_code crop_name parcel_id

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear


keep y3_hhid ea_id hh_wgt  y2_hhid dist_to_IHPSlocation
duplicates report y3_hhid 

save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
keep y3_hhid PID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear 

keep y3_hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use  "${Input}\\${country}\\IHPS 13\\HH_MOD_A_FILT_13.dta", clear
keep ea_id stratum
duplicates drop
merge 1:m ea_id using "${Input}\\${country}\\${wave}\\${cover}", keep(match using) nogen
rename stratum strataid
keep y3_hhid strataid
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace


// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename region admin_1
keep y3_hhid admin_1
decode admin_1, gen(admin_1_name)
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace


// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename district admin_2
keep y3_hhid admin_2
decode admin_2, gen(admin_2_name)
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen TA_temp= string(ta_code) 
replace TA_temp="0"+string(ta_code) if length(string(ta_code))==1
egen admin_3 = concat(district TA_temp)
destring admin_3, replace
replace admin_3= . if inlist(.,district, ta_code )
keep y3_hhid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
recode reside (1 = 1 "Yes") (2 = 0 "No"), gen(urban) label(urban)
keep y3_hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename panelweight_2016 pw
keep pw y3_hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
drop if crop_code==.
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
collapse (min) ag_p04, by(y3_hhid plot_id crop_code)
duplicates drop
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

merge m:1 y3_hhid plot_id crop_code using `perennial', 

gen month = ag_g05a
replace month = 12 if _merge==2
format month %tm 

gen year = ag_g05b 
replace year = ag_p04 if _merge==2
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(y3_hhid crop_code plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if crop_code==.
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
sort y3_hhid plot_id crop_code ag_p06d (ag_p06c)

collapse (first) ag_p06c ag_p06d, by(y3_hhid plot_id crop_code)
duplicates drop
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

merge m:1 y3_hhid plot_id crop_code using `perennial', 

gen month = ag_g12b
replace month = ag_p06c if _merge == 2
format month %tm

gen year = 2014 if ag_g05b==2014 & ag_g05a<=ag_g12b // if planting in 2015 and planting month lower than harvest month 
replace year= 2015 if ag_g05b==2014 & ag_g05a>ag_g12b
replace year= 2015 if ag_g05b==2015 & ag_g05a<=ag_g12b // if planting in 2015 and planting month lower than harvest month 
replace year= 2016 if ag_g05b==2015 & ag_g05a>ag_g12b
replace year=2016 if ag_g05b==2016 & ag_g05a<=ag_g12b 
replace year = ag_p06d if _merge == 2
format year %ty
gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
drop month year

collapse (max) harvest_end_month , by(y3_hhid crop_code plot_id)
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace


// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen month_harvest = substr(interviewdate_v2, 6, 2)
replace month_harvest="." if month_harvest=="##"
destring month_harvest, replace
format month_harvest %tm 
gen year_harvest = substr(interviewdate_v2, 1, 4)
replace year_harvest="." if year_harvest=="##N/"
destring year_harvest, replace
format year_harvest %ty  
gen harvest_interview_month = ym( year_harvest, month_harvest)
format harvest_interview_month %tmCCYYMon
keep y3_hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen month_planting = substr(interviewdate_v1, 6, 2)
destring month_planting, replace
format month_planting %tm 
gen year_planting = substr(interviewdate_v1, 1, 4)
destring year_planting, replace
format year_planting %ty 
gen planting_interview_month = ym( year, month)
format planting_interview_month %tmCCYYMon
keep y3_hhid planting_interview_month
duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${perennial}", clear
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
drop if crop_code==.
recode ag_p07 (1 =1) ( 2 = 0) , gen(crop_shock_per)
collapse (sum) ag_p09a (count) n = ag_p09a (max) crop_shock_per , by(y3_hhid plot_id crop_code ag_p09b region)
replace ag_p09a = . if n ==0 
tostring ag_p09b, gen(unit_code)
merge m:1 region crop_code unit_code  using "${Input}\\${country}\\IHPS 19\\${conversions_tree}", keep(master match)  nogen
ge harvest_per = ag_p09a * conversion
replace harvest_per = ag_p09a if ag_p09b==1
replace harvest_per = ag_p09a * 50 if ag_p09b==2
replace harvest_per = ag_p09a * 90 if ag_p09b==3
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops

collapse (sum) harvest_per (count) n = harvest_per (max) crop_shock_per , by(y3_hhid plot_id crop_code )
replace harvest_per = . if n ==0 
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
rename ag_g13c condition
tostring ag_g13b, gen(unit_code)
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

merge m:1 region crop_code unit_code condition using "${Input}\\${country}\\IHPS 19\\${conversions_crop}", keep(master match)  
gen harvest_kg= ag_g13a * conversion 
replace harvest_kg= ag_g13a if unit_code=="1" & mi(harvest_kg) 
bys region unit_code condition: egen median_conversion_allcrop= median(conversion) // unmatched crop codes
replace harvest_kg = ag_g13a * median_conversion_allcrop if mi(harvest_kg) & !mi(crop_code)

bys crop_code unit_code crop_code: egen median_conversion_allregion= median(conversion) // unmatched region
replace harvest_kg = ag_g13a * median_conversion_allregion if mi(harvest_kg) & !mi(region)
replace harvest_kg=0 if ag_g13a==0 & ag_g09a==0 // 140 had no harvest

drop conversion unit_code unit_name collectionround condition
rename ag_g09c condition  
tostring ag_g09b, gen(unit_code)
count if inlist(., region, crop_code, condition ) | unit_code=="." //  4315 will be unmatched for sure
merge m:1 region crop_code unit_code condition using "${Input}\\${country}\\IHPS 19\\${conversions_crop}", keep(master match) nogen 

gen PPharvest_kg= ag_g09a * conversion
replace PPharvest_kg = ag_g09a if  unit_code=="1" & mi(PPharvest_kg)
replace harvest_kg =  PPharvest_kg if mi(harvest_kg) & !mi(PPharvest_kg) & ag_g07==1  


drop _merge
merge m:1 y3_hhid plot_id crop_code using `perennial',

replace harvest_kg = harvest_per if _merge==2 

recode ag_g10 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = crop_shock_per if _merge ==2

replace harvest_kg = . if harvest_kg==0 & crop_shock!=1

merge m:1 y3_hhid using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg, by(plot_id crop_code ea_id y3_hhid admin_1 admin_2 admin_3 )
replace harvest_kg = . if n_harvest_kg==0

save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
gen pct_area_harvested = .
replace pct_area_harvested= 100 if ag_g10==2
keep y3_hhid plot_id crop_code pct_area_harvested
duplicates drop
save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

drop if crop_code==.
recode ag_p07 (1 =1) ( 2 = 0) , gen(crop_shock_per)
recode ag_p08a (1 =1) ( 2/12 = 0) , gen(drought_shock_per1)
recode ag_p08b (1 =1) ( 2/12 = 0) , gen(drought_shock_per2)
recode ag_p08a (4 5 =1) (1 2 3 6/12 = 0) , gen(pest_shock_per1)
recode ag_p08b (4 5 =1) ( 1 2 3 6/12 = 0) , gen(pest_shock_per2)
recode ag_p08a (2 =1) (1 3/12 = 0) , gen(rain_shock_per1)
recode ag_p08b (2 =1) (1 3/12 = 0) , gen(rain_shock_per2)
recode ag_p08a (12 =1) (1/11 = 0) , gen(flood_shock_per1)
recode ag_p08b (12 =1) (1/11 = 0) , gen(flood_shock_per2)
egen drought_shock_per = rowmax(drought_shock_per*)
egen pest_shock_per = rowmax(pest_shock_per*)
egen rain_shock_per = rowmax(rain_shock_per*)
egen flood_shock_per = rowmax(flood_shock_per*)

collapse (max) crop_shock_per rain_shock_per pest_shock_per drought_shock_per flood_shock_per , by(y3_hhid plot_id crop_code  )
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

merge m:1 y3_hhid plot_id crop_code using `perennial', 


recode ag_g10 (1 = 1 "Yes") (2 = 0 "No") (3 =.), gen(crop_shock) label(crop_shock)

recode ag_g11a (1 = 1 "Yes") (.=.) (else = 0 "No"), gen(drought_shock1) label(drought_shock) 
recode ag_g11b (1 = 1 "Yes") (.=.) (else = 0 "No"), gen(drought_shock2)
replace drought_shock1 = 0 if ag_g10==2
replace drought_shock2 = 0 if ag_g10==2
gen drought_shock= 1 if drought_shock1==1 | drought_shock2==1
replace drought_shock=0 if (drought_shock1==0 & drought_shock2==0 )
replace drought_shock=0 if (drought_shock1==0  & drought_shock2==. ) // second option not always used
replace drought_shock = drought_shock_per if _merge==2

recode ag_g11a (4 = 1 "Yes") (.=.) (else = 0 "No"), gen(pests_shock1) label(pests_shock) 
recode ag_g11b (4 = 1 "Yes") (.=.) (else = 0 "No"), gen(pests_shock2)
replace pests_shock1 = 0 if ag_g10==2
replace pests_shock2 = 0 if ag_g10==2
gen pests_shock= 1 if pests_shock1==1 | pests_shock2==1
replace pests_shock=0 if (pests_shock1==0 & pests_shock2==0 )
replace pests_shock=0 if (pests_shock1==0  & pests_shock2==. ) // second option not always used
replace pests_shock = pest_shock_per if _merge==2

recode ag_g11a (2 11 = 1 "Yes") (.=.) (else = 0 "No"), gen(rain_shock1) label(rain_shock) 
recode ag_g11b (2 11 = 1 "Yes") (.=.) (else = 0 "No"), gen(rain_shock2)
replace rain_shock1 = 0 if ag_g10==2
replace rain_shock2 = 0 if ag_g10==2
gen rain_shock= 1 if rain_shock1==1 | rain_shock2==1
replace rain_shock=0 if (rain_shock1==0 & rain_shock2==0 )
replace rain_shock=0 if (rain_shock1==0  & rain_shock2==. ) // second option not always used
replace rain_shock = rain_shock_per if _merge==2

recode ag_g11a (12 = 1 "Yes") (.=.) (else = 0 "No"), gen(flood_shock1) label(flood_shock) 
recode ag_g11b (12 = 1 "Yes") (.=.) (else = 0 "No"), gen(flood_shock2)
replace flood_shock1 = 0 if ag_g10==2
replace flood_shock1 = 1 if ag_g11a==10 & ag_g11oth=="FLOODING"
replace flood_shock2 = 0 if ag_g10==2
replace flood_shock2 = 1 if ag_g11b==10 & ag_g11oth=="FLOODING"
gen flood_shock= 1 if flood_shock1==1 | flood_shock2==1
replace flood_shock=0 if (flood_shock1==0 & flood_shock2==0 )
replace flood_shock=0 if (flood_shock1==0  & flood_shock2==. ) // second option not always used
replace flood_shock = flood_shock_per if _merge==2

keep y3_hhid plot_id crop_shock pests_shock rain_shock drought_shock  crop_code flood_shock
duplicates drop
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${perennial_sale}", clear
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
drop if crop_code==.
drop if ag_q01==2
tostring ag_q02b, gen(unit_code)
merge m:1 region crop_code unit_code  using "${Input}\\${country}\\IHPS 19\\${conversions_tree}", keep(master match)  

gen harvest_sold_kg_per = ag_q02a * conversion
replace harvest_sold_kg_per = ag_q02a if ag_q02b==1
replace harvest_sold_kg_per = ag_q02a * 50 if ag_q02b==2
replace harvest_sold_kg_per = ag_q02a * 90 if ag_q02b==3
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops

collapse (sum) harvest_sold_kg_per (count) n = harvest_sold_kg_per , by(y3_hhid crop_code )
replace harvest_sold_kg_per = . if n==0
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
rename ag_i02c condition
tostring ag_i02b, gen(unit_code)
merge m:1 region crop_code unit_code condition using "${Input}\\${country}\\IHPS 19\\${conversions_crop}", keep(master match) nogen 
gen harvest_sold_kg = ag_i02a * conversion 
replace harvest_sold_kg = ag_i02a if ag_i02b==1 
replace harvest_sold_kg= 0 if ag_i01==2
merge m:1 y3_hhid  crop_code using `perennial', 
replace harvest_sold_kg = harvest_sold_kg_per if _merge==2 
collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg=harvest_sold_kg , by(y3_hhid crop_code) 
replace harvest_sold_kg=. if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(y3_hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m y3_hhid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(y3_hhid _merge)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
replace share_kg_sold = 0 if harvest_kg==0
replace share_kg_sold = 0 if _merge==2
keep y3_hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace

// harvest sold value
use "${Input}\\${country}\\${wave}\\${perennial_sale}", clear
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
gen harvest_sold_value_per = ag_q03
collapse (sum) harvest_sold_value_per (count) n = harvest_sold_value_per , by(y3_hhid crop_code )
replace harvest_sold_value_per = . if n==0
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
gen harvest_sold_value = ag_i03
merge m:1 y3_hhid  crop_code using `perennial', 
replace harvest_sold_value = harvest_sold_value_per if _merge==2 
collapse (sum) harvest_sold_value (count) n_harvest_sold_value=harvest_sold_value, by(y3_hhid crop_code) 
replace harvest_sold_value=. if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${perennial_sale}", clear
keep y3_hhid crop_code 
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
duplicates drop 
tempfile perennial
save `perennial', replace
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
keep y3_hhid  crop_code 
merge m:1 y3_hhid  crop_code using `perennial', 
duplicates drop
drop if crop_code==.


valuation_median_crops_noea_sort y3_hhid  crop_code  

main_crop_def crop_code


keep y3_hhid plot_id  harvest_value crop_code main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace

// intercropped
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

recode ag_g01 (1 =0 "No") (.=.)  (2/5 = 1 "Yes"), gen(intercropped) label(intercropped)
keep crop_code plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace


// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

drop if crop_code==.
replace crop_code = crop_code + 1000 // to distinguish with seasonal crops
keep y3_hhid crop_code plot_id
duplicates drop 
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
merge m:1 y3_hhid plot_id crop_code using `perennial', 

merge m:1 crop_code plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)


gen codesmain_crop = main_crop
gen codescrop_code = crop_code
foreach c in main_crop crop_code {
lab val `c' crop_complete
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2

replace `c' = subinstr(`c', ":", "", 1)
replace `c'="MAIZE" if  inlist(`c',"MAIZE COMPOSITE/OPV", "MAIZE HYBRID", "MAIZE HYBRID RECYCLED", "MAIZE LOCAL")
replace `c'="MILLET" if  inlist(`c',"PEARL MILLET(MCHEWERE)", "FINGER MILLET(MAWERE)", "MAIZE HYBRID RECYCLED", "MAIZE LOCAL")
replace `c' = "GROUNDNUT" if inlist(`c', "GROUND BEAN(NZAMA", "GROUNDNUT CG7", "GROUNDNUT CHALIMBANA", "GROUNDNUT JL24", "GROUNDNUT MANIPINTA" , "GROUNDNUT MAWANGA", "OTHER GROUNDNUT(SPECIFY)", "OTHER GROUNDNUT (SPECIFY)" )
replace `c' = "GROUNDNUT" if inlist(`c', "GROUNDNUT MANI-PINTAR", "GROUNDNUT OTHER SPECIFY")
replace `c' = "TOBACCO" if inlist(`c', "TOBACCO BURLEY", "TOBACCO FLUE CURED", "TOBACCO NNDF", "TOBACCO ORIENTAL", "TOBACCOSDF", "OTHER TOBACCO (SPECIFY)" )
replace `c' = "RICE" if inlist(`c', "RISE FAYA", "RISE IET4094 (SENGA)", "RISE KILOMBERO", "RISE LOCAL", "RISE MTUPATUPA", "RISE PUSSA", "RISE TCG10", "RISE WAMBONE", "OTHER RICE(SPECIFY)" )
replace `c' = "RICE" if inlist(`c', "RICE FAYA", "RICE IET4094 (SENGA)", "RICE KILOMBERO", "RICE LOCAL", "RICE MTUPATUPA", "RICE PUSSA", "RICE TCG10", "RICE WAMBONE", "OTHER RICE (SPECIFY)" )
replace `c' = "POTATO" if `c' =="IRISH [MALAWI] POTATO"
replace `c' = "SORGHUM" if `c' =="SORGHUM."
replace `c' = "TOMATOES" if `c' =="TOMATO"
replace `c' = "SUGARCANE" if `c' =="SUGAR CANE"
replace `c' = "GROUNDNUTS" if `c' =="GROUNDNUT"

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"PIGEONPEA(NANDOLO", "PIGEONPEA(NANDOLO)", "GROUNDNUTS",  "SOYABEANS", "SOYABEAN", "BEANS", "PEA", "PEAS", "GROUND BEAN(NZAMA)")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"POTATO", "SWEET POTATO")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE" | `c'=="RICE PUSA"
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "MAIZE" if `c'=="MAIZE"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "MILLET" if `c'=="MILLET"
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "" if `c'=="."
replace `c'2 = "PERENNIAL/FRUIT" if codes`c'>=1000 & !mi(codes`c')
drop `c'
rename `c'2 `c'
}
tab crop_code, gen(contains_crop_)



foreach n in  9 8 7 6 5 4  {
local i = `n' + 2
rename contains_crop_`n' contains_crop_`i'
}


foreach n in  3 2 1 {
local i = `n' + 1
rename contains_crop_`n' contains_crop_`i'
}

gen contains_crop_1=0
gen contains_crop_5 =0


//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum) share_crop* (max) contains_crop_* , by(plot_id main_crop maincrop_valueshare) 
save "${Temp}\\${temppath}\\main_crop.dta", replace


// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

recode ag_g03 (1 = 12.5)  (2 = 25) (3 = 50) (4 = 75) (5 = 87.5), gen(pct_area_planted)
replace pct_area_planted = 100 if ag_g02==1 | ag_g01==1

keep pct_area_planted plot_id crop_code
collapse (mean) pct_area_planted , by( crop_code plot_id)
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace


// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
merge m:1 y3_hhid gardenid plotid using "${Input}\\${country}\\${wave}\\${perennial_roster}"

egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

gen area_self_reported = ag_c04a * 0.404686 // most are in acres 
replace area_self_reported = ag_c04a if ag_c04b == 2
replace area_self_reported = ag_c04a * 0.0001 if ag_c04b == 3 // square meters
replace area_self_reported = ag_o04a * 0.404686 if ag_o04b == 1 & _merge==2
replace area_self_reported = ag_o04a  if ag_o04b == 2 & _merge==2
replace area_self_reported = ag_o04a * 0.0001 if ag_o04b == 3 & _merge==2


gen plot_area_GPS= ag_c04c * 0.404686 // acres to ha 
replace plot_area_GPS = ag_o04c if _merge==2


merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid y3_hhid plot_id
sort y3_hhid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
mi impute pmm plot_area_GPS area_self_reported i.admin_3, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys y3_hhid: egen farm_size = total(plot_area_GPS), missing

keep y3_hhid plot_id   plot_area_GPS  farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace


// improved 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode ag_g0f (2=1 "Yes") (1 = 0 "No"), gen(improved) label(improved)
keep plot_id crop_code improved
duplicates drop
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen

egen plot_id = concat(y3_hhid gardenid plotid), punct("-")

gen seed_gram = ag_g04a * 0.001 if ag_g04b==1
gen seed_kg2 = ag_g04a if ag_g04b==2
gen seed_2kg = ag_g04a * 2 if ag_g04b==3
gen seed_3kg = ag_g04a * 3 if ag_g04b==4
gen seed_37kg = ag_g04a * 3.7 if ag_g04b==5
gen seed_5kg = ag_g04a * 5 if ag_g04b==6
gen seed_10g = ag_g04a * 10 if ag_g04b==7
gen seed_50kg = ag_g04a * 50 if ag_g04b==8
gen seed_tina = ag_g04a * 0.25 if ag_g04b_oth=="TINA"

// ta (comparable to wave 1)
gen TA_temp= string(ta_code) 
replace TA_temp="0"+string(ta_code) if length(string(ta_code))==1
egen admin_3 = concat(district TA_temp)
destring admin_3, replace
replace admin_3= . if inlist(.,district, ta_code )
rename district admin_2
rename region admin_1

egen seed_kg = rowtotal(seed_*), missing
collapse  (sum) seed_kg (count) n_seed_kg = seed_kg , by(plot_id crop_code admin_1 admin_2 admin_3 )
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg.dta", replace
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace


// seed_kg_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
forvalues n= 1/2 {
gen seed_purchased`n'_gram = ag_h`n'6a * 0.001 if ag_h`n'6b==1
gen seed_purchased`n'_kg = ag_h`n'6a  if ag_h`n'6b==2
gen seed_purchased`n'_2kg = ag_h`n'6a * 2 if ag_h`n'6b==3
gen seed_purchased`n'_3kg = ag_h`n'6a * 3 if ag_h`n'6b==4
gen seed_purchased`n'_37kg = ag_h`n'6a * 3.7 if ag_h`n'6b==5
gen seed_purchased`n'_5kg = ag_h`n'6a * 5 if ag_h`n'6b==6
gen seed_purchased`n'_10g = ag_h`n'6a * 10 if ag_h`n'6b==7
gen seed_purchased`n'_50kg = ag_h`n'6a * 50 if ag_h`n'6b==8

egen seed_purch_kg`n' = rowtotal(seed_purchased`n'_*), missing
replace seed_purch_kg`n'= . if inlist(ag_h`n'9, ., 0) // Amount shouldn't be counted if there is no corresponding value
}
egen seeds_amount_purchased_kg = rowtotal(seed_purch_kg*), missing

collapse  (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg = seeds_amount_purchased_kg, by(y3_hhid  crop_code)
replace seeds_amount_purchased_kg= . if n_seeds_amount_purchased_kg==0

save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen seed_value_temp = rowtotal(ag_h19 ag_h29), missing

collapse  (sum) seed_value_temp (count) n_seed_value_temp = seed_value_temp, by(y3_hhid  crop_code)
replace seed_value_temp=. if n_seed_value_temp==0

save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
keep y3_hhid crop_code

duplicates drop

val_median_seeds_noimp_noea y3_hhid y3_hhid crop_code 

keep  plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid  gardenid plotid), punct("-")

forvalues x=1/13 {
gen total_family_labor_days1`x' = ag_d42b`x' * ag_d42c`x'
}

forvalues x=1/13 {
gen total_family_labor_days2`x' = ag_d43b`x' * ag_d43c`x'
}


forvalues x=1/13 {
gen total_family_labor_days3`x' = ag_d44b`x' * ag_d44c`x'
}

egen total_family_labor_days = rowtotal(total_family_labor_days*), missing

* 2) Hired labor days

egen hired_man_days = rowtotal(ag_d47a1 ag_d48a1), missing 

egen hired_woman_days = rowtotal(ag_d47a2 ag_d48a2), missing 

egen hired_child_days = rowtotal(ag_d47a3 ag_d48a3), missing 

egen wage_man = rowmean(ag_d47b1 ag_d48b1) 
egen wage_woman = rowmean(ag_d47b2 ag_d48b2) 
egen wage_child = rowmean(ag_d47b3 ag_d48b3) 

valuation_median_wages_noea y3_hhid wage_man wage_woman wage_child
gen man_labor_value = wage_man * hired_man_days
gen woman_labor_value = wage_woman * hired_woman_days
gen child_labor_value = wage_child * hired_child_days
egen hired_labor_value = rowtotal (*_labor_value), missing

egen total_hired_labor_days= rowtotal(hired_man_days hired_woman_days hired_child_days), missing
replace hired_labor_value = 0 if total_hired_labor_days==0
* 3) Other (free) labor

egen other_man_days = rowtotal(ag_d52a ag_d54a), missing
egen other_woman_days = rowtotal(ag_d52b ag_d54b), missing
egen other_child_days = rowtotal(ag_d52c ag_d54c), missing

egen total_other_labor_days= rowtotal(other_*), missing

* 4) Total labor days

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days total_other_labor_days), missing


collapse (sum) total_labor_days   total_family_labor_days total_hired_labor_days hired_labor_value  (count) n_total_labor_days = total_labor_days   n_total_family_labor_days=total_family_labor_days n_total_hired_labor_days = total_hired_labor_days n_hired_labor_value = hired_labor_value, by(plot_id)
foreach var in total_labor_days   total_family_labor_days total_hired_labor_days hired_labor_value {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode ag_d38 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
merge m:1 y3_hhid  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)nogen
recode ag_d38 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
* Chitowe
gen NPK_kg1 = ag_d39d if ag_d39a==1
gen NPK_kg2 = ag_d39j if ag_d39g==1
egen NPK_kg = rowtotal(NPK_kg*), missing
replace NPK_kg=0 if inorganic_fertilizer==0
gen nitrogen_kg1 = NPK_kg * 0.23

* UREA
gen UREA_kg1 = ag_d39d if ag_d39a==4 
gen UREA_kg2 = ag_d39j if ag_d39g==4
egen UREA_kg = rowtotal(UREA_kg*), missing
replace UREA_kg=0 if inorganic_fertilizer==0
gen nitrogen_kg2 = UREA_kg * 0.46

* DAP 
gen DAP_kg1 = ag_d39d if ag_d39a==2
gen DAP_kg2 = ag_d39j if ag_d39g==2
egen DAP_kg = rowtotal(DAP_kg*), missing
replace DAP_kg=0 if inorganic_fertilizer==0
gen nitrogen_kg3 = DAP_kg * 0.18

*CAN 
gen CAN_kg1 = ag_d39d if ag_d39a==3
gen CAN_kg2 = ag_d39j if ag_d39g==3
egen CAN_kg = rowtotal(CAN_kg*), missing
replace CAN_kg=0 if inorganic_fertilizer==0
gen nitrogen_kg4 = CAN_kg * 0.26

*CD compound 
gen D_kg1 = ag_d39d if ag_d39a==5
gen D_kg2 = ag_d39j if ag_d39g==5
egen D_kg = rowtotal(D_kg*), missing
replace D_kg=0 if inorganic_fertilizer==0
gen nitrogen_kg5 = D_kg * 0.07

egen other_kg = rowtotal(DAP_kg D_kg), missing // not enough observations to keep separate 

egen nitrogen_kg = rowtotal(nitrogen_kg*), missing
replace nitrogen_kg= 0 if inorganic_fertilizer==0
collapse (sum) nitrogen_kg NPK_kg DAP_kg UREA_kg CAN_kg D_kg other_kg (count) n_nitrogen_kg = nitrogen_kg n_NPK_kg = NPK_kg n_DAP_kg = DAP_kg n_UREA_kg = UREA_kg n_CAN_kg = CAN_kg n_D_kg = D_kg n_other_kg = other_kg, by(plot_id y3_hhid)
foreach var in nitrogen_kg NPK_kg DAP_kg UREA_kg CAN_kg D_kg other_kg {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 
use "${Input}\\${country}\\${wave}\\${ferts}", clear

gen t = "NPK" if ag_f0c==1 // this variable is created to create conditions in the loop below
replace t = "UREA" if ag_f0c==4
replace t = "CAN" if ag_f0c==3
replace t = "other" if inlist(ag_f0c,2,5)

foreach n in NPK UREA CAN other {
forval i = 1/2{
gen `n'_purchased_kg`i'_gram = ag_f`i'6a * 0.001 if ag_f`i'6b==1 & t=="`n'"
gen `n'_purchased_kg`i'_kg = ag_f`i'6a  if ag_f`i'6b==2& t=="`n'"
gen `n'_purchased_kg`i'_2kg = ag_f`i'6a * 2 if ag_f`i'6b==3 & t=="`n'"
gen `n'_purchased_kg`i'_3kg = ag_f`i'6a * 3 if ag_f`i'6b==4 & t=="`n'"
gen `n'_purchased_kg`i'_5kg = ag_f`i'6a * 5 if ag_f`i'6b==5 & t=="`n'"
gen `n'_purchased_kg`i'_10g = ag_f`i'6a * 10 if ag_f`i'6b==6 & t=="`n'"
gen `n'_purchased_kg`i'_50kg = ag_f`i'6a * 50 if ag_f`i'6b==7 & t=="`n'"
gen `n'_purchased_kg`i'_l = ag_f`i'6a if ag_f`i'6b==8 & t=="`n'"
gen `n'_purchased_kg`i'_ml = ag_f`i'6a * 0.001 if ag_f`i'6b==9 & t=="`n'"

gen `n'_purchased_value`i' = ag_f`i'9 if t=="`n'"
}
egen `n'_purchased_kg = rowtotal(`n'_purchased_kg*), missing
egen `n'_purchased_value = rowtotal(`n'_purchased_value*), missing
}

collapse (sum) UREA_purchased_kg NPK_purchased_kg CAN_purchased_kg other_purchased_kg UREA_purchased_value NPK_purchased_value CAN_purchased_value other_purchased_value  (count) n_UREA_purchased_kg = UREA_purchased_kg n_NPK_purchased_kg = NPK_purchased_kg n_CAN_purchased_kg = CAN_purchased_kg n_other_purchased_kg = other_purchased_kg n_UREA_purchased_value = UREA_purchased_value n_NPK_purchased_value = NPK_purchased_value n_CAN_purchased_value = CAN_purchased_value n_other_purchased_value =other_purchased_value  , by(y3_hhid ag_f0c)
foreach var in UREA_purchased_kg NPK_purchased_kg CAN_purchased_kg other_purchased_kg UREA_purchased_value NPK_purchased_value CAN_purchased_value other_purchased_value {
replace `var' = . if n_`var'==0
}
valuation_median_fert_price y3_hhid UREA

valuation_median_fert_price y3_hhid CAN

valuation_median_fert_price y3_hhid NPK

valuation_median_fert_price y3_hhid other

collapse (sum) UREA_value CAN_value NPK_value other_value (count) n_UREA_value = UREA_value n_CAN_value = CAN_value n_NPK_value = NPK_value n_other_value = other_value, by(y3_hhid) 
foreach var in UREA_value CAN_value NPK_value other_value  {
replace `var' = . if n_`var'==0
} 
merge 1:m y3_hhid using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

foreach n in NPK UREA CAN other {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode ag_d36 (1= 1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode ag_d41a (7 = 1 "Yes") (.=.) (else = 0 "No"), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if ag_d40==2
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_roster_2}", clear
egen parcel_id = concat(y3_hhid  gardenid  ), punct("-")
recode ag_b203 (1/4 12 13 = 1 "Yes") (.=.) (else = 0 "No") , gen(plot_owned) label(plot_owned)
recode ag_b204_1 (1/3 = 1 "Yes") (4 96 = 0 "No") , gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0
keep parcel_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode  ag_d28a (7 = 0 "No") (1/6 = 1 "Yes") (8=.), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace


// erosion protection
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode ag_d25a (1 = 0 "No") (2/9 = 1 "Yes"), gen(erosion_protection)  label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
gen tractor= 1 if hh_m10==1 & inlist(hh_m0b, 611, 612) 
replace tractor= 0 if hh_m10==2
replace tractor= 0 if !inlist(hh_m0b, 611, 612) 
collapse (max) tractor , by(y3_hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
recode ag_d14 (4 = 1) (. = . ) (* = 0), gen(fallow_plot)
bys y3_hhid: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keepusing(y3_hhid)
replace nb_fallow_plots= 0 if _merge ==2
keep y3_hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
bys y3_hhid: egen nb_plots = count(ag_d14) 
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", keepusing(y3_hhid)
replace nb_plots= 0 if _merge ==2
keep y3_hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recode hh_c06 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode hh_c08 (8/23 = 1 "Yes") (.=.) (else =0 "No"), gen(primary_education) label(primary_education)
replace primary_education=0 if hh_c08==8 & hh_c12== 7 // this makes sure that kids which are currently in the last year of PS are not counted (and assumes no one redoes a year)
replace primary_education= 0 if formal_education==0

bys y3_hhid: egen hh_primary_education= max(primary_education) 
bys y3_hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(y3_hhid)
keep y3_hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode hh_f19 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
keep y3_hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${household_roster}", clear
rename hh_b05a age 
gen dep_temp= !inrange(age,15,65) & !mi(age)
gen nondep_temp= inrange(age,15,65) & !mi(age)
bysort y3_hhid: egen dep=total(dep_temp)
bysort y3_hhid: egen nondep=total(nondep_temp)
gen hh_dependency_ratio = (dep/nondep)
replace hh_dependency_ratio = dep  if nondep==0
collapse (max) hh_dependency_ratio, by(y3_hhid)
keep y3_hhid hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
recode ag_r00 (1 = 1 "Yes") (2 . = 0 "No") , gen(livestock) label(livestock) 
collapse (max) livestock, by(y3_hhid) 
merge 1:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keep(using match)
replace livestock = 0 if _merge==2
collapse (max) livestock, by(y3_hhid) 

save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint (absent)

// consumption aggregate (absent)


// manager chars
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid  gardenid plotid), punct("-")
rename ag_d01 manager_id 

sort  y3_hhid (manager_id)
collapse (first) manager_id y3_hhid , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${household_roster}", clear
gen manager_id = id_code  // this is the HH member id 
merge 1:m  y3_hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
gen manager_id = PID
recode hh_b03 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename hh_b05a age_manager
recode hh_b24 ( 1 2 = 1 "Yes") (.=.) (else = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = id_code 
merge 1:m  y3_hhid manager_id using `ID_list', keep(match) nogen
recode hh_c06 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode hh_c08 (8/23 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager=0 if hh_c08==8 & hh_c12== 7
replace primary_education_manager= 0 if formal_education_manager==0
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${ag_meta}", clear
drop if ag_moduleC_respondent==. // drop if no respodnent

// Finding the respondent of the first visit
gen year = substr(ag_moduleC_start_date, 1, 4)
gen month = substr(ag_moduleC_start_date, 6, 2)
replace month="." if month=="##"
replace year="." if year=="##N/"
destring month, replace
destring year, replace
gen date = ym( year, month)
sort y3_hhid (d) // sort ascending

// we delete the observation corresponding to the first visit
bys y3_hhid: gen n=_n
drop if n>1


rename ag_moduleC_respondent respondent_id 
keep respondent_id y3_hhid
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${household_roster}", clear
rename id_code respondent_id // this is the HH member id 
merge 1:m  y3_hhid respondent_id using `ID_list', keep(match) nogen
recode hh_b03 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename hh_b05a age_respondent
recode hh_b24 ( 1 2 = 1 "Yes")(.=.) (else  = 0 "No"), gen(married_respondent) 
rename respondent_id id
gen respondent_id = PID
keep y3_hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename id_code respondent_id // this is the HH member id 
drop if respondent_id==.
duplicates report y3_hhid respondent_id // no duplicates
merge 1:m  y3_hhid respondent_id using `ID_list', keep(match) nogen
recode hh_c06 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode hh_c08 (8/23 = 1 "Yes") (else=0 "No"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent=0 if hh_c08==8 & hh_c12== 7
replace primary_education_respondent= 0 if formal_education_respondent==0
keep y3_hhid primary_education_respondent formal_education_respondent 
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode hh_u01 (2= 0 "No") (1 = 1 "Yes"), gen(hh_shock) 
collapse (max) hh_shock, by(y3_hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${household_roster}", clear
gen hh_size = hhsize
keep y3_hhid hh_size
duplicates drop
isid y3_hhid
save "${Temp}\\${temppath}\\size.dta", replace


// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
rename hh_m0b itemid
drop if itemid>617
recode hh_m0c (1 = 1) (2 . = 0) , gen(hh_owns_) 
keep y3_hhid itemid hh_owns_
reshape wide hh_owns_ , i(y3_hhid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep y3_hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace


// hh assets
use "${Input}\\${country}\\${wave}\\${assets}", clear
drop if hh_l02>532
recode hh_l01 ( 2 = 0 ) (1 = 1), gen (hh_owns) 
keep hh_owns y3_hhid hh_l02
reshape wide hh_owns , i(y3_hhid) j(hh_l02)
factor hh_owns*, pcf 
predict hh_asset_index
xtile hh_asset_index_quint = hh_asset_index, nq(5)
keep y3_hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
egen sum_answers = rowtotal(hh_n01 hh_n02 hh_n03 hh_n04 hh_n05 hh_n06 hh_n07 hh_n08), missing 
gen nonfarm_enterprise = sum_answers<16
keep y3_hhid nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace


// latitude
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep y3_hhid lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace


// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ssa_aez09 agro_ecological_zone
keep y3_hhid agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep y3_hhid dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep y3_hhid dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace

// distance to nearest market (none)


// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
rename slope plot_slope
collapse (mean) plot_slope, by(y3_hhid)
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
collapse (mean) elevation, by(y3_hhid)
save "${Temp}\\${temppath}\\elevation.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
rename twi_mwi twi
keep y3_hhid twi
duplicates drop
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
forvalues i=1/7{
recode sq`i' (1=1) (2/7=0), gen(sq`i'_d)
}
factor sq1_d-sq7_d, pcf 
predict soil_fertility_index

local names "nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability"
forvalues n =1/7 {
local lab: word `n' of `names'
rename sq`n'_d `lab'
}

keep y3_hhid  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace

// popdensity
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
keep y3_hhid popdensity
tostring popdensity , replace
duplicates drop
save "${Temp}\\${temppath}\\popdensity.dta", replace

// plot distance to house
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
egen plot_id = concat(y3_hhid gardenid plotid), punct("-")
rename dist_hh plot_dist_household
keep plot_id  plot_dist_household
duplicates drop
save "${Temp}\\${temppath}\\plot_dist_household.dta", replace

// indiv chars
use "${Input}\\${country}\\${wave}\\${household_roster}", clear

recode  hh_b03 (2=1 "Yes") (1=0 "No"), gen(female) 
rename hh_b05a age
recode hh_b24 (1 2 = 1 "Yes") (3 4 5 6 = 0 "No"), gen(married) 
replace married = 0 if married==.
decode hh_b04, generate(relationship_head) 
replace relationship_head = proper(relationship_head)
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head== "Father/Mother In-Law"
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head== "Father/Mother-In-Law"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head== "Son/Daughter-In-Law"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head== "Brother/Sister In-Law"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head== "Brother/Sister-In-Law"
replace relationship_head = "Non Relative" if relationship_head== "Other Non-Relative"
replace relationship_head = "Non Relative" if relationship_head== "Other (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relative"
replace relationship_head = "Servant" if relationship_head== "Servant Or Servant'S Relative"
replace relationship_head = "Non Relative" if relationship_head== "Lodger/Lodger'S Relative"
replace relationship_head = "Grandparent" if relationship_head== "Grandfather/Mother"
replace relationship_head = "Son/Daughter" if relationship_head== "Child/Adopted Child"
replace relationship_head = "Spouse" if relationship_head== "Wife/Husband"

keep y3_hhid PID married female age relationship_head hh_b05b
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${health}", clear
merge 1:1 y3_hhid PID using "${Input}\\${country}\\${wave}\\${household_roster}", keep(master match) nogen
merge 1:1 y3_hhid PID using "${Temp}\\${temppath}\\indiv_chars.dta",  keep(master match) nogen

*Main anthropometric variables
gen weight=hh_v08
gen height=hh_v09

gen cage=age*12
replace cage = hh_b05b if age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  y3_hhid PID weight height
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
merge 1:1 PID y3_hhid using "${Input}\\${country}\\${wave}\\${household_roster}",

recode hh_e07a (0 = 0) (.=.) (else = 1), gen( hh_head_farm_act1)
recode hh_e07b (0 = 0) (.=.) (else = 1), gen( hh_head_live_act)
recode hh_e07c (0 = 0) (.=.) (else = 1), gen( hh_head_fish_act)
egen farm_work = rowmax(hh_head_farm_act1 hh_head_live_act hh_head_fish_act)

recode hh_e08 (0 = 0) (.=.) (else = 1), gen( hh_head_SB_act1)  
recode hh_e09 (0 = 0) (.=.) (else = 1), gen( hh_head_SB_act2)
egen SOB_work = rowmax(hh_head_SB_act2 hh_head_SB_act1)

recode hh_e11 (0 = 0) (.=.) (else = 1), gen( hh_head_wage_act1)
recode hh_e10 (0 = 0) (.=.) (else = 1), gen( hh_head_wage_act2) // count ganyu as wage

gen wage_work = 1 if hh_head_wage_act1==1 | hh_head_wage_act2==1 
replace wage_work = 0 if hh_head_wage_act1==0 & hh_head_wage_act2 == 0


/// nb of working age members
gen working_age = hh_b05a>=5
bys y3_hhid: egen nb_members_working_age = total(working_age)


// industry:
gen ind_ag = hh_e20b == 11 | hh_e20b ==12  // Agriculture 
gen ind_fish = hh_e20b == 13 // fishing
gen ind_mining = hh_e20b == 29 // mining
gen ind_manuf = hh_e20b >= 31 & hh_e20b <= 42 // manuf
gen ind_const = hh_e20b == 50 // construc
gen ind_serv = hh_e20b >= 61 & hh_e20b<= 96 // services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if hh_e06_4==2 
}


rename ( hh_e11 hh_e10 ) ( wage_hrs1 wage_hrs2 )
egen wage_hrs = rowtotal(wage_hrs1 wage_hrs2 ), missing

egen farm_hrs = rowtotal(hh_e07a hh_e07b hh_e07c), missing
egen SB_hrs = rowtotal(hh_e08 hh_e09), missing

foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep PID y3_hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace



// education
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recode hh_c06 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode hh_c08 (8/23 = 1 "Yes") (.=.) (else =0 "No"), gen(primary_education) label(education)
replace primary_education = 0 if formal_education==0
foreach var in formal_education primary_education {
	replace `var' = 0  if hh_c02=="X"
}
keep PID y3_hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace



// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

drop if hh_g01 ==2 // keep if consumed
rename hh_g02 item_cd 

gen A = item_cd>=101 & item_cd<=117 | item_cd==820
gen B = item_cd>=201 & item_cd<=209 | item_cd==821 | item_cd==822 | item_cd==833 | item_cd==834
gen C = item_cd>=401 & item_cd<=414
gen D = item_cd>=601 & item_cd<=610
gen E = item_cd>=504 & item_cd<=512 | item_cd==515 | item_cd==522 | item_cd==824 | item_cd==825 | item_cd==831 | item_cd==832
gen F = item_cd==501 | item_cd==823
gen G = item_cd>=502 & item_cd<=503 | item_cd==513 | item_cd==826 | item_cd>=5021
gen H = item_cd>=301 & item_cd<=313
gen I = item_cd>=701 & item_cd<=709
gen J = item_cd==803 | item_cd==804 
gen K = item_cd==801 | item_cd==802 | item_cd>=815 & item_cd<=818
gen L = item_cd>=810 & item_cd<=814 |item_cd>=901 &  item_cd <=916 |  item_cd>=827 & item_cd<=830

collapse (max) A B C D E F G H I J K L, by(y3_hhid)
 egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m y3_hhid  using "${Input}\\${country}\\${wave}\\${HDDS}", 

collapse (max) HDDS, by(y3_hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace
