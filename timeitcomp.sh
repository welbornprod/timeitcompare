#!/bin/bash

# Compare code snippets with timeit using multiple interpreters.
# It will also do a single timeit run.

# -Christopher Welborn 07-05-2015
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appdir="${apppath%/*}"

if [[ -f "$appdir/colr.sh" ]]; then
    source "$appdir/colr.sh"
else
    function colr {
        echo -n "$1"
    }
fi

appname="Timeit-Compare"
appversion="0.3.0"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"

# Default python to use.
default_exename="python3"


function format_time {
    # Format a float time (from timeit, or get_overhead), with Optional
    # color codes.
    local floatstr=$1
    local colorname="${2:-magenta}"
    colr "$(printf "%.3f" "$floatstr")" "$colorname"
}

function get_overhead {
    # Get baseline/overhead time for this machine/exe by simply using 'pass'.
    local exe=$1
    local timeitoutput
    timeitoutput="$("$exe" -m timeit)" || return 1
    parse_runtime "$timeitoutput"
}

function get_overhead_diff {
    # Subtract overhead from the final time.
    local total=$1
    local overhead=$2
    if [[ -z "$total" ]] || [[ -z "$overhead" ]]; then
        return 1
    fi
    echo "$total - $overhead" | bc
}

function parse_runtime {
    # Parse the timeit output to extract just the time.
    local timeitoutput=$1
    local basetime
    basetime="$(cut -d' ' -f6 <<<"$timeitoutput")" || return 1
    printf "%s" "$basetime"
}

function print_usage {
    # Print a 'reason' for showing the usage.
    [[ -n "$1" ]] && echo -e "\n$1\n"
    # shellcheck disable=SC2154
    echo "${fore[lightblue]}${style[bright]}$appname v. $appversion${style[reset]}

    Usage:${fore[lightmagenta]}
        $appscript -h | -v
        $appscript [-e=executable...] [-o] [CODE...] [-- ARGS...]${style[reset]}"
    # Print full usage when no reason-arg is given.
    if [[ -z "$1" ]]; then
        echo "
    Options:${fore[lightgreen]}
        CODE              : One or more code snippets to compare.
                            If no snippets are given, input is read from stdin.
                            You can force reading from stdin by passing -.
                            If a file name is given, it will be read and used.
        ARGS              : Extra arguments for timeit.
                            Must be last, and come after the -- separator.
                            This is where --setup can be passed.
        -e=exe,--exe=exe  : Executable to use. Default: $default_exename
                            This flag can be set multiple times.
                            All code snippets will be used once per executable.
        -h,--help         : Show this message and exit.
        -o,--overhead     : Account for some of the overhead of using timeit
                            to run these snippets.
                            Times the execution of a simple 'pass' statement
                            for each executable, and subtracts that from
                            each snippet's run time.
        -v,--version      : Show version and exit.
    ${style[reset]}"
    fi
}

function read_stdin {
    # Read lines from stdin, echo them out so they can be used with $().
    local saveifs="$IFS"
    local line
    IFS=$'\n'
    while read -r line
    do
        echo "$line"
    done
    IFS="$saveifs"
}

function time_code {
    # Time a snippet of code using a specific executable.
    # Arguments:
    #     $1 : Executable name.
    #     $2 : Code snippet.
    #     $3 : Optional display name for this snippet.
    #          Default: Trimmed code snippet text.
    #     $4 : Optional overhead time to subtract from total.
    local output
    local runtime
    if [[ -n "$3" ]]; then
        echo "    Timing: $(colr "$3" "green")"
    else
        echo "    Timing: $(colr "$(trim_text "$2")" "green")"
    fi
    if ! output="$("$1" -m timeit "${timeitargs[@]}" -- "$2" 2>&1)"; then
        printf "        %s\n\n" "$(colr "$output" "red")" 1>&2
        return 1
    fi
    runtime="$(parse_runtime "$output")"
    printf "        %s" "$(colr "$output" "blue")"
    if [[ -z "$4" ]]; then
        # No overhead calculations.
        echo -e "\n"
    else
        local realtime
        if realtime="$(get_overhead_diff "$runtime" "$4")"; then
            printf " (%s: %s)\n\n" "$(colr "actual" "blue")" "$(format_time "$realtime")"
        else
            # Failed to get real time.
            echo -e "\n"
        fi
    fi
}

