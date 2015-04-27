#!/usr/bin/perl -w

#use lib "$ENV{HOME}/D-Roy/D-Scripts/";




#use lib "/usr/local/apache-tomcat-5.5.12/webapps/HMMTagger/royTagger";
use lib "/data/tagger/royTagger";
use MorphTranslation;



#TODO: the gold file should be the same as the corpus format for user 
#convenient
if ($#ARGV < 0 || $ARGV[0] eq "-help") {
  print STDERR <<"EOF";

MorphEval Version 1.0. Copyright 2005, Roy Bar-Haim

Usage: MorphEval.pl [-nopunc] goldfile taggingfile [outputfile]

goldfile        A file containing the correct analysis of the words 
                in the test file. The file format is the same as the  
                output format of MorphTagger.

taggingfile     Output file which contains the tagging result.

outputfile      the name of evaluation files. The default is the
                tagging file (+err,eval).

-nopunc         If specified, punctuations are ignored (including numbers)

-help           print this message
EOF
  exit;
}


sub group_cat {
 my ($analysis) = @_;
 my $ganalysis = "";
 my ($cat,$gcat,$morph);  
# print STDERR "[$analysis] [$ganalysis]\n";
 while ($analysis =~ s/\((\S+)\s(\S+)\)//) {
   ($cat,$morph) = ($1,$2);
   $gcat = GetGroupOf($cat);
#   print STDERR "[$analysis] [$ganalysis] [$morph] [$cat] [$gcat]\n";
   $ganalysis .= "(" . $gcat . " " . $morph . ")";
 }
# print "--> $ganalysis\n";
 $_[0] = $ganalysis;      
 return;
}

if ($ARGV[0] eq '-G') {
    $cat_group = 1;
    shift @ARGV
}
else {
    $cat_group = 0; 
}

if ($ARGV[0] eq "-nopunc") {
    $nopunc = 1;
    shift @ARGV
}
else {
    $nopunc = 0; 
}

$goldfile = $ARGV[0];
$testfile = $ARGV[1];
if (@ARGV == 3) {
	$outfile = $ARGV[2];
}
else {
	#$outfile = $goldfile."-".$testfile;
	#to allow full paths to be used (../data/...)
	$outfile = $testfile;
}
#$goldfile =~ /^.*\/?([^\/]+)$/;
#$outfile = $1 . "-";
#$testfile =~ /^.*\/?([^\/]+)$/;
#$outfile = $outfile . $1;

$outfile .= ".gcat" if ($cat_group); 

open(GH,"<" . $goldfile);  # "gold" sentences
open(TH,"<" . $testfile);  # test (result) sentences

my $numpunc = 0;
my @goldfile = <GH>;
my @testfile = <TH>;

close(TH);
close(GH);

if ($nopunc){
	$numpunc = &RemovePunc(\@goldfile);
	&RemovePunc(\@testfile);
}

open(OH,">" . $outfile.".eval");
open(EH,">" . $outfile.".err");

$sno = 0;
$words =0;
$morphs =0;  
$err = 0;
$segerr =0;
$nofunc = 0;
my ($nnpheu, $nnpheuc, $prob) = (0,0,0);

