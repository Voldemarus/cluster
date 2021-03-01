#!/usr/bin/perl
#
#   Distance matrix generator
#
#   Will create matrix file in working directory
#   Should be called once for each termFile and scoreFile
#
#   ./make_matrix.pl

use strict;
use warnings;

use List::MoreUtils qw(first_index);

use Data::Dumper;


my $SetCapacity      =   80;         # Amount of low correlated terms in the set
my $retryCounter     =   20;         # amount of false retries
my $scoreThreshold   =   0.004;      # maximum similarity for two terms


my $workDir     =   "./work_dir";
my $srcDir      =   "./source_files";

my $termFile    =   $srcDir."/kid-friendly-sets.txt";
my $scoreFile   =   $srcDir."/Human-and-Machine-and-Manual.txt7";

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

    if (!$terms{$term}) {
        # no such term was used before
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

    if ($lineCounter > 30) {
        print Dumper(\%invTerms);
        last;
    }
}
my $uniqueTermsCounter = $lineCounter;
print "*** Amount of unique terms - $uniqueTermsCounter\n";
print "*** Total amount of terms (incl. synonyms) - $termCounter\n";

#
#   Now we should save this hash array into inddex file
#   for later usage
#
open(my $fw, '>:encoding(UTF-8)', $termIndex) or die "Could not open file '$termFile' $!";

foreach my $key (keys %terms) {
    my $value = $terms{$key};
    print $fw "$key,$value\n";
}
close $fw;

print "*** Term index saved in working directory\n";

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
 #          print "!!!!! ".$fields[$i]."\n";
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
 #           print " ".Dumper($scoreList{$headerName});
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
 #   print Dumper(\%scoresLocal);

    $scores{$termName} = \%scoresLocal;
    $totalCnt++;

    if ($totalCnt > 50000) {
#        print Dumper(\%scores);
        last;
    }

    print "Thesaurus records parsed: $totalCnt\r";
}
close $fh;


my $tCounter = @termArray;

my $setCount = 0;
my %pickedTerms;

my $freshPicked = -1;
while ($setCount < $SetCapacity) {
    $freshPicked = -1;
    my $tryCounter = 0;
    while ($freshPicked < 0 && ($tryCounter < $retryCounter * ($setCount + 1))) {
        my $picker = int(rand($tCounter));
        if ($pickedTerms{$picker}) {
            $tryCounter++;
            next;
        } else {
            $freshPicked = $picker;
        }
    }
    if ($setCount == 0) {
        # create scores entries for this element
        my @leftList;
        # get list of synonyms for left part
        my $val = $invTerms{$freshPicked};
        print ">>>>  $freshPicked ->  $val <<<<< \n";
        my $lScoreRec = $scores{$val};
        if ($lScoreRec) {
           # and put it into left array to use in comparasion
          push(@leftList,$lScoreRec);
        }
        for ((my $key, my $value) = each %terms) {
            print "$freshPicked / $value  \n";
            if ($key eq $freshPicked) {
                print "Synonym - $key\n";
                my $addScoreRec = $scores{$key};
                if ($addScoreRec) {
                    push(@leftList, $addScoreRec);
                }
            }
        }
        # add first entry to output list of terms, will be used later
        $pickedTerms{$freshPicked} = \@leftList;
        $setCount++;
        print Dumper(\@leftList);
        print "Picked term - ".$val." as kernel of new set\n";
    } else {
        # This is new term, need to estimate score
#       my @termsToScore = keys %pickedTerms;
#       my @leftList;
#        # get list of synonyms for left part
#        my $lScoreRec = $scores{$value};
#        if ($lScoreRec) {
#             # and put it into left array to use in comparasion
#             push(@leftList,$lScoreRec);
#        }
#        # now @leftList contains all score hashes rlevant to it and synonyms
#        print Dumper(\@leftList);
exit 33;
        # now we'll loop through all entries, picked before
#        for ( my ($key, $value) = each %pickedTerms) {
#            print "checking against ".$invTerms{$key}."\n";
#            my @rightList = @{$value};
#
#
#        }
    }

}   # main set filler loop finished

print "Total amount of terms in output set - $setCount\n";

my @ak = keys %pickedTerms;
print Dumper(\@ak);



exit 0;



