#!/bin/sh

# Generate filelist excluding stuff that takes only space
(
    for pkg in systemd openssh \
          bash  bzip2  coreutils  cryptsetup  device-mapper  dhcpcd \
          diffutils  e2fsprogs  file filesystem  findutils  gawk    \
          gettext  glibc  grep  gzip  inetutils iproute2  \
          iputils  jfsutils  less  licenses  linux  logrotate  lvm2 \
          man-db man-pages  mdadm  nano  pacman  pciutils   \
          pcmciautils  procps-ng psmisc  reiserfsprogs        \
          s-nail  sed  shadow  sysfsutils  systemd-sysvcompat  tar  \
          usbutils  util-linux  vi  which  xfsprogs        \
    ; do
        pacman -Qlq $pkg | grep -v  \
            -e /usr/share/man/      \
            -e /usr/share/doc/      \
            -e /usr/include

    done
) | sort | uniq
