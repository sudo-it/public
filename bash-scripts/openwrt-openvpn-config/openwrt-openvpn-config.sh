#!/bin/ash

#------------------------------------------------------------------------------#
#
# SIT-20190803
#
# file: openwrt-openvpn-config.sh
#
# usage: openwrt-openvpn-config.sh
#
# description: configures a routed openvpn server with pki certificate & 
#              user/password authentication on openwrt
#              
# version: 1.0
# requirements: openvpn-easy-rsa openvpn-openssl
# bugs:
# notes: tested hw - Linksys WRT3200ACM
#        tested os - OpenWrt 18.06.4 r7808-ef686b7292 
#                    LuCI openwrt-18.06 branch (git-19.170.32094-4d6d8bc)
#
# reference: https://openwrt.org/docs/guide-user/services/vpn/openvpn/basic
#
#------------------------------------------------------------------------------#


#-- VARIABLES ------------------------------------------------------------------

export EASYRSA_REQ_CN="vpnca"
export EASYRSA_PKI="/etc/easy-rsa/pki"
export OPENVPN_BASE_DIR="/etc/openvpn"

script_start_ts="$(date)"
script_log_file="/root/${0%.*}.log"

openvpn_status_log="/tmp/openvpn-status.log"

up_auth_script_dir="${OPENVPN_BASE_DIR}/scripts"
up_auth_script_name="openwrt-openvpn-up-auth.sh"
up_auth_script_file="${up_auth_script_dir}/${up_auth_script_name}"
up_auth_conf_file="${up_auth_script_file%.*}.conf"

client_dirname="openvpn-client"
client_dirpath="${OPENVPN_BASE_DIR}/${client_dirname}"
client_config_file="${client_dirpath}/openvpn-client.ovpn"

#-- FUNCTIONS ------------------------------------------------------------------

request_config_info() {

   printf "\n"

   # request input from user and set defaults if no input provided
   sleep 1; read -p "Enter VPN client network (default: 10.0.1.0 255.255.255.0): " VPN_NET
   if [ -z "${VPN_NET}" ]; then VPN_NET="10.0.1.0 255.255.255.0"; fi

   # set default vpn dns address
   DEFAULT_VPN_DNS="${VPN_NET%.* *}.1"

   sleep 1; read -p "Enter VPN client DNS address (default: ${DEFAULT_VPN_DNS}): " VPN_DNS
   if [ -z "${VPN_DNS}" ]; then VPN_DNS="${DEFAULT_VPN_DNS}"; fi

   # get vpn wan ip from existing config
   DEFAULT_VPN_WAN_IP="$(ifconfig eth1.2 | grep "inet addr" | cut -d: -f2 | cut -d" " -f1)"
   
   sleep 1; read -p "Enter VPN WAN IP address (default: "${DEFAULT_VPN_WAN_IP}"): " VPN_WAN_IP
   if [ -z "${VPN_WAN_IP}" ]; then VPN_WAN_IP="${DEFAULT_VPN_WAN_IP}"; fi

   sleep 1; read -p "Enter VPN WAN port (default: "1194"): " VPN_PORT
   if [ -z "${VPN_PORT}" ]; then VPN_PORT="1194"; fi

   # display and confirm user input
   printf "\nYou entered:\n\n"

   printf "VPN client network: \"${VPN_NET}\"\n"
   printf "VPN client DNS address: \"${VPN_DNS}\"\n"
   printf "VPN WAN IP address: \"${VPN_WAN_IP}\"\n"
   printf "VPN WAN port: \"${VPN_PORT}\"\n\n"

   # invoke "confirm_user_input" function with current function name as argument
   confirm_user_input request_config_info

}

request_auth_user_info() {

   printf "\n"

   # request username from user input and set default if none provided
   sleep 1; read -p "Enter desired username (default: user1): " auth_user
   if [ -z "${auth_user}" ]; then auth_user="user1"; fi

   # display and confirm user input
   printf "\nYou entered: "$auth_user"\n\n"
   
   # invoke "confirm_user_input" function with current function name as argument
   confirm_user_input request_auth_user_info

   # write username to auth config file
   printf "$auth_user\n" > "${up_auth_conf_file}"

}

