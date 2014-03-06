#! /usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Parallel::ForkManager;
use LWP::UserAgent;
use Time::HiRes qw(sleep gettimeofday);

usage() if (@ARGV == 0);

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
warn "wait for $wait second between requests\n" if ($wait);

my $ua = LWP::UserAgent->new(
    ssl_opts => { verify_hostname => 0 },
);
my $transfer = 0;
my $pm = Parallel::ForkManager->new($concurrency);
$pm->run_on_finish(
    sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $dataref) = @_;
        if (defined $dataref) {
            $transfer += $$dataref;
        }
    }
);

my ($startsec, $startmicro) = gettimeofday();
for (my $child = 0; $child < $concurrency; $child++) {
    use bytes;
    if ($pm->start) {
        # parent
        warn "forks $child/$concurrency child ...\n";
    }
    else {
        # child
        my $transfer = 0;
        for (my $i = 0; $i < $loops; $i++) {
            print STDERR "processing $i/$loops loop\r";
            foreach my $url (@urls) {
                my $res = $ua->get($url);
                if ($res->is_success) {
                    $transfer += length($res->content);
                }
                else {
                    print STDERR "\nfail: $url";
                }
                sleep($wait);
            }
        }
        $pm->finish(0, \$transfer);
    }
}
$pm->wait_all_children;
my ($endsec, $endmicro) = gettimeofday();
my $elapsed = ($endsec - $startsec) + ($endmicro - $startmicro) / 10**6;
my $bytepersec = $transfer / $elapsed;

my @units = qw( B/s KiB/s MiB/s GiB/s );
my $unit = 0;
while ($bytepersec > 1024) {
    $bytepersec /= 1024;
    $unit++;
}
$bytepersec = sprintf("%.4g", $bytepersec);

warn "\n ...done.\n";
warn "get $transfer bytes in $elapsed seconds ($bytepersec $units[$unit])\n";

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
