#!/bin/sh
#
# Copyright 1999 Igor Chudov
#
# This file is part of WebSTUMP.
# 
# WebSTUMP is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# WebSTUMP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with WebSTUMP.  If not, see <https://www.gnu.org/licenses/>.

# This file creates a little .posted_log file in your home 
# directory. Runs if activeated by crontab. See your crontab
# file for more details.

cat newsgroups.lst | grep -v  ^#|grep \\. \
	| awk '{print "echo " $2 " > newsgroups/" $1 "/address.txt";}'
