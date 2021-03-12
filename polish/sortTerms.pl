#!/usr/bin/perl
#
# Auxillary utility - sort frequency list for polish language
# and removes entries from 3 letters or shorter
#
#    Usage:
#
# ./sortTerms.pl < polfreq.txt | sort > freqSorted.txt
#  wc polfreq.txt
#  5000    5136   40214 polfreq.txt
#  wc freqSorted.txt
# 4749    4886   39282 freqSorted.txt
#

while (<>) {
    chomp;
    my $word = $_;
    if (length($word) < 4) {
        next;
    }
    print $word."\n";
};

