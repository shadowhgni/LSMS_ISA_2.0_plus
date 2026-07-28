/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for ESS5									          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Ethiopia
global wave  ESS 21
global cover  sect_cover_hh_w5.dta
global household_roster sect1_hh_w5.dta
global indiv_roster  sect2_hh_w5.dta
global health  sect3_hh_w5.dta
global lab_roster  sect4_hh_w5.dta
global shocks sect9_hh_w5.dta
global housing  sect10a_hh_w5.dta
global assets sect11_hh_w5.dta
global nfe sect12a_hh_w5.dta
global cover_pc_pp  sect_cover_pp_w5.dta
global parcel_roster  sect2_pp_w5.dta
global plot_roster  sect3_pp_w5.dta
global planting_rwdta  sect4_pp_w5.dta
global seeds sect5_pp_w5.dta
global misc sect7_pp_w5.dta
global cover_pc_ph  sect_cover_ph_w5.dta
global harvest_rwdta  sect9_ph_w5.dta
global labor_ph  sect10_ph_w5.dta
global harvest_sale_rwdta  sect11_ph_w5.dta
global geovars_hh eth_householdgeovariables_y5.dta
global geovars_plot eth_plotgeovariables_y5.dta
global HDDS sect6a_hh_w5.dta

global conversions_land ET_local_area_unit_conversion
global conversions_crop crop_cf_wave5
global csption  cons_agg_w5.dta

global extra_ag sect12c_hh_w5.dta

global temppath ETH\ESS21



**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s9q00b crop_code
merge m:1 household_id field_id crop_id using "${Input}\\${country}\\${wave}\\${extra_ag}", 
replace crop_code = s12cq01b if _merge==2
decode crop_code, generate(crop_name) 
replace crop_name = substr(crop_name, strpos(crop_name, " ") + 1, .)
replace crop_name = substr(crop_name, strpos(crop_name, ".") + 1, .)


egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
egen plot_id2 = concat(household_id field_id), punct("-") // This creates a unique plot id.
replace plot_id = plot_id2 if _merge==2
rename parcel_id parcel_id2
egen parcel_id = concat(holder_id parcel_id2), punct("-") 


keep household_id holder_id parcel_id field_id crop_name crop_code  pw_w5 plot_id

duplicates drop
duplicates report plot_id crop_code crop_name

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear


keep household_id  pw_w5
duplicates report household_id 

save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat(household_id individual_id), punct("-")
keep household_id individual_id ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keepusing(ea_id) nogen

keep household_id ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen strataid= 17 if saq14==1 & saq01==2 // new small region
replace strataid= 18 if saq14==1 & saq01==5 // new small region
replace strataid= 19 if saq14==1 & saq01==6 // new small region
replace strataid= 20 if saq14==1 & saq01==12 // new small region
replace strataid= 21 if saq14==1 & saq01==13 // new small region
replace strataid= 22 if saq14==1 & saq01==15 // new small region
replace strataid= 23 if saq14==2 & saq01==2 // new small region
replace strataid= 24 if saq14==2 & saq01==5 // new small region
replace strataid= 25 if saq14==2 & saq01==6 // new small region
replace strataid= 26 if saq14==2 & saq01==12 // new small region
replace strataid= 27 if saq14==2 & saq01==13 // new small region
replace strataid= 28 if saq14==2 & saq01==15 // new small region
replace strataid= 1 if saq14==1 & saq01==1 // Rural tigray
replace strataid= 2 if saq14==1 & saq01==3 // Rural Amhara
replace strataid= 3 if saq14==1 & saq01==4 // Rural Oromia
replace strataid= 5 if saq14==1 & saq01==7 // Rural SNNP
replace strataid= 29 if saq14==2 & saq01==1 // Urban tigray
replace strataid= 30 if saq14==2 & saq01==3 // Urban Amhara
replace strataid= 31 if saq14==2 & saq01==4 // Urban Oromia
replace strataid= 32 if saq14==2 & saq01==7 // Urban SNNP
replace strataid= 99 if  saq01==14 // Addis
keep household_id strataid
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace


// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keepusing(saq01) // some households drop out in the hh cover
rename saq01 admin_1

keep household_id admin_1
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 1 name 
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keepusing(saq01) // some households drop out in the hh cover

decode saq01, gen(admin_1_name)

keep household_id admin_1_name
duplicates drop
save "${Temp}\\${temppath}\\admin_1_name.dta", replace


// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keepusing(saq01 saq02) // some households drop out in the hh cover
egen admin_2 = concat(saq01 saq02), punct("-") // This creates a unique zone i

keep household_id admin_2
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keepusing(saq01 saq02 saq03)  // some households drop out in the hh cover
egen admin_3 = concat(saq01 saq02 saq03), punct("-") // This creates a unique woreda id

keep household_id admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// admin 4
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}", keepusing(saq01 saq02 saq03 saq06) // some households drop out in the hh cover
egen admin_4 = concat(saq01 saq02 saq03 saq06), punct("-") // This creates a unique kebele id

keep household_id admin_4
duplicates drop
save "${Temp}\\${temppath}\\admin4.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${extra_ag}", clear
recode saq14 (1 = 1 "Yes") (2 = 0 "No"), gen(urban) label(urban)
collapse (max) urban, by(household_id)
tempfile ag_extension 
save `ag_extension', replace
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}",  keepusing(saq14) // some households drop out in the hh cover
recode saq14 (1 =0 "No") ( 2 =1 "Yes"), gen(urban)

merge m:1 household_id using `ag_extension', nogen
keep household_id urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\${country}\\${wave}\\${cover_pc_pp}",  keepusing(pw_w5)  // some households drop out in the hh cover
keep pw_w5 household_id
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace


// planting month
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s4q01b crop_code
drop if s4q15==1
gen year= s4q13b

