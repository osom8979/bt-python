#!/usr/bin/env bash

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd)

INIT_PYTHON_VERSION=3.12.8
SED_INPLACE_SUFFIX=.tmp

VERBOSE=0
AUTO_YES=0
FORCE=0
DRY_RUN=0

USAGE="
Usage: ${BASH_SOURCE[0]} [options]

Available options are:
  -y, --yes         Automatic yes to prompts
  -f, --force       Skip validation
  -n, --dry-run     Don't actually do anything, just show what would be done
  -v, --verbose     Be more verbose/talkative during the operation
  -h, --help        Print this message.
  --                Stop handling options.
"

function print_error
{
    # shellcheck disable=SC2145
    echo -e "\033[31m$@\033[0m" 1>&2
}

function print_message
{
    # shellcheck disable=SC2145
    echo -e "\033[32m$@\033[0m"
}

function print_verbose
{
    if [[ $VERBOSE -ne 0 ]]; then
        echo -e "$@"
    fi
}

function print_usage
{
    echo "$USAGE"
}

function is_number
{
    [[ $1 =~ ^[0-9]+$ ]]
}

function on_interrupt_trap
{
    print_error "An interrupt signal was detected."
    exit 1
}

trap on_interrupt_trap INT

while [[ -n $1 ]]; do
    case $1 in
    -h|--help)
        print_usage
        exit 0
        ;;
    -v|--verbose)
        VERBOSE=1
        shift
        ;;
    -y|--yes)
        AUTO_YES=1
        shift
        ;;
    -f|--force)
        FORCE=1
        shift
        ;;
    -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        break
        ;;
    esac
done

read -r -p "Project name: " PROJECT_NAME
read -r -p "Project description (Do not use quotation marks): " PROJECT_DESC
read -r -e -i "$INIT_PYTHON_VERSION" -p "Python version: " PYTHON_VERSION
read -r -p "Github ID: " GITHUB_ID
read -r -p "User name: " USER_NAME
read -r -p "User e-mail: " USER_EMAIL

IFS="." read -r PYTHON_MAJOR PYTHON_MINOR PYTHON_PATCH <<< "$PYTHON_VERSION"
PYTHON_MAJOR=${PYTHON_MAJOR:-0}
PYTHON_MINOR=${PYTHON_MINOR:-0}
PYTHON_PATCH=${PYTHON_PATCH:-0}

if ! is_number "$PYTHON_MAJOR"; then
    print_error "The Python major version number is incorrect: '$PYTHON_MAJOR'"
    exit 1
fi
if ! is_number "$PYTHON_MINOR"; then
    print_error "The Python minor version number is incorrect: '$PYTHON_MINOR'"
    exit 1
fi
if ! is_number "$PYTHON_PATCH"; then
    print_error "The Python patch version number is incorrect: '$PYTHON_PATCH'"
    exit 1
fi

# shellcheck disable=SC2001
PACKAGE_LOWER=$(echo "${PROJECT_NAME,,}" | sed -e 's/[^a-zA-Z0-9]/_/g')
YEAR=$(date +%Y)

COMMON_FLAGS=()
if [[ $FORCE -ne 0 ]]; then
    COMMON_FLAGS+=(-f)
fi
if [[ $VERBOSE -ne 0 ]]; then
    COMMON_FLAGS+=(-v)
fi

INIT_FILES=(
    ".github/workflows/docker-deploy.yml"
    ".github/workflows/python-deploy.yml"
    ".github/workflows/python-test.yml"
    ".run/main.run.xml"
    ".vim/coc-settings.json"
    "__PACKAGE_LOWER__/logging/formatters/colored.py"
    "__PACKAGE_LOWER__/logging/logging.py"
    "__PACKAGE_LOWER__/logging/__init__.py"
    "__PACKAGE_LOWER__/aio/__init__.py"
    "__PACKAGE_LOWER__/aio/policy.py"
    "__PACKAGE_LOWER__/aio/run.py"
    "__PACKAGE_LOWER__/apps/master/__init__.py"
    "__PACKAGE_LOWER__/apps/__init__.py"
    "__PACKAGE_LOWER__/__init__.py"
    "__PACKAGE_LOWER__/entrypoint.py"
    "__PACKAGE_LOWER__/__main__.py"
    "__PACKAGE_LOWER__/types/string/to_boolean.py"
    "__PACKAGE_LOWER__/types/string/__init__.py"
    "__PACKAGE_LOWER__/types/override.py"
    "__PACKAGE_LOWER__/types/__init__.py"
    "__PACKAGE_LOWER__/arguments.py"
    "__PACKAGE_LOWER__/assets/.gitignore"
    "__PACKAGE_LOWER__/assets/__init__.py"
    "__PACKAGE_LOWER__/system/environ.py"
    "__PACKAGE_LOWER__/system/__init__.py"
    "tester/__init__.py"
    "tester/test_entrypoint.py"
    ".dockerignore"
    ".gitignore"
    ".gitlab-ci.yml"
    ".vimspector.json"
    "Dockerfile"
    "LICENSE"
    "MANIFEST.in"
    "README.md"
    "api.rest"
    "black.sh"
    "build-docker.sh"
    "build-pyinstaller.sh"
    "build.sh"
    "ci.sh"
    "clean.sh"
    "env-template"
    "flake8.ini"
    "flake8.sh"
    "install.dev.sh"
    "isort.cfg"
    "isort.sh"
    "main.py"
    "mypy.ini"
    "mypy.sh"
    "project.dic"
    "pytest.ini"
    "pytest.sh"
    "python"
    "requirements.deploy.txt"
    "requirements.develop.txt"
    "requirements.main.txt"
    "requirements.test.txt"
    "requirements.txt"
    "run"
    "setup.cfg"
    "setup.py"
    "twine.sh"
    "uninstall.sh"
    "version"
)

