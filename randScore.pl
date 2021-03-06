#!/usr/bin/perl
#
#   Picker for nonoverlaped sets of terms, based on random search
#
#  Script analyzes term file and score file and generated text file, which contains groups of
#  terms, with similarity score less than given. It is possible that similar terms are found
#  in different gorups.
#
#   Use
#
#   ./randomScore.pl --help
#
#   to get list of optons
#
#   Author: Vladimir Vodolaxkiy, <vloldearus@gmail.com>
#

use strict;
use warnings;

use List::MoreUtils qw(first_index);
use Getopt::Long;
use Data::Dumper;

# As max score can be 10000 (for example) we need to setup threshold as percent
# of maximium value
my $MaxScore         =   10000;
my $SetAmount        =   100;        # Amount of groups/sets
my $SetCapacity      =   20;         # Amount of low correlated terms in the set
my $retryCounter     =   1500;       # amount of false retries
my $scoreThreshold   =   0.05;       # maximum similarity for two terms


my $workDir     =   "./work_dir";
my $srcDir      =   "./source_files";


my $termFile    =   $srcDir."/kid-friendly-sets.txt";
my $scoreFile   =   $srcDir."/Human-and-Machine-and-Manual.txt7";
# Debug set
# my $scoreFile   =   $srcDir."/test1.txt";

my $verbose = 0;

my $outputFile = $workDir."/resultSet.txt";

##############################################

my $this_program = 'randScore.pl';
my $this_version = '1.0';

my $version_info = <<EOT;
GNU $this_program $this_version

Copyright (C) 2021 Geomatix Laboratory, s.r.o. All Rights Reserved

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Written by Vladimir Vodolazkiy <vloldemarus\@gmail.com>

EOT

my $help_info = <<EOT;

