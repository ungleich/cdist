_cdist()
{
    local cur prev prevprev opts cmds projects
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    prevprev="${COMP_WORDS[COMP_CWORD-2]}"
    opts="-h --help -d --debug -v --verbose -V --version"
    cmds="banner shell config install"

    case "${prevprev}" in
        shell)
            case "${prev}" in
                -s|--shell)
                    shells=$(grep -v '^#' /etc/shells)
                    COMPREPLY=( $(compgen -W "${shells}" -- ${cur}) )
                    return 0
                    ;;
            esac
            ;;
    esac

    case "${prev}" in
        -*)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        banner)
            opts="-h --help -d --debug -v --verbose"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        shell)
            opts="-h --help -d --debug -v --verbose -s --shell"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        config|install)
            opts="-h --help -d --debug -v --verbose -b --beta \
                -C --cache-path-pattern -c --conf-dir -f --file -i --initial-manifest -j --jobs \
                -n --dry-run -o --out-dir -p --parallel -r --remote-out-dir -s --sequential \
                --remote-copy --remote-exec"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        *)
            ;;
    esac

    if [[ ${cur} == -* ]]; then 
    	COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    	return 0
    fi

    COMPREPLY=( $(compgen -W "${cmds}" -- ${cur}) )
    return 0
}

complete -F _cdist cdist
