/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Extract data for NER1          *
 * Date: December 2023                                                            *
 * -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Niger
global wave  ECVMA 11
global cover  ecvmasection00_p1.dta
global cover2  ecvmasection00_p2_en.dta
global indiv_roster  ecvmaind_p1p2.dta
global lab_roster ecvmaas1_p1.dta
global lab_roster2  ecvmaas1_p2.dta
global shocks ecvmachoc_p1.dta
global housing  ecvmamen_p1_en.dta
global plot_roster  ecvmaas1_p1.dta
global plot_inputs ecvmaas2b_p1.dta
global seeds ecvmaas2c_p1.dta
global ferts ecvmaas1_p1_en.dta

global items ecvmaas06_p2.dta
global harvest_rwdta  ecvmaas2e_p2_en.dta
global perennial  ecvmaas05_p2.dta
global geovars_hh NER_HouseholdGeovars_Y1.dta
global geovars_plot NER_PlotGeovariables_Y1.dta
global livestock ecvmaas4a_p2.dta
global welfare ECVMA2011_Welfare_en.dta
global coords NER_EA_Offsets.dta
global HDDS ecvmaali_p1_en.dta

global temppath NER\ECVMA11


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if as05q02==.
rename as05q02 crop_code
decode crop_code, gen(crop_name2)

sort hid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str
gen parcel_id2 = "missing_line_" + n_str

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
egen parcel_id = concat(hid as02eq01), punct("-")
rename as02eq06 crop_code
decode crop_code, gen(crop_name)

merge m:1 hid crop_code using `perennial', 

replace plot_id = plot_id2 if _merge==2
replace parcel_id = parcel_id2 if _merge==2
replace crop_name = crop_name2 if _merge==2 

keep hid plot_id crop_name crop_code   crop_name parcel_id

duplicates drop

duplicates report plot_id crop_code crop_name parcel_id
save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear

keep hid 
duplicates report hid 

save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

egen ID = concat (hid  ms01q00), punct("-")
keep hid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear 
merge 1:m hid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}", nogen
egen ea_id = concat(ms00q10 ms00q11 ms00q12  ms00q14), punct("-")
keep hid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${welfare}", clear 
merge 1:1 grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen
rename strate strataid
keep hid strataid  
merge 1:1 hid using "${Temp}\\${temppath}\\ea_id.dta", nogen
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m hid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}", nogen

rename ms00q10 admin_1 
keep hid admin_1
decode admin_1, gen(admin_1_name)

duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m hid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}",  nogen

rename ms00q11 admin_2 
keep hid admin_2
decode admin_2, gen(admin_2_name)
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m hid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}", nogen
rename ms00q12 admin_3
keep hid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
recode ms00q15 (1 2 = 1 "Yes") (3 = 0 "No"), gen(urban) label(urban)
keep hid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${housing}", clear
rename hhweight pw
keep pw hid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

egen plot_id= concat(hid as02bq01 as02bq03) , punct("-")
rename as02bq06 crop_code

gen month = as02bq11
format month %tm 

gen year = 2011 
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(hid crop_code plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month (absent)


// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear

gen month_harvest = as00q03am
format month_harvest %tm 
gen year_harvest = 2011
format year_harvest %ty  

gen harvest_interview_month = ym( year_harvest, month_harvest)
format harvest_interview_month %tmCCYYMon

keep hid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear

gen month_planting = as00q03am
format month_planting %tm 
gen year_planting = 2011
format year_planting %ty 

gen planting_interview_month = ym( year, month)
format planting_interview_month %tmCCYYMon
duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename (as02eq06 ms00q10 as02eq07b) (crop_code region unit)
gen conversion = as02eq07c / as02eq07a
keep hid region unit crop_code conversion

bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0
collapse (median) conversion (sd) sd = conversion, by(unit)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if as05q02==.
rename as05q02 crop_code
recode as05q06b (1 = 1) (3 = 9 ) (4=5) (5 = 6) (6 = 7) (7 = 8), gen(unit)
merge m:1 unit using `Conversion_factors', nogen keep(master match)
gen harvest_kg_per = as05q05 * as05q06a * conversio

sort hid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str
drop n 

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
merge m:1 hid using "${Temp}\\${temppath}\\admin1", keep(master match) nogen
merge m:1 hid using "${Temp}\\${temppath}\\admin2", keep(master match) nogen
merge m:1 hid using "${Temp}\\${temppath}\\admin3", keep(master match) nogen

egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code
merge m:1 crop_code hid using `perennial'
replace plot_id = plot_id2 if _merge==2

gen harvest_kg = as02eq07c
replace harvest_kg=. if as02eq07b==99
replace harvest_kg = . if as02eq07c== 999999
replace harvest_kg=0 if as02eq07a==0
replace harvest_kg = harvest_kg_per if _merge==2

recode as02eq08 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(crop_shock) label(crop_shock)
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
rename ms00q14 ea_id

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id crop_code  hid admin_1 admin_2 admin_3 hid )
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code

gen pct_area_harvested = (100 - as02eq09)
replace pct_area_harvested = . if as02eq09==999
replace pct_area_harvested= 100 if as02eq08==2
keep hid plot_id crop_code pct_area_harvested
duplicates drop
save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code

recode as02eq08 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(crop_shock) label(crop_shock)
 
recode as02eq10 (3 = 1 "Yes") (. 9 = .) (else = 0 "No"), gen(drought_shock) label(drought_shock) 
replace drought_shock=0 if as02eq08==2

recode as02eq10 (4 = 1 "Yes") (. 9 = .) (else = 0 "No"), gen(flood_shock) label(flood_shock) 
replace flood_shock=0 if as02eq08==2

recode as02eq10 (1 = 1 "Yes") (. 9 = .) (else = 0 "No"), gen(pests_shock) label(pests_shock) 
replace pests_shock=0 if as02eq08==2

gen pct_area_harvested = (100 - as02eq09)
replace pct_area_harvested = . if as02eq09==999
replace pct_area_harvested= 100 if as02eq08==2
gen pct_lost = 100 - pct_area_harvested
replace pct_lost = pct_lost/ 100 

collapse (mean) pct_lost (max) pests_shock  drought_shock flood_shock crop_shock, by(hid plot_id crop_code)
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename (as02eq06 ms00q10 as02eq07b) (crop_code region unit)
gen conversion = as02eq07c / as02eq07a
keep hid region unit crop_code conversion

bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0
collapse (median) conversion (sd) sd = conversion, by(unit)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if as05q02==.
rename as05q02 crop_code
recode as05q06b (1 = 1) (3 = 9 ) (4=5) (5 = 6) (6 = 7) (7 = 8), gen(unit)
merge m:1 unit using `Conversion_factors', nogen keep(master match)
gen harvest_sold_kg_per = as05q09 * conversion

sort hid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str
drop n 

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code

gen harvest_sold_kg = as02eq12c 
replace harvest_sold_kg = 0 if as02eq11==2
replace harvest_sold_kg = 0 if as02eq12a==0
collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by(plot_id crop_code hid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge m:1 crop_code hid using `perennial'

replace plot_id = plot_id2 if _merge==2

replace harvest_sold_kg = harvest_sold_kg_per if _merge==2

save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(hid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m hid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(hid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep hid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace


// harvest sold value
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if as05q02==.
rename as05q02 crop_code
gen harvest_sold_value_per = as05q10

sort hid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str
drop n

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code
merge m:1 crop_code hid using `perennial'

replace plot_id = plot_id2 if _merge ==2 

gen harvest_sold_value = as02eq13 
replace harvest_sold_value = harvest_sold_value_per if _merge==2
collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by(plot_id crop_code hid)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if as05q02==.
rename as05q02 crop_code

sort hid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code
merge m:1 crop_code hid using `perennial'

replace plot_id = plot_id2 if _merge ==2 

keep hid  crop_code  plot_id
duplicates drop


valuation_median_crops_noea hid  plot_id  crop_code

main_crop_def crop_code


keep hid plot_id  harvest_value crop_code main_crop 
duplicates drop
save "${Temp}\\${temppath}\\harvest_value.dta", replace

// intercropped
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id= concat(hid as02bq01 as02bq03) , punct("-")
rename as02bq06 crop_code
recode as02bq07 (0 9 = .) (1= 0 "No") (2=1 "Yes"), gen(intercropped) label(intercropped)
keep crop_code plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if as05q02==.
rename as05q02 crop_code

sort hid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hid as02eq01 as02eq03), punct("-")
rename as02eq06 crop_code
merge m:1 crop_code hid using `perennial'

replace plot_id = plot_id2 if _merge==2

merge m:1 crop_code plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)


gen codesmain_crop = main_crop
gen codescrop_code = crop_code
foreach c in main_crop crop_code {
lab val `c' as02eq06
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2
replace `c' = strupper(`c')
replace `c' = "TOMATOES" if `c' =="TOMATO"
replace `c' = "GROUNDNUTS" if `c' =="PEANUT"

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"COWPEAS", "GROUNDNUTS", "SOY", "BEANS", "PEA", "PEANUTS", "VOANDZOU", "GREEN PEAS")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"POTATO", "SWEET POTATO", "CASSAVA", "YAMS", "CARROT", "BEETS", "TARO", "SOUCHET")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE"
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "MAIZE" if `c'=="MAIZE"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "MILLET" if `c'=="MILLET" | `c'=="FONIO"
replace `c'2 = "NUTS" if `c'=="NUTS"
replace `c'2 = "BEANS AND OTHER LEGUMES" if codes`c'==10
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if codes`c'>50 & !mi(codes`c')
drop `c'
rename `c'2 `c'
}
tab crop_code, gen(contains_crop_)



foreach n in  9 8 7 6 5 4  {
local i = `n' + 2
rename contains_crop_`n' contains_crop_`i'
}

