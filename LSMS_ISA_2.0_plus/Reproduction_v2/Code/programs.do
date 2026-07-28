
// program for median valuations

capture program drop valuation_median_crops
program define valuation_median_crops 
args hhid plotid cropvar 

merge m:1 `hhid'  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	


merge 1:1 `hhid' `plotid' `cropvar' using "${Temp}\\${temppath}\\harvest_sold_value.dta", keep(master match)	nogen
merge 1:1 `hhid' `plotid' `cropvar' using "${Temp}\\${temppath}\\harvest_sold_kg.dta", keep(master match)	nogen
gen crop_price_temp= harvest_sold_value / harvest_sold_kg 
replace crop_price_temp = . if crop_price_temp==0


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

		
		*EA level
		gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
		bys ea_id `cropvar': egen n2= total(n)
		gen ten_obs_EA=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA=0 if n2<10 | mi(n2)
		tab ten_obs_EA
		bys ea_id `cropvar': egen crop_price_EA = median(crop_price_temp) if crop_price_temp!=0
		gen crop_price = crop_price_EA if ten_obs_EA==1
		drop n2 
		
		
		capture confirm variable admin_4
		if !_rc {
				bys admin_4 `cropvar': egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar': egen crop_price_admin4 = median(crop_price_temp) if crop_price_temp!=0
				replace crop_price = crop_price_admin4 if ten_obs_admin4==1 & ten_obs_EA==0 // no change
				drop n2 

				bys admin_3 `cropvar': egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				replace crop_price = crop_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
				else {

				bys admin_3 `cropvar': egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				replace crop_price = crop_price_admin3 if ten_obs_admin3==1 & ten_obs_EA==0 
				drop n2 
				} 
		
		
		* 
		bys admin_2 `cropvar': egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar': egen crop_price_admin2 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar': egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar': egen crop_price_admin_1 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar': egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar': egen crop_price_national = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace crop_price=crop_price_national if ten_obs_n==0
		
	** Collapse to the EA - crop level
	keep ea_id `cropvar' crop_price
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m ea_id `cropvar'  using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using) nogen
	gen harvest_value = crop_price * harvest_kg
		
end


// program for main crop calculation


capture program drop main_crop_def
program define main_crop_def 
args cropvar 

bys plot_id (harvest_value): gen n=_n if !mi(plot_id) & !mi(`cropvar') & !mi(harvest_value) // This ranks crops by harvest value within a plot 
bys plot_id: egen nMax= max(n)  
gen main_crop_obs = `cropvar' if n==nMax
bys plot_id: egen main_crop = max(main_crop_obs) // this is the variable of interest. It is now at the plot level.
drop n nMax


end


capture program drop main_crop_def_parcel
program define main_crop_def_parcel 
args cropvar 

bys parcel_id (harvest_value): gen n=_n if !mi(parcel_id) & !mi(`cropvar') & !mi(harvest_value) // This ranks crops by harvest value within a plot 
bys parcel_id: egen nMax= max(n)  
gen main_crop_obs = `cropvar' if n==nMax
bys parcel_id: egen main_crop = max(main_crop_obs) // this is the variable of interest. It is now at the plot level.
drop n nMax


end


// program to value seeds
capture program drop valuation_median_seeds
program define valuation_median_seeds 
args hhid id_link_seeds cropvar 

merge m:1 `hhid'  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen


merge 1:1 `id_link_seeds' `cropvar' improved using "${Temp}\\${temppath}\\seed_value_temp.dta", keep(master match)	nogen
merge 1:1 `id_link_seeds' `cropvar' improved using "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", keep(master match)	nogen
	
gen seed_price_temp = seed_value_temp / seeds_amount_purchased_kg
replace seed_price_temp = . if seed_price_temp==0



forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

		
		*EA level
		gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
		bys ea_id `cropvar' improved: egen n2= total(n)
		gen ten_obs_EA=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA=0 if n2<10 | mi(n2)
		tab ten_obs_EA
		bys ea_id `cropvar' improved: egen seed_price_EA = median(seed_price_temp) if seed_price_temp!=0
		gen seed_price = seed_price_EA if ten_obs_EA==1
		drop n2 
		
		capture confirm variable admin_4
		if !_rc {
				bys admin_4 `cropvar' improved: egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar' improved: egen seed_price_admin4 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin4 if ten_obs_admin4==1 & ten_obs_EA==0 // no change
				drop n2 

				bys admin_3 `cropvar' improved: egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' improved: egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
			else {
				bys admin_3 `cropvar' improved: egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' improved: egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_EA==0 
				drop n2 
				} 
		
				
		
		* 
		bys admin_2 `cropvar' improved: egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar' improved: egen seed_price_admin2 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar' improved: egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar' improved: egen seed_price_admin_1 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar' improved: egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar' improved: egen seed_price_national = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace seed_price=seed_price_national if ten_obs_n==0
		
	
	** Collapse to the EA - crop level
	keep ea_id `cropvar' seed_price improve
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m ea_id `cropvar' improve using "${Temp}\\${temppath}\\seed_kg.dta", keep(match using) nogen
	gen seed_value = seed_price * seed_kg
		
		
end

// program to calculate median wages

capture program drop valuation_median_wages
program define valuation_median_wages 
args hhid hired_man_wage hired_woman_wage hired_child_wage

merge m:1 `hhid'  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen

forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

	* EA level
	
		// Men
		gen x1=1 if !mi(`hired_man_wage') & `hired_man_wage'>0
		bys ea_id: egen n2= total(x1), missing
		gen ten_obs_EA_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA_man=0 if n2<10 |mi(n2)
		tab ten_obs_EA_man
		bys ea_id: egen man_wage = median(`hired_man_wage') if `hired_man_wage'>0
		bys ea_id (man_wage): replace man_wage = man_wage[1] // in case wage==0
		drop n2
		
		//Women
		gen x2=1 if !mi(`hired_woman_wage') & `hired_woman_wage'>0
		bys ea_id: egen n2= total(x2), missing
		gen ten_obs_EA_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA_woman=0 if n2<10 |mi(n2)
		tab ten_obs_EA_woman
		bys ea_id: egen woman_wage = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys ea_id (woman_wage): replace woman_wage = woman_wage[1] // in case wage==0
		drop n2
		
		// Children
		gen x3=1 if !mi(`hired_child_wage') & `hired_child_wage'>0
		bys ea_id: egen n2= total(x3), missing
		gen ten_obs_EA_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA_child=0 if n2<10 |mi(n2)
		tab ten_obs_EA_child
		bys ea_id: egen child_wage = median(`hired_child_wage') if `hired_child_wage'>0
		bys ea_id (child_wage): replace child_wage = child_wage[1] // in case wage==0
		drop n2
		
	* admin 4 level
		capture confirm variable admin_4
		if !_rc {
		bys admin_4 : egen n2=total(x1)
		gen ten_obs_admin4_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_man
		bys admin_4 : egen  man_wage_kebele = median(`hired_man_wage') if `hired_man_wage'>0
		bys admin_4 (man_wage_kebele): replace man_wage_kebele = man_wage_kebele[1] // in case wage==0
		replace man_wage=  man_wage_kebele if ten_obs_admin4_man==1 & ten_obs_EA_man==0 
		drop n2 
		
		bys admin_4 : egen n2=total(x2), missing
		gen ten_obs_admin4_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_woman
		bys admin_4 : egen  woman_wage_kebele = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys admin_4 (woman_wage_kebele): replace woman_wage_kebele = woman_wage_kebele[1] // in case wage==0
		replace woman_wage=  woman_wage_kebele if ten_obs_admin4_woman==1 & ten_obs_EA_woman==0 
		drop n2
		
		bys admin_4 : egen n2=total(x3), missing
		gen ten_obs_admin4_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_child
		bys admin_4 : egen  child_wage_kebele = median(`hired_child_wage')  if `hired_child_wage'>0
		bys admin_4 (child_wage_kebele): replace child_wage_kebele = child_wage_kebele[1] // in case wage==0
		replace child_wage=  child_wage_kebele if ten_obs_admin4_child==1 & ten_obs_EA_child==0 
		drop n2
		
	* admin 3 level
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_man=1 if n2>=10 & !mi(n2) 
		replace ten_obs_admin3_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_man
		bys admin_3 : egen  man_wage_woreda = median(`hired_man_wage') if `hired_man_wage'>0
		bys admin_3 (man_wage_woreda): replace man_wage_woreda = man_wage_woreda[1] // in case wage==0
		replace man_wage=  man_wage_woreda if ten_obs_admin3_man==1 & ten_obs_admin4_man==0 
		drop n2 
		
		bys admin_3 : egen n2=total(x2), missing
		gen ten_obs_admin3_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_woman
		bys admin_3 : egen  woman_wage_woreda = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys admin_3 (woman_wage_woreda): replace woman_wage_woreda = woman_wage_woreda[1] // in case wage==0
		replace woman_wage=  woman_wage_woreda if ten_obs_admin3_woman==1 & ten_obs_admin4_woman==0 
		drop n2
		
		bys admin_3 : egen n2=total(x3), missing
		gen ten_obs_admin3_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_child
		bys admin_3 : egen  child_wage_woreda = median(`hired_child_wage') if `hired_child_wage'>0
		bys admin_3 (child_wage_woreda): replace child_wage_woreda = child_wage_woreda[1] // in case wage==0
		replace child_wage=  child_wage_woreda if ten_obs_admin3_child==1 & ten_obs_admin4_child==0 
		drop n2
		}
		else {
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_man=1 if n2>=10 & !mi(n2) 
		replace ten_obs_admin3_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_man
		bys admin_3 : egen  man_wage_woreda = median(`hired_man_wage') if `hired_man_wage'>0
		bys admin_3 (man_wage_woreda): replace man_wage_woreda = man_wage_woreda[1] // in case wage==0
		replace man_wage=  man_wage_woreda if ten_obs_admin3_man==1 & ten_obs_EA_man==0 
		drop n2 
		
		bys admin_3 : egen n2=total(x2), missing
		gen ten_obs_admin3_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_woman
		bys admin_3 : egen  woman_wage_woreda = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys admin_3 (woman_wage_woreda): replace woman_wage_woreda = woman_wage_woreda[1] // in case wage==0
		replace woman_wage=  woman_wage_woreda if ten_obs_admin3_woman==1 & ten_obs_EA_woman==0 
		drop n2
		
		bys admin_3 : egen n2=total(x3), missing
		gen ten_obs_admin3_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_child
		bys admin_3 : egen  child_wage_woreda = median(`hired_child_wage') if `hired_child_wage'>0
		bys admin_3 (child_wage_woreda): replace child_wage_woreda = child_wage_woreda[1] // in case wage==0
		replace child_wage=  child_wage_woreda if ten_obs_admin3_child==1 & ten_obs_EA_child==0 
		drop n2
		}
		
	* admin 2 level
		bys admin_2: egen n2=total(x1), missing
		gen ten_obs_admin2_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_man
		bys admin_2: egen  man_wage_zone = median(`hired_man_wage') if `hired_man_wage'>0
		bys admin_2 (man_wage_zone): replace man_wage_zone = man_wage_zone[1] // in case wage==0
		replace man_wage =  man_wage_zone if ten_obs_admin2_man==1 &ten_obs_admin3_man==0 
		drop n2
		
		bys admin_2: egen n2=total(x2), missing
		gen ten_obs_admin2_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_woman
		bys admin_2: egen  woman_wage_zone = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys admin_2 (woman_wage_zone): replace woman_wage_zone = woman_wage_zone[1] // in case wage==0
		replace woman_wage =  woman_wage_zone if ten_obs_admin2_woman==1 &ten_obs_admin3_woman==0 
		drop n2
		
		bys admin_2: egen n2=total(x3), missing
		gen ten_obs_admin2_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_child
		bys admin_2: egen  child_wage_zone = median(`hired_child_wage') if `hired_child_wage'>0
		bys admin_2 (child_wage_zone): replace child_wage_zone = child_wage_zone[1] // in case wage==0
		replace child_wage =  child_wage_zone if ten_obs_admin2_child==1 &ten_obs_admin3_child==0 
		drop n2

		bys admin_1: egen n2=total(x1), missing
		gen ten_obs_admin1_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_man
		bys admin_1: egen  man_wage_region = median(`hired_man_wage') if `hired_man_wage'>0
		bys admin_1 (man_wage_region): replace man_wage_region = man_wage_region[1] // in case wage==0
		replace  man_wage =  man_wage_region if ten_obs_admin1_man==1 &ten_obs_admin2_man==0 
		drop n2
		
		bys admin_1: egen n2=total(x2), missing
		gen ten_obs_admin1_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_woman
		bys admin_1: egen  woman_wage_region = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys admin_1 (woman_wage_region): replace woman_wage_region = woman_wage_region[1] // in case wage==0
		replace  woman_wage =  woman_wage_region if ten_obs_admin1_woman==1 &ten_obs_admin2_woman==0 
		drop n2
		
		bys admin_1: egen n2=total(x3), missing
		gen ten_obs_admin1_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_child
		bys admin_1: egen  child_wage_region = median(`hired_child_wage') if `hired_child_wage'>0
		bys admin_1 (child_wage_region): replace child_wage_region = child_wage_region[1] // in case wage==0
		replace  child_wage =  child_wage_region if ten_obs_admin1_child==1 &ten_obs_admin2_child==0 
		drop n2
		
	* 
		egen n2=total(x1), missing
		gen ten_obs_n_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_man=0 if n2<10 |mi(n2)
		tab ten_obs_n_man
		egen  man_wage_national = median(`hired_man_wage') if `hired_man_wage'>0
		bys man_wage_national: replace man_wage_national = man_wage_national[1] // in case wage==0
		replace  man_wage =  man_wage_national if ten_obs_n_man==1 &ten_obs_admin1_man==0 
		drop n2 x1
		
		egen n2=total(x2), missing
		gen ten_obs_n_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_woman=0 if n2<10 |mi(n2)
		tab ten_obs_n_woman
		egen  woman_wage_national = median(`hired_woman_wage') if `hired_woman_wage'>0
		bys woman_wage_national: replace woman_wage_national = woman_wage_national[1] // in case wage==0
		replace  woman_wage =  woman_wage_national if ten_obs_n_woman==1 &ten_obs_admin1_woman==0 
		drop n2 x2
		
		egen n2=total(x3), missing
		gen ten_obs_n_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_child=0 if n2<10 |mi(n2)
		tab ten_obs_n_child
		egen  child_wage_national = median(`hired_child_wage') if `hired_child_wage'>0
		bys child_wage_national: replace child_wage_national = child_wage_national[1] // in case wage==0
		replace  child_wage =  child_wage_national if ten_obs_n_child==1 &ten_obs_admin1_child==0 
		drop n2 x3
		
		replace man_wage=man_wage_national if ten_obs_n_man==0
		replace woman_wage=woman_wage_national if ten_obs_n_woman==0
		replace child_wage=child_wage_national if ten_obs_n_child==0
		
		
end


// program to calculate inorganic fertilizer value


capture program drop valuation_median_fert_price
program define valuation_median_fert_price 
args hhid name

merge m:1 `hhid'  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen

forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

	gen `name'price = `name'_purchased_value/ `name'_purchased_kg


	** `name'
		gen x1=1 if !mi(`name'price) & `name'price!=0
		bys ea_id: egen n2= total(x1), missing
		gen ten_obs_EA_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_EA_`name'
		bys ea_id: egen `name'_value_EA = median(`name'price) if `name'price>0
		gen `name'_value = `name'_value_EA if ten_obs_EA_`name'==1
		drop n2
		
		
	** Kebele
		capture variable admin_4 
		if !_rc {
		bys admin_4 : egen n2=total(x1), missing
		gen ten_obs_admin4_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_`name'
		bys admin_4 : egen  `name'_value_admin4 = median(`name'price) if `name'price>0 
		replace `name'_value=  `name'_value_admin4 if ten_obs_admin4_`name'==1 & ten_obs_EA_`name'==0 
		drop n2 
		
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_`name'
		bys admin_3 : egen  `name'_value_admin3 = median(`name'price) if `name'price>0 
		replace `name'_value=  `name'_value_admin3 if ten_obs_admin3_`name'==1 & ten_obs_admin4_`name'==0 
		drop n2 
		} 
		else {
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_`name'
		bys admin_3 : egen  `name'_value_admin3 = median(`name'price) if `name'price>0 
		replace `name'_value=  `name'_value_admin3 if ten_obs_admin3_`name'==1 & ten_obs_EA_`name'==0 
		drop n2
		}
	
		
	***  
		bys admin_2 : egen n2=total(x1), missing
		gen ten_obs_admin2_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_`name'
		bys admin_2 : egen  `name'_value_admin2 = median(`name'price) if `name'price>0 
		replace `name'_value=  `name'_value_admin2 if ten_obs_admin2_`name'==1 & ten_obs_admin3_`name'==0 
		drop n2 
		
	***  
		
		bys admin_1 : egen n2=total(x1), missing
		gen ten_obs_admin1_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_`name'
		bys admin_1 : egen  `name'_value_admin1 = median(`name'price) if `name'price>0
		replace `name'_value=  `name'_value_admin1 if ten_obs_admin1_`name'==1 & ten_obs_admin2_`name'==0 
		drop n2 
		
	***  
		egen n2=total(x1), missing
		gen ten_obs_n_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_n_`name'
		egen  `name'_value_national = median(`name'price) if `name'price>0
		replace `name'_value=  `name'_value_national if ten_obs_n_`name'==1 & ten_obs_admin1_`name'==0 
		drop n2  x1
		

	//gen value_`name'_total = `name'_value * `name'_kg

end 


// program to add variable labels
capture program drop define_labels
program define_labels 

	forvalues n= 1/4 {
		capture lab var admin_`n' "Administrative level `n'"
		capture lab var admin_`n'_name "Name of administrative level `n'"
	}
	capture lab var country "Country name"
	capture lab var geocoords_id "Geocoordinate ID"
	capture lab var strataid "Stratum ID"
	capture lab var urban "Is this an urban EA?"
	capture lab var unique_parcel_id "Parcel ID"
	capture lab var season "Season ID (UGA)"
	capture lab var ea_id_obs "EA ID (panel identificator)"
	capture lab var ea_id_merge "EA ID (to merge with raw data)"	
	capture lab var hh_id_obs "Household ID (panel identificator)"
	capture lab var hh_id_merge "Household ID (to merge with raw data)"
	capture lab var indiv_id_obs "Individual ID (panel identificator)"
	capture lab var indiv_id_merge "Individual ID (to merge with raw data)"
	capture lab var plot_id_obs "Plot ID (panel identificator)"
	capture lab var plot_id_merge "Plot ID (to merge with raw data)"
	capture lab var parcel_id_obs "Parcel ID (panel identificator)"
	capture lab var parcel_id_merge "Parcel ID (to merge with raw data)"
	capture lab var manager_id_obs "Manager ID (panel identificator)"
	capture lab var manager_id_merge "Manager ID (to merge with raw data)"
	capture lab var plot_manager_id "Unique plot manager ID"
	capture lab var hh_id "Household ID"
	capture lab var harvest_interview_month  "Month of the harvest interview"
	capture lab var planting_interview_month "Month of the planting interview"
	capture lab var perennial_crops "Does this household grow perennial or annual crops?"
	capture lab var intercropped "Is any crop intercropped?"
	capture lab var harvest_end_month "Harvest end month"
	capture lab var main_crop "Crop with the highest value on the plot"
	capture lab var harvest_kg "Total harvest in kg"
	capture lab var harvest_kg_cc "Total harvest quantity (in kg), using crop cut values"
	capture lab var total_labor_days "Total labor days on the plot"
	capture lab var total_family_labor_days "Total family labor days on the plot"
	capture lab var total_hired_labor_days "Total hired labor days on the plot"
	capture lab var maize_plot "Does this plot contain maize?" 
	capture lab var sorghum_plot "Does this plot contain sorghum?" 
	capture lab var wheat_plot "Does this plot contain wheat?"
	capture lab var seed_transport_cost "Seed transport costs per plot"
	capture lab var improved "Does this plot contain improved seeds? (default: traditional)"
	capture lab var parcel_owned "Is this parcel owned by the household?"
	capture lab var parcel_certificate "Does the household own a certificate for this parcel?"
	capture lab var plot_area "Area (in hectares) of plot"
	capture lab var self_reported_area "Is the area of plot_area self reported?"
	capture lab var irrigated"Is the plot irrigated?" 
	capture lab var fallow "Has the plot been left fallow in the past 10 years?"
	capture lab var hh_primary_education "Did anyone in the household complete primary school?"
	capture lab var hh_formal_education "Does anyone in the household posses any formal education?"
	capture lab var hh_dependency_ratio "Household dependency ratio"
	capture lab var hh_electricity_access "Does this household have access to electricity?"
	capture lab var age_manager "Age (in years) of the plot manager"
	capture lab var female_manager "Is the plot manager female?"
	capture lab var married_manager "Is the plot manager married?"
	capture lab var primary_education_manager "Did the plot manager complete primary school?"
	capture lab var formal_education_manager "Does the plot manager possess any formal education?"
	capture lab var hh_shock "Was the household negatively impacted by a shock over the past 12 months?"
	capture lab var ag_asset_index "Agricultural assets index"
	capture lab var used_herbicides "Were herbicides used on this plot?"
	capture lab var used_pesticides "Were pesticides used on this plot?"
	capture lab var used_fungicides "Were fungicides used on this plot?"
	capture lab var livestock "Is the respondent engaged in livestock activities?"
	capture lab var hh_electricity_access "Does the household have access to electricity?"
	capture lab var erosion_protection "Is the plot protected from erosion by erosion_protection?" 
	capture lab var wheat_kg "Amount of wheat (in kg)"
	capture lab var sorghum_kg "Amount of sorghum (in kg)"
	capture lab var maize_kg "Amount of maize (in kg)"
	capture lab var harvest_transport_cost "Harvest transport cost"
	capture lab var planting_month "Month of planting"
	capture lab var crop_shock "Did a shock affect crops in the current season?" 
	capture lab var drought_shock "Were crops affected by drought in the current agricultural season?" 
	capture lab var rain_shock "Were crops affected by rains in the current agricultural season?" 
	capture lab var pests_shock "Were crops affected by pests in the current agricultural season?"
	capture lab var flood_shock "Were crops affected by floods in the current agricultural season?"
	capture lab var inorganic_fertilizer "Has at least one inorganic fertilizer been used on this plot?"
	capture lab var organic_fertilizer "Has at least one organic fertilizer been used on this plot?"
	capture lab var manure "Has manure been used?"
	capture lab var compost "Has compost been used?"
	capture lab var other_organic "Has another organic fertilizer been used?"	
	capture lab var seed_kg "Quantity of seeds (in kg)"
	capture lab var hh_size "Household size"
	capture lab var respondent_id_obs "Respondent ID (panel identificator)"
	capture lab var respondent_id_merge "Respondent ID (to merge with raw data)"
	capture lab var female_respondent "Is the respondent female?"
	capture lab var age_respondent "What is the age of the respondent?"
	capture lab var married_respondent "Is the respondent married?"
	capture lab var primary_education_respondent "Did the plot respondent complete primary school?"
	capture lab var formal_education_respondent "Does the plot respondent possess any formal education?"
	capture lab var formal_education "Any formal education?"
	capture lab var education "Complete primary school?"
	foreach s in LCU USD { 
	capture lab var yield_value_`s' "Yield value (harvest value/ha), in`s'"
	capture lab var harvest_value_`s' "Value of plot harvest, in `s'"
	capture lab var seed_value_`s' "Value of seeds, in `s' "
	capture lab var hired_labor_value_`s' "Vale of hired labor, in `s'" 		
	capture lab var harvest_sold_value_`s' "Value of sold harvest, in `s'"
	capture lab var inorganic_fertilizer_value_`s' "Inorganic fertilizer value, in `s'"
	capture lab var totcons_`s' "Consumption aggregate per capita, in `s'"
	}
	capture lab var cons_quint "Household consumption quintile"
	capture lab var seeds_amount_purchased_kg "Amount of purchased seeds (in kg)"
	capture lab var strataid "Strata ID"
	capture lab var harvest_sold_kg "Amount of sold harvest (kg)"
	capture lab var yield_kg "Yield amount (harvest in kg/ha)"
	capture lab var pct_area_planted "Percent of plot area planted with crop"
	capture lab var hh_asset_index "Household asset index"
	capture lab var pw "Household weight"
	capture lab var age "Age (in years)"
	capture lab var female "Is the individual a female?"
	capture lab var married "Is the individual married?"
	capture lab var weight "Individual weight"
	capture lab var height "Individual height"
	capture lab var haz06 "Height-for-age Z-score"
	capture lab var farm_work "Individual has worked in own farm in (past) 7 days"
	capture lab var SOB_work "Individual has worked in own business in (past) 7 days"
	capture lab var wage_work "Individual has worked for own wage in (past) 7 days"
	capture lab var farm_hrs "Number of hours spent in own farm ag work in (past) 7 days"
	capture lab var SB_hrs "Number of hours spent in own business work in (past) 7 days"
	capture lab var wage_hrs "Number of hours spent in wage labor in (past) 7 days"
	capture lab var nb_seasonal_crop "Number of seasonal crops grown on plot"
	capture lab var nb_fallow_plots "Number of fallow plots under household management"
	capture lab var nb_plots "Number of plots under household management"
	capture lab var maincrop_valueshare "Share of plot value attribute to main crop"
	capture lab var nitrogen_kg "Nitrogen equivalent of applied inorganic fertilizer (kg)"
	capture lab var nonfarm_enterprise "Someone in household owns a non-farm enterprise"
	capture lab var soil_fertility_index "Soil fertility index"
	capture lab var wasting "Child with wasting"
	capture lab var working_age "Working age household member (according to questionnaire)"
	capture lab var ind_ag "Any wage work in agriculture"
	capture lab var ind_fish  "Any wage work in fishing"
	capture lab var ind_mining  "Any wage work in mining"
	capture lab var ind_manuf "Any wage work in manufacturing"
	capture lab var ind_const "Any wage work in construction"
	capture lab var ind_serv "Any wage work in services"
	capture lab var tractor "Did the household use a tractor in this season?"
	
	local main_crop_grps "BARLEY LEGUMES MAIZE MILLET NUTS OTHER PERENNIALS RICE SORGHUM TUBERS WHEAT"
	forvalues n=1/11 {
	local mc: word `n' of `main_crop_grps'
	capture lab var contains_crop_`n' "Plot contains `mc'"
	capture lab var share_crop`n' "Share of plot value derive from `mc'"
	}
	
	capture rename contains_crop_1 contains_BARLEY
	capture rename contains_crop_2 contains_LEGUMES
	capture rename contains_crop_3 contains_MAIZE
	capture rename contains_crop_4 contains_MILLET
	capture rename contains_crop_5 contains_NUTS
	capture rename contains_crop_6 contains_OTHER
	capture rename contains_crop_7 contains_PERENNIALS
	capture rename contains_crop_8 contains_RICE
	capture rename contains_crop_9 contains_SORGHUM
	capture rename contains_crop_10 contains_TUBERS
	capture rename contains_crop_11 contains_WHEAT
	
	capture rename share_crop1 share_value_BARLEY
	capture rename share_crop2 share_value_LEGUMES
	capture rename share_crop3 share_value_MAIZE
	capture rename share_crop4 share_value_MILLET
	capture rename share_crop5 share_value_NUTS
	capture rename share_crop6 share_value_OTHER
	capture rename share_crop7 share_value_PERENNIAL
	capture rename share_crop8 share_value_RICE
	capture rename share_crop9 share_value_SORGHUM
	capture rename share_crop10 share_value_TUBERS
	capture rename share_crop11 share_value_WHEAT
	
	
	capture lab var nutrient_availability "Nutrient Availability"
	capture lab var nutrient_retention "Nutrient Retention"
	capture lab var rooting_conditions "Rooting conditions"
	capture lab var oxygen_availability "Oxygen availability"
	capture lab var excess_salts "Excess salts"
	capture lab var toxicity "Toxicity"
	capture lab var workability "Workability"
	capture lab var plot_slope "Plot slope"
	capture lab var twi "Total wetness index"
	capture lab var plot_owned "Farmer declares owning the plot"
	capture lab var plot_certificate "Possession of a certificate for the plot"

	capture lab var farm_size "Farm size (ha)"
	capture lab var wave "Wave number"
	 
	capture lab var ag_hh_obs "Household also contains valid seasonal harvest obs (=member of the plot-level dataset)"
	capture lab var wage_ind_ag "Any wage lab in agriculture"
	capture lab var wage_ind_fish  "Any wage lab in fishing"
	capture lab var wage_ind_mining "Any wage lab in mining"
	capture lab var wage_ind_manuf "Any wage lab in manufacturing"
	capture lab var wage_ind_const "Any wage lab in construction"
	capture lab var wage_ind_serv "Any wage lab in services"
	capture lab var HDDS "Household dietary diversity index"
	capture lab var share_kg_sold "Share of harvest output (in kg) sold"
	capture lab var primary_education "Completed primary education?"
	
	capture lab var tractor "Does the household use a tractor?"
	capture lab var tot_precip_cumul_season "Total precipitation in the season (in mm)"
	capture lab var temperature_mean_season "Average temperature in the season (in kelvin)"

	

end



************************************************* ADDITIONAL PROGRAMS

// program to value seeds without an "improved" var
capture program drop valuation_median_seeds_noimprove
program define valuation_median_seeds_noimprove 
args hhid id_link_seeds cropvar 

merge m:1 `hhid'  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen


merge 1:1 `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\seed_value_temp.dta", keep(master match)	nogen
merge 1:1 `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", keep(master match)	nogen
	
gen seed_price_temp = seed_value_temp / seeds_amount_purchased_kg
replace seed_price_temp = . if seed_price_temp==0


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

		
		*EA level
		gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
		bys ea_id `cropvar' : egen n2= total(n)
		gen ten_obs_EA=1 if n2>=10 & !mi(n2)
		replace ten_obs_EA=0 if n2<10 | mi(n2)
		tab ten_obs_EA
		bys ea_id `cropvar' : egen seed_price_EA = median(seed_price_temp) if seed_price_temp!=0
		gen seed_price = seed_price_EA if ten_obs_EA==1
		drop n2 
		
			capture confirm variable admin_4
		if !_rc {
				bys admin_4 `cropvar' : egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar' : egen seed_price_admin4 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin4 if ten_obs_admin4==1 & ten_obs_EA==0 // no change
				drop n2 

				bys admin_3 `cropvar' : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
			else {
				bys admin_3 `cropvar' : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_EA==0 
				drop n2 
				} 
		
				
		
		* 
		bys admin_2 `cropvar' : egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar' : egen seed_price_admin2 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar' : egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar' : egen seed_price_admin_1 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar' : egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar' : egen seed_price_national = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace seed_price=seed_price_national if ten_obs_n==0
		
	
	** Collapse to the EA - crop level
	keep ea_id `cropvar' seed_price 
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m ea_id `cropvar'  using "${Temp}\\${temppath}\\seed_kg.dta", keep(match using) nogen
	gen seed_value = seed_price * seed_kg
		
		
end

capture program drop valuation_median_seeds_noea
program define valuation_median_seeds_noea 
args hhid id_link_seeds cropvar 


merge 1:1 `hhid' `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\seed_value_temp.dta", keep(master match)	nogen
merge 1:1 `hhid' `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", keep(master match)	nogen
	
gen seed_price_temp = seed_value_temp / seeds_amount_purchased_kg
replace seed_price_temp = . if seed_price_temp==0


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

			capture confirm variable admin_4
		if !_rc {
				gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
				bys admin_4 `cropvar' improved : egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar' improved : egen seed_price_admin4 = median(seed_price_temp) if seed_price_temp!=0
				gen seed_price = seed_price_admin4 if ten_obs_admin4==1
				drop n2 

				bys admin_3 `cropvar' improved : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' improved : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
			else {
				gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
				bys admin_3 `cropvar' improved : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' improved : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				gen seed_price = seed_price_admin3 if ten_obs_admin3==1 
				drop n2 
				} 	
		
		* 
		bys admin_2 `cropvar' improved : egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar' improved : egen seed_price_admin2 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar' improved : egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar' improved : egen seed_price_admin_1 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar' improved : egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar' improved : egen seed_price_national = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace seed_price=seed_price_national if ten_obs_n==0
		
	
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3 `cropvar' improved seed_price 
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3 `cropvar' improved  using "${Temp}\\${temppath}\\seed_kg.dta", keep(match using) nogen
	gen seed_value = seed_price * seed_kg
		
		
end

capture program drop valuation_median_seeds_noea_S2
program define valuation_median_seeds_noea_S2 
args hhid id_link_seeds cropvar 


merge 1:1 `hhid' `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\_S2seed_value_temp.dta", keep(master match)	nogen
merge 1:1 `hhid' `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\_S2seeds_amount_purchased_kg.dta", keep(master match)	nogen
	
gen seed_price_temp = seed_value_temp / seeds_amount_purchased_kg
replace seed_price_temp = . if seed_price_temp==0


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
}
}

			capture confirm variable admin_4
		if !_rc {
				gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
				bys admin_4 `cropvar' improved : egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar' improved : egen seed_price_admin4 = median(seed_price_temp) if seed_price_temp!=0
				gen seed_price = seed_price_admin4 if ten_obs_admin4==1
				drop n2 

				bys admin_3 `cropvar' improved : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' improved : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
			else {
				gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
				bys admin_3 `cropvar' improved : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' improved : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				gen seed_price = seed_price_admin3 if ten_obs_admin3==1 
				drop n2 
				} 	
		
		* 
		bys admin_2 `cropvar' improved : egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar' improved : egen seed_price_admin2 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar' improved : egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar' improved : egen seed_price_admin_1 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar' improved : egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar' improved : egen seed_price_national = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace seed_price=seed_price_national if ten_obs_n==0
		
	
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3 `cropvar' improved seed_price 
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3 `cropvar' improved  using "${Temp}\\${temppath}\\seed_kg.dta", keep(match using) nogen
	gen seed_value = seed_price * seed_kg
		
		
end

capture program drop val_median_seeds_noimp_noea
program define val_median_seeds_noimp_noea 
args hhid id_link_seeds cropvar 

merge m:1 `hhid'  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen


merge 1:1 `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\seed_value_temp.dta", keep(master match)	nogen
merge 1:1 `id_link_seeds' `cropvar' using "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", keep(master match)	nogen
	
gen seed_price_temp = seed_value_temp / seeds_amount_purchased_kg
replace seed_price_temp = . if seed_price_temp==0

forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

		
		
			capture confirm variable admin_4
		if !_rc {
			gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
				bys admin_4 `cropvar' : egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar' : egen seed_price_admin4 = median(seed_price_temp) if seed_price_temp!=0
				gen seed_price = seed_price_admin4 if ten_obs_admin4==1 
				drop n2 

				bys admin_3 `cropvar' : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
			else {
				gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
				bys admin_3 `cropvar' : egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar' : egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
				gen seed_price = seed_price_admin3 if ten_obs_admin3==1
				drop n2 
				} 
		
				
		
		* 
		bys admin_2 `cropvar' : egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar' : egen seed_price_admin2 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar' : egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar' : egen seed_price_admin_1 = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar' : egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar' : egen seed_price_national = median(seed_price_temp) if seed_price_temp!=0
		replace seed_price = seed_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace seed_price=seed_price_national if ten_obs_n==0
		
	
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3 `cropvar' seed_price 
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3 `cropvar'  using "${Temp}\\${temppath}\\seed_kg.dta", keep(match using) nogen
	gen seed_value = seed_price * seed_kg
		
		
end

*** wages no EA
capture program drop valuation_median_wages_noea
program define valuation_median_wages_noea 
args hhid hired_man_wage hired_woman_wage hired_child_wage


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}



	* admin 4 level
		capture confirm variable admin_4
		if !_rc {
		gen x1=1 if !mi(`hired_man_wage') & `hired_man_wage'>0
		bys admin_4 : egen n2=total(x1)
		gen ten_obs_admin4_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_man
		bys admin_4 : egen  man_wage_kebele = median(`hired_man_wage') if `hired_man_wage'>0
		gen man_wage=  man_wage_kebele if ten_obs_admin4_man==1 
		drop n2 
		
		gen x2=1 if !mi(`hired_woman_wage') & `hired_woman_wage'>0		
		bys admin_4 : egen n2=total(x2), missing
		gen ten_obs_admin4_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_woman
		bys admin_4 : egen  woman_wage_kebele = median(`hired_woman_wage') if `hired_woman_wage'>0
		gen woman_wage=  woman_wage_kebele if ten_obs_admin4_woman==1 
		drop n2
		
		gen x3=1 if !mi(`hired_child_wage') & `hired_child_wage'>0
		bys admin_4 : egen n2=total(x3), missing
		gen ten_obs_admin4_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_child
		bys admin_4 : egen  child_wage_kebele = median(`hired_child_wage')  if `hired_child_wage'>0
		gen child_wage=  child_wage_kebele if ten_obs_admin4_child==1 
		drop n2
		
	* admin 3 level
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_man=1 if n2>=10 & !mi(n2) 
		replace ten_obs_admin3_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_man
		bys admin_3 : egen  man_wage_woreda = median(`hired_man_wage') if `hired_man_wage'>0
		replace man_wage=  man_wage_woreda if ten_obs_admin3_man==1 & ten_obs_admin4_man==0 
		drop n2 
		
		bys admin_3 : egen n2=total(x2), missing
		gen ten_obs_admin3_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_woman
		bys admin_3 : egen  woman_wage_woreda = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace woman_wage=  woman_wage_woreda if ten_obs_admin3_woman==1 & ten_obs_admin4_woman==0 
		drop n2
		
		bys admin_3 : egen n2=total(x3), missing
		gen ten_obs_admin3_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_child
		bys admin_3 : egen  child_wage_woreda = median(`hired_child_wage') if `hired_child_wage'>0
		replace child_wage=  child_wage_woreda if ten_obs_admin3_child==1 & ten_obs_admin4_child==0 
		drop n2
		}
		else {
		gen x1=1 if !mi(`hired_man_wage') & `hired_man_wage'>0
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_man=1 if n2>=10 & !mi(n2) 
		replace ten_obs_admin3_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_man
		bys admin_3 : egen  man_wage_woreda = median(`hired_man_wage') if `hired_man_wage'>0
		gen man_wage=  man_wage_woreda if ten_obs_admin3_man==1 
		drop n2 

		gen x2=1 if !mi(`hired_woman_wage') & `hired_woman_wage'>0		
		bys admin_3 : egen n2=total(x2), missing
		gen ten_obs_admin3_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_woman
		bys admin_3 : egen  woman_wage_woreda = median(`hired_woman_wage') if `hired_woman_wage'>0
		gen woman_wage=  woman_wage_woreda if ten_obs_admin3_woman==1 
		drop n2
	
		gen x3=1 if !mi(`hired_child_wage') & `hired_child_wage'>0
		bys admin_3 : egen n2=total(x3), missing
		gen ten_obs_admin3_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_child
		bys admin_3 : egen  child_wage_woreda = median(`hired_child_wage') if `hired_child_wage'>0
		gen child_wage=  child_wage_woreda if ten_obs_admin3_child==1 
		drop n2
		}
		
	* admin 2 level
		bys admin_2: egen n2=total(x1), missing
		gen ten_obs_admin2_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_man
		bys admin_2: egen  man_wage_zone = median(`hired_man_wage') if `hired_man_wage'>0
		replace man_wage =  man_wage_zone if ten_obs_admin2_man==1 &ten_obs_admin3_man==0 
		drop n2
		
		bys admin_2: egen n2=total(x2), missing
		gen ten_obs_admin2_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_woman
		bys admin_2: egen  woman_wage_zone = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace woman_wage =  woman_wage_zone if ten_obs_admin2_woman==1 &ten_obs_admin3_woman==0 
		drop n2
		
		bys admin_2: egen n2=total(x3), missing
		gen ten_obs_admin2_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_child
		bys admin_2: egen  child_wage_zone = median(`hired_child_wage') if `hired_child_wage'>0
		replace child_wage =  child_wage_zone if ten_obs_admin2_child==1 &ten_obs_admin3_child==0 
		drop n2

		bys admin_1: egen n2=total(x1), missing
		gen ten_obs_admin1_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_man
		bys admin_1: egen  man_wage_region = median(`hired_man_wage') if `hired_man_wage'>0
		replace  man_wage =  man_wage_region if ten_obs_admin1_man==1 &ten_obs_admin2_man==0 
		drop n2
		
		bys admin_1: egen n2=total(x2), missing
		gen ten_obs_admin1_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_woman
		bys admin_1: egen  woman_wage_region = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace  woman_wage =  woman_wage_region if ten_obs_admin1_woman==1 &ten_obs_admin2_woman==0 
		drop n2
		
		bys admin_1: egen n2=total(x3), missing
		gen ten_obs_admin1_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_child
		bys admin_1: egen  child_wage_region = median(`hired_child_wage') if `hired_child_wage'>0
		replace  child_wage =  child_wage_region if ten_obs_admin1_child==1 &ten_obs_admin2_child==0 
		drop n2
		
	* 
		egen n2=total(x1), missing
		gen ten_obs_n_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_man=0 if n2<10 |mi(n2)
		tab ten_obs_n_man
		egen  man_wage_national = median(`hired_man_wage') if `hired_man_wage'>0
		replace  man_wage =  man_wage_national if ten_obs_n_man==1 &ten_obs_admin1_man==0 
		drop n2 x1
		
		egen n2=total(x2), missing
		gen ten_obs_n_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_woman=0 if n2<10 |mi(n2)
		tab ten_obs_n_woman
		egen  woman_wage_national = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace  woman_wage =  woman_wage_national if ten_obs_n_woman==1 &ten_obs_admin1_woman==0 
		drop n2 x2
		
		egen n2=total(x3), missing
		gen ten_obs_n_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_child=0 if n2<10 |mi(n2)
		tab ten_obs_n_child
		egen  child_wage_national = median(`hired_child_wage') if `hired_child_wage'>0
		replace  child_wage =  child_wage_national if ten_obs_n_child==1 &ten_obs_admin1_child==0 
		drop n2 x3
		
		replace man_wage=man_wage_national if ten_obs_n_man==0
		replace woman_wage=woman_wage_national if ten_obs_n_woman==0
		replace child_wage=child_wage_national if ten_obs_n_child==0
		
		
end

*** SAme as above, for S2 in UGA
capture program drop valuation_median_wages_noea_S2
program define valuation_median_wages_noea_S2
args hhid hired_man_wage hired_woman_wage hired_child_wage


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
}
}



	* admin 4 level
		capture confirm variable admin_4
		if !_rc {
		gen x1=1 if !mi(`hired_man_wage') & `hired_man_wage'>0
		bys admin_4 : egen n2=total(x1)
		gen ten_obs_admin4_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_man
		bys admin_4 : egen  man_wage_kebele = median(`hired_man_wage') if `hired_man_wage'>0
		gen man_wage=  man_wage_kebele if ten_obs_admin4_man==1 
		drop n2 
		
		gen x2=1 if !mi(`hired_woman_wage') & `hired_woman_wage'>0		
		bys admin_4 : egen n2=total(x2), missing
		gen ten_obs_admin4_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_woman
		bys admin_4 : egen  woman_wage_kebele = median(`hired_woman_wage') if `hired_woman_wage'>0
		gen woman_wage=  woman_wage_kebele if ten_obs_admin4_woman==1 
		drop n2
		
		gen x3=1 if !mi(`hired_child_wage') & `hired_child_wage'>0
		bys admin_4 : egen n2=total(x3), missing
		gen ten_obs_admin4_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_child
		bys admin_4 : egen  child_wage_kebele = median(`hired_child_wage')  if `hired_child_wage'>0
		gen child_wage=  child_wage_kebele if ten_obs_admin4_child==1 
		drop n2
		
	* admin 3 level
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_man=1 if n2>=10 & !mi(n2) 
		replace ten_obs_admin3_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_man
		bys admin_3 : egen  man_wage_woreda = median(`hired_man_wage') if `hired_man_wage'>0
		replace man_wage=  man_wage_woreda if ten_obs_admin3_man==1 & ten_obs_admin4_man==0 
		drop n2 
		
		bys admin_3 : egen n2=total(x2), missing
		gen ten_obs_admin3_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_woman
		bys admin_3 : egen  woman_wage_woreda = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace woman_wage=  woman_wage_woreda if ten_obs_admin3_woman==1 & ten_obs_admin4_woman==0 
		drop n2
		
		bys admin_3 : egen n2=total(x3), missing
		gen ten_obs_admin3_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_child
		bys admin_3 : egen  child_wage_woreda = median(`hired_child_wage') if `hired_child_wage'>0
		replace child_wage=  child_wage_woreda if ten_obs_admin3_child==1 & ten_obs_admin4_child==0 
		drop n2
		}
		else {
		gen x1=1 if !mi(`hired_man_wage') & `hired_man_wage'>0
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_man=1 if n2>=10 & !mi(n2) 
		replace ten_obs_admin3_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_man
		bys admin_3 : egen  man_wage_woreda = median(`hired_man_wage') if `hired_man_wage'>0
		gen man_wage=  man_wage_woreda if ten_obs_admin3_man==1 
		drop n2 

		gen x2=1 if !mi(`hired_woman_wage') & `hired_woman_wage'>0		
		bys admin_3 : egen n2=total(x2), missing
		gen ten_obs_admin3_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_woman
		bys admin_3 : egen  woman_wage_woreda = median(`hired_woman_wage') if `hired_woman_wage'>0
		gen woman_wage=  woman_wage_woreda if ten_obs_admin3_woman==1 
		drop n2
	
		gen x3=1 if !mi(`hired_child_wage') & `hired_child_wage'>0
		bys admin_3 : egen n2=total(x3), missing
		gen ten_obs_admin3_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_child
		bys admin_3 : egen  child_wage_woreda = median(`hired_child_wage') if `hired_child_wage'>0
		gen child_wage=  child_wage_woreda if ten_obs_admin3_child==1 
		drop n2
		}
		
	* admin 2 level
		bys admin_2: egen n2=total(x1), missing
		gen ten_obs_admin2_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_man
		bys admin_2: egen  man_wage_zone = median(`hired_man_wage') if `hired_man_wage'>0
		replace man_wage =  man_wage_zone if ten_obs_admin2_man==1 &ten_obs_admin3_man==0 
		drop n2
		
		bys admin_2: egen n2=total(x2), missing
		gen ten_obs_admin2_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_woman
		bys admin_2: egen  woman_wage_zone = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace woman_wage =  woman_wage_zone if ten_obs_admin2_woman==1 &ten_obs_admin3_woman==0 
		drop n2
		
		bys admin_2: egen n2=total(x3), missing
		gen ten_obs_admin2_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_child
		bys admin_2: egen  child_wage_zone = median(`hired_child_wage') if `hired_child_wage'>0
		replace child_wage =  child_wage_zone if ten_obs_admin2_child==1 &ten_obs_admin3_child==0 
		drop n2

		bys admin_1: egen n2=total(x1), missing
		gen ten_obs_admin1_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_man=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_man
		bys admin_1: egen  man_wage_region = median(`hired_man_wage') if `hired_man_wage'>0
		replace  man_wage =  man_wage_region if ten_obs_admin1_man==1 &ten_obs_admin2_man==0 
		drop n2
		
		bys admin_1: egen n2=total(x2), missing
		gen ten_obs_admin1_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_woman=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_woman
		bys admin_1: egen  woman_wage_region = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace  woman_wage =  woman_wage_region if ten_obs_admin1_woman==1 &ten_obs_admin2_woman==0 
		drop n2
		
		bys admin_1: egen n2=total(x3), missing
		gen ten_obs_admin1_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_child=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_child
		bys admin_1: egen  child_wage_region = median(`hired_child_wage') if `hired_child_wage'>0
		replace  child_wage =  child_wage_region if ten_obs_admin1_child==1 &ten_obs_admin2_child==0 
		drop n2
		
	* 
		egen n2=total(x1), missing
		gen ten_obs_n_man=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_man=0 if n2<10 |mi(n2)
		tab ten_obs_n_man
		egen  man_wage_national = median(`hired_man_wage') if `hired_man_wage'>0
		replace  man_wage =  man_wage_national if ten_obs_n_man==1 &ten_obs_admin1_man==0 
		drop n2 x1
		
		egen n2=total(x2), missing
		gen ten_obs_n_woman=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_woman=0 if n2<10 |mi(n2)
		tab ten_obs_n_woman
		egen  woman_wage_national = median(`hired_woman_wage') if `hired_woman_wage'>0
		replace  woman_wage =  woman_wage_national if ten_obs_n_woman==1 &ten_obs_admin1_woman==0 
		drop n2 x2
		
		egen n2=total(x3), missing
		gen ten_obs_n_child=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_child=0 if n2<10 |mi(n2)
		tab ten_obs_n_child
		egen  child_wage_national = median(`hired_child_wage') if `hired_child_wage'>0
		replace  child_wage =  child_wage_national if ten_obs_n_child==1 &ten_obs_admin1_child==0 
		drop n2 x3
		
		replace man_wage=man_wage_national if ten_obs_n_man==0
		replace woman_wage=woman_wage_national if ten_obs_n_woman==0
		replace child_wage=child_wage_national if ten_obs_n_child==0
		
		
end


******** Harvest without EA 

capture program drop valuation_median_crops_noea
program define valuation_median_crops_noea 
args hhid plotid cropvar 

merge 1:1 `hhid' `plotid' `cropvar' using "${Temp}\\${temppath}\\harvest_sold_value.dta", keep(master match)	nogen
merge 1:1 `hhid' `plotid' `cropvar' using "${Temp}\\${temppath}\\harvest_sold_kg.dta", keep(master match)	nogen
gen crop_price_temp= harvest_sold_value / harvest_sold_kg 
replace crop_price_temp = . if crop_price_temp==0


forvalues n =1/3 {
merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}

				gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
				bys admin_3 `cropvar': egen n2= total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				gen crop_price = crop_price_admin3 if ten_obs_admin3==1
				drop n2 
		
		* 
		bys admin_2 `cropvar': egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar': egen crop_price_admin2 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar': egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar': egen crop_price_admin_1 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar': egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar': egen crop_price_national = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace crop_price=crop_price_national if ten_obs_n==0
		
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3  `cropvar' crop_price
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3  `cropvar'  using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using) nogen
	gen harvest_value = crop_price * harvest_kg
		
end

**** Same as above, for S2 in UGA


capture program drop valuation_median_crops_noea_S2
program define valuation_median_crops_noea_S2
args hhid plotid cropvar 

merge 1:1 `hhid' `plotid' `cropvar' using "${Temp}\\${temppath}\\_S2harvest_sold_value.dta", keep(master match)	nogen
merge 1:1 `hhid' `plotid' `cropvar' using "${Temp}\\${temppath}\\_S2harvest_sold_kg.dta", keep(master match)	nogen
gen crop_price_temp= harvest_sold_value / harvest_sold_kg 
replace crop_price_temp = . if crop_price_temp==0


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
}
}

		
	
		
		capture confirm variable admin_4
		if !_rc {
				gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
				bys admin_4 `cropvar': egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar': egen crop_price_admin4 = median(crop_price_temp) if crop_price_temp!=0
				gen crop_price = crop_price_admin4 if ten_obs_admin4==1
				drop n2 

				bys admin_3 `cropvar': egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				replace crop_price = crop_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
				else {
				gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
				bys admin_3 `cropvar': egen n2= total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				gen crop_price = crop_price_admin3 if ten_obs_admin3==1
				drop n2 
				} 
		
		
		* 
		bys admin_2 `cropvar': egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar': egen crop_price_admin2 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar': egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar': egen crop_price_admin_1 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar': egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar': egen crop_price_national = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace crop_price=crop_price_national if ten_obs_n==0
		
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3  `cropvar' crop_price
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3  `cropvar'  using "${Temp}\\${temppath}\\_S2harvest_kg.dta", keep(match using) nogen
	gen harvest_value = crop_price * harvest_kg
		
end

********* fertilizer without EA


capture program drop valuation_median_fert_price_noea
program define valuation_median_fert_price_noea 
args hhid name

forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

	gen `name'price = `name'_purchased_value/ `name'_purchased_kg

		
		capture variable admin_4 
		if !_rc {
		gen x1=1 if !mi(`name'price) & `name'price!=0
		bys admin_4 : egen n2=total(x1), missing
		gen ten_obs_admin4_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin4_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin4_`name'
		bys admin_4 : egen  `name'_value_admin4 = median(`name'price) if `name'price>0 
		gen `name'_value=  `name'_value_admin4 if ten_obs_admin4_`name'==1 
		drop n2 
		
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_`name'
		bys admin_3 : egen  `name'_value_admin3 = median(`name'price) if `name'price>0 
		replace `name'_value=  `name'_value_admin3 if ten_obs_admin3_`name'==1 & ten_obs_admin4_`name'==0 
		drop n2 
		} 
		else {
		gen x1=1 if !mi(`name'price) & `name'price!=0
		bys admin_3 : egen n2=total(x1), missing
		gen ten_obs_admin3_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin3_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin3_`name'
		bys admin_3 : egen  `name'_value_admin3 = median(`name'price) if `name'price>0 
		gen `name'_value=  `name'_value_admin3 if ten_obs_admin3_`name'==1
		drop n2
		}
	
		
	***  
		bys admin_2 : egen n2=total(x1), missing
		gen ten_obs_admin2_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin2_`name'
		bys admin_2 : egen  `name'_value_admin2 = median(`name'price) if `name'price>0 
		replace `name'_value=  `name'_value_admin2 if ten_obs_admin2_`name'==1 & ten_obs_admin3_`name'==0 
		drop n2 
		
	***  
		
		bys admin_1 : egen n2=total(x1), missing
		gen ten_obs_admin1_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_admin1_`name'
		bys admin_1 : egen  `name'_value_admin1 = median(`name'price) if `name'price>0
		replace `name'_value=  `name'_value_admin1 if ten_obs_admin1_`name'==1 & ten_obs_admin2_`name'==0 
		drop n2 
		
	***  
		egen n2=total(x1), missing
		gen ten_obs_n_`name'=1 if n2>=10 & !mi(n2)
		replace ten_obs_n_`name'=0 if n2<10 |mi(n2)
		tab ten_obs_n_`name'
		egen  `name'_value_national = median(`name'price) if `name'price>0
		replace `name'_value=  `name'_value_national if ten_obs_n_`name'==1 & ten_obs_admin1_`name'==0 
		drop n2  x1
		

	//gen value_`name'_total = `name'_value * `name'_kg

end 




capture program drop define_MWI_track
program define_MWI_track
args hhid_n1 hhid_n0 wave_n1 wave_n0 year1 year0 dist_var
	
	gen check = 0
	duplicates report `hhid_n1' // = unique identifier
	gen parent_w`wave_n1' = 1
	duplicates tag `hhid_n0', gen(split_w`wave_n0')
	replace parent_w`wave_n1' = 0 if split_w`wave_n0'>0
		// 1) parent_w`wave_n1' if stayed put (less than 200m)
		replace parent_w`wave_n1' = 1 if `dist_var'<=0.2 & split_w`wave_n0'>0
		replace check = 1 if `dist_var'<=0.2 & split_w`wave_n0'>0
		bys `hhid_n0': egen check_parent_w`wave_n1's = total(parent_w`wave_n1')
		fre check_parent_w`wave_n1's // about 70 with multiple parent_w`wave_n1's
		replace parent_w`wave_n1' = 0 if check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0
		replace check = -1 if check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0
			// 2) if not, parent_w`wave_n1' if hh head tracked
			preserve
				// generate datasets of heads
				foreach option in same different  { // sometimes household heads swtich, but are still in the same hh
				use "${Input}\\Malawi\\IHPS `year1'\\hh_mod_b_`year1'", clear 
				merge m:1 `hhid_n1' using "${Input}\\Malawi\\IHPS `year1'\hh_mod_a_filt_`year1'.dta", keep(master match) nogen
				if "`option'" == "same" {
					keep if hh_b04==1 // keep heads
					duplicates report `hhid_n1' // now unique identifier (= one head per hh)
				}	
				keep  `hhid_n1'  `hhid_n0' PID
				tempfile heads_w`wave_n1'
				save `heads_w`wave_n1'', replace
				
				use "${Input}\\Malawi\\IHPS `year0'\hh_mod_b_`year0'.dta", clear 
				merge m:1 `hhid_n0' using "${Input}\\Malawi\\IHPS `year0'\hh_mod_a_filt_`year0'.dta", keep(master match) nogen
				keep if hh_b04==1 // keep heads
				duplicates report PID // now unique identifier (= one head per hh)				
				keep `hhid_n0' PID
				merge 1:1 PID using `heads_w`wave_n1'', keep(match) nogen
				keep `hhid_n1' 
				duplicates drop // multiple heads can originate from a single hh
				tempfile matched_heads_`option'
				save `matched_heads_`option'', replace
				}
			restore
			
			merge 1:1 `hhid_n1' using  `matched_heads_same'
			replace parent_w`wave_n1' = 1 if _merge==3 & check_parent_w`wave_n1's>1 | _merge==3 &  check_parent_w`wave_n1's==0
			replace check = 2 if _merge==3 & check_parent_w`wave_n1's>1 | _merge==3 &  check_parent_w`wave_n1's==0
			drop  _merge
			merge 1:1 `hhid_n1' using  `matched_heads_different'
			replace parent_w`wave_n1' = 1 if _merge==3 & check_parent_w`wave_n1's>1 | _merge==3 &  check_parent_w`wave_n1's==0
			replace check = 3 if _merge==3 & check_parent_w`wave_n1's>1 | _merge==3 &  check_parent_w`wave_n1's==0
			drop check_parent_w`wave_n1's _merge
			bys `hhid_n0': egen check_parent_w`wave_n1's = total(parent_w`wave_n1')
			fre check_parent_w`wave_n1's // some still with no parent_w`wave_n1'
			replace parent_w`wave_n1' = 0 if check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0
			replace check = -2 if check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0
				// 3) if not, parent_w`wave_n1' if household more populated
				preserve
					// calculate size of hh
					use "${Input}\\Malawi\\IHPS `year1'\\hh_mod_a_filt_`year1'.dta", clear 
					merge 1:m `hhid_n1' using "${Input}\\Malawi\\IHPS `year1'\hh_mod_b_`year1'.dta", keep(master match) keepusing(hhsize) nogen
					keep `hhid_n1' hhsize
					duplicates drop
					duplicates report `hhid_n1' // now unique identifier 
					keep `hhid_n1' hhsize
					tempfile size_w`wave_n1'
					save `size_w`wave_n1'', replace
				restore
				merge 1:1 `hhid_n1' using  `size_w`wave_n1''
				bys `hhid_n0': egen max_size = max(hhsize)
				replace parent_w`wave_n1' = 1 if max_size==hhsize & check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0
				replace check = 4 if max_size==hhsize & check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0
				drop check_parent_w`wave_n1's _merge
				bys `hhid_n0': egen check_parent_w`wave_n1's = total(parent_w`wave_n1')
				fre check_parent_w`wave_n1's // some still with no parent_w`wave_n1'
				replace parent_w`wave_n1' = 0 if check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0 // these are all split offs
				replace check = -3 if check_parent_w`wave_n1's>1 | check_parent_w`wave_n1's==0

end

************************************** Sorting fix


capture program drop valuation_median_crops_noea_sort
program define valuation_median_crops_noea_sort 
args hhid  cropvar 

merge 1:1 `hhid'  `cropvar' using "${Temp}\\${temppath}\\harvest_sold_value.dta", keep(master match)	nogen
merge 1:1 `hhid'  `cropvar' using "${Temp}\\${temppath}\\harvest_sold_kg.dta", keep(master match)	nogen
gen crop_price_temp= harvest_sold_value / harvest_sold_kg 
replace crop_price_temp = . if crop_price_temp==0


forvalues n =1/3 {
merge m:1 `hhid' using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}

				gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
				bys admin_3 `cropvar': egen n2= total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				gen crop_price = crop_price_admin3 if ten_obs_admin3==1
				drop n2 
		
		* 
		bys admin_2 `cropvar': egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar': egen crop_price_admin2 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar': egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar': egen crop_price_admin_1 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar': egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar': egen crop_price_national = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace crop_price=crop_price_national if ten_obs_n==0
		
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3  `cropvar' crop_price
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3  `cropvar'  using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using) nogen
	gen harvest_value = crop_price * harvest_kg
		
end


capture program drop valuation_mdn_cr_noeaS2_sort
program define valuation_mdn_cr_noeaS2_sort 
args hhid cropvar 

merge 1:1 `hhid'  `cropvar' using "${Temp}\\${temppath}\\_S2harvest_sold_value.dta", keep(master match)	nogen
merge 1:1 `hhid'  `cropvar' using "${Temp}\\${temppath}\\_S2harvest_sold_kg.dta", keep(master match)	nogen
gen crop_price_temp= harvest_sold_value / harvest_sold_kg 
replace crop_price_temp = . if crop_price_temp==0


forvalues n =1/4 {
capture merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 `hhid' using "${Temp}\\${temppath}\\_S2admin`n'.dta", keep(master match)	nogen
}
}

		
	
		
		capture confirm variable admin_4
		if !_rc {
				gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
				bys admin_4 `cropvar': egen n2= total(n)
				gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin4=0 if n2<10 | mi(n2)
				tab ten_obs_admin4
				bys admin_4 `cropvar': egen crop_price_admin4 = median(crop_price_temp) if crop_price_temp!=0
				gen crop_price = crop_price_admin4 if ten_obs_admin4==1
				drop n2 

				bys admin_3 `cropvar': egen n2=total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				replace crop_price = crop_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
				drop n2 
				}
				else {
				gen n=1 if !mi(crop_price_temp) & crop_price_temp!=0
				bys admin_3 `cropvar': egen n2= total(n)
				gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
				replace ten_obs_admin3=0 if n2<10 | mi(n2)
				tab ten_obs_admin3
				bys admin_3 `cropvar': egen crop_price_admin3 = median(crop_price_temp) if crop_price_temp!=0
				gen crop_price = crop_price_admin3 if ten_obs_admin3==1
				drop n2 
				} 
		
		
		* 
		bys admin_2 `cropvar': egen n2=total(n)
		gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin2=0 if n2<10 | mi(n2)
		tab ten_obs_admin2
		bys admin_2 `cropvar': egen crop_price_admin2 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
		drop n2

		* admin_1 level 
		bys admin_1 `cropvar': egen n2=total(n)
		gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
		replace ten_obs_admin1=0 if n2<10 | mi(n2)
		tab ten_obs_admin1
		bys admin_1 `cropvar': egen crop_price_admin_1 = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
		drop n2
		
		* 
		bys `cropvar': egen n2=total(n)
		gen ten_obs_n=1 if n2>=10 & !mi(n2)
		replace ten_obs_n=0 if n2<10 | mi(n2)
		tab ten_obs_n
		bys `cropvar': egen crop_price_national = median(crop_price_temp) if crop_price_temp!=0
		replace crop_price = crop_price_national if ten_obs_n==1 & ten_obs_admin1==0 
		drop n2 n
		
		replace crop_price=crop_price_national if ten_obs_n==0
		
	** Collapse to the EA - crop level
	keep admin_1 admin_2 admin_3  `cropvar' crop_price
	duplicates drop
	
	** Generating harvest value, using crop price variable
	merge 1:m admin_1 admin_2 admin_3  `cropvar'  using "${Temp}\\${temppath}\\_S2harvest_kg.dta", keep(match using) nogen
	gen harvest_value = crop_price * harvest_kg
		
end