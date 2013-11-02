#! /usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Getopt::Long;
use Parallel::ForkManager;
use LWP::Simple;
use Time::HiRes qw(sleep);

GetOptions(
    'h|help'            => \ my $help,
    'i|inputfile=s'     => \ my $file,
    'c|concurrency=i'   => \ my $concurrency,
    'n|loops=i'         => \ my $loops,
    'w|wait=f'          => \ my $wait,
) or usage();

usage() if $help;

$concurrency ||= 1;
$loops ||= 1;
$wait ||= 0;

my @urls = file2urls($file) if ($file);
push @urls, @ARGV;

my $num = scalar @urls;
warn "$num urls with $concurrency clients, $loops loops\n";
warn "Total: ", $num * $concurrency * $loops, " requests\n";
warn "wait for $wait second between requests\n";



my $pm = Parallel::ForkManager->new($concurrency);
for (my $child = 0; $child < $concurrency; $child++) {
    if ($pm->start) {
        warn "forks $child/$concurrency child ...\n";
        next;
    }
        for (my $i = 0; $i < $loops; $i++) {
            print STDERR "processing $i/$loops loop\r";
            foreach my $url (@urls) {
                get($url) or warn "fail: $url\n";
                sleep($wait);
            }
        }
    $pm->finish;
}
$pm->wait_all_children;

warn "\n ...done.\n";


sub usage {
    warn "$0 -i urls.txt -c concurrency -n loops -w wait_interval\n",
         " OR...\n",
         "$0 url1 url2\n"
    ;
    
    exit;
}

sub file2urls {
    my $file = shift;
    
    open my $fh, '<', $file or die "$file: $!";
    
    my(@urls, $url);
    while ($url = <$fh>) {
        chomp $url;
        push @urls, $url;
    }
    
    return @urls;
}
