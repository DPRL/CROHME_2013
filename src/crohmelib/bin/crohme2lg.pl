#!/usr/bin/perl
use XML::LibXML;
use Data::Dumper;
use strict;  

# WARNING: to avoid obtaining "Hash reference deprecated" messages,
# removing warnings. For debugging, this needs to be removed!!! (RZ)
no warnings;

if($#ARGV < 0){
print "CROHMELib CROHME .inkml to Label Graph (.lg) Converter
Copyright (c) H. Mouchère and R. Zanibbi, 2012-2013

Usage:  crohme2lg.pl fileIn.inkml [fileOut.lg]
	
If no output file is provided, the label graph is printed on the
standard output (STDOUT).

Version : 1.2
Authors: Harold Mouchère (LUNAM/University of Nantes/IRCCyN/IVC)
	R. Zanibbi (DPRL Lab, RIT, USA)
";
exit();
}

#define some global var
my $warning = 1;

#my $inheritRelationships = 1;
#if ($ARGV[0] eq "-t") {
#	$inheritRelationships = 0;
#	for (my $local; $local < scalar @ARGV; $local++) {
#		$ARGV[$local] = $ARGV[$local + 1];
#	}
#}

# define edges creation depending of the mathML tag : {"tag" => liste of edges with label },  index -1 means that there are no corresponding child but the current node should be used (eq msqrt and mfrac)
my %tagToSRT = (
	"mrow" => [[0,1,'R']],
	"msup" => [[0,1,'Sup']],
	"msub" => [[0,1,'Sub']],
	"mfrac" => [[-1,0,'A'],[-1,1,'B']],
	"msqrt" => [[-1,0,'I'],[-1,1,'I']],
	"mroot" => [[-1,0,'I'],[-1,1,'A']],
	"munder" => [[0,1,'A']],
	"munderover" =>  [[0,1,'B'], [0,2,'A']],
	"msubsup" =>  [[0,1,'Sub'], [0,2,'Sup']]
	);
my %tagMainSymb = (
	"mrow" => 1,
	"msup" => 0,
	"msub" => 0,
	"mfrac" => -1,
	"msqrt" => -1,
	"mroot" => -1,
	"munder" => 0,
	"munderover" => 0,
	"msubsup" => 0,
	"mo" => -1,
	"mi" => -1,
	"mn" => -1
	);




#define the global parser and its options (uses 'recover' because some xml:id do not respect NCName)
my $parser = XML::LibXML->new();
$parser->set_options({no_network=>1,recover=>2,validation=>0, suppress_warnings=>1,suppress_errors=>1});


if($#ARGV < 2){
	my $t1 = &Load_From_INKML($ARGV[0]);
	my $output ;
	
	if($#ARGV == 1){
		open($output, ">", $ARGV[1]) or die "cannot open > ".$ARGV[1].": $!";
	}else{
		$output = \*STDOUT;
	}
	#print "Normalization:\n";
	&norm_mathMLNorm($t1->{XML_GT});
	#print "Checking:\n";
	&check_mathMLNorm($t1->{XML_GT});
	&printBG($t1, $output);
	if($#ARGV == 1){
		close($output);
	}
	exit(0);
}
########## SUB definitions ###########

## create the truth structure ###
sub newTruthStruct {
        my $self  = {};
        $self->{UI}   = "";
        $self->{STRK} = {};
        $self->{SYMB} = {};
        $self->{NBSYMB} = 0;
        $self->{XML_GT} = [];
        bless($self);           
        return $self;
}
############################
#### Load struct from an inkml file         ####
#### param : xml file name                    ####
#### out : truth struct                          ####
############################
sub Load_From_INKML {
	my $fileName = @_[0];
	my $truth = &newTruthStruct();
	if ( not ((-e $fileName) && (-r $fileName) ))
	{
		warn ("[$fileName] : file not found or not readable !\n"); 
		return $truth;
	} 
	if(-z $fileName){
		warn ("[$fileName] : empty file !\n"); 
		return $truth;
	}
	my $doc  = $parser->parse_file($fileName);
	my $ink;
	unless(defined eval {$ink = $doc->documentElement()}){
		warn ("[$fileName] : no xml !\n"); 
		return $truth;
	}
	my $xc = XML::LibXML::XPathContext->new( $doc );
	$xc->registerNs('ns', 'http://www.w3.org/2003/InkML');
	#print STDERR Dumper($data); 
	my @xmlAnn = $xc->findnodes('/ns:ink/ns:annotationXML');
	if($#xmlAnn > -1){ # there are at least one xml annotation
		if($#xmlAnn > 0 and $warning){
			print STDERR $fileName.": several annotationXML ($#xmlAnn) in this file, last is kept\n";
		}
		
		#print STDERR "Ann XML : ".Dumper($xmlAnn[0]); 
		&Load_xml_truth($truth->{XML_GT}, $xmlAnn[$#xmlAnn]->firstNonBlankChild);
		#print STDERR "XML : ".Dumper($truth->{XML_GT}); 
	}
	my $seg;
	my @groups = $xc->findnodes('/ns:ink/ns:traceGroup');
	if($#groups > 0 and $warning){
			print STDERR "  !! ".$fileName.": several segmentations ($#groups traceGroup) in this file, last is kept\n";
		}
	$seg = $groups[$#groups];
	
	$truth->{UI} = $xc->findvalue("/ns:ink/ns:annotation[\@type='UI']");
	#print STDERR "  UI = ".$truth->{UI}."\n";
	#print STDERR "\n";
	#symbol ID, to distinguish different symbols with same label, if symbol without any annotationXML
	my $symbID = 0; 
	
	# Iterate over symbols; $symbID is index for current symbol,
	# following the reading order over segments
	# in the input InkML file
	foreach my $group ($xc->findnodes('ns:traceGroup',$seg)){
		my $lab;
		my $id = "AUTO_".$symbID;
		my $symbError = 0;

		$lab = ($group->getElementsByTagName('annotation')) [0]->textContent;
		if($lab eq "" and $warning){
			print STDERR " !! ".$fileName.": unused symbol (symbol $symbID)\n";
			$symbError = 1;
		}
		my @annXml = $group->getElementsByTagName('annotationXML');
		if($#annXml > -1){
			$id = $annXml[0]->getAttribute('href');
			if($#annXml > 0 and $warning){
				print STDERR $fileName.": multiple XML hrefs for symbol ($#annXml) - keeping first ($id)\n";
			}
			if($id eq "" ){
				#if($warning){
				#	print STDERR " !! ".$fileName.": missing symbol XML href for symbol $symbID\n";
				#}
				$id = "AUTO_".$symbID;
			}
		}
		#print STDERR $lab." : ";
		my @strList = (); #list of strokes in the symbol
		my $locError = 0;
		foreach my $stroke ($xc->findnodes('ns:traceView/@traceDataRef',$group)){
			#print STDERR $stroke->textContent." ";
			my $errorSeg = undef;
			if(defined $truth->{STRK}->{$stroke->textContent}){
				$symbError = 1;
				print STDERR " !! ".$fileName.": repeated/invalid segment (stroke '".$stroke->textContent."' reused) \n";

				$errorSeg =  $truth->{STRK}->{$stroke->textContent}->{id};
				$locError = 1;
			}
			$truth->{STRK}->{$stroke->textContent} = { id => $id, lab => $lab};
			if(defined $errorSeg){
				$truth->{STRK}->{$stroke->textContent}->{errorSeg} = $errorSeg;
			}
			push @strList, $stroke->textContent;
		}
		if ($locError) {
			print STDERR " !! ".$fileName.": reused strokes in symbol $symbID\n";
		}

		#foreach $e (@strList){print STDERR $e." ";}print STDERR "<<<<\n";
		if(@strList > 0){
			$truth->{SYMB}->{$id} = {lab => $lab, strokes =>[@strList]};

			# Report (clearly) which symbols have errors. (RZ)
			if ($symbError) {
				print STDERR " !! ".$fileName.": invalid symbol (symbol $symbID)\n";
			}

			#next symb
			$symbID++;
		}
	}
	$truth->{NBSYMB} = $symbID;
	#print STDERR Dumper($truth);
	return $truth;
}

#############################################
#### Load xml truth from raw data, fill the current xml truth struct	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#### param 2 :  reference to current xml XML::LibXML::Node     	####
#############################################
sub Load_xml_truth {
	my $truth = @_[0];
	my $data = @_[1];
	my $current = {};
	# init current node
	$current->{name} = $data->nodeName;
	$current->{sub} = [];
	$current->{id} = undef;
	push @{$truth}, $current;
	#look for id 
	foreach my $attr ($data->attributes){
		if($attr->nodeName eq 'xml:id'){
			$current->{id} = $attr->nodeValue;
		}
	}
	# look for label and children
	foreach my $subExp ($data->nonBlankChildNodes()){
		if($subExp->nodeType == XML::LibXML::XML_TEXT_NODE){
			#if( =~ /(\S*)/){# non white character
				$current->{lab} = $subExp->nodeValue;
			#}
		}else{
			&Load_xml_truth($current->{sub}, $subExp);
		}	
	}
}

#############################################
#### Use xml truth struct to check CROHME normalization rules	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#############################################
sub check_mathMLNorm {
	my %symbTags = ("mi",1, "mo",1, "mn", 1);
	my %subExpNames = ("mroot",2,"msqrt", 1,"msub",1,"msup",1, "mfrac",2, "msubsup",3,"munderover",3,"munder",2); 
	my $current = @_[0];
	foreach my $exp (@{$current}){
		#print STDERR "-$exp->{name}-:\n";
		#print STDERR $symbTags{"mi"};
		#print STDERR $subExpNames{"msup"};
		if($exp->{name} eq 'math'){
			#start
			my $nb = @{$exp->{sub}};
			if($nb > 1){ #to much children => merge remove the fisrt one and process others
				print(STDERR "math tag problem deteted : not 1 children, nb=".@{$exp->{sub}}."\n");
			}
		}elsif($exp->{name} eq 'mrow'){
			# rule 1 :  no more than 2 symbols in a mrow
			if(@{$exp->{sub}} != 2){
				print (STDERR "mrow problem detected : not 2 children, nb=".@{$exp->{sub}}."\n");
			}else{
			#rule 2 : use right recursive for mrow , so left child should NOT be mrow
				if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
					print (STDERR "mrow problem detected : left child is mrow\n");
					#print STDERR Dumper($exp);
				}
			}
		}elsif($symbTags{$exp->{name}} == 1){
			#no sub exp in symbols
			if(@{$exp->{sub}} != 0){
				print (STDERR $exp->{name}." problem detected : at least one child, nb=".@{$exp->{sub}}."\n");
			}
			# we need a label 
			if($exp->{lab} eq ""){
				print (STDERR $exp->{name}." problem detected : no label\n");
			}
		}elsif($subExpNames{$exp->{name}} == 1){#test basic spatial relations
			#no more than 2 children
			if(@{$exp->{sub}} > 2){
				print (STDERR $exp->{name}." problem detected : more than 2 children, nb=".@{$exp->{sub}}."\n");
			}elsif(@{$exp->{sub}} == 2 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
				# if 2 children with 1 mrow, the mrow should be on right
				print (STDERR $exp->{name}." problem detected : left child is mrow in a ".$exp->{name}."\n");
			}elsif(@{$exp->{sub}} == 1 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
				print (STDERR $exp->{name}." problem detected : if only one child it should not be a mrow\n");
			}elsif(@{$exp->{sub}} == 0){
				print (STDERR $exp->{name}." problem detected : no child !\n");
			}
		}elsif($subExpNames{$exp->{name}} > 1){
			# for special relations with multi sub exp, we should have the exact number of children
			if(@{$exp->{sub}} > $subExpNames{$exp->{name}}){
				print (STDERR $exp->{name}." problem detected : more than ".$subExpNames{$exp->{name}}." children, nb=".@{$exp->{sub}}."\n");
			}
		}else{
			# reject other tags
			print STDERR "unknown tag :". $exp->{name}."\n";
		}
		#recursivity : process sub exp
		foreach my $subExp ($exp->{sub}){
			&check_mathMLNorm($subExp);
		}
	}
}

########################################################
#### Normalization of xml truth struct to assume  CROHME normalization rules	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#######################################################
sub norm_mathMLNorm {
	my %symbTags = ("mi",1, "mo",1, "mn", 1);
	my %subExpNames = ("msub",1,"msup",1, "mfrac",2, "mroot",2, "msubsup",3,"munderover",3,"munder",2); 
	my $current = @_[0];
	my $redo = 0;
	my $redoFather = 0;
	my $redoFromChild = 0;
	do{
		$redoFromChild = 0;
		foreach my $exp (@{$current}){
			do{
				$redo = 0;
				#print "-$exp->{name}- :\n";
				#print $symbTags{"mi"};
				#print $subExpNames{"msup"};
				if($exp->{name} eq 'math'){
					#start : nothing to do
					#start : check if there is one child
					my $nb = @{$exp->{sub}};
					if($nb > 1){ #to much children => merge remove the fisrt one and process others
						#print("math tag problem deteted : not 1 children, nb=".@{$exp->{sub}}."\n");
						#print Dumper($exp->{sub});
						#print "create new node:\n";
						my $newRow = {};# init new  node
						$newRow->{name} = 'mrow';
						$newRow->{sub} = [];
						$newRow->{id} = undef;
						@{$newRow->{sub}} = @{$exp->{sub}};
						@{$exp->{sub}} = ();
						push @{$exp->{sub}}, $newRow;
						#print "new=".Dumper($exp->{sub})."\n";
						$redo = 1;
					}
				}elsif($exp->{name} eq 'mrow'){
					# rule 1 :  no more than 2 symbols in a mrow
					my $nb = @{$exp->{sub}};
					if($nb > 2){ #to much children => merge remove the fisrt one and process others
						#print("mrow problem detected : not 2 children, nb=".@{$exp->{sub}}."\n");
						#print Dumper($exp->{sub});
						#print "create new node:\n";
						my $newRow = {};# init new  node
						$newRow->{name} = 'mrow';
						$newRow->{sub} = [];
						$newRow->{id} = undef;
						@{$newRow->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
						pop @{$newRow->{sub}};#reduce size
						#print Dumper($newRow);
						@{$exp->{sub}} = @{$exp->{sub}}[0..0];
						push @{$exp->{sub}}, $newRow;
						#print "new=".Dumper($exp->{sub})."\n";
						$redo = 1;
					}elsif($nb == 1){ #not enought children => replace  the current mrow by its child
						#print "not enought children => replace  the current mrow by its child:\n";
						#print Dumper($exp);
						$exp->{name} = @{$exp->{sub}}[0]->{name};
						$exp->{id} = @{$exp->{sub}}[0]->{id};
						#if( (@{$exp->{sub}}[0]->{lab})){
							$exp->{lab} =@{$exp->{sub}}[0]->{lab};
						#}
						$exp->{sub} = @{$exp->{sub}}[0]->{sub};
						$redo = 1;
						
						#print "new=".Dumper($exp)."\n";
					}elsif($nb == 0){
						#print "no  child in mrow !\n";
					}else{
					#rule 2 : use right recursive for mrow , so left child should NOT be mrow
						
						if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
							#print("mrow problem detected : left child is mrow=> remove it and insert children in\n");
							#print Dumper($exp);
							my $children = @{$exp->{sub}}[0]->{sub};
							@{$exp->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
							pop @{$exp->{sub}};#reduce size
							push (@{$children},@{$exp->{sub}});
							@{$exp->{sub}} = @{$children};
							#print "new=".Dumper($exp)."\n";
							$redo = 1;
						}
					}
				}elsif($exp->{name} eq 'msqrt'){
					# rule 1 :  no more than 2 symbols in a mrow
					my $nb = @{$exp->{sub}};
					if($nb > 2){ #to much children => merge remove the fisrt one and process others
						#print("mrow problem detected : not 2 children, nb=".@{$exp->{sub}}."\n");
						#print Dumper($exp->{sub});
						#print "create new node:\n";
						my $newRow = {};# init new  node
						$newRow->{name} = 'mrow';
						$newRow->{sub} = [];
						$newRow->{id} = undef;
						@{$newRow->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
						pop @{$newRow->{sub}};#reduce size
						#print Dumper($newRow);
						@{$exp->{sub}} = @{$exp->{sub}}[0..0];
						push @{$exp->{sub}}, $newRow;
						#print "new=".Dumper($exp->{sub})."\n";
						$redo = 1;
					}elsif($nb == 2){
					#rule 2 : use right recursive for mrow , so left child should NOT be mrow
						if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
							#print("mrow problem detected : left child is mrow=> remove it and insert children in\n");
							#print Dumper($exp);
							my $children = @{$exp->{sub}}[0]->{sub};
							@{$exp->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
							pop @{$exp->{sub}};#reduce size
							push (@{$children},@{$exp->{sub}});
							@{$exp->{sub}} = @{$children};
							#print "new=".Dumper($exp)."\n";
							$redo = 1;
						}
					}elsif($nb == 1){
						if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
							#print("msqrt problem detected : only child is mrow=> remove it and insert children in\n");
							#print Dumper($exp);
							my $children = @{$exp->{sub}}[0]->{sub};
							@{$exp->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
							pop @{$exp->{sub}};#reduce size
							push (@{$children},@{$exp->{sub}});
							@{$exp->{sub}} = @{$children};
							#print "new=".Dumper($exp)."\n";
							$redo = 1;
						}
					}
				}elsif($symbTags{$exp->{name}} == 1){
					#nothing to normalise
				}elsif($subExpNames{$exp->{name}} == 1){#test basic spatial relations msup and msub
					#no more than 2 children
					if(@{$exp->{sub}} > 2){
						#print($exp->{name}." problem detected : more than 2 children, nb=".@{$exp->{sub}}."\n");
					}elsif(@{$exp->{sub}} == 2 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
						# if left child is 1 mrow, the mrow should be removed and the relation is put on the last child of the mrow
						#print($exp->{name}."NORM problem detected : left child is mrow in a ".$exp->{name}."\n");
						#print Dumper($exp);
						my $theChildren = @{$exp->{sub}}[0]->{sub};
						if(@{$theChildren} > 0){# we can to it
							#built a new msub/msup relation and put it at the end of the mrow
							my $newSR = {};# init new  node => the new SR
							$newSR->{name} = $exp->{name};
							$newSR->{sub} = [];
							$newSR->{id} = $exp->{id};
							push (@{$newSR->{sub}},@{$theChildren}[$#{$theChildren}]); # the base of SR
							push (@{$newSR->{sub}},@{$exp->{sub}}[1]); # the child
							$exp->{name} = 'mrow';
							$exp->{id} = undef;
							$exp->{sub} = @{$exp->{sub}}[0]->{sub};
							pop @{$exp->{sub}}; # remove the last element (old base of SR)
							push  (@{$exp->{sub}},$newSR);# and replace by the new one
							$redo = 1;
							$redoFather = 1;
							#print "Apres:". Dumper($exp);
						}
						
					}elsif(@{$exp->{sub}} == 1 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
						#print($exp->{name}." problem detected : if only one child it should not be a mrow\n");
						
					}elsif(@{$exp->{sub}} == 0){
						#print($exp->{name}." problem detected : no child !\n");
					}
				}elsif($subExpNames{$exp->{name}} > 1){
					# for special relations with multi sub exp, we should have the exact number of children
					if(@{$exp->{sub}} > $subExpNames{$exp->{name}}){
						#print($exp->{name}." problem detected : more than ".$subExpNames{$exp->{name}}." children, nb=".@{$exp->{sub}}."\n");
					}
				}else{
					# reject other tags
					print "unknown tag :". $exp->{name}."\n";
				}
				#print "redo($redo)\n";
			}while($redo);
			unless($redoFather){
			#recursivity : process sub exp 
				foreach my $subExp ($exp->{sub}){
					$redoFromChild |= &norm_mathMLNorm($subExp);
				}
			}
			#print "redoFromChild($redoFromChild)\n";
		}
	}while($redoFromChild);
	#print "redoFather($redoFather)\n";
	return $redoFather;
}

########################################################
#### Look for a symbol in MathML GT with its ID 			####
#### param 1 :  reference to current xml truth struct (ARRAY)  		####
#### parma 2 ; id of the searched symbol			####
#### return ref to the symbol or undef			####
#######################################################

sub getMathMLSymbFromId {
	my $current = @_[0];
	my $id = @_[1];
	my $found = undef;
	foreach my $exp (@{$current}){
		if($exp->{id} eq $id){
			$found = $exp;
		}else{
			$found = &getMathMLSymbFromId($exp->{sub},$id);
		}
	}
	return $found;
}

########################################################
#### Print BG info : nodes labels and edges labels	####
#### param 1 :  reference to expression 	####
#######################################################
sub printBG {
	my $gdTruth = @_[0];
	my $output = @_[1];
	my $strk; my $tr; my $lab;
	print $output "# IUD, ".$gdTruth->{UI}."\n";
	print $output "# Nodes:\n";
	foreach $strk (sort {$a <=> $b} keys (%{$gdTruth->{STRK}})){
		$lab = (%{$gdTruth->{STRK}})->{$strk}->{lab};
		#print "STRK = $strk \n";
		if($lab eq ""){
			if((%{$gdTruth->{STRK}})->{$strk}->{id} eq ""){
				# THIS ERROR MESSAGE HANDLED AT BOTTOM OF FUNCTION: identifies missing
				# symbol.
				#print STDERR " !! Failure to create empty label for unknown stroke id ".(%{$gdTruth->{STRK}})->{$strk}->{id};
				#print STDERR "\n";
				#Fail to restore an empty label in symbol because of empty id \n";
			}else{
				my $subexp = &getMathMLSymbFromId($gdTruth->{XML_GT}, (%{$gdTruth->{STRK}})->{$strk}->{id});
				if(defined $subexp){
					#print " => defined \n".Dumper((%{$gdTruth->{STRK}})->{$strk});

					print STDERR " !! Inserting empty label for for stroke id  ".(%{$gdTruth->{STRK}})->{$strk}->{id}."\n";
					$lab = %{$subexp}->{lab};
				}else{
					# ERROR MESSAGE PROVIDED AT BOTTOM OF FUNCTION (id's symbol
					# segment that is defined, but unreferenced in the layout tree)
					#print STDERR " !! Failure to create empty stroke label because of missing symbol id ".(%{$gdTruth->{STRK}})->{$strk}->{id}." \n";
				}
			}
			if($lab eq ""){
				$lab = "_";
			}
		}
		
		$lab =~ s/,/COMMA/;
		print $output "N, $strk, $lab, 1.0\n";
		#print Dumper((%{$gdTruth->{STRK}})->{$strk});
		# we can generate an error detection here :
		#if(defined ((%{$gdTruth->{STRK}})->{$strk}->{errorSeg}) ){
			#print $output "N, $strk, ERRORSEG, 1.0\n";
		#}
	}
	print $output "\n# Edges:\n";
	my @outlist = ();

	my %SegSRT ;
	&getSegSRT($gdTruth->{XML_GT}, \%SegSRT);
	#print Dumper($gdTruth->{XML_GT});
	my ($id1,$id2);
	my %usedSymb;
	foreach my $segId (sort keys %SegSRT){
		#print $segId." => ".(%SegSRT->{$segId})."\n";
		if($segId =~ /\[(.*)\],\[(.*)\]/){
			$id1 = $1;
			$id2 = $2;
			
			if((defined $id1) and $id1 ne "" and (defined $id2) and $id2 ne "" ){
				if(defined $gdTruth->{SYMB}->{$id1}){
					$usedSymb{$id1} = 1;
					foreach my $strId1 (sort {$a <=> $b} @{$gdTruth->{SYMB}->{$id1}->{strokes}}){
						if(defined $gdTruth->{SYMB}->{$id2}){

							$usedSymb{$id2} = 1;
							foreach my $strId2 (sort {$a <=> $b} @{$gdTruth->{SYMB}->{$id2}->{strokes}}){
								# NOTE: self-edges will be reproduced as defined.
								push @outlist, ("E, $strId1, $strId2, ". (%SegSRT->{$segId}).", 1.0\n");
							}
						}
					}
				}
			} else {
				print STDERR " !! Skipping empty segment relationship for: $segId; see ".$gdTruth->{UI}."\n";
			}
		}
	}


	# RZ: Adding segmentation edges.
	# FILTER symbols not included in the SRT. 
	for my $nextSymbol (keys (%{$gdTruth->{SYMB}})) {
		if ($usedSymb{$nextSymbol}) { 
			#print $nextSymbol . "\n";
			for my $stroke (@{$gdTruth->{SYMB}->{$nextSymbol}->{strokes}}) {
				#print "STROKE1: " . $stroke . "\n";
				for my $stroke2 (@{$gdTruth->{SYMB}->{$nextSymbol}->{strokes}}) {
					#print "  STROKE2: " . $stroke2 . "\n";
					if ($stroke != $stroke2) {
						# Use extra 0's to mark generated edges.
						push @outlist, ("E, $stroke, $stroke2, *, 1.000\n");
					}
				}
			}
		}
	}
	my ($aid1,$aid2,$bid1,$bid2);
	foreach my $l (sort {((split (/,/, $a)) [1]) <=> ((split (/,/, $b)) [1]) ||((split (/,/, $a)) [2]) <=> ((split (/,/, $b)) [2]) || $a <=> $b} @outlist){ #($a =~ /, (\d+)/)[0] <=> ($b =~ /, (\d+)/)[0] 
		print $output $l;
	}
	if(keys(%{$gdTruth->{SYMB}}) != keys(%usedSymb)){
		print $output "# !! Unused symbols; defined but not in layout tree\n";
		 foreach my $missSymb (keys (%{$gdTruth->{SYMB}})){
			 unless($usedSymb{$missSymb}){
				print $output "# !! Unused symbol : ". ($missSymb)."\n";
				#print STDERR " !! Unused symbol : ". ($missSymb)."\n";
				 # foreach my $str1 (@{(%{$gdTruth->{SYMB}})->{$missSymb}->{strokes}}){
					 # foreach my $str2 (@{(%{$gdTruth->{SYMB}})->{$missSymb}->{strokes}}){
						# if($str1 ne $str2){
							# print $output "E, $str1, $str2, SEG_$missSymb,1.0\n";
						# }
					# }
				 # }
			  }
		
		}
	}
}


########################################################
#### build recursively the SRT with segmentation id from MathML		####
#### param 1 :  current MathML Graph (ARRAY) 			####
#### param 2 :  current SRT (HASH)			####
#### return list of all children id, the first one being the main stroke holding the spatial relation ####
#######################################################
sub getSegSRT {
	my $current = @_[0];
	my $SRT = @_[1];
	my $from,my $to;
	my @children;
	#print "SRT=$SRT\n";
	foreach my $exp (@{$current}){
		# deep first to set children and main symbole in sub exp
		my @currentChildren = &getSegSRT($exp->{sub}, $SRT);
		#set up children
		push @children,@currentChildren;
		if(defined $exp->{id}){
			push @children,$exp->{id};
		}
		$exp->{children} = \@currentChildren;
		# set up the main symb ID
		if(defined $tagMainSymb{$exp->{name}}){
			if( $tagMainSymb{$exp->{name}} == -1){
				#print "$exp->{name} $exp->{id} : self\n";
				$exp->{mainSymbId} = $exp->{id};
			}else{
				$exp->{mainSymbId} = $exp->{sub}[$tagMainSymb{$exp->{name}}]->{mainSymbId};
			}
			if((not defined $exp->{mainSymbId}) or $exp->{mainSymbId} eq ""){
				print STDERR " !! $exp->{name} $exp->{id} tag is missing symbol ID $exp->{mainSymbId}\n";
				#print STDERR Dumper($exp);
			}
		
		}else{
			unless ($exp->{name} eq "math"){
				print STDERR " !! $exp->{name} not in symbol ID list\n";
			}
		}
		# add the link depending of tag name
		if(defined $tagToSRT{$exp->{name}}){
			foreach  my $list ($tagToSRT{$exp->{name}}){
				foreach my $link (@$list){
					#print $exp->{name}."(".$exp->{id}.") ".@{$link}[0]." --> ".@{$link}[1]."=".@{$link}[2]."\n";
					my @ids1;
					if( @{$link}[0] == -1){
						push @ids1 , $exp->{mainSymbId};
					}else{
						push @ids1 ,  $exp->{sub}[@{$link}[0]]->{mainSymbId};
						#push @ids1 , @{$exp->{sub}[@{$link}[0]]->{children}};
					}
					#print "	from [@ids1]\n";
					if(@{$link}[1] <= @{$exp->{sub}}){
						foreach my $id1 (@ids1){
							if(defined $exp->{sub}[@{$link}[1]]->{id}){ # link to the symbol if any
								$SRT->{"[$id1],[".($exp->{sub}[@{$link}[1]]->{id})."]"}=@{$link}[2];
							}


							foreach my $id2 (@{$exp->{sub}[@{$link}[1]]->{children}}){ # link to the children
								$SRT->{"[$id1],[$id2]"}=@{$link}[2];
							}
						}
					}
				}
			}
		}
		
	}
	return @children;
	#print "children : @children";
	
}





