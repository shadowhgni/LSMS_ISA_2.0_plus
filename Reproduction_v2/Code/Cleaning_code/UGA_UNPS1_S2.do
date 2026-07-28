/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for UGA1         *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Uganda
global wave  UNPS 09
global cover  2009_GSEC1.dta
global plot_area 2009_AGSEC2A.dta
global plot_area2 2009_AGSEC2B.dta
global plot_inputs 2009_AGSEC3B.dta
global plot_labor 2009_AGSEC3B_1.dta
global shocks 2009_GSEC16.dta
global housing  2009_GSEC10A.dta
global plot_roster  2009_AGSEC4B.dta
global perennial 2009_SEC_6B.dta
global csption pov2009_10.dta
global items 2009_AGSEC10.dta
global items_hh 2009_GSEC14.dta
global harvest_rwdta  2009_AGSEC5B.dta
global harvest_sold_rwdta  2009_SEC_5A.dta
global indiv_roster 2009_GSEC2.dta
global educ 2009_GSEC4.dta
global anthropo  2009_GSEC6.dta
global labor_hh 2009_GSEC8.dta
global nfe 2009_GSEC12.dta
global livestock 2009_GSEC19.dta
global ag_cover 2009_AGSEC1.dta
global meta 2009_SEC_1_ALL.dta
global HDDS 2009_GSEC15B.dta 
global harvest_int 2009_CSECTION1.dta
global temppath UGA\UNPS09
 

global geovars 2009_UNPS_Geovars_0910.dta




**********************************************************
**** A) Master frame of crops, plots and manager
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear // to import labels

egen plot_id = concat(Hhid A5bq1 A5bq3 ), punct("-")
egen parcel_id = concat(Hhid A5bq1), punct("-")
rename A5bq5 cropID
drop if cropID==. | A5bq1==.

gen crop_name = A5bq4
keep Hhid plot_id crop_name cropID parcel_id 
duplicates drop


bys cropID (crop_name): replace crop_name=crop_name[_N] if crop_name==""
duplicates tag plot_id crop_name, gen(tag2)
drop if tag2>0
 
replace crop_name = strproper(crop_name)

collapse (firstnm) crop_name, by(plot_id cropID  parcel_id Hhid)
duplicates report plot_id   parcel_id Hhid crop_name

save "${Temp}\\${temppath}\\_S2plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename HHID Hhid
keep Hhid 
duplicates report Hhid 
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename HHID Hhid
egen ID = concat (Hhid PID), punct("-")
keep Hhid ID
duplicates drop
save "${Temp}\\${temppath}\\_S2indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA 
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename HHID Hhid 
rename comm ea_id
keep Hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\_S2ea_id.dta", replace


// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename HHID Hhid 
rename stratum strataid
keep Hhid strataid
duplicates drop
save "${Temp}\\${temppath}\\_S2strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename HHID Hhid 
decode region, gen(admin_1_name)
rename region admin_1
keep Hhid admin_1   admin_1_name
duplicates drop
save "${Temp}\\${temppath}\\_S2admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename HHID Hhid 
rename h1aq1_05 admin_2
keep Hhid  admin_2
duplicates drop
save "${Temp}\\${temppath}\\_S2admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename HHID Hhid 
rename h1aq2  admin_3
rename h1aq2b admin_3_name
keep Hhid admin_3  admin_3_name
duplicates drop
save "${Temp}\\${temppath}\\_S2admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename HHID Hhid 
keep Hhid urban
duplicates drop
save "${Temp}\\${temppath}\\_S2urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename HHID Hhid 
rename wgt09 pw
keep Hhid pw
duplicates drop
save "${Temp}\\${temppath}\\_S2weights.dta", replace


// planting month (absent)

// harvest end month (absent)

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename HHID Hhid
rename  comm Comm
merge m:1 Comm using  "${Input}\\${country}\\${wave}\\${harvest_int}", keep(match) nogen

foreach var in  C1bq2am  C1bq3am  C1bq4am  C1bq5am  {
format `var' %tm 
}

foreach var in C1bq2ay C1bq3ay C1bq4ay C1bq5ay {
format `var' %ty
}

