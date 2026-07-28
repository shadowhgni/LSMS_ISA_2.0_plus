/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for MLI2									          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Mali
global wave  EACI 17
global cover  eaci17_s00p1.dta
global cover2  eaci17_s00p2.dta
global indiv_roster  eaci17_s01p1.dta
global indiv_roster2  eaci17_s02p1.dta
global lab_roster  eaci17_s11ep1.dta
global lab_roster2  eaci17_s7ep2.dta
global shocks eaci17_s05p2.dta
global housing  eaci17_s06p1.dta
global assets eaci17_s07p1.dta
global plot_roster  eaci17_s11bp1.dta
global plot_inputs eaci17_s11cp1.dta
global seeds eaci17_s11cp1.dta
global ferts eaci17_s07dp2.dta
global ferts_purch eaci17_s07bp2.dta
global nfe1 eaci17_s05ap1.dta
global nfe2 eaci17_s05bp1.dta
global items eaci17_s9p2.dta
global cover_pc_ph  sect_cover_ph_w4.dta
global harvest_rwdta  eaci17_s7fp2.dta
global harvest_sold  eaci17_s7gp2.dta
global perennial  eaci17_s11fp1.dta
global geovars_hh eaci_geovariables_2017.dta
global livestock eaci17_s8ap2.dta
global weights EACI17_ECHANTILLON.dta
global indiv_labor eaci17_s04p1.dta

global temppath MLI\EACI17


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fq03==2
rename ménage exploitation
duplicates report grappe exploitation s11fq01  s11fq05c s11fq05d
rename s11fq01 crop_code
decode crop_code, generate(crop_name2) 
egen plot_id= concat(grappe exploitation s11fq05c s11fq05d), punct("-")
egen parcel_id= concat(grappe exploitation s11fq05c ), punct("-")

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename s7fq03  crop_code
decode crop_code, generate(crop_name) 

egen plot_id= concat(grappe exploitation s7fq01 s7fq02), punct("-")
egen parcel_id= concat(grappe exploitation s7fq01), punct("-")

merge m:1 grappe exploitation plot_id crop_code using `perennial', 

egen hhid = concat(grappe exploitation), punct("-")
replace crop_name = crop_name2 if _merge==2 

keep hhid plot_id crop_name crop_code   parcel_id 

duplicates drop

duplicates report plot_id crop_code crop_name

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge m:1 grappe exploitation using "${Input}\\${country}\\${wave}\\${cover2}",  keep(master match) nogen
egen hhid = concat(grappe exploitation), punct("-")

keep hhid 
duplicates report hhid 

save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen ID = concat (hhid codeid ), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear 
egen hhid = concat(grappe exploitation), punct("-")

rename grappe ea_id
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${weights}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename strate strataid

keep hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace


// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename s0q01 admin_1 
keep hhid admin_1
decode admin_1, gen(admin_1_name)

duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace


// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen admin_2 = group(s0q01 s0q02)
keep hhid admin_2
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen admin_3 = group(s0q01 s0q02 s0q03)
keep hhid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe exploitation), punct("-")
recode s0q04 (1 3 = 1 "Yes") (2 =0 "No"), gen(urban) label(urban)
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${weights}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename poids_leger pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s11cq03 crop_code
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11cq01 s11cq02) , punct("-")	

gen month = s11cq14b
gen year = 2017
format month %tm
format year %ty

gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(hhid crop_code plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7fq01 s7fq02) , punct("-")
rename s7fq03  crop_code

gen month = s7fq12b
format month %tm
gen year =  s7fq12c
format year %ty
replace year = 2017 if month>=5 & !mi(month) & mi(year) 
replace year = 2018 if month<5  & mi(year)

gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
drop month year

collapse (max) harvest_end_month , by(hhid crop_code plot_id)
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace


// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear
egen hhid = concat(grappe exploitation), punct("-")

gen month = s0q21b
format month %tm 
gen year = s0q21c
format year %ty 

gen harvest_interview_month = ym( year, month)
format harvest_interview_month  %tmCCYYMon

keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear
egen hhid = concat(grappe exploitation), punct("-")
gen month = s0q21b
format month %tm 
gen year = s0q21c
format year %ty 
gen planting_interview_month = ym( year, month)
format planting_interview_month %tmCCYYMon
keep hhid planting_interview_month
duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fq03==2
rename ménage exploitation
duplicates report grappe exploitation s11fq01  s11fq05c s11fq05d
rename s11fq01 crop_code
decode crop_code, generate(crop_name2) 
egen plot_id= concat(grappe exploitation s11fq05c s11fq05d), punct("-")
egen parcel_id= concat(grappe exploitation s11fq05c ), punct("-")
gen harvest_kg_per = s11fq10 * s11fq11c

tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7fq01 s7fq02) , punct("-")
rename s7fq03  crop_code
merge m:1 grappe exploitation plot_id crop_code using `perennial', 

