#! /usr/bin/perl -w

use strict;
$|++;

#Tasks:
#1 [x] Find and take in data from correctly formatted txt files
	# [x] check that txt files are correctly formated
	#[ ] fix line 80 by re-writing elsif block starting ln 74
	# [ ] extract data from incorrectly formatted files 
#2 [x] extract review ratings by date
	# [ ] normalize ratings across different soruces and/or find more informative measures to compare between them
		# (amazon and goodread ratings occur within different contexts and need more nuanced translation between each other.
#3 [ ] Get POS data for contents
	#[x] send file to be processed by Stanford NLP packages 
	#[x] clean tagged POS file of unwanted tags
		#[x] POS tagger removes newline after some comments (ones without eol character).  Would it be better to write each review to a separate file for POS tagging?
	#[ ] expand beyond POS (Starting with POS tagger, but eventually transition to CoreNLP for NER, sentiment, and lexparser too)
		#[ ] output will be in tokenized xml once the switch to CoreNLP occurs
#4 [x] find sentiment-indicative patterns

unlink "POS.txt";
unlink "POStagged.txt";
unlink "timeline.txt";
unlink "POScleaned.txt";
unlink "AA.txt";
unlink "AAA.txt";
unlink "AV.txt";

#1********************************************************		
#open directory and get contents
my $dir = ".";
opendir (DIR, $dir) || die ("Cannot open directory.");
my @files = readdir (DIR);
closedir (DIR);

#Ingest all data files, separate into two hashes containing metadata and contents respectively
my %meta = (); my %contents = (); #
my $ic = 0; #assign a unique item number to each entry.  persistent across files
foreach my $f (@files) {

	# unless (($f eq ".") || ($f eq "..") || ($f eq "search1.pl")) {
	if ($f =~ /.+\.txt$/){ #this should skip all files without a txt extension
		
		open (F, $f);
		my $firstline = <F>;
		next unless ($firstline =~ /$0/ ); #all correctly formatted data files must contain the name of the script in the first line
		
		my $inent = 0; #keep track of when we are within an entry
		my $snd = ''; #buffer of string to be sent to meta or contents array **** actually, I might go with hashes
		
		print "retrieving reviews from ", $f, "...\t";
		while(<F>){
			my $line = $_; chomp $line;
			
			#identify and write metadata to @meta array 
			if ($line =~ /^\d+,(.+?,\s*?\b\d{8}\b,.+?,.+?,.+?,.+?),(.+?)$/){ 
				
				#need to build in a test in case contents from previous entry was never written to %contents.  Should be easy since each %contents assignment is followed by clearing of $snd
				
				$inent = 1;
				$ic++;
				
				my $bulk = $1; #meat of the metadata string from username through title.

				#replace url with something a little friendlier
				my $src = '';
				if ($2 =~ /\bhttp.+?amazon\..+?\b/){
					$src = "Amazon";
				} elsif ($2 =~ /\bhttp.+?goodreads\..+?\b/){
					$src = "Goodreads";
				} else {
					print "source not recognized.\n";
				}
				
				$snd = $ic.",".$bulk.", ".$src;
				#push (@meta, $snd); #useless now that I've decided to use hashes
				$meta{$ic} = $snd;
				$snd = '' #I know there's a command to clear the scalar... look this up later
			}
			
			#write contents to %contents if within an entry.  else ignore line ***********REWRITE!**********
			elsif ($inent eq 1){
				if ($line =~ /^\s*$/){ #"unless" would seem to make more sense here... trigger to send to %contents is blank line at end of each entry
					$contents{$ic} = $snd;
					$snd = '';
					$inent = 0;
				} else {
				$snd .= $line."\n"; #!!!this was causing the contents of the last entry in each file to remain unwritten.  adding 2 blank lines to end of data file as temp fix.  better solution would be to append to value at the end of each qualified line.
				}
			}
			
		}
		print "end retrieval after entry #".$ic."\n";
	}
	close F;
}



#2*********************************************
#star ratings by date
my %points = ();
my %dates = ();
my %ratings = ();
foreach my $key (keys %meta){
	$meta{$key} =~ /^\d+,.+?,\s*?(\b\d{8}\b),(.+?),.+?,.+?,.+?,.+?$/;
	$dates{$key} = $1;
	$ratings{$key} = substr($2, 1, 1);
}
#check date overlap
my %bydate = reverse %dates;
if (scalar keys %dates == scalar keys %bydate){ #no overlap
	foreach my $entry (keys %dates){
		$points{$dates{$entry}} = $ratings{$entry}; 
	}
} else {
	my %seen;
	my @dups;
	foreach my $entry (keys %dates) {
		$points{$dates{$entry}} += $ratings{$entry}; 
		next unless $seen{$dates{$entry}}++; #this should give a count of occurrances for each date
		# my $rating = $points{$dates{$entry}};
		# $rating = ((($rating - $ratings{$entry}) * ($seen{$dates{$entry}} - 1)) + $ratings{$entry}) / $seen{$dates{$entry}};
		# $points{$dates{$entry}} = $rating;
		push (@dups, $dates{$entry}) unless ($dates{$entry} ~~ @dups)
	}
	foreach my $date (sort @dups){
		$points{$date} /= $seen{$date};
		print "\nthere are $seen{$date} entries for an average score of $points{$date} on $date";
	}	
}
#Write timeline to file (writing now in case POS fails 
my $tofile = "";
open (P, ">timeline.txt");
foreach my $key (sort keys %points) {
	$tofile.= "$key\t$points{$key}\n";
}
print P $tofile;
close P;
opendir (DIR, $dir) || die ("\nCannot open directory.");
@files = readdir (DIR);
closedir (DIR);
if ("timeline.txt" ~~ @files) {
	print "\nTimeline written to timeline.txt\n"; #could probably check that the written data is correct, but that might be too much
} else {
	print "\nCould not write timeline to file.";
}



