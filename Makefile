# Copyright 1999 Igor Chudov
#
# This file is part of STUMP.
# 
# STUMP is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# STUMP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with STUMP.  If not, see <https://www.gnu.org/licenses/>.

# This file creates a little .posted_log file in your home 
# directory. Runs if activeated by crontab. See your crontab
# file for more details.

# Edit these variables

WEBSTUMP_HOME = /home/ichudov/public_html/stump/webstump
CC = cc

# do not edit below
all: verify c_compile

verify:
	@if [ ! -x $(WEBSTUMP_HOME)/scripts/webstump.pl ] ;  then	\
		echo $(WEBSTUMP_HOME)/scripts/webstump.pl does not; 	\
		echo point to a valid perl script.;			\
		echo Check the value of WEBSTUMP_HOME in Makefile;	\
		exit 1;							\
	fi	\


c_compile:
	cd src; make WEBSTUMP_HOME=$(WEBSTUMP_HOME)

clean: 
	rm bin/wrapper