gen d = s7fq13d/s7fq13a // this is equal to the conversion rate if that was already multiplied to the rself reported value
gen harvest_kg_temp= s7fq13a * s7fq13d
replace harvest_kg_temp = s7fq13a if s7fq13c==1 // kg
replace harvest_kg_temp = s7fq13a * 100 if s7fq13c==2 & s7fq13d<100
replace harvest_kg_temp = s7fq13d if s7fq13c==2 & inlist(d, 100, 250, 300, 450)
replace harvest_kg_temp = s7fq13d if s7fq13c==3 & inlist(d, 300, 250, 200, 100)
replace harvest_kg_temp = s7fq13a * 100 if s7fq13c==2 & s7fq13d<35
replace harvest_kg_temp  = s7fq13d if s7fq13d>120 & s7fq13c==4
replace harvest_kg_temp = 0 if s7fq13a==0 | s7fq08==100 

gen unfinished_harvest= harvest_kg_temp / (1 - s7fq11/100 ) if s7fq11<100 &  s7fq10==2 
egen harvest_kg = rowtotal(harvest_kg_temp unfinished_harvest), missing
replace harvest_kg = harvest_kg_per if _merge==2
recode s7fq06 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock) label(crop_shock)
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
rename grappe ea_id

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id crop_code  hhid ea_id )
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7fq01 s7fq02) , punct("-")
rename s7fq03  crop_code
gen pct_area_harvested = 100 - s7fq08
replace pct_area_harvested = 100 if s7fq06==2
keep hhid plot_id crop_code pct_area_harvested
duplicates drop
save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7fq01 s7fq02) , punct("-")
rename s7fq03  crop_code

recode s7fq06 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock) label(crop_shock)

recode s7fq07 (1 = 1 "Yes") (2/9 = 0 "No"), gen(drought_shock) label(drought_shock) 
replace drought_shock=0 if s7fq06==2

recode s7fq07 (2 = 1 "Yes") (1 3/9 = 0 "No"), gen(rain_shock) label(rain_shock) 
replace rain_shock=0 if s7fq06==2

recode s7fq07 (4 5 = 1 "Yes") (1/3 6/9 = 0 "No"), gen(pests_shock) label(pests_shock) 
replace pests_shock=0 if s7fq06==2

gen pct_lost = s7fq08
replace pct_lost = 0 if s7fq06==2

keep hhid plot_id crop_shock pests_shock rain_shock drought_shock  crop_code pct_lost
duplicates drop
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fq03==2
rename ménage exploitation
gen harvest_sold_kg_per = s11fq10  * s11fq14c
replace harvest_sold_kg_per = 0  if s11fq14a== 0
replace harvest_sold_kg_per = 0  if s11fq10== 0
duplicates report grappe exploitation s11fq01  harvest_sold_kg_per
rename s11fq01 crop_code
egen plot_id= concat(grappe exploitation s11fq05c s11fq05d), punct("-")
egen parcel_id= concat(grappe exploitation s11fq05c ), punct("-")
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_sold}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename s7gq01 crop_code
merge m:1 grappe exploitation  crop_code using `perennial', 

gen harvest_sold_kg = s7gq21a * s7gq21d
replace harvest_sold_kg = 0 if s7gq20==2

replace harvest_sold_kg = harvest_sold_kg_per if _merge==2
collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( crop_code hhid)
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
drop if s11fq03==2
rename ménage exploitation
gen harvest_sold_value_per = s11fq10  * s11fq15
 
duplicates report grappe exploitation s11fq01  harvest_sold_value_per
rename s11fq01 crop_code
egen plot_id= concat(grappe exploitation s11fq05c s11fq05d), punct("-")
egen parcel_id= concat(grappe exploitation s11fq05c ), punct("-")
tempfile perennial
save `perennial', replace


use "${Input}\\${country}\\${wave}\\${harvest_sold}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename s7gq01 crop_code

merge m:1 grappe exploitation  crop_code using `perennial', 
gen harvest_sold_value = s7gq22
replace harvest_sold_value = 0 if s7gq20==2 & _merge==1
replace harvest_sold_value = harvest_sold_value_per if _merge==2
collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( crop_code hhid)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fq03==2
rename ménage exploitation
duplicates report grappe exploitation s11fq01 
rename s11fq01 crop_code
egen plot_id= concat(grappe exploitation s11fq05c s11fq05d), punct("-")
egen parcel_id= concat(grappe exploitation s11fq05c ), punct("-")
tempfile perennial
save `perennial', replace
use "${Input}\\${country}\\${wave}\\${harvest_sold}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename s7gq01 crop_code
merge m:1 grappe exploitation  crop_code using `perennial', 

keep hhid  crop_code  

duplicates drop


valuation_median_crops hhid hhid crop_code

main_crop_def crop_code


keep hhid plot_id  harvest_value crop_code main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s11cq03 crop_code
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11cq01 s11cq02) , punct("-")	
recode s11cq06 (1 = 0 "No") (2 = 1 "Yes") , gen(intercropped) label(intercropped)
collapse (max) intercropped, by(plot_id)

save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7fq01 s7fq02) , punct("-")
rename s7fq03  crop_code
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fq03==2
rename ménage exploitation
duplicates report grappe exploitation s11fq01 
rename s11fq01 crop_code
egen plot_id= concat(grappe exploitation s11fq05c s11fq05d), punct("-")
egen parcel_id= concat(grappe exploitation s11fq05c ), punct("-")
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7fq01 s7fq02) , punct("-")
rename s7fq03  crop_code
merge m:1 grappe exploitation plot_id crop_code using `perennial', 

