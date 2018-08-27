#!/bin/bash

#------------------------------------------------------------------------------#
#
# SI-20180707
#
# file: bash-script-template-1.0.el7.x86_64.sh
#
# usage: bash-script-template-1.0.el7.x86_64.sh
#
# description: general bash script template
#
# version: 1.0
# requirements:
# bugs:
# notes:
#
#------------------------------------------------------------------------------#



#-- VARIABLES ------------------------------------------------------------------

script_start_timestamp="$(date)"
script_start_timestamp_formatted="$(date +%Y%m%d-%H%M%S)"

script_name="$(basename $0)"
script_name_formatted="$(basename $0 .sh)" #remove .sh suffix
script_dir="$( cd "$(dirname "$0")" ; pwd -P )"
script_file="$script_dir/$script_name"

script_log_dir="$script_dir/$script_name_formatted-log"
script_log_file="$script_log_dir/script.log.$script_start_timestamp_formatted"

start_user="$USER"
start_dir="$(pwd)" #record user's current directory

require_root="no" #script requires root privileges #yes/no


#-- FUNCTIONS ------------------------------------------------------------------

env_prep() {
    echo; echo "  Preparing script environment..."

    # check for root privileges if required.
    if [[ $require_root == "yes" && $EUID != 0 ]]; then
        echo; echo "  ERROR: Script requires root privileges."
        echo; echo "  Exiting..."; echo
        exit 1
    fi

    # check for log directory, create if missing, verify creation, exit on fail.
    if [ ! -d $script_log_dir ]; then
        mkdir -p $script_log_dir
        sleep 1
        if [ ! -d $script_log_dir ]; then
            echo; echo "  ERROR: $script_log_dir not found."
            echo; echo "  Exiting..."; echo
            exit 1
        fi
    fi

    # create log file, verify creation, exit on fail.
    touch $script_log_file
    sleep 1
    if [ ! -f $script_log_file ]; then
        echo; echo "  ERROR: $script_log_file not found."
        echo; echo "  Exiting..."; echo
        exit 1
    fi
}

read_script_source() {
    echo
    echo
    echo "###############################################"
    echo "#                SCRIPT SOURCE                #"
    echo "###############################################"
    echo
    cat $script_file
}


#-- MAIN FUNCTION --------------------------------------------------------------

main() {
    # begin info header
    echo; echo -e "  \e[4mScript:\e[0m $script_file $@"
    echo; echo -e "  \e[4mStarted at:\e[0m $script_start_timestamp" 
    echo; echo -e "  \e[4mStarted by:\e[0m $start_user" 
    # end info header

    echo; echo "    Begin main script function..."
    echo; echo "      Change directory to $script_dir"
    cd $script_dir




    ### ADD FURTHER ACTIONS HERE ###




    echo; echo "      Change directory back to $start_dir"
    cd $start_dir

    # begin info footer
    echo; echo -e "  \e[4mLogfile:\e[0m $script_log_file"
    echo; echo -e "  \e[4mCompleted:\e[0m $(date)"; echo
    # end info footer
}


#-- EXECUTE --------------------------------------------------------------------

# call env_prep function 
env_prep

# call main function and log output to file
main | tee $script_log_file

# record script source to log file
read_script_source >> $script_log_file

exit 0