request_auth_passwd_info() {

   default_pass="password"

   # request password from user input and set default if none provided
   printf "\nEnter desired password (default: ${default_pass}): "; sleep 1; read -s auth_pass
   if [ -z "${auth_pass}" ]; then auth_pass="${default_pass}"; fi

   # request password 2nd time from user input and set default if none provided
   printf "\nVerify desired password (default: ${default_pass}): "; sleep 1; read -s auth_pass2
   if [ -z "${auth_pass2}" ]; then auth_pass2="${default_pass}"; fi
   
   # verify provided passwords match
   if [ "${auth_pass}" != "${auth_pass2}" ]; then
      printf "\n\nPassword mismatch. Try again.\n"
      request_auth_passwd_info
   else   
      # hash password and write to auth config file
      printf "\n\nPassword verified. Proceeding...\n\n"
      printf "${auth_pass}" | sha256sum | cut -d " " -f 1 >> "${up_auth_conf_file}"
   fi
      
}

confirm_user_input() {

   arg1="${1}"

   # request user confirmation
   sleep 1; read -p "Is this correct? (Y/N): " confirm;

   # while input null, repeat confirmation request
   while [ -z "${confirm}" ]; do
      printf "Invalid response.  Please enter Y or N.\n"
      sleep 1; read -p "Is this correct? (Y/N): " confirm;
   done

   # while input invalid, repeat confirmation request
   while [ "${confirm}" != "Y" -a "${confirm}" != "y" -a "${confirm}" != "N" -a "${confirm}" != "n" ]; do
      printf "Invalid response.  Please enter Y or N.\n"
      sleep 1; read -p "Is this correct? (Y/N): " confirm;
   done

   # if negative input recieved, clear variable and repeat menu
   if [ "${confirm}" == "N" -o "${confirm}" == "n" ]; then
      unset confirm
      sleep 1
      ${arg1}
   fi

   # clear variable
   unset confirm

}

install_required_packages() {

   printf "### INSTALL REQUIREMENTS ###\n\n"

   printf "Installing required packages...\n\n"
   # install packages
   opkg update
   opkg install openvpn-easy-rsa openvpn-openssl

   printf "\nCompleted.\n\n"

}

create_openvpn_certs() {

   printf "### CONFIGURE PKI CERTS ###\n\n"

   printf "Creating certificates (should take around 20 minutes)..."
   # remove and re-initialize the PKI directory
   easyrsa --batch init-pki

   printf "\n\n"
 
   # generate DH parameters
   easyrsa --batch gen-dh
 
   printf "\n\n"

   # create a new CA
   easyrsa --batch build-ca nopass

   printf "\n\n"
 
   # generate a keypair and sign locally for vpnserver
   easyrsa --batch build-server-full vpnserver nopass

   printf "\n\n"
 
   # generate a keypair and sign locally for vpnclient
   easyrsa --batch build-client-full vpnclient nopass

   printf "\n\n"

   # generate TLS PSK
   openvpn --genkey --secret "${EASYRSA_PKI}/tc.pem"

   printf "Completed.\n\n"

}