recode s4q13a (1 13 = 9) (2 = 10) (3= 11) (4 = 12 ) (5 = 1) (6 = 2) (7= 3 ) (8=4) (9=5) (10 = 6) (11= 7 ) (12 = 8) (0=.), gen(month)
replace year= 2022  if s4q13b==2013 & month< 9
replace year = 2021 if s4q13b==2013 & month>= 9 & !mi(month)
replace year= 2021 if s4q13b==2012 & month< 9 
replace  year= 2020 if s4q13b==2012 & month>= 9 & !mi(month)
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
collapse (min) planting_month, by(household_id plot_id  crop_code) 
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s9q00b crop_code
recode s9q08b (1 13 = 9) (2 = 10) (3= 11) (4 = 12 ) (5 = 1) (6 = 2) (7= 3 ) (8=4) (9=5) (10 = 6) (11= 7 ) (12 = 8) (0=.), gen(month)
gen year = 2018 if month>=9 & !mi(month)
replace year= 2019 if month<9
gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(household_id plot_id  crop_code) 

save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover_pc_ph}", clear

gen month = ubsubstr( InterviewDate, 6, 2)
replace month="" if month=="##" 
destring month, replace

gen year = ubsubstr(InterviewDate,1, 4)
replace year="" if year=="##N/"
destring year, replace
gen harvest_interview_month = ym(year, month)
format harvest_interview_month %tmCCYYMon
drop month year
keep holder_id harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover_pc_pp}", clear
// planting_interview_month is confidential
gen planting_interview_month = .

save "${Temp}\\${temppath}\\planting_interview_month.dta", replace


// harvest_kg 
use "${Input}\\${country}\\${wave}\\${conversions_crop}", clear
rename unit_cd s11q11b
collapse (mean) mean_cf*, by(s11q11b crop_code)

	reshape long mean_cf, i(crop_code s11q11b) j(saq01)
	
expand=3 if saq01==99 
bysort crop_code s11q11b saq01: gen n=_n
replace saq01=5 if saq01==99 & n==1 
replace saq01=13 if saq01==99 & n==2
replace saq01=15 if saq01==99 & n==3
drop n
tempfile conversions_crop
save `conversions_crop', replace
collapse (median) mean_cf , by(s11q11b)
tempfile conversions_nocrop
save `conversions_nocrop', replace


use "${Input}\\${country}\\${wave}\\${extra_ag}", clear
egen plot_id = concat(household_id field_id), punct("_")
rename s12cq01b crop_code
rename s12cq07b s11q11b
merge m:1 s11q11b using `conversions_nocrop', keep(master match) nogen
gen harvest_kg = s12cq07a 
replace harvest_kg = s12cq07a * mean_cf 
keep harvest_kg plot_id crop_code
duplicates drop 
tempfile ag_extension 
save `ag_extension', replace


use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 household_id using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
duplicates drop // 605 full duplicates
rename s9q00b crop_code
rename s9q05b s11q11b 
merge m:1 saq01 crop_code s11q11b using `conversions_crop', keep(master match) nogen // Merge with CF database

recode s9q10  (1 = 1 "Yes") (2 = 0 "No") (8=.), gen(crop_shock) label(crop_shock)
replace crop_shock=0 if s9q12g==1 & s9q12a==2 & s9q12b==2 & s9q12c==2 & s9q12d==2 & s9q12e==2 & s9q12f==2 & s9q12h==2
replace crop_shock=1 if s9q13==1


gen harvest_kg= s9q05a * mean_cf 
drop mean_cf 
merge m:1 s11q11b using `conversions_nocrop', keep(master match) nogen
replace harvest_kg= s9q05a  * mean_cf if harvest_kg==.
replace harvest_kg= s9q06 if mi(harvest_kg) 


replace harvest_kg = 0 if harvest_kg==. & crop_shock==1 & s9q04 ==2 
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1
sum harvest_kg, d

merge m:1 plot_id crop_code using `ag_extension', nogen

collapse (sum) harvest_kg (count) n_harvest_kg= harvest_kg, by(plot_id crop_code ea_id household_id holder_id)
save "${Temp}\\${temppath}\\harvest_kg_temp.dta", replace

use "${Input}\\${country}\\${wave}\\${extra_ag}", clear

egen plot_id = concat(household_id field_id), punct("-") // This creates a unique plot id.
drop if s12cq01b==.
rename s12cq01b crop_code
rename s12cq07b s11q11b
merge m:1 saq01 crop_code s11q11b using `conversions_crop', keep(master match) nogen