forval n = 2/5 {
gen date`n' = ym(C1bq`n'ay, C1bq`n'am)
}

egen datemax = rowmax(date*)
egen datemin = rowmin(date*)
format datemax %tmCCYYMon
format datemin %tmCCYYMon

gen harvest_interview_month = datemin if datemin<= tm(2010, 2)

format harvest_interview_month %tmCCYYMon

keep harvest_interview_month Hhid
duplicates drop
save "${Temp}\\${temppath}\\_S2harvest_interview_month.dta", replace

// planting_interview_month (absent)

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 
rename (A5bq5) (cropID)

egen plot_id = concat(Hhid A5bq1 A5bq3 ), punct("-")
egen parcel_id = concat(Hhid A5bq1), punct("-")

gen harvest_kg = A5bq6a 
replace harvest_kg = A5bq6a if A5bq6c==1  | A5bq6a==0 
replace harvest_kg = . if A5bq6a==99999

recode A5bq24 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(Hhid plot_id cropID admin_1 admin_2 admin_3 A5bq1 A5bq3 parcel_id)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\_S2harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename (A5bq5) (cropID)

egen plot_id = concat(Hhid A5bq1 A5bq3 ), punct("-")

recode A5bq24 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 

recode A5bq24 (4 = 1 "Yes") (. = .) (else = 0 "No"), gen(drought_shock) label(drought_shock) 

recode A5bq24 (3 = 1 "Yes") (. = .) (else = 0 "No"), gen(flood_shock) label(flood_shock) 

recode A5bq24 (1 = 1 "Yes") (. = .) (else = 0 "No"), gen(pests_shock) label(pests_shock) 

collapse (max)  crop_shock pests_shock  drought_shock  flood_shock   , by(cropID Hhid plot_id)  
save "${Temp}\\${temppath}\\_S2crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


rename (A5bq6b A5bq6c A5bq6d A5bq5) (unit condition conversion cropID )
collapse (median) conversion, by(cropID unit condition)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin1.dta",  nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin2.dta", nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta",  nogen 
rename (A5bq5 ) (cropID )
rename (A5bq7b A5bq7c) (condition unit)
merge m:1 cropID condition unit using `Conversion_factors', keep(master match)

gen harvest_sold_kg = A5bq7a * conversion
replace harvest_sold_kg= A5bq7a if unit==1
replace harvest_sold_kg = 0 if A5bq7a==0

collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( cropID Hhid admin_1 admin_2 admin_3)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\_S2harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(Hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m Hhid using "${Temp}\\${temppath}\\_S2harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(Hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep Hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\_S2harvest_sold_kg_hh.dta", replace


// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

rename (A5bq5 ) (cropID )
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin1.dta", nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin2.dta", nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta",  nogen 

gen harvest_sold_value = A5bq8 / 100

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( cropID Hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\_S2harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

rename (A5bq5 ) (cropID )
keep Hhid  cropID 
duplicates drop

valuation_mdn_cr_noeaS2_sort   Hhid  cropID

main_crop_def_parcel cropID

collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(plot_id parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\_S2harvest_value_plot.dta", replace
collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\_S2harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
drop if A4bq6==.
rename (A4bq6 ) (cropID )
egen plot_id = concat(Hhid A4bq2 A4bq4), punct("-")
egen parcel_id = concat(Hhid A4bq2), punct("-")
recode A4bq7 (. = .) (1= 0 "No") (2=1 "Yes"), gen(intercropped) label(intercropped)
keep cropID plot_id intercropped parcel_id
collapse (max) intercropped, by(parcel_id)
save "${Temp}\\${temppath}\\_S2intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename (A5bq5 ) (cropID )
egen plot_id = concat(Hhid A5bq1 A5bq3 ), punct("-")
egen parcel_id = concat(Hhid A5bq1), punct("-")
egen tag = tag(parcel_id cropID)
egen nb_seasonal_crop = total(tag), by(parcel_id)
keep parcel_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\_S2nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\UNPS 19\AGSEC5A.dta", clear
keep cropID
rename cropID A5bq5
gen todrop = 1
append using "${Input}\\${country}\\${wave}\\${harvest_rwdta}",
drop if todrop ==1
egen plot_id = concat(Hhid A5bq1 A5bq3 ), punct("-")
egen parcel_id = concat(Hhid A5bq1  ), punct("-")
rename (A5bq5 ) (cropID )

merge m:1 cropID parcel_id  using "${Temp}\\${temppath}\\_S2harvest_value.dta", keep(match using) nogen

bys parcel_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if cropID==main_crop
bys parcel_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)


gen codesmain_crop = main_crop
gen codescropID = cropID
foreach c in main_crop cropID {
lab val `c' crop_code__id
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2
replace `c' = upper(`c')

