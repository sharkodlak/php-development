#!/bin/bash

declare -a iniSections

function parseIni {
	local notAssigned=1
	while IFS='=' read variableName value
	do
		if [[ $variableName == \[*]* ]]; then
			local sectionIndex=${#iniSections[*]}
			section=[$sectionIndex]
			iniSections[$sectionIndex]=$(sed -r 's/\[(.+)\].*/\1/' <<< "$variableName")
		elif [[ $value && ! $value =~ ^[[:space:]]*\# ]]; then
			printf -v $variableName$section $value
			notAssigned=0
		fi
	done <<< "$1"
	if [[ $notAssigned == 1 ]]; then
		echo "Empty INI" 1>&2
	fi
	return $notAssigned
}

function parseIniFile {
	local content=$(cat "$1")
	parseIni "$content"
	local result=$?
	if [[ $result != 0 ]]; then
		echo "Error #$result in INI file $1" 1>&2
	fi
	return $result
}

function getIniSectionIndex {
	local i
	for i in "${!iniSections[@]}"; do
		if [[ "$1" == "${iniSections[$i]}" ]]; then
			echo $i;
			return 0
		fi
	done
	return 1
}
