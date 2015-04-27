#!/usr/bin/perl -w

use strict;

#changes a roy corpus format without tags, to something similar to rev map file
#format:
#<s> <s>
# [..]
# [..]
#...
#</s> </s>
#...

#read first {sentence ...}

$_ = <>;
print "<s> <s>\n";

while(<>){
	chop;
	if (/^\s*\{sentence \#\d+\}\s*$/){
		print "</s> </s>\n";
		print "<s> <s>\n";
	}
	elsif (/\s+(\S+)\s+(.+)$/){
		my $parse = $2;		
		#remove trailing spaces
		if ($parse =~ /$(.+\S+)\s+$/){
			$parse = $1;
		}
		print "\t[$parse]\n";
	}
	else{
		die "unexpected format in $_\n";
	}
}
print "</s> </s>\n";

