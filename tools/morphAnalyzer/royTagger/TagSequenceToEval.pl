#!/usr/bin/perl -w
$tagseqfile = $ARGV[0];
$revmapfile = $ARGV[1];

open(TH,"<" . $tagseqfile) or die "Can't open $tagseqfile\n";
open(RH,"<" . $revmapfile) or die "Can't open $revmapfile\n";

#-----------------
# REUT 24-10-2005
#-----------------
#
# get probabilities file
$probfile = $ARGV[2];

# get sentence number
if ($#ARGV > 2) { 
$sentnumber = $ARGV[3];
}
else {
$sentnumber = 1;
print STDERR "sentence number undefined, set to 1\n";
}
# get printprob (yes|no)
if ($#ARGV > 3) {
$printprob = $ARGV[4];
}
else {
$printprob = 0;
print STDERR "printprob number undefined, set to 0\n";
}
#-----------------

#-----------------
# REUT 24-10-2005
#-----------------
#get the next line
my $tagSeq = "";
while ($tagSeq = <TH>)
{

#get the next tag sequence
while($tagSeq !~ /\[/ and $tagSeq) {
  $tagSeq = <TH>;
}
#------------------

#-----------------
# REUT 24-10-2005
#-----------------
# get nbest-count number
# get the probability value from the input line
if ($tagSeq =~ s/^NBEST\_(\w+)(\s+)(\-\S+)//) {
$printprob = 2;
$prob = $3;
}
# get the probability value from a .probs file
elsif ($printprob > 0) {
  $prob = 0;
  open(PH,"<" . $probfile) or die "Can't open $probfile\n";
  $line = <PH>;
  if ($line =~ s/^(\S+)//) {
     $prob = $1;
  }
}
#-----------------

while ($tagSeq =~ s/\[.+?\]//) {
  $analysis = $&;

  #translate the analysis back to parse, using the reverse mapping file
  $revMapLine = <RH>;
  while ($revMapLine !~ /\[/) {
    $revMapLine = <RH>;   
  }
  $analysis1 = $analysis;
  $analysis1 =~ s/([\[\]])//g;
  $revMapLine =~ /\[$analysis1\]/;
  $rest = $';
  $rest =~ /\{(.+?)\}/;
  $parse = $1;
  $parse =~ s/\) \(/\)\(/g;
  print "[$parse]";
}

if ( $printprob > 0 ) {
print "\t$prob";
}
print "\n";

#-----------------
# REUT 24-10-2005
#-----------------
# read the reverse map again
close(RH);
open(RH,"<" . $revmapfile) or die "Can't open $revmapfile\n";
}
# mark end of nbest analyses
if ( $printprob > 1 ) {
print "#\n";
}
#----------------
