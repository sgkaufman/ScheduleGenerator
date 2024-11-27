#!/usr/bin/perl
use v5.36;
use experimental 'signatures';

#open(my $scheduleIn,  "<", "SingleMeeting4.csv")
open( my $scheduleIn,  "<", "SocorroMeetingSchedule.csv" )
    or die "Can't open input file: $!";
open( my $laTeX_output, ">", "LaTeX_Socorro.txt" )
    or die "Can't open output file $!\n";

my $verbose = 0;

my @day_list = ( "Sunday", "Monday", "Tuesday", "Wednesday",
		 "Thursday", "Friday", "Saturday" );

my $meeting;

my %meeting_keys = (
    0 => "time",
    2 => "day",
    3 => "name",
    4 => "location",
    5 => "address",
    6 => "city",
    8 => "types"
    );
# Remaining fields:
# "notes", "loc_notes", "",
# "group", "district", "", "website", "", "mail_address"];
# Venmo,Square,Paypal,Email,Phone,Group Notes,
# Contact 1 Name,Contact 1 Email,Contact 1 Phone,
# Contact 2 Name,Contact 2 Email,Contact 2 Phone,
# Contact 3 Name,Contact 3 Email,Contact 3 Phone,
# Last Contact,Conference URL,Conference URL Notes,
# Conference Phone,Conference Phone Notes,Author,Slug,
# Data Source,Data Source Name,Updated,ID];
 
# The %day_hash has a list of each meeting occuring on that day.
# Each list contains references to lists for the fields of interest
# for the schedule.

my %day_hash = (
    Sunday    => [],
    Monday    => [],
    Tuesday   => [],
    Wednesday => [],
    Thursday  => [],
    Friday    => [],
    Saturday  => []
    );

# Loop over each line, each of which corresponds to a meeting

while ($meeting = <$scheduleIn>) {
    my @meeting_keys = ("time", "day", "name", "location", "address", "city", "types");
    my $remainder;
    my $next = "";

    my @pair_list = ();

    $remainder = "";

    # The first three fields aren't quoted. Peel those off and save the rest.
    # Then break up the rest with double-quote pairs or empty fields,
    # separated by commas.
    chomp $meeting;

    # Blank line?
    next if ($meeting =~ /^$/);

    # Strip off the first three fields
    if ( $meeting =~ /(\d+:\d+ [AP]M),([^,]*),([^,]*),(.*)/) {
	push (@pair_list, ["time", $1]);
	push (@pair_list, ["day", $3]);
	print "Start Time: $1\nEnd Time: $2\nDay: $3 \n" if $verbose;
    
	$remainder = $4;
	
	# from Style Guide: 'print "Starting analysis\n" if $verbose;'
	print "Remainder of meeting is $remainder\n\n" if $verbose;
    }
    else {
	print "Meeting with wrong format!\n" . $meeting . "\n\n";
	next;
    }

    my $field_cnt = 3;

    # On to remainder!
    # Assertions: The time, end time, and day fields have been removed
    # from $remainder, along with the commas ending those fields.
    while ($remainder and $field_cnt < 50) {

	if (substr($remainder,0,3) eq '"",') {
	    # eat up empty quoted field and field-ending comma
	    $remainder = substr($remainder, 3);
	    print "First branch.  Field $field_cnt: blank\n" if $verbose;

	} elsif (substr($remainder,0,1) eq "," ) {
	    # eat up a comma
	    $remainder = substr($remainder,1);
	    # print "$remainder\n";
	    print "Second branch. Field $field_cnt: blank\n" if $verbose;;

	} elsif ($remainder =~ /^"(\d\d\d\d)"$/ ) {
	    # Meeting ID at end-of-line, quoted
	    $next = $1;
	    $remainder = "";
	    print "Third branch. Field $field_cnt: $next\n" if $verbose;

	} elsif ($remainder =~ /^"([^"]+)",(.+)/) {
	    # Not an empty field, so collect full field without quotes.
	    $next = $1;
	    $remainder = $2;
	    print "Fourth (quoted field) branch. Field $field_cnt: $next\n"
		if $verbose;
      	} elsif ($remainder =~ /^([^,]+),(.+)/) {
	    # Not an empty field, no quotes, so collect full field.
	    $next = $1;
	    $remainder = $2;
	    print "Fifth (unquoted field) branch. Field $field_cnt: $next\n"
		if $verbose;
	}
	elsif ($remainder =~ /^(\d\d\d\d)$/) {
	    # Meeting ID at end-of-line, unquoted
	    $next = $1;
	    $remainder = "";
	    print "Sixth branch. Unquoted meeting ID. Field $field_cnt: $next\n"
		if $verbose;

	} else {
	    # Trouble!
	    printf "Dread Seventh Branch. remainder: $remainder\n" if $verbose;
	    printf "field_cnt: $field_cnt\n" if $verbose;
	}
	# print "Contents of hash at $field_cnt: $meeting_keys{$field_cnt}\n";
	
	if (defined($meeting_keys{$field_cnt}) ) {
	    push (@pair_list, [$meeting_keys{$field_cnt}, $next]);
	}
	  
	$field_cnt++;
    }
    
    # end of meeting processing. Results are in @pair_list.
    # Create the hash of meeting elements from @pair_list.
    my $href = {};       # the hash 
    my $day_name;        # meeting day (e.g., 'Sunday')
    my $list_ref;        # reference to the list in %day_hash for the day
   
    # Create the hash
    for my $i ( 0 .. $#pair_list ) {
	${$href}{$pair_list[$i][0]} = $pair_list[$i][1];
    }

    # Push the hash onto the end of the list for that day
    $day_name = ${$href}{day};
    $list_ref = $day_hash{$day_name};
    push @{$list_ref}, $href;    
}