gen harvest_kg= s12cq07a * mean_cf 
drop mean_cf 
merge m:1 s11q11b using `conversions_nocrop', keep(master match) nogen
replace harvest_kg= s12cq07a  * mean_cf if harvest_kg==.

merge 1:m plot_id crop_code using "${Temp}\\${temppath}\\harvest_kg_temp.dta", nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s9q00b crop_code
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
gen pct_area_harvested = s9q11
replace pct_area_harvested=100 if s9q10==2 
replace pct_area_harvested=0 if s9q04==2
keep household_id plot_id crop_code pct_area_harvested
duplicates drop
collapse (max) pct_area_harvested, by(plot_id crop_code)
save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s9q00b crop_code

recode s9q10  (1 = 1 "Yes") (2 = 0 "No") (8=.), gen(crop_shock) label(crop_shock)
replace crop_shock=0 if s9q12g==1 & s9q12a==2 & s9q12b==2 & s9q12c==2 & s9q12d==2 & s9q12e==2 & s9q12f==2 & s9q12h==2
replace crop_shock=1 if s9q13==1


recode s9q12a (1 = 1 "Yes") (2 = 0 "No"), gen(drought_shock1) label(drought_shock) 
recode s9q14 (2 = 1 "Yes") (1 3/100 = 0 "No"), gen(drought_shock2) 
replace drought_shock1 = 0 if s9q10==2
replace drought_shock1=1 if s9q12_os=="Drought"
replace drought_shock2 = 0 if s9q13==2
gen drought_shock= 1 if drought_shock1==1 | drought_shock2==1 
replace drought_shock=0 if (drought_shock1==0 & drought_shock2==0)

recode s9q12b (1 = 1 "Yes") (2 = 0 "No"), gen(rain_shock1) label(rain_shock) 
recode s9q14 (1 = 1 "Yes") ( 2/100 = 0 "No"), gen(rain_shock2) 
replace rain_shock1 = 0 if s9q10==2
replace rain_shock2 = 0 if s9q13==2
gen rain_shock= 1 if rain_shock1==1 | rain_shock2==1 
replace rain_shock=0 if (rain_shock1==0 & rain_shock2==0)

recode s9q12d (1 = 1 "Yes") (2 = 0 "No"), gen(pests_shock1) label(pests_shock) 
recode s9q14 (4 10 = 1 "Yes") (1/3 5/9 11/100 = 0 "No"), gen(pests_shock2) 
replace pests_shock1 = 0 if s9q10==2
replace pests_shock2 = 0 if s9q13==2
gen pests_shock= 1 if pests_shock1==1 | pests_shock2==1 
replace pests_shock=0 if (pests_shock1==0 & pests_shock2==0)

recode s9q14 (7 = 1 "Yes") (1/6 8/16 = 0 "No"), gen(flood_shock) label(flood_shock) 	
replace flood_shock = 0 if s9q13==2		
replace flood_shock = 1 if s9q12_os=="FLOOD"

collapse (max) crop_shock pests_shock rain_shock drought_shock flood_shock, by(household_id plot_id  crop_code) 
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${conversions_crop}", clear
rename unit_cd s11q11b
collapse (mean) mean_cf*, by(s11q11b crop_code)

	reshape long mean_cf, i(crop_code s11q11b) j(saq01)
	
expand=3 if saq01==99 
bysort crop_code s11q11b saq01: gen n=_n
replace saq01=5 if saq01==99 & n==1 
replace saq01=13 if saq01==99 & n==2
replace saq01=15 if saq01==99 & n==3
drop n
tempfile conversions_crop
save `conversions_crop', replace
collapse (median) mean_cf , by(s11q11b)
tempfile conversions_nocrop
save `conversions_nocrop', replace
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
rename s11q01 crop_code
drop if ea_id=="" | crop_code==. 
gen harvest_sold_preCF= s11q11a
merge m:1 saq01 crop_code s11q11b  using `conversions_crop', keep(master match) nogen // Merge with CF database
gen harvest_sold_kg =  harvest_sold_preCF if s11q11b==1
replace harvest_sold_kg = harvest_sold_preCF * mean_cf if harvest_sold_kg==.
drop mean_cf
merge m:1  s11q11b  using `conversions_nocrop', keep(master match) nogen // Merge with CF database
replace harvest_sold_kg = harvest_sold_preCF * mean_cf if harvest_sold_kg==.
replace harvest_sold_kg=0 if s11q07 ==2
collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by(household_id holder_id crop_code) 
replace harvest_sold_kg = . if n_harvest_sold_kg == 0
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(household_id)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m household_id using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(household_id _merge)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
replace share_kg_sold = 0 if harvest_kg==0
replace share_kg_sold = 0 if _merge==2
keep household_id share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace

// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
rename s11q01 crop_code
drop if crop_code==.
gen harvest_sold_value = s11q12
replace harvest_sold_value=0 if  s11q07 ==2
collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by(household_id holder_id crop_code) 
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
rename s11q01 crop_code
drop if crop_code==.
drop if ea_id=="" | crop_code==. 
keep household_id holder_id crop_code 
duplicates drop


merge 1:m household_id holder_id crop_code using "${Temp}\\${temppath}\\harvest_kg.dta", 
keep admin_1 admin_2 admin_3 household_id holder_id crop_code 
duplicates drop

valuation_median_crops_noea household_id holder_id crop_code

main_crop_def crop_code


keep household_id plot_id  harvest_value crop_code main_crop holder_id
save "${Temp}\\${temppath}\\harvest_value.dta", replace

// intercropped
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s9q00b crop_code
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode s9q02  (1 = 0 "No") (2 = 1 "Yes") , gen(intercropped) label(intercropped)
keep household_id plot_id intercropped
collapse (max) intercropped, by(plot_id household_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s9q00b crop_code
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace


// main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s9q00b crop_code
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
duplicates drop
merge m:1 crop_code plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

gen codesmain_crop = main_crop
gen codescrop_code = crop_code
foreach c in main_crop crop_code {
lab val `c' s9q00b
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2
replace `c' = strupper(`c')
replace `c' = substr(`c', strpos(`c',". ") + 2, . )
replace `c' = substr(`c', strpos(`c',".") + 1, . )

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"FIELD PEAS", "HARICOT BEANS", "RED KIDENY BEANS", "CHICK PEAS", "GROUND NUTS", "LENTILS", "VETCH", "SOYA BEANS", "MUNG BEAN/ MASHO")
replace `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"HORSE BEANS")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"GODERE", "SWEET POTATO", "POTATOES", "OTHER ROOT C", "CASSAVA", "CARROT", "BEER ROOT")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE"
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "MAIZE" if `c'=="MAIZE"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "MILLET" if `c'=="MILLET"	
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if inlist(codes`c', 19, 20, 22, 34, 35, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 55, 65, 66, 71, 72, 74, 75, 76, 81, 82, 84, 85, 86, 98, 99, 108, 111, 112, 113, 114, 115, 116, 117, 122)
drop `c'
rename `c'2 `c'
}
tab crop_code, gen(contains_crop_)


foreach n in 10 9 8 7 6 5 {
	local i = `n' + 1
	rename contains_crop_`n' contains_crop_`i'
}

gen contains_crop_5 =0


//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace


// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s4q01b crop_code

gen pct_area_planted = s4q03 
replace pct_area_planted = 100 if s4q02==1 

keep pct_area_planted plot_id crop_code
duplicates drop
collapse (mean) pct_area_planted, by(plot_id crop_code)
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace


// land area

