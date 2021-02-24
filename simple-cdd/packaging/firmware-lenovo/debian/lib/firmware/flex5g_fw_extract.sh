#!/bin/bash

PATH_FW_FLEX5G_SUFFIX="LENOVO/82AK"
PATH_FW_VENUS_SUFFIX="venus-5.2"

TXT_UNDERLINE="\033[1m\033[4m"
TXT_NORMAL="\033[0m"

# Don't run as root to avoid doing anything monumentally stupid
if [ ${UID} -eq 0 ]; then
	echo -e "${TXT_UNDERLINE}Error: This script won't run as root.${TXT_NORMAL}"
	exit
fi

###################################################################################################################################################
# Functions
###################################################################################################################################################
function done_failedexit {
	if [ $1 -eq 0 ]; then
		echo "Done"
	else
		echo "Failed"
		exit
	fi
}

function backup_or_delete {
	local response
	local name=$1
	local dir=$2
	local suffix=$3
	read -r -p "Backup existing ${name} firmware (Y/n): " response
	case "$response" in
		[Nn])								# Delete directory
			echo -n "Deleting old ${name} firmware: "
			sudo rm -rf ${dir} &> /dev/null
			done_failedexit $?
			;;
		*)								# Default: backup directory
			echo -n "Moving ${dir} to ${dir}.${suffix}: "
			sudo mv "${dir}" "${dir}.${suffix}" &> /dev/null
			done_failedexit $?
			;;
	esac
}

###################################################################################################################################################
# Main routine
###################################################################################################################################################
echo -n "Creating temp directory: "
TMP_DIR=`mktemp -d -p . -t flex5g_fw_extract.XXXXXX`
if [ ${?} -ne 0 ]; then
	echo "Failed"
	exit
fi
echo "${TMP_DIR}"
cd "${TMP_DIR}" &> /dev/null

CWD=`pwd`
echo

###################################################################################################################################################
# Find the relevant firmware directories, and make a working copy
###################################################################################################################################################
WIN_PART=""									# Windows partition path
# Try to automatically identify windows partition
echo -e "${TXT_UNDERLINE}Getting Windows drivers...${TXT_NORMAL}"
echo "Searching for Windows partition..."
WIN_PART_LABEL="Windows"
WIN_PART_TMP=`/sbin/blkid -L "${WIN_PART_LABEL}"`
if [ $? -eq 0 ]; then
	echo "	Found Windows partition: ${WIN_PART_TMP}"
	WIN_PART=${WIN_PART_TMP}
else
	echo "	Partition not found."
	echo -n "Please enter the path of the Windows partition: "
	read WIN_PART
fi

# Check if partition exists
if [ ! -e ${WIN_PART} ]; then
	echo "Error: Windows partition path does not exist: ${WIN_PART}"
	exit
fi

WIN_MNT=""									# Windows mount path
WIN_MNT_UNMNT=""								# Whether to umount windows mount
# Check if it's already mounted
echo -n "Checking if partition already mounted: "
while read pmount
do
	if [[ "${pmount}" =~ "${WIN_PART} " ]]; then
		WIN_MNT=`echo "${pmount}"|awk '{print $2}'`
	fi
done < /proc/mounts
if [[ ${WIN_MNT} == "" ]]; then
	echo "No"
else
	echo "${WIN_MNT}"
fi

# Windows partition not mounted, so mount
if [[ $WIN_MNT == "" ]]; then
	# Check if /mnt already in use
	echo -n "Checking if /mnt in use: "
	while read pmount
	do
		if [[ "${pmount}" =~ "/mnt " ]]; then
			echo "Yes"
			echo "	Either unmount /mnt, or manually mount Windows filesystem readonly and rerun."
			exit
		fi
	done < /proc/mounts
	echo "No"

	# Mount windows partition
	echo "Mounting Windows partition: ${WIN_PART}"
	sudo mount -o ro -t ntfs ${WIN_PART} /mnt
	if [ $? -eq 0 ]; then
		WIN_MNT_UNMNT='/mnt'						# Flag that we need to umount /mnt
	else
		echo "	Error: Mount failed."
		exit
	fi
