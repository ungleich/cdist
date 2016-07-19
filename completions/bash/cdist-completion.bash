_cdist()
{
    local cur prev prevprev opts cmds projects
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    prevprev="${COMP_WORDS[COMP_CWORD-2]}"
    opts="-h --help -d --debug -v --verbose -V --version"
    cmds="banner shell config betainventory"

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
         betainventory)
            case "${prev}" in
                list)
                    opts="-h --help -d --debug -v --verbose -I --inventory \
                        -H --host-only -a --all -t --tag -f --file"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                add-host)
                    opts="-h --help -d --debug -v --verbose -I --inventory \
                        -f --file"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                del-host)
                    opts="-h --help -d --debug -v --verbose -I --inventory \
                        -f --file -a --all"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                add-tag)
                    opts="-h --help -d --debug -v --verbose -I --inventory \
                        -f --file -t --taglist -T --tag-file"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                del-tag)
                    opts="-h --help -d --debug -v --verbose -I --inventory \
                        -f --file -t --taglist -T --tag-file -a --all"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
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
        config)
            opts="-h --help -d --debug -v --verbose -I --inventory \
                -c --conf-dir -f --file -i --initial-manifest -n --dry-run \
                -o --out-dir -p --parallel -s --sequential --remote-copy \
                --remote-exec -t --tag -a --all"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        betainventory)
            cmds="list add-host del-host add-tag del-tag"
            opts="-h --help -d --debug -v --verbose"
            COMPREPLY=( $(compgen -W "${opts} ${cmds}" -- ${cur}) )
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