use "${Input}\\${country}\\ESS 18\\${conversions_land}.dta", clear
collapse (median) conversion, by(local_unit)
tempfile median_unit
save `median_unit', replace

use "${Input}\\${country}\\${wave}\\${extra_ag}", clear
egen plot_id = concat(household_id field_id), punct("-") 


rename saq01 region
	rename saq02 zone 
	rename saq03 woreda 
	rename s12cq02b  local_unit
	destring zone, replace
	destring woreda, replace 
	merge m:1 region zone woreda local_unit using "${Input}\\${country}\\ESS 18\\${conversions_land}.dta", keep(master match) nogen
	gen area_self_reported= s12cq02a * conversion * 0.0001
	replace area_self_reported = s12cq02a if local_unit==1
	replace area_self_reported = s12cq02a * 0.0001 if local_unit==2
	drop conversion
	merge m:1  local_unit using `median_unit', keep(master match) nogen
	replace area_self_reported= s12cq02a * conversion * 0.0001 if area_self_reported==.
	keep area_self_reported plot_id
	duplicates drop
	isid plot_id 
	tempfile ag_extension
	save `ag_extension', replace
	

use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.



rename saq01 region
rename saq02 zone 
rename saq03 woreda 
rename s3q02b  local_unit
destring zone, replace
destring woreda, replace 
merge m:1 region zone woreda local_unit using "${Input}\\${country}\\ESS 18\\${conversions_land}.dta", keep(master match) nogen

gen area_self_reported = s3q02a 
replace area_self_reported= area_self_reported * conversion
replace area_self_reported = s3q02a if local_unit==2 // This corresponds to values that are in m²
replace area_self_reported= area_self_reported * 0.0001 // This converts everything in hectares
replace area_self_reported = s3q02a if local_unit==1 // These values are already in hectares.

gen plot_area_GPS= s3q08 * 0.0001  if s3q07==1 | s3q07==2



merge 1:1 plot_id using `ag_extension' , 


merge m:1 household_id using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
encode admin_3, gen(admin_3_num)

duplicates report household_id plot_id
sort household_id plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi impute pmm plot_area_GPS area_self_reported i.admin_3_num, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys household_id: egen farm_size = total(plot_area_GPS), missing

keep household_id plot_id   plot_area_GPS  farm_size 
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved
use "${Input}\\${country}\\${wave}\\${extra_ag}", clear
egen plot_id = concat(household_id field_id), punct("_")
recode s12cq08c (1 = 1 "Yes") (2 = 0 "No"), gen(improved) label(improved)
collapse (max) improved, by(plot_id)
tempfile ag_extension 
save `ag_extension', replace
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s4q01b crop_code
recode s4q11 (1=0 "No") (2/4 =1 "Yes"), gen(improved)
drop if s4q15==1
merge m:1 plot_id using `ag_extension'
keep household_id plot_id  crop_code improved holder_id
duplicates drop
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s4q01b crop_code
drop if s4q15==1
gen seed_kg = s4q11a 
replace seed_kg=. if seed_kg<0 
recode s4q11 (1=0 "No") (2/4 =1 "Yes"), gen(improved)
collapse (sum) seed_kg (max) improved (count) n_seed_kg = seed_kg , by(plot_id crop_code ea_id household_id)
replace seed_kg = . if n_seed_kg==0
merge 1:m plot_id crop_code improved using "${Temp}\\${temppath}\\improved.dta", keepusing(improved) keep(master match) nogen
keep  plot_id crop_code  seed_kg  ea_id improved household_id
duplicates drop
save "${Temp}\\${temppath}\\seed_kg.dta", replace
collapse (sum) seed_kg (count) n_seed_kg = seed_kg, by(plot_id crop_code)
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace

// seed_kg_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s5q0B crop_code
gen seeds_amount_purchased_kg = s5q04 
replace seeds_amount_purchased_kg=0 if s5q02==2
recode s5q01a (1=0 "No") (2=1 "Yes"), gen(improved)
collapse (max) improved (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg = seeds_amount_purchased_kg, by(household_id holder_id crop_code)
replace seeds_amount_purchased_kg = . if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s5q0B crop_code
gen seed_value_temp = s5q07
recode s5q01a (1=0 "No") (2=1 "Yes"), gen(improved)
collapse (max) improved (sum) seed_value_temp (count) n_seed_value_temp = seed_value_temp, by(household_id holder_id crop_code)
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s5q0B crop_code
duplicates drop
recode s5q01a (1=0 "No") (2=1 "Yes"), gen(improved)
collapse (max) improved, by(household_id holder_id crop_code)

valuation_median_seeds household_id holder_id crop_code 

keep household_id plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

// HIRED PP
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.


gen hired_number_man = s3q30a 
gen hired_man_days_av=s3q30b // Total number of days per man 
replace hired_man_days_av=0 if hired_number_man==0
gen PPhired_man_days= hired_man_days_av * hired_number_man // = Variable of interest
	
gen hired_number_woman= s3q30d
gen hired_woman_days_av=s3q30e
replace hired_woman_days_av=0 if hired_number_woman==0
gen PPhired_woman_days= hired_woman_days_av * hired_number_woman  // = Variable of interest
	
gen hired_number_children = s3q30g
gen hired_child_days_av=s3q30h
replace hired_child_days_av=0 if hired_number_children==0
gen PPhired_child_days= hired_child_days_av * hired_number_child // = Variable of interest
	
egen PPtotal_hired_labor_days = rowtotal(PPhired_child_days PPhired_woman_days PPhired_man_days), missing

	// calculate value
		gen PPhired_man_wage= s3q30c
		replace PPhired_man_wage =. if hired_number_man==0  // This is to ensure that these observations are not counted when computing median wages
			
		gen PPhired_woman_wage= s3q30f
		replace PPhired_woman_wage =. if hired_number_woman==0
			
		gen PPhired_child_wage = s3q30i
		replace PPhired_child_wage =. if hired_number_child==0
		
		valuation_median_wages household_id PPhired_man_wage PPhired_woman_wage PPhired_child_wage
		
		gen PPman_labor_value_hired = man_wage * PPhired_man_days
		replace PPman_labor_value_hired = 0 if PPhired_man_days==0
		gen PPwoman_labor_value_hired = woman_wage * PPhired_woman_days
		replace PPwoman_labor_value_hired = 0 if PPhired_woman_days==0
		gen PPchild_labor_value_hired = child_wage * PPhired_child_days
		replace PPchild_labor_value_hired = 0 if PPhired_child_days==0
		egen PPtotal_hired_labor_value = rowtotal( PPman_labor_value_hired PPwoman_labor_value_hired PPchild_labor_value_hired), missing
		
		rename (man_wage woman_wage child_wage ) (PPman_wage PPwoman_wage PPchild_wage )
		
		
 
keep plot_id PPtotal_hired_labor_days PPman_wage PPwoman_wage PPchild_wage PPtotal_hired_labor_value
duplicates drop
tempfile PPtotal_hired_labor_days
save `PPtotal_hired_labor_days', replace

// FAMILY PP 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.


	gen number_weeks1=s3q29b
	gen days_per_week1=s3q29c
	gen number_weeks2=s3q29f
	gen days_per_week2=s3q29g
	gen number_weeks3=s3q29j
	gen days_per_week3=s3q29k
	gen number_weeks4=s3q29n
	gen days_per_week4=s3q29o

gen family_labor_days1 = number_weeks1 * days_per_week1 
gen family_labor_days2 = number_weeks2 * days_per_week2
gen family_labor_days3 = number_weeks3 * days_per_week3
gen family_labor_days4 = number_weeks4 * days_per_week4

egen PPtotal_family_labor_days = rowtotal(family_labor_days*), missing // we aggregate total family days
replace PPtotal_family_labor_days=0 if s3q28==0

keep plot_id PPtotal_family_labor_days
duplicates drop

tempfile PPtotal_family_labor_days
save `PPtotal_family_labor_days', replace

// OTHER PP
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.


	rename s3q31a other_number_men
	gen other_man_days_av=s3q31b
	replace other_man_days_av=0 if other_number_men==0 // this still needs correcting
	gen PPother_man_days= other_man_days_av * other_number_men
	
	rename s3q31c other_number_women
	gen other_woman_days_av=s3q31d
	replace other_woman_days_av=0 if other_number_women==0 
	gen PPother_woman_days= other_woman_days_av * other_number_women
	
	rename s3q31e other_number_children
	gen other_child_days_av=s3q31f
	replace other_child_days_av=0 if other_number_children==0 
	gen PPother_child_days= other_child_days_av * other_number_children
	
	
egen PPtotal_other_labor_days= rowtotal(PPother_man_days PPother_woman_days PPother_child_days), missing

keep plot_id PPtotal_other_labor_days
duplicates drop

tempfile PPtotal_other_labor_days
save `PPtotal_other_labor_days', replace

// HIRED PH
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s9q00b crop_code

gen hired_number_man = s10q01a
gen hired_man_days_av=s10q01b  // Total number of days per man 
replace hired_man_days_av=0 if hired_number_man==0
gen PHhired_man_days1= hired_man_days_av * hired_number_man // = Variable of interest
	
gen hired_number_woman= s10q01d
gen hired_woman_days_av=s10q01e  
replace hired_woman_days_av=0 if hired_number_woman==0
gen PHhired_woman_days1= hired_woman_days_av * hired_number_woman  // = Variable of interest
	
gen hired_number_children = s10q01g
gen hired_child_days_av =s10q01h
replace hired_child_days_av=0 if hired_number_children==0
gen PHhired_child_days1= hired_child_days_av * hired_number_child // = Variable of interest
	
egen PHtotal_hired_labor_days_crop = rowtotal(PHhired_child_days1 PHhired_woman_days1 PHhired_man_days1), missing

		// calculate value
		gen PHhired_man_wage1= s10q01c
		replace PHhired_man_wage1 =. if hired_number_man==0 // This is to ensure that these observations are not counted when computing median wages
		
		gen PHhired_woman_wage1= s10q01f
		replace PHhired_woman_wage1 =. if hired_number_woman==0
		
		gen PHhired_child_wage1 = s10q01i
		replace PHhired_child_wage1 =. if hired_number_child==0
		
		valuation_median_wages household_id PHhired_man_wage1 PHhired_woman_wage1 PHhired_child_wage1
		
		gen PHman_labor_value_hired = man_wage * PHhired_man_days
		replace PHman_labor_value_hired = 0 if PHhired_man_days==0
		gen PHwoman_labor_value_hired = woman_wage * PHhired_woman_days
		replace PHwoman_labor_value_hired = 0 if PHhired_woman_days==0
		gen PHchild_labor_value_hired = child_wage * PHhired_child_days
		replace PHchild_labor_value_hired = 0 if PHhired_child_days==0
		egen PHtotal_hired_labor_value_crop = rowtotal( PHman_labor_value_hired PHwoman_labor_value_hired PHchild_labor_value_hired), missing
		
		rename (man_wage woman_wage child_wage ) (PHman_wage PHwoman_wage PHchild_wage )
		
		

keep plot_id PHtotal_hired_labor_days_crop PHtotal_hired_labor_value_crop crop_code PHman_wage PHwoman_wage PHchild_wage
duplicates drop
collapse (mean)  PHtotal_hired_labor_days_crop PHtotal_hired_labor_value_crop  PHman_wage PHwoman_wage PHchild_wage, by(crop_code plot_id)

tempfile PHtotal_hired_labor_days_crop
save `PHtotal_hired_labor_days_crop', replace


// FAMILY PH
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s9q00b crop_code

	gen number_weeks1=s10q02b
	gen days_per_week1=s10q02c
	gen number_weeks2=s10q02f
	gen days_per_week2=s10q02g
	gen number_weeks3=s10q02j
	gen days_per_week3=s10q02k
	gen number_weeks4=s10q02n
	gen days_per_week4=s10q02o
	
gen family_labor_days1_crop = number_weeks1 * days_per_week1 
gen family_labor_days2_crop = number_weeks2 * days_per_week2
gen family_labor_days3_crop = number_weeks3 * days_per_week3
gen family_labor_days4_crop = number_weeks4 * days_per_week4

egen PHtotal_family_labor_days_crop = rowtotal(family_labor_days*_crop), missing

keep plot_id PHtotal_family_labor_days_crop crop_code
duplicates drop
collapse (mean)  PHtotal_family_labor_days_crop, by(crop_code plot_id)
tempfile PHtotal_family_labor_days_crop
save `PHtotal_family_labor_days_crop', replace


// OTHER PH
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename s9q00b crop_code
	rename s10q03a other_number_men
	gen other_man_days_av=s10q03b
	replace other_man_days_av=0 if other_number_men==0 
	gen PHother_man_days1= other_man_days_av * other_number_men
	
	rename s10q03c other_number_women
	gen other_woman_days_av=s10q03d
	replace other_woman_days_av=0 if other_number_women==0 
	gen PHother_woman_days1= other_woman_days_av * other_number_women
	
	rename s10q03e other_number_children
	gen other_child_days_av=s10q03f
	replace other_child_days_av=0 if other_number_children==0 
	gen PHother_child_days1= other_child_days_av * other_number_children
	
egen PHtotal_other_labor_days_crop= rowtotal(PHother_man_days1 PHother_woman_days1 PHother_child_days1), missing

keep plot_id PHtotal_other_labor_days_crop crop_code
duplicates drop
collapse (mean)  PHtotal_other_labor_days_crop, by(crop_code plot_id)

tempfile PHtotal_other_labor_days_crop
save `PHtotal_other_labor_days_crop', replace

// put all together
use `PHtotal_hired_labor_days_crop', clear
merge 1:1 plot_id crop_code using `PHtotal_family_labor_days_crop', nogen
merge 1:1 plot_id crop_code using `PHtotal_other_labor_days_crop', nogen

foreach var of varlist PHtotal_hired_labor_days_crop PHtotal_family_labor_days_crop PHtotal_other_labor_days_crop PHtotal_hired_labor_value_crop { 
bys plot_id: egen `var'_p = total(`var'), missing
} 
	