fi

# Check mounted readonly
WIN_MNT_STS_RO=""
echo -n "Checking Windows FS is read only: "
while read pmount
do
	if [[ "${pmount}" =~ "${WIN_PART} " ]]; then
		WIN_MNT_STS_RO=`echo "${pmount}"|awk '$4 ~ /^ro,/ {print "true"}; $4 ~ /^rw,/ {print "false"}'`
	fi
done < /proc/mounts
echo "${WIN_MNT_STS_RO}"
if [[ "${WIN_MNT_STS_RO}" != "true" ]]; then
	echo "	Error: Windows filesystem not mounted read-only."
	exit
fi

COPY_ERR=0
# Create directory to copy windows files into
PATH_WIN_DRV="${CWD}/Windows Drivers"
if [ -e "${PATH_WIN_DRV}" ]; then
	echo "Deleting existing copy of Windows drivers..."
	rm -rf "${PATH_WIN_DRV}" &> /dev/null
	done_failedexit $?
fi
echo -n "Creating directory for Windows drivers: "
mkdir "${PATH_WIN_DRV}" &> /dev/null
done_failedexit $?
# Copying Window's driver file
echo -n "Copying Window's driver files: "
# Copy ADSP files
for ADSP_FILE in `find /mnt/Windows/System32/DriverStore/FileRepository/ -name qcadsp8180.mbn`; do
	ADSP_TMP_PATH=`dirname "${ADSP_FILE}"`
	cp -a "${ADSP_TMP_PATH}" "${PATH_WIN_DRV}" &> /dev/null
	if [ $? -ne 0 ]; then
		COPY_ERR=$((COPY_ERR+1))
	fi
done
# Copy CDSP files
for CDSP_FILE in `find /mnt/Windows/System32/DriverStore/FileRepository/ -name qccdsp8180.mbn`; do
	CDSP_TMP_PATH=`dirname "${CDSP_FILE}"`
	cp -a "${CDSP_TMP_PATH}" "${PATH_WIN_DRV}" &> /dev/null
	if [ $? -ne 0 ]; then
		COPY_ERR=$((COPY_ERR+1))
	fi
done
# Copy MPSS files
for MPSS_FILE in `find /mnt/Windows/System32/DriverStore/FileRepository/ -name qcmpss8180_nm.mbn`; do
	MPSS_TMP_PATH=`dirname "${MPSS_FILE}"`
	cp -a "${MPSS_TMP_PATH}" "${PATH_WIN_DRV}" &> /dev/null
	if [ $? -ne 0 ]; then
		COPY_ERR=$((COPY_ERR+1))
	fi
done
# GPU firmware
for GPU_FILE in `find /mnt/Windows/System32/DriverStore/FileRepository/ -name qcdxkmsuc8180.mbn`; do
	GPU_TMP_PATH=`dirname "${GPU_FILE}"`
	cp -a "${GPU_TMP_PATH}" "${PATH_WIN_DRV}" &> /dev/null
	if [ $? -ne 0 ]; then
		COPY_ERR=$((COPY_ERR+1))
	fi
done
# Copy WLAN files
for WLAN_FILE in `find /mnt/Windows/System32/DriverStore/FileRepository/ -name wlanmdsp.mbn`; do
	WLAN_TMP_PATH=`dirname "${WLAN_FILE}"`
	cp -a "${WLAN_TMP_PATH}" "${PATH_WIN_DRV}" &> /dev/null
	if [ $? -ne 0 ]; then
		COPY_ERR=$((COPY_ERR+1))
	fi
done
done_failedexit ${COPY_ERR}

# Umount Windows partition if we mounted it
if [[ "${WIN_MNT_UNMNT}" != "" ]]; then
	echo "Unmounting /mnt."
	sudo umount /mnt
