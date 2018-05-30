package Bug;

use 5.008;
use strict;
use Carp qw(carp croak);
use Time::Piece;

use Exporter 'import';
our @EXPORT_OK = qw( get_ids );


sub get_ids {
  my ($ref_ids, $bug_csv_dir) = @_;
  my %jira_prjs = ();

  opendir my $dh, $bug_csv_dir
    or croak "Couldn't open $bug_csv_dir: $!";
  while (defined (my $bug_csv = readdir($dh))) {
    next unless ($bug_csv =~ /\.csv$/);
    print "$bug_csv\n";

    my $prj = '';
    open my $list, "<", $bug_csv_dir . '/' . $bug_csv
      or croak "Couldn't open $bug_csv: $!";
    while (my $id = <$list>) {
      $id =~ s/"//g; # bugzilla
      $id =~ s/ [\d:]+//g; #bugzilla, jira

      if ($id =~ /([^,]+),([\d\-\/]+),([\d\-\/]+)/) {
	my $bid = $1;
	my $odate = $2;
	my $cdate = $3;

	if ($odate =~ /\//) { # jira
	  my $t = Time::Piece->strptime($odate, '%m/%e/%y');
	  $odate = $t->strftime('%Y-%m-%d');
	}

	if ($cdate =~ /\//) { # jira
	  my $t = Time::Piece->strptime($cdate, '%m/%e/%y');
	  $cdate = $t->strftime('%Y-%m-%d');
	}

	$ref_ids->{$bid}{open} = $odate;
	$ref_ids->{$bid}{chgd} = $cdate;

	if (not $prj and $bid =~ /([A-Z]+)-\d+/) {
	  $prj = $1;
	  $jira_prjs{$prj} = 1;
	}
      }
    }
    close $list
      or croak "Couldn't close a list file: $!";

  }
  closedir $dh;

  return \%jira_prjs;
}


1;
