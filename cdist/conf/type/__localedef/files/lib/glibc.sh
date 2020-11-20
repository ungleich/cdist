# -*- mode: sh; indent-tabs-mode: t -*-

gnu_normalize_codeset() {
	echo "$*" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]'
}
