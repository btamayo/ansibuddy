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

# Load parseargs 
# @TODO: Bianca Tamayo (Aug 16, 2017) - Make sure this still works when you change context
rootdir="$(dirname "$0")"

# @TODO: Bianca Tamayo (Nov 17, 2017) - Change this copypasta, also fall through backup
# functions to handle failure. Also deleted windows part because I'm not supporting
# windows right now. Also should be in postinstall script, not run script.
# @TODO: Bianca Tamayo (Nov 17, 2017) - Check script in
# https://stackoverflow.com/a/33266819 for applicability
# @TODO: Bianca Tamayo (Nov 17, 2017) - Also requires paths to be reliable 
# and directory structure to remain the same

case "$OSTYPE" in
  solaris*) echo "SOLARIS" ;;
  darwin*)  rootdir="$(dirname $(readlink "$0"))" ;; # Change default for macOS
  linux*)   echo "LINUX" ;;
  bsd*)     echo "BSD" ;;
  msys*)    echo "WINDOWS" ;;
  *)        echo "unknown: $OSTYPE" ;;
esac

echo "DEBUG: rootdir for OS ($OSTYPE): $rootdir"


. "$rootdir/usage.bash"

# "Constants"
base_dir=$PWD
inventory_dir_name="inventories"
playbook_dir_name="playbooks"
inventory_base_dir=$base_dir/$inventory_dir_name
playbook_base_dir=$base_dir/$playbook_dir_name

# Defaults
default_playbook_file_name="site.yml"

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
        base_dir=$passed_base_dir
    else
        # Relative to PWD
        base_dir=$base_dir/$passed_base_dir
    fi

    # Warn
    if [[ ! -d "$base_dir" ]]; then
        echo "WARN: $base_dir non-existent path or file"
    fi

    echo "DEBUG: Updated base folder: $base_dir"

    # TODO: Bianca Tamayo (Jul 23, 2017) - This can cause double // in prints, etc. affects polish
    inventory_base_dir=$base_dir/$inventory_dir_name
    playbook_base_dir=$base_dir/$playbook_dir_name
}

find_inventory_in_paths() {
    # Find playbook in array $check_file_paths
    local test_path

    for test_path in "${find_inventory_paths[@]}"; do
        if [[ -f "$test_path" ]]; then
            hostsfile_final_path="$test_path"
            debug "DEBUG: Inventory file found in: $hostsfile_final_path"
            break;
        else
            debug "DEBUG: Inventory file not found in: $test_path"
        fi
    done
}

# _arg_positional_inventory
# _arg_named_inventory_file
parse_inventory_arg() {
    if [[ ! -z "$_arg_named_inventory_file" ]]; then
        # Just go with it and let ansible fail
        hostsfile_final_path="$base_dir/$_arg_named_inventory_file"
    else
        # If the inventory is positional in first place, warn the user and direct them 
        if [[ $_arg_positional_inventory =~ (.+\.yml|.+\.yaml) ]] 
        then
            echo "WARNING: '$_arg_positional_inventory' looks like a YAML file. Use '-p $_arg_positional_inventory' to omit the hosts parameter when passing in a playbook."
        fi

        debug "DEBUG: Determining correct inventory from '$_arg_positional_inventory'"
        # Parse hostgroup name
        IFS='.' read -ra tokens <<< "$_arg_positional_inventory"

        # Try to find a group in the inventory that fits it

        # {base_inventory_find_dir}/{service}/{env}/hosts
        # First check if it even has an inventory directory

        # {base_inventory_find_dir} can be $base_inventory_dir/$service_name/, $base_inventory_dir/, or $base_dir/$service_name/, or $base_dir (in order)
        service_name="${tokens[0]}"
        base_inventory_find_dir=$base_inventory_dir
        
        grp=("${tokens[@]:1}") # Chop off the groupchilds (minus the service_name)

        env_name="${tokens[1]}"

        find_inventory_paths=()

        # If $service_name is a dir, there might be /hosts
        find_inventory_paths+=( "$base_inventory_find_dir/$service_name/hosts" )
        find_inventory_in_paths

        # First check if we even have an ./inventories/ folder
        if [[ -d "$inventory_base_dir" ]]; then
            # If it is a directory, check if ./inventories/service name is a directory
            if [[ -d "$inventory_base_dir/$service_name" ]]; then

                # ./inventories/service/hosts
                if [[ -f "$inventory_base_dir/$service_name/hosts" ]]; then
                    hostsfile_final_path="$inventory_base_dir/$service_name/hosts"

                elif [[ -f "$inventory_base_dir/$service_name/$env_name" && ! -z $env_name ]]; then
                    # If ./inventories/service_name/dev is a file, chop `dev` off the childgroups
                    hostsfile_final_path="$inventory_base_dir/$service_name/$env_name"
                    grp=("${grp[@]:1}")
                fi

            elif [[ -f "$inventory_base_dir/$service_name" ]]; then 
                # If ./inventories/servicename isn't a dir, it might be the file
                hostsfile_final_path="$inventory_base_dir/$service_name"
            fi
        else
            # If it's not a directory, check if ./base_dir/service is a directory AND service len is not zero (since base_dir is certainly a dir)
            if [[ -d $base_dir/${service_name} && ! -z ${service_name} ]]; then
                debug "DEBUG: No directory 'inventories' found"
                # Should people put hosts file in ./bianca-blog/hosts
                # - yes, but only if it's called 'hosts', or it's in an inventory dir
                if [[ -f $base_dir/${service_name}/inventories/hosts ]]; then
                    hostsfile_final_path="$base_dir/${service_name}/inventories/hosts"

                # ./blog/inventories/dev
                elif [[ -f $base_dir/${service_name}/inventories/$env_name && ! -z $env_name ]]; then
                    hostsfile_final_path="$base_dir/${service_name}/inventories/$env_name"
                    grp=("${grp[@]:1}")
                    
                elif [[ -f $base_dir/${service_name}/hosts ]]; then
                    hostsfile_final_path="$base_dir/${service_name}/hosts"

                elif [[ -f $base_dir/${service_name}/$env_name && ! -z $env_name ]]; then
                    hostsfile_final_path="$base_dir/${service_name}/$env_name/hosts"
                    grp=("${grp[@]:1}")
                fi
            
            # Else, if ./$service_name isn't a directory, then check for $service_name in the base directory as a file, if not, find 'hosts', and add $service_name to grp
            else
                debug "DEBUG: $base_dir/$service_name is not a directory"
                if [[ -f $base_dir/$service_name ]]; then
                    debug "DEBUG: Found inventory file in $base_dir/$service_name"
                    hostsfile_final_path="$base_dir/$service_name"
                
                elif [[ -f $base_dir/hosts ]]; then
                    grp=("${tokens[@]}") # All the tokens since none of them are consumed in this
                fi
            fi

            # If it's stilllll can't find it, at least assign the -l
            if [[ -z $hostsfile_final_path ]]; then
                grp=("${tokens[@]}")
            fi


            # Assign the grp
            playgroups=${grp[*]}

            debug "DEBUG: Found service name: $service_name"
            debug "DENUG: Found env name: $env_name"
    
            debug "DEBUG: <parent>.<child> hostgroups are:" "${grp[@]}"
            debug "DEBUG: Length of grp arr: ${#grp[@]}"
            debug "INFO: Limiting to host groups [${grp[*]}]"
        fi
    fi
}

# Find playbook in array $check_file_paths
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
# 3. No playbook provided at all

# _arg_named_playbook_file <- Passed with -p, take it as is
# _arg_positional_playbook <- Could be a path (rel/abs)
parse_playbook_arg() {
    # This is for polish
    # @TODO: Bianca Tamayo (Aug 25, 2017) - If there's no service name (e.g. if command is passed in with -i, then there's no need to go into service subdirs)
    service_playbook_base_path="${playbook_base_dir}/${service_name}"

    # 1
    if [[ ! -z "$_arg_named_playbook_file" ]]; then
        debug "DEBUG: 1 Passed using -p, set as final path"
        debug "DEBUG: setting playbook_final_path to: $base_dir/$_arg_named_playbook_file"
        playbook_final_path="$base_dir/$_arg_named_playbook_file"
    # 2.1 + 2.2
    elif [[ "$_arg_positional_playbook" = */* ]]; then

        if [[ "$_arg_positional_playbook" = /*  ]]; then debug "DEBUG: 2.1 Passed without -p, absolute path"; else debug "DEBUG: 2.2 Passed without -p, relative path"; fi
       
        playbook_find_dir=$_arg_positional_playbook

        # Maybe it's a path to an actual playbook
        if [[ -f "$playbook_find_dir" ]]; then
            playbook_final_path=$playbook_find_dir
        fi

        check_file_paths=( "${playbook_find_dir}" )
        find_playbook_in_paths
    # 2.3
    elif [[ ! -z "$_arg_positional_playbook" ]]; then
        local specific_filename_given
        debug "DEBUG: 2.3 Passed without -p, not a path, plain name"

        if [[ $_arg_positional_playbook = *.yml || $_arg_positional_playbook = *.yaml ]]; then
            debug "DEBUG: 2.3.1 Ends with '.yml' or '.yaml'"
            specific_filename_given=$_arg_positional_playbook

            # If we have a specific filename given, we should honor that
            # Look for that filename in the service's playbook subdirectory, $service_playbook_base_path
            
            # Find that filename in the service's playbook folder 
            check_file_paths=( "${service_playbook_base_path}/${specific_filename_given}" )

            # Then try to find it in the main playbook folder
            check_file_paths+=("${playbook_base_dir}/${specific_filename_given}")

            # If it really can't find it, then base dir
            check_file_paths+=("$base_dir/$specific_filename_given")

            # Run search
            find_playbook_in_paths
        else
            
            debug "DEBUG: 2.3.2 Does not end with YAML extension"

            # This could be a directory, subdirectory or a filename
            # 1. Search in service playbk dir -> if exist, use. if not exist, check if subdir. -> if subdir, check for matching service name or site.yml. 
            # 2. If not in subdir, go back out to main playbook dir and check if it's a playbook there or a subdir there, then do ^

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

            # Playbook directory
            check_file_paths+=("$playbook_base_dir/$_arg_positional_playbook.yml")
            check_file_paths+=("$playbook_base_dir/$_arg_positional_playbook.yaml")

            # If it really can't find it, then base dir
            check_file_paths+=("$base_dir/$_arg_positional_playbook.yml")
            check_file_paths+=("$base_dir/$_arg_positional_playbook.yaml")

            find_playbook_in_paths
        fi
    elif [[ -z "$_arg_positional_playbook" ]]; then
        debug "DEBUG: 3. No playbook provided at all."
        
        if [[ ! -z "$_arg_positional_inventory" ]] 
        then
                
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
        if [[ ! -f "$playbook_final_path" ]]; then
            playbook_final_path="$default_playbook_file_name"
        fi
    fi

    if [[ ! -f "$playbook_final_path" ]]; then
        die "FATAL: No playbook found in: $playbook_final_path"
        # TODO: Bianca Tamayo (Jul 22, 2017) - Add skipping check existence
        exit 1
    fi
}

# ------- MAIN  -------
debug "DEBUG: [INPUT]" "$@"

# Begin parse
parse_commandline "$@"

# Internal
if [[ ! -z $_arg_internal_update_basepath ]];
then
    update_paths "$_arg_internal_update_basepath"
fi

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

debug ""
debug "DEBUG: Base path is: $base_dir"
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
    elif [[ -z "$hostsfile_final_path" ]]; then
        playbook_command=$playbook_command$playbook_param
    else
        playbook_command=$playbook_command$inv_param$playbook_param
    fi

    if [[ "${remainder_args[*]}" =~ $limit_arg_re ]]; then
        echo "WARN: --limit argument passed by user as extra args"
        echo "PLAYGROUPS: $playgroups"

    elif [[ ! -z "$playgroups" ]]; then
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

    debug "[EXEC]: $playbook_command"
    playbook_command=${playbook_command//$base_dir/\.} # Truncate for easier viewing 

    # May have to update this each time cli updates
}

construct_playbook_command

echo ""
echo "[EXEC]: $playbook_command"
echo ""

# TODO: Bianca Tamayo (Jul 22, 2017) - Add suppress prompt

if [[ $_arg_flag_no_exec == "true" ]]; then exit 0; fi

while true; do
    read -rp "Continue? " yn
    case $yn in
        [Yy]* ) $playbook_command; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


# End of file