foreach n in 3 2 1  {
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

collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace


// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat(hid as01q03 as01q05), punct("-")

gen area_self_reported = as01q08 * 0.0001 // m² to hectares 
replace area_self_reported = . if as01q08 == 999999

gen plot_area_GPS= as01q09 * 0.0001 // m² to hectares
replace plot_area_GPS = . if as01q09 == 999999
replace plot_area_GPS = . if plot_area_GPS == 0 // many are 0 

merge m:1 hid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid hid plot_id
sort hid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
mi impute pmm plot_area_GPS area_self_reported i.admin_3, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys hid: egen farm_size = total(plot_area_GPS), missing

keep hid plot_id   plot_area_GPS farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id= concat(hid as02bq01 as02bq03) , punct("-")
rename as02bq06 crop_code
merge m:1 plot_id using "${Temp}\\${temppath}\\plot_area.dta", keep(master match)
replace as02bq08 = . if as02bq08==999999
gen pct_area_planted = (as02bq08/(plot_area *10000))*100
replace pct_area_planted = . if pct_area_planted>100 
replace pct_area_planted = 0 if pct_area_planted<1
collapse (mean) pct_area_planted , by(plot_id hid crop_code)  
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace


// improved 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id= concat(hid as02bq01 as02bq03) , punct("-")
rename as02bq06 crop_code
recode as02bq09 (0 9 = .) (1 2 = 0 "No") (3 4 = 1 "Yes"), gen(improved) label(improved)
collapse (max) improved, by(hid plot_id crop_code)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename (as02eq06 ms00q10 as02eq07b) (crop_code region unit)
gen conversion = as02eq07c / as02eq07a
keep hid region unit crop_code conversion

bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0
collapse (median) conversion (sd) sd = conversion, by(unit)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename as02cq04 crop_code
keep if inlist(as02cq02, 11, 12, 13, 14, 15, 16, 17) // keep seeds
recode as02cq05b (1 = 1) (6 = 5) (else=.), gen(unit) 
merge m:1 unit using `Conversion_factors', keep(master match)  
gen seed_kg = as02cq05a * conversion
replace seed_kg = as02cq05a  if as02cq05b==1 
replace seed_kg = as02cq05a if as02cq05b==8 // litre
replace seed_kg = as02cq05a * 5 if as02cq05b==2
replace seed_kg = as02cq05a * 10 if as02cq05b==3
replace seed_kg = as02cq05a * 25 if as02cq05b==4
replace seed_kg = as02cq05a * 50 if as02cq05b==5
replace seed_kg = 0 if as02cq03==2

collapse  (sum) seed_kg (count) n_seed_kg = seed_kg , by(hid crop_code)
replace seed_kg = . if n_seed_kg==0
tempfile seed_hh 
save `seed_hh', replace

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename (ms00q10 ms00q11 ms00q12) (admin_1 admin_2 admin_3)
egen plot_id= concat(hid as02bq01 as02bq03) , punct("-")
rename as02bq06 crop_code
collapse (max) hid, by(plot_id crop_code admin_1 admin_2 admin_3)
merge m:1 hid crop_code using `seed_hh', keep(master match) nogen
merge m:1 plot_id using "${Temp}\\${temppath}\\plot_area.dta", keep(master match) nogen
bys hid crop_code: egen total_land_area = total(plot_area), missing
gen indicator = plot_area/total_land_area
replace seed_kg= seed_kg*indicator 
keep hid plot_id crop_code seed_kg admin_1 admin_2 admin_3
save "${Temp}\\${temppath}\\seed_kg.dta", replace
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace


// seed_kg_sold 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
drop if ms00q05==.
rename as02cq04 crop_code

keep if inlist(as02cq02, 11, 12, 13, 14, 15, 16, 17) & as02cq03==1 // keep seeds
recode as02cq05b (1 = 1) (6 = 5) (else=.), gen(unit) 
merge m:1 unit using `Conversion_factors', keep(master match) nogen 
gen seeds_amount_purchased_kg = as02cq08a * conversion
replace seeds_amount_purchased_kg = as02cq08a  if as02cq05b==1 
replace seeds_amount_purchased_kg = as02cq08a if as02cq05b==8 // litre
replace seeds_amount_purchased_kg = as02cq08a * 5 if as02cq05b==2
replace seeds_amount_purchased_kg = as02cq08a * 10 if as02cq05b==3
replace seeds_amount_purchased_kg = as02cq08a * 25 if as02cq05b==4
replace seeds_amount_purchased_kg = as02cq08a * 50 if as02cq05b==5

collapse (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg = seeds_amount_purchased_kg, by(crop_code hid)
replace seeds_amount_purchased_kg = . if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
drop if ms00q05==.
rename as02cq04 crop_code

gen seed_value_temp = as02cq08b

collapse  (sum) seed_value_temp (count) n_seed_value_temp = seed_value_temp , by(crop_code hid )
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear

rename as02cq04 crop_code
keep hid  crop_code

duplicates drop

val_median_seeds_noimp_noea hid hid crop_code 

keep  plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

use "${Input}\\${country}\\${wave}\\${lab_roster}", clear

egen plot_id = concat(hid as01q03 as01q05), punct("-")

* 1) Family labor 

foreach var of varlist as02aq20b as02aq21b as02aq22b as02aq23b as02aq24b as02aq25b{
    replace `var'=. if `var'==99
}
egen PPtotal_family_labor_days = rowtotal(as02aq20b as02aq21b as02aq22b as02aq23b as02aq24b as02aq25b), missing

* 2) Hired labor days
 
gen hired_man_days = as02aq27b
replace hired_man_days=. if hired_man_days==999

gen hired_woman_days = as02aq27c
replace hired_woman_days=. if hired_woman_days==999

gen hired_child_days = as02aq27d
replace hired_child_days=. if hired_child_days==999


egen PPtotal_hired_labor_days= rowtotal(hired_man_days hired_woman_days hired_child_days), missing
replace PPtotal_hired_labor_days=0 if as02aq27a==2

