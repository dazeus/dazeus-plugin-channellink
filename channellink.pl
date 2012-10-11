#!/usr/bin/perl
use strict;
use warnings;

use DaZeus;
use POE;

my $one_way = 0;
if(@ARGV && $ARGV[0] eq "--one-way") {
	$one_way = 1;
	shift @ARGV;
}

my ($socket1, $network1, $channel1, $socket2, $network2, $channel2) = @ARGV;
if(!$channel2) {
	die "Usage: $0 [--one-way] socket1 network1 channel1 socket2 network2 channel2"
}

my $dazeus1 = DaZeus->connect($socket1);
my $dazeus2 = DaZeus->connect($socket2);

if(!network_known($dazeus1, $network1)) {
	die "Network $network1 does not seem to be known at $socket1\n";
} elsif(!network_known($dazeus2, $network2)) {
	die "Network $network2 does not seem to be known at $socket2\n";
}

sub dazeus_event {
	my ($from, $event) = @_;
	my $e = uc($event->{event});
	my $fromnet = $event->{'params'}[0];
	my $fromchan = $event->{'params'}[2];

	my ($to, $tonet, $tochan);
	if($from == $dazeus1) {
		if($fromnet ne $network1 || $fromchan ne $channel1) {
			return;
		}
		$to = $dazeus2;
		$tonet = $network2;
		$tochan = $channel2;
	} elsif($one_way) {
		return;
	} else {
		if($fromnet ne $network2 || $fromchan ne $channel2) {
			return;
		}
		$to = $dazeus1;
		$tonet = $network1;
		$tochan = $channel1;
	}
	if($e eq "PRIVMSG") {
		my $message = '<' . $event->{'params'}[1] . '> ' . $event->{'params'}[3];
		$to->message($tonet, $tochan, $message);
	}
}

POE::Session->create(
inline_states => {
	_start => sub {
		$dazeus1->subscribe(qw/PRIVMSG/, \&dazeus_event);
		$dazeus2->subscribe(qw/PRIVMSG/, \&dazeus_event) if(!$one_way);
		$_[KERNEL]->select_read($dazeus1->socket(), "sock1");
		$_[KERNEL]->select_read($dazeus2->socket(), "sock2");
		$dazeus1->handleEvents();
		$dazeus2->handleEvents();
	},
	sock1 => sub { $dazeus1->handleEvents() },
	sock2 => sub { $dazeus2->handleEvents() },
});

POE::Kernel->run();

sub network_known {
	my ($dazeus, $network) = @_;
	foreach(@{$dazeus->networks()}) {
		return 1 if($_ eq $network);
	}
	return 0;
}
