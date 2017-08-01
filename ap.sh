#!/usr/bin/env bash

# http://docopt.org/

# Functions that start with _ have their echos used by other functions.

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
_arg_leftovers=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_inventory_file=
_arg_playbook_file=

long_program_desc="Ansibuddy is a CLI tool for ansible-playbook."

leftpad_length="4"
col_spacing_length="4"

stackable_flags="cxs" # These can be stacked as they're flags

arg_help_keys=("<hostgroup>" "<playbook>")
options_help_keys=("-i <file>, --inventory <file>" "-p <file>, --playbook <file>")
flags_help_keys=("-x, --debug" "-c, --check" "-s, --list-hosts")
command_help_keys=("check" "debug" "help" "version" "list-hosts")
other_keywords_help_keys=("inventory-file" "playbook-file" "ansible-playbook-args" "hostgroup" "playbook")


# Start general script

fmt_str_main=

declare -a arg_help_keys # Positional named args
declare -a options_help_keys # Options with args
declare -a flags_help_keys # Flags
declare -a action_help_keys  # Actions 
declare -a command_help_keys # Commands
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

	# "%4s %15s %s %s\n" "" "<hostgroup>" "Hostgroup you're targeting"
	
	local indent=%-"$leftpad_length"s
	local colspace=%-"$col_spacing_length"s

	echo "$indent $1 $colspace %s"
}

# Uses the main format string
_gprintf() {
	printf "$fmt_str_main" "" "$1" "" "$2" # TODO: Bianca Tamayo (Jul 31, 2017) - Should really improve this later.
}

# ------------------------------------------------------------------------

print_description_info() {
	printf "%s\n\n" "$long_program_desc"
}

# This doesn't need the extra printf formatting
print_usage_patterns() {
    printf "Usage:\n" 
    printf "%${leftpad_length}s %s %s\n" "" "$0" "help"
    printf "%${leftpad_length}s %s %s\n" "" "$0" "(<hostgroup> | [-i|--inventory] <file>) (<playbook> | [-p|--play] <file>) [<command>...] [-- [ansible-playbook-args]]" 
}

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
	fmt=$(_build_col_left "$mxl") # TODO: Bianca Tamayo (Jul 31, 2017) - Change to left?

	fmt_str_main="$fmt\n" # Since we're not changing it by section
}


# Shows the different Usage Patterns
# The only length factor here is the name of the script
# Accepts a format string as an argument
print_help_main() {
	build_help
	print_description_info
	print_usage_patterns
    
    print_options_help
    print_examples
    printf "\n\n"
}

print_options_help ()
{   
    printf "\n\n"
	_gprintf "<hostgroup>" "Hostgroup you're targeting"
	_gprintf "<playbook>" "Playbook you're targeting"
    printf "\n"
    _gprintf "-i <file>, --inventory <file>" "Override hostgroup and pass in inventory file (no default)"
    _gprintf "-p <file>, --playbook <file>" "Override provided playbook if present and pass in play path (no default)"
    printf "\n"
	_gprintf "-x, --debug" "Run in debug mode"
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
			-p|--play)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_playbook_file="$2"
				shift
				;;
			--play=*)
				_arg_playbook_file="${_key##--play=}"
				;;
			-p*)
				_arg_playbook_file="${_key##-p}" # Matches -p=FILENAME.txt. $_arg_playbook_file -> =FILENAME.txt
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
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
            --' '*) shift; echo "ANSIBLE ARGS:" "$@"; break;;
			*)
				_positionals+=("$1")
				;;
		esac
		shift
	done
	echo "BREAK-OUT";

    remainder_args=$*
}

echo ""
echo "---------"
echo "[INPUT]:" "$0" "$@"
echo "---------"

# parse_commandline "$@"

# find_max_length "${options_help_keys[@]}"
print_help_main

echo ""
# THE DEFAULTS INITIALIZATION - POSITIONALS
echo "Positionals:" "${_positionals[@]}"
echo "Leftovers:" "${_arg_leftovers[@]}"
# THE DEFAULTS INITIALIZATION - OPTIONALS
echo "Inventory file:" "${_arg_inventory_file[@]}"
echo "Playbook file:" "${_arg_playbook_file[@]}"
echo "Additional options:" "${remainder_args[*]}"
echo "---------"
