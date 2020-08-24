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

all: ../bin/wrapper

../bin/wrapper: wrapper.c
	$(CC) -o $@ -DWEBSTUMP_HOME=\"$(WEBSTUMP_HOME)\" wrapper.c
	chmod 755 $@
	chmod u+s $@
	ls -l $@