merge m:1 crop_code plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

lab def main_crop 101 "Millet" 102 "Sorghum" 103 "Rice" 104 "Maize" 105 "Wheat" 106 "Barley" 107 "Fonio" 110 "Sweet Potato" 111 "Yams" 112 "Cassava" 113 "Taro" 120 "Cowpea" 121 "Nuts" 122 "Groundnut" 123 "Soy" 124 "Sesame" 130 "Sweet peas" 131 "Ginger" 201 "Tomato" 202 "Onion" 204 "Garlic" 205 "Chilli pepper" 207 "Carrot" 208 "Okra" 209 "Lettuce" 210 "Potato" 212 "Cucumber" 213 "Watermelon" 214 "Melon" 215 "Squash" 216 "Sorrel" 217 "Sorrel" 218 "Cabbage" 220 "Beet" 222 "Pepper" 401 "Cotton" 403 "Dah" 602 "Cowpea" 703 "Calabash" 906 "Jaxatu" 912 "Other"
drop if main_crop==999 | crop_code ==999


gen codesmain_crop = main_crop
gen codescrop_code = crop_code
foreach c in main_crop crop_code {
lab val `c' main_crop
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


foreach n in 10 9 8 7 6 5 4 3 2 1  {
	local i = `n' + 1
	rename contains_crop_`n' contains_crop_`i'
}

gen contains_crop_1 =0

//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id= concat(grappe exploitation s11cq01 s11cq02) , punct("-")	
egen hhid = concat(grappe exploitation), punct("-")
rename s11cq03 crop_code
gen pct_area_planted = s11cq07
keep plot_id hhid crop_code  pct_area_planted
duplicates drop
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace

// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat( grappe exploitation s11bq01 s11bq02) , punct("-")
egen hhid = concat(grappe exploitation), punct("-")

gen area_self_reported= s11bq11a
replace area_self_reported= area_self_reported * 0.0001 if s11bq11b==2

gen plot_area_GPS= s11bq07 

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

keep hhid plot_id   plot_area_GPS  farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s11cq03 crop_code
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11cq01 s11cq02) , punct("-")	
recode s11cq10 (2/5 = 1 "Yes") (1 = 0 "No") , gen(improved) label(improved)
keep hhid plot_id crop_code improved
duplicates drop 
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s11cq03 crop_code
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11cq01 s11cq02) , punct("-")	
gen seed_kg = s11cq11a
replace seed_kg = seed_kg *0.001 if s11cq11b==1
recode s11cq10 (2/5 = 1 "Yes") (1 = 0 "No") , gen(improved) label(improved)
rename grappe ea_id

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
rename s11cq03 crop_code
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11cq01 s11cq02) , punct("-")	
recode s11cq10 (2/5 = 1 "Yes") (1 = 0 "No") , gen(improved) label(improved)
rename grappe ea_id

gen seed_value_temp = s11cq13

collapse  (sum) seed_value_temp (max) improved (count) n_seed_value_temp = seed_value_temp , by(plot_id crop_code hhid ea_id)
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
rename s11cq03 crop_code
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11cq01 s11cq02) , punct("-")	
recode s11cq10 (2/5 = 1 "Yes") (1 = 0 "No") , gen(improved) label(improved)
keep hhid plot_id crop_code improved

duplicates drop

valuation_median_seeds hhid plot_id crop_code 

keep  plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s11eq01 s11eq02) , punct("-")

* 1) Family labor 
	
gen PPfamily_man_days= s11eq05a1 * s11eq05a2
replace PPfamily_man_days= 0 if s11eq04==2

gen PPfamily_woman_days = s11eq05b1 * s11eq05b2
replace PPfamily_woman_days= 0 if s11eq04==2

gen PPfamily_child_days = s11eq05c1 * s11eq05c2
replace PPfamily_child_days= 0 if s11eq04==2

egen PPtotal_family_labor_days = rowtotal(PPfamily*), missing


* 2) Hired labor days

gen PPhired_man_days = s11eq07a1 * s11eq07a2   
replace PPhired_man_days = 0 if s11eq06==2

gen PPhired_woman_days = s11eq07b1 * s11eq07b2
replace PPhired_woman_days = 0 if s11eq06==2

gen PPhired_child_days = s11eq07c1 * s11eq07c2
replace PPhired_child_days = 0 if s11eq06==2

egen PPtotal_hired_labor_days= rowtotal(PPhired_man_days PPhired_woman_days PPhired_child_days), missing


gen PPhired_man_wage= s11eq07a3
	
gen PPhired_woman_wage= s11eq07b3
	
gen PPhired_child_wage = s11eq07c3	

valuation_median_wages hhid PPhired_man_wage PPhired_woman_wage PPhired_child_wage