merge m:1 plot_id using  `PPtotal_hired_labor_days', nogen
merge m:1 plot_id  using `PPtotal_family_labor_days', nogen
merge m:1 plot_id using `PPtotal_other_labor_days', nogen

egen total_labor_days = rowtotal(PHtotal_hired_labor_days_crop_p PHtotal_family_labor_days_crop_p PHtotal_other_labor_days_crop_p  PPtotal_other_labor_days PPtotal_family_labor_days PPtotal_hired_labor_days), missing

egen total_hired_labor_days = rowtotal(PHtotal_hired_labor_days_crop_p PPtotal_hired_labor_days), missing

egen total_family_labor_days = rowtotal(PHtotal_family_labor_days_crop_p PPtotal_family_labor_days)

egen hired_labor_value = rowtotal(PHtotal_hired_labor_value_crop_p PPtotal_hired_labor_value), missing
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days plot_id  total_family_labor_days total_hired_labor_days hired_labor_value
duplicates drop

save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
gen used_UREA = s3q21
replace used_UREA= 0 if s3q21==2
gen used_DAP = s3q22
replace used_DAP = 0 if s3q22==2
gen used_NPS = s3q23 
replace used_NPS=0 if s3q23==2 
recode s3q24 (1 = 1 "Yes") (2 = 0 "No"), gen(used_other_inorganic) label(used_other_inorganic)
gen inorganic_fertilizer= 1 if (used_NPS==1 | used_DAP==1 | used_UREA==1 | used_other_inorganic==1)
replace inorganic_fertilizer=0 if used_NPS==0 & used_DAP==0 & used_UREA==0 & used_other_inorganic==0
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
merge m:1 household_id  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen


gen UREA_kg = s3q21a
replace UREA_kg=0 if s3q21==2

gen DAP_kg = s3q22a
replace DAP_kg=0 if s3q22==2

gen  NPS_kg = s3q23a
replace NPS_kg=0 if s3q23==2
	
gen UREA_N_kg = UREA_kg*0.46
gen DAP_N_kg = DAP_kg*0.18 
gen NPS_N_kg = NPS_kg*0.19
egen nitrogen_kg = rowtotal(UREA_N_kg DAP_N_kg NPS_N_kg), missing
keep plot_id nitrogen_kg DAP_kg UREA_kg NPS_kg
duplicates drop
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
merge 1:1 plot_id using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(master match) nogen


gen UREA_purchased_kg = s3q21c  
gen UREA_purchased_value = s3q21d
		replace UREA_purchased_value=0 if s3q21==2 | s3q21b==2

gen DAP_purchased_kg = s3q22c 
gen DAP_purchased_value = s3q22d
destring DAP_purchased_value, replace
replace DAP_purchased_value=0 if s3q22==2 | s3q22b==2 

gen  NPS_purchased_kg = s3q23c
gen  NPS_purchased_value = s3q23d
replace NPS_purchased_value=0 if s3q23==2 | s3q23b==2

valuation_median_fert_price household_id UREA
gen value_UREA_total = UREA_value * UREA_kg

valuation_median_fert_price household_id DAP
gen value_DAP_total = DAP_value * DAP_kg

valuation_median_fert_price household_id NPS
gen value_NPS_total = NPS_value * NPS_kg

egen inorganic_fertilizer_value = rowtotal(value_UREA_total value_DAP_total value_NPS_total), missing

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace


// organic fert
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode s3q25 (1 = 1 "Yes") ( 2 = 0 "No"), gen(manure) label(manure)
recode s3q26 ( 1 = 1 "Yes") (2 = 0 "No"), gen(compost) label(compost)	
recode s3q27 (1 = 1 "Yes") (2 = 0 "No"), gen(other_organic) label(other_organic)
	
gen organic_fertilizer= 1 if (manure==1 | compost==1 | other_organic==1)
replace organic_fertilizer=0 if manure==0 & compost==0 & other_organic==0   // This dummy is equal to 0 for plots for which we are certain that there are no used fertilizer. 
keep plot_id organic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
rename s4q01b crop_code
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode s4q05 (1 = 1 "Yes") (2 = 0 "No"), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if s4q04==2  
collapse (max) used_pesticides, by(plot_id crop_code)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${parcel_roster}", clear
recode s2q05 ( 1 2 7 = 1 "Yes") (3 4 5 6 = 0 "No") (8=.) , gen(plot_owned) label(plot_owned) 
keep holder_id parcel_id plot_owned
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// plot ceertificate
use "${Input}\\${country}\\${wave}\\${parcel_roster}", clear
recode s2q03 (1 = 1 "Yes") (2= 0 "No"), gen(plot_certificate) label(plot_certificate)
keep holder_id parcel_id plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_certificate.dta", replace	

// irrigated
use "${Input}\\${country}\\${wave}\\${extra_ag}", clear
egen plot_id = concat(household_id field_id), punct("_")
recode s12cq08a (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
collapse (max) irrigated, by(plot_id)
tempfile ag_extension 
save `ag_extension', replace