if [[ $FORCE -eq 0 ]]; then
    for file in "${INIT_FILES[@]}"; do
        file_path="$ROOT_DIR/$file"
        if [[ ! -f "$file_path" ]]; then
            print_error "Not found initialize file: '$file_path'"
            exit 1
        fi
        if [[ ! -w "$file_path" ]]; then
            print_error "Not writable initialize file: '$file_path'"
            exit 1
        fi
    done
fi

SED_ARGS=(
    -e "s/__PROJECT_NAME__/$PROJECT_NAME/g"
    -e "s/__PROJECT_DESC__/$PROJECT_DESC/g"
    -e "s/__PACKAGE_LOWER__/$PACKAGE_LOWER/g"
    -e "s/__PYTHON_VERSION__/$PYTHON_VERSION/g"
    -e "s/__PYTHON_MAJOR__/$PYTHON_MAJOR/g"
    -e "s/__PYTHON_MINOR__/$PYTHON_MINOR/g"
    -e "s/__PYTHON_PATCH__/$PYTHON_PATCH/g"
    -e "s/__USER_NAME__/$USER_NAME/g"
    -e "s/__USER_EMAIL__/$USER_EMAIL/g"
    -e "s/__GITHUB_ID__/$GITHUB_ID/g"
    -e "s/__YEAR__/$YEAR/g"
)

print_verbose "[[VARIABLES REPORT]]"
print_verbose "Project name: '${PROJECT_NAME}'"
print_verbose "Project description: '${PROJECT_DESC}'"
print_verbose "Project lower: ${PACKAGE_LOWER}"
print_verbose "Python version: ${PYTHON_VERSION}"
print_verbose "Python major: ${PYTHON_MAJOR}"
print_verbose "Python minor: ${PYTHON_MINOR}"
print_verbose "Python patch: ${PYTHON_PATCH}"
print_verbose "User name: '${USER_NAME}'"
print_verbose "User e-mail: '${USER_EMAIL}'"
print_verbose "Github ID: '${GITHUB_ID}'"
print_verbose "Year: ${YEAR}"

if [[ $AUTO_YES -eq 0 ]]; then
    read -r -p "Are you sure you want to continue with the installation? (y/n) " YN
    if [[ "${YN,,}" != 'y' ]]; then
        print_error "The job has been canceled"
        exit 1
    fi
fi

INIT_FILES_LENGTH="${#INIT_FILES[@]}";

for (( i = 0; i < INIT_FILES_LENGTH; i++ )); do
    file_path="$ROOT_DIR/${INIT_FILES[$i]}"
    temp_path="$ROOT_DIR/${INIT_FILES[$i]}$SED_INPLACE_SUFFIX"

    if [[ $DRY_RUN -eq 0 ]]; then
        sed "-i$SED_INPLACE_SUFFIX" "${SED_ARGS[@]}" "$file_path"
    fi

    print_verbose "[$((i + 1))/$INIT_FILES_LENGTH] Update file: $file_path"

    if [[ $DRY_RUN -eq 0 ]]; then
        rm "${COMMON_FLAGS[@]}" "$temp_path"
    fi
done

if [[ $DRY_RUN -eq 0 ]]; then
    mv "${COMMON_FLAGS[@]}" "$ROOT_DIR/__PACKAGE_LOWER__" "$ROOT_DIR/$PACKAGE_LOWER"
fi

print_message "Initialization was successful!"

if [[ $AUTO_YES -eq 0 ]]; then
    read -r -p "Do you want to remove init scripts that are no longer used? (y/n) " YN
else
    YN=y
fi

if [[ "${YN,,}" != 'y' ]]; then
    exit 0
fi

if [[ $DRY_RUN -ne 0 ]]; then
    exit 0
fi

rm "${COMMON_FLAGS[@]}" "$(realpath "${BASH_SOURCE[0]}")"