gen man_labor_value = man_wage * PPhired_man_days
gen woman_labor_value = woman_wage * PPhired_woman_days
gen child_labor_value = child_wage * PPhired_child_days
egen PPhired_labor_value = rowtotal (*_labor_value), missing


* 3) Other (free) labor

gen PPother_man_days_temp1 = s11eq09a1 * s11eq09a2  
replace PPother_man_days_temp1 = 0 if s11eq08==2
egen PPother_man_days= rowtotal(PPother_man_days_temp*), missing

gen PPother_woman_days_temp1 = s11eq09b1 * s11eq09b2
replace PPother_woman_days_temp1 = 0 if s11eq08==2
egen PPother_woman_days= rowtotal(PPother_woman_days_temp*), missing

gen PPother_child_days_temp1 = s11eq09c1 * s11eq09c2
replace PPother_child_days_temp1 = 0 if s11eq08==2
egen PPother_child_days= rowtotal(PPother_child_days_temp*), missing


egen PPtotal_other_labor_days= rowtotal(PPother_man_days PPother_woman_days PPother_child_days), missing

* 4) Total labor days

egen PPtotal_labor_days = rowtotal(PPtotal_hired_labor_days PPtotal_family_labor_days PPtotal_other_labor_days), missing


tempfile PPtotal_labor_days 
save `PPtotal_labor_days', replace 

// PH labor

use "${Input}\\${country}\\${wave}\\${lab_roster2}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat(grappe exploitation s7eq01 s7eq02) , punct("-")	

* 1) Family labor 

gen PHfamily_man_days1= s7eq05a1 * s7eq05a2

gen PHfamily_man_days2= s7eq11a1 * s7eq11a2

gen PHfamily_woman_days1 = s7eq05b1 * s7eq05b2

gen PHfamily_woman_days2= s7eq11b1 * s7eq11b2

gen PHfamily_child_days1 = s7eq05c1 * s7eq05c2==2

gen PHfamily_child_days2 = s7eq11c1 * s7eq11c2

egen PHtotal_family_labor_days = rowtotal(PHfamily*), missing

* 2) Hired labor 

gen PHhired_man_days_temp1 = s7eq07a1 * s7eq07a2
replace PHhired_man_days_temp1= 0 if s7eq06==2

gen PHhired_man_days_temp2 = s7eq13a1 * s7eq13a2
replace PHhired_man_days_temp2 = 0 if s7eq12==2

egen PHhired_man_days = rowtotal(PHhired_man_days_temp1 PHhired_man_days_temp2), missing

gen PHhired_woman_days_temp1 = s7eq07b1 * s7eq07b2
replace PHhired_woman_days_temp1= 0 if s7eq06==2


gen PHhired_woman_days_temp2 =s7eq13b1 * s7eq13b2
replace PHhired_woman_days_temp2 = 0 if s7eq12==2

egen PHhired_woman_days = rowtotal(PHhired_woman_days_temp1 PHhired_woman_days_temp2), missing

gen PHhired_child_days_temp1 = s7eq07c1 * s7eq07c2
replace PHhired_child_days_temp1= 0 if s7eq06==2


gen PHhired_child_days_temp2 = s7eq13c1 * s7eq13c3
replace PHhired_child_days_temp2 = 0 if s7eq12==2

egen PHhired_child_days = rowtotal(PHhired_child_days_temp1 PHhired_child_days_temp2), missing

egen PHtotal_hired_labor_days= rowtotal(PHhired_man_days PHhired_woman_days PHhired_child_days), missing

egen PHhired_man_wage= rowtotal(s7eq07a3 s7eq13a3), missing
	
egen PHhired_woman_wage= rowtotal(s7eq07b3 s7eq13b3), missing
	
egen PHhired_child_wage = rowtotal(s7eq07c3 s7eq13c3), missing

valuation_median_wages hhid PHhired_man_wage PHhired_woman_wage PHhired_child_wage
gen man_labor_value = man_wage * PHhired_man_days
gen woman_labor_value = woman_wage * PHhired_woman_days
gen child_labor_value = child_wage * PHhired_child_days
egen PHhired_labor_value = rowtotal (*_labor_value), missing

* 3) Other  labor 

gen PHother_man_days_temp1 =  s7eq09a1 * s7eq09a2
replace PHother_man_days_temp1 = 0 if s7eq08==2
gen PHother_man_days_temp2 =  s7eq15a1 * s7eq15a2
replace PHother_man_days_temp2 = 0 if s7eq14==2

egen PHother_man_days= rowtotal(PHother_man_days_temp*), missing

gen PHother_woman_days_temp1 =  s7eq09b1 * s7eq09b2
replace PHother_woman_days_temp1 = 0 if s7eq08==2

gen PHother_woman_days_temp2 =  s7eq15b1 * s7eq15b2
replace PHother_woman_days_temp2 = 0 if s7eq14==2

egen PHother_woman_days= rowtotal(PHother_woman_days_temp*), missing

gen PHother_child_days_temp1 =  s7eq09c1 * s7eq09c2
replace PHother_child_days_temp1 = 0 if s7eq08==2

gen PHother_child_days_temp2 =  s7eq15c1 * s7eq15c2
replace PHother_child_days_temp2 = 0 if s7eq14==2

egen PHother_child_days= rowtotal(PHother_child_days_temp*), missing

egen PHtotal_other_labor_days= rowtotal(PHother_man_days PHother_woman_days PHother_child_days), missing

 
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
egen hhid = concat(grappe exploitation ), punct("-")
egen plot_id = concat(grappe exploitation s7dq01 s7dq02), punct("-")
recode s7dq22 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 grappe exploitation using "${Input}\\${country}\\${wave}\\${cover}", keep(match) nogen
rename s7fq13c unit 
rename s7fq13d conversion
collapse conversion, by(unit grappe)
drop if unit==.
tempfile Conversions 
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id = concat(grappe exploitation s7dq01 s7dq02), punct("-")
recode s7dq22 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

*UREA
recode s7dq26a2 (3 = 4 "sac") (2 = 11 "Ton") ( 4=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// many "sac" values aren't converted
egen sac_median = median(conversion) if unit==4
replace conversion = sac_median if conversion==. & unit==4

gen UREA_kg = s7dq26a1 * conversion
replace UREA_kg= s7dq26a1 if unit==1
replace UREA_kg = s7dq26a1 * 1000 if unit==11 // tons
replace UREA_kg= 0 if inorganic_fertilizer==0 | s7dq26a1==0
drop conversion unit sac_median

* DAP
recode s7dq26b2 (3 = 4 "sac") (2 = 11 "Ton") ( 4=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// many "sac" values aren't converted
egen sac_median = median(conversion) if unit==4
replace conversion = sac_median if conversion==. & unit==4

gen DAP_kg = s7dq26b1 * conversion
replace DAP_kg= s7dq26b1 if unit==1
replace DAP_kg = s7dq26b1 * 1000 if unit==11 // tons

replace DAP_kg= 0 if inorganic_fertilizer==0 | s7dq26b1==0
drop conversion unit sac_median

* NPK
recode s7dq26c2 (3 = 4 "sac") (2 = 11 "Ton") ( 4=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// many "sac" values aren't converted
egen sac_median = median(conversion) if unit==4
replace conversion = sac_median if conversion==. & unit==4

gen NPK_kg = s7dq26c1 * conversion
replace NPK_kg= s7dq26c1 if unit==1
replace NPK_kg = s7dq26c1 * 1000 if unit==11 // tons
replace NPK_kg= 0 if inorganic_fertilizer==0 | s7dq26c1==0
drop conversion unit sac_median

* Other
recode s7dq26d2 (3 = 4 "sac") (2 = 11 "Ton") ( 4=.), gen(unit)
count if inlist(., grappe, unit)
merge m:1 grappe unit using `Conversions', keep(master match) nogen

