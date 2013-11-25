#!/usr/bin/perl
################## -COPYRIGHTS & WARRANTY- #########################
## This program is provided without any warranty of fitness
## for any purpose. You can redistribute this file
## and/or modify it under the terms of the GNU
## Lesser General Public License (LGPL) as published
## by the Free Software Foundation, either version 3
## of the License or (at your option) any later version.
## (see http://www.opensource.org/licenses for more info)
####################################################################

## -Author: Anver Hisham <anverhisham@gmail.com>
####################################################################

## -Include required packages/functions ,.
use strict;
use warnings;
use POSIX;
$SIG{CHLD} = 'IGNORE';	# To avoid zombie child processes

## -USER INPUTTED PARAMETERS
my $sourceEmailAddress = 'newCommit@cewit.org.in'; 
my $printDebugInfo = 1;

############ First change to working-directory (simulator-directory)
use Cwd 'abs_path';
my $scriptPath = abs_path($0);
my $scriptFolder = $scriptPath; $scriptFolder =~ s/\/[^\/]*$//;

my $workingDirectory = $scriptFolder."/../";           ## "/home/anver/Programming/eclipse_workspace/LTESimulator";   ##"/backup/Repository/LTESimulator"; # '/media/anver@10.7.133.131/LTESimulator'; # "/home/anver/Work/BWSim"; #

sub extractInputFileOfPerl;
sub getCommonElements;
sub getArray1MinusArray2;
sub cleanTheFile;
sub grepOutFromArray;
sub trimSpacesFromBothEnd;
sub getUniqueElements;
sub multiThreadBashCommands;

######### Perl script to send mail if any modification happened in non-permitted files
#########    in latest bazaar revisions
print "-------------- PID of Perl Script(sendEmailUponCommit.pl) = $$ ---- on ".`date`."\n";

####### Note: All temp-files should be in same folder as this script itself #####
use Cwd 'abs_path';
if($printDebugInfo)
{print "\$scriptPath = $scriptPath \n"; }

chdir "$workingDirectory"; 
print(`bzr update;`);
my $mailListFile = "$workingDirectory/bzrEmail/mailListToSendCommit.txt"; cleanTheFile($mailListFile);

my(@violatedFiles,$Warnings,$Errors,@diffFileNamesToAttach);
my $filesToDelete = '';
## 1. Get oldRevNumber from lastRevNumberUponWhichCommitMailSent.txt
my $oldRevNumber = `cat bzrEmail/lastRevNumberUponWhichCommitMailSent.txt`;					chomp($oldRevNumber); 
## 2. Get newRevNumber (ie latest revision number) from bzr
my $newRevNumber = `bzr log |grep -Po '(?<=revno:\\s)\\d*' |head -1`;	chomp($newRevNumber);

