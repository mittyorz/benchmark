#! /usr/bin/perl -w

use strict;
use warnings;

use Net::DNS;

my $hostlist = shift @ARGV || die "usage: $0 list_of_hosts [nameserver]";
if (! -r $hostlist) {
    die "$0: cannot read $hostlist";
}
my $nameserver = shift @ARGV;

my $res;
if ($nameserver) {
    warn "$0: performing DNS query with server($nameserver)";
    $res = Net::DNS::Resolver->new(
        nameservers => [$nameserver],
    );
}
else {
    warn "$0: use system default nameservers";
    $res = Net::DNS::Resolver->new;
}


open LIST, "<$hostlist";
while (my $host = <LIST>) {
    chomp $host;
    my $query = $res->send($host);
    if ($query) {
        print "$host -> ";
        if ($res->errorstring ne 'NOERROR') {
            print $res->errorstring, "\n";
            next;
        }
        foreach my $rr ($query->answer) {
            if ($rr->type eq 'A') {
                print $rr->address, " ";
            }
            elsif ($rr->type eq 'PTR') {
                print $rr->ptrdname, " ";
            }
        }
        print "\n";
    }
    else {
        warn "$0: query failed: ", $res->errorstring, "\n";
    }
}
