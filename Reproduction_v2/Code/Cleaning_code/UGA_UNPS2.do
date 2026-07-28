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
global wave  UNPS 10
global cover  GSEC1.dta
global plot_area AGSEC2A.dta
global plot_area2 AGSEC2B.dta
global plot_inputs AGSEC3A.dta
global plot_labor AGSEC3A_1.dta
global shocks GSEC16.dta
global housing  GSEC10A.dta
global plot_roster  AGSEC4A.dta
global perennial SEC_6B.dta
global csption pov2010_11.dta
global items AGSEC10.dta
global items_hh GSEC14.dta
global harvest_rwdta  AGSEC5A.dta
global harvest_sold_rwdta  SEC_5A.dta
global indiv_roster GSEC2.dta
global educ GSEC4.dta
global anthropo  GSEC6.dta
global labor_hh GSEC8.dta
global nfe GSEC12.dta
global livestock AGSEC2.dta
global ag_cover AGSEC1.dta
global meta SEC_1_ALL.dta
global HDDS GSEC15B.dta 
global harvest_int CSECTION1.dta
global temppath UGA\UNPS10
 

global geovars UNPS_Geovars_1011.dta



**********************************************************
**** A) Master frame of crops, plots and manager
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear // to import labels

egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")

decode cropID, gen(crop_name)
replace crop_name = substr(crop_name, strpos(crop_name, " ")+1, .)
keep HHID plot_id crop_name cropID parcel_id
 
duplicates drop

duplicates tag plot_id crop_name, gen(tag)
decode cropID, gen(cropname2)
replace crop_name = cropname2 if tag>0

replace crop_name = strproper(crop_name)

duplicates report plot_id cropID crop_name parcel_id

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear

keep HHID 
duplicates report HHID 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

egen ID = concat (HHID PID), punct("-")
keep HHID ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA 
use "${Input}\\${country}\\${wave}\\${cover}", clear  
drop comm 
merge m:1 HHID using "${Input}\\Uganda\\UNPS 09\\2009_GSEC1.dta", keep(master match) keepusing(comm)
rename comm ea_id
keep HHID ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear  
drop comm 
merge m:1 HHID using "${Input}\\Uganda\\UNPS 09\\2009_GSEC1.dta", keep(master match) keepusing(stratum)
rename stratum strataid
keep HHID strataid
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1 
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename region admin_1
decode admin_1, gen(admin_1_name)
keep HHID admin_1 admin_1_name
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename h1aq1 admin_2_name
keep HHID admin_2 
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename h1aq3b admin_3_name
keep HHID admin_3 
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
keep HHID urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename wgt10 pw
keep HHID pw
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace


// planting month (absent)


// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


egen plot_id = concat(HHID prcid pltid), punct("-")

// first condition
gen month1 = a5aq6f
format month1 %tm 

gen year1 = 2010
format year %ty 
gen harvest_end_month = ym(year, month)

format harvest_end_month %tmCCYYMon
drop month year

format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(plot_id cropID )

save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge m:1 comm using  "${Input}\\${country}\\${wave}\\${harvest_int}", keep(match) nogen
foreach var in month  c1bq2am  c1bq3am  c1bq4am  c1bq5am  c1bq6am  {
format `var' %tm 
}

foreach var in year c1bq2ay c1bq3ay c1bq4ay c1bq5ay c15q6ay {
format `var' %ty
}

gen date1 = ym(year, month)
forval n = 2/5 {
gen date`n' = ym(c1bq`n'am, c1bq`n'ay)
}
gen date6 = ym(c15q6ay, c1bq6am)
egen datemax = rowmax(date*)
egen datemin = rowmin(date*)
format datemax %tmCCYYMon
format datemin %tmCCYYMon
gen harvest_interview_month = datemin if datemin<= tm(2011, 4)
format harvest_interview_month %tmCCYYMon

keep harvest_interview_month HHID
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month (absent)

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


merge m:1 HHID using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 

egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")

gen harvest_kg = a5aq6a * a5aq6d // amount multiplied by CF
replace harvest_kg = a5aq6a  if a5aq6c==1 

recode a5aq24 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(HHID plot_id cropID admin_1 admin_2 admin_3 prcid pltid parcel_id)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


egen plot_id = concat(HHID prcid pltid), punct("-")

recode a5aq24 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 

recode a5aq24 (4 = 1 "Yes") (. = .) (else = 0 "No"), gen(drought_shock) label(drought_shock) 

recode a5aq24 (3 = 1 "Yes") (. = .) (else = 0 "No"), gen(flood_shock) label(flood_shock) 

recode a5aq24 (1 = 1 "Yes") (. = .) (else = 0 "No"), gen(pests_shock) label(pests_shock) 

collapse (max)  crop_shock pests_shock  drought_shock  flood_shock   , by(cropID HHID plot_id)  
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

rename (a5aq6c a5aq6b a5aq6d) (unit condition conversion )
collapse (median) conversion, by(cropID unit condition)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


merge m:1 HHID using "${Temp}\\${temppath}\\admin1.dta",  nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta",  nogen 

rename (a5aq7b a5aq7c) (condition unit)

merge m:1 cropID condition unit using  `Conversion_factors', keep(master match)
gen harvest_sold_kg = a5aq7a * conversion
replace harvest_sold_kg= a5aq7a if unit==1
replace harvest_sold_kg= 0 if a5aq7a==0

collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( cropID HHID admin_1 admin_2 admin_3)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(HHID)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m HHID using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(HHID)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep HHID share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace


// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


merge m:1 HHID using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_value = a5aq8 

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( cropID HHID admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


keep HHID  cropID 
duplicates drop

valuation_median_crops_noea_sort HHID  cropID


main_crop_def_parcel cropID

collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(plot_id parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\harvest_value_plot.dta", replace
collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")
recode a4aq7 (. = .) (1= 0 "No") (2=1 "Yes"), gen(intercropped) label(intercropped)
keep cropID plot_id intercropped parcel_id
collapse (max) intercropped, by(parcel_id )
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")
egen tag = tag(parcel_id cropID)
egen nb_seasonal_crop = total(tag), by(parcel_id)
keep parcel_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}",  clear // to import labels
egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")

merge m:1 cropID parcel_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen

bys parcel_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if cropID==main_crop
bys parcel_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)


gen codesmain_crop = main_crop
gen codescropID = cropID
foreach c in main_crop cropID {
lab val `c' cropID
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
save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 

// land area
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
merge 1:1  HHID prcid using "${Input}\\${country}\\${wave}\\${plot_area2}"
egen parcel_id = concat(HHID prcid), punct("-")

gen area_GPS = a2aq4 * 0.404686
replace area_GPS = a2bq4 * 0.404686 if area_GPS==.

gen area_self_reported = a2aq5 * 0.404686
replace area_self_reported = a2bq5 * 0.404686 if area_self_reported==.

gen plot_area_GPS=.
replace plot_area_GPS = area_GPS if area_GPS>0
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid HHID parcel_id
sort HHID parcel_id

encode admin_3, gen(admin_3_num)
mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi impute pmm plot_area_GPS area_self_reported i.admin_3_num, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys HHID: egen farm_size = total(plot_area_GPS), missing

keep HHID parcel_id  plot_area_GPS farm_size 
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear

egen plot_id = concat(HHID prcid pltid), punct("-")
recode a4aq13  (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
collapse (max) improved  ,by(HHID plot_id cropID)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg (absent)

// seed_kg_sold (absent)

// seed value 
wbopendata, language(en - English) country(UGA) topics() indicator(FP.CPI.TOTL) clear long
replace fp_cpi_totl = fp_cpi_totl/149.96287
drop if year!=2010 // first year with data in our dataset
drop countrycode region regionname adminregion adminregionname incomelevel incomelevelname lendingtype lendingtypename countryname
rename (fp_cpi_totl ) (CPI)
gen link=1 
tempfile Seed_value_CPI 
save `Seed_value_CPI', replace	

use "${Input}\Uganda\UNPS 10\AGSEC4A.dta", clear 
egen plot_id = concat(HHID prcid pltid), punct("-")
gen link = 1
merge m:1 link using `Seed_value_CPI', nogen
gen seed_value_cp = a4aq11/CPI

collapse (sum) seed_value_cp (count) n_seed_value_cp =  seed_value_cp , by(plot_id cropID)
replace seed_value_cp=. if n_seed_value_cp==.
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")

merge m:1 HHID using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 

local n = 0
foreach mem in a b c {
gen ID_worker`n' = a3aq40`mem' 
local ++n
}

gen total_family_labor_days=  a3aq39
replace total_family_labor_days = 0 if a3aq38==0

gen hired_man_days = a3aq42a
replace hired_man_days = 0 if a3aq41==2

gen hired_woman_days = a3aq42b
replace hired_woman_days = 0 if a3aq41==2

gen hired_child_days = a3aq42c
replace hired_child_days = 0 if a3aq41==2

gen wage = a3aq43 

egen  total_hired_labor_days= rowtotal(hired_*), missing

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing

valuation_median_wages_noea HHID wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days
replace hired_labor_value = 0 if total_hired_labor_days==0



keep total_labor_days parcel_id total_family_labor_days total_hired_labor_days hired_labor_value
collapse (sum) total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value (count) Ntotal_labor_days = total_labor_days Ntotal_family_labor_days = total_family_labor_days Ntotal_hired_labor_days = total_hired_labor_days Nhired_labor_value = hired_labor_value , by(parcel_id)
foreach var in total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value {
	replace `var' = . if N`var'==0
}
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid ), punct("-")
recode a3aq14 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
collapse (max)  inorganic_fertilizer, by(parcel_id)

save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear


egen plot_id = concat(HHID prcid pltid), punct("-") 
egen parcel_id = concat(HHID prcid), punct("-") 

merge m:1 HHID using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 

recode a3aq14 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

	generate nitrogen_kg =a3aq16 *0.46 if a3aq15 ==1
	replace nitrogen_kg =a3aq16 *0.18 if a3aq15 ==2
	replace nitrogen_kg =a3aq16 *0 if a3aq15 ==3 
	replace nitrogen_kg =a3aq16 *((0.46+0.18)/2) if a3aq15 ==4 
	replace nitrogen_kg =0 if a3aq14==2 

gen fert_kg = a3aq16
replace fert_kg=0 if a3aq14==2 

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(parcel_id HHID admin_1 admin_2 admin_3)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear


egen plot_id = concat(HHID prcid pltid), punct("-") 
isid plot_id

merge m:1 HHID using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 HHID using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 
gen fert_purchased_value = a3aq19
gen fert_purchased_kg  = a3aq18

valuation_median_fert_price_noea HHID fert

keep admin_1 admin_2 admin_3 fert_value
duplicates drop

merge 1:m admin_1 admin_2 admin_3 using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

foreach n in fert  {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep parcel_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(HHID prcid pltid), punct("-") 
egen parcel_id = concat(HHID prcid ), punct("-") 
recode a3aq4 (1 =1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(parcel_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear


egen plot_id = concat(HHID prcid pltid), punct("-")
recode a3aq26 (2 = 0 "No") (1 = 1 "Yes") (. = .), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if a3aq27==3
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
merge 1:1 HHID prcid using "${Input}\\${country}\\${wave}\\${plot_area2}"


merge 1:m HHID prcid using "${Temp}\\${temppath}\\harvest_kg.dta", nogen keep(master match)
recode a2aq8 (1 2 = 1 "Yes") (3 4 = 0 "No") (5 6=.) , gen(plot_owned) label(plot_owned)
replace plot_owned= 0 if _merge==2
drop parcel_id
egen parcel_id = concat(HHID prcid), punct("-")

recode a2aq25 (1/3 = 1 "Yes") (4 = 0 "No"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate= 0 if _merge==2
replace plot_owned = 1 if plot_certificate==1
collapse  (max) plot_owned plot_certificate, by(parcel_id)
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
merge 1:1 HHID prcid using  "${Input}\\${country}\\${wave}\\${plot_area2}"


merge 1:m HHID prcid using  "${Temp}\\${temppath}\\harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid ), punct("-")
recode  a2aq20 (1 = 1 "Yes") (. =.) (else = 0 "No"), gen(irrigated) label(irrigated)
replace irrigated=1 if a2bq19==1
replace irrigated=0 if inlist(a2bq19, 2, 3)
collapse (max)  irrigated, by(parcel_id)

save "${Temp}\\${temppath}\\irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${plot_area}", clear
merge 1:1 HHID prcid using  "${Input}\\${country}\\${wave}\\${plot_area2}"


merge 1:m HHID prcid using  "${Temp}\\${temppath}\\harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(HHID prcid pltid), punct("-")
egen parcel_id = concat(HHID prcid), punct("-")
encode a2aq24a, gen(erosion_var1)
encode a2aq24b, gen(erosion_var2)
encode a2bq23a, gen(erosion_var3)
encode a2bq23b, gen(erosion_var4)
recode erosion_var1 (.=.) (8 = 0 "No") (* = 1 "Yes") , gen(erosion_protection) label(erosion_protection)
replace erosion_protection=1 if erosion_var2!=. & erosion_var2!=2 & erosion_var2!=1
replace erosion_protection=1 if !mi(erosion_var3) | !mi(erosion_var4)
replace erosion_protection=0 if erosion_var3==9 | erosion_var4 == 10 & mi(erosion_var3)
collapse (max)  erosion_protection, by(parcel_id)

save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear


merge m:1 HHID using "${Input}\\${country}\\${wave}\\${cover}",
gen tractor = 1 if a10q4==1 & itmcd==6
replace tractor = 0 if a10q4==0 | itmcd!=6
replace tractor = 0 if a10q4==2 & itmcd==6 // not used
replace tractor = 1 if a10q6==1 & itmcd==6
collapse (max) tractor , by(HHID)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow (absent)

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear


egen plot_id = concat(HHID prcid pltid), punct("-")

gen n = 1
bys HHID: egen nb_plots = count(n)
keep HHID nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${educ}", clear


recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode h4q7 (10/16 = 0 "No") (. 99 1 3 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education = 0 if inrange(h4q9,0, 16)
replace primary_education = 1 if inrange(h4q9,17, 60)
replace primary_education = 0 if formal_education==0
bys HHID: egen hh_primary_education= max(primary_education) 
bys HHID: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(HHID)
keep HHID hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode h10q1 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
replace hh_electricity_access=1 if h10q6==1
keep HHID hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
drop if h2q5==0
gen age = h2q8  
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort HHID: egen dep=total(dep_temp)
bysort HHID: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep  if nondep==0

collapse (max)  hh_dependency_ratio, by(HHID)
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear

duplicates report HHID
recode a6aq1 ( 2 = 0 "No") (1 = 1 "Yes"), gen(livestock) label(livestock)	
replace livestock=1 if a6bq1==1
replace livestock=1 if a6cq1==1
replace livestock=0 if a6aq1==2 & a6bq1==2 & a6cq1==2
keep HHID livestock
duplicates drop

save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = (cpexp30 * 12)/hsize
xtile cons_quint= totcons, n(5)
tostring hh, gen(HHID) format("%32.0g")
keep cons_quint HHID 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = (cpexp30 * 12)/hsize
tostring hh, gen(HHID) format("%32.0g")
keep totcons HHID 
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_area}", clear

merge 1:1  HHID prcid using "${Input}\\${country}\\${wave}\\${plot_area2}"
egen parcel_id = concat(HHID prcid), punct("-")
egen manager_id = concat(HHID a2aq28a), punct("-")
egen manager_id2 = concat(HHID a2bq26a), punct("-")
drop if a2bq26a==. & _merge==2 | a2aq28a==. & _merge==1
replace manager_id = manager_id2 if _merge==2
sort  HHID (manager_id)
collapse (first) manager_id  , by(HHID parcel_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

egen manager_id = concat(HHID h2q1), punct("-")

recode h2q3 (0=1 "Yes") (1=0 "No"), gen(female_manager) label(female_manager)
gen age_manager = h2q8
recode h2q10 ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married_manager) label(married_manager)
sort  HHID PID (manager_id)
collapse (first)  female_manager age_manager married_manager PID , by(HHID manager_id)
merge 1:m  HHID manager_id using `ID_list', keep(match ) nogen
merge 1:m parcel_id HHID using "${Temp}\\${temppath}\\plot_crop_frame.dta", keep(match) nogen
rename manager_id manager_id_temp
egen manager_id = concat (HHID PID), punct("-")
keep parcel_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
drop h2q1 // too many missing
merge 1:1 HHID PID using "${Input}\\${country}\\${wave}\\${indiv_roster}", keepusing(h2q1) keep(master match)

egen manager_id = concat(HHID h2q1), punct("-") // 

recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode h4q7 (10/16 = 0 "No") (. 99 1 3 =.) (else =1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager = 0 if inrange(h4q9,0, 16)
replace primary_education_manager = 1 if inrange(h4q9,17, 60)
replace primary_education_manager = 0 if formal_education_manager==0
sort  HHID PID (manager_id)
collapse (first)   primary_education_manager formal_education_manager , by(HHID manager_id)

merge 1:m  HHID manager_id using `ID_list', keep(match) nogen


merge 1:m parcel_id HHID using "${Temp}\\${temppath}\\plot_crop_frame.dta", keep(match) nogen

keep parcel_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars (missing)


// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode h16q01 (1 = 1 "Yes") (2=0 "No"), gen(hh_shock) label(hh_shock)

collapse (max) hh_shock, by(HHID) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear


bys HHID: egen hh_size = count(PID)
collapse (max) hh_size , by(HHID)
save "${Temp}\\${temppath}\\hh_size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
duplicates report HHID itmcd 

drop if a10q1==. | itmcd==. | itmcd==22 // otherwise the pcf cannot be computedd 
recode a10q1 (0=0) (else=1), gen(hh_owns_)
rename itmcd itemid 
collapse (max) hh_owns_ , by(HHID itemid) // many duplicates
keep HHID itemid hh_owns_
reshape wide hh_owns_ , i(HHID) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep HHID ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear
drop if h14q2>20 // drop other
recode h14q3 (1 = 1) (.= . ) (2=0), gen(hh_owns) label(hh_owns) 
keep hh_owns HHID h14q2
reshape wide hh_owns , i(HHID) j(h14q2)
factor hh_owns*, pcf 
predict hh_asset_index
keep HHID hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
merge m:1 HHID using "${Input}\\${country}\\${wave}\\${cover}"
recode h12q1 ( 1 = 1) (2 = 0), gen(nonfarm_enterprise)
replace nonfarm_enterprise = 0 if _merge==2
collapse (max)  nonfarm_enterprise, by(HHID)
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename (lat_mod lon_mod) (lat_modified lon_modified)
keep HHID lat_modified lon_modified 
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename ssa_aez09 agro_ecological_zone
keep HHID agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
keep HHID dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars}", clear
keep HHID dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace

// distance to nearest market
use "${Input}\\${country}\\${wave}\\${geovars}", clear
keep HHID dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace

// plot slope
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename afmnslp_pct plot_slope
keep HHID plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename srtm_uga elevation
keep HHID elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace


// total wetness index 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
rename twi_uga twi
keep HHID twi
duplicates drop
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables 
use "${Input}\\${country}\\${wave}\\${geovars}", clear
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
keep HHID soil_fertility_index nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability 
duplicates drop
save "${Temp}\\${temppath}\\soil_fertility_index.dta", replace

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

egen ID = concat (HHID PID), punct("-")

recode  h2q3 (1=0 "No") (0=1 "Yes") , gen(female) 
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

keep HHID ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${anthropo}", clear

egen ID = concat (HHID PID ), punct("-")
merge 1:1 HHID ID using "${Temp}\\${temppath}\\indiv_chars.dta",  nogen

// age in months
gen age_months=h6q4

*Main anthropometric variables
gen weight= h6q27
gen height= h6q28a 
replace height = h6q28b if height==.

gen cage=age*12
replace cage = age_months if age==0| age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  HHID ID weight height
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${labor_hh}", clear
egen ID = concat (HHID PID), punct("-")

recode h8q12 (1 = 1) (2 = 0), gen(farm_work)
recode h8q6 (1 = 1) (2 = 0), gen( SOB_work)
replace SOB_work = 1 if h8q8==1
recode h8q4 (1 = 1) (2 = 0), gen( wage_work)


egen hrs= rowtotal(h8q36a h8q36b h8q36c h8q36d h8q36e h8q36f h8q36g), missing
gen farm_hrs = hrs if farm_work==1  & wage_work==0
replace farm_hrs = 0 if farm_work == 0
gen SB_hrs = hrs if SOB_work==1 & wage_work==0
replace SB_hrs = 0 if SOB_work == 0
gen wage_hrs = hrs if wage_work==1
replace wage_hrs = 0 if wage_work == 0

keep ID HHID farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs 
duplicates drop
merge 1:1 ID HHID  using "${Temp}\\${temppath}\\indiv_frame.dta", keep(using match)
foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs  {
replace `var' = 0 if _merge==2
}
save "${Temp}\\${temppath}\\labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${educ}", clear
egen ID = concat (HHID PID), punct("-")


recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode h4q7 (10/16 = 0 "No") (. 99 1 3 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education = 0 if inrange(h4q9,0, 16)
replace primary_education = 1 if inrange(h4q9,17, 60)
replace primary_education = 0 if formal_education==0

keep ID HHID formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace



// HDDS

use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if h15bq3a ==1 // keep if consumed
rename itmcd item_cd


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

tostring hh, gen(HHID)  format("%32.0f")
collapse (max) A B C D E F G H I J K L, by(HHID)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:1 HHID  using "${Input}\\${country}\\${wave}\\${cover}", 

collapse (max) HDDS, by(HHID)
save "${Temp}\\${temppath}\\HDDS.dta", replace


