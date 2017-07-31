#!/usr/bin/env bash

# Play: https://github.com/btamayo/play
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
    if [[ "$debug_mode" == "true" ]]; then printf "%s\n" "$@"; fi
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

    local help_text="
    USAGE
        $0 <HOSTGROUP> <PLAYBOOK> [<COMMAND>...] ...

    DESCRIPTION
        A wrapper script around ansible-playbook

    HOSTGROUP
        The HOSTGROUP is the group in the inventory file to target

    COMMAND
        check       Runs syntax-check on determined playbook
        list-hosts  Lists hosts affected by a playbook
        help        Print this help
    "

    echo "$help_text"
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

parse_inventory_arg() {
    if [[ ! -z "$inventory_file" ]]; then
        # Just go with it and let ansible fail
        hostsfile_final_path="$inventory_file"
    else
        # Parse hostgroup name
        IFS='.' read -ra tokens <<< "$hostgroup"

        # Try to find a group in the inventory that fits it
        # /inventories/{service}/{environment}/hosts then save the group
        # e.g. bianca-blog.dev.docker

        # Needs to be at least two, since we don't just deploy to "bianca-blog"
        if [[ "${#tokens[@]}" -gt 1 ]]; then
            # Parse by <service>.<env>
            service_name="${tokens[0]}"
            env_name="${tokens[1]}"

            # Remove first two els which are directories (Note that after the first two '.', this converts into parent>child groups. @TODO)
            grp=("${tokens[@]:2}")

            hostsfile_find_path="$inventory_base_dir/$service_name/$env_name"

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
        # @TODO: Bianca Tamayo (Jul 22, 2017) - Fallback to ansible find path
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

# Check if path is absolute
parse_playbook_arg() {

    if [[ ! -z "$playbook_file_set_by_user" ]]; then
        playbook_final_path="$playbook_final_path"
    elif [[ "$passed_playbook_file_name" = /* ]]; then
        playbook_final_path=$passed_playbook_file_name
    
    elif [[ "$passed_playbook_file_name" = ./* ]]; then
        
        playbook_find_dir=$passed_playbook_file_name

        # Maybe it's a path to an actual playbook
        if [[ -f "$playbook_find_dir" ]]; then
            playbook_final_path=$playbook_find_dir
        fi
    
    else
        # Start looking relative to playbook base dir, then to $pwd

        # Unless it's in the ansible ignore cfg
        # ./playbooks/{service_name}.yml > ./playbooks/{service_name}/
        check_file_paths=( "${playbook_base_dir}/${service_name}.yml" )
        check_file_paths+=( "${playbook_base_dir}/${service_name}.yaml" )

        service_playbook_base_path="${playbook_base_dir}/${service_name}"

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
        usage "FATAL: No playbook ${passed_playbook_file_name} found"
        # TODO: Bianca Tamayo (Jul 22, 2017) - Add skipping check existence
        exit 1
    fi
}


parse_args() {
    hostgroup="$1"; shift;

    if [[ -z "$hostgroup" ]]; then
        usage "ERROR: Missing hostgroup"
        exit 1;
    fi
    
    if [[ "$hostgroup" == "-i" ]]; then
        # Pass in inventory file
        shift;
        inventory_file="$1"
        shift;
    fi


    if [[ "$#" == 0 ]]; then
        # @TODO: Bianca Tamayo (Jul 22, 2017) - This contradicts the behavior of the default 'site.yml' playbook
        # since it can be ran with ./ap hostname 
        usage "ERROR: Missing playbook";
        exit 1;
    fi

    passed_playbook_file_name="$1"; shift;

    if [[ "$passed_playbook_file_name" == "-p" ]]; then
        # Pass in inventory file
        shift;
        playbook_file_set_by_user="$1"
        shift;
    fi

    # TODO: Bianca Tamayo (Jul 23, 2017) - arg parsing w/ short & long opts
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -b|--base)
                shift;
                update_paths "$1"
                shift;;
            debug)
                debug_mode="true"
                shift;;
            help)
                usage
                exit 0
                ;;
            check) ansible_append_flags+=("--syntax-check")
                shift
                ;;
            list-hosts) ansible_append_flags+=("--list-hosts")
                shift
                ;;
            --) shift; break; shift;;
            *) shift;;
        esac
    done

    remainder_args=$*

}

# ------- MAIN  -------
echo "DEBUG: [INPUT]" "$@"
echo ""
# Begin parse
parse_args "$@"


debug "DEBUG: [PWD]" "$PWD"
debug ""
debug "DEBUG: Passed hostgroup: $hostgroup"
debug ""
debug "DEBUG: Inventory path invoked with -i if any: $inventory_file"
debug ""
debug "DEBUG: Playbook path invoked with -p if any: $playbook_file_set_by_user" 
debug ""
debug "DEBUG: Passed playbook name or path: $passed_playbook_file_name"
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