set trace off
set tracedepth 2

cap prog drop stata2r_rf
prog def stata2r_rf

syntax anything , GENerate(string asis) [seed(integer 42)] ///
	[rpath(string asis)] // for windows
	
* Setup

	unab anything : `anything'
	local thedepvar : word 1 of `anything'
	local rhsvars = subinstr("`anything'","`thedepvar' ","",1)
	local rhsvars = subinstr("`rhsvars'"," "," + ",.)

	gen X_FAKEDV = `thedepvar'
	local thedepvar "X_FAKEDV ~ "
	gen X_FAKEID = _n

	preserve
		keep `anything' X_FAKEID X_FAKEDV

// Export dataset

	quietly: cap saveold "testout.dta" , replace v(12)
		if _rc!=0 saveold "testout.dta" , replace
	quietly: file close _all
	 
// Write R Code

	quietly: file open rcode using  test.R, write replace
	quietly: file write rcode ///
		`"setwd("`c(pwd)'")"' _newline ///
		`"set.seed(`seed')"' _newline ///
		`"if(!"randomForests" %in% installed.packages()) install.packages("randomForest",repos="http://cran.us.r-project.org")"' _newline ///
		`"library(foreign)"' _newline ///
		`"library(randomForest)"' _newline ///	
		`"data<-data.frame(read.dta("testout.dta"))"' _newline ///
		`"rf.output <- randomForest(`thedepvar' `rhsvars', data = data)"' _newline ///
		`"data[["`generate'"]] <- rf.output[["predicted"]]"' _newline ///
		`"write.dta(data,"testin.dta")"'
	quietly: file close rcode
	 
// Run R

	if "`c(os)'" == "MacOSX" {
		qui shell /Library/Frameworks/R.framework/Resources/bin/R --vanilla <test.R
		}
	else {
		qui shell "`rpath'" CMD BATCH test.R
		}

// Read Revised Data Back to Stata

	qui use testin.dta, clear
	su `generate' 
	
	qui keep `generate' X_FAKEID
	
	tempfile newdata
		qui save `newdata' , replace
		
	restore
		
		qui merge 1:1 X_FAKEID using `newdata' , nogen update replace
		drop X_FAKEID X_FAKEDV





// Clean up
rm testout.dta
rm testin.dta
rm test.R

end

* Demo
-
sysuse auto, clear

stata2r_rf mpg foreign price  trunk, gen(predicted_price) seed(474747)

* stata2r_rf price mpg trunk, gen(predicted_price) seed(474747) rpath(C:\Program Files\R\R-2.15.1\bin\x64\R.exe)
 
 

* Have a lovely day!