close ($scheduleIn);

# Finished reading the file. Meeting hashes are in %day_hash.
# First handle the location and code translations, then
# 1. Place an asterisk before hybrid meetings
# 2. Not which meeting are online only, and do not print for LaTeX.


for my $day ( @day_list ) {

    my $uc_day = uc( $day );
    print "--------------- beginning of $day meetings ---------------\n";
    print $laTeX_output "\\hline\\multicolumn{3}{|l|}{\\cellcolor[HTML]{EFEFEF}\\textbf{ $uc_day }} \\\\ \\hline\n";

    my $list_ref = $day_hash{$day};
    for my $i ( 0 .. $#{$list_ref} ) { # for each meeting hash
	# Handle the location code
	my $online_flg = 0;
	my $loc = ${$list_ref}[$i]{location};
	${$list_ref}[$i]{location} = translate_loc( $loc );
	if ( length( ${$list_ref}[$i]{location} ) == 0) {
	    $online_flg = 1;
	}

	# Handle the meeting type codes
	my $type = ${$list_ref}[$i]{types};
	my $codes = translate_types( $type );
	${$list_ref}[$i]{types} = $codes;
	if ( $codes =~ /OM/ ) {
	    my $name = ${$list_ref}[$i]{name};
	    ${$list_ref}[$i]{name} = "*" . $name;
	}

	# now print the modified meeting hash
	print "Meeting $i:\n";
	for my $key ( keys ${$list_ref}[$i]->%* ) {
	    print "$key => ${$list_ref}[$i]{$key}\n";
	}
	print "Online Only Meeting? : $online_flg\n";
	print "--------------------------------\n";
	
	my $m_name = ${$list_ref}[$i]{name};
	my $am_pm = lc( ${$list_ref}[$i]{time} );
	my $types = ${$list_ref}[$i]{types};
	$types =~ s/, $//;
	$types =~ s/\s//g;
	if ($types =~ "Albuquerque") {
	    print "TYPE IS ALBUQUERQUE\n";
	}

	my $loc_code = ${$list_ref}[$i]{location};
	# Print to LaTeX file if meeeting is not online-only
	if ( $online_flg == 0 ) {
	    print $laTeX_output "$am_pm	& $m_name \\textbf{\\textsc{$types}} & \\textsc{$loc_code} \\\\ \\hline\n";
	}
    }
    print "--------------- end of $day meetings ---------------\n";
}

