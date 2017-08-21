#!/usr/bin/env bash

# TODO: Bianca Tamayo (Aug 16, 2017) -- Read generic args & spit out parsed formatted text

# Functions that start with _ have their echos used by other functions.

# This can/should be moved to config files. @TODO: Bianca Tamayo (Jul 31, 2017)

long_program_desc="Ansibuddy is a CLI tool for ansible-playbook."

# c: check, x: debug, s: show hosts
_stackable_flags="cxs" # These can be stacked as they're flags

arg_help_keys=("<hostgroup>" "<playbook>")
options_help_keys=("-i <file>, --inventory <file>" "-p <file>, --playbook <file>")
flags_help_keys=("-x, --debug" "-c, --check" "-s, --list-hosts")
command_help_keys=("check" "debug" "help" "version" "list-hosts")
other_keywords_help_keys=("inventory-file" "playbook-file" "ansible-playbook-args" "hostgroup" "playbook")

# ----------------------------------------------------------------

# Argument defaults: Positional
_positionals=()

# Positional vars:
_arg_positional_inventory=
_arg_positional_playbook=

# Argument defaults: Optionals
_arg_named_inventory_file=
_arg_named_playbook_file=

# Formatting Defaults
leftpad_length="0"
col_spacing_length=
fmt_str_main=
fmt_str_condensed=

# Formatting flags
print_condensed_version=
print_aligned_right=

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

        fmt_str_main=$fmt_str_condensed
        
        # Check if it has a newline (if arr.length > 0)
        for index in "${!_arr[@]}"; do
            # If it's the last string in the array (e.g. --inventory <file>), print the help text that goes 
            # along with it ($2). Otherwise, just print the option (i.e. -i <file>), and a blank in lieu of $2
            if [[ $((index+1)) -eq "${#_arr[@]}" ]]; then
                printf "$fmt_str_main" "" "${_arr[index]}" "" "$2" # Print help string
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
    _gprintf "-- <args>" "Delimits between ANSIBUDDY args and ANSIBLE-PLAYBOOK args"
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


print_help_main() {
    build_help
    print_description_info
    print_usage_patterns
    print_options_help
    print_commands_help
    print_examples
    printf "\n\n" 
}

# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------

# Logic for arg parsing:

# Step 1: Filtering out known options, breaking at '--'

# While $# > 0:
# case statements catch all space-delimited tokens from "$@"
# If it starts with a recognized option, set that argument variable to the value (e.g. -i hosts -> _arg_hosts=hosts)
#  - ^ This has its own algorithm as well on how to extract the value[1]
#  - Each option has the following versions: short, long, short=, long=
#  - Each boolean option / flag has the following versions: long, short, short-stacked
#  - Short-stacked options have their own algorithm[2]
# If it's not caught by the 'case' statements yet (options), it falls through to 
# case '--': shift once, then dump the rest in the remainder args var. This will be passed directly to ansible-playbook
# case *: This does not match a known option, so we append it to the positionals array

# At the end of this algorithm, we have:
# Values for named arguments
# Remainder arguments (past '--')
# Positional arguments (): This includes any positional arguments that are required, optional subcommands, and unknown options

# Step 2: Parsing the positionals array
# For ansibuddy, the first two positionals are the hostgroup and the playbook
# While $# > 0:
# If it starts with '--', then we know it's an unknown option that was not caught earlier. Throw a fatal error and exit because we can't parse it.
# Otherwise, allocate positionals[0] to hostgroup, and positional[1] to playbook
# Try to make sense of the rest. If not possible, throw fatal error and exit.

# Step 3: Finalizing the argument values before handing control back to script logic
# For mutually exclusive parameters (denoted by (<>|<>)), implement collision logic: override first var? throw error? explicit set precendence? disregard second var?
# --- Print out warning^?

# Check if required vars are set. If not, throw fatal error and exit.
# If it is, hand contorl back to script.

# @NOTE @TODO: Bianca Tamayo (Aug 18, 2017) - Can filenames start with `-`? Add "" to accept literals in the future? Add escape chars?
# @NOTE @TODO: Bianca Tamayo (Aug 18, 2017) - Functionality to `break` for VERSION, HELP, etc. is not yet completed
# @NOTE @TODO: Bianca Tamayo (Aug 18, 2017) - Functionality for stacked short opts is a WIP
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------

# Version fn 
# TODO: Bianca Tamayo (Aug 21, 2017) - This is only a placeholder, add real fn later
version() {
    echo "Version: 0.1.0"
}

# die:
# $1 - message (string) - Optional: Message to display to user. Defaults to "Fatal"
# $2 - exitcode (number/string) - Optional: Exit code. Defaults to 1. Provide empty message string if you don't wish to use a message with an exit code.
die()
{
    local message=${1-"Fatal"}
    local rc=${2:-1}
    
    echo "${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: $message [err code: $rc]" >&2
    exit "$rc"
}

begins_with_short_option()
{
	local first_option _stackable_flags_all
    _stackable_flags_all=$_stackable_flags
	first_option="${1:0:1}"
	test "$_stackable_flags_all" = "${_stackable_flags_all/$first_option/}" && return 1 || return 0
}

# Processes the $_positionals array after parse_commandline has been called
parse_positionals() {
    # Don't count min arg length here, that check will be done later. Just assign.
    if [[ ${_positionals[0]} != -* ]]; then _arg_positional_inventory=${_positionals[0]}; else die "Unknown option: '${_positionals[0]}'" 1; fi
    if [[ ${_positionals[1]} != -* ]]; then _arg_positional_playbook=${_positionals[1]};  else die "Unknown option: '${_positionals[1]}'" 1; fi
}

# _arg_named_inventory_file <- Path to file, passed with -i, take as is
# _arg_named_playbook_file <- Path to file, passed with -p, take as is 
# _debug_var_used_iflag, _debug_var_used_pflag <- Convenience booleans for debugging and testing
# _arg_flag_check, _arg_flag_debug, _arg_flag_list_hosts <- Flags
# _arg_positional_inventory <- Parse this value 
# _arg_positional_playbook <- Parse this value
# 
# Action commands that exit the program immediately: version, help
parse_commandline ()
{   
    while [[ $# -gt 0 ]] 
    do
        _key="$1"
        case "$_key" in
            -i|--inventory)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'" 1
                _arg_named_inventory_file="$2"
                _debug_var_used_iflag="true"
                shift
                ;;
            --inventory=*)
                _arg_named_inventory_file="${_key##--inventory=}" # Removes a prefix pattern from _key
                _debug_var_used_iflag="true"
                ;;
            -i*)
                _arg_named_inventory_file="${_key##-i}"
                _debug_var_used_iflag="true"
                ;;

            -p|--play)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'" 1
                _arg_named_playbook_file="$2"
                _debug_var_used_pflag="true"
                shift
                ;;
            --play=*)
                _arg_named_playbook_file="${_key##--play=}"
                _debug_var_used_pflag="true"
                ;;
            -p*)
                _arg_named_playbook_file="${_key##-p}" # Matches -p=FILENAME.txt. $_arg_named_playbook_file -> =FILENAME.txt
                _debug_var_used_pflag="true"
                ;;
            
            ## Short options (stackable) bools
            -c|--check)
                _arg_flag_check="true"
                ;;
            -c*)
                _arg_flag_check="true"
                _next="${_key##-c}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    begins_with_short_option "$_next" && shift && set -- "-c" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option" 1
                fi
                ;;

            -x|--debug)
                _arg_flag_debug="true"
                ;;
            -x*)
                _arg_flag_debug="true"
                _next="${_key##-x}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    begins_with_short_option "$_next" && shift && set -- "-x" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option" 1
                fi
                ;;

            -s|--list-hosts)
                _arg_flag_list_hosts="true"
                ;;
            -s*)
                _arg_flag_list_hosts="true"
                _next="${_key##-s}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    begins_with_short_option "$_next" && shift && set -- "-s" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option" 1
                fi
                ;;

            # Actions
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

            --) shift; break;;
            *)
                _positionals+=("$1")
                ;;
        esac
        shift
    done

    remainder_args=$*

    # Parse the positionals
    parse_positionals
}

echo ""
echo "---------"
echo "[INPUT]:" "$0" "$@"
echo "---------"


parse_commandline "$@"
# print_help_main # For nodemon

# This is for human debugging
echo ""
echo ""
echo "--- OUTPUT ---"
echo ""
echo "Positionals (only host.group, playbook, commands. Also extra ap flags if past '--'):"
echo "${_positionals[@]}"
echo ""
printf "PositionalInventoryHostgroup: %s\n" "$_arg_positional_inventory"
printf "PositionalPlaybook: %s\n" "$_arg_positional_playbook"
echo "Inventory file:" "${_arg_named_inventory_file[@]}"
echo "Playbook file:" "${_arg_named_playbook_file[@]}"
echo "Remainder args:" "${remainder_args[*]}"
echo "---------"
echo "---------"
echo "---------"
echo "---------"


# This is for automated testing (uses regex):
oifs=$IFS
IFS=''
printf "Positionals: %s | " "${_positionals[@]}"
printf "PositionalInventoryHostgroup: %s | " "$_arg_positional_inventory"
printf "PositionalPlaybook: %s | " "$_arg_positional_playbook"
printf "Inventory file path: %s | " "${_arg_named_inventory_file[@]}"
printf "Playbook file path: %s | " "${_arg_named_playbook_file[@]}"
printf "Additional options: %s\n" "${remainder_args[*]}"
echo "Flag List hosts:" ${_arg_flag_list_hosts:-"false"}
echo "Flag Debug mode:" ${_arg_flag_debug:-"false"}
echo "Flag Check syntax:" ${_arg_flag_check:-"false"}

IFS=$oifs
