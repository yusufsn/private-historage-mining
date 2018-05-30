#!/usr/bin/perl

use strict;
use warnings;
use Time::Piece;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";
use Git qw( get_now );
use Log qw( escape identify_bugfix );
use Metric qw( :prediction );


my $git_path = $ARGV[0];
my $file_list = $ARGV[1];
my $out_csv = $ARGV[2];
my $cut_days = $ARGV[3];


my $now = get_now($git_path);
my $ref_com_files = identify_bugfix($git_path, $now, $cut_days);
my ($ref_hcm_file, $ref_hcm_method) = measure_hcm($git_path);

# each historical metrics
my $file_num = 1;
my %faults = ();
my %renames = ();
my %module_data = ();
open my $list, "<", $file_list
  or die "Couldn't open $file_list: $!";
while (my $file = <$list>) {
  next if ($file =~ /test/i);

  chomp $file;
  next unless (-f "$git_path/$file" or -d "$git_path/$file");

  print '.';
  print "[$file_num]" unless ($file_num % 100);
  $file_num++;

  mine_git_log($git_path, $now, $file,
	       \%module_data, \%faults, \%renames, $ref_com_files);

  my $loc = count_lines("$git_path/$file");
  $module_data{$file}{loc} = $loc;

  my $hcm = 0;
  if (exists $ref_hcm_file->{$file}) {
    $hcm = $ref_hcm_file->{$file};
  }
  elsif (exists $ref_hcm_method->{$file}) {
    $hcm = $ref_hcm_method->{$file};
  }
  $module_data{$file}{hcm} = $hcm;
}
close $list
  or die "Couldn't close a list file: $!\n";
print "[$file_num]\n";

measure_bug_coupling($git_path, \%module_data, \%faults, \%renames);
measure_near_bugs(\%module_data);

open my $csv, ">", $out_csv
  or die "Couln't open $out_csv: $!";
out_csv_header($csv);
out_csv_data($csv, \%module_data);
close $csv
  or die "Couldn't close $out_csv: $!\n";

exit 0;


sub mine_git_log {
  my ($git_path, $now, $file,
      $ref_module_data, $ref_faults, $ref_renames, $ref_com_files
     ) = @_;

  my $com_num = 0;
  my $fix_com_num = 0;
  my $com = '';
  my $zone = '';
  my $author = '';
  my %days = ();
  my %authors = ();
  my %zones = ();
  my %bug_id_fixs = ();

  my $exists_logs = 0;
  my $this_com = 0;
  my $efile = escape($file);
  my $git_log_file_option = '--pretty="<COM>%H@@%cd@@%cE" --date=raw --name-status -M -l 3000';
  open my $git_log_file, "-|", "git --git-dir=$git_path/.git --work-tree=$git_path log $git_log_file_option -- $efile"
    or die "Couldn't open git log: $!";
  while (my $line = <$git_log_file>) {
    next if ($line =~ /^\n/);
    if ($line =~ /^<COM>(.*?)@@(\d+) (\S+)@@(.*?)\n$/) {
      $com = $1;
      $days{$2} = 1;
      $zone = $3;
      $zones{$zone} += 1;
      $author = $4;
      $authors{$author} += 1;

      $exists_logs = 1;
      $com_num++;
      $this_com = 0;
    }
    else {
      next if ($line =~ /test/);

      my $file1 = '';
      my $file2 = '';

      if ($line =~ /^[ADM]\t(.*)\n$/) {
	$file1 = $1;
      }
      elsif ($line =~ /^C\d+\t[^\t]+\t(.*)\n$/) {
	$file1 = $1;
      }
      elsif ($line =~ /^R\d+\t([^\t]+)\t(.*)\n$/) {
	$file1 = $1;
	$file2 = $2;

	$ref_renames->{$file1} = $file if ($file1 ne $file);

      }
      elsif ($line =~ /^C\d+\s+\S+\s+(\S+)\n$/) {
	$file1 = $1;
      }
      else {
	print $line;
	exit;
      }

      if (exists $ref_com_files->{file}{$file1}) {
	if (exists $ref_com_files->{file}{$file1}{$com}) {
	  if (exists $ref_com_files->{file}{$file1}{$com}{bug}) {
	    for my $id_fix (keys %{$ref_com_files->{file}{$file1}{$com}{bug}}) {
	      $bug_id_fixs{$id_fix} = 'faulty' if (not exists $bug_id_fixs{$id_fix});
	    }
	  }
	  if (exists $ref_com_files->{file}{$file1}{$com}{fix}) {
	    $fix_com_num++ unless ($this_com);
	    $this_com = 1;
	    for my $id_fix (keys %{$ref_com_files->{file}{$file1}{$com}{fix}}) {
	      $bug_id_fixs{$id_fix} = 'clean';
	    }
	    $ref_faults->{$file} = 1;
	  }
	}
      }
      elsif ($file2 and exists $ref_com_files->{file}{$file2}) {
	if (exists $ref_com_files->{file}{$file2}{$com}) {
	  if (exists $ref_com_files->{file}{$file2}{$com}{bug}) {
	    for my $id_fix (keys %{$ref_com_files->{file}{$file2}{$com}{bug}}) {
	      $bug_id_fixs{$id_fix} = 'faulty' if (not exists $bug_id_fixs{$id_fix});
	    }
	  }
	  if (exists $ref_com_files->{file}{$file2}{$com}{fix}) {
	    $fix_com_num++ unless ($this_com);
	    $this_com = 1;
	    for my $id_fix (keys %{$ref_com_files->{file}{$file2}{$com}{fix}}) {
	      $bug_id_fixs{$id_fix} = 'clean';
	    }
	    $ref_faults->{$file} = 1;
	  }
	}
      }
    }
  }
  close $git_log_file
    or die $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git log";

  if ($exists_logs && $com_num > 1) {
    my ($add_loc, $del_loc) = measure_churn($git_path, $file, $com);
    $ref_module_data->{$file}{add_loc} = $add_loc;
    $ref_module_data->{$file}{del_loc} = $del_loc;
  }
  else {
    $ref_module_data->{$file}{add_loc} = 0;
    $ref_module_data->{$file}{del_loc} = 0;
  }

  $ref_module_data->{$file}{com_num} = $com_num;
  $ref_module_data->{$file}{fix_com_num} = $fix_com_num;

  my ($minor, $major, $ownership) = measure_ownership(\%authors, $com_num);
  $ref_module_data->{$file}{dev_total} = keys %authors;
  $ref_module_data->{$file}{dev_minor} = $minor;
  $ref_module_data->{$file}{dev_major} = $major;
  $ref_module_data->{$file}{dev_ownership} = $ownership;

  my ($period, $avg, $max, $min) = measure_interval($now, $com_num, \%days);
  $ref_module_data->{$file}{period} = $period;
  $ref_module_data->{$file}{avg_period} = $avg;
  $ref_module_data->{$file}{max_interval} = $max;
  $ref_module_data->{$file}{min_interval} = $min;

  $ref_module_data->{$file}{bug_coupling} = 0;
  $ref_module_data->{$file}{near_bugs} = 0;

  my $faulty = 'n';
  # module is faulty if more than bug_id has not been fixed
  while (my ($id_fix, $status) = each %bug_id_fixs) {
    $faulty = 'y' if ($status eq 'faulty');
  }
  $ref_module_data->{$file}{faulty} = $faulty;

  return 0;
}


