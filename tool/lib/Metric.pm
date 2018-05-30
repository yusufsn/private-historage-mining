package Metric;

use 5.008;
use strict;
use Carp qw(carp croak);

use FindBin qw( $Bin );
use lib "$Bin";
use Log qw( escape );

use Exporter 'import';
our @EXPORT_OK = qw(
		     measure_hcm count_lines measure_churn measure_ownership measure_interval
		     measure_bug_coupling measure_near_bugs
		  );
our %EXPORT_TAGS = (
		    prediction => [qw(
				       measure_hcm count_lines measure_churn measure_ownership measure_interval
				       measure_bug_coupling measure_near_bugs
				    )],
		   );


# history complexity metric (ignore rename)
sub measure_hcm {
  my $git_path = shift;

  my $com = '';
  my $this_time = '';
  my $previous_time = '';
  my $quiet_time = 60 * 60;
  my $modified_line_file_total = 0;
  my $modified_line_method_total = 0;
  my %modified_line_file = ();
  my %modified_line_method = ();
  my %hcm_file = ();
  my %hcm_method = ();

  my $git_log_entire_option = '--pretty="<COM>%H@@%ad" --date=raw --numstat --reverse';
  open my $git_log_entire, "-|", "git --git-dir=$git_path/.git --work-tree=$git_path log $git_log_entire_option"
    or croak "Couldn't open git log: $!";
  while (my $line = <$git_log_entire>) {
    next if ($line =~ /^\n/);
    next if ($line =~ /test/);

    if ($line =~ /^<COM>(.*?)@@(\d+) \S+$/) {
      $com = $1;
      $this_time = $2;

      if ( $previous_time && ( ($this_time - $previous_time) > $quiet_time ) && $modified_line_method_total ) {
	print '-';

	change_complexity($git_path, $com,
			  \%modified_line_file, \%modified_line_method,
			  $modified_line_file_total, $modified_line_method_total,
			  \%hcm_file, \%hcm_method
			 );

	# reset
	$modified_line_file_total = 0;
	$modified_line_method_total = 0;
	%modified_line_file = ();
	%modified_line_method = ();
      }

      $previous_time = $this_time;
    }
    else {
      chomp $line;
      my @stats = split(/\t/, $line);

      my $module = $stats[2];
      if ($module =~ /\.java$/) {
	$modified_line_file_total += $stats[0] + $stats[1];
	$modified_line_file{$module} += $stats[0] + $stats[1];
      }
      elsif ($module =~ /\[MT\]/) {
	$modified_line_method_total += $stats[0] + $stats[1];
	$modified_line_method{$module} += $stats[0] + $stats[1];
      }

    }
  }
  close $git_log_entire
    or carp $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git log";

  if ( (($this_time - $previous_time) > $quiet_time) && $modified_line_file_total ) {
    print 'z';

    change_complexity($git_path, $com,
		      \%modified_line_file, \%modified_line_method,
		      $modified_line_file_total, $modified_line_method_total,
		      \%hcm_file, \%hcm_method
		     );
  }

  return \%hcm_file, \%hcm_method;
}

sub change_complexity {
  my ($git_path, $com,
      $ref_modi_file, $ref_modi_method,
      $lines_file, $lines_method,
      $ref_hcm_file, $ref_hcm_method
     ) = @_;

  # module change probability
  while (my ($module, $lines) = each %$ref_modi_file) {
    $ref_modi_file->{$module} = $lines / $lines_file;
  }
  if ($lines_method) {
    while (my ($module, $lines) = each %$ref_modi_method) {
      $ref_modi_method->{$module} = $lines / $lines_method;
    }
  }

  # number of modules
  my $num_files = 0;
  my $num_methods = 0;
  my %packages = ();
  my $git_ls_tree_option = '-r --name-only';
  open my $git_ls_tree, "-|", "git --git-dir=$git_path/.git --work-tree=$git_path ls-tree $git_ls_tree_option $com"
    or croak "Couldn't open git ls-tree: $!";
  while (my $line = <$git_ls_tree>) {
    next if ($line =~ /test/);

    chomp $line;
    if ($line =~ /\.java$/) {
      $num_files++;
    }
    elsif ($line =~ /\[MT\]/) {
      $num_methods++;
    }
  }
  close $git_ls_tree
    or croak $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git log";
  return 0 if ($num_methods == 0);

  # normalized static entropy
  my $h_file = 0;
  my $h_method = 0;
  while (my ($module, $p) = each %$ref_modi_file) {
    $h_file -= $p ?
      $p * log($p) / log($num_files): 0;
  }
  if ($num_methods) {
    while (my ($module, $p) = each %$ref_modi_method) {
      $h_method -= $p ?
	$p * log($p) / log($num_methods) : 0;
    }
  }

  # history complexity metric
  for my $module (keys %$ref_modi_file) {
    $ref_hcm_file->{$module} += $h_file / $num_files;
  }
  if ($num_methods) {
    for my $module (keys %$ref_modi_method) {
      $ref_hcm_method->{$module} += $h_method / $num_methods;
    }
  }

  return 0;
}