configure_openvpn_server() {

   printf "### CONFIGURE OPENVPN SERVER ###\n\n"

   printf "Configuring Firewall...\n\n"
   # configure firewall
   uci set firewall.@zone[0].device="tun0"
   uci -q delete firewall.vpn
   uci set firewall.vpn="rule"
   uci set firewall.vpn.name="Allow-OpenVPN"
   uci set firewall.vpn.src="wan"
   uci set firewall.vpn.dest_port="${VPN_PORT}"
   uci set firewall.vpn.proto="udp"
   uci set firewall.vpn.target="ACCEPT"
   uci commit firewall
   /etc/init.d/firewall restart

   printf "\nConfiguring VPN Server...\n\n"
   # set configuration parameters
   vpn_dev="$(uci get firewall.@zone[0].device)"
   vpn_domain="$(uci get dhcp.@dnsmasq[0].domain)"
   dh_key="$(cat "${EASYRSA_PKI}/dh.pem")"
   tc_key="$(sed -e "/^#/d;/^\w/N;s/\n//" "${EASYRSA_PKI}/tc.pem")"
   ca_cert="$(openssl x509 -in "${EASYRSA_PKI}/ca.crt")"
   newline=$'\n'
 
   grep -l -r -e "TLS Web Server Authentication" "${EASYRSA_PKI}/issued" \
   | sed -e "s/^.*\///;s/\.\w*$//" \
   | while read vpn_id
   do
   vpn_conf="/etc/openvpn/${vpn_id}.conf"
   vpn_cert="$(openssl x509 -in "${EASYRSA_PKI}/issued/${vpn_id}.crt")"
   vpn_key="$(cat "${EASYRSA_PKI}/private/${vpn_id}.key")"

   # create vpn server configuration file (indentation removed for proper file formatting)
   printf "auth RSA-SHA256
auth-user-pass-verify ${up_auth_script_file} via-file
client-to-client
comp-lzo
dev ${vpn_dev}
group nogroup
keepalive 10 120
persist-key
persist-tun
port ${VPN_PORT}
proto udp
push \"dhcp-option DNS ${VPN_DNS}\"
push \"dhcp-option DOMAIN ${vpn_domain}\"
push \"persist-key\"
push \"persist-tun\"
push \"redirect-gateway def1\"
script-security 2
server ${VPN_NET}
status ${openvpn_status_log}
topology subnet
user nobody
verb 3
<dh>\n${dh_key}\n</dh>
<ca>\n${ca_cert}\n</ca>
<cert>\n${vpn_cert}\n</cert>
<key>\n${vpn_key}\n</key>
<tls-crypt>\n${tc_key}\n</tls-crypt>
" > "${vpn_conf}"

   chmod "400" "${vpn_conf}"

   done

   printf "OpenVPN server configuration file written to: ${vpn_conf}\n\n"

   printf "Restarting openvpn service...\n\n"
   # restart openvpn service
   /etc/init.d/openvpn restart

   printf "OpenVPN server status log located: ${openvpn_status_log}\n\n"

   printf "Completed.\n\n"

}

configure_openvpn_up_auth() {
# creates an executable script file for use with "auth-user-pass-verify" server directive

   printf "### CONFIGURE OPENVPN SERVER USER/PASSWORD AUTH ###\n\n"

   printf "Creating user/password authentication script file...\n\n"
   # create script file (indentation removed for proper script formatting)
   printf "%s\n" '#!/bin/ash
# description: provides username/password authentication for openvpn

# script parent directory
script_dir="$(dirname ${0})"

# script file name
script_file="$(basename ${0})"

# script file name with trailing extension removed
script_file_noext="${script_file%.*}"

# script config file name
conf_file="${script_dir}/${script_file_noext}.conf"

# script log file name
log_file="/tmp/${script_file_noext}.log"

# note: openvpn "auth-user-pass-verify" server directive with "via-file" option \
# provides user/pass in 2-line plain text file format, where line 1 is \
# username and line 2 is password.

# capture username from script input
input_user="$(head -1 ${1})"

# capture password from script input and hash the value
input_pass="$(printf $(tail -1 ${1}) | sha256sum | cut -d " " -f 1)"

# capture username from conf file
conf_user="$(head -1 ${conf_file})"

# capture password hash from conf file
conf_pass="$(tail -1 ${conf_file})"

printf "\nDate: $(date)\n" | tee -a ${log_file}
printf "Username: ${input_user}\n\n" | tee -a ${log_file}

# if username incorrect, exit with failure
if [ "${input_user}" != "${conf_user}" ]; then

   printf "ERROR: Incorrect username. Access denied!\n\n" | tee -a ${log_file}
   exit 1

# username verified, if password incorrect, exit with failure
elif [ "${input_pass}" != "${conf_pass}" ]; then

   printf "ERROR: Incorrect password. Access denied!\n\n" | tee -a ${log_file}
   exit 1

# username and password verified; exit with success
else

   printf "SUCCESS: Correct username and password. Access granted.\n\n" | tee -a ${log_file}
   exit 0

fi
' > "${up_auth_script_file}"

   # set script permissions
   chmod 555 "${up_auth_script_file}"
   
   printf "OpenVPN user/password authentication script written to: ${up_auth_script_file}\n\n"
   printf "OpenVPN user/password authentication log located: /tmp/${up_auth_script_name%.*}.log\n\n" 

   printf "Completed.\n\n"

}

