#!/bin/bash
# SIT-20200822
# name: termlogger.sh
# description: termlogger.sh records all terminal session activity.
#              see "termlogger.sh --help" for more info.
#!/bin/bash
# SIT-20200822
# name: termlogger.sh
# description: termlogger.sh records all terminal session activity.
#              see "termlogger.sh --help" for more info.

### GENERAL VARS ###

enable_quiet=no # yes/no - suprress script logging messages
enable_compress=yes # yes/no - compress output files on exit

### ADVANCED VARS ###

x="$(date --rfc-3339=ns)" # preload dtstamp including nanoseconds
dtstamp="${x}"
dtstamp_fmt1="$(date --date "$dtstamp" +%Y%m%d.%H%M%S.%N)"
dtstamp_fmt2="$(date --date "$dtstamp" +%Y%m)"

filename="$(hostname).$(whoami).${dtstamp_fmt1}"

output_dir="${HOME}/.termlogger"
tgz_file="${output_dir}/${filename}.tgz"
ts_file="${output_dir}/${filename}.ts"
ts_timing_file="${output_dir}/${filename}.ts-timing"

### TRAPS ###

# remove the termlogger_runonce variable on exit
trap "func_exit" EXIT

### FUNCTIONS ###

func_prereq() {
# script prerequisites

   # set script_cmd_vars as indicated above
   if [ "${enable_quiet}" = "yes" ]; then
      export script_cmd_vars="-q "
   fi

   # create required output directory
   mkdir -p "${output_dir}"

   # create required files
   touch "${ts_file}" "${ts_timing_file}"

   # verify required files exist
   if [ ! -f "${ts_file}" ] || [ ! -f "${ts_timing_file}" ]; then

      echo "

      ERROR: Unable to access required files: ${ts_file}
      					      OR
					      ${ts_timing_file}

      "

      exit 1

   fi

}

func_print_help() {
# print help message

   echo "

   termlogger.sh records all terminal session activity to ${output_dir}.
   it is intended to be invoked automatically via $HOME/.bashrc, or similar.
   to replay a saved session, use 'scriptreplay'.

   e.g.: scriptreplay -t \"$ts_timing_file\" \"$ts_file\"
   
   "

}

func_print_usage() {
# print usage message

   echo "

   USAGE: $0 --help

   "

}

func_runonce() {
# ensure this is the first run, exit if not true
# prevents script loop when initiated within subshell

   if [ -v termlogger_runonce ]; then
      exit 1;
   else
      export termlogger_runonce="1"
   fi

}

func_exit() {
# actions to complete on script exit

    unset termlogger_runonce

    # if compress enabled and #ts_file exists, compress output files
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
                printf "\n\n   Log file written to: ${tgz_file}\n\n"
            else
	        printf "\n\n   Log files written to: ${ts_file}\n\t\t\t ${ts_timing_file}\n\n"
	    fi
        fi
    fi

}

### MAIN ###

# call functions

# if invoked with argument
if [ -n "${1}" ]; then
    if [ "${1}" = "-h" ]  || [ "${1}" = "-help" ]  || [ "${1}" = "--help" ]; then
        func_print_help
        exit 0
    else
        func_print_usage
        exit 1
    fi
fi

func_runonce

func_prereq

# define script command
script_cmd="script "${script_cmd_vars}" --flush --timing="${ts_timing_file}" "${ts_file}""

# execute script_cmd
${script_cmd}

#exit
exit 0

### GENERAL VARS ###

enable_quiet=no # yes/no - suprress script logging messages
enable_compress=no # yes/no - compress output files on exit

### ADVANCED VARS ###

x="$(date --rfc-3339=ns)" # preload dtstamp including nanoseconds
dtstamp="${x}"
dtstamp_fmt1="$(date --date "$dtstamp" +%Y%m%d.%H%M%S.%N)"
dtstamp_fmt2="$(date --date "$dtstamp" +%Y%m)"

filename="$(hostname).$(whoami).${dtstamp_fmt1}"

output_dir="${HOME}/.termlogger"
tgz_file="${output_dir}/${filename}.tgz"
ts_file="${output_dir}/${filename}.ts"
ts_timing_file="${output_dir}/${filename}.ts-timing"

### TRAPS ###

# remove the termlogger_runonce variable on exit
trap "func_exit" EXIT

### FUNCTIONS ###

func_prereq() {
# script prerequisites

   # set script_cmd_vars as indicated above
   if [ "${enable_quiet}" = "yes" ]; then
      export script_cmd_vars="-q "
   fi

   # create required output directory
   mkdir -p "${output_dir}"

   # create required files
   touch "${ts_file}" "${ts_timing_file}"

   # verify required files exist
   if [ ! -f "${ts_file}" ] || [ ! -f "${ts_timing_file}" ]; then

      echo "

      ERROR: Unable to access required files: ${ts_file}
      					      OR
					      ${ts_timing_file}

      "

      exit 1

   fi

}

func_print_help() {
# print help message

   echo "

   termlogger.sh records all terminal session activity to ${output_dir}.
   it is intended to be invoked automatically via $HOME/.bashrc, or similar.
   to replay a saved session, use 'scriptreplay'.

   e.g.: scriptreplay -t \"$ts_timing_file\" \"$ts_file\"
   
   "

}

func_print_usage() {
# print usage message

   echo "

   USAGE: $0 --help

   "

}

func_runonce() {
# ensure this is the first run, exit if not true
# prevents script loop when initiated within subshell

   if [ -v termlogger_runonce ]; then
      exit 1;
   else
      export termlogger_runonce="1"
   fi

}

func_exit() {
# actions to complete on script exit

    unset termlogger_runonce

    if [ "${enable_compress}" == "yes" ]; then
        tar cpzf "${tgz_file}" --remove-files "${ts_timing_file}" "${ts_file}" > /dev/null 2>&1
    fi

    if [ "${enable_quiet}" != "yes" ]; then
        if [ "${enable_compress}" == "yes" ]; then
            printf "\n\n   Log file written to: ${tgz_file}\n\n"
        else
	    printf "\n\n
	Log files written to: ${ts_file}
	                      ${ts_timing_file}\n\n"
	fi
    fi

}

### MAIN ###

# call functions

# if invoked with argument
if [ -n "${1}" ]; then
    if [ "${1}" = "-h" ]  || [ "${1}" = "-help" ]  || [ "${1}" = "--help" ]; then
        func_print_help
        exit 0
    else
        func_print_usage
        exit 1
    fi
fi

func_runonce

func_prereq

# define script command
script_cmd="script "${script_cmd_vars}" --flush --timing="${ts_timing_file}" "${ts_file}""

# execute script_cmd
${script_cmd}

# exit
exit 0