sub count_lines {
  my $filename = shift;

  my $lines = 0;
  open my $in, "<", $filename or croak "Can't open `$filename': $!";
  while (sysread $in, my $buffer, 4096) {
    $lines += ($buffer =~ tr/\n//);
  }
  close $in or croak "Can't close `$filename': $!";

  return $lines;
}

sub measure_churn {
  my ($git_path, $file, $com) = @_;

  my $add_loc = 0;
  my $del_loc = 0;
  my $efile = escape($file);
  my $git_diff_option = '--numstat';
  open my $git_diff, "-|", "git --git-dir=$git_path/.git --work-tree=$git_path diff $git_diff_option $com HEAD -- $efile"
    or die "Couldn't open git diff: $!";
  while (my $line = <$git_diff>) {
    next if ($line =~ /test/);

    my @info = split(/\t/, $line);
    $add_loc += $info[0];
    $del_loc += $info[1];
  }
  close $git_diff
    or croak $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git diff";

  return $add_loc, $del_loc;
}

sub measure_bug_coupling {
  my ($git_path, $ref_module_data, $ref_faults, $ref_renames) = @_;

  my $exist_faulty = 0;
  my %set = ();

  my $git_log_option = '--pretty="<COM>%n" --name-only --no-renames';
  open my $git_log, "-|", "git --git-dir=$git_path/.git log $git_log_option"
    or croak "Couldn't open git log: $!";
  while (my $line = <$git_log>) {
    next if ($line =~ /^\n/);
    next if ($line =~ /test/);

    chomp $line;

    if ($line =~ /^<COM>$/) {
      if ($exist_faulty) {
	for my $fle (keys %set) {
	  next if (not exists $ref_module_data->{$fle});
	  $ref_module_data->{$fle}{bug_coupling} += 1;
	}
	$exist_faulty = 0;
      }
      %set = ();
    }
    else {
      $line = $ref_renames->{$line} if (exists $ref_renames->{$line});
      $set{$line} = 1;

      $exist_faulty++ if (exists $ref_faults->{$line});
    }
  }
  close $git_log
    or croak $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git log";
  if ($exist_faulty) {
    for my $fle (keys %set) {
      next if (not exists $ref_module_data->{$fle});
      $ref_module_data->{$fle}{bug_coupling} += 1;
    }
  }

  return 0;
}

sub measure_near_bugs {
  my $ref_module_data = shift;
  my %y_file_methods = ();
  my %n_methods = ();

  for my $module (keys %$ref_module_data) {
    my $faulty = $ref_module_data->{$module}{faulty};
    $module =~ /^(.*?\.java)\//;
    my $file = $1;
    if ($faulty eq 'y') {
      $y_file_methods{$file}{$module} = 1;
    }
    else {
      $n_methods{$module} = $file;
    }
  }

  for my $mdl (keys %n_methods) {
    my $fle = $n_methods{$mdl};
    if (exists $y_file_methods{$fle}) {
      my $num = keys %{ $y_file_methods{$fle} };
      $ref_module_data->{$mdl}{near_bugs} = $num;
    }
  }

  return 0;
}

sub measure_ownership {
  my ($ref_data, $total) = @_;
  my $minor = 0;
  my $major = 0;
  my $ownership = 0;

  for my $i (keys %$ref_data) {
    my $ratio = $ref_data->{$i} / $total;
    $ownership = $ratio if ($ratio > $ownership);

    if ($ratio < 0.2) {
      $minor++;
    }
    else {
      $major++;
    }
  }

  return $minor, $major, $ownership;
}

sub measure_interval {
  my ($now, $com_num, $ref_days) = @_;
  my $after_day = $now;
  my $init_day = 0;
  my $interval = 0;
  my $max_interval = 0;
  my $min_interval = $now;
  my $day_sec = 60 * 60 * 24;

  for my $day (sort { $b <=> $a } keys %$ref_days) {
    $interval = $after_day - $day;
    $max_interval = $interval if ($interval > $max_interval);
    $min_interval = $interval if ($interval < $min_interval);

    $after_day = $day;
    $init_day = $day;
  }

  my $period = int( ($now - $init_day) / $day_sec );
  my $avg = int( ($now - $init_day) / ($com_num * $day_sec) );
  my $max = int( $max_interval / $day_sec );
  my $min = int( $min_interval / $day_sec );

  return $period, $avg, $max, $min;
}

1;
