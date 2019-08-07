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

script_start_ts="$(date +"%Y-%m-%d %H:%M:%S")"
script_start_ts_fmt="$(date --date "${script_start_ts}" +%Y%m%d-%H%M%S)"
script_log_dir="/root/${0%.*}-log"
script_log_file="${script_log_dir}/${0%.*}-${script_start_ts_fmt}.log"
script_bkp_file="${script_log_dir}/${0%.*}-${script_start_ts_fmt}-bkp.tgz"

easyrsa_req_cn="vpnca"
easyrsa_base_dir="/etc/easy-rsa"
easyrsa_pki_dir="${easyrsa_base_dir}/pki"

export EASYRSA_PKI="${easyrsa_pki_dir}" #env variable required by easyrsa
export EASYRSA_REQ_CN="${easyrsa_req_cn}" #env variable required by easyrsa

openvpn_base_dir="/etc/openvpn"
openvpn_status_log="/tmp/openvpn-status.log"

os_conf_dir="/etc/config"

up_auth_script_dir="${openvpn_base_dir}/scripts"
up_auth_script_name="openwrt-openvpn-up-auth.sh"
up_auth_script_file="${up_auth_script_dir}/${up_auth_script_name}"
up_auth_conf_file="${up_auth_script_file%.*}.conf"

client_dir_name="openvpn-client"
client_dir_path="${openvpn_base_dir}/${client_dir_name}"
client_conf_file="${client_dir_path}/openvpn-client.ovpn"

#-- FUNCTIONS ------------------------------------------------------------------