// many "sac" values aren't converted
egen sac_median = median(conversion) if unit==4
replace conversion = sac_median if conversion==. & unit==4

gen other_kg = s7dq26d1 * conversion
replace other_kg= s7dq26d1 if unit==1
replace other_kg = s7dq26d1 * 1000 if unit==11 // tons
replace other_kg= 0 if inorganic_fertilizer==0 | s7dq26d1==0
drop conversion unit sac_median


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
egen hhid = concat(grappe exploitation), punct("-")
recode s7bq09b (7 8 = 2 "charette") (2 = 1 "kg") (1 = 12 "gram") (3 = 13 "ton") (5 = 4 "sac") (6 9 10 11= . ), gen(unit) 

merge m:1 grappe unit using `Conversions', keep(master match) nogen

gen UREA_purchased_kg = s7bq09a * conversion if s7bq01==6 
replace UREA_purchased_kg = s7bq09a if unit==1 &  s7bq01==6
replace UREA_purchased_kg = s7bq09a *0.001 if unit==12 &  s7bq01==6
replace UREA_purchased_kg = s7bq09a * 1000 if unit==13 &  s7bq01==6
gen UREA_purchased_value = s7bq09c if UREA_purchased_kg!=.

gen DAP_purchased_kg = s7bq09a * conversion if s7bq01==7
replace DAP_purchased_kg = s7bq09a if unit==1 &  s7bq01==7
replace DAP_purchased_kg = s7bq09a *0.001 if unit==12 &  s7bq01==7
replace DAP_purchased_kg = s7bq09a * 1000 if unit==13 &  s7bq01==7 
gen DAP_purchased_value = s7bq09c if DAP_purchased_kg!=.

gen NPK_purchased_kg = s7bq09a * conversion if s7bq01==11
replace NPK_purchased_kg = s7bq09a if unit==1 &  s7bq01==11
replace NPK_purchased_kg = s7bq09a *0.001 if unit==12 &  s7bq01==11
replace NPK_purchased_kg = s7bq09a * 1000 if unit==13 &  s7bq01==11
gen NPK_purchased_value = s7bq09c if NPK_purchased_kg!=.

gen comp_purchased_kg = s7bq09a * conversion if s7bq01==5
replace comp_purchased_kg = s7bq09a if unit==1 &  s7bq01==5
replace comp_purchased_kg = s7bq09a *0.001 if unit==12 &  s7bq01==5
replace comp_purchased_kg = s7bq09a * 1000 if unit==13 &  s7bq01==5
gen comp_purchased_value = s7bq09c if comp_purchased_kg!=.

collapse (max) UREA_purchased_kg DAP_purchased_kg NPK_purchased_kg comp_purchased_kg UREA_purchased_value DAP_purchased_value NPK_purchased_value comp_purchased_value , by(hhid)

valuation_median_fert_price hhid UREA

valuation_median_fert_price hhid DAP

valuation_median_fert_price hhid NPK

valuation_median_fert_price hhid comp

collapse (sum) UREA_value DAP_value NPK_value comp_value (count) n_UREA_value = UREA_value n_DAP_value = DAP_value n_NPK_value = NPK_value n_comp_value = comp_value , by(hhid) 
foreach var in UREA_value DAP_value NPK_value comp_value {
replace `var' = . if n_`var'==0
}
merge 1:m hhid using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

