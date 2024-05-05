#!/bin/bash

check(){
	#Syntaxfehler Titel
	AllFalseTitleRow=$(cat literatur.bib | grep -n "\<title\>[[:space:]]*[=][[:space:]]*[^\"][{]" | cut -d ':' -f 1)
	for titleRow in $AllFalseTitleRow
	do
		title=$(awk -v i=$titleRow 'NR==i' literatur.bib)
		echo "False title ($titleRow): $title"
	done

	echo Checking for too long lines...
	
	#Syntaxmeldung Zeilenlänge
	lineCount=$(cat literatur.bib | wc -l)
	for (( i=1; i<=lineCount; i++ ))
	do
		Row=$i
		count=$(awk -v b=$Row 'NR==b' literatur.bib | wc -c)
		if [ $count -gt 81 ]
             	then
                     line=$(awk -v b=$Row 'NR==b' literatur.bib)
                       echo "Long line ($Row): $line"
              	fi
	done

	#Fragwürdiges Jahr
	currentYear=$(date +'%Y')
	AllYearRow=$(cat literatur.bib | grep -n "year.*=.*[[:digit:]]\{4\}" | cut -d ':' -f 1)
	for yearRow in $AllYearRow
	do
		year=$(awk -v i=$yearRow 'NR==i' literatur.bib | cut -d '=' -f 2 | cut -d ',' -f 1)
		if [ $year -lt 1500 ] || [ $year -gt $currentYear ]
		then
			echo "Questionable year ($yearRow): $(awk -v i=$yearRow 'NR==i' literatur.bib)"
		fi
		
		quoteRow=$yearRow
		while [ "$(awk -v i=$quoteRow 'NR==i' literatur.bib)" != "" ]
		do
			((quoteRow=quoteRow-1))
		done
		((quoteRow=quoteRow+1))
		
		quoteYear=$(awk -v i=$quoteRow 'NR==i' literatur.bib | cut -d ':' -f 2)
		if [ $quoteYear != $year ]
		then
			echo "Different years ($yearRow): $(awk -v i=$yearRow 'NR==i' literatur.bib) Zitierschlüssel: $(awk -v i=$quoteRow 'NR==i' literatur.bib)"
		fi
	done

	#Syntaxfehler Zitierschlüssel
	AllQuoteRow=$(cat literatur.bib | grep -n "[@][[:alpha:]]*[{]" | cut -d ':' -f 1)
	for quoteRow in $AllQuoteRow
        do
                quote=$(awk -v i=$quoteRow 'NR==i' literatur.bib)
		year=$(echo $quote | cut -d ':' -f2)
		yearRow=$quoteRow
		#Für Jahr xxxx
		if [ $year == "xxxx" ]
		then
			#Korrektheit Syntax
			if ! [[ $quote  = $(echo $quote | grep -o "[@][[:alpha:]*[-]*]*[{][[:alpha:]*[-]*]*[:]\([[:digit:]]\{4\}\|[x]\{4\}\)[:]\([[:alpha:]*[:digit:]*[-]*[\+]*[.]*[_]*]*\)*[,]*") ]] 
			then
				echo "False quote - syntax incorrect ($quoteRow): $quote"
			fi
			#Überprüfung Jahr
			while [ "$(awk -v i=$yearRow 'NR==i' literatur.bib)" != "" ]
			do
				((yearRow=yearRow+1))
				if ! [[ $(awk -v i=$yearRow 'NR==i' literatur.bib | grep -o "year.*") = "" ]]
				then
					yearEintrag=$(awk -v i=$yearRow 'NR==i' literatur.bib | cut -d '=' -f 2 | cut -d ',' -f 1)
					if [ $yearEintrag != "xxxx" ]
					then
						echo "False quote - year not matching ($quoteRow): $quote"
					fi
				fi
			done
		#für Jahreszahl
		else
			#Korrektheit Syntax
			if ! [[ $quote  = $(echo $quote | grep -o "[@][[:alpha:]*[-]*]*[{][[:alpha:]*[-]*]*[:]\([[:digit:]]\{4\}\|[x]\{4\}\)[:]\([[:alpha:]*[:digit:]*[-]*[\+]*[.]*[_]*]*\)*[,]*") ]] || [ $year -lt 1500 ] || [ $year -gt $(date +'%Y') ]
			then
				echo "False quote - syntax incorrect ($quoteRow): $quote"	
			fi
			#Überprüfung Jahr
			while [ "$(awk -v i=$yearRow 'NR==i' literatur.bib)" != "" ]
                        do
                                ((yearRow=yearRow+1))
				if ! [[ $(awk -v i=$yearRow 'NR==i' literatur.bib | grep -o "year.*") = "" ]]
                                then
                                        yearEintrag=$(awk -v i=$yearRow 'NR==i' literatur.bib | cut -d '=' -f 2 | cut -d ',' -f 1)
                                        if ! [ $yearEintrag -eq $year &>/dev/null ]
                                        then
                                                echo "False quote - year not matching ($quoteRow): $quote"
                                        fi
                                fi
                        done
		fi
	done

	#Systaxfehler ","
	AllBracRow=$(cat literatur.bib | grep -x -n "}" | cut -d ':' -f 1)
	for bracRow in $AllBracRow
	do
		((bracRow=$bracRow-1))
		string=$(awk -v i=$bracRow 'NR==i' literatur.bib)
		if [[ $string =~ .*}, ]]
		then
			echo "False comma ($bracRow): $string"
		fi
	done

	#Fehler URL
	AllUrlRow=$(cat literatur.bib | grep -n "url =" | cut -d ':' -f 1)
	for urlRow in $AllUrlRow
	do
		url=$(echo $(awk -v i=$urlRow 'NR==i' literatur.bib | grep -o "{.*}") | cut -d '{' -f 2 |  cut -d '}' -f 1)
		wget -q --spider --no-check-certificate $url &>/dev/null
		status=$(echo $?)
		if [ $status != 0 ]
		then
			echo "Unreachable url ($urlRow): $url"
		fi
	done
	
	return 0;
}

