cat newsgroups.lst | grep -v  ^#|grep \\. \
	| awk '{print "echo " $2 " > newsgroups/" $1 "/address.txt";}'
