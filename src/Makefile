
all: ../bin/wrapper

../bin/wrapper: wrapper.c
	$(CC) -o $@ -DWEBSTUMP_HOME=\"$(WEBSTUMP_HOME)\" wrapper.c
	chmod 755 $@
	chmod u+s $@
	ls -l $@