gen wage_h = as02aq27e 
replace wage_h=. if as02aq27e==999999
gen wage_w = as02aq27e 
replace wage_w=. if as02aq27e==999999
gen wage_c = as02aq27e 
replace wage_c=. if as02aq27e==999999

valuation_median_wages hid wage_h wage_w wage_c

gen man_labor_value = man_wage * hired_man_days
gen woman_labor_value = woman_wage * hired_woman_days
gen child_labor_value = child_wage * hired_child_days
egen PPhired_labor_value = rowtotal (*_labor_value), missing


* 3) Other (free) labor

gen other_man_days = as02aq26b
replace other_man_days=. if other_man_days==999

gen other_woman_days = as02aq26c
replace other_woman_days=. if other_woman_days==999

gen other_child_days = as02aq26d
replace other_child_days=. if other_child_days==999

egen PPtotal_other_labor_days= rowtotal(other_man_days other_woman_days other_child_days), missing
replace PPtotal_other_labor_days=0 if as02aq26a==2

* 4) Total labor days

egen PPtotal_labor_days = rowtotal(PPtotal_hired_labor_days PPtotal_family_labor_days PPtotal_other_labor_days), missing


tempfile PPtotal_labor_days 
save `PPtotal_labor_days', replace 

// PH labor

use "${Input}\\${country}\\${wave}\\${lab_roster2}", clear

egen plot_id = concat(hid as01q03 as01q05), punct("-")

* 1) Family labor 

foreach var of varlist as02aq28b as02aq29b as02aq30b as02aq31b as02aq32b as02aq33b as02aq36b as02aq37b as02aq38b as02aq39b as02aq40b as02aq41b {
    replace `var'=. if `var'==99
}
egen PHtotal_family_labor_days = rowtotal(as02aq28b as02aq29b as02aq30b as02aq31b as02aq32b as02aq33b as02aq36b as02aq37b as02aq38b as02aq39b as02aq40b as02aq41b), missing

* 2) Hired labor 

gen hired_man_days1 = as02aq35b
replace hired_man_days1=. if hired_man_days1==999

gen hired_man_days2 = as02aq43b
replace hired_man_days2=. if hired_man_days2==999

gen hired_woman_days1 = as02aq35c
replace hired_woman_days1=. if hired_woman_days1==999

gen hired_woman_days2 = as02aq43c
replace hired_woman_days2=. if hired_woman_days2==999

gen hired_child_days1 = as02aq35d
replace hired_child_days1=. if hired_child_days1==999

gen hired_child_days2 = as02aq43d
replace hired_child_days2=. if hired_child_days2==999
egen PHtotal_hired_labor_days1= rowtotal(hired_*1), missing
replace PHtotal_hired_labor_days1=0 if as02aq35a==2
egen PHtotal_hired_labor_days2= rowtotal(hired_*1), missing
replace PHtotal_hired_labor_days2=0 if as02aq43a==2

egen PHtotal_hired_labor_days = rowtotal(PHtotal_hired_labor_days*), missing

gen wage1_m = as02aq35e 
replace wage1_m=. if as02aq35e==999999
gen wage1_w = as02aq35e 
replace wage1_w=. if as02aq35e==999999
gen wage1_c = as02aq35e 
replace wage1_c=. if as02aq35e==999999

gen wage2_m = as02aq43e 
replace wage2_m=. if as02aq43e==999999
gen wage2_w = as02aq43e 
replace wage2_w=. if as02aq43e==999999
gen wage2_c = as02aq43e 
replace wage2_c=. if as02aq43e==999999

valuation_median_wages hid wage1_m wage1_w wage1_c

gen man_labor_value = man_wage * hired_man_days1
gen woman_labor_value = woman_wage * hired_woman_days1
gen child_labor_value = child_wage * hired_child_days1
egen PHhired_labor_value1 = rowtotal (*_labor_value), missing
drop man_wage woman_wage child_wage ten_obs_EA_man ten_obs_EA_woman ten_obs_EA_child ten_obs_admin3_man ten_obs_admin3_woman ten_obs_admin3_child ten_obs_admin2_man ten_obs_admin2_woman ten_obs_admin2_child ten_obs_admin1_man ten_obs_admin1_woman ten_obs_admin1_child ten_obs_n_man ten_obs_n_woman ten_obs_n_child man_wage_woreda woman_wage_woreda child_wage_woreda man_wage_zone woman_wage_zone child_wage_zone man_wage_region woman_wage_region child_wage_region man_wage_national woman_wage_national child_wage_national man_labor_value woman_labor_value child_labor_value

valuation_median_wages hid wage2_m wage2_w wage2_c

gen man_labor_value = man_wage * hired_man_days2
gen woman_labor_value = woman_wage * hired_woman_days2
gen child_labor_value = child_wage * hired_child_days2
egen PHhired_labor_value2 = rowtotal (*_labor_value), missing
egen PHhired_labor_value = rowtotal (PHhired_labor_value1 PHhired_labor_value2), missing

* 3) Other  labor 

gen other_man_days1 = as02aq34b
replace other_man_days1=. if other_man_days1==999

gen other_man_days2 = as02aq42b
replace other_man_days2=. if other_man_days2==999

gen other_woman_days1 = as02aq34c
replace other_woman_days1=. if other_woman_days1==999