`$this_program' generates sets of nonoverlapping terms
with similiraty score less then threshold.

Usage: $this_program [OPTION]... -f <terms file> -s <score file>

-f, --file='FILE'          process data from 'terms file'    (STDIN)
-s, --score='FILE'         use score file as reference data (file in txt7 format)
-o, --output='FILE'        set name of the output file to 'FILE' ($outputFile)
-v, --verbose              print out progress to STDOUT
-t, --threshold='FLOAT'    set up score threshold in range 0..1 ($scoreThreshold)
-r, --retry='INT'          set up retry counter ($retryCounter)
-S, --sets='INT'           amount of sets to be generated ($SetAmount)
-c, --capacity='INT'       amount of records in each set ($SetCapacity)

--help                     print this help, then exit
--version                  print version number, then exit

Report bugs and send comments to <vloldemarus\@gmail.com>.
EOT

my %opt_def = (
               'f|file=s'      => \$termFile,
               'o|output=s'    => \$outputFile,
               's|score=s'     => \$scoreFile,
               'v|verbose'     => \$verbose,
               't|threshold=f' => \$scoreThreshold,
               'r|retry=i'     => \$retryCounter,
               'S|sets=i'      => \$SetAmount,
               'c|capacity=i'  => \$SetCapacity,
               );

# Parse options.
Getopt::Long::config('bundling');
GetOptions (%opt_def,
            help    => sub { print $help_info; exit },
            version => sub { print $version_info; exit },
            ) or die $help_info;

##############################################

$scoreThreshold = $scoreThreshold * $MaxScore;

open (my $ofh,'>:encoding(UTF-8)', $outputFile) or die "Could not open file '$outputFile' $!";

# Used in test run only
#my @themeList = qw(attention policeman risk boiler  posture
#    generator trolley giraffe whistle radiator);

my $termIndex   =   $workDir."/termIndex";


# Step 1. Create list of terms

open(my $fh, '<:encoding(UTF-8)', $termFile) or die "Could not open file '$termFile' $!";


my @termArray;
my %terms;
my %invTerms;
my $lineCounter = 0;        # to look into kids file in a natural way
my $termCounter = 0;
while (my $row = <$fh>) {
    chomp $row;
    $termArray[$lineCounter] = $row;
    my ($term,$syns) = $row =~ /^@\s(.*)\s=(.*)$/;
    # unify term representation
    $term  = lc $term;
    # Uncomment next two lines to limit search for a test set
#    my $found = first_index { $_ eq $term } @themeList;
#    if ($found == -1) { next; }
    if (!$terms{$term}) {
        # no such term was used before
        # Check for our shortList
        $terms{$term} = $lineCounter;
        $invTerms{$lineCounter} = $term;
        $termCounter++;
    }
    my @sarr = split /\s.\s/,$syns;
    foreach (@sarr) {
        my ($sentry) = $_ =~ /^[<\s]*([A-Za-z\d\-\s\'\.]*)[\>\s]?$/i;
        if ($sentry) {
            $sentry = lc $sentry;
            if (!$terms{$sentry}) {
                $terms{$sentry} = $lineCounter;
                $termCounter++;
            }
        } else {
            print "Cannot parse - >".$_."<\n";
        }
    }
    $lineCounter++;

#    if ($lineCounter >= 10) {
#        print Dumper(\%invTerms);
#        last;
#    }
}
my $uniqueTermsCounter = $lineCounter;
if ($verbose == 1) {
    print "*** Amount of unique terms - $uniqueTermsCounter\n";
    print "*** Total amount of terms (incl. synonyms) - $termCounter\n";
}

#
#   Now we should save this hash array into inddex file
#   for later usage
#
#open(my $fw, '>:encoding(UTF-8)', $termIndex) or die "Could not open file '$termIndex' $!";
#
#foreach my $key (keys %terms) {
#    my $value = $terms{$key};
#    print $fw "$key,$value\n";
#}
#close $fw;
#
#if ($verbose == 1) {
#    print "*** Term index saved in working directory\n";
#}

#
#   Step 2. Parsing main Score file
#

open ($fh,'<:encoding(UTF-8)', $scoreFile) or die "Could not open file '$termFile' $!";

my $cntDirect = 0;
my $cntAssoc = 0;
my $totalCnt = 0;

my %scores;

while (my $row = <$fh>) {
    chomp $row;
    my $fc = my @fields = split /\;/,$row;
    # print Dumper(\@fields);
    my $termName = "";
    my $headerName = "";        # root term name
    my %scoreList;              # scoreLists for particular parameters
    for (my $i = 0; $i < $fc; $i++) {
        my ($header, $content) = $fields[$i] =~ /^(.*):(.*)$/;
        if (!$header || !$content) {
            next;
        }
        # parse header
        (my $tmp) = $header =~ /^\#(.*)\[/;
        if ($tmp) {
            $termName = $tmp;
            if (length($termName) < 3) {
                # exclude articles etc.
                next;
            }
        }
        my $tac = my @tmpArray  = split /\|/,$content;
         # content is a list separated by |
        (my $headerNameTmp) = $header =~ /\[(.*)\=\d/;
        if ($headerNameTmp) {
            $headerName = $headerNameTmp;
            # this content has list of terms
            @tmpArray  = split /\|/,$content;
            $scoreList{$headerName} = \@tmpArray;
         } else {
            # look for scores
            ($headerNameTmp) = $header =~ /\[(.*)\-score]/;
            if ($headerNameTmp) {
                if (ref($scoreList{$headerName}) ne 'ARRAY') { next; }
                my $tac = my @ta = @{$scoreList{$headerName}};
                @tmpArray  = split /\|/,$content;
                my %tScore;
                for (my $j = 0; $j < $tac; $j++) {
                    my $tName = lc $ta[$j];
                    my $tSc = $tmpArray[$j];
                   $tScore{$tName} = $tSc;
                }
                $scoreList{$headerName} = \%tScore;
            }
        }
    }
    # Now we should integrate all particular socres pairs to
    # single hash
    my %scoresLocal;
    foreach my $key (keys %scoreList) {
        my %partScore = %{$scoreList{$key}};
        %scoresLocal = (%scoresLocal, %partScore);
    }
    $scores{$termName} = \%scoresLocal;
    $totalCnt++;
    if ($verbose == 1) {
        print "Thesaurus records parsed: $totalCnt\r";
    }
}
close $fh;

my $tCounter = @termArray;
my @justUsedTerms = ();
my $tryCounter = 0;
my $setCounter = 0;


while ($setCounter < $SetAmount && $tryCounter < $retryCounter) {
    # reset array of rejected terms
    my @rejectedTerms = ();
    my $freshPicked = -1;
    my $setCount = 0;
    my %pickedTerms;
    while ($setCount < $SetCapacity && $tryCounter < $retryCounter) {
        $freshPicked = -1;
        my $rCounter = 0;
        while ($freshPicked < 0 && ($rCounter < $retryCounter * ($setCount + 1))) {
            my $picker = int(rand($tCounter));
            if ($pickedTerms{$picker}) {
                $rCounter++;
                next;
            } else {
                my $used = first_index { $_ eq $picker} @justUsedTerms;
                if ($used >= 0) {
                    $rCounter++;
                    $freshPicked = -1;
                } else {
                    my $justRejected = first_index { $_ eq $picker} @rejectedTerms;
                    if ($justRejected >= 0) {
                        $rCounter++;
                        $freshPicked = -1;
                    } else {
                        $freshPicked = $picker;
                        $rCounter = 0;
                    }
                }
             }
        }
        if ($setCount == 0) {
            # create scores entries for this element
            my @leftList;
            # get list of synonyms for left part
            my $val = $invTerms{$freshPicked};
            if (!$val) { next; }
            #        print ">>>>  $freshPicked ->  $val <<<<< \n";
            my $lScoreRec = $scores{$val};
            if (!$lScoreRec) {
                $rCounter++;
                next;
            }
            my %lh = %{$lScoreRec};
            foreach my $key  (keys %terms) {
                # key - term
                my $value = $terms{$key};
                # value - cluster (basic term) it belongs to
                if ($value eq $freshPicked) {
                    my $addScoreRec = $scores{$key};
                    if ($addScoreRec) {
                        # append list of scores to description
                        my %rh = %{$addScoreRec};
                        %lh = (%lh, %rh);
                    }
                }
            }
            # add first entry to output list of terms, will be used later
            $pickedTerms{$freshPicked} = \%lh;
            $setCount++;
            if ($verbose == 1) {
                print "Picked term - ".$val." as kernel of new set\n";
            }
            $tryCounter = 0;
        } else {
            # This is a new term, need to estimate score in compare with
            # all previously picked terms
            my $value = $invTerms{$freshPicked};
            if (!$value) {
                $tryCounter++;
                next;
            }  # Sanity check. not found in term list
            # get list of all terms, picked so far
            my @currentPicked = keys %pickedTerms;
            my $justPresent = first_index { $_ eq $value} @currentPicked;
            if ($justPresent >= 0) {
                $tryCounter++;
                next;
            }  # this entry was picked before
            # Now we are sure, that new term is not included into %pickedTerms
            # Create structure for new term
            my @leftList;
            # get list of synonyms for left part
            my $lScoreRec = $scores{$value};
            if (!$lScoreRec) {
                # no description for this term found in scores
                $tryCounter++;
                next;
            }
            my %lh = %{$lScoreRec};
            foreach my $key (keys %terms) {
                my $value = $terms{$key};
                #           print "$freshPicked / $value  \n";
                if ($value eq $freshPicked) {
                    my $addScoreRec = $scores{$key};
                    if ($addScoreRec) {
                        my %rh = %{$addScoreRec};
                        %lh = (%lh, %rh);
                    }
                }
            }
            # now @leftList contains all score hashes rlevant to it and synonyms
            if ($verbose == 1) {
                print "New pretendent to picked terms : $value\n";
            }
            my $llCount = my @llKeys = keys %lh;
            my $sumScore = 0;
            # now we'll loop through all entries, picked before
            foreach  my $key (keys %pickedTerms) {
                my $value = $pickedTerms{$key};
                my $rightTerm = $invTerms{$key};
                if ($verbose == 1) {
                    print "checking against ".$invTerms{$key}." ($key) \n";
                }
                my $directScore = $lh{$rightTerm};
                if ($directScore) {
                    #
                    # We have direct score precalculated. No need to waste time
                    # for additional checks, just pick up final score
                    #
                    if ($verbose == 1) {
                        print "Direct score = $directScore\n";
                    }
                    $sumScore = $directScore;
                    last;
                } else {
                    #
                    # We should compare hashes in left nd right parts
                    #
                    my %rh = %{$value};
                    my $rrCount = my @rrKeys = keys %rh;
                    for my $le (@llKeys) {
                        my $rs = $rh{$le};
                        if ($rs) {
                            # $le can be found in both arrays - in left and right but values can be differentl 309
                           $sumScore += $rs;
                            if ($lh{$le}) {
                                $sumScore += $lh{$le};
                            }
                        }
                    }
                }
            }
            # Now evaluate final score with threshold and make decision
            if ($sumScore <= $scoreThreshold) {
                # Yes, this term is distant enought from all previous
                # Add it to the pickedTerms
                $pickedTerms{$freshPicked} = \%lh;
                $tryCounter = 0;
                $setCount++;
                if ($verbose == 1) {
                    print "Term is OK, max score is $sumScore. Added to list\n";
                }
            } else {
                if ($verbose == 1) {
                    print "Term is too close to picked set - score is $sumScore. Looking for next...\n";
                }
                push(@rejectedTerms,$freshPicked);
                $tryCounter++;
            }
        }
    }   # main set filler loop finished

    print "Total amount of terms in output Set#".$setCounter." - $setCount\n";
    my @ak = keys %pickedTerms;
    # print Dumper(\@ak);

    foreach my $kkk (@ak) {
        my $pTerm =  $invTerms{$kkk};
        print $pTerm,"\n";
        push(@justUsedTerms, $kkk);
        print $ofh $termArray[$kkk]."\n";
    }
    print $ofh "--------------------------------\n";

    $setCounter++;
}

close $fh;

exit 0;



