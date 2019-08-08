#!/bin/bash

#------------------------------------------------------------------------------#
#
# SIT-20180827
#
#         File: bash-script-template-2.0.el7.x86_64.sh
#
#        Usage: bash-script-template-2.0.el7.x86_64.sh {*string*}
#
#  Description: bash script template which: \
#               - provides some error handling \
#				- provides text formatting functions \
#               - saves logs to script's current directory.
#
#      Version: 2.0
#
# Requirements: 
#
#     Platform: rhel/centos 7
#
#         Bugs: n/a
#
#        Notes: all code additions intended to be appended toward end of file \
#               contained within the "CUSTOM_CODE" function braces.
#
#------------------------------------------------------------------------------#



#-- GLOBAL VARIABLES -----------------------------------------------------------

SCRIPT_REQUIRE_ROOT="yes" # script requires root privileges: yes/no

x="$(date)" #preload SCRIPT_START_TIMESTAMP
SCRIPT_START_TIMESTAMP="$x"

SCRIPT_START_TIMESTAMP_FORMATTED=\
"$(date --date "$SCRIPT_START_TIMESTAMP" +%Y%m%d-%H%M%S)"

SCRIPT_START_USER="$(whoami)" # will be 'root' if called with sudo
SCRIPT_START_SUDOUSER="$SUDO_USER" # find username from $SUDOUSER

x="$(pwd)" #preload SCRIPT_START_USER_DIR
SCRIPT_START_USER_DIR="$x" # record user's current working directory

x="$1"
if [ -n "$x" ];then SCRIPT_ARG1="$1-"; fi # log filename prefix

SCRIPT_NAME="$(basename $0)"
SCRIPT_NAME_FORMATTED="$(basename $0 .sh)" # remove .sh suffix
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )" # find script's current dir
SCRIPT_FILE="$SCRIPT_DIR/$SCRIPT_NAME"

SCRIPT_OUTPUT_DIR="$SCRIPT_DIR/$SCRIPT_NAME_FORMATTED-log"
SCRIPT_OUTPUT_FILE_PREFIX="$SCRIPT_ARG1"
SCRIPT_OUTPUT_FILE="script.log"
SCRIPT_OUTPUT_FULLPATH="$SCRIPT_OUTPUT_DIR\
/$SCRIPT_NAME_FORMATTED-$SCRIPT_START_TIMESTAMP_FORMATTED-\
$SCRIPT_OUTPUT_FILE_PREFIX\
$SCRIPT_OUTPUT_FILE"

# intended for use with 'echo -e'
SCRIPT_TEXT0="\e[0m" # text effect off
SCRIPT_TEXT1="\e[1m" # bold
SCRIPT_TEXT2="\e[4m" # underline
SCRIPT_TEXT3="\e[1;4m" # bold, underline
SCRIPT_TEXT10="\e[1;4;35m" # bold, underline, purple

# set location of unbuffer binary - remain empty if none found
# unbuffer is useful for enabling color output to terminal from script
SCRIPT_UNBUFFER="$(command -v unbuffer)"

#-- GLOBAL FUNCTIONS -----------------------------------------------------------

# SCRIPT_CHECK function provides error handling and takes arguments of:
#     1. exist *NOTE: full condition syntax TBD
#     2. directory/file/parameter
#     3. [filename]
# Example: SCRIPT_CHECK "exist" "directory" "/var/log"
SCRIPT_CHECK() {
    script_check-error_exit() {
        SCRIPT_SAY "  ERROR: $1" "" "" "\n\n"
        SCRIPT_EXIT 1    
    }

    script_check-directory_exist() {
        if [ ! -d "$3" ]; then
            script_check-error_exit "$3 $2 not found."
        fi
    }

    script_check-file_exist() {
        if [ ! -f "$3" ]; then
           script_check-error_exit "$3 $2 not found."
        fi
    }

    script_check-$2_$1 "$@" # call indicated sub function and pass
                            # all parent function parameters
}


# SCRIPT_EXIT function allows for descriptive exit
SCRIPT_EXIT() {
    if [ "$1" = "0" ]; then
        exit 0
    else
        SCRIPT_SAY "  Exiting..." "" "" "\n\n"
        exit 1
    fi
}


# SCRIPT_DISPLAY_HEADER function displays an informative header
SCRIPT_DISPLAY_INFO_BANNER() {
    local arg1="$1"

    SCRIPT_SAY "Script:" "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$SCRIPT_FILE" "" 2 "\n\n"
    SCRIPT_SAY "Hostname:" "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$(hostname)" "" 1 "\n\n"
    SCRIPT_SAY "Release:" "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$(cat /etc/redhat-release)" "" 1 "\n\n"
    SCRIPT_SAY "Kernel:" "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$(uname -r)" "" 2 "\n\n"
    SCRIPT_SAY "Started:" "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$SCRIPT_START_TIMESTAMP" "" 1 "\n\n"
    SCRIPT_SAY "User:"  "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$SCRIPT_START_USER" "" 2 "\n\n"
    if [ -n "$SCRIPT_START_SUDOUSER" ]; then # display sudo user only if in use
        SCRIPT_SAY "Sudo User:" "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$SCRIPT_START_SUDOUSER" "" 1 "\n\n"
    fi
    SCRIPT_SAY "Logfile:"  "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$SCRIPT_OUTPUT_FULLPATH" "" 1 "\n\n"
    if [[ $arg1 = "complete" ]]; then # display completion line only if requested
        SCRIPT_SAY "Completed:"  "$SCRIPT_TEXT10" 1 && SCRIPT_SAY "$(date)" "" 1 "\n\n"
    fi
}