################## IF any new commits happened, then only proceed #################
if($newRevNumber>$oldRevNumber) {
	## 5. Create subject/message-body-file/attachments if violations happened.
	## my $emailSubject = "[New Commit] ";
	my $emailSubject = ($newRevNumber-$oldRevNumber>1)? "[New Commit] {rev: ".($oldRevNumber+1)."..$newRevNumber}":"[New Commit] {rev: $newRevNumber}";

	my @violatedFilesOnEmailSubject = ();
	my $emailText = "-" x 60; $emailText=$emailText."\n";
###	for my $iRevision($oldRevNumber+1..$newRevNumber) {
        for (my $iRevision=$newRevNumber; $iRevision>$oldRevNumber; $iRevision--) {
		$emailText = $emailText.`bzr log --verbose|grep -Pzo 'revno:\\s$iRevision\\X*?-{10,}'`;
		#### Now Create a diff-file ####
		my $tempOldRev = $iRevision-1;
		my $diffFileName = "${scriptFolder}/diff_r${tempOldRev}to${iRevision}.txt";
		print(`bzr diff -r${tempOldRev}..${iRevision} > $diffFileName;`);
		push(@diffFileNamesToAttach,$diffFileName);
		#### 3.2 Get files which got changed
		my @changedFiles = `bzr log -r${iRevision} --verbose |perl -ne 'BEGIN{undef \$/;} s/-*\\Rrevno(\\X|\\R)*?modified:\\R\\s*//g && print'`;	trimSpacesFromBothEnd(\@changedFiles);
		push(@violatedFilesOnEmailSubject,@changedFiles);
	}
	
	
	@violatedFilesOnEmailSubject = grepOutFromArray('[^/]*$',getUniqueElements(@violatedFilesOnEmailSubject));
	if(scalar(@violatedFilesOnEmailSubject)<5) {
		$emailSubject = $emailSubject.join(' ',@violatedFilesOnEmailSubject);
	}
	
	
	my $emailTextFileName = "${scriptFolder}/emailText.txt"; $filesToDelete = "$filesToDelete $emailTextFileName";
	open emailTextFile, ">$emailTextFileName"  or die "can't open file: $!";
  	print(emailTextFile $emailText); close emailTextFile;
  
  	if($printDebugInfo) {
		print "\$emailText = $emailText \n";
		print "\$emailSubject = $emailSubject \n";
  	}

	## 6. Finally send-mail	
	my @mailList = extractInputFileOfPerl($mailListFile); my $mailListAsString = join(' ',@mailList);
	my $uuencodeString='';
	foreach my $fileToAttach(@diffFileNamesToAttach) {
		my $destinationFile = $fileToAttach;
		$destinationFile =~ s/^.*\///; $destinationFile =~ s/\..*?$//;
		$uuencodeString = $uuencodeString." uuencode $fileToAttach $destinationFile;";
	}
	my $diffFileNamesAsString = join(' ',@diffFileNamesToAttach);
	my $shellScriptToSendMail = "(cat $emailTextFileName; $uuencodeString) |mail -a From:$sourceEmailAddress -s \"$emailSubject\" $mailListAsString;";
    multiThreadBashCommands($shellScriptToSendMail);
  	if($printDebugInfo)
	{	print "\$shellScriptToSendMail = $shellScriptToSendMail \n"; 	}		
	###### Delete ALL Temp files created ######	
	$filesToDelete = "$filesToDelete ".join(' ',@diffFileNamesToAttach);
	print(`rm -f $filesToDelete;`);
}
#############################################################################
	
### Printig new-revision number,
print(`echo "$newRevNumber" > bzrEmail/lastRevNumberUponWhichCommitMailSent.txt`);
	
if(defined $Warnings && $Warnings !~ m/^\s*$/)
{	print "\n************** Warnings: *****************\n $Warnings"; 	}	
if(defined $Errors && $Errors !~ m/^\s*$/)
{	print "\n************** Errors: *****************\n $Errors";		}
print "\n________________ sendEmailUponCommit.pl Script Over _____________--- on ".`date`."\n";
	
	
	
############################## Supporting Functions ################################
####################################################################################

########### Return: array of lines which excludes perl comments & spaces on both sides... #########
########### Usage: extractInputFileOfPerl($fileName)..... ############
sub extractInputFileOfPerl {
	my $inputfileName = $_[0];
	my $delimiter;
	if(defined($_[1]))	{	$delimiter = $_[1];	}
	else				{	$delimiter = '\n';	}
	my @output;		
	
	open FH, "<", "$inputfileName" or die "cannot open < $inputfileName: $!";
	########################## Collect all inputs ###################
	my $iLine=0;
	while(my $line= <FH>) {
		$line =~ s/#.*//g;  # Chopping out the commmenting part...
		chomp($line); 		# Chopping out the end newline character...
		push(@output,split($delimiter,$line));
	}
	trimSpacesFromBothEnd(\@output);
	return @output;	
}