use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode s3q17 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
merge m:1 plot_id using `ag_extension', 

keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace	


// erosion protection
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode s3q38 ( 1 = 1 "Yes") (2 = 0 "No"), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace	

// tractor
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode s3q35 (1 2 = 1 "Yes") (3/9 = 0 "No"), gen(tractor) label(tractor)
keep plot_id tractor
duplicates drop
save "${Temp}\\${temppath}\\tractor.dta", replace	

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode s3q03 (3 = 1) (. = . ) (* = 0), gen(fallow_plot)
bys household_id: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 household_id using "${Input}\\${country}\\${wave}\\${cover}", keepusing(household_id)
replace nb_fallow_plots= 0 if _merge ==2
keep household_id nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace	

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
bys household_id: egen nb_plots = count(s3q03)
merge m:1 household_id using "${Input}\\${country}\\${wave}\\${cover}", keepusing(household_id)
replace nb_plots= 0 if _merge ==2
keep household_id nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace	

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recode s2q04 ( 2 = 0 "No") (1 = 1 "Yes"), gen(formal_education) label(hh_primary_education)
recode s2q06 (  0/7 93/96 98 99 = 0 "No" ) (8/35 = 1 "Yes"), gen(education) label(education)
replace education = 0 if s2q04==2 // These individuals have never attended school	
bys household: egen hh_formal_education= max(formal_education) 
bys household: egen hh_primary_education= max(education) 
collapse (max) hh_formal_education hh_primary_education, by(household_id)	
keep household_id hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace	


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode s10aq34  (1/4 = 1 "Yes") (5/13 = 0 "No"), gen(hh_electricity_access)
keep household_id hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace	

// dependency ratio
use "${Input}\\${country}\\${wave}\\${household_roster}", clear
rename s1q03a age
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents
bysort household: egen dep=total(dep_temp)
bysort household: egen nondep=total(nondep_temp)
gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep if nondep==0
collapse (max) hh_dependency_ratio, by(household)
keep household_id hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace	

// livestock
use "${Input}\\${country}\\${wave}\\${cover_pc_pp}", clear
recode saq15 (2 3 =1 "Yes") (1 4 = 0 "No") , gen(livestock) label(livestock)
merge 1:m holder_id using "${Input}\\${country}\\${wave}\\${plot_roster}", nogen keep(match)

keep holder_id livestock
duplicates drop
save "${Temp}\\${temppath}\\livestock.dta", replace	

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
drop cons_quint
xtile cons_quint= nom_totcons_aeq, n(5)
keep household_id cons_quint
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace	

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
rename nom_totcons_aeq totcons
keep household_id totcons
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace	

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-")
rename s3q13 manager_id // The plot manager here is the holder


sort  household_id (manager_id)
collapse (first) manager_id household_id , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${household_roster}", clear
gen manager_id = individual_id  // this is the HH member id 
merge 1:m  household_id manager_id using `ID_list', keep(match) nogen
rename manager_id manager_id_temp
egen manager_id = concat (household manager_id_temp), punct("-")
recode  s1q02 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename s1q03a age_manager
recode s1q09 (2 3 = 1 "Yes") (1 4 5 6 7 = 0 "No"), gen(married_manager) 
keep household_id female_manager age_manager married_manager manager_id plot_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename individual_id  manager_id

merge 1:m  household_id manager_id using `ID_list', keep(match) nogen
recode s2q04 ( 2 = 0 "No" ) (1 = 1 "Yes"), gen(formal_education_manager) 
recode s2q06 (  0/7 93/96 98 99 = 0 "No" ) (8/35 = 1 "Yes"), gen(primary_education_manager) label(education)
replace primary_education_manager = 0 if s2q04==2
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace	

// respondent chars
use "${Input}\\${country}\\${wave}\\${parcel_roster}", clear
gen respondent_id = s2q01a 
keep  respondent holder_id parcel_id
tempfile ID_list_temp
save `ID_list_temp', replace
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
merge m:1  holder_id parcel_id using `ID_list_temp', keep(match) nogen
egen plot_id = concat(holder_id parcel_id field_id), punct("-") 

sort  household_id (respondent_id)
collapse (first) respondent_id household_id , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${household_roster}", clear
rename individual_id respondent_id // this is the HH member id 
merge 1:m  household_id respondent_id using `ID_list', keep(match) nogen
rename respondent_id respondent_id_temp
egen respondent_id = concat (household respondent_id_temp), punct("-")
recode  s1q02 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename s1q03a age_respondent
recode s1q09 (2 3 = 1 "Yes") (1 4 5 6 7 = 0 "No"), gen(married_respondent) 	
keep plot_id female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename individual_id respondent_id // this is the HH member id 
duplicates report household_id respondent_id // no duplicates
merge 1:m  household_id respondent_id using `ID_list', keep(match) nogen
recode s2q04 ( 2 = 0 "No" ) (1 = 1 "Yes"), gen(formal_education_respondent) 
recode s2q06 (  0/7 93/96 98 99 = 0 "No" ) (8/35 = 1 "Yes"), gen(primary_education_respondent) label(education)
replace primary_education_respondent = 0 if s2q04==2 
keep plot_id primary_education_respondent formal_education_respondent 
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace	

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode s9q01 (2=0 "No") (1 =1 "Yes" ), gen(hh_shock) label(hh_shock) // I only code negative shocks as 1 
replace hh_shock =0 if !inlist(2, s9q03a, s9q03b, s9q03c, s9q03d, s9q03e)
keep household_id hh_shock
collapse (max) hh_shock, by(household_id) 
save "${Temp}\\${temppath}\\hh_shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen hh_size = saq09
keep household_id hh_size
duplicates drop
save "${Temp}\\${temppath}\\hh_size.dta", replace	


// ag assets
use "${Input}\\${country}\\${wave}\\${assets}", clear
rename asset_cd item_code
keep if inlist(item_code, 15,16,29,30,31,32,33,34)
rename s11q01 d_
replace d_=0 if s11q00==2
replace d_=1 if d_>1 & !mi(d_)
keep household item_code d_
reshape wide d_ , i(household) j(item_code)
factor d_*, pcf 
predict ag_asset_index
drop d_*
keep household_id ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace


// hh assets
use "${Input}\\${country}\\${wave}\\${assets}", clear
keep if inlist(asset_cd, 15,16,29,30,31,32,33,34)
recode s11q00 ( 2 = 0 ) (1 = 1), gen (hh_owns) 
keep hh_owns household_id asset_cd
reshape wide hh_owns , i(household_id) j(asset_cd)
factor hh_owns*, pcf 
predict hh_asset_index
keep household_id hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
egen total = rowtotal(s12aq01_1 s12aq01_2 s12aq01_3 s12aq01_4 s12aq01_5 s12aq01_6 s12aq01_7 s12aq01_8)
gen nonfarm_enterprise = 0 if total==16
replace nonfarm_enterprise = 1 if total<16
keep household_id nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nonfarm_enterprise.dta", replace

// latitude
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename (lat_dd_mod lon_dd_mod) ( lat_modified lon_modified)
keep household_id lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ssa_aez09 agro_ecological_zone
keep household_id agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace

// distance to nearest market
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace

// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
rename afmnslp_pct plot_slope 
keep household_id plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot distance to hh (absent)

//  elevation
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename srtm_1k elevation 
keep household_id elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename twi_ne twi
keep household_id twi
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
rename	sq`n'_d `lab'
}

