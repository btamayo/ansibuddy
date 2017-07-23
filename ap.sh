#!/usr/bin/env bash

# "Constants"
ansible_project_base=$(dirname "$0")

inventory_dir_name="inventories"
playbook_dir_name="playbooks"
inventory_base_dir=$ansible_project_base/$inventory_dir_name
playbook_base_dir=$ansible_project_base/$playbook_dir_name

# Defaults
# default_playbook_file_name="site.yml"

# Script-specific commands like "check", "help", and "list-hosts"
ansible_append_flags=()

# @TODO: Bianca Tamayo (Jul 22, 2017) - Make unnecessary
if [[ $ansible_project_base != "." ]]; then
    echo "FATAL: Current directory should be project root (where ap.sh is). Paths may resolve incorrectly otherwise."
fi

# Functions
usage() {
    echo "$1"

    local help_text="
    USAGE
        $0 <HOSTGROUP> <COMMAND> [...OPTIONS] [...ARGS]

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
        echo "DEBUG: $hostsfile_find_path does not exist"
    elif [[ -d "$hostsfile_find_path" && ! -f "$hostsfile_find_path/hosts" ]]; then
        echo "DEBUG: hosts file in $hostsfile_find_path does not exist"
    elif [[ -f "$hostsfile_find_path/hosts" ]]; then
        echo "DEBUG: Found hosts file in $hostsfile_find_path/hosts"
    fi

    # If it does exist, we're still gonna assign it and let ansible fail. ^ is for debugging only.
    hostsfile_final_path="$hostsfile_find_path/hosts"
}

parse_inventory_arg() {
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

        echo "INFO: Finding group [${grp[*]}] in $hostsfile_find_path/hosts"

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
            echo "DEBUG: Playbook found in: $playbook_final_path"
            break;
        else
            echo "DEBUG: Playbook not found in: $test_path"
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
        usage "Error: Missing hostgroup";
        exit 0;
    fi


    if [[ "$#" == 0 ]]; then
        # @TODO: Bianca Tamayo (Jul 22, 2017) - This contradicts the behavior of the default 'site.yml' playbook
        # since it can be ran with ./ap hostname 
        usage "Error: Missing playbook";
        exit 0;
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
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
            *)  passed_playbook_file_name="$1"; shift;; # TODO: Bianca Tamayo (Jul 22, 2017) - this will keep looping if there's unhandled args, also it does not maintain order

            --)
                break; shift;;
        esac
    done
}




# ------- MAIN  -------

echo "DEBUG: [INPUT]" "$@"

# Begin parse
parse_args "$@"

echo ""
echo "DEBUG: Passed hostgroup: $hostgroup"
echo "DEBUG: Passed playbook name or path: $passed_playbook_file_name"
echo "DEBUG: Passed Commands:" "${ansible_append_flags[*]}"

# Begin logic
parse_inventory_arg

# Find a playbook directory that has the same name as the service name

# If the playbook is specified and named exactly the same as the playbook in the directory, choose that play
# e.g. ./playbooks/bianca-blog.yml > ./playbooks/bianca-blog/bianca-blog.yml > ./playbooks/bianca-blog/site.yml
parse_playbook_arg

# ---------------------


# Construct the ansible command
playbook_command="ansible-playbook -i $hostsfile_final_path $playbook_final_path ${ansible_append_flags[*]}"


echo "DEBUG: Additional options:" "$@"

echo "DEBUG: Parsed env_name, service_name: $service_name, $env_name"
echo "DEBUG: Parsed groupname in host:" "${grp[@]}"
echo ""
echo "DEBUG: Looking for inventory in: $hostsfile_find_path"
echo "DEBUG: Playbook file: $passed_playbook_file_name"

echo ""
echo "DEBUG: [FINAL]: $playbook_command"

# TODO: Bianca Tamayo (Jul 22, 2017) - Add prompt and suppress prompt

# End of file