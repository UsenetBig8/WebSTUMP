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

# If you run make from the webstump directory you shouls not need
# to edit these variables.

WEBSTUMP_HOME = $(CURDIR)
CC = cc

# do not edit below
all: verify c_compile

verify:
	@if [ ! -x $(WEBSTUMP_HOME)/scripts/webstump.pl ] ;  then	\
		echo $(WEBSTUMP_HOME)/scripts/webstump.pl does not; 	\
		echo point to a valid perl script.;			\
		echo Run make from the webstump directory;		\
		echo \(cd webstump\; make\);				\
		echo If that does not work, set the value of;		\
		echo WEBSTUMP_HOME in Makefile;				\
		exit 1;							\
	fi	\


c_compile:
	cd src; make WEBSTUMP_HOME=$(WEBSTUMP_HOME)

clean: 
	rm bin/wrapper

# For people working on the code:

# run the tests
# note that 'cover -test' will use the 'test' target to generate a coverage report
.PHONY: test
test:
	prove -I scripts t
	
# generate a test coverage report - or use 'cover -test'
coverage:
	cover -delete
	for f in t/*.t; do perl -MDevel::Cover -I scripts $$f; done
	cover -report html

