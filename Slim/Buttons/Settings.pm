package Slim::Buttons::Settings;

# SlimServer Copyright (c) 2001, 2002, 2003 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use File::Spec::Functions qw(:ALL);
use File::Spec::Functions qw(updir);
use Slim::Buttons::Common;
use Slim::Buttons::Browse;
use Slim::Buttons::AlarmClock;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw (string);
use Slim::Utils::Prefs;
use Slim::Buttons::Information;

# button functions for browse directory
my @defaultSettingsChoices = ('ALARM','VOLUME', 'BASS','TREBLE','REPEAT','SHUFFLE','TITLEFORMAT','TEXTSIZE','OFFDISPLAYSIZE','INFORMATION');
my @settingsChoices;

my %current;
my %menuParams = (
	'settings' => {
		'listRef' => \@defaultSettingsChoices
		,'stringExternRef' => 1
		,'header' => 'SETTINGS'
		,'stringHeader' => 1
		,'headerAddCount' => 1
		,'callback' => \&settingsExitHandler
		,'overlayRef' => sub {return (undef,Slim::Hardware::VFD::symbol('rightarrow'));}
		,'overlayRefArgs' => ''
	}
	,catdir('settings','ALARM') => {
		'useMode' => 'alarm'
	}
	,catdir('settings','VOLUME') => {
		'useMode' => 'volume' # replace with INPUT.Bar when available
	}
	,catdir('settings','BASS') => {
		'useMode' => 'bass' # replace with INPUT.Bar when available
	}
	,catdir('settings','TREBLE') => {
		'useMode' => 'treble' # replace with INPUT.Bar when available
	}
	,catdir('settings','REPEAT') => {
		'useMode' => 'INPUT.List'
		,'listRef' => [0,1,2]
		,'externRef' => ['REPEAT_OFF', 'REPEAT_ONE', 'REPEAT_ALL']
		,'stringExternRef' => 1
		,'header' => 'REPEAT'
		,'stringHeader' => 1
		,'onChange' => sub { Slim::Control::Command::execute($_[0], ["playlist", "repeat", $_[1]]); }
		,'onChangeArgs' => 'CV'
		,'initialValue' => \&Slim::Player::Playlist::repeat
	}
	,catdir('settings','SHUFFLE') => {
		'useMode' => 'INPUT.List'
		,'listRef' => [0,1,2]
		,'externRef' => [ 'SHUFFLE_OFF','SHUFFLE_ON_SONGS','SHUFFLE_ON_ALBUMS']
		,'stringExternRef' => 1
		,'header' => 'SHUFFLE'
		,'stringHeader' => 1
		,'onChange' => sub { Slim::Control::Command::execute($_[0], ["playlist", "shuffle", $_[1]]); }
		,'onChangeArgs' => 'CV'
		,'initialValue' => \&Slim::Player::Playlist::shuffle
	}
	,catdir('settings','TITLEFORMAT') => {
		'useMode' => 'INPUT.List'
		,'listRef' => undef # filled before changing modes
		,'listIndex' => undef #filled before changing modes
		,'externRef' => undef #filled before changing modes
		,'header' => 'TITLEFORMAT'
		,'stringHeader' => 1
		,'onChange' => sub { Slim::Utils::Prefs::clientSet($_[0],"titleFormatCurr",Slim::Buttons::Common::param($_[0],'listIndex')); }
		,'onChangeArgs' => 'C'
	}
	,catdir('settings','TEXTSIZE') => {
		'useMode' => 'INPUT.List'
		,'listRef' => [0,1]
		,'externRef' => [ 'SMALL','LARGE']
		,'stringExternRef' => 1
		,'header' => 'TEXTSIZE'
		,'stringHeader' => 1
		,'onChange' => sub { Slim::Utils::Prefs::clientSet($_[0], "doublesize", $_[1]); }
		,'onChangeArgs' => 'CV'
		,'initialValue' => 'doublesize'
	}
	,catdir('settings','OFFDISPLAYSIZE') => {
		'useMode' => 'INPUT.List'
		,'listRef' => [0,1]
		,'externRef' => [ 'SMALL','LARGE']
		,'stringExternRef' => 1
		,'header' => 'OFFDISPLAYSIZE'
		,'stringHeader' => 1
		,'onChange' => sub { Slim::Utils::Prefs::clientSet($_[0], "offDisplaySize", $_[1]); }
		,'onChangeArgs' => 'CV'
		,'initialValue' => 'offDisplaySize'
	}
	,catdir('settings','INFORMATION') => {
		'useMode' => 'information'
	}
	,catdir('settings','SYNCHRONIZE') => {
		'useMode' => 'synchronize'
	}
	#,catdir('settings','PLAYER_NAME') => {
	#	'useMode' => 'INPUT.Text'
		#add more params here after the rest is working
	#}

);

sub settingsExitHandler {
	my ($client,$exittype) = @_;
	$exittype = uc($exittype);
	if ($exittype eq 'LEFT') {
		Slim::Buttons::Common::popModeRight($client);
	} elsif ($exittype eq 'RIGHT') {
		my $nextmenu = catdir('settings',$current{$client});
		if (exists($menuParams{$nextmenu})) {
			my %nextParams = %{$menuParams{$nextmenu}};
			if ($nextParams{'useMode'} eq 'INPUT.List' && exists($nextParams{'initialValue'})) {
				#set up valueRef for current pref
				my $value;
				if (ref($nextParams{'initialValue'}) eq 'CODE') {
					$value = $nextParams{'initialValue'}->($client);
				} else {
					$value = Slim::Utils::Prefs::clientGet($client,$nextParams{'initialValue'});
				}
				$nextParams{'valueRef'} = \$value;
			}
			if ($nextmenu eq catdir('settings','TITLEFORMAT')) {
				my @titleFormat = Slim::Utils::Prefs::clientGetArray($client,'titleFormat');
				$nextParams{'listRef'} = \@titleFormat;
				my @externTF = map {Slim::Utils::Prefs::getInd('titleFormat',$_)} @titleFormat;
				$nextParams{'externRef'} = \@externTF;
				$nextParams{'listIndex'} = Slim::Utils::Prefs::clientGet($client,'titleFormatCurr');
				
			}
			Slim::Buttons::Common::pushModeLeft(
				$client
				,$nextParams{'useMode'}
				,\%nextParams
			);
		} else {
			Slim::Display::Animation::bumpRight($client);
		}
	} else {
		return;
	}
}