gen other_woman_days2 = as02aq42c
replace other_woman_days2=. if other_woman_days2==999

gen other_child_days1 = as02aq34d
replace other_child_days1=. if other_child_days1==999

gen other_child_days2 = as02aq42d
replace other_child_days2=. if other_child_days2==999

egen PHtotal_other_labor_days1= rowtotal(other_*1), missing
replace PHtotal_other_labor_days1=0 if as02aq34a==2

egen PHtotal_other_labor_days2= rowtotal(other_*2), missing
replace PHtotal_other_labor_days2=0 if as02aq42a==2

egen PHtotal_other_labor_days= rowtotal(PHtotal_other_labor_days*), missing


tempfile PHtotal_labor_days 
save `PHtotal_labor_days', replace 

// put all together
use `PHtotal_labor_days', clear
merge 1:1 plot_id  using `PPtotal_labor_days', nogen

egen total_labor_days = rowtotal(PHtotal_hired_labor_days PHtotal_family_labor_days PHtotal_other_labor_days  PPtotal_other_labor_days PPtotal_family_labor_days PPtotal_hired_labor_days), missing

egen total_hired_labor_days = rowtotal(PHtotal_hired_labor_days PPtotal_hired_labor_days), missing

egen total_family_labor_days = rowtotal(PHtotal_family_labor_days PPtotal_family_labor_days)

egen hired_labor_value = rowtotal(PHhired_labor_value PPhired_labor_value), missing
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value 
duplicates drop

save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id= concat(hid as01q03 as01q05) , punct("-")
recode as02aq10 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename (as02eq06 ms00q10 as02eq07b) (crop_code region unit)
gen conversion = as02eq07c / as02eq07a
keep hid region unit crop_code conversion

bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0
collapse (median) conversion (sd) sd = conversion, by(region unit)
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${ferts}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen plot_id= concat(hid as01q03 as01q05) , punct("-")
rename ms00q10 region
recode as02aq10 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
recode as02aq11b (6 = 5) (else=.), gen(unit) // converting tiya

* UREA
merge m:1 region unit using `Conversions', keep(master match) nogen 
gen UREA_kg = as02aq11a * conversion
replace UREA_kg = as02aq11a * 5 if as02aq11b==2
replace UREA_kg = as02aq11a * 10 if as02aq11b==3
replace UREA_kg = as02aq11a * 25 if as02aq11b==4
replace UREA_kg = as02aq11a * 50 if as02aq11b==5
replace UREA_kg = 0 if as02aq10==2
gen nitrogen_kg1 = UREA_kg * 0.46
drop conversion

* DAP 
merge m:1 region unit using `Conversions', keep(master match) nogen 
gen DAP_kg = as02aq12a * conversion
replace DAP_kg = as02aq12a * 5 if as02aq12b==2
replace DAP_kg = as02aq12a * 10 if as02aq12b==3
replace DAP_kg = as02aq12a * 25 if as02aq12b==4
replace DAP_kg = as02aq12a * 50 if as02aq12b==5
replace DAP_kg = 0 if as02aq10==2
gen nitrogen_kg2 = DAP_kg * 0.18
drop conversion

* NPK 
merge m:1 region unit using `Conversions', keep(master match) nogen 
gen NPK_kg = as02aq13a * conversion
replace NPK_kg = as02aq13a * 5 if as02aq13b==2
replace NPK_kg = as02aq13a * 10 if as02aq13b==3
replace NPK_kg = as02aq13a * 25 if as02aq13b==4
replace NPK_kg = as02aq13a * 50 if as02aq13b==5
replace NPK_kg = 0 if as02aq10==2
gen nitrogen_kg3 = NPK_kg * 0.15
drop conversion
 
egen nitrogen_kg = rowtotal(nitrogen_kg*), missing
replace nitrogen_kg= 0 if inorganic_fertilizer==0


collapse (sum) nitrogen_kg  UREA_kg DAP_kg NPK_kg  (count) n_nitrogen_kg = nitrogen_kg n_NPK_kg = NPK_kg n_DAP_kg = DAP_kg n_UREA_kg = UREA_kg  , by(plot_id hid)
foreach var in nitrogen_kg NPK_kg DAP_kg UREA_kg    {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}", nogen
rename ( ms00q14 ms00q10 ms00q11 ms00q12) ( ea region departement commune)
rename as02cq04 crop_code

// amount purchased and value
gen t = "NPK" if as02cq02==5 // this variable is created to create conditions in the loop below
replace t = "UREA" if as02cq02==3
replace t = "DAP" if as02cq02==4

recode as02cq05b (1 = 1) (6 = 5) (else=.), gen(unit)  
merge m:1 region unit using `Conversions', keep(master match) nogen

foreach n in NPK UREA DAP {
gen `n'_purchased_kg = as02cq08a * conversion
replace `n'_purchased_kg = as02cq08a  if as02cq05b==1 & t=="`n'"
replace `n'_purchased_kg = as02cq08a if as02cq05b==8 & t=="`n'" // litre
replace `n'_purchased_kg = as02cq08a * 5 if as02cq05b==2 & t=="`n'"
replace `n'_purchased_kg = as02cq08a * 10 if as02cq05b==3 & t=="`n'"
replace `n'_purchased_kg = as02cq08a * 25 if as02cq05b==4 & t=="`n'"
replace `n'_purchased_kg = as02cq08a * 50 if as02cq05b==5 & t=="`n'"

