/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Extract data for NER2          *
 * Date: December 2023                                                            *
 * -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Niger
global wave  ECVMA 14
global cover  ECVMA2_MS00P1.dta
global indiv_roster  ECVMA2_MS01P1.dta
global indiv_roster2  ECVMA2_MS02P1.dta
global lab_roster ECVMA2_AS2AP1.dta
global lab_roster2  ECVMA2_AS2AP2.dta
global shocks ECVMA2_MS10P1.dta
global housing  ECVMA2_MS06P1.dta
global plot_roster  ECVMA2_AS1P1.dta
global plot_inputs ECVMA2_AS2BP1.dta
global seeds ECVMA2_AS02CP1.dta
global ferts ecvmaas1_p1_en.dta
global meta ECVMA2_0P2.dta
global meta2 ECVMA2_MS00P1.dta
global items ECVMA2_AS03P1.dta
global items_hh ECVMA2_MS07P1.dta
global harvest_rwdta1  ECVMA2_AS2E1P2.dta
global harvest_rwdta2  ECVMA2_AS2E2P2.dta
global perennial  ECVMA2_AS05P2.dta
global geovars_hh NER_HouseholdGeovars_Y1.dta
global geovars_plot NER_PlotGeovariables_Y1.dta
global livestock ECVMA2_AS4AP2.dta
global welfare ECVMA2011_Welfare_en.dta
global coords NER_EA_Offsets.dta
global csption ECVMA2014_P1P2_ConsoMen.dta
global nfe ECVMA2_MS05AP1.dta
global labor_hh ECVMA2_MS04P1.dta
global HDDS ECVMA2_MS12P1.dta

global temppath NER\ECVMA14


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
drop if AS05Q04 == 2
rename AS05Q02 crop_code
decode crop_code, gen(crop_name2)

sort hhid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen parcel_id2 = "missing_line_" + n_str
gen plot_id2 = "missing_line_" + n_str 
drop n 

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename CULTURE crop_code
decode crop_code, generate(crop_name)
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")
egen parcel_id = concat(hhid AS02EQ01), punct("-")
merge m:1 hhid crop_code using `perennial', 

replace plot_id = plot_id2 if _merge ==2 
replace parcel_id = parcel_id2 if _merge==2
replace crop_name = crop_name2 if _merge==2 


keep hhid plot_id crop_name crop_code   crop_name parcel_id

duplicates drop

duplicates report plot_id crop_code crop_name parcel_id
 
save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")

keep hhid EXTENSION
duplicates report hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
egen ID = concat (hhid  MS01Q0), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear 
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
egen ea_id = concat(MS00Q10 MS00Q11 MS00Q12 MS00Q14), punct("-")
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata

use "${Input}\\${country}\\${wave}\\${csption}", clear 
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
rename MENAGE menage
rename GRAPPE grappe
merge m:1 grappe menage using "${Input}\\${country}\\ECVMA 11\\ecvmamen_p1_en.dta", keep(master match) nogen 
rename strate strataid
bys grappe (strataid): replace strataid = strataid[1] if strataid==.
keep hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename  MS00Q10 admin_1 
keep hhid admin_1
decode admin_1, gen(admin_1_name)
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")

rename MS00Q11 admin_2 
keep hhid admin_2
decode admin_2, gen(admin_2_name)
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")

rename MS00Q12 admin_3
keep hhid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
recode MS00Q15 (1 2 = 1 "Yes") (3 = 0 "No"), gen(urban) label(urban)
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${csption}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename hhweight pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
rename AS02BQ06 crop_code

gen month = AS02BQ11
format month %tm 

gen year = 2014
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(hhid crop_code plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")
rename CULTURE crop_code
gen month = AS02EQ06B
replace month=. if AS02EQ06B==99
format month %tm
gen year = 2014 
replace year=2015 if inlist(month, 1, 2)
gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
drop month year
keep  plot_id crop_code harvest_end_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${meta2}", clear

egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")

tostring MS00Q03A, replace
gen month_harvest = substr(MS00Q03A, 3, 2 ) if strlen(MS00Q03A)==8
replace month_harvest = substr(MS00Q03A, 2, 2 ) if strlen(MS00Q03A)==7
destring month_harvest, replace
format month_harvest %tm 
gen year_harvest = substr(MS00Q03A, 5, 4 ) if strlen(MS00Q03A)==8
replace year_harvest = substr(MS00Q03A, 4, 4 ) if strlen(MS00Q03A)==7
destring year_harvest, replace
format year_harvest %ty 

gen harvest_interview_month = ym( year_harvest, month_harvest)
format harvest_interview_month %tmCCYYMon

keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
tostring MS00Q03A, replace
gen month_planting = substr(MS00Q03A, 3, 2 ) if strlen(MS00Q03A)==8
replace month_planting = substr(MS00Q03A, 2, 2 ) if strlen(MS00Q03A)==7
destring month_planting, replace
format month_planting %tm 
gen year_planting = substr(MS00Q03A, 5, 4 ) if strlen(MS00Q03A)==8
replace year_planting = substr(MS00Q03A, 4, 4 ) if strlen(MS00Q03A)==7
destring year_planting, replace
format year_planting %ty 

gen planting_interview_month = ym( year, month)
format planting_interview_month %tmCCYYMon
duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 

use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")

rename (CULTURE MS00Q10 AS02EQ07B) (crop_code region unit)

gen conversion = AS02EQ07C / AS02EQ07A
keep region unit crop_code conversion

bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
replace conversion=. if unit==99
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0 |conversion==.
collapse (median) conversion (sd) sd= conversion , by(unit)
tempfile Conversions
save `Conversions', replace


use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS05Q02 crop_code
drop if AS05Q04 == 2
recode AS05Q07 (1 = 1) (3 = 9 ) (4=5) (5 = 6) (6 = 7) (7 = 8), gen(unit)
merge m:1 unit using `Conversions', nogen keep(master match)
gen harvest_kg_per = AS05Q05 * AS05Q06 * conversio

sort hhid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str 
drop n unit

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
merge m:1 hhid using "${Temp}\\${temppath}\\admin1", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin2", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin3", keep(master match) nogen
rename (MS00Q14 MS00Q10 MS00Q11 MS00Q12) (ea_id region departement commune)
rename CULTURE AS02EQ110B 
rename AS02EQ110B crop_code
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")
merge m:1 crop_code hhid using `perennial'

replace plot_id = plot_id2 if _merge ==2 
replace ea=. if ea==999

gen harvest_kg = AS02EQ07C
replace harvest_kg=. if AS02EQ07B==99
replace harvest_kg = . if AS02EQ06A==0
replace harvest_kg = . if harvest_kg==999998
replace harvest_kg=0 if AS02EQ07A==0
replace harvest_kg = harvest_kg_per if _merge==2

drop _merge
gen unit = AS02EQ07F
merge m:1  unit using `Conversions', keep(master match)
gen unfinished_harvest= AS02EQ07E * conversion
egen harvest_kg_temp = rowtotal(harvest_kg unfinished_harvest), missing
replace harvest_kg = harvest_kg_temp if AS02EQ07D==2

recode AS02EQ08 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(crop_shock) label(crop_shock)
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id crop_code  admin_1 admin_2 admin_3 hhid)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
rename CULTURE AS02EQ110B
merge m:1 GRAPPE MENAGE EXTENSION AS02EQ110B using "${Input}\\${country}\\${wave}\\${harvest_rwdta2}",  keep(master match) keepusing(AS02EQ16) nogen
rename AS02EQ110B crop_code 
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")

gen pct_area_harvested = (100 - AS02EQ09)
replace pct_area_harvested = . if AS02EQ09>100
replace pct_area_harvested= 100 if AS02EQ08==2
keep hhid plot_id crop_code pct_area_harvested
duplicates drop
save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
merge m:1 hhid using "${Temp}\\${temppath}\\admin1", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin2", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin3", keep(master match) nogen
rename (MS00Q14 MS00Q10 MS00Q11 MS00Q12) (ea_id region departement commune)
rename CULTURE AS02EQ110B 
rename AS02EQ110B crop_code
replace ea=. if ea==999
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")

recode AS02EQ08 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(crop_shock) label(crop_shock)
 
recode AS02EQ10 (3 = 1 "Yes") (. 9 = .) (else = 0 "No"), gen(drought_shock) label(drought_shock) 
replace drought_shock=0 if AS02EQ08==2

recode AS02EQ10 (4 = 1 "Yes") (. 9 = .) (else = 0 "No"), gen(flood_shock) label(flood_shock) 
replace flood_shock=0 if AS02EQ08==2

recode AS02EQ10 (1 = 1 "Yes") (. 9 = .) (else = 0 "No"), gen(pests_shock) label(pests_shock) 
replace pests_shock=0 if AS02EQ08==2

gen pct_area_harvested = (100 - AS02EQ09)
replace pct_area_harvested = . if AS02EQ09>100
replace pct_area_harvested= 100 if AS02EQ08==2
gen pct_lost = 100 - pct_area_harvested
replace pct_lost = pct_lost/ 100 

keep hhid plot_id crop_shock pests_shock  drought_shock flood_shock  crop_code pct_lost
duplicates drop
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount

use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")

rename (CULTURE MS00Q10 AS02EQ07B) (crop_code region unit)

gen conversion = AS02EQ07C / AS02EQ07A
keep region unit crop_code conversion

bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
replace conversion=. if unit==99
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0 |conversion==.
collapse (median) conversion (sd) sd= conversion , by(unit)
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS05Q02 crop_code
drop if AS05Q04 == 2

sort hhid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str 
drop n

recode AS05Q10B (1 = 1) (3 = 9 ) (4=5) (5 = 6) (6 = 7) (7 = 8), gen(unit)
merge m:1 unit using `Conversions', nogen keep(master match) 
gen harvest_sold_kg_per = AS05Q10A * conversio
replace harvest_sold_kg_per = 0 if AS05Q05==0
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS02EQ110B crop_code
gen harvest_sold_kg = AS02EQ12C 
replace harvest_sold_kg = 0 if AS02EQ11==2 | AS02EQ110C==0
collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( crop_code hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge m:1 crop_code hhid using `perennial'

replace harvest_sold_kg = harvest_sold_kg_per if _merge==2
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m hhid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match)  nogen
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace

// harvest sold value
use "${Input}\\${country}\\${wave}\\${perennial}", clear

egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS05Q02 crop_code
drop if AS05Q04 == 2

sort hhid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str 
drop n 
gen harvest_sold_value_per = AS05Q11

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS02EQ110B crop_code

merge m:1 crop_code hhid using `perennial'

gen harvest_sold_value = AS02EQ13 
replace harvest_sold_value = harvest_sold_value_per if _merge==2

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by(crop_code hhid)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS05Q02 crop_code
drop if AS05Q04 == 2

sort hhid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str 
drop n
tempfile perennial
save `perennial', replace


use "${Input}\\${country}\\${wave}\\${harvest_rwdta2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS02EQ110B crop_code
keep hhid  crop_code 
duplicates drop
merge m:1 crop_code hhid using `perennial'


valuation_median_crops_noea_sort hhid  crop_code  

main_crop_def crop_code


keep plot_id harvest_value crop_code main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
rename AS02BQ06 crop_code
recode AS02BQ07 (0 9 = .) (1= 0 "No") (2=1 "Yes"), gen(intercropped) label(intercropped)
keep crop_code plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")
rename CULTURE crop_code
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS05Q02 crop_code
drop if AS05Q04 == 2

sort hhid   (crop_code)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str 
drop n 

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS02EQ01 AS02EQ03), punct("-")
rename CULTURE crop_code
merge m:1 crop_code hhid using `perennial'

merge m:1 crop_code plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

lab def main_crop 1 "Millet" 2 "Sorghum" 3 "Paddy rice"4 "Maize"5 "Souchet"6 "Wheat"7 "Fonio"8 "cowpeas"9 "Voandzou"10 "Nuts"11 "Gombo"12 "Sorrel"13 "Sesame"14 "Cassava"15 "Sweet Potato"16 "Potato"17 "Pepper"20 "Mint" 23 "Parsley" 24 "Spice(pepper)"25 "Melon" 26 "Watermelon"27 "Lettuce"28 "Cabbage"29 "Tomato"32 "Eggplant"33 "Onion"34 "Cucumber"35 "Squash"36 "Garlic"37 "Green peas" 38 "Gourd"42 "Amarante(Tchapata)"43 "Cotton" 44 "Beets"48 "Other(specify)"

gen codesmain_crop = main_crop
gen codescrop_code = crop_code
foreach c in main_crop crop_code {
lab val `c' main_crop
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
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")

gen area_self_reported = AS01Q06 * 0.0001 // m² to hectares 
replace area_self_reported = . if AS01Q06 == 999999

gen plot_area_GPS= AS01Q07 * 0.0001 // m² to hectares
replace plot_area_GPS = . if AS01Q07 == 999999
replace plot_area_GPS = . if AS01Q07 == 0 // many are 0 

merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid hhid plot_id
sort hhid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
mi impute pmm plot_area_GPS area_self_reported i.admin_3, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys hhid: egen farm_size = total(plot_area_GPS), missing

keep hhid plot_id   plot_area_GPS farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace


// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
rename AS02BQ06 crop_code
merge m:1 plot_id using "${Temp}\\${temppath}\\plot_area.dta", keep(master match)
replace AS02BQ08 = . if AS02BQ08>999998
gen pct_area_planted = (AS02BQ08/(plot_area *10000))*100
replace pct_area_planted = . if pct_area_planted>100 
replace pct_area_planted = 0 if pct_area_planted<1
keep plot_id hhid crop_code  pct_area_planted
duplicates drop
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace

// improved 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
rename AS02BQ06 crop_code
recode AS02BQ09 (0 9 = .) (1 2 = 0 "No") (3 4 = 1 "Yes"), gen(improved) label(improved)
collapse (max) improved, by(hhid plot_id crop_code)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (CULTURE MS00Q10 AS02EQ07B) (crop_code region unit)
gen conversion = AS02EQ07C / AS02EQ07A
keep region unit crop_code conversion
bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
replace conversion=. if unit==99
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0 |conversion==.
collapse (median) conversion (sd) sd= conversion , by(unit)
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
merge m:1 GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (AS02CQ04 MS00Q10) (crop_code region)
keep if inlist(AS02CQ02, 11, 12, 13, 14, 15, 16, 17) // keep seeds
recode AS02CQ05B (1 = 1) (3 = 5) (else=.), gen(unit) 
merge m:1 unit using `Conversions', keep(master match) 
gen seed_kg = AS02CQ05A * conversion
replace seed_kg = AS02CQ05A  if AS02CQ05B==1 
replace seed_kg = AS02CQ05A if AS02CQ05B==5 // litre
replace seed_kg = AS02CQ05A * 0.001 if AS02CQ05B==2 // gram 
replace seed_kg = 0 if AS02CQ03==2 // only 5% of seeds are not converted, half are tiya, the other half "sachet"
keep hhid crop_code seed_kg
collapse (sum) seed_kg (count) n_seed_kg=seed_kg, by(hhid crop_code)
replace seed_kg=. if n_seed_kg==0
drop if crop_code==.
tempfile seed_plot
save `seed_plot', replace

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
merge m:1 hhid using  "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 hhid using  "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 hhid using  "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 plot_id using "${Temp}\\${temppath}\\plot_area.dta", keep(master match) nogen
rename AS02BQ06 crop_code
merge m:1 hhid crop_code using `seed_plot', keep(master match)  
bys hhid crop_code: egen total_land_area = total(plot_area), missing
gen indicator = plot_area/total_land_area
replace seed_kg= seed_kg*indicator 
keep hhid plot_id crop_code seed_kg admin_1 admin_2 admin_3
save "${Temp}\\${temppath}\\seed_kg.dta", replace
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace


// seed_kg_sold 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename (CULTURE MS00Q10 AS02EQ07B) (crop_code region unit)
gen conversion = AS02EQ07C / AS02EQ07A
keep region unit crop_code conversion
bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
replace conversion=. if unit==99
collapse (median) conversion (sd) sd= conversion, by(unit)
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (AS02CQ04 ) (crop_code )

keep if inlist(AS02CQ02, 11, 12, 13, 14, 15, 16, 17) // keep seeds
recode AS02CQ08B (1 = 1) (3 = 5) (else=.), gen(unit) 
merge m:1 unit using `Conversions', keep(master match) nogen 
gen seeds_amount_purchased_kg = AS02CQ08A * conversion
replace seeds_amount_purchased_kg = AS02CQ08A  if AS02CQ08B==1 
replace seeds_amount_purchased_kg = AS02CQ08A if AS02CQ08B==5 // litre
replace seeds_amount_purchased_kg = AS02CQ08A * 0.001 if AS02CQ08B==2

collapse (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg = seeds_amount_purchased_kg, by(crop_code hhid)
replace seeds_amount_purchased_kg = . if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (AS02CQ04 ) (crop_code )
keep if inlist(AS02CQ02, 11, 12, 13, 14, 15, 16, 17) // keep seeds

gen seed_value_temp = AS02CQ08C

collapse  (sum) seed_value_temp (count) n_seed_value_temp = seed_value_temp , by(crop_code hhid )
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (AS02CQ04 ) (crop_code )
keep crop_code hhid
duplicates drop

val_median_seeds_noimp_noea hhid hhid crop_code 

keep  plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")

* 1) Family labor 

foreach var of varlist AS02AQ17B AS02AQ18B AS02AQ19B AS02AQ20B AS02AQ21B AS02AQ22B {
    replace `var'=. if `var'==99
}
egen  PPtotal_family_labor_days = rowtotal(AS02AQ17B AS02AQ18B AS02AQ19B AS02AQ20B AS02AQ21B AS02AQ22B), missing

* 2) Hired labor days
 
gen hired_man_days = AS02AQ24B
replace hired_man_days=. if hired_man_days==999

gen hired_woman_days = AS02AQ24C
replace hired_woman_days=. if hired_woman_days==999

gen hired_child_days = AS02AQ24D
replace hired_child_days=. if hired_child_days==999


egen PPtotal_hired_labor_days= rowtotal(hired_man_days hired_woman_days hired_child_days), missing
replace  PPtotal_hired_labor_days=0 if AS02AQ24A==2

gen wage_h = AS02AQ24E  
gen wage_w = AS02AQ24E  
gen wage_c = AS02AQ24E  

valuation_median_wages hhid wage_h wage_w wage_c

gen man_labor_value = man_wage * hired_man_days
gen woman_labor_value = woman_wage * hired_woman_days
gen child_labor_value = child_wage * hired_child_days
egen PPhired_labor_value = rowtotal (*_labor_value), missing


* 3) Other (free) labor

gen other_man_days = AS02AQ23B
replace other_man_days=. if other_man_days==999

gen other_woman_days = AS02AQ23C
replace other_woman_days=. if other_woman_days==999

gen other_child_days = AS02AQ23D
replace other_child_days=. if other_child_days==999

egen  PPtotal_other_labor_days= rowtotal(other_*), missing
replace  PPtotal_other_labor_days=0 if AS02AQ23A==2

* 4) Total labor days

egen PPtotal_labor_days = rowtotal(PPtotal_hired_labor_days PPtotal_family_labor_days PPtotal_other_labor_days), missing


tempfile PPtotal_labor_days 
save `PPtotal_labor_days', replace 

// PH labor

use "${Input}\\${country}\\${wave}\\${lab_roster2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS02AQ01 AS02AQ03), punct("-")

* 1) Family labor 

foreach var of varlist AS02AQ28B AS02AQ29B AS02AQ30B AS02AQ31B AS02AQ32B AS02AQ33B AS02AQ36B AS02AQ37B AS02AQ38B AS02AQ39B AS02AQ40B AS02AQ41B {
    replace `var'=. if `var'==99
}
egen PHtotal_family_labor_days = rowtotal(AS02AQ28B AS02AQ29B AS02AQ30B AS02AQ31B AS02AQ32B AS02AQ33B AS02AQ36B AS02AQ37B AS02AQ38B AS02AQ39B AS02AQ40B AS02AQ41B), missing

* 2) Hired labor 

gen hired_man_days = AS02AQ35B

gen hired_woman_days = AS02AQ35C

gen hired_child_days = AS02AQ35D


egen PHtotal_hired_labor_days= rowtotal(hired_man_days hired_woman_days hired_child_days), missing
replace PHtotal_hired_labor_days=0 if AS02AQ35A==2

gen wage1_m = AS02AQ35E 
gen wage1_w = AS02AQ35E 
gen wage1_c = AS02AQ35E 

gen wage2_m = AS02AQ35E 
gen wage2_w = AS02AQ35E 
gen wage2_c = AS02AQ35E 

valuation_median_wages hhid wage1_m wage1_w wage1_c

gen man_labor_value = man_wage * hired_man_days
gen woman_labor_value = woman_wage * hired_woman_days
gen child_labor_value = child_wage * hired_child_days
egen PHhired_labor_value = rowtotal (*_labor_value), missing

* 3) Other  labor 

gen other_man_days = AS02AQ34B
replace other_man_days=. if other_man_days==999

gen other_woman_days = AS02AQ34C
replace other_woman_days=. if other_woman_days==999

gen other_child_days = AS02AQ34D
replace other_child_days=. if other_child_days==999

egen PHtotal_other_labor_days= rowtotal(other_man_days other_woman_days other_child_days), missing
replace PHtotal_other_labor_days=0 if AS02AQ34A==2


collapse (sum) PHtotal_family_labor_days PHtotal_hired_labor_days PHhired_labor_value PHtotal_other_labor_days (count) n_PHtotal_family_labor_days = PHtotal_family_labor_days n_PHtotal_hired_labor_days = PHtotal_hired_labor_days n_PHhired_labor_value = PHhired_labor_value n_PHtotal_other_labor_days = PHtotal_other_labor_days , by(plot_id hhid)
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
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
gen inorganic_fertilizer= 1 if inlist(1, AS02AQ09A, AS02AQ10A, AS02AQ11A, AS02AQ12A)
replace inorganic_fertilizer=0 if AS02AQ09A==2 & AS02AQ10A==2 & AS02AQ11A==2 & AS02AQ12A==2
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (CULTURE MS00Q10 AS02EQ07B) (crop_code region unit)
gen conversion = AS02EQ07C / AS02EQ07A
keep region unit crop_code conversion
bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
replace conversion=. if unit==99
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0 |conversion==.
collapse (median) conversion (sd) sd= conversion , by(region unit)
tempfile Conversions
save `Conversions', replace
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
rename MS00Q10 region

gen inorganic_fertilizer= 1 if inlist(1, AS02AQ09A, AS02AQ10A, AS02AQ11A, AS02AQ12A)
replace inorganic_fertilizer=0 if AS02AQ09A==2 & AS02AQ10A==2 & AS02AQ11A==2 & AS02AQ12A==2

recode AS02AQ09C (3 = 5) (else=.), gen(unit) // converting tiya
merge m:1 region unit using `Conversions', keep(master match) nogen 
gen UREA_kg = AS02AQ09B * conversion
replace UREA_kg = AS02AQ09B if AS02AQ09C==1
replace UREA_kg = 0 if AS02AQ09A==2
gen nitrogen_kg1 = UREA_kg * 0.46
drop conversion unit

* DAP 
recode AS02AQ10C (3 = 5) (else=.), gen(unit) // converting tiya
merge m:1 region unit using `Conversions', keep(master match) nogen 
gen DAP_kg = AS02AQ10B * conversion
replace DAP_kg = AS02AQ10B if AS02AQ10C==1
replace DAP_kg = 0 if AS02AQ10A==2
gen nitrogen_kg2 = DAP_kg * 0.18
drop conversion unit

* NPK 
recode AS02AQ11C (3 = 5) (else=.), gen(unit) // converting tiya
merge m:1 region unit using `Conversions', keep(master match) nogen 
gen NPK_kg = AS02AQ11B * conversion
replace NPK_kg = AS02AQ11B if AS02AQ11C==1
replace NPK_kg = 0 if AS02AQ11A==2
gen nitrogen_kg3 = NPK_kg * 0.15
drop conversion unit
 
egen nitrogen_kg = rowtotal(nitrogen_kg*), missing
replace nitrogen_kg= 0 if inorganic_fertilizer==0

collapse (sum) nitrogen_kg  UREA_kg DAP_kg NPK_kg  (count) n_nitrogen_kg = nitrogen_kg n_NPK_kg = NPK_kg n_DAP_kg = DAP_kg n_UREA_kg = UREA_kg  , by(plot_id hhid)
foreach var in nitrogen_kg NPK_kg DAP_kg UREA_kg    {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta1}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (CULTURE MS00Q10 AS02EQ07B) (crop_code region unit)
gen conversion = AS02EQ07C / AS02EQ07A
keep region unit crop_code conversion
bys region crop_code unit: egen med_conv = median(conversion)
replace conversion = med_conv 
replace conversion = 1 if unit==1
replace conversion=. if unit==99
collapse (median) conversion, by(region crop_code unit)
drop if inlist(., region, crop_code, unit)
drop if conversion==0 |conversion==.
collapse (median) conversion (sd) sd= conversion , by(region unit)
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename (AS02CQ04 ) (crop_code )
rename ( MS00Q10 MS00Q11 MS00Q12 MS00Q14 ) ( region departement commune ea)

// amount purchased and value
gen t = "NPK" if AS02CQ02==5 // this variable is created to create conditions in the loop below
replace t = "UREA" if AS02CQ02==3
replace t = "DAP" if AS02CQ02==4

recode AS02CQ08B (1 = 1) (3 = 5) (else=.), gen(unit) 
merge m:1 region unit using `Conversions', keep(master match) nogen

foreach n in NPK UREA DAP {
gen `n'_purchased_kg = AS02CQ08A * conversion
replace `n'_purchased_kg = AS02CQ08A  if AS02CQ08B==1 & t=="`n'"
replace `n'_purchased_kg = AS02CQ08A if AS02CQ08B==8 & t=="`n'" // litre
replace `n'_purchased_kg = AS02CQ08A * 0.001 if AS02CQ08B==2 & t=="`n'"

gen `n'_purchased_value = AS02CQ08C if t=="`n'"
}

collapse (max) UREA_purchased_kg DAP_purchased_kg NPK_purchased_kg  UREA_purchased_value DAP_purchased_value NPK_purchased_value  , by(hhid)

valuation_median_fert_price hhid UREA

valuation_median_fert_price hhid DAP

valuation_median_fert_price hhid NPK


collapse (sum) UREA_value DAP_value NPK_value , by(hhid) 
merge 1:m hhid using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

foreach n in NPK UREA DAP  {
    gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
gen organic_fertilizer = 1 if inlist(1, AS02AQ06A, AS02AQ07A)
replace  organic_fertilizer = 0 if AS02AQ07A==2 & AS02AQ06A==2
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id= concat(hhid AS01Q01 AS01Q03) , punct("-")
recode AS02AQ13A (2 = 0 "No") (1 = 1 "Yes") (. 9 = .), gen(used_pesticides) label(used_pesticides)
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")
recode AS01Q14 (1 2 4 = 1 "Yes") (3 5 6 = 0 "No") , gen(plot_owned) label(plot_owned)
recode AS01Q15 (1/4 = 1 "Yes") (5 = 0 "No"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace


// irrigated
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")
recode  AS01Q31 (5 = 0 "No") (7 9 =.) (else = 1 "Yes"), gen(irrigated) label(irrigated)
replace irrigated=1 if AS01Q35==1
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace


// erosion protection
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")
recode AS01Q27 (1 = 1 "Yes") (2 = 0 "No") (. 9 = .), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
gen tractor= 1 if AS03Q02==10 & AS03Q08==1 
replace tractor= 1 if AS03Q02==10 & AS03Q09==1 
replace tractor= 0 if AS03Q02==10 & AS03Q03==2
replace tractor= 0 if AS03Q02==10 & AS03Q03==1 & AS03Q09==2 & AS03Q08==2
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
merge m:1 GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}"
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")
recode AS01Q39 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
replace fallow_plot= 0 if AS01Q38==1
bys hhid: egen nb_fallow_plots = total(fallow_plot), missing
replace nb_fallow_plots = 0 if _merge==2
keep hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
merge m:1 GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}"
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")
recode AS01Q39 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
replace fallow_plot= 0 if AS01Q38==1
bys hhid: egen nb_plots = count(fallow_plot)
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
recode MS02Q04 (1 =1 "Yes") (2/4 = 0 "No"), gen(formal_education) label(formal_education)
recode MS02Q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education=1 if inlist(MS02Q23, 3, 4, 5, 6, 7)
replace primary_education=0 if inlist(MS02Q23, 1, 2)
replace primary_education= 0 if formal_education==0

bys hhid: egen hh_primary_education= max(primary_education) 
bys hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(hhid)
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
recode MS06Q23 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
replace hh_electricity_access=1 if inlist(MS06Q26, 1, 2, 5)
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
gen age = MS01Q06A  
replace age=. if age==99 | age==98
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort hhid: egen dep=total(dep_temp)
bysort hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep  if nondep==0
collapse (max) hh_dependency_ratio, by(hhid)
keep hhid hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
recode AS4AQ05 ( 2 . = 0 "No") (1 = 1 "Yes"), gen(livestock) label(livestock)
merge m:1  GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${cover}",
replace livestock = 0 if _merge==2
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
collapse (max) livestock, by(hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
xtile cons_quint= dtet, n(5)  
keep hhid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
egen hhid= concat(GRAPPE MENAGE EXTENSION), punct("-")
rename dtet totcons
keep hhid totcons 
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
keep if MS01Q02==1
keep EXTENSION GRAPPE MENAGE MS01Q0
merge 1:m GRAPPE MENAGE EXTENSION   using "${Input}\\${country}\\${wave}\\${plot_roster}", keep(match using) nogen
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen plot_id = concat(hhid AS01Q01 AS01Q03), punct("-")
gen  manager_id = AS01Q45
replace manager_id = MS01Q0 if manager_id==98
sort  hhid (manager_id)
collapse (first) manager_id  , by(hhid plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = MS01Q0  // this is the HH member id 
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
merge 1:m  hhid manager_id using `ID_list', keep(match ) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode MS01Q01 (2=1 "Yes") (1=0 "No"), gen(female_manager) label(female_manager)
recode MS01Q06A (98 99 = .), gen(age_manager)
recode MS01Q15 ( 2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married_manager) label(married_manager)
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
gen manager_id =  MS02Q00  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode MS02Q04 (1 =1 "Yes") (2/4 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode MS02Q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager=0 if inlist(MS02Q23, 3, 4, 5, 6, 7)
replace primary_education_manager=1 if inlist(MS02Q23, 1, 2)
replace primary_education_manager= 0 if formal_education_manager==0
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${housing}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
duplicates report hhid // one duplicate
rename MS11Q00 respondent_id 
sort  hhid (respondent_id)
collapse (first) respondent_id, by(hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename MS01Q0 respondent_id // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode MS01Q01 (2=1 "Yes") (1=0 "No"), gen(female_respondent) label(female_respondent)
recode MS01Q06A (98 99 = .), gen(age_respondent)
recode MS01Q15 ( 2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married_respondent) label(married_respondent)
keep hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
gen respondent_id = MS02Q00  // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode MS02Q04 (1 =1 "Yes") (2/4 = 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode MS02Q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent=0 if inlist(MS02Q23, 3, 4, 5, 6, 7)
replace primary_education_respondent=1 if inlist(MS02Q23, 1, 2)
replace primary_education_respondent= 0 if formal_education_respondent==0
keep hhid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
recode MS10Q02 (2= 0 "No") (1 = 1 "Yes"), gen(hh_shock) 
collapse (max) hh_shock, by(hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
bys hhid: egen hh_size = count(MS01Q0)
keep hhid hh_size
duplicates drop
isid hhid
save "${Temp}\\${temppath}\\size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename AS03Q02 itemid
drop if itemid==18 // we exclude buildings
recode AS03Q03 (1 = 1) (2  = 0) , gen(hh_owns_) 
keep hhid itemid hh_owns_
reshape wide hh_owns_ , i(hhid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
recode MS07Q02 ( 2 = 0 ) (1 = 1), gen (hh_owns) 
keep hh_owns hhid MS07Q01
reshape wide hh_owns , i(hhid) j(MS07Q01)
factor hh_owns*, pcf 
predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
recode MS05Q11 ( 2 = 0 "No") (1 = 1 "Yes") (9 = .) , gen(nonfarm_enterprise) label(nonfarm_enterprise)
keep hhid nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen ea_id = concat(MS00Q10 MS00Q11 MS00Q12 MS00Q14), punct("-")
rename (GRAPPE MENAGE) (grappe menage)
merge m:1 grappe using "${Input}\\${country}\\ECVMA 11\\NER_EA_Offsets", keep(master match) nogen
drop if EXTENSION==2 | EXTENSION==3 // drop if hh moved or split off
rename (LAT_DD_MOD LON_DD_MOD) (lat_modified lon_modified)
keep ea_id lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone (no geovars)


// distance to nearest road (no geovars)

// distance to nearest population center (no geovars)

 
// distance to nearest market ((no geovars)
 

// plot slope (no geovars)

// plot elevation (no geovars)


// total wetness index (no geovars)

// soil variables (no geovars)

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen ID = concat (hhid MS01Q0), punct("-")
recode MS01Q01 (2=1 "Yes") (1=0 "No"), gen(female) 
recode MS01Q06A (98 99 = .), gen(age)
recode MS01Q15 ( 2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married) 
replace married = 0 if married==.
decode MS01Q02, generate(relationship_head) 
replace  relationship_head = ustrregexra(relationship_head,`"[^a-zA-Z0-9]"',"")
replace  relationship_head = strlower(relationship_head)
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

keep hhid ID married female age relationship_head MS01Q06B
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting (absent)


// labor 
use "${Input}\\${country}\\${wave}\\${labor_hh}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
rename MS04Q00 MS01Q0
merge m:1 MS01Q0 GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${indiv_roster}",
egen ID = concat (hhid MS01Q0), punct("-")

recode MS04Q01 (1 = 1) (2= 0) (9 = .), gen( farm_work)
recode MS04Q02 (1 = 1) (2= 0) (9 = .), gen( SOB_work)
recode MS04Q03 (1 = 1) (2= 0) (9 = .), gen( wage_work)

// nb of working age members
gen working_age = MS01Q06A>=6 
bys hhid: egen nb_members_working_age = total(working_age)


// industry:
gen ind_ag = MS04Q23 >= 11 & MS04Q23 <=40  // Agriculture 
gen ind_fish = MS04Q23 == 51 | MS04Q23==52 // fishing
gen ind_mining = MS04Q23 >= 60 & MS04Q23==72 // mining
gen ind_manuf = MS04Q23 >= 81 & MS04Q23 <= 292 // manuf
gen ind_const = MS04Q23 >= 301 & MS04Q23 <= 302 // construc
gen ind_serv = MS04Q23 >= 310 & MS04Q23<= 430 // services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if MS04Q24==4 | MS04Q29==7 | MS04Q29==8 | MS04Q29==9 | MS04Q29==7 // remove self employment
replace `var' = 0 if MS04Q20==2 // did not work
}


gen hour_job1 = MS04Q28
replace hour_job1 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed
gen hour_job2 = MS04Q52
replace hour_job2 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed

gen day_job1 = MS04Q27
replace day_job1 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed
gen day_job2 = MS04Q53
replace day_job2 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed

gen month_job1 = MS04Q25
replace month_job1 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed
gen month_job2 = MS04Q51
replace month_job2 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed

gen week_job1 = MS04Q26
replace week_job1 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed
gen week_job2 = MS04Q51B
replace week_job2 = 0 if MS04Q05==2 & MS04Q06==2 //answered "no" to filter questions = unemployed

recode MS04Q22 (1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 = 1) (. 9999 =.) (else = 0) , gen(farm_job1)
recode MS04Q48 (1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 = 1) (. 9999 =.) (else = 0) , gen(farm_job2)
replace farm_job1 = 0 if farm_job1==1 & inlist(MS04Q24, 1, 2, 3, 7)
replace farm_job2 = 0 if farm_job2==1 & inlist(MS04Q50, 1, 2, 3, 7)
recode MS04Q22 ( 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212 = 1) (. 9999 =.) (else = 0) , gen(SB_job1)
recode MS04Q48 ( 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212 = 1) (. 9999 =.) (else = 0) , gen(SB_job2)
replace SB_job1 = 0 if SB_job1==1 & inlist(MS04Q24, 1, 2, 3, 7)
replace SB_job2 = 0 if SB_job2==1 & inlist(MS04Q50, 1, 2, 3, 7)
recode MS04Q22 ( 1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212 = 0) (. 9999 =.) (else = 1) , gen(wage_job1)
recode MS04Q48 ( 1101 1102 1103 1104 1105 1106 1107 1201 1202 1203 1204 1205 6101 6202 6203 6204 6205 6206 6207 6209 6210 6211 6212  = 0) (. 9999 =.) (else = 1) , gen(wage_job2)
replace wage_job1 = 1 if wage_job1==0 & inlist(MS04Q24, 1, 2, 3, 7)
replace wage_job2 = 1 if wage_job2==0 & inlist(MS04Q50, 1, 2, 3, 7)

gen av_hours1 = (month_job1 * week_job1 * hour_job1 * day_job1) / 52 // (week average of hours)
gen av_hours2 = (month_job2 * week_job2 * hour_job2 * day_job2) / 52 // (week average of hours)

foreach act in farm SB wage {
gen `act'_hrs1 = av_hours1 if `act'_job1 == 1
replace `act'_hrs1 = 0 if `act'_job1 == 0
replace `act'_hrs1 = 0 if MS04Q20==2 
gen `act'_hrs2 = av_hours2 if `act'_job2 == 1
replace `act'_hrs2 = 0 if `act'_job2 == 0
replace `act'_hrs2 = 0 if MS04Q46==2 
egen `act'_hrs = rowtotal(`act'_hrs1 `act'_hrs2), missing
}

foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep ID hhid  farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education
use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
egen ID = concat (hhid MS02Q00), punct("-")
rename MS02Q00 MS01Q0
merge m:1 MS01Q0 GRAPPE MENAGE EXTENSION using "${Input}\\${country}\\${wave}\\${indiv_roster}", nogen

recode MS02Q04 (1 =1 "Yes") (2/4 = 0 "No"), gen(formal_education) label(formal_education)
recode MS02Q12 (1 2 = 0 "No") (.=.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education=1 if inlist(MS02Q23, 3, 4, 5, 6, 7)
replace primary_education=0 if inlist(MS02Q23, 1, 2)
replace primary_education= 0 if formal_education==0
foreach var in formal_education primary_education {
	replace `var' = 0  if MS01Q06A<6
}
keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace


// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if MS12Q02 ==1 // keep if consumed
rename MS12Q01 food_id

gen A = food_id>=701 & food_id<=712 | food_id>=810 & food_id<=813 | food_id>=816 & food_id<=821
gen B = food_id>=748 & food_id<=753
gen C = food_id>=717 & food_id<=734 | food_id>=740 & food_id<=743
gen D = food_id>=754 & food_id<=765
gen E = food_id>=766 & food_id<=773
gen F = food_id>=785 & food_id<=785
gen G = food_id>=774 & food_id<=778
gen H = food_id>=814 & food_id<=815
gen I = food_id>=786 & food_id<=792
gen J = food_id>=713 & food_id<=714 | food_id>=779 & food_id<=784
gen K = food_id>=715 & food_id<=716 | food_id>=793 & food_id<=798
gen L = food_id>=744 & food_id<=736

collapse (max) A B C D E F G H I J K L, by( GRAPPE MENAGE EXTENSION)
 egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m GRAPPE MENAGE EXTENSION  using "${Input}\\${country}\\${wave}\\${HDDS}", 
egen hhid = concat(GRAPPE MENAGE EXTENSION), punct("-")
collapse (max) HDDS, by(hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace

