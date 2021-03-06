#!/usr/bin/env bash

# 1. Parse command line arguments.
# 2. Check dependencies.
# 3. Try to create new directory for the project.
# 4. Clone bionitio git repository into the newly created directory.
# 5. Recursively copy source tree from the git repository into the project directory.
# 6. Recursively copy test_data directory from the git repository into the project directory.
# 7. Set the license for the project.
# 8. Copy the .travis/test.sh script into the project directory.
# 9. Remove the cloned git repository.
# 10. Rename bionitio to the new project name.
# 11. Create repository for new project.

#set -x

program_name="bionitio-boot.sh"
# The name of the programming language that the user wants to use from the
# available bionitio implementations
language=""
# The license used for the new project. It defaults to MIT.
license="MIT"
# The name of the new software project that the user wants to create
new_project_name=""
# Verbose output
verbose=""
# Name of temporary sub-directory to store bionitio git repository
git_tmp_dir="bionitio-boot-git-tmp"

# Help message for using the program.
function show_help {
cat << UsageMessage

${program_name}: initialise a new bioinformatics project, starting from bionitio

Usage:
    ${program_name} [-h] [-v] [-c license] -l language -n new_project_name

Example:
    ${program_name} -c BSD-3-Clause -l python -n skynet

The above example will try to initialise a new project in directory 'skynet'
based on the 'python' bionitio implementation, using the BSD-3-Clause license.

If a directory already exists in the current working directory with the same
name as the new_project_name then this installer will not continue.

If no license is supplied, it will default to using the MIT license.

Valid languages are:
c, clojure, cpp, haskell, java, js, perl5, python, r, ruby, rust

Valid licenses are:
Apache-2.0, BSD-2-Clause, BSD-3-Clause, GPL-2.0, GPL-3.0, MIT

These are just a selection of commonly used licenses, but you are free to
choose another, if you so desire.

-h shows this help message

-v verbose output

Dependencies:

   - git must be installed on your computer to use this script.

UsageMessage
}


# echo an error message $1 and exit with status $2
function exit_with_error {
    printf "${program_name}: ERROR: $1\n"
	exit $2
}

# Parse the command line arguments and set the global variables language and new_project_name
function parse_args {
    local OPTIND opt

    while getopts "hc:l:n:v" opt; do
        case "${opt}" in
            h)
                show_help
                exit 0
                ;;
            l)  language="${OPTARG}"
                ;;
            c)  license="${OPTARG}"
                ;;
            n)  new_project_name="${OPTARG}"
                ;;
	    v)  verbose=true
		;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    if [[ -z ${language} ]]; then
		exit_with_error "missing command line argument: -l language, use -h for help" 2
    fi

    case ${language} in
        c|clojure|cpp|haskell|java|js|perl5|python|r|ruby|rust)
            # this is an allowed language
            ;;
        *)
            exit_with_error "${language} is not one of the valid languages, use -h to see the list" 2
    esac

    case ${license} in
	Apache-2.0|BSD-2-Clause|BSD-3-Clause|GPL-2.0|GPL-3.0|MIT)
            # this is an allowed license 
            ;;
        *)
            exit_with_error "${license} is not one of the valid licenses, use -h to see the list" 2
    esac

    if [[ -z ${new_project_name} ]]; then
        exit_with_error "missing command line argument: -n new_project_name, use -h for help" 2
    fi
}

function check_dependencies {
    # Check for git
    git --version > /dev/null || {
       exit_with_error "git is not installed in the PATH\nPlease install git, and ensure it can be found in your PATH variable." 1
    }
}

function create_project_directory {
    if [[ -d ${new_project_name} ]]; then
        exit_with_error "directory ${new_project_name} already exists, try another name or location, or rename the existing directory" 1
    else
        mkdir ${new_project_name} || {
            exit_with_error "failed to create directory ${new_project_name}" 1
        }
    fi
}

function clone_bionitio_repository {
    # XXX check if git is executable, catch output from git in case we need to report an error
    git clone https://github.com/bionitio-team/bionitio ${new_project_name}/${git_tmp_dir} > /dev/null 2>&1 || {
        exit_with_error "git command failed: \'git clone https://github.com/bionitio-team/bionitio ${new_project_name}/${git_tmp_dir}\'" 1
    }
}

function copy_bionitio_language {
    cp -R ${new_project_name}/${git_tmp_dir}/${language}/ ${new_project_name} || {
        exit_with_error "copy command failed: \'cp -R {new_project_name}/${git_tmp_dir}/$language/ ${new_project_name}\'" 1
    }
}

function copy_test_data {
    cp -R ${new_project_name}/${git_tmp_dir}/test_data/ ${new_project_name}/test_data/ || {
        exit_with_error "copy command failed: \'cp -R ${new_project_name}/${git_tmp_dir}/test_data/ ${new_project_name}/test_data/\'" 1
    }
}

function set_license {
    cp ${new_project_name}/${git_tmp_dir}/license_options/${license} ${new_project_name}/LICENSE
}

function copy_travis_test {
    cp ${new_project_name}/${git_tmp_dir}/.travis/test.sh ${new_project_name}/.travis/test.sh
}

function remove_bionitio_repository {
    /bin/rm -fr "${new_project_name}/${git_tmp_dir}"
}

function rename_project {
    # Annoyingly BSD sed and GNU sed differ in handling the -i option (update in place).
    # So we opt for a portable approach which creates backups of the original ending in .temporary,
    # which we then later delete. It is ugly, but it is portable.
    # See: http://stackoverflow.com/questions/5694228/sed-in-place-flag-that-works-both-on-mac-bsd-and-linux
    # BSD sed does not support case insensitive matching, so we have to repeat for each
    # style of capitalisation.
    
    # project name with first character upper case
    first_upper_project_name="$(tr '[:lower:]' '[:upper:]' <<< ${new_project_name:0:1})${new_project_name:1}"
    
    # project name with all characters upper case
    all_upper_project_name="$(tr '[:lower:]' '[:upper:]' <<< ${new_project_name})"
    
    # substitute all occurrences of bionitio in content
    find ${new_project_name} -type f -print0 | xargs -0 sed -i.temporary  "s/bionitio/${new_project_name}/g"
    find ${new_project_name} -name "*.temporary" -type f -delete
    
    find ${new_project_name} -type f -print0 | xargs -0 sed -i.temporary  "s/Bionitio/${first_upper_project_name}/g"
    find ${new_project_name} -name "*.temporary" -type f -delete
    
    find ${new_project_name} -type f -print0 | xargs -0 sed -i.temporary  "s/BIONITIO/${all_upper_project_name}/g"
    find ${new_project_name} -name "*.temporary" -type f -delete

    # rename directories and files
    verbose_message "renaming directories..."
    (shopt -s nullglob && recursive_rename() {
        for old in "$1"*/; do
            new1="${old//bionitio/${new_project_name}}"
            new2="${new1//Bionitio/${first_upper_project_name}}"
            new="${new2//BIONITIO/${all_upper_project_name}}"
            if [ "$old" != "$new" ]; then
                verbose_message "$old -> $new"
                if [ -e "$new" ]; then
                    exit_with_error "cannot rename directory \"$old\" to \"$new\": \"$new\" exists. Choose a different project name." 1
                fi
                mv -- "$old" "$new"
            fi
            recursive_rename "$new" || exit 1
        done
    } && recursive_rename "${new_project_name}/") || exit 1

    verbose_message "renaming files..."
    for old in $(find ${new_project_name} -type f); do
        new1="${old//bionitio/${new_project_name}}"
        new2="${new1//Bionitio/${first_upper_project_name}}"
        new="${new2//BIONITIO/${all_upper_project_name}}"
        if [ "$old" != "$new" ]; then
            verbose_message "$old -> $new"
            if [ -e "$new" ]; then
                exit_with_error "cannot rename file \"$old\" to \"$new\": \"$new\" exists. Choose a different project name." 1
            fi
            mv -- "$old" "$new"
        fi
    done
}


function create_project_repository {
    (
        cd ${new_project_name}
        git init
        git add .
        git commit -m "Initial commit of ${new_project_name}; starting from bionitio (${language})"
    ) > /dev/null 2>&1
}


function verbose_message {
    if [ "${verbose}" = true ]; then
        echo "${program_name} $1"
    fi
}

# 1. Parse command line arguments.
parse_args $@
# 2. Check that dependencies are met
verbose_message "checking for dependencies"
check_dependencies
# 3. Try to create new directory for the project.
verbose_message "creating project directory ${new_project_name}"
create_project_directory
# 4. Clone bionitio git repository into the newly created directory.
verbose_message "cloning bionitio repository into ${new_project_name}/${git_tmp_dir}"
clone_bionitio_repository
# 5. Recursively copy source tree from the git repository into the project directory.
verbose_message "copying ${language} source tree into ${new_project_name}"
copy_bionitio_language
# 6. Recursively copy test_data directory from the git repository into the project directory.
verbose_message "copying test_data into ${new_project_name}"
copy_test_data
# 7. Set the license for the project
verbose_message "setting the license to ${license}"
set_license
# 8. Copy the .travis/test.sh script into the project directory.
verbose_message "copying .travis/test.sh into the project directory"
copy_travis_test
# 9. remove the cloned git repository.
verbose_message "removing ${new_project_name}/${git_tmp_dir}"
remove_bionitio_repository
# 10. Rename bionitio to the new project name.
verbose_message "renaming references to bionitio to new project name ${new_project_name}" 
rename_project
# 11. Create repository for new project.
verbose_message "initialising new git repository for ${new_project_name}"
create_project_repository
verbose_message "done"
