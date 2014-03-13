package SomethingAwful::Forums;
use Moose;
use namespace::autoclean;
use Method::Signatures;
use URI;
use LWP::Protocol::AnyEvent::http;
use WWW::Mechanize;
use Coro qw( async );
require SomethingAwful::Forums::Scraper::Index;
require SomethingAwful::Forums::Scraper::Forum;
require SomethingAwful::Forums::Scraper::Thread;

has 'index_scraper' => ( 
    isa     => 'Web::Scraper::LibXML', 
    is      => 'ro',
    default => sub { SomethingAwful::Forums::Scraper::Index->new; },
);

has 'forum_scraper' => ( 
    isa     => 'Web::Scraper::LibXML', 
    is      => 'ro',
    default => sub{ SomethingAwful::Forums::Scraper::Forum->new; },
);

has 'thread_scraper' => ( 
    isa     => 'Web::Scraper::LibXML', 
    is      => 'ro',
    default => sub { SomethingAwful::Forums::Scraper::Thread->new; },
);

has 'base_url' => ( 
    isa     => 'Str', 
    is      => 'rw', 
    default => 'http://forums.somethingawful.com/' 
);

has 'mech'     => ( 
    isa     => 'WWW::Mechanize', 
    is      => 'ro', 
    default => sub { 
        return WWW::Mechanize->new( 
            agent     => 'Mozilla/5.0 (Windows; U; Windows NT 6.1; nl; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13',
            autocheck => 1,
        );
    },
);


method login(Str :$username!, Str :$password!) {
    $self->mech->get( URI->new_abs( 'account.php?action=loginform', $self->base_url ) );

    $self->mech->submit_form(
        with_fields => {
            username => $username,
            password => $password,
        },
    );

    # check to see if login was a success
}


method fetch_forums {
    my $res = $self->mech->get( $self->base_url );
    return $self->index_scraper->scrape( $res->decoded_content, $self->base_url );
}

# Possibly allow Int|URI $forum, and if it is URI then use that instead of assuming the url
# see: Method-Signatures and MooseX::Method::Signatures 
method fetch_threads(Int :$forum_id!) {
    my $res = $self->mech->get( URI->new_abs( "/forumdisplay.php?forumid=$forum_id", $self->base_url ) );
    return $self->forum_scraper->scrape( $res->decoded_content, $self->base_url );
}

method fetch_posts(Int :$thread_id!, Int|ArrayRef[Int] :$pages , Int :$per_page = 40) {
    my @pages = ($pages);
    push @pages, ref $pages ? @$pages : $pages;

    my $sem = new Coro::Semaphore 3; # process 3 pages max at a time
    my @cs;
    my @unsorted_results;
    foreach my $page ( @pages ) {
        $sem->down;

        my $c = async {
            my $uri = URI->new_abs( "/showthread.php?threadid=$thread_id&pagenumber=$page&perpage=$per_page", $self->base_url );
            my $res = $self->mech->get( $uri );

            warn "Thread fetch failed! thread_id: $thread_id page: $page" if !$self->mech->success;
            my $scraped = $self->thread_scraper->scrape( $res->decoded_content, $self->base_url );

            push( @unsorted_results, $scraped );
        };

        $sem->up;
        push(@cs, $c);
    }
    $_->join for (@cs);


    my @sorted_results = sort { $a->{page_info}->{current} <=> $b->{page_info}->{current} } @unsorted_results;
    return \@sorted_results;
}


__PACKAGE__->meta->make_immutable;
1;


__END__