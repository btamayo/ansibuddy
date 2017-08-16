#!/usr/bin/env bash

# Formatting flags
print_condensed_version="true"
print_aligned_right=

# Functions that start with _ have their echos used by other functions.

# This can/should be moved to config files. @TODO: Bianca Tamayo (Jul 31, 2017)

long_program_desc="Ansibuddy is a CLI tool for ansible-playbook."

# c: check, x: debug, s: show hosts
stackable_flags="cxs" # These can be stacked as they're flags

arg_help_keys=("<hostgroup>" "<playbook>")
options_help_keys=("-i <file>, --inventory <file>" "-p <file>, --playbook <file>")
flags_help_keys=("-x, --debug" "-c, --check" "-s, --list-hosts")
command_help_keys=("check" "debug" "help" "version" "list-hosts")
other_keywords_help_keys=("inventory-file" "playbook-file" "ansible-playbook-args" "hostgroup" "playbook")

# ----------------------------------------------------------------

# Argument defaults: Positional
_positionals=()
_arg_leftovers=()
# Argument defaults: Optionals
_arg_inventory_file=
_arg_playbook_file=

# Formatting Defaults
leftpad_length="2"
col_spacing_length="2"
fmt_str_main=
fmt_str_condensed=

# Start general script

# Allow for different formatting per-section
declare -a arg_help_keys 			# Positional named args
declare -a options_help_keys 		# Options with args
declare -a flags_help_keys 			# Flags
declare -a action_help_keys  		# Actions 
declare -a command_help_keys 		# Commands
declare -a other_keywords_help_keys # Other things that need explaining

# Take in to consideration the locale. Going to assume that we're just doing normal UTF-8. 
# Useful information for string vs byte length:
# See: https://stackoverflow.com/questions/17368067/length-of-string-in-bash

# See: https://www.gnu.org/software/bash/manual/bashref.html#Shell-Parameter-Expansion
# ${#parameter}: The length in characters of the expanded value of parameter is substituted.

# See also: http://mywiki.wooledge.org/Bashism

# Accepts array as param, returns max length of strings in arr
_find_max_length() {
    local max=0
    while [[ $# -gt 0 ]]
    do	
        _word="$1"
        if [[ ${#_word} -gt $max ]]; then max=${#_word}; fi
        shift;
    done

    echo "$max"
}

# Accepts pad length as param
_build_col_right() {
    local fmt_str
    if [[ ! -z $1 ]]; then fmt_str=$(_build_colspaces "%$1s"); else fmt_str=$(_build_colspaces %-s); fi
    echo "$fmt_str"
}

# Accepts pad length as param
_build_col_left() {
    local fmt_str
    if [[ ! -z $1 ]]; then fmt_str=$(_build_colspaces "%-$1s"); else fmt_str=$(_build_colspaces %-s); fi
    echo "$fmt_str"
}

# Accepts a string as a param. This then surrounds the string
_build_colspaces() {
    # Padding length from the left (for indented lines, e.g. non-headers) + max of strs
    # leftpad_length + find_max_length(section array) + general spacing ($col_spacing_length) + Value String (The actual help string that goes with the keys)

    echo "%-${leftpad_length}s $1 %-${col_spacing_length}s %s"
}


# Uses the main format string
_gprintf() {

    if [[ $print_condensed_version == "true" ]]; then
        # Change commas to \n chars
        comma_tokens=$(sed $'s/, /\\\n/g' <<< "$1")

        # Check if it has a new line, for now let's assume it does: e.g. (-i <file>\n --inventory <file>)
        # Print the first one before the newline (.e.g -i <file>)
        # Convert to array
        _arr=()
        while read -r line; do
            _arr+=("$line")
        done <<< "$comma_tokens"

        # SWITCH TO CONDENSED VERSION HERE (@NOTE)
        fmt_str_main=$fmt_str_condensed
        
        # Check if it has a newline (if arr.length > 0)
        for index in "${!_arr[@]}"; do
            # If it's the last string in the array (e.g. --inventory <file>), print the help text that goes 
            # along with it ($2). Otherwise, just print the option (i.e. -i <file>), and a blank in lieu of $2
            if [[ $((index+1)) -eq "${#_arr[@]}" ]]; then
                printf "$fmt_str_main\n" "" "${_arr[index]}" "" "$2" # Print help string
            else
                printf "$fmt_str_main" "" "${_arr[index]}" "" ""  # Don't print help string
            fi
        done
    else
        printf "$fmt_str_main" "" "$1" "" "$2" 
    fi    
}

# ------------------------------------------------------------------------


# Build the usage
build_help() {
    local arg_keys=()
    declare -a arg_keys

    # Lol too much. Plan was to programatically build sections, but ¯\_(ツ)_/¯ maybe later
    # Quotes are important here since bash arrays are space delimited by default.
    arg_keys+=("${arg_help_keys[@]}")
    arg_keys+=("${options_help_keys[@]}")
    arg_keys+=("${flags_help_keys[@]}")
    arg_keys+=("${action_help_keys[@]}")
    arg_keys+=("${command_help_keys[@]}")
    arg_keys+=("${other_keywords_help_keys[@]}")
    
    local mxl
    local fmt

    mxl=$(_find_max_length "${arg_keys[@]}")

    # $mxl is the longest option combination (short + long format, e.g. "-i <file>, --inventory <file>")

    # Run through it again, but this time split it by comma so
    # we can format the column by the longest single option string instead of combined

    # Declare empty 
    local _opts_all
    declare -a _opts_all
    _ops_all=()             # String array of all options, including long and short options, used for
                            # when options are split by "," (e.g. "-i, --inventory")
    
                   
    for x in "${arg_keys[@]}"; do
        IFS=', ' read -r -a line <<< "$x" # Scopes IFS to this fn
        _opts_all+=("${line[@]}")
    done

    mxl_individual=$(_find_max_length "${_opts_all[@]}") # Longest singular option 

    if [[ "$print_aligned_right" == "true" ]]; then
        fmt=$(_build_col_right "$mxl")
        fmt_condensed=$(_build_col_right "$mxl_individual")
    else
        fmt=$(_build_col_left "$mxl")
        fmt_condensed=$(_build_col_left "$mxl_individual")
    fi
    
    fmt_str_condensed="$fmt_condensed\n" # Since we're not changing it by section, declare a/the main fmt str here.
    fmt_str_main="$fmt\n" # Since we're not changing it by section, declare a/the main fmt str here.
}

print_description_info() {
    printf "%s\n\n" "$long_program_desc"
}

# This doesn't need the extra printf formatting
print_usage_patterns() {
    printf "Usage:\n" 
    printf "%${leftpad_length}s %s %s\n" "" "$0" "[help | version]"
    printf "%${leftpad_length}s %s %s\n" "" "$0" "<hostgroup> <playbook> [options] [<command>...]" 
    printf "%${leftpad_length}s %s %s\n" "" "$0" "(<hostgroup> | -i <file>) (<playbook> | -p <file>) [options...] [<command>...] [-- [ansible-playbook-args]]" 
}

print_commands_help() {
    # command_help_keys=("check" "debug" "help" "version" "list-hosts")
    printf "Commands:\n" 
    _gprintf "check" "Check syntax [Also: -c, --check]"
    _gprintf "debug" "Debug mode [Also: -x, --debug]"
    _gprintf "list-hosts" "List hosts [Also: -s, --list-hosts]"
    _gprintf "help" "Print help and terminate [Also: -h, --help]"
    _gprintf "version" "Print version and terminate [Also: -v, --version]"
    printf "\n\n"
}

print_options_help()
{   
    printf "\n\n"
    _gprintf "<hostgroup>" "Hostgroup you're targeting"
    _gprintf "<playbook>" "Playbook you're targeting"
    printf "\n"
    _gprintf "-i <file>, --inventory <file>" "Override hostgroup and pass in inventory file (no default)"
    _gprintf "-p <file>, --playbook <file>" "Override provided playbook if present and pass in ansibuddy path (no default)"
    printf "\n"
    _gprintf "-x, --debug" "Run in debug mode"
    _gprintf "-c, --check" "Check syntax"
    _gprintf "-s, --list-hosts" "(S)how hosts, --list-hosts"


    printf "\n"
    _gprintf "-h, --help" "Prints help, then terminate"
    _gprintf "-v, --version" "Prints version, then terminate"
    _gprintf "-- <args>" "Delimits between PLAY args and ANSIBLE-PLAYBOOK args"
    _gprintf "... " "Remainder"
    printf "\n"
}

print_examples () {
    printf "Examples:\n"
    printf "%4s %s\n" "" "<hostgroup>: hostgroup you're targeting"
}

# Tokenize all input

# _next="${_key##-v}"
# if test -n "$_next" -a "$_next" != "$_key"
# then
# 	begins_with_short_option "$_next" && shift && set -- "-v" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
# fi
# ;;

buildbuild() {
    build_help
    # print_description_info
    # print_usage_patterns
    print_options_help
    # print_commands_help
    # print_examples
    printf "\n\n"
}

print_help_main() {
    buildbuild 
}

parse_commandline ()
{
    while [[ $# -gt 0 ]] 
    do
        _key="$1"
        echo $_key
        case "$_key" in
            -i|--inventory)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
                _arg_inventory_file="$2"
                shift
                ;;
            --inventory=*)
                _arg_inventory_file="${_key##--inventory=}" # Removes a prefix pattern from _key
                ;;
            -i*)
                _arg_inventory_file="${_key##-i}"
                ;;
            -p|--ansibuddy)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
                _arg_playbook_file="$2"
                shift
                ;;
            --ansibuddy=*)
                _arg_playbook_file="${_key##--ansibuddy=}"
                ;;
            -p*)
                _arg_playbook_file="${_key##-p}" # Matches -p=FILENAME.txt. $_arg_playbook_file -> =FILENAME.txt
                ;;
            ## Short options (stackable) bools
            -c|--check)
                _arg_check="on"
                ;;
            -c*)
                _arg_check="on"
                _next="${_key##-c}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    begins_with_short_option "$_next" && shift && set -- "-c" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            -h|--help)
                print_help_main
                exit 0
                ;;
            -h*)
                print_help_main
                exit 0
                ;;
            -v|--version)
                version
                exit 0
                ;;
            -v*)
                version
                exit 0
                ;;
            --debug)
                usage
                exit 0
                ;;
            --' '*) shift; break;; # Covers cases like --unknownoption -- -l 
            *)
                _positionals+=("$1")
                ;;
        esac
        shift
    done

    remainder_args=$*
}

echo ""
echo "---------"
echo "[INPUT]:" "$0" "$@"
echo "---------"

# parse_commandline "$@"
print_help_main # For nodemon

# _arg_check, _arg_debug, _arg_list_hosts

# find_max_length "${options_help_keys[@]}"

echo ""
echo "Positionals:" "${_positionals[@]}"
echo "Leftovers:" "${_arg_leftovers[@]}"

echo "Inventory file:" "${_arg_inventory_file[@]}"
echo "Playbook file:" "${_arg_playbook_file[@]}"
echo "Additional options:" "${remainder_args[*]}"
echo "---------"