request_config_info() {

   printf "\n### CONFIGURATION MENU ###\n\n"

   # set default vpn net
   default_vpn_net="10.0.1.0 255.255.255.0"

   # request input from user and set defaults if no input provided
   sleep 1; read -p "Enter VPN client network address and mask (default: ${default_vpn_net}): " vpn_net
   if [ -z "${vpn_net}" ]; then vpn_net="${default_vpn_net}"; fi

   # set default vpn dns address
   default_vpn_dns="1.1.1.1"

   sleep 1; read -p "Enter VPN client DNS server address (default: ${default_vpn_dns}): " vpn_dns
   if [ -z "${vpn_dns}" ]; then vpn_dns="${default_vpn_dns}"; fi

   # set default vpn wan ip - query value from existing config
   default_vpn_wan_ip="$(ifconfig eth1.2 | grep "inet addr" | cut -d: -f2 | cut -d" " -f1)"
 
   sleep 1; read -p "Enter VPN WAN IP address (default: ${default_vpn_wan_ip}): " vpn_wan_ip
   if [ -z "${vpn_wan_ip}" ]; then vpn_wan_ip="${default_vpn_wan_ip}"; fi

   # set default vpn port
   default_vpn_port="1194"

   sleep 1; read -p "Enter VPN WAN port (default: ${default_vpn_port}): " vpn_port
   if [ -z "${vpn_port}" ]; then vpn_port="${default_vpn_port}"; fi

   # display and confirm user input
   printf "\nYou entered:\n\n"

   printf "VPN client network: \"${vpn_net}\"\n"
   printf "VPN client DNS address: \"${vpn_dns}\"\n"
   printf "VPN WAN IP address: \"${vpn_wan_ip}\"\n"
   printf "VPN WAN port: \"${vpn_port}\"\n\n"

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

backup_existing_config() {

   printf "### BACKUP EXISTING CONFIG ###\n\n"

   printf "Backing up any existing certificates and configuration to:\n"
   printf "${script_bkp_file}"

   # backup any existing certificates and configuration
   tar cpzf "${script_bkp_file}" \
      "${easyrsa_base_dir}" \
      "${openvpn_base_dir}" \
      "${os_conf_dir}" \
      "${0}" > /dev/null 2>&1

   printf "\n\n"

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

   printf "Creating certificates...\n\n"

   # remove and re-initialize the PKI directory
   printf "Removing any existing certificates at: ${easyrsa_pki_dir}"
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
   openvpn --genkey --secret "${easyrsa_pki_dir}/tc.pem"

   printf "Completed.\n\n"

}

configure_openvpn_server() {

   printf "### CONFIGURE OPENVPN SERVER ###\n\n"

   printf "Configuring firewall...\n\n"
   # configure firewall
   uci set firewall.@zone[0].device="tun0"
   uci -q delete firewall.vpn
   uci set firewall.vpn="rule"
   uci set firewall.vpn.name="Allow-OpenVPN"
   uci set firewall.vpn.src="wan"
   uci set firewall.vpn.dest_port="${vpn_port}"
   uci set firewall.vpn.proto="udp"
   uci set firewall.vpn.target="ACCEPT"
   uci commit firewall
   /etc/init.d/firewall restart

   printf "\nConfiguring OpenVPN server...\n\n"
   # set configuration parameters
   vpn_dev="$(uci get firewall.@zone[0].device)"
   vpn_domain="$(uci get dhcp.@dnsmasq[0].domain)"
   vpn_dh_key="$(cat "${easyrsa_pki_dir}/dh.pem")"
   vpn_tc_key="$(sed -e "/^#/d;/^\w/N;s/\n//" "${easyrsa_pki_dir}/tc.pem")"
   vpn_ca_cert="$(openssl x509 -in "${easyrsa_pki_dir}/ca.crt")"
 
   grep -l -r -e "TLS Web Server Authentication" "${easyrsa_pki_dir}/issued" \
   | sed -e "s/^.*\///;s/\.\w*$//" \
   | while read vpn_id
   do
   vpn_conf="${openvpn_base_dir}/${vpn_id}.conf"
   vpn_cert="$(openssl x509 -in "${easyrsa_pki_dir}/issued/${vpn_id}.crt")"
   vpn_key="$(cat "${easyrsa_pki_dir}/private/${vpn_id}.key")"

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
port ${vpn_port}
proto udp
push \"dhcp-option DNS ${vpn_dns}\"
push \"dhcp-option DOMAIN ${vpn_domain}\"
push \"persist-key\"
push \"persist-tun\"
push \"redirect-gateway def1\"
script-security 2
server ${vpn_net}
status ${openvpn_status_log}
topology subnet
user nobody
verb 3
<dh>\n${vpn_dh_key}\n</dh>
<ca>\n${vpn_ca_cert}\n</ca>
<cert>\n${vpn_cert}\n</cert>
<key>\n${vpn_key}\n</key>
<tls-crypt>\n${vpn_tc_key}\n</tls-crypt>
" > "${vpn_conf}"

   printf "OpenVPN server configuration file written to: ${vpn_conf}\n\n"

   chmod "400" "${vpn_conf}"

   done

   printf "Restarting OpenVPN service...\n\n"
   # restart openvpn service
   /etc/init.d/openvpn restart

   printf "OpenVPN server status log located: ${openvpn_status_log}\n\n"

   printf "Completed.\n\n"

}

configure_openvpn_up_auth() {
# creates an executable script file for use with "auth-user-pass-verify" server directive

   printf "### CONFIGURE OPENVPN SERVER USER/PASSWORD AUTH ###\n\n"

   printf "Creating OpenVPN user/password authentication script file...\n\n"
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

   mkdir -p "${client_dir_path}"

   printf "Creating OpenVPN client configuration file...\n\n"
   # create client config file (indentation removed for proper file formatting)
   printf "auth RSA-SHA256
auth-user-pass
ca ca.crt
cert vpnclient.crt
client
comp-lzo
dhcp-option DNS ${vpn_dns}
dev tun0
group nobody
key-direction 1
key vpnclient.key
nobind
persist-key
persist-tun
proto udp
pull
remote ${vpn_wan_ip} ${vpn_port}
resolv-retry infinite
tls-client
tls-crypt tc.pem 1
user nobody
verb 3
" > "${client_conf_file}"

   # create client readme
   printf "Execute command \"sudo openvpn $(basename ${client_conf_file})\" from client device to connect to openvpn server.\n" \
   > ${client_conf_file%.*}.readme

   printf "OpenVPN client configuration file written to: ${client_conf_file}\n\n"

   printf "Completed.\n\n"

}

create_openvpn_client_archive() {

   printf "### CREATE OPENVPN CLIENT CONFIGURATION ARCHIVE ###\n\n"

   # copy required certs to client dir
   cp -p "${easyrsa_pki_dir}/ca.crt" \
   "${easyrsa_pki_dir}/tc.pem" \
   "${easyrsa_pki_dir}/issued/vpnclient.crt" \
   "${easyrsa_pki_dir}/private/vpnclient.key" "${client_dir_path}/"

   # set client file permissions
   chmod 400 "${client_dir_path}"/*

   printf "Creating OpenVPN client archive file...\n\n"
   # create client archive file
   client_archive_file="${openvpn_base_dir}/${client_dir_name}.tgz"
   cd "${client_dir_path}/.."
   tar cpzf "${client_archive_file}" "${client_dir_name}"
   cd - > /dev/null 2>&1

   printf "OpenVPN client archive file created at: "${client_archive_file}"\n"
   printf "*Securely* copy (e.g. scp) and extract this file to client device.\n\n"

   printf "Completed.\n\n"

}

print_system_info() {

   printf "### SYSTEM INFO ###\n\n"
   uname -a
   printf "\n"
   cat /etc/os-release
   printf "\n\n"

}

#-- MAIN FUNCTION --------------------------------------------------------------

main() {

   printf "\n### INSTALLATION MENU ###\n\n"

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
      backup_existing_config
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
      backup_existing_config
      configure_openvpn_server
      configure_openvpn_up_auth
      configure_openvpn_client
      create_openvpn_client_archive
      ;;
   3)
      backup_existing_config
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
   printf "SCRIPT END TIME: $(date +"%Y-%m-%d %H:%M:%S")\n\n"
   printf "SCRIPT LOGFILE: ${script_log_file}\n\n"


   exit 0

}

#-- EXECUTE --------------------------------------------------------------------

# create required script log directory
mkdir -p "${script_log_dir}"

#create required openvpn user/pass script directory
mkdir -p "${up_auth_script_dir}"

# execute main function and log output to file
main 2>&1 | tee "${script_log_file}"

# append system info to log file without terminal display
print_system_info >> ${script_log_file}
