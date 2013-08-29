die() {
   echo "[__install_partition_msdos_apply] $@" >&2
   exit 1
}
debug() {
   #echo "[__install_partition_msdos_apply] $@" >&2
   :
}

fdisk_command() {
   local device="$1"
   local cmd="$2"

   debug fdisk_command "running fdisk command '${cmd}' on device ${device}"
   printf "${cmd}\nw\n" | fdisk -c -u "$device"
   ret=$?
   # give disk some time
   sleep 1
   return $ret
}

create_disklabel() {
   local device=$1

   debug create_disklabel "creating new msdos disklabel"
   fdisk_command ${device} "o"
   return $?
}

toggle_bootable() {
   local device="$1"
   local minor="$2"
   fdisk_command ${device} "a\n${minor}\n"
   return $?
}

create_partition() {
  local device="$1"
  local minor="$2"
  local size="$3"
  local type="$4"
  local primary_count="$5"

  if [ "$type" = "extended" -o "$type" = "5" ]; then
    # Extended partition
    primary_extended="e\n"
    first_minor="${minor}\n"
    [ "${minor}" = "4" ] && first_minor=""
    type_minor="${minor}\n"
    [ "${minor}" = "1" ] && type_minor=""
    type="5"
  elif [ "${minor}" -lt "5" ]; then
    primary_extended="p\n"
    first_minor="${minor}\n"
    [ "${minor}" = "4" ] && first_minor=""
    type_minor="${minor}\n"
    [ "${minor}" = "1" ] && type_minor=""
  else
    # Logical partitions
    first_minor="${minor}\n"
    type_minor="${minor}\n"
    primary_extended="l\n"
    [ "$primary_count" -gt "3" ] && primary_extended=""
  fi
  [ -n "${size}" ] && size="+${size}M"
  fdisk_command ${device} "n\n${primary_extended}${first_minor}\n${size}\nt\n${type_minor}${type}\n"
  return $?
}