keep household_id  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace


// popdensity
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
keep household_id popdensity
tostring popdensity , replace
duplicates drop
save "${Temp}\\${temppath}\\popdensity.dta", replace

// indiv chars
use "${Input}\\${country}\\${wave}\\${household_roster}", clear
egen ID = concat(household_id individual_id), punct("-")

recode  s1q02 (2=1 "Yes") (1=0 "No"), gen(female) 
rename s1q03a age
recode s1q09 (2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married) 
replace married = 0 if married==.
decode s1q01, generate(relationship_head) 
replace relationship_head = substr(relationship_head,strpos(relationship_head, " " ) + 1, .)
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head== "Father/month-in-Law"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head== "Son/Daughter-in-Law"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head== "Brother/Sister-in-Law"

keep household_id ID individual_id married female age relationship_head
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace

// wasting
use "${Input}\\${country}\\${wave}\\${health}", clear
merge 1:1 household_id individual_id using "${Input}\\${country}\\${wave}\\${household_roster}", keep(master match) nogen keepusing(s1q03b)
egen ID = concat(household_id individual_id), punct("-")

merge 1:1 household_id individual_id using "${Temp}\\${temppath}\\indiv_chars.dta",  keep(master match) nogen

*Main anthropometric variables
gen weight=s3q37
gen height=s3q38
replace height=. if height>200

gen cage=age*12
replace cage = s1q03b if age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  household_id individual_id weight height ID
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen ID = concat(household_id individual_id), punct("-")

recode s4q05 (1 = 1) (2=0) , gen(farm_work)
recode s4q08 (1 = 1) (2=0) , gen( SOB_work)
recode s4q12 (1 = 1) (2=0) , gen( wage_work)


// nb of working age members

gen working_age = s4q00==1 
bys household_id: egen nb_members_working_age = total(working_age)


// industry:
gen 	ind_ag = s4q34d == 1  // Agriculture 
gen 	ind_fish = s4q34d == 2	// fishing
gen 	ind_mining = s4q34d == 3	// mining
gen 	ind_manuf = s4q34d == 4 | s4q34d == 5	// manuf
gen 	ind_const = s4q34d == 6	// construc
gen 	ind_serv = s4q34d >= 7 & s4q34d<= 18	// services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if s4q33b==2 
}


rename (s4q06 s4q09 s4q13 ) (farm_hrs SB_hrs wage_hrs )

foreach var in farm_hrs SB_hrs wage_hrs farm_work SOB_work wage_work ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if working_age==0
}

keep ID individual_id household_id farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat(household_id individual_id), punct("-")

recode s2q04 ( 2 = 0 "No") (1 = 1 "Yes"), gen(formal_education) label(hh_primary_education)
recode s2q06 (  0/7 93/96 98 99 = 0 "No" ) (8/35 = 1 "Yes"), gen(primary_education) label(education)
foreach var in formal_education primary_education {
	replace `var' = 0  if s2q00==2
	replace `var' = 0  if s2q04==2
}
keep individual_id household_id formal_education primary_education ID
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace

// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if s6aq01 ==1 // keep if consumed

gen A = item_cd>=101 | item_cd<=109 | item_cd>=901 & !mi(item_cd)
gen B = item_cd>=601 | item_cd<=610
gen C = item_cd>=401 | item_cd<=409
gen D = item_cd>=501 | item_cd<=509
gen E = item_cd>=701 | item_cd<=703 | item_cd==714
gen F = item_cd==704
gen G = item_cd==705
gen H = item_cd>=201 | item_cd<=211
gen I = item_cd==706
gen J = item_cd==707 | item_cd==708
gen K = item_cd==710 | item_cd==711
gen L = item_cd==712 | item_cd==713 | item_cd>=801 & item_cd<=806 | item_cd>=301 & item_cd<=305

collapse (max) A B C D E F G H I J K L, by(household_id)
 egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m household_id  using "${Input}\\${country}\\${wave}\\${HDDS}", 

collapse (max) HDDS, by(household_id)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace

