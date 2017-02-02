#!/bin/sh

abspath=$(command -v "$1")
pacman -Qoq "$abspath"
