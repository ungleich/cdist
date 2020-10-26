# -*- mode: sh; indent-tabs-mode: t -*-

append_values() {
	while read -r _value
	do
		set -- "$@" --value "${_value}"
	done
	unset _value
	"$@" </dev/null
}

grep_line() {
	{ shift; printf '%s\n' "$@"; } | grep -qxF "$1"
}

prefix_lines() {
	while test $# -gt 0
	do
		echo "$2" | awk -v prefix="$1" '$0 { printf "%s %s\n", prefix, $0 }'
		shift; shift
	done
}

print_errors() {
	awk -v prefix="${1:-Found errors:}" -v suffix="${2-}" '
		BEGIN {
			if (getline) {
				print prefix
				print
				rc = 1
			}
		}
		{ print }
		END {
			if (rc && suffix) print suffix
			exit rc
		}' >&2
}

uci_validate_name() {
	# like util.c uci_validate_name()
	test -n "$*" && test -z "$(printf %s "$*" | tr -d '[:alnum:]_' | tr -c '' .)"
}

unquote_lines() {
	sed -e '/^".*"$/{s/^"//;s/"$//}' \
	    -e '/'"^'.*'"'$/{s/'"^'"'//;s/'"'$"'//}'
}

validate_options() {
	grep -shv -e '^[[:alnum:]_]\{1,\}=' "$@"
}
