package Link;

use 5.008;
use strict;
use Carp qw(carp);
use Time::Piece;

use Git qw( git_checkout git_dtag git_tag_obj git_gc );
use Log qw( escape );

use Exporter 'import';
our @EXPORT_OK = qw(
		     examine_msg__set_fixtag
		     szz_diff szz_blame szz_bugtag
		     git_checkout git_dtag git_gc
		  );
our %EXPORT_TAGS = (
		    fix_tags => [qw( examine_msg__set_fixtag git_gc )],
		    bug_tags => [qw( szz_diff szz_blame szz_bugtag
				     git_checkout git_dtag git_gc )],
		   );



sub examine_msg__set_fixtag {
  my ($git_path, $tag_ini, $com_date, $sha, $msg, $ref_id2date, $count, $prj) = @_;
  my %checked_id = ();

  while ($msg =~ /(\d+)/g) {
    my $num = $1;
    my $id = $prj ? $prj . '-' . $num : $num;

    next if (exists $checked_id{$id});
    $checked_id{$id} = 1;
    next unless ($msg =~ /$id/);

    if (exists $ref_id2date->{$id}) {
      my $t_id_open = Time::Piece->strptime($ref_id2date->{$id}{open}, '%Y-%m-%d');
      my $t_id_chgd = Time::Piece->strptime($ref_id2date->{$id}{chgd}, '%Y-%m-%d');
      my $t_com_date = Time::Piece->strptime($com_date, '%Y-%m-%d');

      next unless ($t_com_date >= $t_id_open);
      next unless ($t_com_date <= $t_id_chgd);
      my $tag = $tag_ini . '-' . $id . '-' . $count;
      git_tag_obj($git_path, $tag, 'with Bugzilla', $sha);
      print " [Tagged ($tag)]\n";
      $count++;
    }
  }

  return $count;
}

sub szz_diff {
  my ($ref_data, $ref_java, $git_path, $past_com, $com, @files) = @_;
  my $path = escape($files[0]);
  $path .= ' ' . escape($files[1]) if ($files[1]);

  my $git_difftool_option = "-M -l 3000 --no-prompt --extcmd=diff -b -w $past_com $com";
  open my $git_difftool, "-|", "git --git-dir=$git_path/.git --work-tree=$git_path difftool"
    . " $git_difftool_option -- '$path'"
    or carp "Couldn't open git difftool: $!";
  while (my $dline = <$git_difftool>) {
    next if ($dline =~ /^</ or $dline =~ /^>/ or $dline =~ /^---/ or $dline =~ /a/);
    $dline =~ /^([\d,]+)[cd]/;
    my $pre_line = $1;
    $pre_line .= ','.$pre_line if ($pre_line !~ /,/); # for one line

    $ref_data->{$files[0]}{$pre_line} = 1;

#    if ($files[0] =~ /[MT]/) {
#      my $java = $files[0];
#      $java =~ s|\.f/[CL]/.*?$|\.java|;
#      $ref_java->{$java} = 1;
#    }
  }
  close $git_difftool
    or carp $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git difftool";

  return 0;
}

sub szz_blame {
  my ($ref_data, $ref_java, $git_path) = @_;
  my %checked_com = ();

  for my $file (keys %$ref_data) {
    for my $nums (keys %{ $ref_data->{$file} }) {

      my $git_blame_option = "--incremental -L $nums -w";
      my ($bcom, $ep_date, $ori_file) = ();
      open my $git_blame, "-|", "git --git-dir=$git_path/.git --work-tree=$git_path blame"
	. " $git_blame_option -- " . escape($file)
	  or carp "Couldn't open git blame: $!";
      while (my $line = <$git_blame>) {
	if ($line =~ /^(\w{40})/) {
	  $bcom = $1;
	}
	elsif ($line =~ /^committer-time (\d+)\n$/) {
	  $ep_date = $1;
	}
	elsif ($line =~ /^filename (.*)\n$/) {
	  $ori_file = $1;

	  $checked_com{$bcom}{date} = $ep_date;
	  $checked_com{$bcom}{file}{$ori_file} = 1;

#	  if ($ori_file =~ /[MT]/) {
#	    my $java = $ori_file;
#	    $java =~ s|\.f/[CL]/.*?$|\.java|;
#	    $ref_java->{$java} = 1;
#	  }
	}
      }
      close $git_blame
	or carp $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git blame";

    }
    print '.';
  }
  print "\n";

  return \%checked_com;
}

sub szz_bugtag {
  my ($ref_list, $git_path, $tag, $com) = @_;

  my $list = '@@';
  for my $file (keys %$ref_list) {
    $list .= $file.'@@';
  }
  $list .= '@@';

  git_tag_obj($git_path, $tag, $list, $com);

  return 0;
}


1;
