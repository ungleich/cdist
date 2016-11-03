_cdist()
{
    local cur prev prevprev opts cmds projects
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    prevprev="${COMP_WORDS[COMP_CWORD-2]}"
    opts="-h --help -d --debug -v --verbose -V --version"
    cmds="banner shell config install inventory"

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
         inventory)
            case "${prev}" in
                list)
                    opts="-h --help -d --debug -v --verbose -b --enable-beta \
                        -I --inventory -a --all -f --file -H --host-only \
                        -t --tag"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                add-host)
                    opts="-h --help -d --debug -v --verbose -b --enable-beta \
                        -I --inventory -f --file"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                del-host)
                    opts="-h --help -d --debug -v --verbose -b --enable-beta \
                        -I --inventory -a --all -f --file"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                add-tag)
                    opts="-h --help -d --debug -v --verbose -b --enable-beta \
                        -I --inventory -f --file -T --tag-file -t --taglist"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                del-tag)
                    opts="-h --help -d --debug -v --verbose -b --enable-beta \
                        -I --inventory -a --all -f --file -T --tag-file -t --taglist"
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
        config|install)
            opts="-h --help -d --debug -v --verbose -b --beta \
                -I --inventory -c --conf-dir -f --file -i --initial-manifest \
                -j --jobs -n --dry-run -o --out-dir -p --parallel \
                -s --sequential --remote-copy --remote-exec -t --tags -a --all"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        inventory)
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