my %functions = (
	'right' => sub  {
		my ($client,$funct,$functarg) = @_;
		if (defined(Slim::Buttons::Common::param($client,'useMode'))) {
			#in a submenu of settings, which is passing back a button press
			Slim::Display::Animation::bumpRight($client);
		} else {
			#handle passback of button presses
			settingsExitHandler($client,'RIGHT');
		}
	}
);

sub getFunctions {
	return \%functions;
}

sub setMode {
	my $client = shift;
	my $method = shift;
	if ($method eq 'pop') {
		Slim::Buttons::Common::popModeRight($client);
		return;
	}

	$current{$client} = $defaultSettingsChoices[0] unless exists($current{$client});
	my %params = %{$menuParams{'settings'}};
	$params{'valueRef'} = \$current{$client};
	if (Slim::Player::Sync::isSynced($client) || (scalar(Slim::Player::Sync::canSyncWith($client)) > 0)) {
		my @settingsChoices = @defaultSettingsChoices;
		push @settingsChoices, 'SYNCHRONIZE';
		$params{'listRef'} = \@settingsChoices;
	}
	Slim::Buttons::Common::pushMode($client,'INPUT.List',\%params);
	$client->update();
}

######################################################################
# settings submodes for: treble, bass, and volume
#################################################################################
my %trebleSettingsFunctions = (
	'up' => sub {
		my $client = shift;
		Slim::Buttons::Common::mixer($client,'treble','up');
	},
	'down' => sub {
		my $client = shift;
		Slim::Buttons::Common::mixer($client,'treble','down');
	},
	'left' => sub   {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub { Slim::Display::Animation::bumpRight(shift); },
	'add' => sub { Slim::Display::Animation::bumpRight(shift); },
	'play' => sub { Slim::Display::Animation::bumpRight(shift); },
);

sub getTrebleFunctions {
	return \%trebleSettingsFunctions;
}

sub setTrebleMode {
	my $client = shift;
	$client->lines(\&trebleSettingsLines);
}

 sub trebleSettingsLines {
	my $client = shift;
	my ($line1, $line2);
	my $level = int(Slim::Utils::Prefs::clientGet($client, "treble")/100*40 + 0.5) - 20;
	$line1 = string('TREBLE') . " ($level)";

	$line2 = Slim::Display::Display::balanceBar($client, 40, Slim::Utils::Prefs::clientGet($client, "treble"));	
	if (Slim::Utils::Prefs::clientGet($client,'doublesize')) { $line2 = $line1; }
	
	return ($line1, $line2);
}

#################################################################################
my %bassSettingsFunctions = (
	'up' => sub {
		my $client = shift;
		Slim::Buttons::Common::mixer($client,'bass','up');
	},
	'down' => sub {
		my $client = shift;
		Slim::Buttons::Common::mixer($client,'bass','down');
	},
	'left' => sub   {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub { Slim::Display::Animation::bumpRight(shift); },
	'add' => sub { Slim::Display::Animation::bumpRight(shift); },
	'play' => sub { Slim::Display::Animation::bumpRight(shift); },
);

sub getBassFunctions {
	return \%bassSettingsFunctions;
}

sub setBassMode {
	my $client = shift;
	$client->lines(\&bassSettingsLines);
}

 sub bassSettingsLines {
	my $client = shift;
	my ($line1, $line2);
	
	my $level = int(Slim::Utils::Prefs::clientGet($client, "bass")/100*40 + 0.5) - 20;
	$line1 = string('BASS') . " ($level)";

	$line2 = Slim::Display::Display::balanceBar($client, 40, Slim::Utils::Prefs::clientGet($client, "bass"));	
	if (Slim::Utils::Prefs::clientGet($client,'doublesize')) { $line2 = $line1; }
	return ($line1, $line2);
}

#################################################################################
my %volumeSettingsFunctions = (
	'left' => sub   {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub { Slim::Display::Animation::bumpRight(shift); },
	'add' => sub { Slim::Display::Animation::bumpRight(shift); },
	'play' => sub { Slim::Display::Animation::bumpRight(shift); },
);

sub getVolumeFunctions {
	return \%volumeSettingsFunctions;
}

sub setVolumeMode {
	my $client = shift;
	$client->lines(\&volumeLines);
}

 sub volumeLines {
	my $client = shift;

	my $level = int(Slim::Utils::Prefs::clientGet($client, "volume") / $Slim::Player::Client::maxVolume * 40);

	my $line1;
	my $line2;
	
	if ($level < 0) {
		$line1 = string('VOLUME')."  (". string('MUTED') . ")";
		$level = 0;
	} else {
		$line1 = string('VOLUME')." (".$level.")";
	}

	$line2 = Slim::Display::Display::progressBar($client, 40, $level / 40);	
	
	if (Slim::Utils::Prefs::clientGet($client,'doublesize')) { $line2 = $line1; }
	return ($line1, $line2);
}

1;

__END__