#3***************************************************
# Parts of speech

#create file to be processed
$tofile = "";
foreach my $item (keys %contents){
	$meta{$item} =~ /^\d+,.+?,\s*?\b\d{8}\b,.+?,.+?,.+?,(.+?),.+?$/; #grab user-assigned title/categories from metadata
	#Original plan was for more metadata to be included in the contents file, but for this portion, it would be more useful to keep the text clean
	my $pmeta = $1;
	$tofile .= "$item ($pmeta)>>\n$contents{$item}\n";
}

open (P, ">POS.txt");
print P $tofile;
close P;
opendir (DIR, $dir) || die ("\nCannot open directory.");
@files = readdir (DIR);
closedir (DIR);
if ("POS.txt" ~~ @files) {
	print "\nSending contents to Stanford POS tagger...\n";
} else {
	die ("\nCould not write contents to file for POS tagging.");
}
#send to POStagger
my $POS = `java -Xmx3g -cp c:\\tagger\\stanford-postagger-3.3.0.jar edu.stanford.nlp.tagger.maxent.MaxentTagger -model c:\\tagger\\models\\english-left3words-distsim.tagger -textFile POS.txt > POStagged.txt`;
opendir (DIR, $dir) || die ("Cannot open directory.");
@files = readdir (DIR);
closedir (DIR);
if ("POStagged.txt" ~~ @files) {
	print "POS tagging successful.\n";
} else {
	die ("POS tagging failed.");
}
#tag patterns we want
$POS = "";
open (F, "POStagged.txt");
while (<F>) {
	my $line = $_; chomp $line;
	$line =~ s/_(?!RB[RS]?|VB\b|JJ[RS]?)[A-Z]{2,4}\${0,1}//g; #since we're only keeping a limited set of tags, it's easier to just remove everything but exceptions
	$line =~ s/_RB[RS]?/_ADV/g;
	$line =~ s/_JJ[RS]?/_ADJ/g;
	$line =~ s/_VB\b/_VRB/g;
		$line =~ s/\>\>_.+?\b/>>/g; 
		$line =~ s/\-LRB\-_\-LRB\-/(/g;
		$line =~ s/\-RRB\-_\-RRB\-/)/g;
		$line =~ s/\(\s/(/g;
		$line =~ s/\s\)/)/g;
		$line =~ s/_[,.:]//g;
		$line =~ s/\s(?=[;,:.\-?!])//g;
		$line =~ s/\'\'_\'\'/"/g;
		$line =~ s/\`\`_\`\`\s/"/g;
		$line =~ s/\s\'s/'s/g; #remove this line if you start tagging nouns! not removing spaces before all ' because some verbs are tagged
	$POS .= $line."\n";
}
close F;
$POS =~ s/([0-9]{1,2})\s\(.*?\)\s\>\>/\n$1\>\>\n/g; 
$POS =~ s/\n\s+/\n/g; #remove leading spaces and extra blank lines
open (P, ">POScleaned.txt");
print P $POS;
close P;
print "\nRemoved unwanted POS tags.  Saved to POScleaned.txt\n";

#4*************************************************
#Find patterns.  Starting with the three in the example: adv adj, adv adv adj, adv vrb
#The example code did all of this on a file-by-file basisand therefore does not have to worry about keeping track of multiple 
my @aa = (); my @aaa = (); my @av = ();
$POS .="\n00\>\>"; #dummy tag so I don't have to deal with the end of the file being different from everything else
while ($POS =~  /([0-9]{1,2})\>\>\n((.+?\n+?)+?)(?=[0-9]{1,2}\>\>)/mg){
	$contents{$1} = $2;
}
foreach my $entry (keys %contents){
	my $review = $contents{$entry};
	$meta{$entry} =~ /^\d+,.+?,\s*?\b\d{8}\b,.+?,.+?,.+?,.+?,(.+?)$/;
	my $site = substr($1, 1);
	my $score = $ratings{$entry};
	foreach my $sentence (split /\n/, $review){
		my $desc =  "$site (rating: $score, ID: $entry)";
		if ($sentence =~ /\w+_ADV\s\w+_VRB/){
			$desc .= "-RV";
			if ($sentence =~ /\w+_ADV\s\w+_ADV\s\w+_ADJ/) {
				$desc .= "-RR";
			}
			if ($sentence =~ /\w+_ADV\s\w+_ADJ/) {
				$desc .= "-RJ";
			}
			push @av, $desc.">>".$sentence;
		}
		elsif ($sentence =~ /\w+_ADV\s\w+_ADV\s\w+_ADJ/) {
			$desc .= "-RR";
			if ($sentence =~ /\w+_ADV\s\w+_ADJ/){
				$desc .= "-RJ";
			}
			push @aaa,$desc.">>".$sentence;
		}
		elsif ($sentence =~ /\w+_ADV\s\w+_ADJ/){
			$desc .= "-RJ";
			push @aa,$desc.">> ".$sentence;
		}
	}
}
#save 'em!
open (P, ">AAA.txt");
print P "Sentiment (ADV ADV ADJ):\n\n";
foreach my $snt (sort @aaa) {
	print P $snt."\n";
}
close P; 
open (P, ">AA.txt");
print P "Sentiment (ADV ADJ):\n\n";
foreach my $snt (sort @aa) {
	print P $snt."\n";
}
close P; 
open (P, ">AV.txt");
print P "Sentiment (ADV Vrb):\n\n";
foreach my $snt (sort @av) {
	print P $snt."\n";
}
close P; 

print "\nSaved pattern-matched files, AA.txt, AAA.txt, and AV.txt";
