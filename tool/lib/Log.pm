package Log;

use 5.008;
use strict;
use Carp qw(carp croak);

use Exporter 'import';
our @EXPORT_OK = qw(
		     escape identify_bugfix
		  );


sub escape {
  my $path = shift;

  $path =~ s|\(|\\(|g;
  $path =~ s|\)|\\)|g;
  $path =~ s|\<|\\<|g;
  $path =~ s|\>|\\>|g;
  $path =~ s|\[|\\[|g;
  $path =~ s|\]|\\]|g;
  $path =~ s|(\s)|\\$1|g;
  $path =~ s|(\$)|\\$1|g;
  $path =~ s|\*|\\*|g;
  $path =~ s|\&|\\&|g;

  return $path;
}

sub identify_bugfix {
  my ($git_path, $now, $cut_days) = @_;
  my $day_sec = 60 * 60 * 24;
  my $limit_sec = $cut_days * $day_sec;
  my $cut_time = $now + $limit_sec;
  my %com_files = ();

  my $git_tag_option = '-l "_BUG-*"';
  open my $git_tag, "-|", "git --git-dir=$git_path/.git tag $git_tag_option"
    or croak "Couldn't open git tag: $!";
  while (my $btag = <$git_tag>) {
    chomp $btag;
    print "$btag ";

    my $lnum_fs = 0;
    my $tag_msg_fs = '';
    my $bug_com_hash = '';
    my $git_show_btag_option = '--pretty="<COM>%H@@%ct@@"';
    open my $git_show_btag, "-|", "git --git-dir=$git_path/.git show $git_show_btag_option $btag"
      or croak "Couldn't open git show: $!";
    while (my $line = <$git_show_btag>) {
      $lnum_fs++;
      if ($lnum_fs == 4) {
	chomp $line;
	$tag_msg_fs = $line;
      }
      if ($line =~ /^<COM>(.*?)@@(.*?)@@/) {
	$bug_com_hash = $1;
	my $bug_sec = $2;

	if ($bug_sec > $now) {
	  print '|';
	  next;
	}

	# btag = _BUG-(id)-\d+-\d+
	$btag =~ s/_BUG-//;
	$btag =~ s/-\d+$//;
	my $ftag = '_FIX-' . $btag;

	my $fix_com_hash = '';
	my $git_show_ftag_option = '--pretty="<COM>%H@@%ct@@"';
	open my $git_show_ftag, "-|", "git --git-dir=$git_path/.git show $git_show_ftag_option $ftag"
	  or croak "Couldn't open git show: $!";
	while (my $line = <$git_show_ftag>) {
	  if ($line =~ /^<COM>(.*?)@@(.*?)@@/) {
	    $fix_com_hash = $1;
	    my $fix_sec = $2;

	    if ($fix_sec > $cut_time) {
	      print '/';
	      next;
	    }
	    else {
	      print 'v';
	    }

	    for my $file ( split(/@@/, $tag_msg_fs) ) {
	      next unless ($file);
	      $com_files{file}{$file}{$bug_com_hash}{bug}{$btag} = 1;
	      $com_files{file}{$file}{$fix_com_hash}{fix}{$btag} = 1;
	      $com_files{com}{$bug_com_hash}{$file}{bug} = 1;
	      $com_files{com}{$fix_com_hash}{$file}{fix} = 1;
	    }
	  }
	}
	close $git_show_ftag
	  or carp $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git show";
      }
    }
    close $git_show_btag
      or carp $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git show";

    print "\n";
  }
  close $git_tag
    or carp $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git tag";

  return \%com_files;
}

1;