function trim_text {
    # Output the first line of some text (up to 40 characters).
    # Add '...' if the text was trimmed.
    local firstline="${1%%$'\n'*}"
    if (( ${#firstline} > 40 )) || [[ "$1" != "$firstline" ]]; then
        echo "${firstline:0:40} ..."
    else
        echo "$firstline"
    fi
}

declare -a exenames
declare -a filenames
declare -a snippets
declare -a timeitargs
force_stdin=0
in_args=0
use_overhead=0

for arg
do
    if (( in_args )); then
        # Build timeit args.
        timeitargs=("${timeitargs[@]}" "$arg")
    elif [[ "$arg" == "--" ]]; then
        # All other args will be treated as timeit args.
        in_args=1
    elif [[ "$arg" == "-" ]]; then
        # Stdin will be used.
        force_stdin=1
    elif [[ "$arg" =~ ^(-h)|(--help)$ ]]; then
        print_usage ""
        exit 0
    elif [[ "$arg" =~ ^(-o)|(--overhead)$ ]]; then
        use_overhead=1
    elif [[ "$arg" =~ ^(-v)|(--version)$ ]]; then
        echo -e "$appname v. $appversion\n"
        exit 0
    elif [[ "$arg" =~ ^(-e)|(--exe)= ]]; then
        exeargname="${arg##*=}"
        if [[ -z "$exeargname" ]] || [[ "$exeargname" =~ ^(-e)|(--exe)$ ]]; then
            print_usage "Invalid executable arg: $arg\n    Expecting: -e=executable"
            exit 1
        elif ! which "$exeargname" &>/dev/null; then
            echo -e "\nNot a valid executable: $exeargname" 2>&1
            exit 1
        else
            exenames=("${exenames[@]}" "$exeargname")
        fi
    else
        # Any non-flag arg before -- is a snippet of code or a filename.
        if [[ -e "$arg" ]]; then
            filenames=("${filenames[@]}" "$arg")
        else
            snippets=("${snippets[@]}" "$arg")
        fi
    fi
done

# Ensure at least one executable, and one code snippet.
if (( ${#exenames[@]} == 0 )); then
    exenames=("$default_exename")
fi

do_stdin=$(( ${#snippets[@]} == 0 && ${#filenames[@]} == 0 ))
# Use stdin if forced, or if no snippets or file names have been passed.
if (( force_stdin || do_stdin )); then
    ([[ -t 0 ]] && [[ -t 1 ]]) && echo -e "Reading lines from stdin until EOF (Ctrl + D)...\n"
    snippets=("${snippets[@]}" "$(read_stdin)")
    # Stdin may not have produced any valid snippets.
    if (( ${#snippets} == 0 )) && (( ${#filenames} == 0 )); then
        print_usage "No code to test!"
        exit 1
    fi
fi


# Run timeit for each snippet, once per executable.
for exename in "${exenames[@]}"
do
    exenamefmt="$(colr "$exename" "red")"
    timeitargsfmt="$(colr "$(trim_text "${timeitargs[*]}")" "magenta")"
    printf "\nUsing: %s %s\n" "$exenamefmt" "$timeitargsfmt"
    if ((use_overhead)); then
        printf "  %s\n" "$(colr "...calculating overhead time." "green")"
        if exeoverhead="$(get_overhead "$exename")"; then
            printf "  Overhead: %s\n" "$(format_time "$exeoverhead" "blue")"
        else
            printf "  %s\n" "$(colr "Failed!" "red")"
        fi
    else
        exeoverhead=""
    fi
    # Read any files passed in.
    for fname in "${filenames[@]}"
    do
        if ! time_code "$exename" "$(<"$fname")" "$fname" "$exeoverhead"; then
            exit 1
        fi
    done
    # Use any snippets passed in.
    for code in "${snippets[@]}"
    do
        if ! time_code "$exename" "$code" "" "$exeoverhead"; then
            exit 1
        fi
    done
done
