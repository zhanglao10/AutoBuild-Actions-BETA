#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions

GET_TARGET_INFO() {
	Diy_Core
	Home="${GITHUB_WORKSPACE}/openwrt"
	[ -f "${GITHUB_WORKSPACE}/Openwrt.info" ] && . ${GITHUB_WORKSPACE}/Openwrt.info
	[[ "${Short_Firmware_Date}" == true ]] && Compile_Date="$(echo ${Compile_Date} | cut -c1-8)"
	Owner_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100)"
	Source_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${Home}/.git/config | cut -c8-100)"
	Source_Owner="$(echo "${Source_Repo}" | egrep -o "[a-z]+" | awk 'NR==4')"
	Current_Branch="$(git branch | sed 's/* //g')"
	AB_Firmware_Info=package/base-files/files/etc/openwrt_info
	[[ ! ${Current_Branch} == master ]] && {
		Current_Branch="$(echo ${Current_Branch} | egrep -o "[0-9]+.[0-9]+")"
		Openwrt_Version_="R${Current_Branch}-"
	} || {
		Openwrt_Version_="R18.06-"
	}
	case ${Source_Owner} in
	coolsnowwolf)
		Version_File=package/lean/default-settings/files/zzz-default-settings
		Old_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		Openwrt_Version="${Old_Version}-${Compile_Date}"
	;;
	immortalwrt)
		Version_File=package/base-files/files/etc/openwrt_release
		Openwrt_Version="${Openwrt_Version_}${Compile_Date}"
	;;
	*)
		Openwrt_Version="${Openwrt_Version_}${Compile_Date}"
	;;
	esac
	while [[ -z "${x86_Test}" ]]
	do
		x86_Test="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/CONFIG_TARGET_(.*)_DEVICE_(.*)=y/\1/')"
		[[ -n "${x86_Test}" ]] && break
		x86_Test="$(egrep -o "CONFIG_TARGET.*Generic=y" .config | sed -r 's/CONFIG_TARGET_(.*)_Generic=y/\1/')"
		[[ -z "${x86_Test}" ]] && TIME "Can not obtain the TARGET_PROFILE !" && exit 1
	done
	[[ "${x86_Test}" == "x86_64" ]] && {
		TARGET_PROFILE="x86_64"
	} || {
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	}
	[[ -z "${TARGET_PROFILE}" ]] && TARGET_PROFILE="${Default_Device}"
	[[ "${TARGET_PROFILE}" == x86_64 ]] && {
		[[ "$(cat ${Home}/.config)" =~ "CONFIG_TARGET_IMAGES_GZIP=y" ]] && {
			Firmware_Type=img.gz
		} || {
			Firmware_Type=img
		}
	}
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)"
	case ${TARGET_BOARD} in
	ramips | reltek | ipq40xx | ath79)
		Firmware_Type=bin
	;;
	rockchip)
		Firmware_Type=img.gz
	;;
	esac
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)"
	
	echo "Firmware_Type=${Firmware_Type}" > ${Home}/TARGET_INFO
	echo "TARGET_PROFILE=${TARGET_PROFILE}" >> ${Home}/TARGET_INFO
	echo "Openwrt_Version=${Openwrt_Version}" >> ${Home}/TARGET_INFO
	echo "Source_Owner=${Source_Owner}" >> ${Home}/TARGET_INFO
	echo "TARGET_BOARD=${TARGET_BOARD}" >> ${Home}/TARGET_INFO
	echo "TARGET_SUBTARGET=${TARGET_SUBTARGET}" >> ${Home}/TARGET_INFO
	echo "Home=${Home}" >> ${Home}/TARGET_INFO
	echo "Current_Branch=${Current_Branch}" >> ${Home}/TARGET_INFO
	
	echo "${Openwrt_Version}" > ${AB_Firmware_Info}
	echo "${Owner_Repo}" >> ${AB_Firmware_Info}
	echo "${TARGET_PROFILE}" >> ${AB_Firmware_Info}
	echo "${Firmware_Type}" >> ${AB_Firmware_Info}
	
	echo "Author: ${Author}"
	echo "Author Github: ${Owner_Repo}"
	echo "Firmware Version: ${Openwrt_Version}"
	echo "Firmware Type: ${Firmware_Type}"
	echo "Source: ${Source_Repo}"
	echo "Source Author: ${Source_Owner}"
	echo "Source Branch: ${Current_Branch}"
	echo "TARGET_PROFILE: ${TARGET_PROFILE}"
	echo "TARGET_BOARD: ${TARGET_BOARD}"
	echo "TARGET_SUBTARGET: ${TARGET_SUBTARGET}"
	
	TIME "[Preload Info] All done !"
}

Firmware-Diy_Base() {
	GET_TARGET_INFO
	Auto_ExtraPackages
	chmod +x -R ${GITHUB_WORKSPACE}/Scripts
	chmod +x -R ${GITHUB_WORKSPACE}/CustomFiles
	chmod +x -R ${GITHUB_WORKSPACE}/CustomPackages
	[[ "${INCLUDE_AutoBuild_Tools}" == true ]] && {
		Replace_File Scripts/AutoBuild_Tools.sh package/base-files/files/bin
	}
	[[ "${INCLUDE_AutoUpdate}" == true ]] && {
		ExtraPackages git lean luci-app-autoupdate https://github.com/Hyy2001X main
		Replace_File Scripts/AutoUpdate.sh package/base-files/files/bin
	}
	[[ "${INCLUDE_Theme_Argon}" == true ]] && {
		case ${Source_Owner} in
		coolsnowwolf)
				ExtraPackages git lean luci-theme-argon https://github.com/jerrykuku 18.06
		;;
		*)
			case ${Current_Branch} in
			19.07)
				ExtraPackages git other luci-theme-argon https://github.com/jerrykuku v2.2.5
			;;
			21.02)
				ExtraPackages git other luci-theme-argon https://github.com/jerrykuku
			;;
			18.06)
				ExtraPackages git other luci-theme-argon https://github.com/jerrykuku 18.06
			;;
			*)
				TIME "[ERROR] Unknown source branch: [${Current_Branch}] !"
			;;
			esac
		;;
		esac
	}
	[ -f package/base-files/files/bin/AutoUpdate.sh ] && {
		AutoUpdate_Version=$(awk 'NR==6' package/base-files/files/bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
	} || AutoUpdate_Version=OFF

	Replace_File CustomFiles/Depends/profile package/base-files/files/etc
	case ${Source_Owner} in
	coolsnowwolf)
		Replace_File CustomFiles/Depends/coremark_lede.sh package/lean/coremark coremark.sh
		Replace_File CustomFiles/Depends/cpuinfo_x86 package/lean/autocore/files/x86/sbin cpuinfo
		ExtraPackages git other helloworld https://github.com/fw876 master
		sed -i 's/143/143,8080/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr
		sed -i "s?iptables?#iptables?g" ${Version_File} > /dev/null 2>&1
		sed -i "s?${Old_Version}?${Old_Version} Compiled by ${Author} [${Display_Date}]?g" ${Version_File}
		[[ "${INCLUDE_DRM_I915}" == true ]] && Replace_File CustomFiles/Depends/i915-5.4 target/linux/x86 config-5.4
	;;
	immortalwrt)
		sed -i 's/143/143,8080/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr
		Replace_File CustomFiles/Depends/coremark_ImmortalWrt.sh package/base-files/files/etc coremark.sh
		Replace_File CustomFiles/Depends/ImmortalWrt package/base-files/files/etc openwrt_release
		Replace_File CustomFiles/Depends/cpuinfo_x86 package/lean/autocore/files/x86/sbin cpuinfo
		sed -i "s?Template?Compiled by ${Author} [${Display_Date}]?g" ${Version_File}
		[[ "${INCLUDE_DRM_I915}" == true ]] && Replace_File CustomFiles/Depends/i915-4.19 target/linux/x86 config-4.19
	;;
	esac
	
	case ${Source_Owner} in
	immortalwrt)
		Replace_File CustomFiles/Depends/banner package/lean/default-settings/files openwrt_banner
		sed -i "s?By?By ${Author}?g" package/lean/default-settings/files/openwrt_banner
		sed -i "s?Openwrt?ImmortalWrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/lean/default-settings/files/openwrt_banner
	;;
	*)
		Replace_File CustomFiles/Depends/banner package/base-files/files/etc
		sed -i "s?By?By ${Author}?g" package/base-files/files/etc/banner
		sed -i "s?Openwrt?Openwrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
	;;
	esac

	[[ "${INCLUDE_Obsolete_PKG_Compatible}" == true ]] && {
		TIME "Start to run Obsolete_Package_Compatible Scripts ..."
		[[ ${Source_Owner} == openwrt ]] && {
			case ${Current_Branch} in
			19.07 | 21.02)
				Replace_File CustomFiles/Patches/0003-upx-ucl-${Current_Branch}.patch ./
				cat 0003-upx-ucl-${Current_Branch}.patch | patch -p1 > /dev/null 2>&1
				ExtraPackages svn ../feeds/packages/lang golang https://github.com/coolsnowwolf/packages/trunk/lang
				TIME "Start to convert zh-cn translation files to zh_Hans ..."
				Replace_File Scripts/Convert_Translation.sh package
				cd ./package
				bash ./Convert_Translation.sh
				cd ..
			;;
			*)
				TIME "[ERROR] Current branch: [${Current_Branch}] is not supported !"
			;;
			esac
		} || {
			TIME "[ERROR] Current source: [${Source_Owner}] is not supported !"
		}
	}
	TIME "[Firmware-Diy_Base] All done !"
}

