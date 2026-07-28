/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: This code harmonises LSMS-ISA data						          *
 * Date: December 2023                                                            *
 * -------------------------------------------------------------------------------*
*/


cap log close _all
clear all
clear matrix
macro drop _all
set more off
set maxvar 10000
set type double

set seed 12345

** Global Pathways
global Do = "...[to be filled] ....."
global Input = "...[to be filled] ....."
global Temp = "...[to be filled] ....."
global Final = "...[to be filled] ....."

adopath ++ "${Do}\ado"


*** download requisite packages


foreach pkg in 			distinct	egenmore		extremes	fre	insob		lgraph	mdesc	mmerge		myaxis	mypkg		palettes	psmatch2		rmse			spmap		wbopendata		winsor2	xtgcause	zscore06 {
capture which `pkg'
if _rc == 111 {
ssc install `pkg'
}
}




*** run all

do "${Do}\\programs.do"

do "${Do}\Cleaning_code\ETH_ESS1.do"
do "${Do}\Cleaning_code\ETH_ESS2.do"
do "${Do}\Cleaning_code\ETH_ESS3.do"
do "${Do}\Cleaning_code\ETH_ESS4.do"
do "${Do}\Cleaning_code\ETH_ESS5.do"
do "${Do}\Cleaning_code\Append_ETH.do"

do "${Do}\Cleaning_code\MWI_IHPS1.do"
do "${Do}\Cleaning_code\MWI_IHPS2.do"
do "${Do}\Cleaning_code\MWI_IHPS3.do"
do "${Do}\Cleaning_code\MWI_IHPS4.do"
do "${Do}\Cleaning_code\Append_MWI.do"

do "${Do}\Cleaning_code\MLI_EACI1.do"
do "${Do}\Cleaning_code\MLI_EACI2.do"
do "${Do}\Cleaning_code\Append_MLI.do"

do "${Do}\Cleaning_code\NER_ECVMA1.do"
do "${Do}\Cleaning_code\NER_ECVMA2.do"
do "${Do}\Cleaning_code\Append_NER.do"

do "${Do}\Cleaning_code\NGA_GHS1.do"
do "${Do}\Cleaning_code\NGA_GHS2.do"
do "${Do}\Cleaning_code\NGA_GHS3.do"
do "${Do}\Cleaning_code\NGA_GHS4.do"
do "${Do}\Cleaning_code\NGA_GHS5.do"
do "${Do}\Cleaning_code\Append_NGA.do"

do "${Do}\Cleaning_code\TZA_NPS1.do"
do "${Do}\Cleaning_code\TZA_NPS2.do"
do "${Do}\Cleaning_code\TZA_NPS3.do"
do "${Do}\Cleaning_code\TZA_NPS4.do"
do "${Do}\Cleaning_code\TZA_NPS4_refresh.do"
do "${Do}\Cleaning_code\TZA_NPS5.do"
do "${Do}\Cleaning_code\TZA_NPS5_refresh.do"
do "${Do}\Cleaning_code\Append_TZA.do"

do "${Do}\Cleaning_code\UGA_UNPS1.do"
do "${Do}\Cleaning_code\UGA_UNPS2.do"
do "${Do}\Cleaning_code\UGA_UNPS3.do"
do "${Do}\Cleaning_code\UGA_UNPS4.do"
do "${Do}\Cleaning_code\UGA_UNPS5.do"
do "${Do}\Cleaning_code\UGA_UNPS7.do"
do "${Do}\Cleaning_code\UGA_UNPS8.do"

do "${Do}\Cleaning_code\UGA_UNPS1_S2.do"
do "${Do}\Cleaning_code\UGA_UNPS2_S2.do"
do "${Do}\Cleaning_code\UGA_UNPS3_S2.do"
do "${Do}\Cleaning_code\UGA_UNPS4_S2.do"
do "${Do}\Cleaning_code\UGA_UNPS5_S2.do"
do "${Do}\Cleaning_code\UGA_UNPS7_S2.do"
do "${Do}\Cleaning_code\UGA_UNPS8_S2.do"
do "${Do}\Cleaning_code\Append_UGA.do"

do "${Do}\Cleaning_code\Append_ALL.do"




