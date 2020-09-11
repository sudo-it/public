#!/bin/bash
# SIT-20200822
#
# name: termlogger.sh
# description: termlogger.sh records all terminal session activity.
#              see "termlogger.sh --help" for more info.
# notes: written for rhel7 and above.
#        (rhel6 '/usr/bin/script' does not support "--timing" option)

### USER OPTIONS ###

enable_quiet=no # yes/no - suppress script logging messages
enable_compress=yes # yes/no - compress output files

### ADVANCED VARS ###

x="$(date --rfc-3339=ns)" # date including nanoseconds
dtstamp="${x}"
dtstamp_fmt1="$(date --date "$dtstamp" +%Y%m%d.%H%M%S.%N)" # date format1
dtstamp_fmt2="$(date --date "$dtstamp" +%Y%m)" # date format2

output_dir="${HOME}/.termlogger"
output_filename="$(hostname).$(whoami).${dtstamp_fmt1}"

tgz_file="${output_dir}/${output_filename}.tgz"
ts_file="${output_dir}/${output_filename}.ts"
ts_timing_file="${output_dir}/${output_filename}.ts-timing"

### TRAPS ###

# trap exit signal and call func_exit
trap "func_exit" EXIT

### FUNCTIONS ###

func_prereq() {
# script prerequisites

   # set script_cmd_vars as indicated by user options
   if [ "${enable_quiet}" = "yes" ]; then
      export script_cmd_vars="-q "
   fi

   # create required output directory
   mkdir -p "${output_dir}"

   # create required files
   touch "${ts_file}" "${ts_timing_file}"

   # verify required files exist
   if [ ! -f "${ts_file}" ] || [ ! -f "${ts_timing_file}" ]; then

      printf "\n\tERROR: Unable to access required files:\n"
      printf "\t\t${ts_file}\n"
      printf "\t\t${ts_timing_file}\n\n"
      exit 1

   fi

}

func_print_help() {
# print help message

   printf "

   \e[4mtermlogger.sh\e[0m records all terminal session activity to ${output_dir}.
   it is useful any time you wish to record your terminal activity, and can be
   made to execute automatically via $HOME/.bashrc, or similar.
   to replay a saved session, use 'scriptreplay'.\n
   e.g.: scriptreplay -t "${ts_timing_file}" "${ts_file}"
   \n"

}

func_print_usage() {
# print usage message

   printf "

   USAGE: ${0} --help\n\n"

}

func_runonce() {
# ensure this is the first run, exit if not true
# prevents script loop when initiated within subshell

   if [ "${termlogger_runonce}" == "1" ]; then
      exit 1;
   else
      export termlogger_runonce="1"
   fi

}

func_exit() {
# actions to complete on script exit

    # ensure termlogger_runonce variable is cleared
    unset termlogger_runonce

    # if compress enabled and $ts_file exists, archive and compress output files
    if [ "${enable_compress}" == "yes" ] && [ -f "${ts_file}" ]; then
	    tar cpzf "${tgz_file}" --remove-files -C "${output_dir}" \
		         "$(basename ${ts_timing_file})" \
		       	 "$(basename ${ts_file})" \
			 > /dev/null 2>&1
    fi

    
    # if $ts_file or $tgz_file exist (will only exist if 'script_cmd' has been executed)
    # ...prevents displaying log output with 'help' message
    if [ -f "${ts_file}" ] || [ -f "${tgz_file}" ]; then
        # if quiet option enabled
        if [ "${enable_quiet}" != "yes" ]; then
            # if compress option enabled
            if [ "${enable_compress}" == "yes" ]; then
                printf "\tLog file written to: ${tgz_file}\n\n"
            else
                printf "\n\tLog files written to:\n"
		printf "\t\t${ts_file}\n"
		printf "\t\t${ts_timing_file}\n\n"
            fi
        fi
    fi

}

### MAIN ###

# if main script invoked with argument
if [ -n "${1}" ]; then
    # if argument is 'help'
    if [ "${1}" = "-h" ]  || [ "${1}" = "-help" ]  || [ "${1}" = "--help" ]; then
        # call print_help function and exit
        func_print_help
        exit 0
    else
        # otherwise call print_usage function and exit
        func_print_usage
        exit 1
    fi
fi

# call runonce function
func_runonce

# call prereq funtion
func_prereq

# define 'script' command
script_cmd="script "${script_cmd_vars}" --flush --timing="${ts_timing_file}" "${ts_file}""

# execute script_cmd
${script_cmd}

# exit script
exit 0
