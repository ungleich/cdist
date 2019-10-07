__cdist_unsupported_os() {
    if [ $# -gt 0 ]
    then
        os=$1
        shift
    else
        os=$(cat "$__explorer/os")
    fi
	printf "Your operating system \"%s\" is currently not supported.\nPlease contribute an implementation for it if you can.\n" "${os}" >&2
	exit 1
}

__cdist_error() {
    printf "$@" >&2
    exit 1
}
