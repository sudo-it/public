#!/bin/bash
# SIT-20200426

x="$(date --rfc-3339=ns)" # preload dtstamp including nanoseconds

dtstamp="${x}"
dtstamp_fmt1="$(date --date "$dtstamp" +%Y%m%d.%H%M%S.%N)"
dtstamp_fmt2="$(date --date "$dtstamp" +%Y%m)"

output_dir=~/".termlogger"

filename="$(hostname).$(whoami).${dtstamp_fmt1}"

ts_file="${output_dir}/${filename}.ts"
ts_timing_file="${output_dir}/${filename}.ts-timing"

# create required output directory
mkdir -p "${output_dir}"

# capture following terminal session to log
script --flush --timing="${ts_timing_file}" "${ts_file}"
