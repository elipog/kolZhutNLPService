#!/usr/bin/perl -w

package CorpusProbabilities;
require Exporter;

use strict;

#use lib "$ENV{HOME}/D-Roy/D-Scripts/";


use lib "/usr/local/apache-tomcat-5.5.12/webapps/HMMTagger/royTagger";

use MorphTranslation;
use Storable;


our @ISA = qw(Exporter);
our @EXPORT = qw(CountCorpus
                 %GPARSES
                 %GANALYSES
                 %GWORDANALYSISPAIRS
                 %CATS
                 %PAIRS
                 %GCATS
                 %GPAIRS
                 %GREVPAIRS
                 %CATCOUNTS
                 %PAIRCOUNTS
                 $PAIRCOUNT
				 $ANALYSESCOUNT
                 CountSublexicon          
                 %LEXGPARSES
                 %LEXGWORDANALYSISPAIRS
                 %LEXGCATS
                 %LEXGPAIRS
                 $LEXPAIRCOUNT
                 $LEXWORDCOUNT 
                 %PROBCATS  
                 %PROBGCATS
                 %PROBGANALYSES  
                 %PROBGPAIRS
                 %PROBGREVPAIRS                 
                 %PROBGWORDANALYSISPAIRS
                 CreateCombinedProbabilities
                 GetMorphProbGivenTagWithoutFeatures 
                 MatchParse
                 SetLambda
				 RetrieveCountCorpus
				 SaveLexicalProb
);

#removed
#                 %PARSES  
#                 %LEXPARSES  
#                 %LEXCATS
#                 %LEXPAIRS
#                 %PROBPAIRS                  
#                 $WORDCOUNT      

#REALLY GLOBAL
#PROBGPAIRS
#PROBGREVPAIRS
#PROBGCATS

our $VERSION = 1.00;

#%PARSES =();
our %GPARSES = (); 
our %GANALYSES = ();
our %CATS  =(); 
our %CATSMORPHFEATURES = ();
our %CATSFEATURES = ();
our %PAIRS =(); 
our %GCATS =(); 
our %GPAIRS =(); 
our %GREVPAIRS =(); 
our %GWORDANALYSISPAIRS = ();
our $PAIRCOUNT = 0;
our $ANALYSESCOUNT = 0;
our %CATCOUNTS =(); 
our %PAIRCOUNTS =(); 
#%LEXPARSES =();
our %LEXGPARSES = (); 
#%LEXCATS  =(); 
#%LEXPAIRS =(); 
our %LEXGCATS =(); 
our %LEXGPAIRS =();
our %LEXGWORDANALYSISPAIRS = ();
our $LEXPAIRCOUNT = 0;
our $LEXANALYSESCOUNT = 0;
#%PROBPAIRS =();
our %PROBGPAIRS =(); 
our %PROBGREVPAIRS = ();
our %PROBGCATS = ();
our %PROBGANALYSES = ();
our %PROBGWORDANALYSISPAIRS = ();


#my $C_SMOOTH_LIMIT=5;
my $C_N_0=1e5;
#my @C_P=(0.2,0.3,0.4,0.5,0.6,0.7);

#my $M_SMOOTH_LIMIT=5;
my $M_N_0=1e5;
#my @M_P=(1,1,1,1,1,1);
my $lambda = 0.5;

#my $ANALYSIS_LIMIT = 20;
#my @ANALYSIS_LAMBDAS = (1.0,0.95,0.9,0.85,0.8,0.75,0.7,0.65,0.6,0.55,
 #                        0.5,0.45,0.4,0.35,0.3,0.25,0.2,0.14,0.1,0.05);
                        
#my $lexpairref;
#my $cpairref;
#my $ccatref; 
#my $no_features = 0 ;

sub SetLambda {
  $lambda = shift;
  print STDERR "Lambda was set to $lambda\n";
}

sub print_set {
    print STDERR "[\n";
  foreach my $element (@_) {
    print STDERR "$element\n";
  }
  print STDERR "]\n";
}


sub MakeConsistent {
  my @features_set = @_;
  my ($std_feat,$j,$i,$max_length,$f);
  my @features_array=();
  $i=0;

  $max_length = 0;
  foreach my $feature (@features_set) {
    $max_length = length($feature) > $max_length ? length($feature) :
                          $max_length; 
    @{$features_array[$i++]} = split("",$feature);
  }
  
  $std_feat = "";
  for($i=0;$i<$max_length;$i++) {
    for($j=0;scalar(@{$features_array[$j]})<$max_length;$j++) {};
    $f=$features_array[$j][$i]; $j++;
    for (;$j<=$#features_set;$j++) { 
      next if (scalar(@{$features_array[$j]})<$max_length);   
      $f="B" if ($features_array[$j][$i] ne $f);  
    }
    $std_feat .= $f;
  }
  return $std_feat;
}

sub MatchTag {
  my ($tag,$morph) = @_;
  
  $tag =~ /^([A-Z]+)-([A-Z0-9-]+)$/;
  my ($cat,$features) = ($1,$2);
  
#  print STDERR "[$tag] [$morph] [$cat] [$features]\n";
  # first try to consider only features of the same morpheme
  
  my @features_set =  keys %{$CATSMORPHFEATURES{$cat}{$morph}};
  #print_set(@features_set);
  my $cfeatures = MakeConsistent(@features_set);
  my $fixed_tag = $cat . "-" . $cfeatures;
  return $fixed_tag if ((length($fixed_tag) == length($tag)) &&
		      ($CATSMORPHFEATURES{$cat}{$morph}{$cfeatures}));

  # otherwise, try to consider all the features of this category
  @features_set =  keys %{$CATSFEATURES{$cat}};
  #print_set(@features_set);  
  $cfeatures = MakeConsistent(@features_set);
  $fixed_tag = $cat . "-" . $cfeatures;
  return $fixed_tag if ((length($fixed_tag) == length($tag)) &&
		      ($CATS{$fixed_tag}));

  return $tag; 

}

sub MatchParse {
  my $parse = $_[0];
  my @parse=split(/\)/,$parse);
  my $mparse = ""; 
  foreach(@parse) {
    s/\(//go; s/\)//go; # remove all ('s and )'s
    if(/\S+/) {
      /^\s*(\S+)\s+(\S+)\s*$/; 
      my ($tag,$morph)=($1,$2);
      $morph = "NUM" if $morph =~ /\d+/;
                
      unless($CATS{$tag}) {
        my $mtag = MatchTag($tag,$morph);
        if ($mtag eq $tag) {
#          print STDERR "couldn't match tag $tag in morpheme $morph\n";	 
	  return ""; 
        }
#        print STDERR "tag $tag matched as $mtag in morpheme $morph\n";	 
        $tag = $mtag;
      } 
      $mparse .= "(" . $tag . " " . $morph . ") ";        
    }
  } 
  $mparse =~ s/\s+$//;
  return $mparse; 
}


#This function updates the followin GLOBAL variables (never use global variables :( )
#GPARSES
#GANALYSES
#GWORDANALYSISPAIRS
#ANALYSESCOUNT
#GCATS
#GPAIRS
#PAIRCOUNTS (using PAIRS)
#CATCOUNTS (using CATS)
#GREVPAIRS
sub CountCorpus {
  my ($corpus_file) = @_;
  open(CF,"<" . $corpus_file) or die "Can't open $corpus_file\n";
  my $scnt=0;
  while (<CF>) {
    chomp;
    my $line= $_;
    # start of next sentence.
    if (/^\s*\{sentence( #\d+)?\}\s*$/) {
      $scnt++;
      next;
    } 
    # validity tests 
#    next unless (/^ +(\S+)( ([\(\)\-A-Z0-9a-z\*\_\<\> ]+))?$/);
    /^\s*(\S+)\s+(\S.+)\s*$/;
    die "No parse available in $scnt for $1\n" unless defined($2);
 
    my ($word,$parse)=($1,$2); 
    #$word =~ s/yy//g;
    #$parse =~ s/yy//g; 
    #print STDERR "word=$word parse=$parse\n"; 
    $parse =~ s/\s+$//; $parse =~ s/^\s+//;
    #  increment  C(word) and C(word,parse)
  
#    $PARSES{$word}{$parse}++;
#    $PARSES{$word}{"**COUNT**"}++;
    
    my $gparse = $parse; 
#    $gparse = RemoveFeaturesFromParse($parse);    
    $GPARSES{$word}{$gparse}++;

    my $analysis = ParseToTagSequence($gparse);
    #$analysis =~ s/ /_/g;
    $GANALYSES{$analysis}++;
    $GWORDANALYSISPAIRS{$analysis}{$word}++;
    $ANALYSESCOUNT++;
    my @parse=split(/\)/,$parse);

    #iterate over the morphemes. 
    #for each morpheme m, full analysis(cartegory) c, and pos-tag p:
    # increment C(c),C(c,m),C(p),C(p,m) 
  
    foreach (@parse) {
      s/\(//go; s/\)//go; 
      if (/\S+/) {
	/^\s*(\S+)\s+(\S+)\s*$/;
        my ($tag,$morph)=($1,$2);
        print STDERR "!! $_ !!! $line $scnt \n" unless defined($morph);   
#        $CATS{$tag}++;
#        $PAIRS{$tag}{$morph}++;
#        $tag =~ /^([A-Z]+)-([A-Z0-9-]+)$/;
#        my ($cat,$features) = ($1,$2);        
#        $CATSMORPHFEATURES{$cat}{$morph}{$features} = 1;           
#        $CATSFEATURES{$cat}{$features}=1;
#        print STDERR "tag before: $tag\n"; 
#        $tag=RemoveFeaturesFromParse($tag);
#        print STDERR "tag after: $tag\n";

        $GCATS{$tag}++;
        $GPAIRS{$tag}{$morph}++;
        $PAIRCOUNT++;
      }
    }
  }
  close(CF);

  # count how many categories appeared X times
  while (my ($cat,$count)=each(%CATS)) {
    $CATCOUNTS{$count}++;
  }

  # smoothing - giving a non-zero probability for non-occuring categories
  $CATCOUNTS{0}=$C_N_0;

  # count how many (morpheme,category) pairs appeared X times
  foreach my $cat (keys %PAIRS) {
    while (my ($morph,$count)=each(%{$PAIRS{$cat}})) {
      $PAIRCOUNTS{$count}++;
    } 
  }

  ReversePairs(\%GPAIRS,\%GREVPAIRS);

  # smoothing for non-occuring pairs.
  $PAIRCOUNTS{0}=$M_N_0;

}

sub CountSublexicon {
  my ($corpus_file) = @_;
  my ($word,$prob,$parse,$line,$mparse);
  open(CF,"<" . $corpus_file) or die "Can't open $corpus_file\n";
  print STDERR "COUNTING WORD #:";
  my $scnt=0;
  my $wcnt=0;
  while (<CF>) {
    chomp;
    if (/([\d\.]+)\s(.+$)/) {
      $prob = $1; 
      $parse = $2; 
      #$parse =~ s/yy//g;      
      $parse =~ s/^\s+//; $parse =~ s/\s+$//; #removing leading and trailing
                                              # white spaces

#      $parse = FixParseFeatures($parse);
#      $mparse = MatchParse($parse);
#      $parse = $mparse if ($mparse ne "");
#      print "<$word><$prob><$parse>\n"; 
#      $LEXPARSES{$word}{$parse}+=$prob;
#      $LEXPARSES{$word}{"**COUNT**"}++;          
      my $gparse;
      $gparse = $parse;
#     print "<$word><$prob><$gparse>\n"; 

      $LEXGPARSES{$word}{$gparse}+= $prob;

      my $analysis = ParseToTagSequence($gparse);
      $LEXGWORDANALYSISPAIRS{$analysis}{$word}+= $prob;
      $LEXANALYSESCOUNT+= $prob;
      my @parse=split(/\)/,$parse);

      #iterate over the morphemes. 
      #for each morpheme m, full analysis(cartegory) c, and pos-tag p:
      # increment C(c),C(c,m),C(p),C(p,m) 
  
      foreach (@parse) {
        s/\(//go; s/\)//go; 
        if(/\S+/) {
	  /^\s*(\S+)\s+(\S+)\s*$/; 
          my ($tag,$morph)=($1,$2);
          $morph = "NUM" if $morph =~ /\d+/;
          print STDERR "ttt $_ ttt $word $parse\n" unless ($morph);   
          
#          $LEXCATS{$tag}+=$prob;
#          print STDERR "Sublexicon category $tag in word $word, parse $parse\n"
#	      unless ($CATS{$tag});
#          $LEXPAIRS{$tag}{$morph}+=$prob;
#          $tag=RemoveFeaturesFromParse($tag);
           
          $LEXGCATS{$tag}+=$prob;
          $LEXGPAIRS{$tag}{$morph}+=$prob;
          $LEXPAIRCOUNT+=$prob;
       }
      }

    }      
    else { 
      $word = $_; 
      $word =~ s/^\s+//; $word =~ s/\s+$//; 
      #$word =~ s/yy//g;
      $wcnt++; print STDERR "$wcnt " unless ($wcnt % 1000);
    } 
  }
  close(CF);
  print STDERR "\n";
}

sub CreateCombinedProbabilitiesOf {
  my ($catref,$cpairref,$paircount,$lexpairref,$lexpaircount,$combref
#     ,$lambdasref,$limit
      ) = @_;
  my ($cat,$morph,$prob,$count);
  foreach $cat (keys %$catref) {
    my $total_prob = 0;
#print STDERR "\n <$cat> (corpus): ";    
    #iterate over Pcorpus(T,m) for each m
    foreach $morph (keys %{$$cpairref{$cat}}) {
#      $count = $$cpairref{$cat}{$morph}; 
#      $lambda = $limit <= $count ? 0 : $$lambdasref[$count];                        
      $prob =  (1-$lambda) * $$cpairref{$cat}{$morph}/$paircount; 
      $$combref{$cat}{$morph} = $prob;
      $total_prob += $prob;
#print "$morph ";     
    }
#print "\n $cat (sublexicon): ";       

    #iterate over Plexicon(T,m) for each m
    foreach $morph (keys %{$$lexpairref{$cat}}) {
#        $count = defined ($$cpairref{$cat}{$morph}) ? $$cpairref{$cat}{$morph} 
#                  : 0; 
#        $lambda = $limit <= $count ? 0 : $$lambdasref[$count]; 
        $prob = $lambda * $$lexpairref{$cat}{$morph}/$lexpaircount;
        if (exists $$combref{$cat}{$morph}) {
	  $$combref{$cat}{$morph} += $prob;
        }
        else {
	  $$combref{$cat}{$morph} = $prob;
        } 
        $total_prob += $prob;
#print "$morph ";
    }

    #normalize Pcombined(T,m) for each m so they will sum up to Pcorpus(T) 
    foreach $morph (keys %{$$combref{$cat}}) {
      $$combref{$cat}{$morph} *= $$catref{$cat}/($total_prob*$paircount);
    }
  }
}

sub CreateCombinedProbabilities {
my ($analysis, $cat);
#  CreateCombinedProbabilitiesOf(
#    \%CATS,\%PAIRS,$PAIRCOUNT,\%LEXPAIRS,$LEXPAIRCOUNT,\%PROBPAIRS);

  CreateCombinedProbabilitiesOf(
    \%GCATS,\%GPAIRS,$PAIRCOUNT,\%LEXGPAIRS,$LEXPAIRCOUNT,\%PROBGPAIRS); 

   printf STDERR "Analyses in tagged corpus: %d\n",$ANALYSESCOUNT;
   printf STDERR "Analyses in ambiguous corpus: %d\n",$LEXANALYSESCOUNT;  
   CreateCombinedProbabilitiesOf(
    \%GANALYSES,\%GWORDANALYSISPAIRS,$ANALYSESCOUNT,\%LEXGWORDANALYSISPAIRS,
        $LEXANALYSESCOUNT,\%PROBGWORDANALYSISPAIRS
        
#        ,\@ANALYSIS_LAMBDAS,
#        $ANALYSIS_LIMIT
      ); 

#  %PROBCATS = %CATS;
#  foreach $cat (keys %PROBCATS) { 
#    $PROBCATS{$cat} /= $PAIRCOUNT;
#  }

  %PROBGCATS = %GCATS;
  foreach $cat (keys %PROBGCATS) { 
    $PROBGCATS{$cat} /= $PAIRCOUNT;
  }  
  ReversePairs(\%PROBGPAIRS,\%PROBGREVPAIRS);

  %PROBGANALYSES = %GANALYSES;
  foreach $analysis (keys %PROBGANALYSES) { 
    $PROBGANALYSES{$analysis} /= $ANALYSESCOUNT;
  }  

}

sub ReversePairs {

  my ($pairhash,$revpairhash) = @_;
  foreach my $p1 (keys %$pairhash) {
      foreach my $p2 (keys %{$$pairhash{$p1}}) {
	  #$$revpairhash{$p2}{$p1} = $$pairhsh{$p1}{$p2};
	  $$revpairhash{$p2}{$p1} = $$pairhash{$p1}{$p2};	#new by saib!
      }
  }
}


sub GetMorphProbGivenTagOf {
  my ($cat,$morph,$catref,$combref) = @_;
  return 0.0 unless (exists $$combref{$cat}{$morph});
  return $$combref{$cat}{$morph}/$$catref{$cat};
}    


sub GetMorphProbGivenTagWithoutFeatures {
  my ($cat,$morph) = @_;
  return GetTagProbGivenMorphOf($cat,$morph,\%GCATS,\%PROBGCATS); 
} 


sub RetrieveCountCorpus{
	my $lexprobfile = shift @_;
	printf STDERR "BAZINGA - $lexprobfile \n";
	my %hash = %{ retrieve($lexprobfile) };   
	#update in CorpusProbabilities.pm
	%GPARSES = %{ $hash{"GPARSES"} };
	%GANALYSES = %{ $hash{"GANALYSES"} };
	%GWORDANALYSISPAIRS = %{ $hash{"GWORDANALYSISPAIRS"} };
	$ANALYSESCOUNT = $hash{"ANALYSESCOUNT"} ;		#(seems needed only for ambig, but save anyway)
	%GCATS = %{ $hash{"GCATS"} };
	%GPAIRS = %{ $hash{"GPAIRS"} };
	$PAIRCOUNT = $hash{"PAIRCOUNT"};
	%GREVPAIRS = %{ $hash{"GREVPAIRS"} };
	%CATS = %{ $hash{"CATS"} };
	%CATCOUNTS = %{ $hash{"CATCOUNTS"} };
	%PAIRS = %{ $hash{"PAIRS"} };
	%PAIRCOUNTS = %{ $hash{"PAIRCOUNTS"} };
	%GPARSES = %{ $hash{"GPARSES"} };
	#%LEXGPARSES = %{ $hash{"LEXGPARSES"} };
	#%LEXGCATS = %{ $hash{"LEXGCATS"} };
	#if there is sublexicon retrieve all the following values
	if (defined(%{ $hash{"PROBGCATS"} })){	
		%LEXGPAIRS = %{ $hash{"LEXGPAIRS"} };
		%LEXGWORDANALYSISPAIRS = %{ $hash{"LEXGWORDANALYSISPAIRS"} };
		%PROBGPAIRS = %{ $hash{"PROBGPAIRS"} };
		%PROBGREVPAIRS = %{ $hash{"PROBGREVPAIRS"} };
		%PROBGCATS = %{ $hash{"PROBGCATS"} };
		%PROBGANALYSES = %{ $hash{"PROBGANALYSES"} };
		%PROBGWORDANALYSISPAIRS = %{ $hash{"PROBGWORDANALYSISPAIRS"} };
	}
}


#into a file, so to be retrieved in the test phase (corpus.lex.prob)
sub SaveLexicalProb{
	my $outputlexprob = shift @_;
	my %hash = ();
	#open(LP,">$outputlexprob") or die "can't create $outputlexprob: $!";
	$hash{"GPARSES"} = \%GPARSES;
	$hash{"GANALYSES"} = \%GANALYSES;
	$hash{"CATS"} = \%CATS;
	$hash{"PAIRS"} = \%PAIRS;
	$hash{"GCATS"} = \%GCATS;
	$hash{"GPAIRS"} = \%GPAIRS;
	$hash{"GREVPAIRS"} = \%GREVPAIRS;
	$hash{"GWORDANALYSISPAIRS"} = \%GWORDANALYSISPAIRS;
	$hash{"ANALYSESCOUNT"} = $ANALYSESCOUNT;		#(seems needed only for ambig, but save anyway)
	$hash{"PAIRCOUNT"} = $PAIRCOUNT;
	$hash{"CATCOUNTS"} = \%CATCOUNTS;
	$hash{"PAIRCOUNTS"} = \%PAIRCOUNTS;
	$hash{"LEXGPARSES"} = \%LEXGPARSES; 
	$hash{"LEXGCATS"} = \%LEXGCATS; 
	$hash{"LEXGPAIRS"} = \%LEXGPAIRS;
	$hash{"LEXGWORDANALYSISPAIRS"} = \%LEXGWORDANALYSISPAIRS;
	$hash{"PROBGPAIRS"} = \%PROBGPAIRS; 
	$hash{"PROBGREVPAIRS"} = \%PROBGREVPAIRS;
	$hash{"PROBGCATS"} = \%PROBGCATS;
	$hash{"PROBGANALYSES"} = \%PROBGANALYSES;
	$hash{"PROBGWORDANALYSISPAIRS"} = \%PROBGWORDANALYSISPAIRS;
	
	store(\%hash, $outputlexprob);
}

 
1;













