configure_openvpn_client() {

   printf "### CONFIGURE OPENVPN CLIENT ###\n\n"

   mkdir -p "${client_dirpath}"

   printf "Creating client configuration file...\n\n"
   # create client config file (indentation removed for proper file formatting)
   printf "auth RSA-SHA256
auth-user-pass
ca ca.crt
cert vpnclient.crt
client
comp-lzo
dhcp-option DNS ${VPN_DNS}
dev tun0
group nobody
key-direction 1
key vpnclient.key
nobind
persist-key
persist-tun
proto udp
pull
remote ${VPN_WAN_IP} ${VPN_PORT}
resolv-retry infinite
tls-client
tls-crypt tc.pem 1
user nobody
verb 3
" > "${client_config_file}"

   printf "Completed.\n\n"

}

create_openvpn_client_archive() {

   printf "### CREATE OPENVPN CLIENT CONFIGURATION ARCHIVE ###\n\n"

   # copy required certs to client dir
   cp -p "${EASYRSA_PKI}/ca.crt" \
   "${EASYRSA_PKI}/tc.pem" \
   "${EASYRSA_PKI}/issued/vpnclient.crt" \
   "${EASYRSA_PKI}/private/vpnclient.key" "${client_dirpath}/"

   # create client readme
   printf "Execute command \"sudo openvpn $(basename ${client_config_file})\" from client device to connect to openvpn server.\n" \
   > ${client_config_file%.*}.readme

   # set client file permissions
   chmod 400 "${client_dirpath}"/*

   printf "Creating client archive file...\n\n"
   # create client archive file
   client_archive_file="${OPENVPN_BASE_DIR}/${client_dirname}.tgz"
   cd "${client_dirpath}/.."
   tar cpzf "${client_archive_file}" "${client_dirname}"
   rm -rf "${client_dirname}"
   cd - > /dev/null 2>&1

   printf "Client archive file created at: "${client_archive_file}"\n"
   printf "*Securely* copy (e.g. scp) and extract this file to client device.\n\n"

   printf "Completed.\n\n"

}

#-- MAIN FUNCTION --------------------------------------------------------------

main() {

   #create required script directory
   mkdir -p "${up_auth_script_dir}"

   printf "\n"
   printf "1 - New installation (complete)\n"
   printf "2 - Reconfigure existing installation (leave previously generated certificates alone)\n"
   printf "3 - Generate new certificates (and create new client archive)\n\n"

   sleep 1; read -p "Please make a selection: " select

   printf "\nYou selected: "${select}"\n\n"

   # invoke "confirm_user_input" function with current function name as argument
   confirm_user_input main

   case "${select}" in
   1)
      request_config_info
      request_auth_user_info
      request_auth_passwd_info
      install_required_packages
      create_openvpn_certs
      configure_openvpn_server
      configure_openvpn_up_auth
      configure_openvpn_client
      create_openvpn_client_archive
      ;;
   2)
      request_config_info
      request_auth_user_info
      request_auth_passwd_info
      configure_openvpn_server
      configure_openvpn_up_auth
      configure_openvpn_client
      create_openvpn_client_archive
      ;;
   3)
      create_openvpn_certs
      create_openvpn_client_archive
      ;;
   *)
      printf "\nERROR: Invalid selection.  No changes made.  Exiting script.\n\n"
      break
      ;;
   esac

   printf "### SCRIPT COMPLETED ###\n\n"
   printf "SCRIPT START TIME: ${script_start_ts}\n"
   printf "SCRIPT END TIME: $(date)\n\n"
   printf "SCRIPT LOGFILE: ${script_log_file}\n\n"
   exit 0

}

#-- EXECUTE --------------------------------------------------------------------

# execute main function and log output to file
main | tee "${script_log_file}"
