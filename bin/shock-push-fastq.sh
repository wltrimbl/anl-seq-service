#!/bin/bash

# # this script pushes a run folder to shock, creating 3 different subsets
# 
# a) entire run folder (minus fastq files and minus thumbnails); a single tar.gz file ${RUN_FOLDER_NAME}.tar.gz
# b) multiple fastq files and SAV.tar.fz file are stored (the SAV file includes the Samplesheets and other documents required for the Illumina SAV tool)
# c) thumbnail files (a single tar.gz file): example: ${RUN_FOLDER_NAME}.tumbnails.tar.tgz
# all 3 files are required to obtain the entire RUN_Folder (note the SAV files are stored twice)
# #############################################
# #############################################

# #############################################

# constants
SHOCK_SERVER="http://shock.metagenomics.anl.gov"
TMP_TAR_FILE="/var/tmp/temporary-tar-file-shock-client.$$.tar.gz"
rm -f ${TMP_TAR_FILE} # ensure we are not re-using an old tar file

# make sure all files are deleted if we exit prematurely or die
function clean_up {

	# Perform program exit housekeeping
	rm -f ${TMP_TAR_FILE}
	exit
}
trap clean_up SIGHUP SIGINT SIGTERM

# ##############################
# ##############################
# include a library of basic functions for SHOCK interaction
INSTALL_DIR=`dirname $0`
source ${INSTALL_DIR}/SHOCK_functions.sh

# ##############################
# ##############################
# we could create a file with project wide defaults to set for all scripts
INSTALL_DIR=`dirname $0`
if [ -e "${INSTALL_DIR}/PROJECT_settings.sh" ]
then
	source ${INSTALL_DIR}/PROJECT_settings.sh
fi

# usage info 
function usage () { 
	echo "Usage: shock-push.sh [-h <help>] [-d] -r <run folder> "
	echo " -d  delete files after upload"
 }


# get options
while getopts hdr: option; do
    case "${option}"
        in
		h) HELP=1;;
		r) RUN_FOLDER=${OPTARG};;
		d) DELETE=1;;
		*)
		usage
		;;
    esac
done

# make sure the required options are present
if [[ -z ${RUN_FOLDER} ]]
then
	usage
	exit 1
fi

# ensire the run_folder is present
if [  ! -d ${RUN_FOLDER} ] 
then
	echo "$0 ${RUN_FOLDER} not found"
	usage
	exit 1
fi

# check for presence of RTAComplete.txt
if [ ! -e ${RUN_FOLDER}/RTAComplete.txt ] 
then
	echo "$0 ${RUN_FOLDER} is incomplete, RTAComplete.txt is not present. Aborting"
	exit 1
fi	

# exit on any error
set -e 

# strip the prefix of the run folder to get the name 
RUN_FOLDER_NAME=`basename ${RUN_FOLDER}`

# fastq files
cd ${RUN_FOLDER}
FASTQ_FILES=`find ./ -name \*.fastq\*`

for i in ${FASTQ_FILES}
do
	# use Illumina directory structure to extract group (e.g. unaligned), project and sample info.
	# ./unaligned/Project_AR3/Sample_AR314/AR314_GGAACT_L003_R1_001.fastq.gz  [sample $i]
	#    group        project      sample    name
	group=`echo $i | awk -F/  '{print $2 }' `
	project=`echo $i | awk -F/  '{print $3 }' | sed s/Project_//g`
	sample=`echo $i | awk -F/  '{print $4 }' | sed s/Sample_//g`
	file=`echo $i | awk -F/  '{print $5 }' `

	# project_id, owner and type are indexed in SHOCK
	JSON="	{  \
\"type\" : \"run-folder-archive-fastq\" , \
\"project_id\" : \"${RUN_FOLDER_NAME}\" ,\
\"owner\" : \"${OWNER}\", \
\"group\" : \"$group\", \
\"project\" : \"$project\",\
\"sample\" : \"$sample\",\
\"name\" : \"$file\"\
}" 

	echo "uploading ${i} .. "
	NODE_ID=$(secure_shock_write "${JSON}" "${i}" )

	# check if the NODE_ID already exists 
	if [ "${NODE_ID}" == "1" ]
		then
				echo "skipped (file already exists)."
			else
				echo "done."
	fi
done
# we are done with all FASTQ files

# find SAV files now and tar them
# from documentation SAV files are:  RunInfo.xml, runParameters.xml, SampleSheet.csv, InterOp  (directory)
SAV_FILES="RunInfo.xml runParameters.xml SampleSheet.csv InterOp/*"

return=`tar cfz ${TMP_TAR_FILE} ${SAV_FILES} `
# ensure tar worked
if [ ! $? -eq 0 ]
then
	echo "$0 tar command failed [ $? ] "
	rm -f ${TMP_TAR_FILE}
fi

JSON="{\
\"type\" : \"run-folder-archive-sav\",\
\"name\" : \"${RUN_FOLDER_NAME}.sav.tar.gz\",\
\"project_id\" : \"${RUN_FOLDER_NAME}\",\
\"owner\" : \"${OWNER}\"\
}" 

REAL_FILE_NAME="${RUN_FOLDER_NAME}.sav.tar.gz"

echo "uploading SAV-TAR-Archive .. "
NODE_ID=$(secure_shock_write "${JSON}" "${TMP_TAR_FILE}" "${REAL_FILE_NAME}" )
# check if the NODE_ID already exists 
if [ "${NODE_ID}" == "1" ]
	then
			echo "skipped (file already exists)."
		else
			echo "done."
fi


if [ -n "${DELETE}"  ]
	then
		echo "removing FASTQ + SAV files in 5 seconds [time for CTRL-C now...]"
		sleep 5
		rm -rf ${SAV_FILES} ${FASTQ_FILES}
	fi

# cleanup
exit 1
rm -f ${TMP_TAR_FILE}
 