fi

# Process copied files
if [ ${COPY_ERR} -eq 0 ]; then
###################################################################################################################################################
# Select directories with the latest respective firmwares
###################################################################################################################################################
	echo -e "\n${TXT_UNDERLINE}Processing found drivers.${TXT_NORMAL}"
	echo -n "Scanning copied files: "
	# Get path to latest ADSP files
	ADSP_FILE_CUR=`find Windows\ Drivers/ -type f -name qcadsp8180.mbn -exec ls -t {} +|head -n1`
	if [[ "${ADSP_FILE_CUR}" == "" ]]; then
		echo "Failed to find any ADSP files."
		exit
	else
		ADSP_TMP_PATH=`dirname "${ADSP_FILE_CUR}"`
	fi
	# Get path to latest CDSP files
	CDSP_FILE_CUR=`find Windows\ Drivers/ -type f -name qccdsp8180.mbn -exec ls -t {} +|head -n1`
	if [[ "${CDSP_FILE_CUR}" == "" ]]; then
		echo "Failed to find any CDSP files."
		exit
	else
		CDSP_TMP_PATH=`dirname "${CDSP_FILE_CUR}"`
	fi
	# Get path to latest MPSS files
	MPSS_FILE_CUR=`find Windows\ Drivers/ -type f -name qcmpss8180_nm.mbn -exec ls -t {} +|head -n1`
	if [[ "${MPSS_FILE_CUR}" == "" ]]; then
		echo "Failed to find any MPSS files."
		exit
	else
		MPSS_TMP_PATH=`dirname "${MPSS_FILE_CUR}"`
	fi
	# Get path to latest GPU files
	GPU_FILE_CUR=`find Windows\ Drivers/ -type f -name qcdxkmsuc8180.mbn -exec ls -t {} +|head -n1`
	if [[ "${GPU_FILE_CUR}" == "" ]]; then
		echo "Failed to find any GPU FW files."
		exit
	else
		GPU_TMP_PATH=`dirname "${GPU_FILE_CUR}"`
	fi
	# Get path to latest Venus files
	VENUS_FILE_CUR=`find Windows\ Drivers/ -type f -name qcvss8180.mbn -exec ls -t {} +|head -n1`
	if [[ "${VENUS_FILE_CUR}" == "" ]]; then
		echo "Failed to find any Venus FW files."
		exit
	else
		VENUS_TMP_PATH=`dirname "${VENUS_FILE_CUR}"`
	fi
	# Get path to latest WLAN files
	WLAN_FILE_CUR=`find Windows\ Drivers/ -type f -name wlanmdsp.mbn -exec ls -t {} +|head -n1`
	if [[ "${WLAN_FILE_CUR}" == "" ]]; then
		echo "Failed to find any WLAN files."
		exit
	else
		WLAN_TMP_PATH=`dirname "${WLAN_FILE_CUR}"`
	fi
	echo "Done"
	cd "${CWD}"

