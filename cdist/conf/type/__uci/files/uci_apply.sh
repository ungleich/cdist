changes=$(uci changes)

if test -n "${changes}"
then
	echo 'Uncommited UCI changes were found on the target:'
	printf '%s\n\n' "${changes}"
	echo 'This can be caused by manual changes or due to a previous failed run.'
	echo 'Please investigate the situation, revert or commit the changes, and try again.'
	exit 1
fi >&2

check_errors() {
	# reads stdin and forwards non-empty lines to stderr.
	# returns 0 if stdin is empty, else 1.
	! grep -e . >&2
}

commit() {
	uci commit
}

rollback() {
	printf '\nAn error occurred when trying to commit UCI transaction!\n' >&2

	uci changes \
	| sed -e 's/^-//' -e 's/\..*\$//' \
	| sort -u \
	| while read -r _package
	  do
		  uci revert "${_package}"
		  echo "${_package}"  # for logging
	  done \
	| awk '
	  BEGIN { printf "Reverted changes in: " }
	  { printf "%s%s", (FNR > 1 ? ", " : ""), $0 }
	  END { printf "\n" }' >&2

	return 1
}

uci_apply() {
	uci batch 2>&1 | check_errors && commit || rollback
}
