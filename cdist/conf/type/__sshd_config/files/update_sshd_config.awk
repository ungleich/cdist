# -*- mode: awk; indent-tabs-mode: t -*-

function usage() {
	print_err("Usage: awk -f update_sshd_config.awk -- -o set|unset [-m 'User git'] -l 'X11Forwarding no' /etc/ssh/sshd_config")
}

function print_err(s) { print s | "cat >&2" }

function alength(a,    i) {
	for (i = 0; (i + 1) in a; ++i);
	return i
}

function join(sep, a, i,    s) {
	for (i = i ? i : 1; i in a; i++)
		s = s sep a[i]
	return substr(s, 2)
}

function getopt(opts, argv, target, files,    i, c, lv, idx, nf) {
	# trivial getopt(3) implementation; only basic functionality
	if (argv[1] == "--") i++
	for (i += 1; i in argv; i++) {
		if (lv) { target[c] = argv[i]; lv = 0; continue }
		if (argv[i] ~ /^-/) {
			c = substr(argv[i], 2, 1)
			idx = index(opts, c)
			if (!idx) {
				print_err(sprintf("invalid option -%c\n", c))
				continue
			}
			if (substr(opts, idx + 1, 1) == ":") {
				# option takes argument
				if (length(argv[i]) > 2)
					target[c] = substr(argv[i], 3)
				else
					lv = 1
			} else {
				target[c] = 1
			}
		} else
			files[++nf] = argv[i]
	}
}

# tokenise configuration line
# this function mimics the counterpart in OpenSSH (misc.c)
# but it returns two (next token SUBSEP rest) because I didn’t want to have to
# simulate any pointer magic.
function strdelim_internal(s, split_equals,    old) {
	if (!s)
		return ""

	old = s

	if (!match(s, WHITESPACE "|" QUOTE "" (split_equals ? "|" EQUALS : "")))
		return s

	s = substr(s, RSTART)
	old = substr(old, 1, RSTART - 1)

	if (s ~ "^" QUOTE) {
		old = substr(old, 2)

		# Find matching quote
		if (match(s, QUOTE)) {
			old = substr(old, 1, RSTART)
			# s = substr()
			if (match(s, "^" WHITESPACE "*"))
				s = substr(s, RLENGTH)
			return old
		} else {
			# no matching quote
			return ""
		}
	}

	if (match(s, "^" WHITESPACE "+")) {
		sub("^" WHITESPACE "+", "", s)
		if (split_equals)
			sub(EQUALS WHITESPACE "*", "", s)
	} else if (s ~ "^" EQUALS) {
		s = substr(s, 2)
	}

	return old SUBSEP s
}
function strdelim(s) { return strdelim_internal(s, 1) }
function strdelimw(s) { return strdelim_internal(s, 0) }

function singleton_option(opt) {
	return tolower(opt) !~ /^(acceptenv|allowgroups|allowusers|denygroups|denyusers|hostcertificate|hostkey|listenaddress|logverbose|permitlisten|permitopen|port|setenv|subsystem)$/
}

function print_update() {
	if (mode) {
		if (match_only) printf "\t"
		printf "%s\n", line_should
		updated = 1
	}
}

BEGIN {
	FS = "\n"  # disable field splitting

	WHITESPACE = "[ \t]"  # servconf.c, misc.c:strdelim_internal (without line breaks, cf. bugs)
	QUOTE = "[\"]"  # misc.c:strdelim_internal
	EQUALS = "[=]"

	split("", opts)
	split("", files)
	getopt("ho:l:m:", ARGV, opts, files)

	if (opts["h"]) { usage(); exit (e="0") }

	line_should = opts["l"]
	match_only = opts["m"]
	num_files = alength(files)

	if (num_files != 1 || !opts["o"] || !line_should) {
		usage()
		exit (e=126)
	}

	if (opts["o"] == "set") {
		mode = 1
	} else if (opts["o"] == "unset") {
		mode = 0
	} else {
		print_err(sprintf("invalid mode %s\n", mode))
		exit (e=1)
	}

	if (mode) {
		# loop over sshd_config twice!
		ARGV[2] = ARGV[1] = files[1]
		ARGC = 3
	} else {
		# only loop once
		ARGV[1] = files[1]
		ARGC = 2
	}

	split(strdelim(line_should), should, SUBSEP)
	option_should = tolower(should[1])
	value_should = should[2]
}

