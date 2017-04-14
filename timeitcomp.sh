#!/bin/bash

# Compare code snippets with timeit using multiple interpreters.
# It will also do a single timeit run.

# -Christopher Welborn 07-05-2015
appname="Timeit-Compare"
appversion="0.5.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appdir="${apppath%/*}"
appscript="${apppath##*/}"

if [[ -f "$appdir/colr.sh" ]]; then
    # shellcheck source=/home/cj/scripts/bash/timeitcompare/colr.sh
    source "$appdir/colr.sh"
else
    function colr {
        echo -n "$1"
    }
fi

# Default python to use, in their preferred order.
default_exename=""
declare -a python_exes=("python3" "python2" "python")
for try_py_exe in "${python_exes[@]}"; do
    if hash "$try_py_exe" &>/dev/null; then
        default_exename="$try_py_exe"
        break
    fi
done


function echo_err {
    # Echo to stderr, with color.
    echo -e "$(colr "$*" "red")" 1>&2
}

function echo_lbl {
    # Echo a formatted lbl: value pair to stdout.
    local lbl=$1
    shift
    echo -e "$(colr "$lbl" "cyan"): $*"
}

function echo_lbl_err {
    # Echo a formatted lbl: value pair to stderr.
    local lbl=$1
    shift
    echo -e "$(colr "$lbl" "red"): $(colr "$*" "magenta")" 1>&2
}

function fail {
    # Print a message to stderr and exit with an error status code.
    echo_err "$@"
    exit 1
}

function fail_usage {
    # Print a usage failure message, and exit with an error status code.
    print_usage "$@"
    exit 1
}

function first_line {
    # Get the first non-blank line from some text.
    awk '/\w/ { print; exit}' <<<"$1"
}

function format_code {
    # Formats code for terminal printing.
    # Uses 'highlight' if available, then 'pygmentz', then 'ccat'.
    # If no highlighting program is available, it is simply colorized with
    # colr.sh.
    # Arguments:
    #   $1 : The code snippet to highlight.
    [[ -n "$1" ]] || {
        echo_err "No code given for format_code."
        return 1
    }
    colr_is_disabled && {
        # No highlighting when color is disabled.
        printf "%s" "$1"
        return 0
    }
    if hash highlight &>/dev/null; then
        highlight --style=molokai --syntax=python --out-format=xterm256 <<<"$1"
    elif hash pygmentize &>/dev/null; then
        pygmentize -l python3 -f terminal256 -O 'style=monokai' <<<"$1"
    elif hash ccat &>/dev/null; then
        ccat -c -s monokai -l python3 <<<"$1"
    else
        colr "$1" "green"
    fi
}

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
    # Flags already used by timiet: -c -h -n -p -r -s -t -u -v
    # shellcheck disable=SC2154
    echo "${fore[lightblue]}${style[bright]}$appname v. $appversion${style[reset]}

    Usage:${fore[lightmagenta]}
        $appscript -h | -v
        $appscript [-e=exe...] [-s code...] [CODE...] [options] [-- ARGS...]${style[reset]}"
    # Print full usage when no reason-arg is given.
    if [[ -z "$1" ]]; then
        echo "
    Options:${fore[lightgreen]}
        CODE                  : One or more code snippets to compare.
                                If a file name is given, it will be read.
                                You can force reading from stdin by passing -.
                                Default: stdin
        ARGS                  : Extra arguments for timeit.
                                Must be last, and come after the -- separator.
        -C,--color            : Use colors, even when piping output.
        -e=exe,--exe=exe      : Executable to use. This flag can be set
                                multiple times. All code snippets will be used
                                once per executable.
                                Default: $default_exename
        -h,--help             : Show this message and exit.
        -N,--nocolor          : Disable colors.
        -o,--overhead         : Account for some of the overhead of using
                                timeit to run these snippets.
                                Times the execution of a simple 'pass'
                                statement for each executable, and subtracts
                                that from each snippet's run time.
        -s code,--setup code  : Setup code for timeit (same as timeit -s).
                                Can be used multiple times.
                                This can also be a file name to read setup
                                code from.
        -v,--version          : Show version and exit.
    ${style[reset]}"
    fi
}

function print_versions {
    # Print app name and version, possibly with dependency versions.
    echo "$appname v. $appversion"
    # shellcheck disable=SC2154
    # ..colr_app_name/version only available when colr.sh is sourced.
    if [[ -n "$colr_app_name" && -n "$colr_app_version" ]]; then
        local colrver
        colrver="$(colr "$colr_app_name v. $colr_app_version" "blue")"
        echo -e "    using $colrver"
    fi
    echo
}

function printf_err {
    # Printf, to stderr.
    # shellcheck disable=SC2059
    # ...using vars in printf on purpose.
    colr "$(printf "$@")" "red" 1>&2
}

function read_stdin {
    # Read lines from stdin, echo them out so they can be used with $().
    local saveifs="$IFS" line
    IFS=$'\n'
    while read -r line
    do
        echo "$line"
    done
    IFS="$saveifs"
}

function read_setup {
    # Read setup code form a file. Exits the program on error.
    local filename=$1 setuplines=""
    mapfile -t setuplines < "$filename"
    if ((${#setuplines[@]} == 0)); then
        echo_lbl_err "No setup code in" "$filename"
        return 1
    fi
    printf "%s\n" "${setuplines[@]}"
}

function time_code {
    # Time a snippet of code using a specific executable.
    # Arguments:
    #     $1 : Executable name.
    #     $2 : Code snippet.
    #     $3 : Optional display/file name for this snippet.
    #          Default: Trimmed code snippet text.
    #     $4 : Optional overhead time to subtract from total.
    local output
    local runtime
    if [[ -n "$3" ]]; then
        echo "    Timing: $(colr "$3" "cyan")"
    else
        echo "    Timing: $(format_code "$(trim_text "$2")")"
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
    # Output the first line of some text (up to maxwidth characters).
    # Add '...' if the text was trimmed.
    local firstline
    firstline="$(first_line "$1")"
    local maxwidth="${2:-40}"
    if (( ${#firstline} > maxwidth )) || [[ "$1" != "$firstline" ]]; then
        # Either the first line is too long, or it was multiline.
        printf "%s ..." "${firstline:0:$maxwidth}"
    else
        printf "%s" "$firstline"
    fi
}

function use_colors {
    # Determines whether color should be used, before or during regular arg
    # parsing. Must be given script arguments to help decide.
    [[ "$*" =~ (-C)|(--color) ]] && return 0
    [[ "$*" =~ (-N)|(--nocolor) ]] && return 1
    [[ -t 1 ]] && return 0
    return 1
}

declare -a exenames
declare -a filenames
declare -a snippets
declare -a timeitargs timeitargs_display
force_stdin=0
use_overhead=0
in_args=0
in_setup=0
auto_disable_colors=1
for arg; do
    if (( in_args )); then
        # Build timeit args.
        timeitargs+=("$arg")
        timeitargs_display+=("$arg")
    elif (( in_setup )); then
        # -s flag was passed early, grab this for setup.
        if [[ -e "$arg" ]]; then
            # Setup content was a file name, grab it's content.
            echo_lbl "Reading setup code from" "$arg"
            timeitargs_display+=("$(trim_text "$arg" 60)")
            if ! arg=$(read_setup "$arg"); then
                exit 1
            fi
        else
            # Setup content was a code snippet.
            if use_colors "$@"; then
                timeitargs_display+=("$(format_code "$(trim_text "$arg" 60)")")
            else
                # No highlighting for setup snippet.
                timeitargs_display+=("$(trim_text "$arg" 60)")
            fi
        fi
        timeitargs+=("$arg")
        in_setup=0
    elif [[ "$arg" == "--" ]]; then
        # All other args will be treated as timeit args.
        in_args=1
    elif [[ "$arg" == "-" ]]; then
        # Stdin will be used.
        force_stdin=1
    elif [[ "$arg" =~ ^(-C)|(--color)$ ]]; then
        auto_disable_colors=0
    elif [[ "$arg" =~ ^(-h)|(--help)$ ]]; then
        print_usage ""
        exit 0
    elif [[ "$arg" =~ ^(-N)|(--nocolor)$ ]]; then
        colr_disable
    elif [[ "$arg" =~ ^(-o)|(--overhead)$ ]]; then
        use_overhead=1
    elif [[ "$arg" =~ ^(-s)|(--setup)$ ]]; then
        timeitargs+=("-s")
        timeitargs_display+=("-s")
        in_setup=1
    elif [[ "$arg" =~ ^(-v)|(--version)$ ]]; then
        print_versions
        exit 0
    elif [[ "$arg" =~ ^(-e)|(--exe)= ]]; then
        exeargname="${arg##*=}"
        if [[ -z "$exeargname" ]] || [[ "$exeargname" =~ ^(-e)|(--exe)$ ]]; then
            echo_lbl_err "Invalid executable arg" "$arg"
            echo_lbl_err "    Expecting" "-e=executable"
            exit 1
        elif ! hash "$exeargname" &>/dev/null; then
            echo_lbl_err "\nNot a valid executable" "$exeargname"
            exit 1
        else
            exenames+=("$exeargname")
        fi
    else
        # Any non-flag arg before -- is a snippet of code or a filename.
        if [[ -e "$arg" ]]; then
            filenames+=("$arg")
        else
            snippets+=("$arg")
        fi
    fi
done
# Automatically disable colors for stdout and stderr.
((auto_disable_colors)) && colr_auto_disable 1 2

# Ensure at least one executable, and one code snippet.
if (( ${#exenames[@]} == 0 )); then
    if [[ -z "$default_exename" ]]; then
        echo_err "Cannot find any of the default python executables:"
        echo_err "$(printf "    %s\n" "${python_exes[@]}")"
        fail "\nYou can specify one with the -e flag."
    fi
    exenames=("$default_exename")
fi

# With no snippets or file names, stdin will be used.
do_stdin=$(( ${#snippets[@]} == 0 && ${#filenames[@]} == 0 ))
# Use stdin if forced, or if no snippets or file names have been passed.
if (( force_stdin || do_stdin )); then
    ([[ -t 0 ]] && [[ -t 1 ]]) && echo -e "Reading lines from stdin until EOF (Ctrl + D)...\n"
    snippets=("${snippets[@]}" "$(read_stdin)")
    # Stdin may not have produced any valid snippets.
    if (( ${#snippets} == 0 )) && (( ${#filenames} == 0 )); then
        fail_usage "No code to test!"
    fi
fi


# Run timeit for each snippet, once per executable.
for exename in "${exenames[@]}"; do
    exenamefmt="$(colr "$exename" "red")"
    timeitargsfmt="$(colr "${timeitargs_display[*]}" "magenta")"
    printf "\nUsing: %s %s\n" "$exenamefmt" "$timeitargsfmt"
    if ((use_overhead)); then
        printf "  %s\n" "$(colr "...calculating overhead time." "green")"
        if exeoverhead="$(get_overhead "$exename")"; then
            printf "  Overhead: %s\n" "$(format_time "$exeoverhead" "blue")"
        else
            printf_err "  %s\n" "Failed!"
        fi
    else
        exeoverhead=""
    fi
    # Read any files passed in.
    for fname in "${filenames[@]}"; do
        if ! time_code "$exename" "$(<"$fname")" "$fname" "$exeoverhead"; then
            exit 1
        fi
    done
    # Use any snippets passed in.
    for code in "${snippets[@]}"; do
        if ! time_code "$exename" "$code" "" "$exeoverhead"; then
            exit 1
        fi
    done
done
