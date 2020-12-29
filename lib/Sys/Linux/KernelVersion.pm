package Sys::Linux::KernelVersion;

# ABSTRACT: Gives tools for checking the current running linux kernel version

use v5.8.3;
use strict;
use warnings;

our $VERSION = '0.100';
use Exporter 'import';

our @EXPORT_OK = qw/is_linux_kernel get_kernel_version is_at_least_kernel_version is_development_kernel stringify_kernel_version/;

# not a complicated check, probably doesn't need to exist either but sure
sub is_linux_kernel { $^O eq 'linux' }

my $linux_version;

sub get_kernel_version {
  # cache the result, it shouldn't ever change while we run.  if it does TS for you.
  return $linux_version if $linux_version;

  open(my $fh, "<", "/proc/version") or die "Couldn't open /proc/version : $!";

  my $line = <$fh>;

  close($fh) or die "Couldn't close the handle for /proc/version $!";

  $linux_version = _parse_version_line($line);
}

sub _parse_version_spec {
  my $spec = shift;
  if ($spec =~ /^(\d+)\.(\d+)\.(\d+)(-\S+)?$/) {
    my ($major, $minor, $revision, $subpart) = ($1, $2, $3, $4);

    $linux_version = {major => $major, minor => $minor, revision => $revision, subpart => $subpart, subparts => [split /-/, $subpart||""]};
  } else {
    die "Invalid version spec";
  }
}

# TODO parse the compiler and other version info too? I'm not interested in it and I don't know if they're stable formatting wise
sub _parse_version_line {
  my $line = shift;

  if ($line =~ /^Linux version (\S+) .*$/) {
    return _parse_version_spec($1);
  } else {
    die "Couldn't parse [$line]";
  }
}

sub _cmp_version {
  my ($left, $right) = @_;

  unless (defined($left->{major})  && defined($left->{minor})  && defined($left->{revision}) &&
          defined($right->{major}) && defined($right->{minor}) && defined($right->{revision})) {
    die "Invalid version spec provided";
  }

  return $left->{major} <=> $right->{major} || $left->{minor} <=> $right->{minor} || $left->{revision} <=> $right->{revision};
}

sub is_at_least_kernel_version {
  my $input = shift; # just a string as input

  my $running_version = get_version();
  my $input_version = _parse_version($input);

  my $cmp = _cmp_version($running_version, $input_version);

  return $cmp != -1;
}

# Is this a development kernel
sub is_development_kernel {
  my $running_version = get_kernel_version();

  return _is_development($running_version);
}

sub _is_development {
  my $version = shift;

  my $last_dev_rev = _parse_version_spec("2.5.9999"); # last one where the even/odd minor number was a thing

  if (_cmp_version($last_dev_rev, $version) != -1) {
    my $minor = $version->{minor};

    return 1 if ($minor % 2);
    return 0;
  } else {
    # There's no longer any proper development series like there used to be, but there are -rcN kernels during development, these should count
    my $subpart = $version->{subpart} || "";
    
    return ($subpart =~ /-rc\d/);
  }
}

sub stringify_kernel_version {
  my $version = shift;

  sprintf "%d.%d.%d%s", $version->{major}, $version->{minor}, $version->{revision}, $version->{subpart}||"";
}

1;
