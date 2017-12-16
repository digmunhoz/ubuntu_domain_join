#! /bin/bash

clear

# Variables definition
LOG=/tmp/linux_ad_join.log
LIGHTDM_FILE=/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf
PBIS_URL=https://github.com/BeyondTrust/pbis-open/releases/download/8.5.7/pbis-open-8.5.7.385.linux.x86_64.deb.sh
PBIS_BIN=/opt/pbis/bin/domainjoin-cli
PBIS_CONFIG_BIN=/opt/pbis/bin/config

# Colors
RED='\033[0;31m'
GREEN='\033[01;32m'
NC='\033[0m'

# User Validation
if [ "$(id -u)" != "0" ]; then
	echo "${RED}ERROR:${NC} This script must be run as root" ;
	exit 1;
fi

# Functions definitions
status ()
{
	if [[ $? -gt 0 ]]; then
		echo -e "${STEP}: ${RED}ERROR${NC}";
		cat ${LOG};
		exit 1;
	else
		echo -e "${STEP}: ${GREEN}OK${NC}";
		echo "";
	fi
}

get_os_info ()
{
	OS_VERSION=$(cat /etc/os-release |grep VERSION_ID |grep -o '"[^"]\+"'| tr -d '"')
	OS_NAME=$(cat /etc/os-release |grep PRETTY_NAME |grep -o '"[^"]\+"'| tr -d '"')
}

check_supported_os ()
{
	get_os_info 1> /dev/null 2> /dev/null
	case ${OS_VERSION} in
		16.04 )
			;;
		*)
			echo -e "Unsupported Operating System ${RED}${OS_NAME} ${OS_VERSION}${NC}"
			echo ""
			exit 1
			;;
	esac
}

get_domain_informaion ()
{
	STEP="Getting domain informations" 1> /dev/null 2> ${LOG}
	whiptail --title "Active Directory Join Wizard" --msgbox "This is a Wizard to help you joining Linux workstation on Active Directory.\n\nPress ENTER to continue." 10 78
	DOMAIN=$(whiptail --inputbox "Type the domain name.\nLike this: contoso.net" 12 80 --title "Domain Name" 3>&1 1>&2 2>&3 )
	DOMAIN_USER=$(whiptail --inputbox "Type the admin domain user to join to the domain." 12 80 --title "Domain User" 3>&1 1>&2 2>&3 )
	DOMAIN_PASSWD=$(whiptail --passwordbox "Type the password for the user: ${DOMAIN_USER}" 8 78 --title "Domain Password" 3>&1 1>&2 2>&3 )
	status
}

nm_config ()
{
	STEP="Config NetworkManager" 1> /dev/null 2> ${LOG}
	sed -i -ri.bak '^s/dns=dnsmasq/#dns=dnsmasq/g' /etc/NetworkManager/NetworkManager.conf 1> /dev/null 2>> ${LOG}
	service network-manager restart 1> /dev/null 2>> ${LOG}
	status
}

lightdm_config ()
{
	STEP="Config Lightdm"
	grep greeter-show-manual-login ${LIGHTDM_FILE} 1> /dev/null 2> ${LOG}
	SHOW_MANUAL_LOGIN=$?
	if [[ ${SHOW_MANUAL_LOGIN} -gt 0 ]]; then
		echo "greeter-show-manual-login=true" >> ${LIGHTDM_FILE} 1> /dev/null 2>> ${LOG}
	else
		sed -ri.bak_$(date +%s) 's/greeter-show-manual-login=.*/greeter-show-manual-login=true/g' ${LIGHTDM_FILE} 1> /dev/null 2>> ${LOG}
	fi
	systemctl restart lightdm 1> /dev/null 2>> ${LOG}
	status
}

install_pbis ()
{
	STEP="Installing pbis" 1> /dev/null 2> ${LOG}
	wget ${PBIS_URL} -O /tmp/pbis.sh 1> /dev/null 2>> ${LOG}
	sh /tmp/pbis.sh 1> /dev/null 2>> ${LOG}
	status
}

config_pbis ()
{
	STEP="Config pbis" 1> /dev/null 2> ${LOG}
	${PBIS_CONFIG_BIN} HomeDirTemplate %H/%D/%U 1> /dev/null 2>> ${LOG}
	${PBIS_CONFIG_BIN} LoginShellTemplate /bin/bash 1> /dev/null 2>> ${LOG}
	status
}

join_domain ()
{
	STEP="Join domain" 1> /dev/null 2> ${LOG}
	${PBIS_BIN} join --assumeDefaultDomain yes --userDomainPrefix "${DOMAIN,,}" "${DOMAIN^^}" ${DOMAIN_USER} ${DOMAIN_PASSWD} 1> /dev/null 2>> ${LOG}
	status
}

# Functions Call
check_supported_os
get_domain_informaion
nm_config
lightdm_config
install_pbis
config_pbis
join_domain