{
	line = $0

	# Strip trailing whitespace. Allow \f (form feed) at EOL only
	sub("(" WHITESPACE "|\f)*$", "", line)

	# Strip leading whitespace
	sub("^" WHITESPACE "*", "", line)

	if (match(line, "^#" WHITESPACE "*")) {
		prefix = substr(line, RSTART, RLENGTH)
		line = substr(line, RSTART + RLENGTH)
	} else {
		prefix = ""
	}

	line_type = "invalid"
	option_is = value_is = ""

	if (line) {
		split(strdelim(line), toks, SUBSEP)

		if (tolower(toks[1]) == "match") {
			MATCH = (prefix ~ /^#/ ? "#" : "") join(" ", toks, 2)
			line_type = "match"
		} else if (toks[1] ~ /^[A-Za-z][A-Za-z0-9]+$/) {
			# This could be an option line
			line_type = "option"
			option_is = tolower(toks[1])
			value_is = toks[2]
		}
	} else {
		line_type = "empty"
	}
}

# mode: unset

!mode {
	# delete matching config
	if (prefix !~ /^#/)
		if (MATCH == match_only && option_is == option_should)
			if (!value_should || value_should == value_is)
				next

	print
	next
}


# mode: set

mode && NR == FNR {
	if (line_type == "option") {
		if (MATCH !~ /^#/) {
			if (prefix ~ /^#/) {
				# comment line
				last_occ[MATCH, "#" option_is] = FNR
			} else {
				# option line
				last_occ[MATCH, option_is] = FNR
			}
			last_occ[MATCH] = FNR
		}
	} else if (line_type == "invalid" && !prefix) {
		# INVALID LINE
		print_err(sprintf("%s: syntax error on line %u\n", ARGV[0], FNR))
	}

	next
}

# before second pass prepare hashes containing location information to be used
# in the second pass.
mode && NR > FNR && FNR == 1 {
	# First we drop the locations of commented-out options if a non-commented
	# option is available. If a non-commented option is available, we will
	# append new config options there to have them all at one place.
	for (k in last_occ) {
		if (k ~ /^#/) {
			# delete entries of commented out match blocks
			delete last_occ[k]
			continue
		}

		split(k, parts, SUBSEP)

		if (parts[2] ~ /^#/ && ((parts[1], substr(parts[2], 2)) in last_occ))
			delete last_occ[k]
	}

	# Reverse the option => line mapping. The line_map allows for easier lookups
	# in the second pass.
	# We only keep options, not top-level keywords, because we can only have
	# one entry per line and there are conflicts with last lines of "sections".
	for (k in last_occ) {
		if (!index(k, SUBSEP)) continue
		line_map[last_occ[k]] = k
	}
}

# Second pass
mode && line_map[FNR] == match_only SUBSEP option_should && !updated {
	split(line_map[FNR], parts, SUBSEP)

	# If option allows multiple values, print current value
	if (!singleton_option(parts[2])) {
		if (value_should != value_is)
			print
	}

	print_update()

	next
}

mode { print }

# Is a comment option
mode && line_map[FNR] == match_only SUBSEP "#" option_should && !updated {
	print_update()
}

# Last line of the should match section
mode && last_occ[match_only] == FNR && !updated {
	# NOTE: Inserting empty lines is only cosmetic.  It is only done if
	#       different options are next to each other and not in a match block
	#       (match blocks are usually not in the default config and thus don’t
	#       contain commented blocks.)
	if (line && option_is != option_should && !MATCH)
		print ""
	print_update()
}

END {
	if (e) exit e

	if (mode && !updated) {
		if (match_only && MATCH != match_only) {
			printf "\nMatch %s\n", match_only
		}

		print_update()
	}
}
