#!/usr/bin/env bash

# "Constants"
base_folder=$PWD
ansible_project_base=$(dirname "$0")

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

# @TODO: Bianca Tamayo (Jul 22, 2017) - Make unnecessary
echo $PWD
if [[ $ansible_project_base != "." ]]; then
    echo "FATAL: Current directory should be project root (where ap.sh is). Paths may resolve incorrectly otherwise."
    exit 1
fi

# Functions
debug() {
    if [[ "$debug_mode" == "true" ]]; then echo "$@"; fi
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

            # Remove first two els
            grp=("${tokens[@]:2}")

            hostsfile_find_path="$inventory_base_dir/$service_name/$env_name"

            debug "INFO: Finding group [${grp[*]}] in $hostsfile_find_path/hosts"

            find_inventory_in_paths


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

    if [[ "$passed_playbook_file_name" = /* ]]; then
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
        # ./playbooks/{service_name}.yml > ./playbooks/{service_name}
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
    elif [[ "$hostgroup" == "-i" ]]; then
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

    while [ "$#" -gt 0 ]; do
        case "$1" in
            test)
                test_mode="true"
                debug_mode="true"
                base_folder="$PWD/test"
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
            *) remainder_args+=("$1"); shift;;
            --|---)
                break; shift;;
        esac
    done
}

# ------- MAIN  -------

debug "DEBUG: [PWD]" "$PWD"
debug "DEBUG: [INPUT]" "$@"

# Begin parse
parse_args "$@"

debug ""
debug "DEBUG: Passed hostgroup: $hostgroup"
debug "DEBUG: Passed playbook name or path: $passed_playbook_file_name"
debug "DEBUG: Passed Commands:" "${ansible_append_flags[*]}"

# Begin logic
parse_inventory_arg

# Find a playbook directory that has the same name as the service name

# If the playbook is specified and named exactly the same as the playbook in the directory, choose that play
# e.g. ./playbooks/bianca-blog.yml > ./playbooks/bianca-blog/bianca-blog.yml > ./playbooks/bianca-blog/site.yml
parse_playbook_arg

# ---------------------


# Construct the ansible command @TODO: Bianca Tamayo (Jul 22, 2017) - get rid of extra spaces
playbook_command="ansible-playbook -i $hostsfile_final_path $playbook_final_path ${ansible_append_flags[*]} ${remainder_args[*]}"

echo ""
echo "[EXEC]: $playbook_command"
echo ""

debug "DEBUG: Additional options:" "${remainder_args[*]}"

debug "DEBUG: Parsed env_name, service_name: $service_name, $env_name"
debug "DEBUG: Parsed groupname in host:" "${grp[@]}"
debug ""
debug "DEBUG: Looking for inventory in: $hostsfile_find_path"
debug "DEBUG: Playbook file: $passed_playbook_file_name"

debug ""

# TODO: Bianca Tamayo (Jul 22, 2017) - Add uppress prompt
while true; do
    read -p "Continue? " yn
    case $yn in
        [Yy]* ) $playbook_command; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


# End of file