stat(){
	#Anzahl Literatureintraege
	totalCount=$(cat literatur.bib | grep -o "^@" | wc -l) 
	echo Anzahl aller Literatureintraege: $totalCount

	echo ----------

	#Anzahl Eintraege je Kategorie
	AllCategory=$(cat literatur.bib | grep -o "@.*[{].*" | cut -d '{' -f 1 | cut -c2- | sort -u )
	for category in $AllCategory
	do
		countPerCategory=$(cat literatur.bib | grep "@$category{" | wc -l)
		echo "$category: $countPerCategory"
	done

	echo ----------

 	#Anzahl Eintraege pro Jahr
	AllYear=$(cat literatur.bib | grep "year =.*" | cut -d '=' -f2 | grep -o "[[:digit:]]\{4\}"| sort -u)
	for year in $AllYear
	do
		countPerYear=$(cat literatur.bib | grep "year =.*" | grep -o "$year" | wc -l)
		echo "$year: $countPerYear"
	done

	return 0;
}

search(){
	startYear=$(echo $1 | cut -d '-' -f1)
	endYear=$(echo $1 | cut -d '-' -f2)
	if ! [[ $startYear =~ ^[0-9][0-9][0-9][0-9] ]]
	then
		return 2
	fi
	if ! [[ $endYear =~ ^[0-9][0-9][0-9][0-9] ]]
        then
                return 2
        fi
	if [ $startYear -gt $endYear ]
	then
		return 1
	fi

	echo "Search form: $startYear to $endYear:"
	for (( year=startYear; year<=endYear; year++ ))
	do
		AllLine=$(cat literatur.bib | grep -n "year.*$year" | cut -d ':' -f1)
		if [[ $AllLine == "" ]]
		then
			echo "Keine Treffer für das Jahr $year."
		fi
		for line in $AllLine
		do
			upperLine=$line
			lowerLine=$line
			while [ "$(awk -v i=$upperLine 'NR==i' literatur.bib)" != "" ]
			do
			        ((upperLine=upperLine-1))
			done
			while [ "$(awk -v i=$lowerLine 'NR==i' literatur.bib)" != "" ]
                        do
				((lowerLine=lowerLine+1))
                        done
			dif=$((lowerLine-upperLine))
			echo "$(head -n $lowerLine literatur.bib | tail -n $dif)"
		done
	done
	
	return 0;
}

#Inputcheck
if [ $# != 1 ] && [ $# != 2 ]
then
	echo Usage: $0 check/stat/search
	exit 1
fi

if [ $1 = "check" ] && [ $# = 1 ]
then
	check
else
	if [ $1 = "stat" ] && [ $# = 1 ]
	then
		stat
	else
		if [ $1 = "search" ] && [ $# = 2 ]
		then
			search $2
			ret=$?
			if [ $ret -eq 1 ]
			then
				echo Jahreszahlen in falscher Reihenfolge
			fi
			if [ $ret -eq 2 ]
                        then
                                echo Jahreszahlen ungültig
                        fi
		else
			echo Usage: search + year-year
        		exit 1
		fi
	fi
fi

exit 0
