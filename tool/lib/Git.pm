package Git;

use 5.008;
use strict;
use Carp qw(carp croak);

use Exporter 'import';
our @EXPORT_OK = qw(
		     git_checkout git_dtag git_tag_obj git_gc
		     get_now get_first
		  );


sub git_checkout {
  my ($git_path, $obj) = @_;

  my $gc_status = system("git", "--git-dir=$git_path/.git", "--work-tree=$git_path",
			 "checkout", "-q",
			 "-f", # bugyy (hg-git problem?: Not currently on any branch.)
			 $obj);
  croak "git checkout exited funny: $?" unless $gc_status == 0;

  return 0;
}

sub git_dtag {
  my ($git_path, $tag) = @_;

  my $gc_status = system("git", "--git-dir=$git_path/.git", "--work-tree=$git_path", "tag",
			 "-d", $tag);
  croak "git tag exited funny: $?" unless $gc_status == 0;

  return 0;
}

sub git_tag_obj {
  my ($git_path, $tag, $msg, $obj) = @_;

  my $gc_status = system("git", "--git-dir=$git_path/.git", "--work-tree=$git_path", "tag",
			 "-a", $tag, "-m", $msg, $obj);
  croak "git tag exited funny: $?" unless $gc_status == 0;

  return 0;
}

sub git_gc {
  my $git_path = shift;

  my $gc_status = system("git", "--git-dir=$git_path/.git", "--work-tree=$git_path", "gc");
  croak "git gc exited funny: $?" unless $gc_status == 0;

  return 0;
}

sub get_now {
  my $git_path = shift;

  my $git_lg_opt = '--pretty="%ct" -n 1';
  open my $git_lg, "-|", "git --git-dir=$git_path/.git log $git_lg_opt"
    or croak "Couldn't open git log: $!";
  my $now = <$git_lg>;
  chomp $now;
  close $git_lg
    or croak $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git log";

  return $now;
}

sub get_first {
  my $git_path = shift;

  my $init = '';
  my $git_lg_opt = '--pretty="%ct" --reverse';
  open my $git_lg, "-|", "git --git-dir=$git_path/.git log $git_lg_opt"
    or croak "Couldn't open git log: $!";
  while (my $line = <$git_lg>) {
    unless ($init) {
      chomp $line;
      $init = $line;
    }
  }
  close $git_lg
    or croak $! ? "Syserr closing pipe: $!" : "Wait status ". $? . " from git log";

  return $init;
}


1;
