
# Edit these variables

WEBSTUMP_HOME = /home/ichudov/public_html/stump/webstump
CC = cc

# do not edit below
all: verify c_compile

verify:
	if [ ! -x $(WEBSTUMP_HOME)/scripts/webstump.pl ] ;  then	\
		echo $(WEBSTUMP_HOME)/scripts/webstump.pl does not; 	\
		echo point to a valid perl script.;			\
		echo Check the value of WEBSTUMP_HOME in Makefile;	\
		exit 1;							\
	fi	\
	
	
c_compile:
	cd src; make WEBSTUMP_HOME=$(WEBSTUMP_HOME)

clean: 
	rm bin/wrapper
