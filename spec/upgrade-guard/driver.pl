#!/usr/bin/env perl
# Runs the cases in cases.yml against the pre-deploy hook's decision functions
# and prints one JSON array of results.  The functions need no BOSH director.
# Usage: driver.pl <kit directory> <cases file>
use v5.20;
use warnings;

BEGIN { push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib' }
use JSON::PP ();
use Genesis qw/load_yaml_file/;

my ($kit_dir, $cases_file) = @ARGV;
die "usage: driver.pl <kit directory> <cases file>\n" unless $kit_dir && $cases_file;

require "$kit_dir/hooks/pre-deploy.pm";
my $hook = 'Genesis::Hook::PreDeploy::RabbitMQ';

my ($cases, $rc, $err) = load_yaml_file($cases_file);
die "could not read $cases_file: $err\n" if $rc || ref($cases) ne 'HASH';

my @results;
for my $case (@{$cases->{guard} || []}) {
  my $got = eval { no strict 'refs'; &{"${hook}::assess_deployed_rabbitmq"}($case->{manifest}, $case->{deployed_releases} || {}) };
  my $problem = $@ ? "died: $@" : '';
  $problem ||= sprintf('expected verdict %s, got %s (%s)', $case->{expect}, $got->{verdict}, $got->{reason})
    if !$problem && $got->{verdict} ne $case->{expect};
  $problem ||= sprintf('expected the reason to include "%s", got "%s"', $case->{reason_includes}, $got->{reason})
    if !$problem && defined($case->{reason_includes}) && index($got->{reason}, $case->{reason_includes}) < 0;
  push @results, {name => $case->{name}, ok => $problem ? JSON::PP::false : JSON::PP::true, message => $problem};
}

for my $case (@{$cases->{booleans} || []}) {
  my $value = $case->{value};
  my $shown = ref($value) eq 'ARRAY' ? 'a list' : (ref($value) ? ($value ? 'true' : 'false') : "\"$value\"");
  my $got = eval { no strict 'refs'; &{"${hook}::parse_boolean_param"}($value, 'params.skip_rabbitmq_upgrade_check') };
  my $outcome = $@ ? 'error' : ($got ? 'true' : 'false');
  my $problem = $outcome ne $case->{expect} ? "expected $case->{expect}, got $outcome" : '';
  push @results, {name => "the skip parameter value $shown", ok => $problem ? JSON::PP::false : JSON::PP::true, message => $problem};
}

print JSON::PP->new->canonical->encode(\@results), "\n";