close ($laTeX_output);

   
# \hline\multicolumn{3}{|l|}{\cellcolor[HTML]{EFEFEF}\textbf{SUNDAY}}   \\\hline

# \hline \multicolumn{3}{|l|}{\cellcolor[HTML]{EFEFEF}\textbf{SUNDAY}} \\ \hline

sub translate_loc($loc_name) {
    $loc_name =~ s/Online-Albuquerque//;
    $loc_name =~ s/Albuquerque Indian Center/aic/;
    $loc_name =~ s/Asbury Methodist Church/aum/;
    $loc_name =~ s/AsburyUnited Methodist Church/aum/;
    $loc_name =~ s/Albuquerque Central Office/aco/;
    $loc_name =~ s/Brownbaggers Group/bbg/;
    $loc_name =~ s/1656 Bridge Blvd. SW/bri/;
    $loc_name =~ s/2300 Candelaria NE/cad/;
    $loc_name =~ s/Church of the Risen Savior/crs/;
    $loc_name =~ s/Covenant United Methodist Church/cum/;
    $loc_name =~ s/Desert Club/des/;
    $loc_name =~ s/Domenici Center/dom/;
    $loc_name =~ s/Endorphin Power Company/epc/;
    $loc_name =~ s/First Congregational Church/fcc/;
    $loc_name =~ s/Faith Lutheran Church/flc/;
    $loc_name =~ s/First Nations Healthcare/fnh/;
    $loc_name =~ s/First Presbyterian Church/fpc/;
    $loc_name =~ s/Fiesta\'s Restaurant/fie/;
    $loc_name =~ s/Foothills Group/fth/;
    $loc_name =~ s/2715 4th Street NW/fou/;
    $loc_name =~ s/Grace United Methodist Church/gum/;
    $loc_name =~ s/Groupo El Perdon AA/gep/;
    $loc_name =~ s/Hope in the Desert Episcopal Church/hde/;
    $loc_name =~ s/Heights Club/hts/;
    $loc_name =~ s/Immanuel Presbyterian Church/ipc/;
    $loc_name =~ s/Isleta Club/isl/;
    $loc_name =~ s/Mesa View Methodist Church/mvu/;
    $loc_name =~ s/Metropolitan Community Church/mcc/;
    $loc_name =~ s/Monte Vista Christian Church/mvc/;
    $loc_name =~ s/Nativity Church/nat/;
    $loc_name =~ s/Netherwood Park Church of Christ/npc/;
    $loc_name =~ s/Our Lady of the Valley Church/olv/;
    $loc_name =~ s/Our Savior Lutheran Church/osl/;
    $loc_name =~ s/Paws and Stripes/pas/;
    $loc_name =~ s/Plaza West, Suite F/pwf/;
    $loc_name =~ s/Rio Vista Church of the Nazarene/rcn/;
    $loc_name =~ s/St Andrew Presbyterian Church/sap/;
    $loc_name =~ s/St Michael & All Angels Episcopal Church/sma/;
    $loc_name =~ s/St Marks Episcopal/smc/;
    $loc_name =~ s/St. Mark's Episcopal Church/smc/;
    $loc_name =~ s/St Mary's Episcopal Church/sme/;
    $loc_name =~ s/208 San Pedro/snp/;
    $loc_name =~ s/St Johns Episcopal Cathedral/stj/;
    $loc_name =~ s/St Timothy's Lutheran Church/stl/;
    $loc_name =~ s/St Thomas of Canterbury/stc/;
    $loc_name =~ s/VA Campus/vac/;

    # Rio Rancho location codes
    $loc_name =~ s/Anchor Point Church/apc/;
    $loc_name =~ s/Community of Joy Church/cjc/;
    $loc_name =~ s/The Mesa Club/mcl/;
    $loc_name =~ s/Rio Rancho Presbyterian Church/rrp/;
    $loc_name =~ s/Rio Rancho United Methodist Church/rrm/;
    $loc_name =~ s/St Francis Episcopal Church/sfe/;

    # Outside Albuquerque codes

    $loc_name =~ s/Community Bible Church/cbc/;
    $loc_name =~ s/Corrales Community Center/ccc/;
    $loc_name =~ s/Community Church/cch/;
    $loc_name =~ s/Corrales Community Library/ccl/;
    $loc_name =~ s/Christian Fellowship Church Gym/cfc/;
    $loc_name =~ s/Epiphany Episcopal Church/eec/;
    $loc_name =~ s/Full Circle Recovery/fcr/;            
    $loc_name =~ s/Holy Child Catholic Church/hct/;
    $loc_name =~ s/Holy Cross Episcopal Church/hce/;
    $loc_name =~ s/First United Methodist Church of Belen/mcb/;
    $loc_name =~ s/Good Shepherd Lutheran Church/gsl/;
    $loc_name =~ s/Mountainside Methodist Church/msm/;
    $loc_name =~ s/Presbyterian Church, Placitas/ppc/;
    $loc_name =~ s/St Matthew's Episcopal Church/mec/;
    $loc_name =~ s/The shopping center south of El Camino restaurant/sel/;
    $loc_name =~ s/United Methodist Church/umb/; # of Bernalillo
    $loc_name =~ s/Unitarian Universalist Church/uuc/;
    $loc_name =~ s/Wellness Center/wcl/;
    $loc_name =~ s/Woods End Church/wec/;

    
    return $loc_name;
}

sub translate_types($types) {
    $types =~ s/11th Step Meditation/ME/;
    $types =~ s/12 Steps & 12 Traditions/ST, T/;
    $types =~ s/As Bill Sees It/A/;
    $types =~ s/Big Book/BB/;
    $types =~ s/Birthday/B/;
    $types =~ s/Breakfast/BF/;
    $types =~ s/Candlelight/CL/;
    $types =~ s/Closed/C/;
    $types =~ s/Concurrent with Al-Anon/AL/;
    $types =~ s/Daily Reflections/DR/;
    $types =~ s/Digital Basket/DB/;
    $types =~ s/Discussion/D/;
    $types =~ s/Dual Diagnosis/DD/;
    $types =~ s/English/E/;
    $types =~ s/Fragrance Free/FF/;	
    $types =~ s/Gay/G/;
    $types =~ s/Grapevine/GV/;
    $types =~ s/Lesbian/L/;
    $types =~ s/Literature/LI/;
    $types =~ s/Living Sober/LS/;
    $types =~ s/LGBTQ/LGBTQ/;
    $types =~ s/Location Temporarily Closed,//;
    $types =~ s/Location Temporarily Closed//;
    $types =~ s/Location Temporarily C,//;
    $types =~ s/Location Temporarily C//;
    $types =~ s/Meditation/ME/;
    $types =~ s/Men/M/;
    $types =~ s/Native American/NA/;
    $types =~ s/Newcomer/N/;
    #$types =~ s/Online Meeting,/OM/;
    $types =~ s/Online Meeting/OM/;
    $types =~ s/Open/O/;
    $types =~ s/Outdoor Meeting/OD/;
    $types =~ s/Secular/SC/;
    $types =~ s/Sign Language/SL/;
    $types =~ s/Spanish/S/;
    $types =~ s/Speaker/SP/;
    $types =~ s/Step Meeting/ST/;
    $types =~ s/Tradition Study/T/;
    $types =~ s/Transgender/TR/;
    $types =~ s/Wheelchair Access/WA/;
    $types =~ s/Wheelchair-Accessible Bathroom/WB/;
    $types =~ s/Women/W/;
    $types =~ s/Young People/Y/;

    # Clean up spaces (only in type field)
    $types =~ s/\s//g;

    return ($types);
}

# 34 meetings on Sunday including online-only
