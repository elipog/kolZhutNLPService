#!/usr/bin/perl 

package MorphTranslation;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(ConvertParsesToMorphSequences 
		 ParseToMorphTagPairs
                 GetAllParses 
                 RemoveRuleNumbers 
		 RemoveFeatures 
                 RemoveFeaturesFromParse
		 RemoveFullFeaturesFromParse
                 RemoveProbabilities   
                 ReadConversionProbabilities 
                 ReadAdditionalProbabilities 
                 Normalize
                 GetGroupOf
                 GroupParse  
                 GroupParses                 
                 ExpandFeatures
                 DontExpandFeatures   
		 DontAddParses
		 AddParses
                 FixFeatures
                 FixParseFeatures
		 ParseToTagSequence
                 Seg
                 Prefixes  
                 MorphCount
                 PrintAnalyses
                 AreWithProbs      
               );
our @EXPORT_OK =qw();
our $VERSION = 1.00;
                    
%ruleProb = ();

%GROUP = ("NNG","NN",
          "NNGT","NNT",
          "AGR","PRP",
          "MOD","RB", 
          "AUX","VB",
	  "COM","IN","REL","IN", 
          "WDT","DT","DTH","DT", 
          "CDT","CD","CDTH","CD","CDH","CD"
        );


$AdditionalProbabilities = 0;                  
$DontExpandFeatures = 0;
$DontAddParses = 0;

sub ParseToMorphTagPairs {
    my $p = $_[0];
    $p =~ s/[\(\)]//g;
    return split(" ",$p);
}
sub AreWithProbs {
  return 1 if $_[1] =~ /^[0-9\.]+/;
  return 0;
}

sub Seg {
  my $p = $_[0];
  $p =~ s/\(\S+( \S+)\)/$1/g;
  $p = join (' ',split(' ',$p));
  return $p;
}

sub Prefixes {
 my @morph;
 my $s;


 $s = $_[0];
 @morphs = split(' ',$s);
 pop @morphs;
 return join(" ",@morphs); 
}

sub MorphCount {
  my @s;
  @s = split(' ',$_[0]);
  return scalar(@s);
}

sub PrintAnalyses {
  print "$_[0]\n";
  my $i;
  for ($i=1;$i<=$#_;$i++) {
    print "\t$_[$i]\n";
  }
}

sub ParseToTagSequence {
  my $parse = $_[0];
  $parse =~ s/\)\s+\(/\)\(/g;
  $parse =~ s/\((\S+)\s+\S+\)/$1 /g;
  $parse =~ s/\s+$//;
  $parse =~ s/^\s+//;
  return "[ " . $parse . " ]"; 
}
sub FixFeatures {
  my $tag = $_[0];
  my $out;
  return "VB-M-BBBBB" if ($tag eq "VB-M");
  if ($tag =~ /-/) {  # has features
    $tag =~ s/([A-Z]+)-([A-Z0-9]+)(-H)?//;
    $out = $1 . "-" . $2 . substr "BBBB",length($2);
    if ($3) { 
      $out .= "H"
    }
    else { 
      $out .= "B";
    }
    if ($tag =~ /-([A-Z0-9]+)/) {
    $out .= "-" . $1 . substr("BBBBB",length($1));
     
    }
 
  } 
  else {
    $out .= $tag . "-BBBBB";
  }  
  return $out;              
}

sub FixParseFeatures {
  my $parse = $_[0];
  my $new_parse = $parse;

  while ($parse =~ s/\((\S+)\s+(\S+)\)//) {
    ($tag,$m) = ($1,$2);
    $fixed =  FixFeatures($tag);
    $new_parse =~ s/\($tag\s+$m\)/\($fixed $m\)/g;
  }   
  return $new_parse;
}

sub AddParses {
  $DontAddParses = 0;
}

sub DontAddParses {
    $DontAddParses = 1;
}

sub ExapndFeatures {
  $DontExpandFeatures = 0;
}

sub DontExpandFeatures {
  $DontExpandFeatures = 1;
}

sub leaf {
  print $_[0];
}

sub GetGroupOf {
  my $tag = $_[0];
  my ($group,$cat,$feat);
  
  $tag =~ /^([A-Z]+)(-[A-Z0-9-]+)?$/;
  $cat=$1;  
  return $tag unless ($group=$GROUP{$cat}); 
  $tag =~ s/^$cat/$group/;
  return $tag; 
}

sub GroupParse {
  my $parse = $_[0];
  my ($tag,$morph,$group,$result);
  $result = "";

  #check if the parse contains probability  
  $result .= $1 if ($parse =~ s/^([0-9\.]+\s)//);
  while ($parse =~ s/\((\S+)\s(\S+)\)//) {
    ($tag,$morph)=($1,$2);
    $group = GetGroupOf($tag); 
    $result .= "(" . $group . " " . $morph . ") ";
  }
  $result =~ s/\s+$//; $result =~ s/^\s+//;
  return $result;
}

sub GroupParses {
  my ($i,$parse,$group,$has_prob,$prob);
  my %parses = ();
  my @results = ();
  $has_prob = 0; 
  $results[0] = $_[0];
  
  for ($i=1;$i<=$#_;$i++) {
    $parse = $_[$i];

    #$parse =~ s/(\([A-Z]+)-([A-Z0-9-]+)(\s)/$1$3/go; #remove features
    if ($parse =~ s/^([0-9\.]*)\s+//) {; #capture and remove parse probability 
                                      # (if any) 
      $has_prob = 1;
      $prob = $1;         
 
      $group = GroupParse($parse); 
      if ($parses{$group}) {
        $parses{$group} += $prob;
      }
      else { 
	  $parses{$group} = $prob;
      }
    }
    else {
       $group = GroupParse($parse);
       $parses{$group} = 1;
   }
  }

  foreach $parse (keys %parses) {
    if ($has_prob) {
      push @results,("$parses{$parse} $parse");
    }
    else {
      push @results,("$parse");
    }
  }  
  return @results;
}

sub expand {
  local $_=$_[0];
  my $m=$_[1];
#  print STDERR "### in expand: m=$m\n";
  my $my_aux;
  my @out=("<0> $_ $m");

  my %KL = ('KWLI','PRP-BY1',
	 'KWLK','PRP-BY2',
	 'KWLW','PRP-ZY3',
	 'KWLH','PRP-NY3',
	 'KWLNW','PRP-BR1',
	 'KWLKM','PRP-ZR2',
	 'KWLKN','PRP-NR2',
	 'KWLM','PRP-ZR3',
	 'KWLN','PRP-NR3');

  my %RWB = ('RWBI','PRP-BY1',
	 'RWBK','PRP-BY2',
	 'RWBW','PRP-ZY3',
	 'RWBH','PRP-NY3',
	 'RWBINW','PRP-BR1',
	 'RWBKM','PRP-ZR2',
	 'RWBKN','PRP-NR2',
	 'RWBM','PRP-ZR3',
	 'RWBN','PRP-NR3');

  if ((/^VB(-...[^C])$/) &&
          (
	   # HIH
           $m =~ /^(HIITI|HIIT|HIH|HITH|HIINW|HIITM|HIW|HIITN)$/ ||
           $m =~ /^(AHIA|THIH|IHIH|THII|NHIH|THIW|IHIW|THIINH)$/ ||
           # HPK
           $m =~ /^(HPKTI|HPKT|HPK|HPKH|HPKNW|HPKTM|HPKW|HPKTN)$/ ||
           $m =~ /^(HWPK|HWPKT|HWPKIM|HWPKWT)$/ ||     
           $m =~ /^(AHPWK|THPWK|IHPWK|THPKI|NHPWK|THPKW|IHPKW|THPWKNH)$/ ||
           # NEFH
           $m =~ /^(NEFITI|NEFIT|NEFH|NEFTH|NEFINW|NEFITM|NEFW|NEFITN)$/ ||
           $m =~ /^(NEFIM|NEFWT)$/ || 
           $m =~ /^(AEFH|TIEFH|IIEFW|TIEFI|NIEFH|TIEFW|IIEFW|TIEFINH)$/  ||
           # MHWHH 
           $m =~ /^(MHWWH|MHWWIM|MHWWT)$/ )) {

    unless ($DontExpandFeatures) {
      if (/^(VB-)(..)A(.)$/) {
        push(@out,"<1a> AUX-${2}1$3 $m","<1b> AUX-${2}2$3 $m",
             "<1c> AUX-${2}3$3 $m") 
      }    
      else {  
        /^VB(-....)$/;
        $my_aux="AUX$1";
        push(@out,"<1d> $my_aux $m");                  
        push(@out,"<1e> ${1}Z$2 $m","<1f> ${1}N$2 $m") if $my_aux =~ /^(AUX-)B(...)$/;
      }
    }
    #don't expand features
    else {
      /^VB(-....)$/;
      $my_aux="AUX$1";
      push(@out,"<1> $my_aux $m");                  
    }
  }
  unless ($DontExpandFeatures) {
    push(@out,"<2a> ${1}Z$3 $m","<2b> ${1}N$3 $m") if /^((VB|AUX)-)B(...)$/;
  
    if (/^((VB|AUX)-..)A(.)$/) {
        push(@out,"<3a> ${1}1$3 $m","<3b> ${1}2$3 $m") if /^((VB|AUX)-..)A(.)$/;
        # replace the original analysis
        $out[0] = "<3c> ${1}3$3 $m"; 
    }
  }
  push(@out,"<5> NNG$1 $m") if /^NN([T-].*)$/;  
  unless ($DontAddParses) {
    push(@out,"<6*> NN$1 $m") if /^CD(.*)$/; 
  } 
  push(@out,"<7> CD-BB $m") if /^CD-BR$/;  
  push(@out,"<8> CD$1-H $m") if /^CD(.*)$/;  
  unless ($DontAddParses) {
    if ($m =~ /^KL|MSPIQ|ITR|FWM|AWTW|AWTH|AWTN|RWB|HRBH|AP|MSPR|MEJ$/) {
      push(@out,"<9> DT$1 $m") if /^CDT(-..)$/ ;
    }
  }
  if (/^(NNP-[ZNB])$/) {
     push(@out,"<10a> $1Y $m","<10b> $1R $m") unless ($DontExpandFeatures);
     $out[0] = "<10c> $1B $m"; 
  };
  push(@out,"<13a> RB $m","<13b> IN $m") if (/^MOD$/ && $m !~ /^AL|BLI|BIN$/);
  push(@out,"<14> MOD $m") if /^RB$/;
  push(@out,"<15> AGR$1 $m") if /^PRP(-..).$/;
  unless ($DontAddParses) {
    push(@out,"<16*> NN$1 $m") if /^JJ((T?)-..)$/;
  }

  push(@out,"<17> JJ$1 $m") if (($m =~ /^(ZH|ZW|ALH|ALW|ZAT)$/) && (/^PRP(-..).$/));
  unless ($DontAddParses) {
    push(@out,"<18*> RBR $m") if ($m =~ /^(PXWT|IWTR)$/);
  }
  unless ($DontAddParses) {
    push(@out,"<19> NN-BB-H $m") if ($m =~ /^HKL$/);
    push(@out,"<20> HAM $m") if ($m =~ /^HAM$/);
    push(@out,"<21*> QW $m") if (($_ !~ /^QW$/) && ($m =~ /^(MH|MI|MTI|AIK|AIPH|KICD|LMH)$/));
    push(@out,"<22*> WDT $m") if (($_ !~/^WDT$/) && ($m =~ /^(KMH|AIZH|AIZW)$/));
  }  
    push(@out,"<24a> VB-ZY3H $m","<24b> RB $m") if ($m =~ /^AIN$/);

  @out=("<0>/<0> IN M) (<25a>/[<25a>,<25b>,<25c>,<25d>] NN-ZY AZ",
                       "<25b>/[<25a>,<25b>,<25c>,<25d>] IN MAZ",
                       "<25c>/[<25a>,<25b>,<25c>,<25d>] MOD MAZ",
                       "<25d>/[<25a>,<25b>,<25c>,<25d>] RB MAZ")
       if ($m =~ /^MAZ$/);
  @out=("<27a> COM $m","<27b> REL $m","<27c> IN $m") if /^COM_REL$/;
  @out=("<28> AT $m") if (/^IN$/ && $m =~ /^AWT$/);
  @out=("<29> POS $m") if (/^IN$/ && $m =~ /^FL$/);
  @out=("<30a> PRP-NY2 AT","<30b> PRP-ZY2 ATH") if ($m =~ /^AT\/H$/);
  if ($m =~ /^O([0-9]+$)/) {
    my $num=$1;
    /^CD(-.*)$/;
    @out=("<31>/[<31>] CDT$1 $num) (<31>/[<31>] NN-ZY O");
  }
#  push @out,("<32a*> NN-BB $m",
#            "<32b*> NN-ZR $m",
#            "<32c*> NN-NY $m",
#            "<32d*> NN-NR $m",
#            "<32e*> NN-BY $m",
#            "<32f*> NN-BR $m")   
#    if /^NNP(.*)$/;
  unless ($DontAddParses) {  
#    push(@out,"<33*> JJ$2 $m") if /^NN(T)?(-.*)$/;
# push(@out,"<33*> JJT$1 $m") if /^NNT(-.*)$/;  
    push(@out,"<34a*> JJ-$1 $m","<34b*> NN-$1 $m") if /^VB-(..).H$/;  
  }
  @out=("<35a> H H","<35b> REL H") if /^H_REL$/;

  @out=() if /^UNKNOWN(_H)?$/; 
  unless ($DontAddParses) {  
    push (@out,
	"<36a> VB-BY1V $m",
	"<36b> VB-ZY2V $m",
	"<36c> VB-NY2V $m",
	"<36d> VB-ZY3V $m",
	"<36e> VB-NY3V $m",
	"<36f> VB-BR1V $m", 
	"<36g> VB-ZR2V $m",
	"<36h> VB-NR2V $m",
	"<36i> VB-BR3V $m",
	"<36j> VB-ZYAH $m",
	"<36k> VB-NYAH $m",
	"<36l> VB-ZRAH $m",
	"<36m> VB-NRAH $m",
	"<36n> VB-BY1T $m",
	"<36o> VB-ZY2T $m",
	"<36p> VB-NY2T $m",
	"<36q> VB-ZY3T $m",
	"<36r> VB-NY3T $m",
	"<36s> VB-BR1T $m",
	"<36t> VB-ZR2T $m",
	"<36u> VB-NR2T $m",
	"<36v> VB-ZR3T $m",
	"<36w> VB-NR3T $m",
	"<36x> VB-ZY2C $m",
	"<36y> VB-ZR2C $m",
	"<36z> VB-NY2C $m",
	"<36A> VB-NR2C $m",
	"<36A> VB-M $m")  
    if /^UNKNOWN$/;
  }
  push (@out,
          "<37a> NN-BB $m",
          "<37b> NN-BY $m",
          "<37c> NN-BR $m",
          "<37d> NN-ZB $m",
          "<37e> NN-ZY $m",
          "<37f> NN-ZR $m",
          "<37g> NN-NB $m",
          "<37h> NN-NY $m",
          "<37i> NN-NR $m")   
     if /^UNKNOWN(_H)?$/;


  push (@out,
          "<38a> NNP-BB $m",
          "<38b> NNP-BY $m",
          "<38c> NNP-BR $m",
          "<38d> NNP-ZB $m",
          "<38e> NNP-ZY $m",
          "<38f> NNP-ZR $m",
          "<38g> NNP-NB $m",
          "<38h> NNP-NY $m",
          "<38i> NNP-NR $m")   
     if /^UNKNOWN$/;
  unless ($DontAddParses) {  
    push (@out,
            "<39a> JJ-BB $m",
            "<39b> JJ-BY $m",
            "<39c> JJ-BR $m",
            "<39d> JJ-ZB $m",
            "<39e> JJ-ZY $m",
            "<39f> JJ-ZR $m",
            "<39g> JJ-NB $m",
            "<39h> JJ-NY $m",
            "<39i> JJ-NR $m")   
       if /^UNKNOWN(_H)?$/;
  }
  push(@out,"<40> DT $m") if $m =~ /^FAR$/;  
  push(@out,"<41> RB-ZY3H $m") if $m =~ /^AINNW$/;
  @out=("<42a> WDT $m","<42b> DT-BR $m") if (/CD/ && ($m eq "KMH"));

  push(@out,"<43> MOD $m") if /^PRP-...$/ && 
      $m =~/^ECMW|ECMH|ECMM|ECMN|ECMI|ECMK|ECMNW|ECMKM|ECMKN$/;
  push(@out,"<44a> RB $m","<44b> MOD $m") if $m eq "EWD" && /^IN$/;
  push(@out,"<45> RB $m") if $m eq "AL" && /^MOD$/;
  push(@out,"<46a> RB $m","<46b> MOD $m") if $m eq "KN" && /^PRP-BY3$/;
  my $kl;
  if (defined( $kl = $KL{$m}) && /^CD-/) {
      push(@out,"<47> ${kl} $m");
  }; 
  push(@out,"<48> IN $m") if $m =~ /^MBLI$/ && /^MOD$/;
  push(@out,"<49> RB $m") if $m =~ /^SMWK$/ && /^IN$/;
  push(@out,"<50> RB $m") if $m =~ /^BLI$/ && /^MOD$/;
  push(@out,"<51> IN $m") if $m =~ /^KEBWR$/ && /^MOD$/;
  push(@out,"<52> MOD $m") if $m =~ /^ALA$/ && /^CC$/;
  push(@out,"<53> MOD $m") if $m =~ /^BIWTR|MAD|FLA|HPEM$/ && /^RB$/;
  push(@out,"<54> RB $m") if $m =~ /^QRI$/ && /^MOD$/;
  push(@out,"<55a> COM $m","<55b> IN $m") if (/^CC$/ && ($m eq "KI"));
  push(@out,"<56a> MOD $m","<56b> IN $m","<56c> COM $m","<56d> HAM $m") 
      if $m =~ /^AM$/ && /^CC$/;
  @out = ("<57a> IN $m","<57b> REL $m") if $m eq "AFR" && /^CC$/;  
  @out = ("<58> IN $m") if $m =~ /^KAFR|MAFR|TMWRT$/ && /^CC$/; 
  @out = ("<59a> REL $m","<59b> COM $m") if $m eq "F" && /^CC$/;
  @out = ("<60a> H $m","<60b> REL $m","<60c> COM $m") if $m eq "H" && /^CC$/;
  push(@out,"<61a> IN $m","<61b> QW $m") if $m =~ /^FMA$/ && /^CC$/;
  push(@out,"<62a> IN $m","<62b> RB $m") if $m =~ /^LKN$/ && /^CC$/;
  my $rwb;
  if (defined( $rwb = $RWB{$m}) && /^CD-/) {
      push(@out,"<63> ${rwb} $m");
  }; 

  return @out;

}

sub do_expand {

  my ($m1,@more)=@_;
#  print STDERR "### in do_expand; before m= $m1\n";
  $m1 =~ s/\(//go; 
  $m1 =~ s/\)//go; #removing all ( and )'s
#  print STDERR "### in do_expand; after1 m= $m1\n";
  $m1 =~ s/^\s*(.*?)\s*$/$1/; #removing leading and trailing white spaces
#  print STDERR "### in do_expand; after2 m= $m1\n";
  my ($postag,$morpheme)=split(/ /,$m1);

  my @out;
  if (@more) {
    @morex=do_expand (@more);
  } else {
    @morex=("");
  }
  my @expansion=expand($postag,$morpheme);

  my $out_morph;
  my @out_morphs;
  my $set = "[";
  my $i;
  
  foreach $out_morph (@expansion) {
    next if $out_morph =~ /\[/;
    #ignore rules that contain '*'
    $set .= $& if ($out_morph =~ /<[^\*]*>/);        
;  
  } 

  $set .= "]";
  if ($set ne "[]") {
    for($i=0;$i<=$#expansion;$i++) {
      #ignore rules that contain '*'
      $expansion[$i] =~ s/(<[^\*]*>)/$1\/$set/;             
    }
  }   
 
  foreach $expt (@expansion) {
    foreach $mx (@morex) {
      push(@out,"($expt) $mx");
    }
  }
  return (@out);
}
 
sub parse {
    my $word = shift(@_);
    my $mean = shift(@_);
    my ($origword,$origmean) = ($word,$mean);
    my %wdt = ('J','$','K','K$','L','LK$','H','H','S','$');
    my %wdtx = ('J','$','K','K$','L','LK$','H','H','S','$H'); #' )
    my %in = ('b','B','k','K','l','L','m','M');
    my %cat = ('E','NN','P','VB','p','NNP','z','VB','T','JJ','t','RB','M','CD','m','MOD','x','CC','y','IN','j','QW','g','PRP','U','UNKNOWN');
    my %words = (',','(yyCM yyCM) ',
                 '.',"(yyDOT yyDOT) ",
                 '?',"(yyQM yyQM) ",
                 '!',"(yyEXCL yyEXCL) ",
                 '(','(yyLRB yyLRB) ',')','(yyRRB yyRRB) ',
                 '"','(yyQUOT yyQUOT) ',':','(yyCLN yyCLN) ',
                 '-','(yyDASH yyDASH) ','...','(yyELPS yyELPS) ',
                 ';','(yySCLN yySCLN) ');
    my %special_words = ('LBLTI','(IN L)(MOD BLTI)',
                         'MKAN','(IN M)(RB KAN)',
                         'LKAN','(IN L)(RB KAN)');

    my %wordcat = ('$L','POS');
    my %prp = ('ZY1','ANI','ZY2','ATH','ZY3','HWA',
	       'ZR1','ANXNW','ZR2','ATM','ZR3','HM',
	       'NY1','ANI','NY2','AT','NY3','HIA',
	       'NR1','ANXNW','NR2','ATN','NR3','HN',
	       'BY1','ANI','BR1','ANXNW','BY2','AT/H');
    my %possr = ('ZY1','I','ZY2','K','ZY3','W',
		 'ZR1','NW','ZR2','KM','ZR3','HM',
		 'NY1','I','NY2','K','NY3','H',
		 'NR1','NW','NR2','KN','NR3','HN',
		 'BY1','I','BR1','NW','BY2','K');
    my %possy = ('ZY1','I','ZY2','K','ZY3','W',
		 'ZR1','NW','ZR2','KM','ZR3','M',
		 'NY1','I','NY2','K','NY3','H',
		 'NR1','NW','NR2','KN','NR3','N',
		 'BY1','I','BR1','NW','BY2','K');

    if ($words{$word}) {
        if ($word =~ /^[\.\?]$/) {
           $scnt++;
        }
	return $words{$word};
    }
    if ($special_words{$word}) {
      return $special_words{$word};
    }

    $root = $mean;
    $root =~ s/[1*].*$//;
    @root = split(//,$root);
    $mean =~ s/^[^1\*]+//;
    @data = split(//,$mean);
    @word = split(//,$word);
    $type = $data[1];
    $cat = $cat{$type};
    my $out="";

    if ($data[0] eq "1") {
	$out .= "(CC ";
	$out .= "W"; 
	$out .= ") ";
#	while (@poss) {
#		(pop(@poss) eq pop(@word)) or print STDERR "POSS Error $word $mean\n"; 
#	    }

	(shift(@word) eq "W") or die "word:$origword;analysis:$origmean --- W Error\n";
    }

    if ($wdt{$data[2]}) {
        if ($data[2] eq "S" && $word[0] eq 'K' && $word[1] eq '$') {
          $data[2]='K';
          print STDERR "Erel's S=>K error ($scnt).\n";
        }
        $out .= "(COM_REL ";
	$out .= $wdt{$data[2]};
        $out .= ") ";
        if ($data[2] eq "S") {

            $out .= "(H H) ";
        }
	@wdtx = split(//,$wdtx{$data[2]});
	while (@wdtx) {
	    ((shift @word) eq (shift @wdtx)) or die "word:$origword;analysis:$origmean --- WDT Error\n";
	}
    }

    $word=join('',@word);
    if ($wordcat{$word}) {
	$out .= "(".$wordcat{$word}." $word) ";
	return $out;
    }
    my $ot_yahas = "";
    if ($type =~ /[EMTUpg]/) {
	if ($in{$data[3]}) {
          $out .= "(IN ";
          $out .= $in{$data[3]};
          $ot_yahas = $in{$data[3]};
          $out .= ") ";
	  ((shift @word) eq ($in{$data[3]})) or die "word:$origword;analysis:$origmean --- IN Error\n";
	}
	shift @data;
    }

    if ($type =~ /[ETMg]/) {
	if ($data[3] eq 'K') {
            $out.= "(H H) ";
	    shift(@word) unless ($ot_yahas =~ /[BKL]/);
#	    ($w1 eq "H") or unshift(@word,$w1);
	}
	shift @data;
    }
    
    my $word1 = join('',@word);
    $cat = "AT" if ($word1 eq "AT" && $cat eq "IN"); 
    if ($type eq 'U') {
#      print "---> $root $word1\n";
      if ($word1 eq ("H" . $root)) {
        $cat = "UNKNOWN_H";
        $out.= "(H H) ";
        shift @word;
      }            
    }
    if ($type =~ /[EpPzTMyg]/) {
	shift @data;
	shift @data;
	if ($data[1] ne "*") {
	    $acc = "-" . $data[1];
	    if ($type =~ /[EPzTMyg]/) {
		if ($data[2] eq '*') {
		  $acc .= 'R';
		} else {
		  $acc .= $data[2];
		}
	    }
	} else {
	    if ($type =~ /[EpPzTMg]/) {
		$acc = "-";
	    } else {
		$acc = "";
	    }
	}
    } else {
	$acc = "";
    }

    if ($type =~ /[ETM]/) {
	if ($data[3] eq "S") {
	    $cat .= "T";
	}
	shift @data;
    }

    if ($type =~ /[Pzgy]/) {
	if ($data[3] ne "*") {
	    $acc .= $data[3];
	}
	shift @data;
    }

    if ($type =~ /[Pz]/) {
	$acc .= ($data[3] eq "S" ? "H" : $data[3]);
	shift @data;
    }

    $prp = "";
    if (($type =~ /[y]/) && ($acc)) {
      unless ($root eq "AIN") {
	$acc = substr($acc,1);
	$prp = $prp{$acc};
	@prp = split(//,$possr{$acc});
	while (@prp) {
            $ltr=pop(@word);
	    if (pop(@prp) ne $ltr) {
#               print STDERR "IN PRP debug $word $mean\n"; 
               push(@word,$ltr);
               if (@prp) {
                  die "word:$origword;analysis:$origmean --- IN PRP Error $word $mean\n";
               }
            }
	}
	$prpacc=$acc;
	$acc="";
      } else {
	$acc.="H";
	$cat="RB";
      }
    }

    $poss = "";
    if ($type =~ /[E]/) {
	if ($data[3] ne "*") {
	    shift @data;
	    shift @data;
	    shift @data;
#	    print "(H ";
#           leaf "H";
#           print ") ";
	    $poss = '-H-'.join('',@data);
#	    if ($acc =~ /[R]/) {
#		@poss = split('',"I" . $possr{$poss});
#		while (@poss) {
#		    (pop(@poss) eq pop(@word)) or print STDERR "POSS Error $word $mean\n"; 
#		}
#		$cword=join('',@word);
#		if ((substr($cword,-2) ne "WT") || ($root eq ($cword)))  {
#		    push (@word,"I");
#		    push (@word,"M");
#		}
#		print STDERR "$word $mean $root @word\n";
#	    } else {
#		@word = split('',$root);
#	    }
#	    
	}
    }

    $out .= "(".$cat.$acc.$poss." ";
    $out .= join('',@word);
    $out .= ") ";

#    if ($poss) {
#	print "(IN ";
#        leaf "\$L",1;
#        print ") (PRP ";
#        leaf $prp{$poss},1;
#        print ") ";
#    }

    if ($prp) {
	$out .= "(PRP-$prpacc $prp) ";
    }

    if ($type eq "T" && $out =~ /\(H H\) \(JJ/) {
      $out =~ s/\(H H\)/\(H_REL H\)/;  
    } 

    return $out;

}

sub RemoveRuleNumbers {
  my $i;
  my @parses = @_;
  for($i=0;$i<=$#parses;$i++) {
      $parses[$i] =~ s/\<.+?(\]|(\*>))\s//go;
  }
  return @parses;
}
 
sub ConvertParsesToMorphSequences {
  my %segmentations = ();
  my $prob=0;
  my @result;
  my $word;

  my @parses = RemoveRuleNumbers(@_);
  $word = shift @parses;

  foreach $parse (@parses) {
    next if $parse =~ /\*\*COUNT/;
    $parse =~ s/\((\S+?)\s(\S+?)\)/$2/go; #remove POStags
    $parse =~ s/^([0-9\.]*)//; #capture and remove parse probability (if any) 
    $prob=$1;
    $parse =~ s/^\s//;
    if ($prob) { #probabilities are provided
      unless ($segmentations{$parse}) {
        $segmentations{$parse}=$prob;
      }
      else { 
        $segmentations{$parse}+=$prob;
      }  
    }
    else {
        $segmentations{$parse}=1;
    }      
  }
  unless ($prob) { 
    @result =  keys %segmentations;
  }
  else {
    @result = ();   
    foreach $key (keys %segmentations) {
      push @result, ("$segmentations{$key} $key"); 
    }
  } 
  unshift @result, $word;
  return @result;

}

sub RemoveFullFeaturesFromParse {
  #remove all features except
  #M in VB-M
  #H in NN-...-H(-...)
  my $parse = $_[0];
  $parse =~ s/(NN(G)?)-....H/$1-H/g;
  $parse =~ s/-[ZNBA][A-Z0-9-]*//g;
  return $parse; 
}

sub RemoveFeaturesFromParse {
  #remove all features except
  #M in VB-M
  #H in NN-...-H(-...)
  my $parse = $_[0];
  $parse =~ s/(NN(G)?)-[A-Z0-9]+-H(-([A-Z0-9]+))/$1-H/g;
  $parse =~ s/-[ZNBA][A-Z0-9-]*//g;
  return $parse; 
}

sub RemoveFeatures {
  my %parsesWoFeatures = ();
  my $prob=0;
  my @result;
  my $word;
  my @parses = RemoveRuleNumbers(@_);
  $word = shift @parses;

  foreach $parse (@parses) {
#    print "parse before $parse\n";
    $parse = RemoveFeaturesFromParse($parse);
 
    $parse =~ s/^([0-9\.]*)//; #capture and remove parse probability (if any) 
    $prob=$1;
    $parse =~ s/^\s//;
#    print "parse after $parse\n";
    if ($prob) { #probabilities are provided
      unless ($parsesWoFeatures{$parse}) {
        $parsesWoFeatures{$parse}=$prob;
      }
      else { 
        $parsesWoFeatures{$parse}+=$prob;
      }  
    }
    else {
        $parsesWoFeatures{$parse}=1;
    }      
  }
  unless ($prob) { 
    @result = keys %parsesWoFeatures;
  }
  else {
    @result = ();   
    foreach $key (keys %parsesWoFeatures) {
      push @result, ("$parsesWoFeatures{$key} $key"); 
    }
  }
  unshift @result, $word;
  return @result; 
  
}

sub RemoveProbabilities {
  my @result = @_;
  my $i;

  for ($i=1;$i<scalar(@result);$i++) {
    $result[$i] =~ s/^([0-9\.]* )//; 
  }
  return @result;   
}

sub GetAllParses {

  my $word= shift @_; 
  my ($p, $result,$item, $anaylsis, $anal_prob,$rel_prob,$prob, $parses, 
     $parses2, $prob_string,$with_probs);
  $anal_prob = 0;
  $prob =1;
  $with_probs = 0;
  %parses = ();
  @parses2 = ();
  while ($item = shift (@_)) {
    if ($item =~ /^[0-9]+$/) { # the analyses are provided with probabilities 
       $anal_prob = $item;
       $with_probs = 1;  
       $analysis = shift (@_);
    }
    else {
	$analysis = $item;
    }
    if ($word =~ /^\)$/) {
      %parses=('(<0>/[<0>] yyRRB yyRRB)',1);
  }
    else {
      $p=parse ($word, $analysis);
      $p =~ tr/\@\$\&\%\"/JFEOU/;
      $p =~ s/^\s*(.*?)\s*$/$1/;
      
      # translate 'U' at the beginning of a morpheme to (yyQUOT yyQUOT)
      $p =~ s/(\(\S+? )U(\S+?\))/(yyQUOT yyQUOT) $1$2/;
      @morph=split(/\)/,$p);
      foreach $ex (do_expand(@morph)) {
        $ex =~ s/^\s*(.*?)\s*$/$1/;

        # the parse is a sub-analysis of the orginial analysis 
        if ($ex !~ /\*>/) { 
          if ($with_probs) {
	    $prob=$anal_prob*GetRelativeProb($ex)/1000;
            unless($parses{$ex}) {
              $parses{$ex}=$prob;
            }
  	    else {
	      $parses{$ex}+=$prob;
            }  
          }
          else {
            $parses{$ex}=$prob;
          }
        }
        # the parse is an additional analysis 
        else { 
           push @parses2,($ex); 
	}
             
      }      
    }
  }

  $word =~ tr/\@\$\&\%\"/JFEOU/;
 
  # generate additional parses 
 # push @parses2,("(<101a*> NNP-ZY $word)",
 #                "(<101b*> NNP-NY $word)",
 #                "(<101c*> NNP-ZB $word)",
 #                "(<101d*> NNP-NB $word)",
 #                "(<101e*> NNP-BB $word)",
 #                "(<101f*> NNP-BY $word)");
  # probabilities are given, and probabilities of additional parses exist
  # OR probabilities are not given




    if ((!$with_probs) || $AdditionalProbabilities) {     
    # add additional parses if not already in parses set 
    my $p2;
    my %rulecount = ();
    my @parses_list = keys %parses;
    foreach $p2 (@parses2) {
      unless (IsInParses($p2,@parses_list)) {
        $p2 =~ s/(<[^\)]+?\*>)/$1\/\[$1\]/g;
        $rulecount{$1}++;
        $parses{$p2}="1.0";
        push @parses_list, ($p2);  
      }
    }
    #if probabilities are provided, redistribute them.
    if ($with_probs) {
      AdjustForAdditonalRules(\%parses,\%rulecount);
    }
  } 

 
  unless ($with_probs) {  
    @result = keys %parses;
  } 
  else { # probabilities are provided
      
      @result = ();   
      foreach $key (keys %parses) {
        if ($parses{$key}>0.0) {
	  $prob_string = sprintf "%f %s",$parses{$key},$key;
          push @result, $prob_string;
        }
      }
  }
  unshift @result, ($word);
  Normalize(\@result) if ($with_probs);
  return @result;
}

sub AdjustForAdditonalRules {
 my ($parsesref,$rulecountref) = @_;
 my (@parses,$parse,$set,$rule,%starredRules,$r_prob);
 @parses = keys %$parsesref;

 # create a set of all the starred rules (additional analyses) + <0> (the default analyses) 
 %starredRules = ();
 foreach $parse (@parses) {
  if ($parse =~ /(<[^\)]+?\*>)\//) {; 
    $starredRules{$1} = 1;
  } 
 }
 $set = "[<0>" . join("",sort keys %starredRules) . "]";
 foreach $parse (@parses) {
   
   #statistics are available for this set of rules 
   if($ruleProb{$set}) { 

     # the analysis is an additional one
       if ($parse =~ /(<[^\)]+?\*>)\//) {
       $rule = $1;   
       $$parsesref{$parse} /= $$rulecountref{$1};
     }
     # the analysis in not an additional one 
     else {
       $rule = "<0>";
     }             

     #P(rule,set) exists.
     if(defined($ruleProb{$set}{$rule})){ 
        $r_prob = $ruleProb{$set}{$rule};
#        print "$rule/$set prob= $r_prob\n";
    } 
     #if not, P(rule,set) = 0;
     else {
        $r_prob = 0;
     }

     #update probability
     $$parsesref{$parse} *=$r_prob;  
   }        
   else { 
      #no probabilities for this set - give zero probability for additional analyses 
#       print "rule for set $set does not exist!\n";
      # the analysis is an additional one
       if ($parse =~ /(<[^\)]+?\*>)\//) {
         $$parsesref{$parse} = 0;  
     }             
  }
 }
  
}

sub GetRelativeProb {
    my $parse = shift;
    my $rule;
    my $prob;   
    my $set;
    my @set;
#   print "*** $parse\n";      
    my $r_prob = 1;
    while ($parse =~ s/(<\w+?>)\/(\[(.+?)\])//) {
      $rule = $1; 
      $set = $2;
      next if $set =~ /\*/; # additional rules are ignored here
      if (%ruleProb) { 
        if($ruleProb{$set}) {
          if($ruleProb{$set}{$rule}){ 

    	    $r_prob *= $ruleProb{$set}{$rule};
          } 
          else {
	    $r_prob = 0;
          }  
        }        
        else { 
	 @set = split("><",$set);
 	 $r_prob /= scalar (@set);
        }
     }
     else { 
	@set = split("><",$set);
	$r_prob /= scalar (@set);
     }
   } 
return $r_prob;   

}

sub ReadConversionProbabilities {
  print STDERR "Reading conversion rules probabilities...\n";
  my $filename = shift;
  my ($line,$rule,$set, @field);
  open(FH,"<" . $filename) or die "Can't open $filename\n";
  while($line=<FH>) {
    @field = split (" ",$line);
    ($rule,$set) = split("/",$field[0]);
     if ($set !~ /\*/) {
#        print "$field[0] $rule $set $field[2]\n";
         $ruleProb{$set}{$rule}=$field[2]
     };     
  }    
#    print join(" ",keys %ruleProb);print "\n";
}

sub ReadAdditionalProbabilities {
  print STDERR "Reading additional probabilities...\n";
  my $filename = shift;
  my ($line,$rule,$set, @field);
  open(FH,"<" . $filename) or die "Can't open $filename\n";
  while($line=<FH>) {
    @field = split (" ",$line);
    ($rule,$set) = split("/",$field[0]);
    if ($set =~ /\*/) {
#      print "$field[0] $rule $set $field[2]\n";
      $ruleProb{$set}{$rule}=$field[2] ;     
    }
  }    
#    print join(" ",keys %ruleProb);print "\n";
  $AdditionalProbabilities = 1;
}

sub IsInParses{
  my ($ex,@parses) = @_;
  my ($i);
  $ex =~  s/\<[^\)]+(\]|(\*>))\s//go;
  my $p1;
  foreach $p1 (@parses) {
    $p1 =~ s/\<[^\)]+(\]|(\*>))\s//go;
#    print STDERR "---> [$p1] [$ex]\n";
    return 1 if ($ex eq $p1); 
  }
  return 0;
}

# Normalize probabilities
# We assume that the first element is the word
sub Normalize{
  my ($parsesref) = @_;
  my $prob_sum = 0;
  my @line_array;

  #accumulate the total probability mass
  for ($i=1;$i<=$#$parsesref;$i++) {
    @line_array = split(" ",$$parsesref[$i]);
    $prob_sum += $line_array[0]; 
#    print STDERR "XXX $prob_sum [$$parsesref[$i]]\n";
  }  
  
#  print STDERR "total_prob=$prob_sum\n";
  #normalize the probabilities
  for ($i=1;$i<=$#$parsesref;$i++) {
    $$parsesref[$i] =~ /^\s*(\S+)\s/;
    $$parsesref[$i] = sprintf"%f %s",$1/$prob_sum,$';
  }  
  
}

1;













