print  OH "               words              segmentations\n";
print  OH "#      count   correct  %crct     correct  %crct     prob\n";
print  OH "-----------------------------------------------------------\n"; 
while($gold=shift @goldfile and $gold!~/^\s*$/) {
  $sno++;
  $morphs++;
  $swords = 0;
#  $smorphs = 0;
  $serr = 0;
  $ssegerr = 0;
  $test=shift @testfile;

  if ($test =~ /^NBEST_\d+\s+(\S+)\s+(.+)$/){
	  $prob = $1;
  }
  else {$prob = 0;}
  
  while ($gold =~ s/\[(.+?)\]//) {
    $gword = $1;
    if ($gword =~ /\(NO_FUNC/){
    	#print STDERR "[$gword]\n";
    	$nofunc++;
    	$test=~s/\[(.+?)\]//;
    	next;
    }
    $words++;
    $swords++;    
    if ($test =~ s/\[(.+?)\]//) {
      $tword = $1;
    }
    else {
      print EH "test sentence $sno length doesn't match\n";
      die;
    }
 
    # if -G is specified - translate categories to their representatives 
    # in their equivalence classes
    if ($cat_group) {
#        print "GOLD:$gword "; 
 	group_cat($gword);
#        print "$gword\n";

#        print "TEST:$tword "; 
	group_cat($tword);
#        $tword = RemoveFullFeaturesFromParse($tword); 
 #       print " $tword\n"; 
    }      


    if ($gword ne $tword) {
    	if ($tword =~ /^\s*\(XXX \S+?\)\s*$/){
    		$nnpheu++;
    		if ($gword =~ /^\s*\(NNP \S+?\)\s*$/){
	    		#print STDERR "[$gword]\t[$tword]\n";
	    		$nnpheuc++;
	    		next;
    		}
    	}
      $serr++;
      $gseg= $gword;
      $gseg =~ s/\(\S+(\s\S+)\)/$1/g;
      $gseg =~ s/^\s+//;
      $tseg= $tword;
      $tseg =~ s/\(\S+(\s\S+)\)/$1/g;
      $tseg =~ s/^\s+//;

      if ($gseg ne $tseg) {
	$ssegerr++;
        print EH "($sno) segmentation err:[$tseg] instead of [$gseg] ($tword instead of $gword)\n";
      }
      else {
        print EH "($sno) tagging err:[$tword] instead of [$gword]\n";
      }      
    }  
  }
  $err += $serr;
  $segerr += $ssegerr;
  my $tagprob = (($swords-$serr)*100/$swords);
  my $segprob = (($swords-$ssegerr)*100/$swords);
  printf OH "%2d    %2d      %2d       %6.2f     %2d     %6.2f     %2.4f\n",
    $sno,$swords,$swords-$serr,$tagprob,$swords-$ssegerr,$segprob,$prob;
}

print OH "number of words: $words\n";
print OH "number of ignored puncs: $numpunc\n";
printf OH "number of correctly tagged words: %d (%6.2f%%)\n",
          $words-$err,100*($words-$err)/$words;
printf OH "number of tagging errors: %d (%6.2f%%)\n",
          $err,100*$err/$words;
printf OH "number of correctly segmented words: %d (%6.2f%%)\n",
          $words-$segerr,100*($words-$segerr)/$words;
printf OH "number of segmentation errors: %d (%6.2f%%)\n",
          $segerr,100*$segerr/$words;

if ($numpunc!=0){
	my $tokens = $words+$numpunc;
	printf OH "correctly tagged words (including puncs): %d (%6.2f%%)\n",
          $tokens-$err,100*($tokens-$err)/$tokens;
	printf OH "correctly segmented words (including puncs): %d (%6.2f%%)\n",
          $tokens-$segerr,100*($tokens-$segerr)/$tokens;
}

printf OH "NO_FUNC: %d (%6.2f%%)\n",
          $nofunc,100*$nofunc/($words+$nofunc);
printf OH "correct nnp heuristics: %d (%6.2f%%)\n",
          $nnpheuc,($nnpheu)?100*$nnpheuc/$nnpheu:"NAN";

close(EH);
close(OH);
print STDERR "The output was written to $outfile.(err,eval)\n";






###############################################
#gets an array of sentences and removes punc and returns
#their number
sub RemovePunc(){
	my $sentences = shift @_; #ref to list
	my $numpunc = 0;
	for(my $i=0; $i < @$sentences; $i++){
		$numpunc += ($$sentences[$i] =~ s/\(PUNC .+?\)//g);
		$numpunc += ($$sentences[$i] =~ s/\(CD NUM\)//g);
		$numpunc += ($$sentences[$i] =~ s/\(CD [^a-oq-z]+\)//g);
		$numpunc += ($$sentences[$i] =~ s/\(FW .+?\)//g);
		$numpunc += ($$sentences[$i] =~ s/\(\S+ \S*\d\S*\)//g);
		#adjustments because of differences between different versions of BW
		$$sentences[$i] =~ s/YB/U/g;
		
		$$sentences[$i] =~ s/\[\]//g;
	}
	
	return $numpunc;
}

	