replace `c' = "YAMS" if `c'=="YAM"
replace `c' = "COCOYAM" if `c'=="COCO YAM"
replace `c' = "CARROT" if `c'=="CARROTS"
replace `c' = "SOYABEANS" if `c'=="SOYA BEANS"

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c', "GROUNDNUTS", "SOY", "SOYABEAN", "SOYABEANS",  "BEANS", "BEAN", "VOANDZOU")  | strpos(`c',"BAMBARA NUT") | strpos(`c',"PEA")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c', "CASSAVA", "YAMS", "CARROT", "BEETS") | strpos(`c',"POTATO") | strpos(`c',"COCOYAM")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE" | `c'=="PADDY"
replace `c'2 = "MAIZE" if `c'=="MAIZE"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "MILLET" if `c'=="MILLET" | `c'=="ACHA" |  `c'=="FONIO" | `c'=="BULRUSH MILLET" | `c'=="FINGER MILLET"
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if codes`c' >=700 & !mi(codes`c' )
drop `c'
rename `c'2 `c'
}
tab cropID, gen(contains_crop_)

foreach n in 9 8 7 6 5 4 {
local i = `n' + 2
rename contains_crop_`n' contains_crop_`i'
} 

foreach n in 3 2 1 {
local i = `n' + 1
rename contains_crop_`n' contains_crop_`i'
} 

gen contains_crop_1=0
gen contains_crop_5=0

//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum) share_crop* (max) contains_crop_* , by(parcel_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\_S2main_crop.dta", replace

// share of plot area planted by crop 

// land area
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
rename A2aq2 A2bq2
merge 1:1 Hhid A2bq2 using "${Input}\\${country}\\${wave}\\${plot_area2}"
egen parcel_id = concat(Hhid A2bq2), punct("-")

gen area_GPS = A2aq4 * 0.404686
replace area_GPS = A2bq4 * 0.404686 if area_GPS==.

gen area_self_reported = A2aq5 * 0.404686
replace area_self_reported = A2bq5 * 0.404686 if area_self_reported==.

gen plot_area_GPS=.
replace plot_area_GPS = area_GPS if area_GPS>0
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen

isid Hhid parcel_id
sort Hhid parcel_id

//encode admin_3, gen(admin_3_num)
mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi impute pmm plot_area_GPS area_self_reported i.admin_3, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys Hhid: egen farm_size = total(plot_area_GPS), missing

keep Hhid parcel_id  plot_area_GPS farm_size 
duplicates drop
save "${Temp}\\${temppath}\\_S2plot_area.dta", replace


