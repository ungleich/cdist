# -*- mode: awk; indent-tabs-mode:t -*-
# Usage: awk -f option_state.awk option_type option_name
# e.g. awk -f option_state.awk option title
#      awk -f option_state.awk list entry

function unquote(s) {
	# simplified dequoting of single quoted strings
	if (s ~ /^'.*'$/) {
		s = substr(s, 2, length(s) - 2)
		sub(/'\\''/, "'", s)
	}
	return s
}

function valueof(line) {
	if (line !~ /^[[:alpha:]_]+=/) return 0
	return unquote(substr(line, index(line, "=") + 1))
}

BEGIN {
	__object = ENVIRON["__object"]
	if (!__object) exit 1

	opttype = ARGV[1]
	optname = ARGV[2]

	if (opttype !~ /^(option|list)/ || !optname) {
		print "invalid"
		exit (e=1)
	}

	ARGV[1] = __object "/parameter/" opttype
	ARGV[2] = __object "/explorer/options"

	state = "present"
}

NR == FNR {
	# memoize "should" state
	if (index($0, optname "=") == 1) {
		should[++should_count] = valueof($0)
	}

	# go to next line (important!)
	next
}

{
	# compare "is" state
	if (index($0, optname "=") != 1)
		next
	++is_count

	v = valueof($0)

	if (v == should[is_count]) {
		# looks good, but can't say definitely just from this line
	} else if (is_count > should_count) {
		# there are more "is" records than "should" -> definitely different
		state = "different"
		exit
	} else {
		# see if we can find the "is" value somewhere in "should"
		for (i in should) {
			if (v == should[i]) {
				# value found -> could be rearranged
				# FIXME: Duplicate values are not properly handled here. Do they matter?
				state = "rearranged"
				next
			}
		}

		# "is" value could not be found in "should" -> definitely different
		state = "different"
		exit
	}
}

END {
	if (e) exit

	if (!is_count) {
		# no "is" values -> absent
		state = "absent"
	} else if (is_count < should_count) {
		# "is" was shorter than "should" -> different
		state = "different"
	}

	print state
}
