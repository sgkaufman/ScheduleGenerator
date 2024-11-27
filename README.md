# ScheduleGenerator
The program schedule.pl is a Perl program that reads a csv file from the Twelve Step Meeting List.
The input csv file is hard-coded at line 6. An output file name is hard-coded at line 8.
The output file is a fragment of the LaTeX file that creates the Albuquerque-area printed schedule.
It is run when something like this commmand line is typed: 
`/usr/bin/env perl Schedule.pl > SocorroScheduleOut.txt`

The output file created by the output redirection in the above example command line
is a printout of the data structure that hold the meeting data.