gen `n'_purchased_value = as02cq08b if t=="`n'"
}

collapse (max) UREA_purchased_kg DAP_purchased_kg NPK_purchased_kg  UREA_purchased_value DAP_purchased_value NPK_purchased_value  , by(hid)

valuation_median_fert_price hid UREA

valuation_median_fert_price hid DAP

valuation_median_fert_price hid NPK


collapse (sum) UREA_value DAP_value NPK_value , by(hid) 
merge 1:m hid using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

foreach n in NPK UREA DAP  {
    gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id= concat(hid as01q03 as01q05) , punct("-")
recode as02aq06 (1= 1 "Yes") (9=.) (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id= concat(hid as01q03 as01q05) , punct("-")
recode as02aq16a (0 = 0 "No") (. = .) (else = 1 "Yes"), gen(used_pesticides) label(used_pesticides)
replace used_pesticides = 0 if as02aq15==2
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen plot_id = concat(hid as01q03 as01q05), punct("-")
recode as01q16 (1 3 = 1 "Yes") (2 4 5 = 0 "No") , gen(plot_owned) label(plot_owned)
recode as01q18 (1/4 = 1 "Yes") (5 = 0 "No") (9 = .), gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace


// irrigated
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen plot_id = concat(hid as01q03 as01q05), punct("-")
recode  as01q39 (5 = 0 "No") (. 7=.) (else = 1 "Yes"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace


// erosion protection
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen plot_id = concat(hid as01q03 as01q05), punct("-")
recode as01q27 (2 = 0 "No") (1 = 1 "Yes") (. 9 = .), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
gen tractor= 1 if as06q02==10 & as06q09==1 
replace tractor= 1 if as06q02==10 & as06q12==1 
replace tractor= 0 if as06q02==10 & as06q03==2
replace tractor= 0 if as06q02==10 & as06q03==1 & as06q09==2 & as06q12==2
replace tractor= 0 if as06q02==.
collapse (max) tractor , by(hid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}"
egen plot_id = concat(hid as01q03 as01q05), punct("-")
recode as01q41 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
replace fallow_plot= 0 if as01q40==1
bys hid: egen nb_fallow_plots = total(fallow_plot), missing
replace nb_fallow_plots = 0 if _merge==2
keep hid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
merge m:1 hid using "${Input}\\${country}\\${wave}\\${cover}"
egen plot_id = concat(hid as01q03 as01q05), punct("-")
recode as01q41 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
replace fallow_plot= 0 if as01q40==1
bys hid: egen nb_plots = count(fallow_plot)
replace nb_plots = 0 if _merge==2
keep hid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

recode ms02q04 (1 =1 "Yes") (2/4 = 0 "No") (9 = .), gen(formal_education) label(formal_education)
recode ms02q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education=1 if inlist(ms02q23, 3, 4, 5, 6, 7)
replace primary_education=0 if inlist(ms02q23, 1, 2)
replace primary_education= 0 if formal_education==0

bys hid: egen hh_primary_education= max(primary_education) 
bys hid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(hid)
keep hid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode ms06q26 (1 2 = 1 "Yes") (else = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
keep hid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

rename ms01q06a age 
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort hid: egen dep=total(dep_temp)
bysort hid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep if nondep==0
collapse (max) hh_dependency_ratio, by(hid)
keep hid hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
merge m:1 hid passage grappe using "${Input}\\${country}\\${wave}\\${cover}", 
recode as4aq05 ( 2 . = 0 "No") (1 = 1 "Yes"), gen(livestock) label(livestock)
collapse (max) livestock, by(hid) 
save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint
use "${Input}\\${country}\\${wave}\\${welfare}", clear
merge 1:1 grappe menage using "${Input}\\${country}\\${wave}\\${housing}", nogen
xtile cons_quint= pcexp, n(5)
keep hid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${welfare}", clear
merge 1:1 grappe menage using "${Input}\\${country}\\${wave}\\${housing}", nogen
rename pcexp totcons
keep hid totcons 
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
keep if ms01q02==1
keep hid  ms01q00
merge 1:m hid  using "${Input}\\${country}\\${wave}\\${lab_roster}", keep(match using) nogen
egen plot_id = concat(hid as01q03 as01q05), punct("-")
gen  manager_id = as01q47
replace manager_id = ms01q00 if manager_id==98
sort  hid (manager_id)
collapse (first) manager_id hid , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = ms01q00  // this is the HH member id 
merge 1:m  hid manager_id using `ID_list', keep(match using) nogen
rename manager_id id
egen manager_id = concat (hid id ), punct("-")
recode ms01q01 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename ms01q06a age_manager
recode ms01q15 ( 2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

gen manager_id = ms01q00  // this is the HH member id 
merge 1:m  hid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hid id ), punct("-")
recode ms02q04 (1 =1 "Yes") (2/4 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode ms02q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager=1 if inlist(ms02q23, 3, 4, 5, 6, 7)
replace primary_education_manager=0 if inlist(ms02q23, 1, 2)
replace primary_education_manager= 0 if formal_education_manager==0
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${cover}", clear
duplicates report hid // one duplicate
rename ms00q24 respondent_id 
sort  hid (respondent_id)
collapse (first) respondent_id, by(hid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename ms01q00 respondent_id // this is the HH member id 
merge 1:m  hid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hid id ), punct("-")
recode ms01q01 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename ms01q06a age_respondent
recode ms01q15 ( 2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married_respondent) 
keep hid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen respondent_id = ms01q00  // this is the HH member id 
merge 1:m  hid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hid id ), punct("-")
recode ms02q04 (1 =1 "Yes") (2/4 = 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode ms02q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent=1 if inlist(ms02q23, 3, 4, 5, 6, 7)
replace primary_education_respondent=0 if inlist(ms02q23, 1, 2)
replace primary_education_respondent= 0 if formal_education_respondent==0
keep hid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode ms11q02 (2= 0 "No") (1 = 1 "Yes"), gen(hh_shock) 
collapse (max) hh_shock, by(hid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
bys hid: egen hh_size = count(ms01q00)
keep hid hh_size
duplicates drop
isid hid
save "${Temp}\\${temppath}\\size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
rename as06q02 itemid
bys hid: replace itemid = _n if hid==14813
drop if inlist(itemid, 18, 19, 20) // we exclude buildings
recode as06q03 (1 = 1) (2 . = 0) , gen(hh_owns_) 
keep hid itemid hh_owns_
reshape wide hh_owns_ , i(hid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep hid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items}", clear
drop if as06q02==. // one household
recode as06q03 ( 2 = 0 ) (1 = 1), gen (hh_owns) 
keep hh_owns hid as06q02
reshape wide hh_owns , i(hid) j(as06q02)
factor hh_owns*, pcf 
predict hh_asset_index
keep hid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${housing}", clear
egen total = rowtotal(ms05q02 ms05q03 ms05q04 ms05q05 ms05q06 ms05q07 ms05q08 ms05q09 ms05q10)
gen nonfarm_enterprise= 0 if total==18
replace nonfarm_enterprise = 1 if total<18
keep hid nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude
use "${Input}\\${country}\\${wave}\\${coords}", clear
merge 1:m grappe using "${Input}\\${country}\\${wave}\\${cover}", nogen keep(master match)
egen ea_id = concat(ms00q10 ms00q11 ms00q12  ms00q14), punct("-")
rename (LAT_DD_MOD LON_DD_MOD) (lat_modified lon_modified)
keep ea_id lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
merge 1:m grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen

rename ssa_aez09 agro_ecological_zone
keep hid agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
merge 1:m grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen

rename grappe ea_id

keep hid dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
merge 1:m grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen
keep hid dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace
 
// distance to nearest market (none)
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
merge 1:m grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen
keep hid dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace
 

// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
merge m:1 grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen
egen plot_id = concat(hid field parcel), punct("-")
rename plot_srtmslp plot_slope
collapse (mean)  plot_slope, by(plot_id)
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
egen plot_id = concat(hid field parcel), punct("-")
rename plot_srtm elevation 
collapse (mean)  elevation, by(plot_id)
save "${Temp}\\${temppath}\\elevation.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear 
egen plot_id = concat(hid field parcel), punct("-")
rename grappe ea_id
rename plot_twi twi 
collapse (mean)  twi, by(plot_id)
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
merge 1:m grappe menage using "${Input}\\${country}\\${wave}\\${cover}", nogen
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

keep hid  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace

// indiv chars
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hid ms01q00), punct("-")
recode ms01q01 (2=1 "Yes") (1=0 "No"), gen(female) 
rename ms01q06a age
recode ms01q15 ( 2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married) 
replace married = 0 if married==.
decode ms01q02, generate(relationship_head) 
replace  relationship_head = ustrregexra(relationship_head,`"[^a-zA-Z0-9]"',"")
replace relationship_head = "Head" if relationship_head=="chefdemnage"
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head=="beauprebellemre"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head=="beaufrrebellesoeur"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head=="beaufilsbellefille"
replace relationship_head = "Grandparent" if relationship_head=="grandpregrandmre"
replace relationship_head = "Servant" if relationship_head=="domestiqueouparentdudomestique"
replace relationship_head = "Spouse" if relationship_head=="conjointeducm"
replace relationship_head = "Son/Daughter" if relationship_head=="filsfille"
replace relationship_head = "Father/Mother" if relationship_head=="premre"
replace relationship_head = "Sister/Brother" if relationship_head=="frresoeur"
replace relationship_head = "Other Relative" if relationship_head=="cousincousine"
replace relationship_head = "Other Relative" if relationship_head=="autresparentsducmouduconjointe"
replace relationship_head = "Non Relative" if relationship_head=="personnenonapparenteaucmoulaconjointe"
replace relationship_head = "Niece/Nephew" if relationship_head=="neveunice"
replace relationship_head = "Grandchild" if relationship_head=="petitfilspetitefille"



keep hid ID married female age relationship_head ms01q06b
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting (absent)



// labor 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hid ms01q00), punct("-")

recode ms04q03 (1 = 1) (2= 0) (9 = .), gen( farm_work)
recode ms04q05 (1 = 1) (2= 0) (9 = .), gen( SOB_work)
recode ms04q02 (1 = 1) (2= 0) (9 = .), gen( wage_work)

// nb of working age members
gen working_age = ms01q06a>=6
bys hid: egen nb_members_working_age = total(working_age)


// industry:
gen ind_ag = ms04q24 >= 11 & ms04q24 <=40  // Agriculture 
gen ind_fish = ms04q24 == 51 | ms04q24==52 // fishing
gen ind_mining = ms04q24 >= 60 & ms04q24==72 // mining
gen ind_manuf = ms04q24 >= 81 & ms04q24 <= 292 // manuf
gen ind_const = ms04q24 >= 301 & ms04q24 <= 302 // construc
gen ind_serv = ms04q24 >= 310 & ms04q24<= 430 // services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if ms04q26==4 | ms04q25==6 | ms04q25==7 | ms04q25 == 8 // remove self employment
replace `var' = 0 if ms04q22==2 // did not work
}


gen hour_job1 = ms04q30
replace hour_job1 = 0 if ms04q11==2 & ms04q12==2 //answered "no" to filter questions = unemployed
gen hour_job2 = ms04q56
replace hour_job2 = 0 if ms04q11==2 & ms04q12==2 //answered "no" to filter questions = unemployed

gen day_job1 = ms04q31
replace day_job1 = 0 if ms04q11==2 & ms04q12==2 //answered "no" to filter questions = unemployed
gen day_job2 = ms04q57
replace day_job2 = 0 if ms04q11==2 & ms04q12==2 //answered "no" to filter questions = unemployed

gen month_job1 = ms04q29
replace month_job1 = 0 if ms04q11==2 & ms04q12==2 //answered "no" to filter questions = unemployed
gen month_job2 = ms04q55
replace month_job2 = 0 if ms04q11==2 & ms04q12==2 //answered "no" to filter questions = unemployed

gen av_hours1 = (month_job1 * hour_job1 * day_job1) / 52 // (week average of hours)
gen av_hours2 = (month_job2 * hour_job2 * day_job2) / 52 // (week average of hours)


recode ms04q23 (1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 = 1) (. 9999 =.) (else = 0) , gen(farm_job1)
recode ms04q51 (1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 = 1) (. 9999 =.) (else = 0) , gen(farm_job2)
replace farm_job1 = 0 if farm_job1==1 & inlist(ms04q26, 1, 2, 3, 7)
replace farm_job2 = 0 if farm_job2==1 & inlist(ms04q54, 1, 2, 3, 7)
recode ms04q23 ( 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212 = 1) (. 9999 =.) (else = 0) , gen(SB_job1)
recode ms04q51 ( 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212 = 1) (. 9999 =.) (else = 0) , gen(SB_job2)
replace SB_job1 = 0 if SB_job1==1 & inlist(ms04q26, 1, 2, 3, 7)
replace SB_job2 = 0 if SB_job2==1 & inlist(ms04q54, 1, 2, 3, 7)
recode ms04q23 ( 1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212 = 0) (. 9999 =.) (else = 1) , gen(wage_job1)
recode ms04q51 ( 1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212  = 0) (. 9999 =.) (else = 1) , gen(wage_job2)
replace wage_job1 = 1 if wage_job1==0 & inlist(ms04q26, 1, 2, 3, 7)
replace wage_job2 = 1 if wage_job2==0 & inlist(ms04q54, 1, 2, 3, 7)

foreach act in farm SB wage {
gen `act'_hrs1 = av_hours1 if `act'_job1 == 1
replace `act'_hrs1 = 0 if `act'_job1 == 0
replace `act'_hrs1 = 0 if ms04q22 == 2
gen `act'_hrs2 = av_hours2 if `act'_job2 == 1
replace `act'_hrs2 = 0 if `act'_job2 == 0
replace `act'_hrs2 = 0 if ms04q50==2 
egen `act'_hrs = rowtotal(`act'_hrs1 `act'_hrs2), missing
}



foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}


keep ID hid  farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hid ms01q00), punct("-")
recode ms02q04 (1 =1 "Yes") (2/4 = 0 "No") (9 = .), gen(formal_education) label(formal_education)
recode ms02q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education=1 if inlist(ms02q23, 3, 4, 5, 6, 7)
replace primary_education=0 if inlist(ms02q23, 1, 2)
replace primary_education= 0 if formal_education==0
foreach var in formal_education primary_education {
	replace `var' = 0  if ms01q06a<6
}
keep ID hid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace

// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if ms13q02 ==1 // keep if consumed
rename ms13q01 food_id

gen A = food_id>=701 & food_id<=712 | food_id>=810 & food_id<=813 | food_id>=816 & food_id<=821
gen B = food_id>=748 & food_id<=753
gen C = food_id>=717 & food_id<=730
gen D = food_id>=754 & food_id<=765
gen E = food_id>=766 & food_id<=773
gen F = food_id>=785 & food_id<=785
gen G = food_id>=774 & food_id<=778
gen H = food_id>=731 & food_id<=734  | food_id>=814 & food_id<=815
gen I = food_id>=786 & food_id<=792
gen J = food_id>=713 & food_id<=714 | food_id>=779 & food_id<=784
gen K = food_id>=715 & food_id<=716 | food_id>=793 & food_id<=798
gen L = food_id>=735 & food_id<=747

collapse (max) A B C D E F G H I J K L, by(hid)
 egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m hid  using "${Input}\\${country}\\${wave}\\${HDDS}", 
collapse (max) HDDS, by(hid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace