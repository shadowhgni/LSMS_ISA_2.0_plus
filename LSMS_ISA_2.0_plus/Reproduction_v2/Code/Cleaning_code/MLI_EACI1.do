/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for MLI1									          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Mali 
global wave  EACI 14
global cover  EACICONTROLE_p1.dta
global cover2  EACICONTROLE_p2.dta
global indiv_roster  EACIIND_p1.dta
global lab_roster  EACIMAINOUVRE_p1.dta
global lab_roster2  EACIS2F_p2.dta
global shocks EACICHOC_p2.dta
global housing  EACIMEN_p1.dta
global assets EACIACT_p1.dta
global plot_roster  EACIEXPLOI_p1.dta
global plot_inputs EACICULTURE_p1.dta
global seeds EACIS1E_p2.dta
global ferts EACIS2C_p2.dta
global ferts_purch EACIS2D_p2.dta
global items EACIS5_p2.dta
global harvest_rwdta  EACIS3A_p2.dta
global perennial  EACIS3B_p2.dta
global geovars_hh eaci_geovariables_2014.dta
global livestock EACIS4A_p2.dta
global weights EACIPOIDS.dta
global HDDS EACIALI_p1.dta
global csption  eaci2014_agregatconso.dta

global temppath MLI\EACI14


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s3bq01==.
drop if s3bq03==2
drop if s3bq10b==9
egen hhid = concat(grappe menage ), punct("-")

sort hhid (s3bq01)
gen n = _n
tostring n, gen(n_str)
gen parcel_id2 = "missing_line_" + n_str
gen plot_id2 = "missing_line_" + n_str 

duplicates report grappe menage s3bq01
rename s3bq01 s3aq03b
decode s3aq03b, generate(crop_name2) 
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear 
decode s3aq03b, generate(crop_name) 
egen hhid = concat(grappe menage ), punct("-")

egen plot_id= concat( grappe menage s3aq01 s3aq02)  , punct("-")
egen parcel_id= concat( grappe menage s3aq01) , punct("-")

merge m:1 grappe menage s3aq03b using `perennial', 
rename s3aq03b crop_code
replace crop_name = crop_name2 if _merge==2 
replace plot_id = plot_id2 if _merge==2 
replace parcel_id = parcel_id2 if _merge==2 



keep hhid plot_id crop_name crop_code  parcel_id _merge

duplicates drop

duplicates report plot_id crop_code crop_name parcel_id 

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe menage ), punct("-")

keep hhid 
duplicates report hhid 

save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
egen ID = concat (hhid s01q00 ), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear 
egen hhid = concat(grappe menage ), punct("-")

rename grappe ea_id
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\EACI 17\\EACI17_ECHANTILLON.dta", clear // extract the strata id
keep grappe strate
duplicates drop
merge 1:m grappe using "${Input}\\${country}\\${wave}\\${weights}", keep(match using)
merge 1:m grappe menage using "${Input}\\${country}\\${wave}\\${cover}", keep(master match) nogen // extract cercle id to identify strata for grappes that are not matched
egen hhid = concat(grappe menage ), punct("-")

rename s00q01 admin_1  
egen admin_2 = concat(admin_1 s00q02), punct("-")

bys admin_2 s00q04 : assert strate==strate[1] | mi(strate) | mi(strate[1])
bys admin_2 s00q04: egen strataid2= max(strate)
rename strate strataid 
replace strataid = strataid2 if _merge==2
rename grappe ea_id 

keep hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace


// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe menage ), punct("-")
rename s00q01 admin_1 
keep hhid admin_1
decode admin_1, gen(admin_1_name)

duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace


// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe menage ), punct("-")
egen admin_2 = group(s00q01 s00q02)
keep hhid admin_2
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe menage ), punct("-")
egen admin_3 = group(s00q01 s00q02 s00q03)
keep hhid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe menage ), punct("-")
recode s00q04 (1 = 1 "Yes") (2 =0 "No"), gen(urban) label(urban)
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${weights}", clear
egen hhid = concat(grappe menage ), punct("-")
rename poids_menage pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s1cq01 s1cq02) , punct("-")	
rename s1cq03 crop_code

gen month = s1cq11b
replace month=. if month==99
gen year = 2014
format month %tm
format year %ty

gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(hhid crop_code plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s3aq03b crop_code
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")

gen month = s3aq07b
replace month=. if month==99
recode s3aq07b (1/3 = 2015) ( 4/ 12 = 2014) (99=.), gen(year) label(year)

gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
drop month year

collapse (max) harvest_end_month , by(hhid crop_code plot_id)
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace


// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear
egen hhid = concat(grappe menage ), punct("-")

gen month = s00q22m
format month %tm 
gen year = s00q22y
format year %ty 

gen harvest_interview_month = ym( year, month)
format harvest_interview_month  %tmCCYYMon

keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear
egen hhid = concat(grappe menage ), punct("-")
gen month = s00q22m
format month %tm 
gen year = s00q22y
format year %ty 
gen planting_interview_month = ym( year, month)
format planting_interview_month %tmCCYYMon
keep hhid planting_interview_month
duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s3bq01==.
drop if s3bq03==2
drop if s3bq10b==9
egen hhid = concat(grappe menage ), punct("-")

sort hhid (s3bq01)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str

gen harvest_kg_per = s3bq09 * s3bq10b if s3bq09!=(99)
rename s3bq01 s3aq03b
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")

merge m:1 grappe menage s3aq03b using `perennial', 
rename s3aq03b crop_code
replace plot_id = plot_id2 if _merge==2 

gen CF = s3aq08c/ s3aq08a
gen conversion = s3aq08c
gen unit = s3aq08b
bys grappe unit (CF) : replace conversion = CF if CF[1]==CF[_N] 
replace conversion = 1 if unit==1

gen harvest_kg= s3aq08a * conversion
replace harvest_kg =. if s3aq08a==9999
replace harvest_kg =harvest_kg_per if _merge==2

gen d = conversion/s3aq08a 
replace harvest_kg = s3aq08a if s3aq08b==1 // kg
replace harvest_kg = s3aq08a * 100 if s3aq08b==2 & s3aq08c<100
replace harvest_kg = s3aq08c if s3aq08b==2 & inlist(d, 100, 250, 300, 450)
replace harvest_kg = s3aq08c if s3aq08b==3 & inlist(d, 300, 250, 200, 100)
replace harvest_kg = s3aq08a * 100 if s3aq08b==2 & s3aq08c<35
replace harvest_kg = s3aq08c if s3aq08c>120 & s3aq08b==4 
replace harvest_kg = 0 if s3aq08a==0 | s3aq10==10
replace harvest_kg = harvest_kg / (1 - s3aq06/100 ) if s3aq06<100 & s3aq05==2 

recode s3aq09 (1 = 1 "Yes") (2 = 0 "No") (9 = .), gen(crop_shock) label(crop_shock)
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
rename grappe ea_id

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id crop_code  hhid ea_id )
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")
rename s3aq03b crop_code
gen pct_area_harvested = 100 - (s3aq10 * 10) 
replace pct_area_harvested= . if s3aq10>10 
replace pct_area_harvested = 100 if s3aq09==2
keep hhid plot_id crop_code pct_area_harvested
duplicates drop
save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")
rename s3aq03b crop_code

recode s3aq09 (1 = 1 "Yes") (2 = 0 "No") (9 = .), gen(crop_shock) label(crop_shock)

recode s3aq11 (1 = 1 "Yes") (2/9 = 0 "No"), gen(drought_shock) label(drought_shock) 
replace drought_shock=0 if s3aq09==2

recode s3aq11 (2 = 1 "Yes") (1 3/9 = 0 "No"), gen(rain_shock) label(rain_shock) 
replace rain_shock=0 if s3aq09==2

recode s3aq11 (5 = 1 "Yes") (1/4 6/9 = 0 "No"), gen(pests_shock) label(pests_shock) 
replace pests_shock=0 if s3aq09==2

gen pct_lost = s3aq10 * 10 if s3aq10<=10
replace pct_lost = 0 if s3aq09==2
replace pct_lost = pct_lost / 100

collapse (max) pests_shock rain_shock drought_shock (mean) pct_lost, by(hhid plot_id crop_shock  crop_code )
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s3bq01==.
drop if s3bq03==2
drop if s3bq10b==9
egen hhid = concat(grappe menage ), punct("-")

sort hhid (s3bq01)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str

gen harvest_sold_kg_per = s3bq13a * s3bq13c if s3bq09!=(99)
replace harvest_sold_kg_per = 0 if s3bq13a==0
rename s3bq01 s3aq03b
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")

merge m:1 grappe menage s3aq03b using `perennial', 
rename s3aq03b crop_code
replace plot_id = plot_id2 if _merge==2 

gen unit = s3aq23b 
replace s3aq23c=1 if unit==1
gen harvest_sold_kg = s3aq23a * s3aq23c
replace harvest_sold_kg= . if unit== 99 | unit==10 
replace harvest_sold_kg= 0 if s3aq22==2
replace harvest_sold_kg= 0 if s3aq23a==0
replace harvest_sold_kg= harvest_sold_kg_per  if _merge==2
collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by(plot_id crop_code hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m hhid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(hhid _merge)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
replace share_kg_sold = 0 if harvest_kg==0
replace share_kg_sold = 0 if _merge==2
keep hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace

// harvest sold value
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s3bq01==.
drop if s3bq03==2
drop if s3bq10b==9
egen hhid = concat(grappe menage ), punct("-")

sort hhid (s3bq01)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str
gen harvest_sold_value_per = s3bq14 if s3bq09!=(99)
rename s3bq01 s3aq03b
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")
merge m:1 grappe menage s3aq03b using `perennial', 
rename s3aq03b crop_code
replace plot_id = plot_id2 if _merge==2 

gen harvest_sold_value = s3aq24
replace harvest_sold_value= harvest_sold_value_per  if _merge==2

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by(plot_id crop_code hhid)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s3bq01==.
drop if s3bq03==2
drop if s3bq10b==9
egen hhid = concat(grappe menage ), punct("-")

sort hhid (s3bq01)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str

rename s3bq01 s3aq03b
tempfile perennial
save `perennial', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")
merge m:1 grappe menage s3aq03b using `perennial', 
rename s3aq03b crop_code
replace plot_id = plot_id2 if _merge==2 

keep hhid  crop_code  plot_id
duplicates drop


valuation_median_crops hhid  plot_id  crop_code

main_crop_def crop_code


keep hhid plot_id  harvest_value crop_code main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace

// intercropped
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s1cq01 s1cq02) , punct("-")	
rename s1cq03 crop_code
recode s1cq05 (1 = 0 "No") (2 = 1 "Yes") (9=.), gen(intercropped) label(intercropped)
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s3aq03b crop_code
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s3bq01==.
drop if s3bq03==2
drop if s3bq10b==9
egen hhid = concat(grappe menage ), punct("-")

sort hhid (s3bq01)
gen n = _n
tostring n, gen(n_str)
gen plot_id2 = "missing_line_" + n_str

rename s3bq01 s3aq03b
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s3aq01 s3aq02) , punct("-")
merge m:1 grappe menage s3aq03b using `perennial', 
rename s3aq03b crop_code
replace plot_id = plot_id2 if _merge==2 

merge m:1 crop_code plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)


gen codesmain_crop = main_crop
gen codescrop_code = crop_code
foreach c in main_crop crop_code {
lab val `c' s3aq03b
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2

replace `c'="." if `c'=="Other"
replace `c' = strupper(`c')
replace `c' = usubinstr(`c', "`=uchar(65533)'", ":", .)
replace `c' = "TOMATOES" if `c' =="TOMATO"
replace `c' = "GROUNDNUTS" if `c' =="GROUNDNUT"

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"COWPEA", "GROUNDNUTS", "SOY", "BEANS", "PEA", "SWEET PEAS","HARICOT VERT") |  inlist(`c',"NI:B:", "PETITS POIS", "POIS SUCR:",  "SOJA", "VOANDZOU")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"POTATO", "SWEET POTATO", "CASSAVA", "YAMS", "CARROT", "BEET", "TARO") | inlist(`c', "IGNAME", "MANIOC", "PATATE DOUCE", "POMME DE TERRE", "TARO")
replace `c'2 = "RICE" if strpos(`c', "RICE") | strpos(`c', "RIZ") 
replace `c'2 = "WHEAT" if `c'=="WHEAT" | `c'=="BL:"
replace `c'2 = "MAIZE" if `c'=="MAIZE" | `c'=="MA:S"
replace `c'2 = "BARLEY" if `c'=="BARLEY" | `c'=="ORGE"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM" |  `c'=="SORGHO"
replace `c'2 = "MILLET" if `c'=="MILLET"  | `c'=="FONIO" | `c'=="MIL"
replace `c'2 = "NUTS" if `c'=="NUTS" | `c'=="ARACHIDE" 
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if codes`c'>=300 & codes`c'<=400
drop `c'
rename `c'2 `c'
}
tab crop_code, gen(contains_crop_)


//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id= concat( grappe menage s1eq01 s1eq02) , punct("-")	
egen hhid = concat(grappe menage ), punct("-")
rename s1eq03b crop_code
gen pct_area_planted = s1eq08
replace pct_area_planted = 100 if s1eq07==1
collapse (mean) pct_area_planted, by(plot_id hhid crop_code )
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace

// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat( grappe menage s1bq01 s1bq02) , punct("-")	
egen hhid = concat(grappe menage ), punct("-")

gen area_self_reported= s1bq10
replace area_self_reported= . if area_self_reported==99


gen plot_area_GPS= s1bq05a 
replace plot_area_GPS=. if plot_area_GPS==99

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

// improved 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename (s1eq03b s1eq01 s1eq02) (s1cq03 s1cq01 s1cq02)
recode s1eq04 (2/5 = 1 "Yes") (1 = 0 "No") ( 9 =.) , gen(improved) label(improved)
collapse (max) improved s1eq05b (sum) s1eq05a (count) n_s1eq05a=s1eq05a , by(s1cq03 grappe menage s1cq01 s1cq02)
replace s1eq05a = . if n_s1eq05a==0
merge m:1 s1cq03 grappe menage s1cq01 s1cq02 using "${Input}\\${country}\\${wave}\\${plot_inputs}", nogen 
replace improved = 1 if s1cq09>=2 & s1cq09<=5
replace improved = 0 if s1cq09==1
rename s1cq03 crop_code
egen plot_id= concat( grappe menage s1cq01 s1cq02) , punct("-")	
egen hhid = concat(grappe menage ), punct("-")
keep hhid plot_id crop_code improved
duplicates drop 
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename (s1eq03b s1eq01 s1eq02) (s1cq03 s1cq01 s1cq02)
recode s1eq04 (2/5 = 1 "Yes") (1 = 0 "No") ( 9 =.) , gen(improved) label(improved)
collapse (max) improved s1eq05b (sum) s1eq05a (count) n_s1eq05a=s1eq05a , by(s1cq03 grappe menage s1cq01 s1cq02)
replace s1eq05a = . if n_s1eq05a==0
merge m:1 s1cq03 grappe menage s1cq01 s1cq02 using "${Input}\\${country}\\${wave}\\${plot_inputs}", nogen 
replace improved = 1 if s1cq09>=2 & s1cq09<=5
replace improved = 0 if s1cq09==1
egen hhid = concat(grappe menage), punct("-")
egen plot_id= concat( grappe menage s1cq01 s1cq02) , punct("-")	
rename s1cq03 crop_code
rename grappe ea_id
gen seed_kg_temp = s1cq10a if s1cq10b==2
replace seed_kg_temp = . if seed_kg_temp>=9999 | seed_kg_temp>=999 & seed_kg_temp<1000
gen seed_gram= s1cq10a * 0.001 if s1cq10b==1  

egen seed_kg = rowtotal(seed_kg_temp seed_gram), missing

replace seed_kg = s1eq05a if seed_kg==.
replace seed_kg = s1eq05a * 0.001 if s1eq05b==1
replace seed_kg =. if seed_kg>=9999

collapse  (sum) seed_kg (max) improved (count) n_seed_kg = seed_kg , by(plot_id crop_code ea_id)
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg.dta", replace
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace


// seed_kg_sold (absent - we assume all seeds were bought)
use  "${Temp}\\${temppath}\\seed_kg.dta", clear

gen seeds_amount_purchased_kg = seed_kg

save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s1eq01 s1eq02) , punct("-")
rename s1eq03b crop_code
rename grappe ea_id
recode s1eq04 (2/5 = 1 "Yes") (1 = 0 "No") ( 9 =.) , gen(improved) label(improved)

gen seed_value_temp = s1eq06
replace seed_value_temp = . if seed_value_temp==0 | s1eq06>=999998 | s1eq06== 99999

collapse  (sum) seed_value_temp (max) improved (count) n_seed_value_temp = seed_value_temp , by(plot_id crop_code hhid ea_id)
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id= concat( grappe menage s1eq01 s1eq02) , punct("-")
egen hhid = concat(grappe menage ), punct("-")
rename s1eq03b crop_code
recode s1eq04 (2/5 = 1 "Yes") (1 = 0 "No") ( 9 =.) , gen(improved) label(improved)
keep hhid plot_id crop_code improved

duplicates drop

valuation_median_seeds hhid plot_id crop_code 

keep  plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s2bq01 s2bq02) , punct("-")

* 1) Family labor 
	
gen PPfamily_man_days= s2bq05a * s2bq05b
replace PPfamily_man_days= 0 if s2bq04==2

gen PPfamily_woman_days = s2bq05d * s2bq05e
replace PPfamily_woman_days= 0 if s2bq04==2

gen PPfamily_child_days = s2bq05g * s2bq05h
replace PPfamily_child_days= 0 if s2bq04==2

egen PPtotal_family_labor_days = rowtotal(PPfamily*), missing


* 2) Hired labor days

gen PPhired_man_days = s2bq07a * s2bq07b 
replace PPhired_man_days = 0 if s2bq06==2
replace PPhired_man_days = 0 if s2bq07c==0

gen PPhired_woman_days = s2bq07d * s2bq07e
replace PPhired_woman_days = 0 if s2bq06==2
replace PPhired_woman_days = 0 if s2bq07f==0

gen PPhired_child_days = s2bq07g * s2bq07h
replace PPhired_child_days = 0 if s2bq06==2
replace PPhired_child_days = 0 if s2bq07i==0

egen PPtotal_hired_labor_days= rowtotal(PPhired_man_days PPhired_woman_days PPhired_child_days), missing


gen PPhired_man_wage= s2bq07c
	
gen PPhired_woman_wage= s2bq07f
	
gen PPhired_child_wage = s2bq07i	

valuation_median_wages hhid PPhired_man_wage PPhired_woman_wage PPhired_child_wage

gen man_labor_value = man_wage * PPhired_man_days
gen woman_labor_value = woman_wage * PPhired_woman_days
gen child_labor_value = child_wage * PPhired_child_days
egen PPhired_labor_value = rowtotal (*_labor_value), missing


* 3) Other (free) labor

foreach var of varlist s2bq09a s2bq09b s2bq09c s2bq09d s2bq09e s2bq09f s2bq09g s2bq09h s2bq09i {
	 replace `var' = . if `var'==99 | `var' == 999 | `var'==99999999 
}

gen PPother_man_days_temp1 = s2bq09a * s2bq09b
replace PPother_man_days_temp1 = 0 if s2bq08==2 
gen PPother_man_days_temp2 = s2bq07a * s2bq07b if s2bq07c==0
egen PPother_man_days = rowtotal(PPother_man_days_temp*), missing

gen PPother_woman_days_temp1 = s2bq09d * s2bq09e
replace PPother_woman_days_temp1 = 0 if s2bq08==2 
gen PPother_woman_days_temp2 = s2bq07d * s2bq07e if s2bq07f==0
egen PPother_woman_days = rowtotal(PPother_woman_days_temp*), missing

gen PPother_child_days_temp1 = s2bq09g * s2bq09h
replace PPother_child_days_temp1 = 0 if s2bq08==2 
gen PPother_child_days_temp2 =  s2bq07g * s2bq07h if s2bq07i==0 
egen PPother_child_days = rowtotal(PPother_child_days_temp*), missing


egen PPtotal_other_labor_days= rowtotal(PPother_man_days PPother_woman_days PPother_child_days), missing

* 4) Total labor days

egen PPtotal_labor_days = rowtotal(PPtotal_hired_labor_days PPtotal_family_labor_days PPtotal_other_labor_days), missing


tempfile PPtotal_labor_days 
save `PPtotal_labor_days', replace 

// PH labor

use "${Input}\\${country}\\${wave}\\${lab_roster2}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s2fq01 s2fq02) , punct("-")	

foreach var of varlist s2fq04a s2fq04b s2fq04c s2fq04d s2fq04e s2fq04f s2fq06a s2fq06b s2fq06c s2fq06d s2fq06e s2fq06f s2fq06g s2fq06h s2fq06i s2fq08a s2fq08b s2fq08c s2fq08d s2fq08e s2fq08f s2fq08g s2fq08h s2fq08i s2fq10a s2fq10b s2fq10c s2fq10d s2fq10e s2fq10f s2fq12a s2fq12b s2fq12c s2fq12d s2fq12e s2fq12f s2fq12g s2fq12h s2fq12i {
	replace `var' = . if `var'==99 | `var' == 999 | `var'==99999999 
}

* 1) Family labor 

gen PHfamily_man_days1= s2fq04a * s2fq04b
replace PHfamily_man_days1= 0 if s2fq03==2

gen PHfamily_man_days2= s2fq10a * s2fq10b // post harvest labor is split into 2 different types of activities
replace PHfamily_man_days2= 0 if s2fq09==2

gen PHfamily_woman_days1 = s2fq04c * s2fq04d
replace PHfamily_woman_days1 = 0 if s2fq03==2

gen PHfamily_woman_days2= s2fq10c * s2fq10d
replace PHfamily_woman_days2= 0 if s2fq09==2

gen PHfamily_child_days1 = s2fq04e * s2fq04f
replace PHfamily_child_days1 = 0 if s2fq03==2

gen PHfamily_child_days2 = s2fq10e * s2fq10f
replace PHfamily_child_days2 = 0 if s2fq09==2

egen PHtotal_family_labor_days = rowtotal(PHfamily*), missing

* 2) Hired labor 

gen PHhired_man_days1 = s2fq06a * s2fq06b
replace PHhired_man_days1 = 0 if s2fq05==2

gen PHhired_man_days2 = s2fq12a * s2fq12b
replace PHhired_man_days2 = 0 if s2fq11==2

egen PHhired_man_days = rowtotal(PHhired_man_days*), missing

gen PHhired_woman_days1 = s2fq06d * s2fq06e
replace PHhired_woman_days1 = 0 if s2fq05==2

gen PHhired_woman_days2 = s2fq12d * s2fq12e
replace PHhired_woman_days2 = 0 if s2fq11==2

egen PHhired_woman_days = rowtotal(PHhired_woman_days*), missing

gen PHhired_child_days1 = s2fq06g * s2fq06h
replace PHhired_child_days1 = 0 if s2fq05==2

gen PHhired_child_days2 = s2fq12g * s2fq12h
replace PHhired_child_days2 = 0 if s2fq11==2 

egen PHhired_child_days = rowtotal(PHhired_child_days*), missing

egen PHtotal_hired_labor_days= rowtotal(PHhired_man_days PHhired_woman_days PHhired_child_days), missing

egen PHhired_man_wage= rowtotal(s2fq06c s2fq12c), missing 
	
egen PHhired_woman_wage= rowtotal(s2fq06f s2fq12f), missing
	
egen PHhired_child_wage = rowtotal(s2fq06i s2fq12i), missing

valuation_median_wages hhid PHhired_man_wage PHhired_woman_wage PHhired_child_wage
gen man_labor_value = man_wage * PHhired_man_days
gen woman_labor_value = woman_wage * PHhired_woman_days
gen child_labor_value = child_wage * PHhired_child_days
egen PHhired_labor_value = rowtotal (*_labor_value), missing

* 3) Other  labor 

gen PHother_man_days1 = s2fq08a * s2fq08b
replace PHother_man_days1 = 0 if s2fq07==2 

gen PHother_man_days2 = s2fq14a * s2fq14b
replace PHother_man_days2 = 0 if s2fq13==2

gen PHother_woman_days1 = s2fq08d * s2fq08e
replace PHhired_woman_days1 = 0 if s2fq07==2 

gen PHother_woman_days2 = s2fq14d * s2fq14e
replace PHhired_woman_days2 = 0 if s2fq13==2

gen PHother_child_days1 = s2fq08g * s2fq08h
replace PHhired_child_days1 = 0 if s2fq07==2 

gen PHother_child_days2 = s2fq14g * s2fq14h
replace PHhired_child_days2 = 0 if s2fq13==2 

egen PHtotal_other_labor_days= rowtotal(PHother*), missing

collapse (sum) PHtotal_other_labor_days PHtotal_hired_labor_days PHtotal_family_labor_days PHhired_labor_value (count) n_PHtotal_other_labor_days = PHtotal_other_labor_days n_PHtotal_hired_labor_days = PHtotal_hired_labor_days n_PHtotal_family_labor_days = PHtotal_family_labor_days n_PHhired_labor_value =PHhired_labor_value , by(plot_id)
foreach var in  PHtotal_other_labor_days PHtotal_hired_labor_days PHtotal_family_labor_days PHhired_labor_value  {
	replace `var' = . if n_`var'==0
}

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
egen hhid = concat(grappe menage ), punct("-")
egen plot_id = concat(grappe menage s2cq01 s2cq02), punct("-")
recode s2cq21 (1 =1 "Yes") (2 = 0 "No") (9=.), gen(inorganic_fertilizer) label(inorganic_fertilizer)
collapse (max) inorganic_fertilizer , by(plot_id)
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s0aq01 admin_1
rename s0aq02 admin_2
rename s0aq03 admin_3
// CF
gen CF = s3aq08c/ s3aq08a
gen conversion = s3aq08c
gen unit = s3aq08b
bys grappe unit (CF) : replace conversion = CF if CF[1]==CF[_N] // replace if all CFs are equal inside a grappe (meaning that conversions were already applied)
replace conversion= 1 if unit==1
replace conversion=. if unit==. |grappe==.

collapse (median) conversion (sd) sd_conv = conversion , by(admin_1 admin_2 admin_3 grappe unit )
tempfile Conversions 
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id = concat(grappe menage s2cq01 s2cq02), punct("-")
recode s2cq21 (1 =1 "Yes") (2 = 0 "No") (9=.), gen(inorganic_fertilizer) label(inorganic_fertilizer)

*UREA
recode s2cq25b (2 = 4 "sac") (3 4 = 2 "Charette") ( 9=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// a lot of values reported in "charettes" are missing
egen charette_median = median(conversion) if unit==2
replace conversion = charette_median if conversion==. & unit==2

gen UREA_kg = s2cq25a * conversion
replace UREA_kg= s2cq25a if unit==1
replace UREA_kg= 0 if inorganic_fertilizer==0
drop conversion unit charette_median

* DAP
recode s2cq25d (2 = 4 "sac") (3 4 = 2 "Charette") ( 9=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// a lot of values reported in "charrettes" are missing
egen charette_median = median(conversion) if unit==2
replace conversion = charette_median if conversion==. & unit==2

gen DAP_kg = s2cq25c * conversion
replace DAP_kg= s2cq25c if unit==1
replace DAP_kg= 0 if inorganic_fertilizer==0
drop conversion unit charette_median

* NPK
recode s2cq25f (2 = 4 "sac") (3 4 = 2 "Charette") ( 9=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen
gen NPK_kg = s2cq25e * conversion
replace NPK_kg= s2cq25e if unit==1

// a lot of values reported in "charrettes" are missing
egen charette_median = median(conversion) if unit==2
replace conversion = charette_median if conversion==. & unit==2

replace NPK_kg= 0 if inorganic_fertilizer==0
drop conversion unit charette_median

* Other
recode s2cq25h (2 = 4 "sac") (3 4 = 2 "Charette") ( 9=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// a lot of values reported in "charrettes" are missing
egen charette_median = median(conversion) if unit==2
replace conversion = charette_median if conversion==. & unit==2

gen other_kg = s2cq25g * conversion
replace other_kg= s2cq25g if unit==1
replace other_kg= 0 if inorganic_fertilizer==0
drop conversion unit charette_median


gen UREA_N_kg = UREA_kg*0.46
gen DAP_N_kg = DAP_kg*0.18
gen NPK_N_kg = NPK_kg*0.2
gen other_N_kg = other_kg * 0.15 // most "other" fertilizers are cereal complex
egen nitrogen_kg = rowtotal(UREA_N_kg DAP_N_kg NPK_N_kg), missing


collapse (sum) nitrogen_kg  UREA_kg DAP_kg NPK_kg other_kg (count) n_nitrogen_kg = nitrogen_kg n_NPK_kg = NPK_kg n_DAP_kg = DAP_kg n_UREA_kg = UREA_kg  n_other_kg = other_kg , by(plot_id hhid)
foreach var in nitrogen_kg NPK_kg DAP_kg UREA_kg   other_k {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 
use "${Input}\\${country}\\${wave}\\${ferts_purch}", clear
egen hhid = concat(grappe menage), punct("-")
recode s2dq09b (5 = 2 "charette") (2 = 1 "kg") (1 = 12 "gram") (3 = 13 "ton") (else= . ), gen(unit) 
merge m:1 grappe unit using `Conversions', keep(master match) nogen

gen UREA_purchased_kg = s2dq09a * conversion if s2dq01=="Engrais inorganiques - Ur"
replace UREA_purchased_kg = s2dq09a if unit==1 &  s2dq01=="Engrais inorganiques - Ur"
replace UREA_purchased_kg = s2dq09a *0.001 if unit==12 &  s2dq01=="Engrais inorganiques - Ur"
replace UREA_purchased_kg = s2dq09a * 1000 if unit==13 &  s2dq01=="Engrais inorganiques - Ur"

gen DAP_purchased_kg = s2dq09a * conversion if s2dq01=="Engrais inorganiques - DA"
replace DAP_purchased_kg = s2dq09a if unit==1 &  s2dq01=="Engrais inorganiques - DA"
replace DAP_purchased_kg = s2dq09a *0.001 if unit==12 &  s2dq01=="Engrais inorganiques - DA"
replace DAP_purchased_kg = s2dq09a * 1000 if unit==13 &  s2dq01=="Engrais inorganiques - DA"

gen NPK_purchased_kg = s2dq09a * conversion if s2dq01=="Engrais inorganiques - NP"
replace NPK_purchased_kg = s2dq09a if unit==1 &  s2dq01=="Engrais inorganiques - NP"
replace NPK_purchased_kg = s2dq09a *0.001 if unit==12 &  s2dq01=="Engrais inorganiques - NP"
replace NPK_purchased_kg = s2dq09a * 1000 if unit==13 &  s2dq01=="Engrais inorganiques - NP"

gen comp_purchased_kg = s2dq09a * conversion if s2dq01=="Engrais inorganiques - Co"
replace comp_purchased_kg = s2dq09a if unit==1 &  s2dq01=="Engrais inorganiques - Co"
replace comp_purchased_kg = s2dq09a *0.001 if unit==12 &  s2dq01=="Engrais inorganiques - Co"
replace comp_purchased_kg = s2dq09a * 1000 if unit==13 &  s2dq01=="Engrais inorganiques - Co"

gen UREA_purchased_value = s2dq09c if UREA_purchased_kg!=.
gen DAP_purchased_value = s2dq09c if DAP_purchased_kg!=.
gen NPK_purchased_value = s2dq09c if NPK_purchased_kg!=.
gen comp_purchased_value = s2dq09c if comp_purchased_kg!=.

collapse (max) UREA_purchased_kg DAP_purchased_kg NPK_purchased_kg comp_purchased_kg UREA_purchased_value DAP_purchased_value NPK_purchased_value comp_purchased_value , by(hhid)

valuation_median_fert_price hhid UREA

valuation_median_fert_price hhid DAP

valuation_median_fert_price hhid NPK

valuation_median_fert_price hhid comp

collapse (sum) UREA_value DAP_value NPK_value comp_value, by(hhid) 
merge 1:m hhid using "${Temp}\\${temppath}\\nitrogen_kg.dta", nogen

rename comp_value other_value
foreach n in NPK UREA DAP other {
		gen value_`n' = `n'_value * `n'_kg
	}
	
	egen inorganic_fertilizer_value = rowtotal(value_*), missing

collapse (sum) inorganic_fertilizer_value (count) n_inorganic_fertilizer_value = inorganic_fertilizer_value , by(plot_id)  
replace inorganic_fertilizer_value =. if n_inorganic_fertilizer_value==0
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id = concat(grappe menage s2cq01 s2cq02), punct("-")
gen organic_fertilizer = 1 if s2cq09==1 | s2cq04 ==1 | s2cq15==1
replace organic_fertilizer= 0 if s2cq09==2 & s2cq04==2 & s2cq15==2
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id = concat(grappe menage s2cq01 s2cq02), punct("-")
recode s2cq26 (2 = 0 "No") (9=.), gen(used_pesticides) label(used_pesticides)
replace used_pesticides = 0 if s2cq29a==0 
replace used_pesticides = 1 if s2cq29a>0 & !mi(s2cq29a)
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id = concat(grappe menage s1bq01 s1bq02), punct("-")
recode s1bq17 ( 1 2  = 1 "Yes") (3/7 = 0 "No") (9=.) , gen(plot_owned) label(plot_owned) 
recode s1bq17 (1 = 1 "Yes") (2/7 = 0 "No") (9=.), gen(plot_certificate) label(plot_certificate)
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace


// irrigated
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s1bq01 s1bq02) , punct("-")	
recode s1bq36 (5 = 1 "Yes") (1/4 6 = 0 "No") (9 = .), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace	


// erosion protection
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id= concat( grappe menage s1bq01 s1bq02) , punct("-")	
recode s1bq28 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace	

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
egen hhid = concat(grappe menage ), punct("-")
drop if as05q00!=101 // we drop non tractors
duplicates report hhid // none 
recode as05q02 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(tractor) label(tractor)
replace tractor= 1 if as05q10==1
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace	

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat( grappe menage s1bq01 s1bq02) , punct("-")	
recode s1bq32 (1 = 1) (9 . = . ) (* = 0), gen(fallow_plot)
bys grappe menage: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 grappe menage using "${Input}\\${country}\\${wave}\\${cover}", keepusing(grappe menage)
egen hhid = concat(grappe menage ), punct("-")
replace nb_fallow_plots= 0 if _merge ==2		
keep hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace	

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat( grappe menage s1bq01 s1bq02) , punct("-")	
recode s1bq32 (1 = 1) (9 . = . ) (* = 0), gen(fallow_plot)
bys grappe menage: egen nb_plots = count(fallow_plot) 	
merge m:1 grappe menage using "${Input}\\${country}\\${wave}\\${cover}", keepusing(grappe menage)
egen hhid = concat(grappe menage ), punct("-")
replace nb_plots= 0 if _merge ==2	
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace	

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
recode s02q03 ( 1 =1 "Yes") (2 = 0 "No"), gen(formal_educ) label(hh_formal_education)
recode s02q23 (  0/5 = 0 "No" ) (99= .) (6/16 = 1 "Yes"), gen(education) label(primary_education)
replace education= 0 if s02q03==2 // no studies
replace education = 1 if inrange(s02q12, 6, 16) // current students

bys hhid: egen hh_primary_education= max(education) 
bys hhid: egen hh_formal_education = max(formal_educ)

collapse (max) hh_formal_education hh_primary_education, by(hhid)	
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace	


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
egen hhid = concat(grappe menage ), punct("-")
recode s07q26 (1 2 3 6 = 1 "Yes") (4 5 7 = 0 "No") (9 =.),  gen(hh_electricity_access) label(hh_electricity_access)
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace	

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
rename s01q04a age 
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort hhid: egen dep=total(dep_temp)
bysort hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep if nondep==0
collapse (max) hh_dependency_ratio, by(hhid)
keep hhid hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace	

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
merge m:1 grappe menage  using "${Input}\\${country}\\${wave}\\${cover}"
egen hhid = concat(grappe menage ), punct("-")
recode s4aq03 (1 = 1 "Yes") (2 = 0 "No") (9 =.), gen(livestock) label(livestock)
replace livestock = 0 if _merge ==2 
collapse (max) livestock, by(hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace	

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
egen hhid = concat(grappe menage ), punct("-")
xtile cons_quint= pcexp, n(5)
keep hhid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace	

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
egen hhid = concat(grappe menage ), punct("-")
rename pcexp totcons
keep hhid totcons 
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace	

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
egen plot_id = concat(grappe menage s1bq01 s1bq02), punct("-")
rename s1bq09 manager_id
replace manager_id=. if manager_id==99
sort  hhid (manager_id)
collapse (first) manager_id hhid , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
gen manager_id = s01q00  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode  s01q01 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename s01q04a age_manager
replace age_manager=. if age_manager==98 | age_manager==99
recode s01q09 ( 2 3 = 1 "Yes") (1 4/6  = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
gen manager_id = s01q00  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode s02q23 (  0/5 = 0 "No" ) (6/16 = 1 "Yes") (99= .) , gen(primary_education_manager) label(primary_education_manager)
recode s02q03 (1 =1 "Yes") (2 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
replace primary_education_manager= 0 if s02q03==2 // no studies
replace primary_education_manager = 1 if inrange(s02q12, 6, 16)
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace	

// respondent chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe menage), punct("-")
egen plot_id = concat(grappe menage s1bq01 s1bq02), punct("-")
gen respondent_id = s1bq03 
replace respondent_id= . if respondent_id==99
keep  respondent  hhid plot_id
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename s01q00 respondent_id // this is the HH member id 
egen hhid = concat(grappe menage), punct("-")
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode  s01q01 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename s01q04a age_respondent
replace age_respondent=. if age_respondent==98 | age_respondent==99
recode s01q09 ( 2 3 = 1 "Yes") (1 4/6  = 0 "No"), gen(married_respondent) 
keep plot_id female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\Respondent_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage ), punct("-")
gen respondent_id = s01q00  // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode s02q23 (  0/5 = 0 "No" ) (6/16 = 1 "Yes") (99= .) , gen(primary_education_respondent) label(primary_education_respondent)
recode s02q03 (1 =1 "Yes") (2 = 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
replace primary_education_respondent= 0 if s02q03==2 // no studies
replace primary_education_respondent = 1 if inrange(s02q12, 6, 16)
keep plot_id primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace	

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
egen hhid = concat(grappe menage), punct("-")
recode s11q02 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_shock) label(hh_shock)
collapse (max) hh_shock, by(hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe menage ), punct("-")
rename s00q29 hh_size
keep hhid hh_size
duplicates drop
isid hhid
save "${Temp}\\${temppath}\\size.dta", replace	

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
egen hhid = concat(grappe menage), punct("-")
rename as05q00 item_cd
drop if inlist(item_cd, 111, 112, 109, 128 )
recode as05q02 (1 = 1) (2 = 0) , gen(hh_owns_) 
keep hhid item_cd hh_owns_
reshape wide hh_owns_ , i(hhid) j(item_cd)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace


// hh assets
use "${Input}\\${country}\\${wave}\\${assets}", clear
egen hhid = concat(grappe menage), punct("-")
recode s08q02 ( 2 = 0 ) (1 = 1), gen (hh_owns) // missing items are owned
keep hh_owns hhid s08q01
reshape wide hh_owns , i(hhid) j(s08q01)
factor hh_owns*, pcf 
predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${housing}", clear
egen hhid = concat(grappe menage), punct("-")

recode s06q11 ( 2 = 0 "No") (1= 1 "Yes") (9=.), gen(nonfarm_enterprise) label(nonfarm_enterprise)
keep hhid nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace


// latitude
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id
rename (lat_dd_mod lon_dd_mod) (lat_modified lon_modified)
keep ea_id lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace


// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id

rename ssa_aez09 agro_ecological_zone
keep ea_id agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id

keep ea_id dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id
keep ea_id dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace

// distance to nearest market (none)


// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id
rename afmnslp_pct plot_slope
keep ea_id plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id
rename srtm_1k elevation 
keep ea_id elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
rename grappe ea_id
keep ea_id twi
duplicates drop
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename grappe ea_id
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

keep ea_id  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace


// popdensity
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
rename grappe ea_id
keep ea_id popdensity
tostring popdensity , replace
duplicates drop
save "${Temp}\\${temppath}\\popdensity.dta", replace

// indiv chars
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage), punct("-")
egen ID = concat (hhid s01q00 ), punct("-")


recode  s01q01 (2=1 "Yes") (1=0 "No"), gen(female) 
rename s01q04a age
replace age=. if age==98 | age==99
recode s01q09 ( 2 3 = 1 "Yes") (1 4/6  = 0 "No"), gen(married)
replace married = 0 if married==.

decode  s01q02, gen(relationship_head)
replace  relationship_head = ustrregexra(relationship_head,`"[^a-zA-Z0-9]"',"")
replace relationship_head = "Head" if relationship_head=="Chefdemnage"
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head=="Beauprebellemre"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head=="Beaufrrebellesoeur"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head=="Beaufilsbellefille"
replace relationship_head = "Grandparent" if relationship_head=="GrandpreGrandmre"
replace relationship_head = "Servant" if relationship_head=="Domestiqueouparentdudomestique"
replace relationship_head = "Spouse" if relationship_head=="ConjointeduCM"
replace relationship_head = "Son/Daughter" if relationship_head=="FilsFille"
replace relationship_head = "Father/Mother" if relationship_head=="PreMre"
replace relationship_head = "Sister/Brother" if relationship_head=="Frresoeur"
replace relationship_head = "Other Relative" if relationship_head=="Cousincousine"
replace relationship_head = "Other Relative" if relationship_head=="AutresparentsduCMouduconjointe"
replace relationship_head = "Non Relative" if relationship_head=="PersonnenonapparenteauCMoulaconjointe"
replace relationship_head = "Niece/Nephew" if relationship_head=="Neveunice"
replace relationship_head = "Grandchild" if relationship_head=="PetitfilsPetitefille"




keep hhid ID married female age relationship_head s01q04b
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting (absent)


// labor 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage), punct("-")
egen ID = concat (hhid s01q00 ), punct("-")

recode s04q01 (2 = 0) (9 .=.) (else = 1) , gen(farm_work)
recode s04q02 (2 = 0) (9 .=.) (else = 1) , gen( SOB_work)
recode s04q03 (2 = 0) (. 9 =.) (else = 1) , gen( wage_work)


// nb of working age members
gen working_age =  s01q04a>=6
bys hhid: egen nb_members_working_age = total(working_age)


// industry:
gen 	ind_ag = s04q22 >= 11 & s04q22 <=40  // Agriculture 
gen 	ind_fish = s04q22 >= 51 & s04q22<=52	// fishing
gen 	ind_mining = s04q22 == 71 | s04q22==72	// mining
gen 	ind_manuf = s04q22 >= 81 & s04q22 <= 292	// manuf
gen 	ind_const = s04q22 == 301 | s04q22==302	// construc
gen 	ind_serv = s04q22 >= 310 & s04q22<= 430	// services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if s04q23==4 // remove self employment
}


gen hour_job1 = s04q25
	replace hour_job1 = 0 if s04q05==2 & s04q06==2 //answered "no" to filter questions = unemployed
	replace hour_job1 = 0 if s04q19==2 
	gen hour_job2 = s04q48
	replace hour_job2 = 0 if s04q05==2 & s04q06==2 //answered "no" to filter questions = unemployed
	replace hour_job2 = 0 if s04q19==2 

	gen day_job1 = s04q26
	replace day_job1 = 0 if s04q05==2 & s04q06==2 //answered "no" to filter questions = unemployed
	replace day_job1 = 0 if s04q19==2 
	gen day_job2 = s04q49
	replace day_job2 = 0 if s04q05==2 & s04q06==2 //answered "no" to filter questions = unemployed
	replace day_job2 = 0 if s04q19==2 
	
	gen month_job1 = s04q24
	replace month_job1 = 0 if s04q05==2 & s04q06==2 //answered "no" to filter questions = unemployed
	replace month_job1 = 0 if s04q19==2 		
	gen month_job2 = s04q47
	replace month_job2 = 0 if s04q05==2 & s04q06==2 //answered "no" to filter questions = unemployed
	replace month_job2 = 0 if s04q19==2 		
		gen av_hours1 = (month_job1 * hour_job1 * day_job1) / 52 // (week average of hours)
gen av_hours2 = (month_job2 * hour_job2 * day_job2) / 52 // (week average of hours)
replace av_hours2 = 0 if s04q42==2 
	
	
recode s04q21 (11 12 = 1) (. 99 =.) (else = 0) , gen(farm_job1)
recode s04q44 (11 12 = 1) (. 99 =.) (else = 0) , gen(farm_job2)
replace farm_job1 = 0 if farm_job1==1 & inlist(s04q23, 1, 2, 3, 7)
replace farm_job2 = 0 if farm_job2==1 & inlist(s04q46, 1, 2, 3, 7)
recode s04q21 ( 62 = 1) (. 99 =.) (else = 0) , gen(SB_job1)
recode s04q44 ( 62 = 1) (. 99 =.) (else = 0) , gen(SB_job2)
replace SB_job1 = 0 if SB_job1==1 & inlist(s04q23, 1, 2, 3, 7)
replace SB_job2 = 0 if SB_job2==1 & inlist(s04q46, 1, 2, 3, 7)
recode s04q21 ( 21 22 23 24 25 41 42 43 51 52 61 63 71 72 81 = 1) (. 99 =.) (else = 0) , gen(wage_job1)
recode s04q44 ( 21 22 23 24 25 41 42 43 51 52 61 63 71 72 81 = 1) (. 99 =.) (else = 0) , gen(wage_job2)
replace wage_job1 = 1 if wage_job1==0 & inlist(s04q23, 1, 2, 3, 7)
replace wage_job2 = 1 if wage_job2==0 & inlist(s04q46, 1, 2, 3, 7)

rename SOB_work SB_work
foreach act in farm SB wage {
	gen `act'_hrs1 = av_hours1 if `act'_job1 == 1
	replace `act'_hrs1 = 0 if `act'_job1 == 0
	replace `act'_hrs1 = 0 if `act'_work == 0
	gen `act'_hrs2 = av_hours2 if `act'_job2 == 1
	replace `act'_hrs2 = 0 if `act'_job2 == 0
	replace `act'_hrs2 = 0 if `act'_work == 0
	egen `act'_hrs = rowtotal(`act'_hrs1 `act'_hrs2), missing
}

rename  SB_work SOB_work
foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}



keep ID hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace


// education
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe menage), punct("-")
egen ID = concat (hhid s01q00 ), punct("-")
recode s02q03 ( 1 =1 "Yes") (2 = 0 "No"), gen(formal_education) label(formal_education)
recode s02q23 (  0/5 = 0 "No" ) (99= .) (6/16 = 1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education= 0 if s02q03==2 // no studies
replace primary_education = 1 if inrange(s02q12, 6, 16) // current students
foreach var in formal_education primary_education {
replace `var' = 0  if s01q04a<6
}
keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace


// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if s13q02 ==1 // keep if consumed
rename s13q01 food_id

gen A = food_id>=501 & food_id<=512 | food_id>=521 & food_id<=522
gen B = food_id>=513 & food_id<=520
gen C = food_id>=526 & food_id<=545 | food_id>=548 & food_id<=550
gen D = food_id>=555 & food_id<=569
gen E = food_id>=570 & food_id<=580
gen F = food_id>=593
gen G = food_id>=581 & food_id<=585
gen H = food_id>=546 & food_id<=547 
gen I = food_id>=594 & food_id<=600
gen J = food_id>=586 & food_id<=592
gen K = food_id>=523 & food_id<=525 | food_id>=601 & food_id<=604
gen L = food_id>=552 & food_id<=554 | food_id>=605 & food_id<=611

collapse (max) A B C D E F G H I J K L, by(grappe menage)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m grappe menage  using "${Input}\\${country}\\${wave}\\${HDDS}", 
egen hhid = concat(grappe menage), punct("-")

collapse (max) HDDS, by(hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace
