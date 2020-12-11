# -*- mode: sh; indent-tabs-mode:t -*-

parse_locale() {
	# This function will split locales into their parts. Locale strings are
	# usually of the form: [language[_territory][.codeset][@modifier]]
	# For simplicity, language and territory are not separated by this function.
	# Old Linux systems were also using "english" or "german" as locale strings.
	# Usage: parse_locale locale_str lang_var codeset_var modifier_var
	eval "${2:?}"="$(expr "$1" : '\([^.@]*\)')"
	eval "${3:?}"="$(expr "$1" : '[^.]*\.\([^@]*\)')"
	eval "${4:?}"="$(expr "$1" : '.*@\(.*\)$')"
}

format_locale() {
	# Usage: format_locale language codeset modifier
	printf '%s' "$1"
	test -z "$2" || printf '.%s' "$2"
	test -z "$3" || printf '@%s' "$3"
	printf '\n'
}
