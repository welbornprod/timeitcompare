#!/bin/bash

# Compare code snippets with timeit using multiple interpreters.
# It will also do a single timeit run.

# -Christopher Welborn 07-05-2015
appname="timeit-compare"
appversion="0.2.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"

# Default python to use.
default_exename="python3"
function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [-e=executable...] [CODE...] [-- ARGS...]

    Options:
        CODE              : One or more code snippets to compare.
                            If no snippets are given, input is read from stdin.
                            You can force reading from stdin by passing -.
                            If a file name is given, it will be read and used.
        ARGS              : Extra arguments for timeit.
                            Must be last, and come after the -- separator.
        -e=exe,--exe=exe  : Executable to use. Default: $default_exename
                            This flag can be set multiple times.
                            All code snippets will be used once per executable.
        -h,--help         : Show this message and exit.
        -v,--version      : Show version and exit.
    "
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
    if [[ -n "$3" ]]; then
        echo "    Timing: $3"
    else
        echo "    Timing: $(trim_text "$2")"
    fi
    printf "        %s\n\n" "$("$1" -m timeit "${timeitargs[@]}" -- "$2")"
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
force_stdin=false
in_args=false
for arg
do
    if [[ $in_args == true ]]; then
        # Build timeit args.
        timeitargs=("${timeitargs[@]}" "$arg")
    elif [[ "$arg" == "--" ]]; then
        # All other args will be treated as timeit args.
        in_args=true
    elif [[ "$arg" == "-" ]]; then
        # Stdin will be used.
        force_stdin=true
    elif [[ "$arg" =~ ^(-h)|(--help)$ ]]; then
        print_usage ""
        exit 0
    elif [[ "$arg" =~ ^(-v)|(--version)$ ]]; then
        echo -e "$appname v. $appversion\n"
        exit 0
    elif [[ "$arg" =~ ^(-e)|(--exe)= ]]; then
        exeargname="${arg##*=}"
        if [[ -z "$exeargname" ]] || [[ "$exeargname" =~ ^(-e)|(--exe)$ ]]; then
            print_usage "Invalid executable arg: $arg"
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

# Use stdin if forced, or if no snippets or file names have been passed.
if [[ $force_stdin == true ]] || [[ (( ${#snippets} == 0 )) && (( ${#filenames} == 0 )) ]]; then
    [[ -t 0 ]] && echo -e "Reading lines from stdin until EOF (Ctrl + D)...\n"
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
    printf "\nUsing: %s %s\n" "$exename" "$(trim_text "${timeitargs[*]}")"
    # Read any files passed in.
    for fname in "${filenames[@]}"
    do
        time_code "$exename" "$(<"$fname")" "$fname"
    done
    # Use any snippets passed in.
    for code in "${snippets[@]}"
    do
        time_code "$exename" "$code"
    done
done