sub out_csv_header {
  my $out = shift;

  print $out 'loc';

  print $out  ',' . 'add_loc';
  print $out  ',' . 'del_loc';

  print $out ',' . 'com_num';
  print $out ',' . 'fix_com_num';

  print $out ',' . 'hcm';

  print $out ',' . 'dev_total';
  print $out ',' . 'dev_minor';
  print $out ',' . 'dev_major';
  print $out ',' . 'dev_ownership';

  print $out ',' . 'period';
  print $out ',' . 'avg_period';
  print $out ',' . 'max_interval';
  print $out ',' . 'min_interval';

  print $out ',' . 'bug_coupling';
  print $out ',' . 'near_bugs';

  print $out ',' . 'faulty';

  print $out ',' . 'file';
  print $out "\n";


  return 0;
}


sub out_csv_data {
  my ($out, $ref_data) = @_;

  for my $file (keys %$ref_data) {
    next unless ($ref_data->{$file}{loc});

    print $out $ref_data->{$file}{loc};

    print $out ',' . $ref_data->{$file}{add_loc};
    print $out ',' . $ref_data->{$file}{del_loc};

    print $out ',' . $ref_data->{$file}{com_num};
    print $out ',' . $ref_data->{$file}{fix_com_num};

    print $out ',' . $ref_data->{$file}{hcm};

    print $out ',' . $ref_data->{$file}{dev_total};
    print $out ',' . $ref_data->{$file}{dev_minor};
    print $out ',' . $ref_data->{$file}{dev_major};
    print $out ',' . $ref_data->{$file}{dev_ownership};

    print $out ',' . $ref_data->{$file}{period};
    print $out ',' . $ref_data->{$file}{avg_period};
    print $out ',' . $ref_data->{$file}{max_interval};
    print $out ',' . $ref_data->{$file}{min_interval};

    print $out ',' . $ref_data->{$file}{bug_coupling};
    print $out ',' . $ref_data->{$file}{near_bugs};

    print $out ',' . $ref_data->{$file}{faulty};

    $file =~ s/,/@/;
    print $out ',"' . $file . '"' . "\n";
  }

  return 0;
}
