#!/bin/sh

fakeroot pacman -r $(pwd -P)/preos -Syu --noconfirm --cachedir $(pwd -P)/preos/var/cache/pacman base 

