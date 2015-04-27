#!/usr/bin/perl -w

#analyses.morph.map analyses.morph.revmap corpus.morph.lm 3 kaka . 1 1 1
#smalltest.map goldrevf corpus.lm 3 kaka . 1 1 0
my $LOWPROB = -30;
my $NORM = 0.001;
my $NORMLOG = -3; #log($NORM)/log(10);

print STDERR "low probability: $LOWPROB\n",
			 "normalize factor: $NORM\n";

$mapfile = $ARGV[0];
$revmapfile = $ARGV[1]; #in case of gold it will be gold segmentation mtgold [w Akl][..]...
$lmfile = $ARGV[2];
$order  = $ARGV[3];
$outputfile = $ARGV[4];
$workdir = $ARGV[5];
$typeofrun = $ARGV[6];

my $mapfilename = $mapfile;
if ($mapfilename =~ /\/([^\/]+)$/){
	$mapfilename = $1;
}

#my $mtdir = "/usr/local/apache-tomcat-5.5.12/webapps/HMMTagger/royTagger";
my $mtdir = "/data/tagger/royTagger";

#-----------------
# REUT 24-10-2005
#-----------------
# get nbest number
# set print prob (yes/no) 
if ($#ARGV > 6) {
$nbest = $ARGV[7];
$withprobs = $ARGV[8];
$svm = $ARGV[9];
#print STDERR "RunTagger nbest = $nbest";
}
else {
$nbest = 1;
$withprobs = 0;
#print STDERR "RunTagger nbest = $nbest";
}
#-----------------

my $retagfile = "retagstat";

open(RETAG, ">$workdir/$retagfile") or die "can't open $workdir/$retagfile: $!" if $svm;
#this is the final map that was used!
open(MAP, ">$workdir/analyses.map") or die "can't open $workdir/analyses.map: $!" if $svm;

$sntcount = 0;
open(MF,"<" . $mapfile) or die "Can't open $mapfile\n";
open(RMF,"<" . $revmapfile) or die "Can't open $revmapfile\n";
if ($svm){
	open(MFSVM,"<  $mapfile\.svm") or die "Can't open $mapfile\.svm\n";
	open(RMFSVM,"< $revmapfile\.svm") or die "Can't open $revmapfile\.svm\n";
}

`rm -f $outputfile`;
while() {
  $sntcount++;  

  # read next sentence

  $sentmap = "";
  $revsentmap = "";
  $sentmapsvm = "";
  $revsentmapsvm = "";
  
  #28.9.07 DALIA
  my $isnewparagraph = 0;
  
  #split to two whiles because MF length might not be the same as RMF
  #in case of gold RMF contains a word per line, and MF a morpheme per line
  while ($line=<MF>) {
  	
  	#28.9.07 DALIA
	  if ($line =~ /^\s*<\/p> <\/p>\s*$/){
		  $isnewparagraph = 1;
		  next;
	  }
	  
    $sentmap .= $line;
	if ($svm){
		$sentmapsvm .= <MFSVM>;
	}
		
    last if $line =~ /<\/s> <\/s>/;
  }
  
  while ($line=<RMF>) {
    $revsentmap .= $line;
	if ($svm){
		$revsentmapsvm .= <RMFSVM>;
	}
		
    last if $line =~ /<\/s> <\/s>/;
  }

  if ($typeofrun eq "gold"){
	  #remove <s>, </s>, spaces
	  $revsentmap =~ s/\<s\>//g;
	  $revsentmap =~ s/\<\/s\>//g;
	  $revsentmap =~ s/\s+\[/\[/g;
	  $revsentmap =~ s/\]\s+/\]/g;
	  $revsentmapsvm = $revsentmap;
  }
  
  last unless ($sentmap);
  print STDERR "Tagging sentence no: $sntcount\r"; 
  #print STDERR "$sntcount "; 
  open(TMP,">".$workdir."/$mapfilename.sentmap") or die "Can't open $workdir/$mapfilename.sentmap for output";
  print TMP $sentmap;
  close(TMP);
  open(TMP,">".$workdir."/$mapfilename.sentrevmap") or die "Can't open $workdir/$mapfilename.sentrevmap for output";
  print TMP $revsentmap;
  close(TMP);

  # tag sentence
  `rm -f $workdir/$mapfilename.tagging`;
#-----------------
# REUT 24-10-2005
#-----------------
# added $nbest argument to disambig command line
# added output probabilities to disambig (for nbest=1)
# added $printprob to TagSequenceToEval command line
  `disambig -text-map $workdir/$mapfilename.sentmap -lm $lmfile -order $order -nbest $nbest > $workdir/$mapfilename.tagging`;
  #add probabilities in case of nbest==1 because normal disambig doesn't output it
  `disambig -text-map $workdir/$mapfilename.sentmap -lm $lmfile -order $order -nbest $nbest -totals > $workdir/$mapfilename.probs` if ($nbest==1 and ($svm or $withprobs));
  
  if ($svm){
	  #get probability
	  my $prob = GetProb();
	  my $len = GetLength();
	  #if prob low and different analyses
	  if (($prob-$NORMLOG*$len) < $LOWPROB and $sentmap ne $sentmapsvm){
		print RETAG "retagging $sntcount with prob:[$prob], len:[$len], norm:[",$prob-$NORMLOG*$len,"]\n"; #old tag:$sentmap\nnew tag:$sentmapsvm\n"; 
		#create new sentmap and sentrevmap from files including svm
		open(TMP,">".$workdir."/$mapfilename.sentmap") or die "Can't open $workdir/$mapfilename.sentmap for output";
		print TMP $sentmapsvm;
		close(TMP);
		open(TMP,">".$workdir."/$mapfilename.sentrevmap") or die "Can't open $workdir/$mapfilename.sentrevmap for output";
		print TMP $revsentmapsvm;
		close(TMP);
		
		#final sentmap used
		$sentmap = $sentmapsvm;
		
		#disambig again
		`rm -f $workdir/$mapfilename.tagging`;
		`disambig -text-map $workdir/$mapfilename.sentmap -lm $lmfile -order $order -nbest $nbest > $workdir/$mapfilename.tagging`;
		#add probabilities in case of nbest==1 because normal disambig doesn't output it
		`disambig -text-map $workdir/$mapfilename.sentmap -lm $lmfile -order $order -nbest $nbest -totals > $workdir/$mapfilename.probs` if ($nbest==1 and ($svm or $withprobs));
  
		#[TODO] if increases previous prob then ok, otherwise restore
		print RETAG "new prob [", GetProb(), "]\n";
	  }	  
	  
  }
  
  print MAP "$sentmap" if $svm;
  
  #28.9.07 DALIA
	  if ($isnewparagraph){
		  open(OUT,">>$outputfile") or die "Can't open $outputfile\n";
		  print OUT "</paragraph>\n";
		  close(OUT);
	  }
	  
  if ($typeofrun eq "normal"){
	`$mtdir/TagSequenceToEval.pl $workdir/$mapfilename.tagging $workdir/$mapfilename.sentrevmap $workdir/$mapfilename.probs $sntcount $withprobs >>$outputfile`;
  }
  else{
	`$mtdir/TaggedMorphsToEval.pl $workdir/$mapfilename.tagging $workdir/$mapfilename.sentrevmap >>$outputfile`;
  }
  
  
  
#---------------
  
}
printf STDERR "\n";

open(OUT,">>$outputfile") or die "Can't open $outputfile\n";
print OUT "EOF\n";
close(OUT);



if ($svm){
	close(RMFSVM);
	close(MFSVM);
	close(RETAG);
}
close(MF);
close(RMF);


#####################3
sub GetProb{
	my $prob;
	if ($nbest==1){
		open(PROB,"< $workdir/$mapfilename.probs") or die "couldn't find file $workdir/$mapfilename.probs: $1\n";
		$prob = <PROB>;
		close(PROB);
		
		chop $prob;		
		return $prob;
	}
	else{
		open(PROB,"< $workdir/$mapfilename.tagging") or die "couldn't find file $workdir/$mapfilename.tagging: $1\n";
		$prob = <PROB>;
		close(PROB);
		$prob =~ /^\s*NBEST_\d+\s+([0-9-.]+)\s+/;
		$prob = $1;
		return $prob;
	}
}


#####################3
sub GetLength{
	my $line;
	open(TAG,"< $workdir/$mapfilename.tagging") or die "couldn't find file $workdir/$mapfilename.tagging: $1\n";
	$line = <TAG>;
	close(TAG);
	my @numsp = ($line =~ / /g);
	return @numsp;
}