// improved 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
drop if A4bq6==.
rename A4bq6 cropID
egen plot_id = concat(Hhid A4bq2 A4bq4), punct("-")
recode A4bq13  (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
collapse (max) improved  ,by(Hhid plot_id cropID)
save "${Temp}\\${temppath}\\_S2improved.dta", replace

// seed kg (absent)

// seed_kg_sold (absent)

// seed_value_sold (absent)

// seed value 
wbopendata, language(en - English) country(UGA) topics() indicator(FP.CPI.TOTL) clear long
replace fp_cpi_totl = fp_cpi_totl/149.96287
drop if year!=2009 // first year with data in our dataset
drop countrycode region regionname adminregion adminregionname incomelevel incomelevelname lendingtype lendingtypename countryname
rename (fp_cpi_totl ) (CPI)
gen link=1 
tempfile Seed_value_CPI 
save `Seed_value_CPI', replace	

use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
drop if A4bq6==.
egen plot_id = concat(Hhid A4bq2 A4bq4), punct("-")
gen link = 1
merge m:1 link using `Seed_value_CPI', nogen
gen seed_value_cp = A4bq11/CPI
rename A4bq6 cropID

collapse (sum) seed_value_cp (count) n_seed_value_cp =  seed_value_cp , by(plot_id cropID )
replace seed_value_cp=. if n_seed_value_cp==.
save "${Temp}\\${temppath}\\_S2seed_value.dta", replace

// labor days

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")
egen parcel_id = concat(Hhid a3bq1), punct("-")

merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 

local n = 0
foreach mem in a b c {
gen ID_worker`n' = a3bq40`mem' 
local ++n
}

gen total_family_labor_days= a3bq39
replace total_family_labor_days = 0 if a3bq38==0

gen hired_man_days = a3bq42a
replace hired_man_days = 0 if a3bq41==2

gen hired_woman_days = a3bq42b
replace hired_woman_days = 0 if a3bq41==2

gen hired_child_days = a3bq42c
replace hired_child_days = 0 if a3bq41==2

gen wage = a3bq43 

egen  total_hired_labor_days= rowtotal(hired_*), missing

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing


valuation_median_wages_noea_S2 Hhid wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days parcel_id total_family_labor_days total_hired_labor_days hired_labor_value
collapse (sum) total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value (count) Ntotal_labor_days = total_labor_days Ntotal_family_labor_days = total_family_labor_days Ntotal_hired_labor_days = total_hired_labor_days Nhired_labor_value = hired_labor_value , by(parcel_id)
foreach var in total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value {
	replace `var' = . if N`var'==0
}
save "${Temp}\\${temppath}\\_S2labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")
egen parcel_id = concat(Hhid a3bq1 ), punct("-")
recode a3bq14 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
collapse (max)  inorganic_fertilizer, by(parcel_id)

save "${Temp}\\${temppath}\\_S2inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")
egen parcel_id = concat(Hhid a3bq1), punct("-")

merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 

recode a3bq14 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

	generate nitrogen_kg =a3bq16 *0.46 if a3bq15 ==1
	replace nitrogen_kg =a3bq16 *0.18 if a3bq15 ==2
	replace nitrogen_kg =a3bq16 *0 if a3bq15 ==3 
	replace nitrogen_kg =a3bq16 *((0.46+0.18)/2) if a3bq15 ==4 
	replace nitrogen_kg =0 if a3bq14==2 

gen fert_kg = a3bq16
replace fert_kg=0 if a3bq14==2 

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(parcel_id Hhid admin_1 admin_2 admin_3)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\_S2nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")

isid plot_id

merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 Hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 
gen fert_purchased_value = a3bq19
gen fert_purchased_kg  = a3bq18

valuation_median_fert_price_noea Hhid fert

keep admin_1 admin_2 admin_3 fert_value
duplicates drop

merge 1:m admin_1 admin_2 admin_3 using "${Temp}\\${temppath}\\_S2nitrogen_kg.dta", keep(match) nogen

foreach n in fert  {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

collapse (max)  inorganic_fertilizer, by(parcel_id)

save "${Temp}\\${temppath}\\_S2inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")
egen parcel_id = concat(Hhid a3bq1), punct("-")
recode a3bq4 (1 =1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(parcel_id)
save "${Temp}\\${temppath}\\_S2organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")

recode a3bq26 (2 = 0 "No") (1 = 1 "Yes") (. = .), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if a3bq27==3
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\_S2used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
rename A2aq2 A2bq2
merge 1:1 Hhid A2bq2 using "${Input}\\${country}\\${wave}\\${plot_area2}"
egen parcel_id = concat(Hhid A2bq2), punct("-")
merge 1:m Hhid parcel_id using "${Temp}\\${temppath}\\_S2harvest_kg.dta", nogen keep(master match)
recode A2aq8 (1 2 = 1 "Yes") (3 4 = 0 "No") (5 6=.) , gen(plot_owned) label(plot_owned)
replace plot_owned= 0 if _merge==2

recode A2aq25 (1/3 = 1 "Yes") (4 = 0 "No"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate= 0 if _merge==2
replace plot_owned = 1 if plot_certificate==1
keep parcel_id plot_owned plot_certificate
duplicates drop
isid parcel_id
save "${Temp}\\${temppath}\\_S2plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
rename A2aq2 A2bq2

merge 1:1 Hhid A2bq2 using  "${Input}\\${country}\\${wave}\\${plot_area2}"
egen parcel_id = concat(Hhid A2bq2), punct("-")

merge 1:m Hhid parcel_id using  "${Temp}\\${temppath}\\_S2harvest_kg.dta", nogen
drop plot_id
egen plot_id = concat(Hhid A5bq1 A5bq3), punct("-")
recode  A2aq20 (1 = 1 "Yes") (. =.) (else = 0 "No"), gen(irrigated) label(irrigated)
replace irrigated=1 if A2bq19==1
replace irrigated=0 if inlist(A2bq19, 2, 3)
collapse (max)  irrigated, by(parcel_id)

save "${Temp}\\${temppath}\\_S2irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
rename A2aq2 A2bq2
merge 1:1 Hhid A2bq2 using  "${Input}\\${country}\\${wave}\\${plot_area2}"

rename A2bq2 A5bq1
merge 1:m Hhid A5bq1 using  "${Temp}\\${temppath}\\_S2harvest_kg.dta", nogen
drop plot_id
egen plot_id = concat(Hhid A5bq1 A5bq3), punct("-")
encode A2aq24, gen(erosion_var1)
encode A2bq23, gen(erosion_var2)
recode erosion_var1 (.=.) (40 43 = 0 "No") (* = 1 "Yes") , gen(erosion_protection) label(erosion_protection)
replace erosion_protection=1 if !mi(erosion_var2) 
replace erosion_protection=0 if inlist(erosion_var2, 24, 25)
collapse (max)  erosion_protection, by(parcel_id)
save "${Temp}\\${temppath}\\_S2erosion_protection.dta", replace

// tractor (absent)

// nb fallow (absent)

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

rename HHID Hhid 

egen plot_id = concat(Hhid a3bq1 a3bq3), punct("-")

gen n = 1
bys Hhid: egen nb_plots = count(n)
keep Hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\_S2nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${educ}", clear
rename  HHID Hhid
recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode h4q7 (10/16 = 0 "No") (. 99 1 3 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education = 0 if inrange(h4q9,0, 16)
replace primary_education = 1 if inrange(h4q9,17, 60)
replace primary_education = 0 if formal_education==0
bys Hhid: egen hh_primary_education= max(primary_education) 
bys Hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(Hhid)
keep Hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
rename HHID Hhid
recode h10q1 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
replace hh_electricity_access=1 if h10q6==1
keep Hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename HHID Hhid
drop if h2q5==0
gen age = h2q8  
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort Hhid: egen dep=total(dep_temp)
bysort Hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep)  
replace hh_dependency_ratio = dep if nondep==0

collapse (max)  hh_dependency_ratio, by(Hhid)
save "${Temp}\\${temppath}\\_S2hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${ag_cover}", clear
duplicates report Hhid
recode A6aq1 ( 2 = 0 "No") (1 = 1 "Yes"), gen(livestock) label(livestock)	
replace livestock=1 if A6bq1==1
replace livestock=1 if A6cq1==1
replace livestock=0 if A6aq1==2 & A6bq1==2 & A6cq1==2
keep Hhid livestock
duplicates drop

save "${Temp}\\${temppath}\\_S2livestock.dta", replace

// consumption quint 
use "${Input}\\${country}\\${wave}\\${csption}", clear
tostring hh, gen(Hhid) format("%32.0g")
gen totcons = (nrrexp30 * 12)/hsize_m
xtile cons_quint= totcons, n(5)
keep cons_quint Hhid 
duplicates drop
save "${Temp}\\${temppath}\\_S2cons_quint.dta", replace

// consumption aggregate 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = (nrrexp30 * 12)/hsize_m
tostring hh, gen(Hhid) format("%32.0g")
keep totcons Hhid 
duplicates drop
save "${Temp}\\${temppath}\\_S2totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_area}", clear

rename A2aq2 A2bq2
merge 1:1 Hhid A2bq2 using "${Input}\\${country}\\${wave}\\${plot_area2}"
egen parcel_id = concat(Hhid A2bq2), punct("-")
egen manager_id = concat(Hhid A2aq28a), punct("-")
egen manager_id2 = concat(Hhid A2bq26a), punct("-")
drop if A2bq26a==. & _merge==2 | A2aq28a==. & _merge==1
replace manager_id = manager_id2 if _merge==2
sort  parcel_id (manager_id)
collapse (first) manager_id  , by(Hhid parcel_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename HHID Hhid

egen manager_id = concat(Hhid h2q1), punct("-")

merge 1:m  Hhid manager_id using `ID_list', keep(match ) nogen

recode h2q3 (2=1 "Yes") (1=0 "No"), gen(female_manager) label(female_manager)
gen age_manager = h2q8
recode h2q10 ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married_manager) label(married_manager)

merge 1:m parcel_id using "${Temp}\\${temppath}\\_S2plot_crop_frame.dta", keep(match) nogen
rename manager_id manager_id_temp
egen manager_id = concat (Hhid PID), punct("-")
keep parcel_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\_S2Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
rename HHID Hhid
egen manager_id = concat(Hhid h4q1), punct("-") // 

merge 1:m  Hhid manager_id using `ID_list', keep(match) nogen

recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode h4q7 (10/16 = 0 "No") (. 99 1 3 =.) (else =1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager = 0 if inrange(h4q9,0, 16)
replace primary_education_manager = 1 if inrange(h4q9,17, 60)
replace primary_education_manager = 0 if formal_education_manager==0
sort  Hhid (manager_id)

merge 1:m parcel_id Hhid using "${Temp}\\${temppath}\\_S2plot_crop_frame.dta", keep(match) nogen

keep parcel_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\_S2Manager_characteristics2.dta", replace

// respondent chars (missing)


// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
rename HHID Hhid
recode h16q01 (1 = 1 "Yes") (2=0 "No"), gen(hh_shock) label(hh_shock)

collapse (max) hh_shock, by(Hhid) 
save "${Temp}\\${temppath}\\_S2shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename HHID Hhid
bys Hhid: egen hh_size = count(PID)
collapse (max) hh_size , by(Hhid)
save "${Temp}\\${temppath}\\_S2hh_size.dta", replace

// ag assets (absent)


// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear
rename HHID Hhid
drop if h14q2>20 // drop other
recode h14q3 (1 = 1) (.= . ) (2=0), gen(hh_owns) label(hh_owns) 
keep hh_owns Hhid h14q2
reshape wide hh_owns , i(Hhid) j(h14q2)
factor hh_owns*, pcf 
predict hh_asset_index
keep Hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
rename  HHID Hhid
recode h12q01 ( 1 = 1) (2 = 0), gen(nonfarm_enterprise)
collapse (max)  nonfarm_enterprise, by(Hhid)
duplicates drop
save "${Temp}\\${temppath}\\_S2nfe.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
rename (lat_mod lon_mod) (lat_modified lon_modified)
keep Hhid lat_modified lon_modified 
duplicates drop
save "${Temp}\\${temppath}\\_S2Coords.dta", replace

// agro ecological zone 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
rename ssa_aez09 agro_ecological_zone
keep Hhid agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\_S2aez.dta", replace

// distance to nearest road 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
keep Hhid dist_road
duplicates drop
save "${Temp}\\${temppath}\\_S2dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
keep Hhid dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\_S2dist_popcenter.dta", replace

// distance to nearest market
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
keep Hhid dist_market
duplicates drop
save "${Temp}\\${temppath}\\_S2dist_market.dta", replace

// plot slope
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
rename afmnslp_pct plot_slope
keep Hhid plot_slope
duplicates drop
save "${Temp}\\${temppath}\\_S2plot_slope.dta", replace

// plot elevation 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
rename srtm_uga elevation
keep Hhid elevation
duplicates drop
save "${Temp}\\${temppath}\\_S2elevation.dta", replace


// total wetness index 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
rename twi_uga twi
keep Hhid twi
duplicates drop
save "${Temp}\\${temppath}\\_S2twi.dta", replace

// soil variables 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename  HHID Hhid
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
keep Hhid soil_fertility_index nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability 
duplicates drop
save "${Temp}\\${temppath}\\_S2soil_fertility_index.dta", replace

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename HHID  Hhid
egen ID = concat (Hhid PID), punct("-")

recode  h2q3 (2=1 "Yes") (1=0 "No"), gen(female) 
rename h2q8 age
recode h2q10  ( 1 2 = 1 "Yes") (3 4 5 = 0 "No") (99 =.), gen(married) 
replace married = 0 if age<10
rename h2q4 relationship_head_temp 
decode relationship_head_temp, gen(relationship_head)
replace relationship_head = proper(relationship_head)
replace relationship_head = "Niece/Nephew" if relationship_head== "Nephew/Niece"
replace relationship_head = "Non Relative" if relationship_head== "Other (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relatives"
replace relationship_head = "Grandchild" if relationship_head== "Grand Child"

// month of birth
gen birth_month= ym(h2q9c, h2q9b)
format birth_month %tm 

keep Hhid ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\_S2indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${anthropo}", clear

egen ID = concat (Hhid Pid ), punct("-")
merge 1:1 Hhid ID using "${Temp}\\${temppath}\\_S2indiv_chars.dta",  nogen

// age in months
gen age_months=H6q04

*Main anthropometric variables
gen weight= H6q27
gen height= H6q28a 
replace height = H6q28b if height==.

gen cage=age*12
replace cage = age_months if age==0| age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  Hhid ID weight height
duplicates drop
save "${Temp}\\${temppath}\\_S2wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${labor_hh}", clear
egen ID = concat (Hhid Pid), punct("-")

recode H8q12 (1 = 1) (2 = 0), gen(farm_work)
recode H8q06 (1 = 1) (2 = 0), gen( SOB_work)
replace SOB_work = 1 if H8q08==1
recode H8q04 (1 = 1) (2 = 0), gen( wage_work)


egen hrs= rowtotal(H8q36a H8q36b H8q36c H8q36d H8q36e H8q36f H8q36g), missing
gen farm_hrs = hrs if farm_work==1  & wage_work==0
replace farm_hrs = 0 if farm_work == 0
gen SB_hrs = hrs if SOB_work==1 & wage_work==0
replace SB_hrs = 0 if SOB_work == 0
gen wage_hrs = hrs if wage_work==1
replace wage_hrs = 0 if wage_work == 0

keep ID Hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs 
duplicates drop
merge 1:1 ID Hhid  using "${Temp}\\${temppath}\\indiv_frame.dta", keep(using match)
foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs  {
replace `var' = 0 if _merge==2
}
save "${Temp}\\${temppath}\\_S2labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${educ}", clear
egen ID = concat (HHID PID), punct("-")

rename HHID Hhid
recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode h4q7 (10/16 = 0 "No") (. 99 1 3 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education = 0 if inrange(h4q9,0, 16)
replace primary_education = 1 if inrange(h4q9,17, 60)
replace primary_education = 0 if formal_education==0

keep ID Hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\_S2educ_indiv.dta", replace



// HDDS

use "${Input}\\${country}\\${wave}\\${HDDS}", clear

rename h15bq2 item_cd

gen A = item_cd>=101 & item_cd<=104 | item_cd>=110 & item_cd<=116 | item_cd>=172 & item_cd<=173  | item_cd==180 | item_cd>=190 & item_cd<=191
gen B = item_cd>=105 & item_cd<=109
gen C = item_cd>=135 & item_cd<=139 | item_cd>=164 & item_cd<=168 | item_cd>=181 & item_cd<=182
gen D = item_cd>=130 & item_cd<=134 | item_cd>=169 & item_cd<=171 | item_cd==174 
gen E = item_cd>=117 & item_cd<=121
gen F = item_cd==124
gen G = item_cd>=122 & item_cd<=123
gen H = item_cd>=140 & item_cd<=145 | item_cd>=162 & item_cd<=163
gen I = item_cd>=125 & item_cd<=126
gen J = item_cd>=127 & item_cd<=129
gen K = item_cd==147 
gen L = item_cd>=148 & item_cd<=150

collapse (max) A B C D E F G H I J K L, by(HHID)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 

merge 1:1 HHID  using "${Input}\\${country}\\${wave}\\${cover}", 

rename HHID Hhid
collapse (max) HDDS, by(Hhid)
save "${Temp}\\${temppath}\\_S2HDDS.dta", replace


