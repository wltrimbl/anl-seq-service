#!/bin/bash

# ##############################################
# ##############################################
# ##############################################

# 
# SHOCK_functions.sh reusable SHELL functions for SHOCK interaction
# 

# exit on ANY error
set -e

# securely write filename to SHOCK using the JSON information
# note that the env variable AUTH will provide the authentication 
function secure_shock_write {
	local INPUT_JSON=$1
	local FILENAME=$2
	local REAL_FILENAME=$3  # in case we are using a temporary file but want a better name
 	
	# need to check for presence of parameters 
	# if there is no  JSON or FILENAME or the file is not readable
  if [ "${JSON}_x" == "_x" ]  
		then
			echo "$0 function secure_shock_write:: missing JSON parameters"
			exit 1		
	fi
	
	if  [ "${FILENAME}_x" == "_x" ] 
	then
			echo "$0 function secure_shock_write:: missing filename "
			exit 1
	fi		
	
	if [ ! -e "${FILENAME}" ]
	then
		echo "$0 function secure_shock_write:: file unreadable (${FILENAME})"
		exit 1
	fi
	
	
	# compute MD5 checksum for the input file
	# note this will need to be changed when not running on a Mac	
	local FILE_MD5=`md5 -q ${FILENAME}`		
	#FILE_MD5=`md5sum $i` # for Linux

# use either the basename or the third argument as the "filename" in SHOCK	
if [ "${REAL_FILENAME}_x" != "_x" ]
then
	local BASE_FILENAME="${REAL_FILENAME}"
else
	local BASE_FILENAME=$(basename "${FILENAME}")
fi


	# check if file already exists
  #	echo "\n\n\nWE SHOULD DISCUSS ADDING AN MD5 INDEX TO SHOCK <--- Folker says\n\n\n" 
#	local	RETURN_JSON=$(curl --silent -X GET -H "${AUTH}" "${SHOCK_SERVER}/node?querynode&file.name=${FILENAME}&file.checksum.md5=${FILE_MD5}")
#	local LCOUNT=$(echo "${RETURN_JSON}" | jq -r  '{ total_count: .total_count }' |  IFS='}' cut -d: -f2 | tr -d "}{\n\"\ " )
local LCOUNT=0
	if [ ! $LCOUNT -eq 0 ]
	then
		# echo "$0 the file ${FILENAME} is already present in SHOCK, not uploading it"
		echo 1
	else
		# the file does not exist in SHOCK, we continue processing
								
		# 
		local JSON=$(curl --progress-bar -X POST -H "${AUTH}" -F "attributes_str=${INPUT_JSON}" -F "file_name=${BASE_FILENAME}" -F "upload=@${FILENAME}" ${SHOCK_SERVER}/node)
		# parse the return JSON to find error
		local ERROR_STATUS=$(echo ${JSON} | jq -r  '{ error: .error }' |  IFS='}' cut -d: -f2 | tr -d "}{\n\"\ "  )
		# grab nodeid from JSON return
			
		local NODE_ID=$(echo ${JSON} | jq -r ' { nid: .data.id }' |  IFS='}' cut -d: -f2 | tr -d "}{\n\"\ " )
				
		# if there is no return JSON and or we see an error status we report and die
    if [  ${NODE_ID} == "" ]
			then
				echo "can't get a node id (${FILENAME})"
				exit 1		
		fi
		
		# if there is no return JSON and or we see an error status we report and die
    if [  "${JSON}_x" == "_x"  -o   "${ERROR_STATUS}" != "null"  ]
			then
				echo "can't get feedback for upload (${FILENAME}, ${ERROR_STATUS})"
				exit 1		
		fi

		# get MD5 for node ID and validate with local md5
		local NODE_ATTRIBUTES=`curl -s -X GET  -H "${AUTH}" "http://shock.metagenomics.anl.gov/node/${NODE_ID}" `
		local SHOCK_MD5=`echo ${NODE_ATTRIBUTES} | jq -r '{ md5: .data.file.checksum.md5 }' |  IFS='}' cut -d: -f2 | tr -d "}{\n\"\ " `
		
		if [[ ${SHOCK_MD5} == "" ]] # this needs to check for the correct shock response (status 200?)
		then
			echo "$0 could not obtain md5 sum for SHOCK node ${nodeid}"
			exit 1
		fi
		
		
		if [[ ${FILE_MD5} != ${SHOCK_MD5} ]]
				then
					echo "$0 MD5 checksum mismatch for ${FILENAME}, aborting (local-md5:(${FILE_MD5}), remote-md5:(${SHOCK_MD5})"
					# remove uploaded file
					exit 1	
		fi
		
		echo "${NODE_ID}"
	fi
	}
# ##############################################
# ##############################################
# ##############################################
function secure_shock_read {
        local JSON=$1
        local FILENAME=$2

        # need to check for presence of parameters 
        # if there is no  JSON or FILENAME or the file is not readable
  if [  [ "${JSON}_x" == "_x" ]  ]
                then
                        echo "$0 function secure_shock_read:: missing JSON parameters"
                        exit 1
        fi

        if [ [ "${FILENAME}_x" == "_x" ]  ]   # we might want to test if we can create the file .. -o  [ -w "${FILENAME}" ] ]
        then
                echo "$0 function secure_shock_read:: missing filename"
                exit 1
        fi

# now download the file
        res=`curl -H ${AUTH} GET ${SHOCK_SERVER}/node${file}/?download > ${TARGET_PATH}`

# check if we get an error code
        if [[ $res != 0 ]]
                then
                        echo "download failed ($filename)"
                        exit 1
        fi

# get the MD5 to ensure we got the correct file
        JSON=`curl -H ${AUTH} GET ${SHOCK_SERVER}/node/${file} `
        # if there is no return JSON and or we see an error status we report and die
  if [  "${JSON}" == ""  ]
                then
                        echo "can't get feedback for upload (${FILENAME}, ${ERROR_STATUS})"
                        exit 1
        fi

        # grab error status from JSON return    
        SHOCK_MD5=`echo ${JSON} | jq -r '{ md5: .data[].file.checksum.md5 }' `

        # if there is no return JSON and or we see an error status we report and die
  if [  ${SHOCK_MD5} == "" ]
                then
                        echo "can't get an MD5 from SHOCK for (${i})"
                        exit 1
        fi

        # return the remote MD5 fingerprint
        echo ${SHOCK_MD5}
}


# #############################################
# #############################################