rename comp_value other_value
foreach n in NPK UREA DAP other {
		gen value_`n' = `n'_value * `n'_kg
	}
	
	egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id = concat(grappe exploitation  s7dq01 s7dq02), punct("-")
gen organic_fertilizer = 1 if s7dq05==1 | s7dq10==1 | s7dq16==1
replace organic_fertilizer= 0 if s7dq05==2 & s7dq10==2 & s7dq16==2
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id = concat(grappe exploitation s7dq01 s7dq02), punct("-")
gen used_pesticides = 1 if s7dq30a1!= 0 & !mi(s7dq30a1)
replace used_pesticides=0 if s7dq30a1==0
replace used_pesticides=0 if s7dq27==2
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id = concat(grappe exploitation s11bq01 s11bq02), punct("-")
recode s11bq17 ( 1 2  = 1 "Yes") (3/7 = 0 "No") (99=.) ,  gen(plot_owned) label(plot_owned) 
recode s11bq17 (1 = 1 "Yes") (2/7 = 0 "No") (99=.),  gen(plot_certificate) label(plot_certificate)
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace


// irrigated
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11bq01 s11bq02) , punct("-")	
recode s11bq36 (21/23 = 1 "Yes") (11/14 = 0 "No") (3 = .), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace	


// erosion protection
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id= concat( grappe exploitation s11bq01 s11bq02) , punct("-")	
recode s11bq28 (1 =1 "Yes") ( 2 = 0 "No"), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace	

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
egen hhid = concat(grappe exploitation ), punct("-")
drop if s9q02!=101
recode s09q02 (1 = 1 "Yes") (2 = 0 "No") (9=.), gen(tractor) label(tractor)
replace tractor= 1 if s09q10==1
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace	

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat( grappe exploitation s11bq01 s11bq02) , punct("-")		
recode s11bq32 (1 = 1)  (. = .)  (* = 0), gen(fallow_plot)
bys grappe exploitation: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 grappe exploitation using "${Input}\\${country}\\${wave}\\${cover}", keepusing(grappe exploitation)
egen hhid = concat(grappe exploitation ), punct("-")
replace nb_fallow_plots= 0 if _merge ==2		
keep hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace	

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat( grappe exploitation s11bq01 s11bq02) , punct("-")	
recode s11bq32 (1 = 1)  (. = .)  (* = 0), gen(fallow_plot)
bys grappe exploitation: egen nb_plots = count(fallow_plot) 	
merge m:1 grappe exploitation using "${Input}\\${country}\\${wave}\\${cover}", keepusing(grappe exploitation)
egen hhid = concat(grappe exploitation ), punct("-")
replace nb_plots= 0 if _merge ==2		
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace	

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid = concat(grappe exploitation), punct("-")
recode s2q03 (1= 1 "Yes") (2=0 "No"), gen(formal_education) label(formal_education)
recode s2q06 (  0/5 = 0 "No" ) (6/16 = 1 "Yes") (99= .), gen(primary_education) label(primary_education)
replace primary_education=0 if s2q03==2

