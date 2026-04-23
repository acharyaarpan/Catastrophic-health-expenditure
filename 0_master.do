*------------------------------------------------------------------------------*
*           		 This is the templet master do file				           *
/*

	Author:				Arpan
	Date created:		20th April 2026
	Date updated:		20th April 2026
	Last updated by:	Arpan

	Notes:
						This is a templet master do file.
			
	Dependencies:		This do file is not dependendent on any other do files.

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
	global	tab				"$workspace/6_output"
	

	*--------------------------------------------------------------------------*
	**# Macros check
	
	** No need to change following codes
	if "$workspace" == "" {
		di as error "Please set up workspace directory"
		exit
	} 
	
	*--------------------------------------------------------------------------*
	**# Packages check
	
	** Setting ado path
	adopath + "${prep}/ado"
	adopath + "${analysis}/ado"
	
	** List all required packages below as local. !! No SPACES in package name !!
	local packages "estout texify"
	
	foreach package in `packages' {
		cap which `package'
		if _rc {
			if "`package'"=="estout" {
				** Steps to install specific package
				ssc install estout
			}
			if "`package'"=="texify" {
				** Steps to install specific package
				ssc install texify
			}
			else {
				di as error "Need to install following package: `package'"
				search `package'
			}
		}
	}
	
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

*Project1: Working for cleaning consumption (NLSS IV)

doedit "$prep/1_catastrophic.do"

*Phase 2: Analysis

doedit "$analysis/0_descriptive.do"
doedit "$analysis/1_logit_che.do"


*Project2 : Also cleaning health related expenditure for something else
/*
doedit "$prep/6_health_exp.do"
*/

*------------------------------------------------------------------------------*		
**#							End of do file
*------------------------------------------------------------------------------*
	exit
*-----------------------------------------------------------------------