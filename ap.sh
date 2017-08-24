#!/usr/bin/env bash

# Ansibuddy: https://github.com/btamayo/ansibuddy
# MIT License

# Copyright (c) 2017 Bianca Tamayo

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# -------------------------------------------------------------------------------

# @TODO: Bianca Tamayo (Aug 21, 2017) - Switch to unix `find` instead of looping?

# Load parseargs 
# @TODO: Bianca Tamayo (Aug 16, 2017) - Make sure this still works when you change context
rootdir="$(dirname "$0")"

. "$rootdir/usage.bash"

# "Constants"
base_folder=$PWD
inventory_dir_name="inventories"
playbook_dir_name="playbooks"
inventory_base_dir=$base_folder/$inventory_dir_name
playbook_base_dir=$base_folder/$playbook_dir_name

# Defaults
# default_playbook_file_name="site.yml"

# Script-specific commands like "check", "help", and "list-hosts"
ansible_append_flags=()

# The rest of the args to pass to ansible
remainder_args=()

# @SEE: https://github.com/ansible/proposals/issues/35 for possible ansible integration

# Functions
debug() {
    if [[ "$_arg_flag_debug" == "true" ]]; then printf "%s\n" "$@"; fi
}

update_paths() {
    local passed_base_dir="$1"

    # See if it's an absolute path
    if [[ "$passed_base_dir" = /* ]]; then
        base_folder=$passed_base_dir
    else
        # Relative to PWD
        base_folder=$base_folder/$passed_base_dir
    fi

    # Warn
    if [[ ! -d "$base_folder" ]]; then
        echo "WARN: $base_folder non-existent path or file"
    fi

    echo "DEBUG: Updated base folder: $base_folder"

    # TODO: Bianca Tamayo (Jul 23, 2017) - This can cause double // in prints, etc. affects polish
    inventory_base_dir=$base_folder/$inventory_dir_name
    playbook_base_dir=$base_folder/$playbook_dir_name
}

usage() {
    echo "$1"

    # local help_text="
    # USAGE
    #     $0 <HOSTGROUP> <PLAYBOOK> [<COMMAND>...] ...

    # DESCRIPTION
    #     A wrapper script around ansible-playbook

    # HOSTGROUP
    #     The HOSTGROUP is the group in the inventory file to target

    # COMMAND
    #     check       Runs syntax-check on determined playbook
    #     list-hosts  Lists hosts affected by a playbook
    #     help        Print this help
    # "

    # echo "$help_text"
}

find_inventory_in_paths() {

    if [[ ! -d "$hostsfile_find_path" ]]; then
        debug "DEBUG: $hostsfile_find_path does not exist"
    elif [[ -d "$hostsfile_find_path" && ! -f "$hostsfile_find_path/hosts" ]]; then
        debug "DEBUG: hosts file in $hostsfile_find_path does not exist"
    elif [[ -f "$hostsfile_find_path/hosts" ]]; then
        debug "DEBUG: Found hosts file in $hostsfile_find_path/hosts"
    fi

    # If it does exist, we're still gonna assign it and let ansible fail. ^ is for debugging only.
    hostsfile_final_path="$hostsfile_find_path/hosts"
}

# _arg_positional_inventory
# _arg_named_inventory_file
parse_inventory_arg() {
    if [[ ! -z "$_arg_named_inventory_file" ]]; then
        # Just go with it and let ansible fail
        hostsfile_final_path="$inventory_file"
    else
        debug "DEBUG: Determining correct inventory from '$_arg_positional_inventory'"
        # Parse hostgroup name
        IFS='.' read -ra tokens <<< "$_arg_positional_inventory"

        # Try to find a group in the inventory that fits it
        # /inventories/{service}/{environment}/hosts then save the group
        # e.g. bianca-blog.dev.docker

        # Needs to be at least two, since we don't just deploy to "bianca-blog"
        if [[ "${#tokens[@]}" -gt 1 ]]; then
            # Parse by <service>.<env>
            service_name="${tokens[0]}"
            env_name="${tokens[1]}"

            debug "DEBUG: Found service name: $service_name"
            debug "DENUG: Found env name: $env_name"

            # Remove first two els which are directories (Note that after the first two '.', this converts into parent>child groups. @TODO)
            grp=("${tokens[@]:2}")

            debug "DEBUG: <parent>.<child> hostgroups are:" "${grp[@]}"
            debug "DEBUG: Length of grp arr: ${#grp[@]}"

            hostsfile_find_path="$inventory_base_dir/$service_name/$env_name"

            # Search for inventory file
            find_inventory_in_paths

            debug "INFO: Limiting to host groups [${grp[*]}]"

            # For the rest, make them into groups
            # playgroups=$(printf ":&%s" "${grp[@]]}")
            playgroups=${grp}


        elif [[ "${#tokens[@]}" -eq 1 ]]; then
            # Just the service name or the env name for single projects

            # e.g. bianca-blog/hosts
            # e.g. dev/hosts

            # @TODO: Bianca Tamayo (Jul 22, 2017) - Handle custom inv files?

            dir_name="${tokens[0]}"
            hostsfile_find_path="$inventory_base_dir/$dir_name"

            find_inventory_in_paths
        fi

        # @TODO: Bianca Tamayo (Jul 22, 2017) - Handle cases like this: bianca-blog.dev.docker.webserver
        # bianca-blog.dev.docker&webserver
        # bianca-blog.dev&stage.docker&webserver

        # @TODO: Bianca Tamayo (Jul 22, 2017) - Create generator functions
        # @TODO: Bianca Tamayo (Jul 22, 2017) - Fallback to ansible find path: If hosts just cannot be found, don't add -i to the constructed ansible-playbook command so that ansible-playbook will take care of the missing argument
    fi
}

# Find playbook
# If the passed_playbook_file_name looks like a path, 
# find it in that path first relative to ./playbooks/ then relative to 
# basedir, unless it's absolute

find_playbook_in_paths() {
    local test_path

    for test_path in "${check_file_paths[@]}"; do
        if [[ -f "$test_path" ]]; then
            playbook_final_path="$test_path"
            debug "DEBUG: Playbook found in: $playbook_final_path"
            break;
        else
            debug "DEBUG: Playbook not found in: $test_path"
        fi
    done
}

# Playbook cases:
# 1. Passed with -p [_arg_named_playbook_file]
# 2. Passed without -p [_arg_positional_playbook]
#    2.1 Absolute path (starts with /)
#    2.2 Relative path (starts with ./, or has / in the middle of the string)
#    2.3 Plain name
#        2.3.1 Ends with '.yml' or '.yaml'
#        2.3.2 Does not end with YAML extension (Haven't figured out how to handle other exts yet)
# 3. Not provided at all.

# Check if path is absolute
# _arg_named_playbook_file
# _arg_positional_playbook
parse_playbook_arg() {
    # 1
    if [[ ! -z "$_arg_named_playbook_file" ]]; then
        debug "DEBUG: 1 Passed using -p, set as final path"
        debug "DEBUG: setting playbook_final_path to: $_arg_named_playbook_file"
        playbook_final_path="$_arg_named_playbook_file"

    # 2.1
    elif [[ "$_arg_positional_playbook" = /* ]]; then
        debug "DEBUG: 2.1 Passed without -p, absolute path"
        playbook_final_path=$passed_playbook_file_name
    
    # 2.2
    elif [[ "$_arg_positional_playbook" = ./* || "$_arg_positional_playbook" = */* ]]; then
        debug "DEBUG: 2.2 Passed without -p, relative path"
        playbook_find_dir=$_arg_positional_playbook

        # Maybe it's a path to an actual playbook
        if [[ -f "$playbook_find_dir" ]]; then
            playbook_final_path=$playbook_find_dir
        fi
    
    # 2.3
    elif [[ ! -z "$_arg_positional_playbook" ]]; then
        local specific_filename_given
        debug "DEBUG: 2.3 Passed without -p, not a path, plain name"

        if [[ $_arg_positional_playbook = *.yml || $_arg_positional_playbook = *.yaml ]]; then
            debug "DEBUG: 2.3.1 Ends with '.yml' or '.yaml'"
            specific_filename_given=$_arg_positional_playbook

            # If we have a specific filename given, we should honor that
            # Look for that filename in the service's playbook subdirectory
            service_playbook_base_path="${playbook_base_dir}/${service_name}"
            
            # Find that filename in the service's playbook folder 
            check_file_paths=( "${service_playbook_base_path}/${specific_filename_given}" )

            # Then try to find it in the main playbook folder
            check_file_paths+=("${playbook_base_dir}/${specific_filename_given}")

            # Run search
            find_playbook_in_paths

            # Exit if we can't find it. since they gave us a filename, let's not try to guess what the file itself should be
            if [[ ! -f "$playbook_final_path" ]]; then
                usage "FATAL: No playbook found in:  $playbook_final_path"
                # TODO: Bianca Tamayo (Jul 22, 2017) - Add skipping check existence
                exit 1
            fi
        else
            
            debug "DEBUG: 2.3.2 Does not end with YAML extension"

            # This could be a directory, subdirectory or a filename
            # 1. Search in service playbk dir -> if exist, use. if not exist, check if subdir. -> if subdir, check for matching service name or site.yml. 
            # 2. If not in subdir, go back out to main playbook dir and check if it's a playbook there or a subdir there, then do ^

            service_playbook_base_path="${playbook_base_dir}/${service_name}"

            check_file_paths=( "${service_playbook_base_path}/${_arg_positional_playbook}.yml" )
            check_file_paths+=( "${service_playbook_base_path}/${_arg_positional_playbook}.yaml" )

            local service_playbook_base_path_playbook_subdir # Possibly
            service_playbook_base_path_playbook_subdir="$service_playbook_base_path/$_arg_positional_playbook"
                echo "$service_playbook_base_path_playbook_subdir"

            if [[ -d $service_playbook_base_path_playbook_subdir ]]; then
                # 2. ./playbooks/bianca-blog/deploy/bianca-blog.yml
                # 3. ./playbooks/bianca-blog/deploy/deploy.yml
                # 4. ./playbooks/bianca-blog/deploy/site.yml

                check_file_paths+=("$service_playbook_base_path_playbook_subdir/$service_name.yml")
                check_file_paths+=("$service_playbook_base_path_playbook_subdir/$service_name.yaml")

                check_file_paths+=("$service_playbook_base_path_playbook_subdir/$_arg_positional_playbook.yml")
                check_file_paths+=("$service_playbook_base_path_playbook_subdir/site.yml")
            fi

            local playbook_base_dir_playbook_subdir # Possibly
            playbook_base_dir_playbook_subdir="$playbook_base_dir/$_arg_positional_playbook"
            if [[ -d $playbook_base_dir_playbook_subdir ]]; then
                # 5. ./playbooks/deploy/bianca-blog.yml
                # 6. ./playbooks/deploy/deploy.yml
                # 7. ./playbooks/deploy/site.yml

                check_file_paths+=("$playbook_base_dir_playbook_subdir/$service_name.yml")
                check_file_paths+=("$playbook_base_dir_playbook_subdir/$service_name.yaml")

                check_file_paths+=("$playbook_base_dir_playbook_subdir/$_arg_positional_playbook.yml")
                check_file_paths+=("$playbook_base_dir_playbook_subdir/site.yml")
            fi

            # Lastly
            check_file_paths+=("$playbook_base_dir/$_arg_positional_playbook.yml")
            check_file_paths+=("$playbook_base_dir/$_arg_positional_playbook.yaml")

            find_playbook_in_paths
        fi
    elif [[ -z "$_arg_positional_playbook" ]]; then
        debug "DEBUG: 3. Not provided at all."

        # Start looking relative to playbook base dir, then to $pwd

        # Unless it's in the ansible ignore cfg
        # ./playbooks/{service_name}.yml > ./playbooks/{service_name}/
        check_file_paths=( "${playbook_base_dir}/${service_name}.yml" )
        check_file_paths+=( "${playbook_base_dir}/${service_name}.yaml" )

        # Run block
        find_playbook_in_paths

        # If it found it, good, if not, update the search paths
        if [[ ! -f "$playbook_final_path" && -d "$service_playbook_base_path" ]]; then
            check_file_paths=("${service_playbook_base_path}/${service_name}.yml")
            check_file_paths+=("${service_playbook_base_path}/site.yml")

            # Run block again
            find_playbook_in_paths
        fi

        # If it's still not found
        # Check existence of extensionless playbook files
        if [[ ! -f "$playbook_final_path" ]]; then
            check_file_paths=( "${playbook_base_dir}/${service_name}" )
            check_file_paths+=("${service_playbook_base_path}/${service_name}")

            # Run block again
            find_playbook_in_paths
        fi
    fi

    # If it still can't find it, assign the final to the default and don't even bother checking if it's a file
    # if [[ ! -f "$playbook_final_path" ]]; then
    #     playbook_final_path="$default_playbook_file_name"
    # fi

    if [[ ! -f "$playbook_final_path" ]]; then
        usage "FATAL: No playbook found in:  $playbook_final_path"
        # TODO: Bianca Tamayo (Jul 22, 2017) - Add skipping check existence
        exit 1
    fi
}

# ------- MAIN  -------
echo "DEBUG: [INPUT]" "$@"
echo ""
# Begin parse
parse_commandline "$@"


# Variables processed by parse_commandline:
# Passed positionally:
# _arg_positional_inventory
# _arg_positional_playbook
#
# Passed with a named argument (e.g. --inventory):
# _arg_named_inventory_file
# _arg_named_playbook_file
#
# Flags:
# _arg_flag_list_hosts
# _arg_flag_debug
# _arg_flag_check
#
# All positionals:
# _positionals[@] (arr)
#
# All remaining args: 
# remainder_args[@] (arr) -- pass to ansible-playbook directly

echo "Positional inventory:" "$_arg_positional_inventory"
printf "Positional playbook: %s\n" "$_arg_positional_playbook"
echo ""
printf "Inventory file path: %s\n" "${_arg_named_inventory_file[@]}"
printf "Playbook file path: %s\n" "${_arg_named_playbook_file[@]}"
echo ""
echo "Flag List hosts:" ${_arg_flag_list_hosts:-"false"}
echo "Flag Debug mode:" ${_arg_flag_debug:-"false"}
echo "Flag Check syntax:" ${_arg_flag_check:-"false"}
echo ""
printf "Ansible playbook args: %s\n" "${remainder_args[*]}"

debug ""
debug "DEBUG: Base path is: $base_folder"
debug ""
debug "DEBUG: Passed Commands:" "${ansible_append_flags[*]}"


# Begin logic
parse_inventory_arg

# Find a playbook directory that has the same name as the service name

# If the playbook is specified and named exactly the same as the playbook in the directory, choose that play
# e.g. ./playbooks/bianca-blog.yml > ./playbooks/bianca-blog/bianca-blog.yml > ./playbooks/bianca-blog/site.yml
parse_playbook_arg

# ---------------------


# Construct the ansible command @TODO: Bianca Tamayo (Jul 22, 2017) - get rid of extra spaces
playbook_command="ansible-playbook "

construct_playbook_command() {
    # Parse the extra ansible commands and make that override everything
    # Clashes: -l, -i, not -p

    #-i $hostsfile_final_path $playbook_final_path ${ansible_append_flags[*]} ${remainder_args[*]}"

    local inv_param="-i $hostsfile_final_path "
    local playbook_param="$playbook_final_path "
    local limit_groups_param="-l $playgroups "
    local syntax_check_param="--syntax_check "
    local list_hosts_param="--list-hosts "

    local limit_arg_re="(-l|--limit)+"
    local check_syntax_re="(--syntax_check)+"
    local inventory_arg_re="(-i|--inventory-file)+"
    local list_hosts_re="(--list-hosts)+"

    

    if [[ "${remainder_args[*]}" =~ $inventory_arg_re ]]; then
        echo "WARN: --inventory-file argument passed by user as extra args"
        # Skip appending it then
        playbook_command=$playbook_command$playbook_param
    else
        playbook_command=$playbook_command$inv_param$playbook_param
    fi

    if [[ "${remainder_args[*]}" =~ $limit_arg_re ]]; then # And playgroups is ! -z
        echo "WARN: --limit argument passed by user as extra args"
        echo "PLAYGROUPS: $playgroups"

        if [[ -z "$playgroups" ]]; then
            # noop, just add it at the end
            echo ""
        else
            echo "playgroups: $playgroups" #TODO append
        fi
    else
        playbook_command=$playbook_command$limit_groups_param
    fi

    if [[ "${remainder_args[*]}" =~ $check_syntax_re || "${ansible_append_flags[*]}" =~ $check_syntax_re ]]; then
        echo "DEBUG: extra: --syntax_check flag passed by user as extra args"

        # If it's in the ansible-append-flags, then we append it, otherwise let it fall through
        if [[ "${ansible_append_flags[*]}" =~ $check_syntax_re ]]; then playbook_command=$playbook_command$syntax_check_param; fi
    fi

    if [[ "${remainder_args[*]}" =~ $list_hosts_re || "${ansible_append_flags[*]}" =~ $list_hosts_re ]]; then
        echo "DEBUG: extra: --list-hosts flag passed by user as extra args"

        # If it's in the ansible-append-flags, then we append it
        if [[ "${ansible_append_flags[*]}" =~ $list_hosts_re ]]; then playbook_command=$playbook_command$list_hosts_param; fi
    fi

    playbook_command=$playbook_command${remainder_args[*]}

    # May have to update this each time cli updates
}

construct_playbook_command

echo ""
echo "[EXEC]: $playbook_command"
echo ""

debug "DEBUG: Host group and child names: $playgroups"
debug "DEBUG: Additional options:" "${remainder_args[*]}"

# debug "DEBUG: Parsed env_name, service_name: $service_name, $env_name"
debug "DEBUG: Parsed groupname in host:" "${grp[@]}"
debug ""
# debug "DEBUG: Looking for inventory in: $hostsfile_find_path"
debug ""
debug "DEBUG: Playbook file: $passed_playbook_file_name"
debug ""

# TODO: Bianca Tamayo (Jul 22, 2017) - Add suppress prompt
if [[ "$debug_mode" == "true" ]]; then exit 0; fi

while true; do
    read -p "Continue? " yn
    case $yn in
        [Yy]* ) $playbook_command; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


# End of file