PS_Firmware() {
	. TARGET_INFO
	ls bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
	case ${Source_Owner} in
	immortalwrt)
		_Firmware=immortalwrt
	;;
	*)
		_Firmware=openwrt
	;;
	esac
	case ${Current_Branch} in
	19.07 | 18.06)
		case ${Source_Owner} in
		immortalwrt)
			_Legacy_Firmware=combined-squashfs
			_EFI_Firmware=uefi-gpt-squashfs
		;;
		*)
			_Legacy_Firmware=combined-squashfs
			_EFI_Firmware=combined-squashfs-efi
		;;
		esac
	;;
	*)
		_Legacy_Firmware=generic-squashfs-combined
		_EFI_Firmware=generic-squashfs-combined-efi
	;;
	esac
	Firmware_Path="bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"
	Mkdir bin/Firmware
	case "${TARGET_PROFILE}" in
	x86_64)
		cd ${Firmware_Path}
		Legacy_Firmware="${_Firmware}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${_Legacy_Firmware}.${Firmware_Type}"
		EFI_Firmware="${_Firmware}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${_EFI_Firmware}.${Firmware_Type}"
		AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}"
		echo "[Preload Info] Legacy_Firmware: ${Legacy_Firmware}"
		echo "[Preload Info] UEFI_Firmware: ${EFI_Firmware}"
		echo "[Preload Info] AutoBuild_Firmware: ${AutoBuild_Firmware}"
		[ -f "${Legacy_Firmware}" ] && {
			_MD5=$(md5sum ${Legacy_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${Legacy_Firmware} | cut -d ' ' -f1)
			touch ${Home}/bin/Firmware/${AutoBuild_Firmware}.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy.detail
			mv -f ${Legacy_Firmware} ${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy.${Firmware_Type}
			TIME "Legacy Firmware is detected !"
		} || {
			TIME "[ERROR] Legacy Firmware is not detected !"
		}
		[ -f "${EFI_Firmware}" ] && {
			_MD5=$(md5sum ${EFI_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${EFI_Firmware} | cut -d ' ' -f1)
			touch ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.detail
			cp ${EFI_Firmware} ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.${Firmware_Type}
			TIME "UEFI Firmware is detected !"
		} || {
			TIME "[ERROR] UEFI Firmware is not detected !"
		}
	;;
	*)
		cd ${Home}
		Default_Firmware="${_Firmware}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.${Firmware_Type}"
		AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_Type}"
		AutoBuild_Detail="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.detail"
		echo "[Preload Info] Default_Firmware: ${Default_Firmware}"
		echo "[Preload Info] AutoBuild_Firmware: ${AutoBuild_Firmware}"
		[ -f ${Firmware_Path}/${Default_Firmware} ] && {
			mv -f ${Firmware_Path}/${Default_Firmware} bin/Firmware/${AutoBuild_Firmware}
			_MD5=$(md5sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > bin/Firmware/${AutoBuild_Detail}
			TIME "Firmware is detected !"
		} || {
			TIME "[ERROR] Firmware is not detected !"
		}
	;;
	esac
	cd ${Home}
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
}

TIME() {
	echo "[$(date "+%H:%M:%S")] ${*}"
}

Mkdir() {
	[[ $# -ne 1 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	_DIR=${1}
	[ ! -d "${_DIR}" ] && {
		TIME "Creating new folder [${_DIR}] ..."
		mkdir -p ${_DIR}
	}
	unset _DIR
}

PKG_Finder() {
	[[ $# -ne 3 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	unset PKG_RESULT
	_PKG_TYPE=${1}
	_PKG_DIR=${2}
	_PKG_NAME=${3}
	[[ -z ${_PKG_TYPE} ]] && [[ -z ${_PKG_NAME} ]] || [[ -z ${_PKG_DIR} ]] && return
	_PKG_RESULT=$(find ${_PKG_DIR} -name ${_PKG_NAME} -type ${_PKG_TYPE} -exec echo {} \;)
	[[ -n "${_PKG_RESULT}" ]] && echo "${_PKG_RESULT}"
	unset _PKG_TYPE _PKG_DIR _PKG_NAME
}

Auto_ExtraPackages() {
	COMMON_FILE="${GITHUB_WORKSPACE}/CustomPackages/Common"
	TARGET_FILE="${GITHUB_WORKSPACE}/CustomPackages/${TARGET_PROFILE}"
	Auto_ExtraPackages_mod ${COMMON_FILE}
	Auto_ExtraPackages_mod ${TARGET_FILE}
}

Auto_ExtraPackages_mod() {
	[[ $# != 1 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
    _FILENAME=${1}
	echo "" >> ${_FILENAME}
    [ -f "${_FILENAME}" ] && {
	    TIME "Loading Custom Packages list: [${_FILENAME}]..."
	    cat ${_FILENAME} | sed '/^$/d' | while read X
	    do
	    	[[ "${X}" != "" ]] && [[ -n ${X} ]] && ExtraPackages ${X}
	    	unset X
	    done
	}
	unset _FILENAME
}

ExtraPackages() {
	[[ $# -lt 4 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	case ${1} in
	git | svn)
		PKG_PROTO=${1}
	;;
	*)
		return 0
	;;
	esac
	
	PKG_DIR=${2}
	PKG_NAME=${3}
	REPO_URL=${4}
	REPO_BRANCH=${5}

	Mkdir package/${PKG_DIR}
	[ -d "package/${PKG_DIR}/${PKG_NAME}" ] && {
		TIME "Removing old package: [${PKG_NAME}] ..."
		rm -rf "package/${PKG_DIR}/${PKG_NAME}"
	}
	TIME "Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
	case "${PKG_PROTO}" in
	git)
		[[ -z "${REPO_BRANCH}" ]] && REPO_BRANCH=master
		PKG_URL="$(echo ${REPO_URL}/${PKG_NAME} | sed s/[[:space:]]//g)"
		git clone -b ${REPO_BRANCH} ${PKG_URL} ${PKG_NAME} > /dev/null 2>&1
	;;
	svn)
		svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
	;;
	esac
	[ -f ${PKG_NAME}/Makefile ] || [ -f ${PKG_NAME}/README* ] || [[ -n "$(ls -A ${PKG_NAME})" ]] && {
		mv -f "${PKG_NAME}" "package/${PKG_DIR}"
	} || {
		TIME "[ERROR] Package [${PKG_NAME}] is not detected!"
	}
	unset PKG_PROTO PKG_DIR PKG_NAME REPO_URL REPO_BRANCH
}

Replace_File() {
	[[ $# -lt 2 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	FILE_NAME=${1}
	PATCH_DIR=${GITHUB_WORKSPACE}/openwrt/${2}
	FILE_RENAME=${3}
	
	Mkdir ${PATCH_DIR}
	[ -f "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="f" && _TYPE2="File"
	[ -d "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="d" && _TYPE2="Folder"
	[ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && {
		[[ -n "${FILE_RENAME}" ]] && _RENAME="${FILE_RENAME}" || _RENAME=""
		[ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && {
			TIME "Moving [${_TYPE2}] ${FILE_NAME} to ${2}/${FILE_RENAME} ..."
			mv -f "${GITHUB_WORKSPACE}/${FILE_NAME}" "${PATCH_DIR}/${_RENAME}"
		} || {
			TIME "CustomFiles ${_TYPE2} [${FILE_NAME}] is not detected !"
		}
	}
	unset FILE_NAME PATCH_DIR FILE_RENAME
}

Update_Makefile() {
	[[ $# -ne 2 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	PKG_NAME=${1}
	Makefile=${2}/Makefile
	[ -f "/tmp/tmp_file" ] && rm -f /tmp/tmp_file
	[ -f "${Makefile}" ] && {
		PKG_URL_MAIN="$(grep "PKG_SOURCE_URL:=" ${Makefile} | cut -c17-100)"
		_process1=${PKG_URL_MAIN##*com/}
		_process2=${_process1%%/tar*}
		api_URL="https://api.github.com/repos/${_process2}/releases"
		PKG_SOURCE_URL="$(grep "PKG_SOURCE_URL:=" ${Makefile} | cut -c17-100)"
		PKG_DL_URL="${PKG_SOURCE_URL%\$(\PKG_VERSION*}"
		Offical_Version="$(curl -s ${api_URL} 2>/dev/null | grep 'tag_name' | egrep -o '[0-9].+[0-9.]+' | awk 'NR==1')"
		[[ -z "${Offical_Version}" ]] && {
			TIME "[ERROR] Failed to obtain the Offical version of [${PKG_NAME}] !"
			return
		}
		Source_Version="$(grep "PKG_VERSION:=" ${Makefile} | cut -c14-20)"
		Source_HASH="$(grep "PKG_HASH:=" ${Makefile} | cut -c11-100)"
		[[ -z "${Source_Version}" ]] || [[ -z "${Source_HASH}" ]] && {
			TIME "[ERROR] Failed to obtain the Source version or Hash !"
			return
		}
		[[ ! "${Source_Version}" == "${Offical_Version}" ]] && {
			TIME "Updating package ${PKG_NAME} [${Source_Version}] to [${Offical_Version}] ..."
			sed -i "s?PKG_VERSION:=${Source_Version}?PKG_VERSION:=${Offical_Version}?g" ${Makefile}
			wget -q "${PKG_DL_URL}${Offical_Version}?" -O /tmp/tmp_file
			[[ "$?" -eq 0 ]] && {
				Offical_HASH="$(sha256sum /tmp/tmp_file | cut -d ' ' -f1)"
				sed -i "s?PKG_HASH:=${Source_HASH}?PKG_HASH:=${Offical_HASH}?g" ${Makefile}
			} || {
				TIME "[ERROR] Failed to update the package [${PKG_NAME}] !"
			}
		}
	} || {
		TIME "[ERROR] Package ${PKG_NAME} is not detected !"
	}
	unset _process1 _process2 Offical_Version Source_Version
}
