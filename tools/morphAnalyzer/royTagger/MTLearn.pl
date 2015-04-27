#!/usr/bin/perl -w

#MTLearn

#learn phase for morphtagger

use strict;

#my $mtdir = "/usr/local/apache-tomcat-5.5.12/webapps/HMMTagger/royTagger";
my $mtdir = "/data/tagger/royTagger";


######################### parse command line #####################
if ($#ARGV < 0 || $ARGV[0] eq "-help") {
  print STDERR <<"EOF";

MorphTagger Version 1.0. Copyright 2005, Roy Bar-Haim

Usage: MTLearn.pl [options] corpusfile [lmfile lexprobfile]

lmfile          specifies the name of the language model file to be
                generated. If not specified, corpus.lm is generated in
                the working directory.
				
lexprobfile     specifies the name of the lexical probabilities file
                to be generated. If not specified, corpus.lex.prob 
                is generated in	the working directory.
				
corpusfile      a tagged training corpus. See software documentation 
                for further details on the required format for this
                file.

OPTIONS:
-a filename  
                The file could be an already generated ambigous corpus
                by CreateAmbigousCorpus.pl, or an analyses file for which
                an ambiguous probabilistic corpus will be created. See software 
                documentation for further details on the required format for 
                this file. The ambiguous corpus is used to estimate
                lexical probabilities, which are interpolated 
                with lexical probabilities estimated from the tagged 
                corpus.

-lambda f       f should be between 0 and 1. Used for interpolation
                between lexical probabilities obtained from the tagged 
                corpus and the ambiguous corpus: 
                lambda*P(tagged corpus)+(1-lambda)*P(ambiguous corpus)
                Default value:0.85
                This option may be specified only in conjunction with
                -ambig-corpus or -bootstrap-input.                  
				
-n ngram-order  ngram-order should be an integer between 1 and 5. Sets the order
                of the ngram model used for the HMM model for tagging.
		
-dir workdirname
                a directory into which all the temporary files will be 
                written. If the directory does not exist, it will be created.
                The default value is .MorphTaggerWorkDir.
				
-help           print this message
EOF
  exit;
}

############ setting the defaults
my $lambda;
my $order = 3;
my $ambigcorpusfile = "";
my $corpusfile = "";
my $analysesfile = "";

my $lmfile = "corpus.lm";
my $lexprobfile = "corpus.lex.prob";
my $workdir = ".MorphTaggerWorkDir";

my $nbest = 2;
#$cleanworkdir = 0;

############## parsing parameters
my $ok =0;

while (@ARGV) {
  my $arg = shift @ARGV;

  ### -ambig-corpus <filename>   
  if ($arg eq "-a") {
    die "missing argument for -a\n" unless (@ARGV);
    $ambigcorpusfile = shift @ARGV;
    die "$ambigcorpusfile was not found\n" unless -e $ambigcorpusfile;
  }

  ### -lambda <number> (default:0.85)
  elsif ($arg eq "-lambda") {
    die "missing argument for -lambda\n" unless (@ARGV);
    my $newlambda = shift @ARGV;    
    if ($newlambda >0 && $newlambda <1) {
      $lambda = 1-$newlambda;
    }
    else {
      die "Invalid value for -lambda\n"; 
    }
  }     

  #### -ngram-order n (default 3)
  elsif ($arg eq "-n") {
    die "missing argument for -n\n" unless (@ARGV);
    my $neworder = shift @ARGV;
    if ($neworder >=1 && $neworder <=5) {
      $order = $neworder;
    }
    else {
      die "Invalid value for -order (should be between 1 and 5)\n";
    }
  }  

  ### -workdir <dirname> (dedault:.MorphTagger)
  elsif ($arg eq "-dir") {
    die "missing argument for -dir\n" unless (@ARGV);
    $workdir = shift @ARGV;
  }
    
  ### not an option - we got to the required parameters
  else {
    die "Unknown option '$arg'; type $0 -help for information\n"
      if ($arg =~ /^-/);
    $corpusfile=$arg;
    die "$corpusfile was not found\n" unless -e $corpusfile;
    if (scalar(@ARGV)==2) {
      ($lmfile,$lexprobfile)=@ARGV;
      #die "$corpusfile was not found\n" unless -e $corpusfile;
      $ok=1;
    }    
    last;
  } 
}

unless ($ok) {
  die "Too many arguments ; type $0 -help for information\n" if (scalar(@ARGV)>2);
  die "Too few arguments ;  type $0 -help for information\n" if (scalar(@ARGV)<2 and scalar(@ARGV)!=0); 
}
die "-lambda may be specified only in conjunction with -ambig-corpus\n"
  if (defined($lambda) && $ambigcorpusfile eq "");

#set lambda to default value
if (!defined($lambda) && $ambigcorpusfile ne "") {$lambda = 0.15;}

`mkdir $workdir` unless -e $workdir;

######## make ambiguous corpus out of the input sentences if specified ###########
if ($ambigcorpusfile) {
  print STDERR "Handling ambigous corpus\n";
  `rm -f $workdir/analyses.probs`;
  if (! &WithProb($ambigcorpusfile)){
	`./CreateAmbiguousCorpus.pl -workdir $workdir $ambigcorpusfile $corpusfile $workdir/analyses.probs`;
	CheckStat("Estimation of probabilities for input analyses");

	`rm -f $workdir/ambigcorpus`;
	
	`mv $workdir/analyses.probs $workdir/ambigcorpus`;
	
	$ambigcorpusfile = $workdir . "/ambigcorpus";
  }
}

######################### Tagging #####################
##### create language model for morphemes
print STDERR "CREATING THE PROBABILISTIC MODEL:\n";
print STDERR "creating a backoff language model over morpheme tags:\n";

# convert the corpus to tag sequence format
`rm -f $workdir/corpus.tagseq`;
#print STDERR "$mtdir\n";
`$mtdir/CorpusToTagSequence.pl <$corpusfile > $workdir/corpus.tagseq`;
CheckStat("Conversion to tag sequence");

# create a backoff language model over morpheme tags
`rm -f $workdir/$lmfile`;
`ngram-count -order $order -text $workdir/corpus.tagseq -lm $workdir/$lmfile -gt1max 0`;
CheckStat("Generatoin of LM");

##### create the tagging model
print STDERR "Converting the morpheme-level model into a word-level HMM:\n";
`rm -f $workdir/analyses.morph.{map,revmap} $workdir/corpus.morph.lm`;
#TODO:the creation of the tag model is done even if gold segmentation is present.
#this is to create analyses.morph.revmap but it should be created seperately
#as it is merely a format
if ($ambigcorpusfile) {
  `./CountCorpus.pl $workdir/$lexprobfile $corpusfile $ambigcorpusfile $lambda`;   
}
else {
  `$mtdir/CountCorpus.pl $workdir/$lexprobfile $corpusfile -`;
}
CheckStat("HMM model creation");




####################### Adjust the output ########################

print STDERR "\nDONE!\n";

sub CheckStat {
  my $status = $?;
  if ($status) {
     printf STDERR "%s failed (exit status %d)\nMorphTagger terminated\n",$_[0],$status; 
     exit $status; 
  }
}



sub WithProb(){
	my $ambigcorpusfile = shift @_;
	
	open(AM,"<$ambigcorpusfile") or die "couldn't open $ambigcorpusfile: $!\n";
	
	while(<AM>){
		#with prob
		if (/^\s+\d+\.\d+\s+\(\S+ \S+\)/){
			close(AM);
			return 1;
		}
		elsif (/^\s+\(\S+ \S+\)/){
			close(AM);
			return 0;
		}
	}
	
}



	
	
