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

my $workDir     =   "./work_dir";
my $srcDir      =   "./source_files";

my $termFile    =   $srcDir."/kid-friendly-sets.txt";
my $scoreFile   =   $srcDir."/Human-and-Machine-and-Manual.txt7";

my $termIndex   =   $workDir."/termIndex";
my $distMatrix  =   $workDir."/distanceMatrix";

# Step 1. Create list of terms

open(my $fh, '<:encoding(UTF-8)', $termFile) or die "Could not open file '$termFile' $!";

my %terms;
my $lineCounter = 1;        # to look into kids file in a ntural way
my $termCounter = 0;
while (my $row = <$fh>) {
    chomp $row;
    my ($term,$syns) = $row =~ /^@\s(.*)\s=(.*)$/;
    # unify term representation
    $term  = lc $term;

    if (!$terms{$term}) {
        # no such term was used before
        $terms{$term} = $lineCounter;
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

#    if ($totalCnt > 1000) {
#        print Dumper(\%scores);
#        last;
#    }

    print "Thesaurus records parsed: $totalCnt\r";
}
close $fh;

print "\n";

#
# Step 2.1 Merge terms with upper and lower cases
#
my %scoreMerged;
my $entryCount = my @entries = keys %scores;
for (my $i = 0; $i < $entryCount; $i++) {
    my $keyToCheck = lc $entries[$i];
    if (length($keyToCheck) < 3) {
        print "Non valid word - $keyToCheck\n";
        next;
    }
#    print "Key : $keyToCheck\n";

    # find keys which resemble to this key
    my @matching = ();
    foreach (@entries) {
        push(@matching, $_) if /$keyToCheck/i;
    }
    # init output score
    my %buffer = %{$scores{$matching[0]}};
    my $keyCount = @matching;
    # and add any additional definitions from "suimilar" definitions
    if ($keyCount > 1) {
        for (my $k = 1; $k < $keyCount; $k++) {
            my %buf2 = %{$scores{$matching[$k]}};
            %buffer = (%buffer, %buf2);
        }
    }
    $scoreMerged{$keyToCheck} = \%buffer;
#    print "( $i of $entryCount)\n";
}

# print Dumper(\%scoreMerged);

print "\n*** Total direct definitions - $entryCount\n";


#
#   Step 3. Create and Fill distance Matrix
#

print "*** Initialising distance Matrix";

my @distance;

$uniqueTermsCounter = 100;

#DEBUG FIX ME!
#my $matrixSize = $uniqueTermsCounter * $uniqueTermsCounter;


print "MatrixSize - $matrixSize\n";
for (my $i = 0; $i < $matrixSize; $i++) {
     $distance[$i] = 0;
}

print "*** Distance Matrix initialised ($matrixSize elements total).";

# now we making biiiig loop through the whole synsets
my @keyTerms  = keys %terms;
for (my $i = 0; $i < $termCounter; $i++) {
    my $leftTerm = $keyTerms[$i];
    my $leftIndex = $terms{$leftTerm};
    for (my $j = 0; $j < $termCounter; $j++) {
        my $rightTerm = $keyTerms[$j];
        my $rightIndex = $terms{$rightTerm};

#        print "$i : $leftTerm  $j : $rightTerm ";

        my $matrixOffset = $leftIndex * $uniqueTermsCounter + $rightIndex;
        if ($leftIndex == $rightIndex) {
            $distance[$matrixOffset] = 10000;   # diagonal
#            print "$i : $j -> $leftTerm ($leftIndex) : $rightTerm ($rightIndex) : Diagonal - Score -- 10000\n";
            next;
        } else {
            # try to pick score for direct synset case
            if (!$scoreMerged{$leftTerm}) {
#                print "No score for $leftTerm found!  Score -- 0\n";
                next;
            }
            my %leftList = %{$scoreMerged{$leftTerm}};
            if (%leftList && $leftList{$rightTerm}) {
                my $addScore = $leftList{$rightTerm};
                $distance[$matrixOffset] += $addScore;
                print "(L) Direct $rightTerm found - add: $addScore  total: ".$distance[$matrixOffset]."\n";
                next;
            }
            if (!$scoreMerged{$rightTerm}) {
#                print "No score for $rightTerm found!  Score -- 0\n";
                next;
            }
            my %rightList = %{$scoreMerged{$rightTerm}};
            if (%rightList && $rightList{$leftTerm}) {
                my $addScore = $rightList{$leftTerm};
                $distance[$matrixOffset] += $addScore;
                print "(R) Direct $leftTerm found - add: $addScore  total: ".$distance[$matrixOffset]."\n";
                next;
            }
            # case 2 - try to estimate score by comparasion
            # scores in left and right lists. It requires both
            # terms should have synset lists
             if (%leftList && %rightList) {
                my $lkc = my @keysLeft = keys %leftList;
                my $rkc = my @keysRight = keys %rightList;
                my $localScore = 0;
                 print "Looking for intersect - L($lkc) and R($rkc)\n";
                # Scan arrays to get intersections
                 foreach my $rec (@keysRight) {
                   #  print "       $rec ";
                     my $ind = first_index { $_ eq $rec } @keysLeft;
                     if ($ind > -1) {
                         # found
 #                        print "$rec found! \n";
 #                        print "   Left score - ".$leftList{$rec}."\n";
                         $localScore += $leftList{$rec};
  #                       print "   Right score - ".$rightList{$rec}."\n";
                         $localScore += $rightList{$rec};
 #                        print "   Adjusted local score $localScore\n";
                     }
                 }
                 $distance[$matrixOffset] += $localScore;
                 print "Indirect score calculated = ".$distance[$matrixOffset]."\n";
             }
        }
    }
}

print "*** Distance Matrix calculated.\n";

#
# Storing matric in work-dir
#
open($fw, '>:encoding(UTF-8)', $distMatrix) or die "Could not open file '$distMatrix' $!";

print $fw "$uniqueTermsCounter\n";

foreach my $rec (@distance) {
    print $fw "$rec\n";
}
close $fw;

print "*** Distance Matrix saved.\n";

#
# Estimate score histogram
#

my %histogram;
foreach my $rec (@distance) {
    if (!$histogram{$rec}) {
        $histogram{$rec} = 1;
    } else {
        $histogram{$rec} = $histogram{$rec} + 1;
    }
}
print "\n\n\n";
#my $karc = my @keke =  sort keys %histogram;
#print Dumper(\@keke);
#for (my $i = 0; $i < $karc; $i++) {
#    my $karr = $keke[$i];
#    print "$karr :: ",$histogram{$karr}."\n";
#}

print "\n\n\n";

exit 0;



