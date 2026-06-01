*------------------------------------------------------------------------------*
*                 Master do-file: active OOPG manuscript workflow              *
/*

    Author:             Arpan
    Last updated by:    Codex

    Notes:
        Runs the active OOPG-only data preparation and analysis pipeline.

*/

*------------------------------------------------------------------------------*
**#							STATA setups       								    
*------------------------------------------------------------------------------*

local dofilename "0_master"
version 17
clear all
macro drop _all
cap log close
set rmsg on	
set more off
cap clear frames

	
*--------------------------------------------------------------------------*
	**# Folder macros (global)
	
	if "`c(username)'" == "Arpan Acharya" {
		global workspace "C:/Users/Arpan Acharya/OneDrive - HERD/Documents/Personal/CIH-project"
	}
	
	if "`c(username)'" == "ACER" {
		global workspace "D:\Projects\CIH-project\consumption"
	}
	
	if "`c(username)'" == "Kapil Pokhrel" {
		global workspace "C:\Users\iprad\OneDrive\Documents\GitHub\NLSSiv_consumption"
	}

	if "$workspace" == "" & fileexists("D:/Projects/CIH-project/consumption/0_master.do") {
		global workspace "D:/Projects/CIH-project/consumption"
	}
	
	**# Sub folder macros (global)
	global data 			"$workspace/1_data"
		gl data_raw 		"$data/1_raw"
		gl data_clean		"$data/2_clean"
		gl data_analysis	"$data/3_analysis"
		gl data_tmp			"$data/4_tmp"
	global prep				"$workspace/2_prep"
	global	analysis		"$workspace/3_analysis"	
	global	log				"$workspace/4_log"
	global	doc				"$workspace/5_documentation"
	global	tab				"$workspace/6_output/main_output"

	cap mkdir "$workspace/6_output"
	cap mkdir "$tab"
	

	*--------------------------------------------------------------------------*
	**# Macros check
	
	** No need to change following codes
	if "$workspace" == "" {
		di as error "Please set up workspace directory"
		exit
	} 
	
	*--------------------------------------------------------------------------*
	**# Ado path
	adopath + "${prep}/ado"
	adopath + "${analysis}/ado"
	
	*--------------------------------------------------------------------------*
	**# Date/time macro (global)
	** Following is useful for hourly log purpose
	local datehour =ustrregexra(regexr("`c(current_date)'"," 20","") +"_"+regexr("`c(current_time)'",":[0-9]+:[0-9]+","")," ","") //saves string in 4Mar23_13 format, equivalent to 4th march 2023, 13 hour.
	
*------------------------------------------------------------------------------*
**#							Setting directory
/*
	Please avoid changing directory frequently during a STATA session. 
	Subsequent do files might be dependent on setting of directory to "workspace"
	folder. This avoids breakage of scripts. In cases where changing directory 
	is unavoidable, do change them back to "workspace" folder.
*/      								    
*------------------------------------------------------------------------------*

cd "$workspace"

*Project: OOPG catastrophic health expenditure analysis (NLSS IV)

do "$prep/1_catastrophic.do"

*Phase 2: Analysis

do "$analysis/01_oopg_che_analysis.do"

/*
Build the manuscript after Stata finishes:
    python 3_analysis\02_build_oopg_manuscript.py
*/

*------------------------------------------------------------------------------*		
**#							End of do file
*------------------------------------------------------------------------------*
	exit
*-----------------------------------------------------------------------