######### pointers to two arrays are expected as input ###########
sub getCommonElements {
  my @input0 = @{$_[0]};
  my @input1 = @{$_[1]};
  my @output=();
  foreach my $temp(@input0) {
    # grep(/$_/i, @input1)
    @output=(@output,grep(/\b$temp\b/, @input1));
  }
  return @output;
}

######### pointers to two arrays are expected as input ###########
sub getArray1MinusArray2 {
  my @input0 = @{$_[0]};
  my @input1 = @{$_[1]};
  my @output=();
  foreach my $temp(@input0) {
  	if(!grep(/\b$temp\b/,@input1)) {
  		push(@output,$temp);
  	}
  }
  return @output;
}

######### Following function clean the inputFile by removing hidden characters & blank lines #########
sub cleanTheFile {
	my $inputfileName = $_[0];
	`perl -p -i -e 's/[^\\040-\\176\\012]/ /g' $inputfileName;`; ### Removing all hidden characters in intput text file...
	`perl -p -i -e 'BEGIN{undef $/;} s/^(\\s|\\R)*\$//g' $inputfileName;`; ### Removing all blank lines...
}


######### Filter the pattern from the array ########
sub grepOutFromArray {
	my @output = ();
	my $pattern = shift(@_);
	
	foreach my $element(@_) {
		if($element =~ /($pattern)/) {
			push(@output,$1);
		}
		else {
			push(@output,'');
			$Warnings = $Warnings."In function grepOutFromArray: No \$pattern = $pattern in \$element = $element \n";
		}
	}
	return @output;
}

################ Output the unique elements in an Array ##################
##### Got code from http://stackoverflow.com/questions/7651/how-do-i-remove-duplicate-items-from-an-array-in-perl
sub getUniqueElements {
    my %seen = ();
    my @r = ();
    foreach my $a (@_) {
        unless ($seen{$a}) {
            push @r, $a;
            $seen{$a} = 1;
        }
    }
    return @r;
}

######### Advantage: Trim an array of array of array..... ##########
######### Input: Only one reference to Scalar/Array... ##########
sub trimSpacesFromBothEnd {
	my $input = $_[0];
	
	if ( UNIVERSAL::isa($input,'REF') ) {											# Reference to a Reference
		trimSpacesFromBothEnd(${$input});
	}
	elsif ( ! ref($input) ) { 														# Not a reference
	    print "Error(trimSpacesFromBothEnd): Not a reference, Can't be trimmed...";
	    exit 0;
	}
	elsif ( UNIVERSAL::isa($input,'SCALAR')) {  									# Reference to a scalar
		chomp(${$input});			## TODO This line added on 17-7-2012. won't be harmful, I think
		${$input} =~ s/^\s+//g;
		${$input} =~ s/\s+$//g;		
	}
	elsif ( UNIVERSAL::isa($input,'ARRAY') ) { 										# Reference to an array
		foreach my $element(@{$input}) {
			trimSpacesFromBothEnd(\$element);
		}
	}
	elsif ( UNIVERSAL::isa($input,'HASH') ) { 										# Reference to a hash
	    print "Error(trimSpacesFromBothEnd): Reference to an hash, Can't be trimmed...";
	    exit 0;
	}
	elsif ( UNIVERSAL::isa($input,'CODE') ) { 										# Reference to a subroutine
	    print "Error(trimSpacesFromBothEnd): Reference to an subroutine, Can't be trimmed...";
	    exit 0;
	}
}

### Input: Array of input shell commands #####
### Note: This function waits for all bash-commands to get finished.. ######
use threads();
sub multiThreadBashCommands {
	my @threads; my $ithread=0;
	foreach my $bashCommand(@_) {
		if($bashCommand=~m/^\s*$/) { next; }
		$ithread = $ithread+1;
		push @threads, threads->new(sub{print(`$bashCommand`)}, $ithread);
	}
	foreach (@threads) {
	   $_->join();
	}
}


