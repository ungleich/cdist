# -*- mode: sh; indent-tabs-mode: t -*-

NL=$(printf '\n '); NL=${NL% }

grep_line() {
	{ shift; printf '%s\n' "$@"; } | grep -qxF "$1"
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

quote() {
	for _arg
	do
		shift
		if test -n "$(printf %s "${_arg}" | tr -d -c '\t\n \042-\047\050-\052\073-\077\133\\`|~' | tr -c '' '.')"
		then
			# needs quoting
			set -- "$@" "$(printf "'%s'" "$(printf %s "${_arg}" | sed -e "s/'/'\\\\''/g")")"
		else
			set -- "$@" "${_arg}"
		fi
	done
	unset _arg
	printf '%s' "$*"
}

uci_cmd() {
	# Usage: uci_cmd [UCI ARGUMENTS]...
	mkdir -p "${__object:?}/files"
	printf '%s\n' "$(quote "$@")" >>"${__object:?}/files/uci_batch.txt"
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