# SCRIPT_PREP_ENV function prepares script environment
SCRIPT_PREP_ENV() {
    SCRIPT_SAY "  Preparing script environment..." "$SCRIPT_TEXT1" "0" "\n\n"

    # check for root privileges if required.
    if [[ $SCRIPT_REQUIRE_ROOT == "yes" && $EUID != 0 ]]; then
        SCRIPT_SAY "  ERROR: Script requires root privileges." "" "" "\n\n"
        SCRIPT_EXIT 1
    fi

    # check for log directory, create if missing, verify creation, exit on fail.
    if [ ! -d $SCRIPT_OUTPUT_DIR ]; then
        mkdir -p $SCRIPT_OUTPUT_DIR
        sleep 1
        SCRIPT_CHECK "exist" "directory" "$SCRIPT_OUTPUT_DIR"
    fi

    # create log file, verify creation, exit on fail.
    touch $SCRIPT_OUTPUT_FULLPATH
    sleep 1
    SCRIPT_CHECK "exist" "file" "$SCRIPT_OUTPUT_FULLPATH"
}


# SCRIPT_READ_SOURCE funtion reads script source prefixed with identifying header
SCRIPT_READ_SOURCE() {
    printf "\n\n\n\n\n\n\n\n"
    printf "################################################################################\n"
    printf "#                              SCRIPT SOURCE                                   #\n"
    printf "################################################################################\n"
    printf "\n\n\n\n"
    cat $SCRIPT_FILE
}


# SCRIPT_SAY function outputs formatted text
# Use: SCRIPT_SAY [string] [style] [indent] [closing]
# Example: SCRIPT_SAY "hello world" "$SCRIPT_TEXT10" "2" "\n"
SCRIPT_SAY() {
    local arg1="$1"
    local arg2="$2"
    local arg3="$3"
    local arg4="$4"

    local string=""
    local indent=""
    local style_on=""
    local style_off=""
    local closing=""

    if [ -v arg1 ]; then
        string="$arg1"
        # if arg 2 exist, set style_on variable to match 
        if [ -v arg2 ]; then
            style_on="$arg2"
            style_off="$SCRIPT_TEXT0"
        
            # if arg 3 exist, add matching quantity of escape tab to style variable
            if [ -v arg3 ]; then
                for i in $(seq 1 $arg3); do
                    indent="$indent\t"
                done
                if [ -v arg4 ]; then
                    closing="$arg4" 
                fi
            fi
        fi
        # print formatted string
        printf "${indent}${style_on}${string}${closing}${style_off}"
    else
        printf "USAGE: $0 [string] [style] [indent] [closing]"
        SCRIPT_EXIT 0
    fi
}


#-- MAIN FUNCTION --------------------------------------------------------------

SCRIPT_MAIN() {

    # call SCRIPT_DISPLAY_INFO_BANNER function
    SCRIPT_DISPLAY_INFO_BANNER

    SCRIPT_SAY "  Begin main script function..." "$SCRIPT_TEXT1" "0" "\n\n"
    SCRIPT_SAY "Change directory to: $SCRIPT_DIR" "" "1" "\n\n"
    cd $SCRIPT_DIR

    # call CUSTOM_CODE function
    CUSTOM_CODE

    # clean up
    SCRIPT_SAY "Change directory back to: $SCRIPT_START_USER_DIR" "" "1" "\n\n"
    cd $SCRIPT_START_USER_DIR

    # call SCRIPT_DISPLAY_INFO_BANNER function with complete arg
    SCRIPT_DISPLAY_INFO_BANNER "complete"
}


#-- CUSTOM CODE ----------------------------------------------------------------

    # CUSTOM_CODE function braces should contain all custom code
    CUSTOM_CODE() {

    ### ADD FURTHER ACTIONS HERE ###

}


#-- EXECUTE --------------------------------------------------------------------

# open script with line break
printf "\n\n"

# call SCRIPT_PREP_ENV function 
SCRIPT_PREP_ENV

# call SCRIPT_MAIN function and log output to file
SCRIPT_MAIN | tee $SCRIPT_OUTPUT_FULLPATH

# call SCRIPT_READ_SOURCE function and log output to file
SCRIPT_READ_SOURCE >> $SCRIPT_OUTPUT_FULLPATH

# call SCRIPT_EXIT function
SCRIPT_EXIT 0