###################################################################################################################################################
# Qualcomm DSP files
###################################################################################################################################################
	# Create linux dsp directory
	echo -e "\n${TXT_UNDERLINE}Qualcomm DSP firmware${TXT_NORMAL}"
	PATH_FW_FLEX5G="${CWD}/${PATH_FW_FLEX5G_SUFFIX}"
	if [ -e "${PATH_FW_FLEX5G}" ]; then
		echo "Deleting existing copy of linux DSP files..."
		rm -rf "${PATH_FW_FLEX5G}" &> /dev/null
		done_failedexit $?
	fi
	echo -n "Creating directory for linux DSP files: "
	mkdir -p "${PATH_FW_FLEX5G}" &> /dev/null
	done_failedexit $?
	echo -n "Copying linux ADSP files: "
	cp -a "${ADSP_TMP_PATH}"/*.mbn "${PATH_FW_FLEX5G}" &> /dev/null
	done_failedexit $?
	echo -n "Copying linux CDSP files: "
	cp -a "${CDSP_TMP_PATH}"/*.mbn "${PATH_FW_FLEX5G}" &> /dev/null
	done_failedexit $?
	echo -n "Copying linux MPSS files: "
	cp -a "${MPSS_TMP_PATH}"/*.mbn "${PATH_FW_FLEX5G}" &> /dev/null
	done_failedexit $?
	echo -n "Copying linux GPU FW files: "
	cp -a "${GPU_TMP_PATH}"/*.mbn "${PATH_FW_FLEX5G}" &> /dev/null
	done_failedexit $?
	echo -n "Copying linux WLAN files: "
	cp -a "${WLAN_TMP_PATH}"/*.mbn "${PATH_FW_FLEX5G}" &> /dev/null
	done_failedexit $?
	cd "${PATH_FW_FLEX5G}"
	cd "${CWD}"

###################################################################################################################################################
# Qualcomm Venus DSP files
###################################################################################################################################################
	echo -e "\n${TXT_UNDERLINE}Qualcomm Venus DSP firmware${TXT_NORMAL}"
	PATH_FW_VENUS="${CWD}/${PATH_FW_VENUS_SUFFIX}"
	echo -n "Creating directory for linux Venus DSP files: "
	mkdir -p "${PATH_FW_VENUS}" &> /dev/null
	done_failedexit $?
	echo -n "Copying Venus firmware from tmp path: "
	cp -a "${VENUS_TMP_PATH}/qcvss8180.mbn" "${PATH_FW_VENUS}" &> /dev/null
	done_failedexit $?
	echo -n "Extracting Venus firmware files: "
	python2 "/lib/firmware/pil-splitter.py" "${PATH_FW_VENUS}/qcvss8180.mbn" "${PATH_FW_VENUS}/venus" &> /dev/null
	done_failedexit $?

###################################################################################################################################################
# INSTALL
###################################################################################################################################################
	echo -e "\n${TXT_UNDERLINE}Install firmware...${TXT_NORMAL}"
	BKUP_DATETIME=`date +'%Y%m%dT%H%M%S'`
	PATH_LIBFW_QCOM="/lib/firmware/qcom"

	echo -n "Copying new Qualcomm DSP firmware: "
	if [[ `dirname ${PATH_FW_FLEX5G_SUFFIX}` == "." ]]; then		# If multi level directory structure
		PATH_FW_COPY=${PATH_FW_FLEX5G_SUFFIX}
	else
		PATH_FW_COPY=`dirname ${PATH_FW_FLEX5G_SUFFIX}`			# Strip second level
	fi
	sudo cp -r "${PATH_FW_COPY}" "${PATH_LIBFW_QCOM}" &> /dev/null
	done_failedexit $?

	# Copy Venus DSP firmware files
	if [ -e "${PATH_LIBFW_QCOM}/${PATH_FW_VENUS_SUFFIX}" ]; then
		backup_or_delete "Qualcomm Venus DSP" "${PATH_LIBFW_QCOM}/${PATH_FW_VENUS_SUFFIX}" "${BKUP_DATETIME}"
	fi
	echo -n "Copying new Qualcomm Venus DSP firmware: "
	if [[ `dirname ${PATH_FW_VENUS_SUFFIX}` == "." ]]; then			# If multi level directory structure
		PATH_FW_COPY=${PATH_FW_VENUS_SUFFIX}
	else
		PATH_FW_COPY=`dirname ${PATH_FW_VENUS_SUFFIX}`			# Strip second level
	fi
	sudo cp -r "${PATH_FW_COPY}" "${PATH_LIBFW_QCOM}" &> /dev/null
	done_failedexit $?

	# Reset firmware owner/group permissions
	sudo chown -R root:root "${PATH_LIBFW_QCOM}"
	sudo find "${PATH_LIBFW_QCOM}" -type f -exec chmod 0644 {} \;
fi
