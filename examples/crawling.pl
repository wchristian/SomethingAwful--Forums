use v5.10;
use strict;
use warnings;
use URI;
use Getopt::Long::Descriptive;
use lib '../lib';
use SomethingAwful::Forums;

# Example of how to scrape the forum's index, navigate to and scrape the first forum, then navigate
# to and scrape the first thread while finally outputting the first post of this thread.
# Remember login credentials are often required to view many forums/threads, but not always.

my ($opt, $usage) = describe_options(
  "$0 %o",
    [ 'username|u=s',   'your username maybe?', ],
    [ 'password|p:s',   'hmmmmm',               ],
    [ 'url:s',          'Forum index URL', { default => 'http://forums.somethingawful.com' } ],
    [],
    [ 'help', 'print usage message and exit'    ],
);
if( $opt->help ) {
    say $usage->text; 
    exit; 
}

my $SA = SomethingAwful::Forums->new;

###########################################################################################

say 'Starting...';
if(defined $opt->username && defined $opt->password) {
    $SA->('username' => $opt->username);
    $SA->('password' => $opt->password);
}
else {
    say 'No login credentials supplied. Not logging in.'
}

say $SA->base_url;
my $scraped_index = $SA->fetch_forums;

if( exists $scraped_index->{logged_in_as_username} ) {
    say "Logged in as: " . $scraped_index->{logged_in_as_username} if exists $scraped_index->{logged_in_as_username};

    if( exists $scraped_index->{pm_info} ) {
        say "Messages: ";
        say "\ttotal["  . $scraped_index->{pm_info}->{total}  . "]" if $scraped_index->{pm_info}->{total};
        say "\tunread[" . $scraped_index->{pm_info}->{unread} . "]" if $scraped_index->{pm_info}->{unread};
        say "\tnew["    . $scraped_index->{pm_info}->{new}    . "]" if $scraped_index->{pm_info}->{new}; 
    }
}


# Do some processing on the data (gather forum data & process the first forums first page of threads)
foreach my $forum ( @{$scraped_index->{forums}} ) {
    use Data::Dumper;
    say Dumper($forum);
    last;
}


1;


__END__