bys hhid: egen hh_primary_education= max(primary_education) 
bys hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(hhid)	
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace	


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
egen hhid = concat(grappe exploitation), punct("-")
recode s6q15 (1 2 3 6 = 1 "Yes") (4 5 7 = 0 "No"),  gen(hh_electricity_access) label(hh_electricity_access)
replace hh_electricity_access=1 if s6q16a==4 | s6q16b==4
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace	

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename s1q04a age 
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
merge m:1 grappe exploitation using "${Input}\\${country}\\${wave}\\${cover}",
egen hhid = concat(grappe exploitation), punct("-")
recode s8aq04 (1 = 1 "Yes") (2 = 0 "No") , gen(livestock) label(livestock)
replace livestock=0 if _merge==2
collapse (max) livestock, by(hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace	

// consumption quint (absent)


// consumption aggregate (absent)


// manager chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id = concat(grappe exploitation s11bq01 s11bq02), punct("-")
rename s11bq10 manager_id
sort  hhid (manager_id)
collapse (first) manager_id hhid , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
gen manager_id = codeid  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode  s1q01 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename s1q04a age_manager
replace age_manager=. if age_manager==98 | age_manager==99
recode s1q09 ( 2 3 = 1 "Yes") (1 4/7  = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid = concat(grappe exploitation), punct("-")
gen manager_id = codeid  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode s2q03 (1= 1 "Yes") (2=0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode s2q06 (  0/5 = 0 "No" ) (99= .) (6/16 = 1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager=0 if s2q03==2
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace	

// respondent chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen hhid = concat(grappe exploitation), punct("-")
egen plot_id = concat(grappe exploitation s11bq01 s11bq02), punct("-")
gen respondent_id = s11bq09 
keep  respondent  hhid plot_id
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename codeid respondent_id // this is the HH member id 
egen hhid = concat(grappe exploitation), punct("-")
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode  s1q01 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename s1q04a age_respondent
replace age_respondent=. if age_respondent==98 | age_respondent==99
recode s1q09 ( 2 3 = 1 "Yes") (1 4/6  = 0 "No"), gen(married_respondent) 
keep plot_id female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\Respondent_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
egen hhid = concat(grappe exploitation), punct("-")
gen respondent_id = codeid  // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode s2q03 (1= 1 "Yes") (2=0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode s2q06 (  0/5 = 0 "No" ) (99= .) (6/16 = 1 "Yes"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent=0 if s2q03==2
keep plot_id primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace	

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear // only questionnaire "lourd "
egen hhid = concat(grappe exploitation), punct("-")
recode s5q02 (1 = 1 "Yes") (2 . = 0 "No"), gen(hh_shock) label(hh_shock)
collapse (max) hh_shock, by(hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename  s0q28 hh_size
keep hhid hh_size
duplicates drop
isid hhid
save "${Temp}\\${temppath}\\size.dta", replace	

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
egen hhid = concat(grappe exploitation), punct("-")
rename s9q02 item_cd
drop if inlist(item_cd, 111, 112, 109, 127, 128, 129, 130 )
recode s09q02 (1 = 1) (2 = 0) , gen(hh_owns_) 
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
egen hhid = concat(grappe exploitation), punct("-")
drop if s7q01>31
recode s7q02 ( 2 = 0 ) (1 = 1), gen (hh_owns) // missing items are owned
keep hh_owns hhid s7q01
reshape wide hh_owns , i(hhid) j(s7q01)
factor hh_owns*, pcf 
predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe1}", clear // only questionnaire "lourd "
merge 1:m grappe exploitation using "${Input}\\${country}\\${wave}\\${nfe2}",
egen hhid = concat(grappe exploitation), punct("-")

recode s5q11 ( 2 = 0 "No") (1 = 1 "Yes") (. = .), gen(nonfarm_enterprise) label(nonfarm_enterprise)
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
egen hhid = concat(grappe exploitation), punct("-")
egen ID = concat (hhid codeid ), punct("-")


recode  s1q01 (2=1 "Yes") (1=0 "No"), gen(female) 
rename s1q04a age
recode s1q09 ( 2 3 = 1 "Yes") (1 4/6 7   = 0 "No"), gen(married)
replace married = 0 if married==.
decode  s1q02, gen(relationship_head)
replace  relationship_head = ustrregexra(relationship_head,`"[^a-zA-Z0-9]"',"")
replace relationship_head = "Head" if relationship_head=="Chefdemnage"
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head=="BeaupreBellemre"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head=="BeaufrreBellesoeur"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head=="BeaufilsBellefille"
replace relationship_head = "Grandparent" if relationship_head=="GrandpreGrandmre"
replace relationship_head = "Servant" if relationship_head=="Domestiqueouparentdudomestique"
replace relationship_head = "Spouse" if relationship_head=="Conjointe"
replace relationship_head = "Son/Daughter" if relationship_head=="FilsFille"
replace relationship_head = "Father/Mother" if relationship_head=="PreMre"
replace relationship_head = "Sister/Brother" if relationship_head=="Frresoeur"
replace relationship_head = "Other Relative" if relationship_head=="CousinCousine "
replace relationship_head = "Other Relative" if relationship_head=="AutresParentsduCMConjoint"
replace relationship_head = "Non Relative" if relationship_head=="PersonnenonapparenteauCMniauconjoint"
replace relationship_head = "Niece/Nephew" if relationship_head=="NeveuNice"
replace relationship_head = "Grandchild" if relationship_head=="Petitfilspetitefille"


keep hhid ID married female age relationship_head s1q04b
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting (absent)


// labor 
use "${Input}\\${country}\\${wave}\\${indiv_labor}", clear 
merge 1:1 grappe exploitation codeid using "${Input}\\${country}\\${wave}\\${indiv_roster}"
egen hhid = concat(grappe exploitation), punct("-")
egen ID = concat (hhid codeid ), punct("-")

recode s4q01 (2 = 0) (.=.) (else = 1) , gen(farm_work)
recode s4q02 (2 = 0) (.=.) (else = 1) , gen( SOB_work)
recode s4q03 (2 = 0) (.=.) (else = 1) , gen( wage_work)


// nb of working age members
gen working_age = s1q04a>=6
bys hhid: egen nb_members_working_age = total(working_age)


// industry:
gen 	ind_ag = s4q13 >= 1 & s4q13 <=4  // Agriculture 
gen 	ind_fish = s4q13 == 5 // fishing
gen 	ind_mining = s4q13 == 6 | s4q13==7	// mining
gen 	ind_manuf = s4q13 >= 8 & s4q13 <= 29	// manuf
gen 	ind_const = s4q13 == 30	// construc
gen 	ind_serv = s4q13 >= 31 & s4q13<= 43	// services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if s4q14==3 | s4q18==7 | s4q18==8 | s4q18==9 // remove self employment
	replace `var' = 0 if s4q11==2 // did not work
}

	gen hour_job1 = s4q17
	replace hour_job1 = 0 if s4q05==2 & s4q06==2 //answered "no" to filter questions = unemployed
	replace hour_job1 = 0 if s4q11==2 
	gen hour_job2 = s4q32
	replace hour_job2 = 0 if s4q05==2 & s4q06==2 //answered "no" to filter questions = unemployed
	replace hour_job2 = 0 if s4q11==2 

	gen day_job1 = s4q16
	replace day_job1 = 0 if s4q05==2 & s4q06==2 //answered "no" to filter questions = unemployed
	replace day_job1 = 0 if s4q11==2 
	gen day_job2 = s4q31
	replace day_job2 = 0 if s4q05==2 & s4q06==2 //answered "no" to filter questions = unemployed
	replace day_job2 = 0 if s4q11==2 
	
	gen month_job1 = s4q15
	replace month_job1 = 0 if s4q05==2 & s4q06==2 //answered "no" to filter questions = unemployed
	replace month_job1 = 0 if s4q11==2 	
	gen month_job2 = s4q30
	replace month_job2 = 0 if s4q05==2 & s4q06==2 //answered "no" to filter questions = unemployed
	replace month_job2 = 0 if s4q11==2 			

gen av_hours1 = (month_job1 * hour_job1 * day_job1) / 52 // (week average of hours)
gen av_hours2 = (month_job2 * hour_job2 * day_job2) / 52 // (week average of hours)
replace av_hours2 = 0 if s4q26==2 
	
	
recode s4q12 (11 12 = 1) (. 99 =.) (else = 0) , gen(farm_job1)
recode s4q27 (11 12 = 1) (. 99 =.) (else = 0) , gen(farm_job2)
replace farm_job1 = 0 if s4q11==2
replace farm_job1 = 0 if farm_job1==1 & inlist(s4q14, 1, 2, 3, 7)
replace farm_job2 = 0 if s4q11==2
replace farm_job2 = 0 if farm_job2==1 & inlist(s4q29, 1, 2, 3, 7)
recode s4q12 ( 62 = 1) (. 99 =.) (else = 0) , gen(SB_job1)
recode s4q27 ( 62 = 1) (. 99 =.) (else = 0) , gen(SB_job2)
replace SB_job1 = 0 if SB_job1==1 & inlist(s4q14, 1, 2, 3, 7)
replace SB_job1 = 0 if s4q11==2
replace SB_job2 = 0 if SB_job2==1 & inlist(s4q29, 1, 2, 3, 7)
replace SB_job2 = 0 if s4q11==2
recode s4q12 ( 20 21 22 23 24 25 31 41 42 43 51 52 61 63 71 72 81= 1) (. 99 =.) (else = 0) , gen(wage_job1)
recode s4q27 ( 20 21 22 23 24 25 31 41 42 43 51 52 61 63 71 72 81 = 1) (. 99 =.) (else = 0) , gen(wage_job2)
replace wage_job1 = 1 if wage_job1==0 & inlist(s4q14, 1, 2, 3, 7)
replace wage_job1 = 0 if s4q11==2
replace wage_job2 = 1 if wage_job2==0 & inlist(s4q29, 1, 2, 3, 7)
replace wage_job2 = 0 if s4q11==2

foreach act in farm SB wage {
	gen `act'_hrs1 = av_hours1 if `act'_job1 == 1
	replace `act'_hrs1 = 0 if `act'_job1 == 0
	gen `act'_hrs2 = av_hours2 if `act'_job2 == 1
	replace `act'_hrs2 = 0 if `act'_job2 == 0
	egen `act'_hrs = rowtotal(`act'_hrs1 `act'_hrs2), missing
}


foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep ID hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace


// education
use "${Input}\\${country}\\${wave}\\${indiv_roster2}", clear
merge 1:1 grappe exploitation codeid using "${Input}\\${country}\\${wave}\\${indiv_roster}", 
egen hhid = concat(grappe exploitation), punct("-")
egen ID = concat (hhid codeid ), punct("-")
recode s2q03 (1= 1 "Yes") (2=0 "No"), gen(formal_education) label(formal_education)
recode s2q06 (  0/5 = 0 "No" ) (6/16 = 1 "Yes") (99= .), gen(primary_education) label(primary_education)
replace primary_education=0 if s2q03==2
foreach var in formal_education primary_education {
replace `var' = 0  if s1q04a<6
}
keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace

// HDDS (absent)
