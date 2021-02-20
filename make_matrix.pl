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

use Data::Dumper;

my $workDir     =   "./work_dir";
my $srcDir      =   "./source_files";

my $termFile    =   $srcDir."/kid-friendly-sets.txt";
my $scoreFile   =   $srcDir."/Human-and-Machine-and-Manual.txt7";

my $termIndex   =   $workDir."/termIndex";


# Step 1. Create list of terms

open(my $fh, '<:encoding(UTF-8)', $termFile) or die "Could not open file '$termFile' $!";

my %terms;
my $lineCounter = 0;
my $termCounter = 0;
while (my $row = <$fh>) {
    chomp $row;
    my ($term,$syns) = $row =~ /^@\s(.*)\s=(.*)$/;
    # unify term representation
    $term  = lc $term;

 #   print "term - $term\n";
 #   print "syns - $syns\n";
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
print "*** Amount of unique terms - $lineCounter\n";
print "*** Total amount of terms (incl. synonyms) - $termCounter\n";

exit 40;

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
        # parse header
        (my $tmp) = $header =~ /^\#(.*)\[/;
        if ($tmp) {
            $termName = $tmp;
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
                my $tac = my @ta = @{$scoreList{$headerName}};
                @tmpArray  = split /\|/,$content;
                my %tScore;
                for (my $j = 0; $j < $tac; $j++) {
                    my $tName = $ta[$j];
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

    print "Thesaurus records parsed: $totalCnt\r";
}
close $fh;

print "\n";

#
#   Step 3. Create and Fill distance Matrix
#





print "*** Total direct definitions - $cntDirect\n";



print "\n\n\n";




exit 0;

