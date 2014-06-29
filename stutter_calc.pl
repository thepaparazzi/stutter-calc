#!/opt/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

my %EXIT = (
    SUCCESS    => 0,
    ERROR      => 1,
    ARGS_ERROR => 2,
);

use constant {
    DEBUG => 1,
    TRUNC_THRESHOLD => 0.001, # stepmania rounds at three decimal points
};

my ($START_BEAT, $SPAN_LENGTH, $BPM, $QUANTIZE, $MULTIPLIER,
    $QUIET, $SHOW_HELP);

GetOptions(
    '--quiet'   => \$QUIET,
    '--help'    => \$SHOW_HELP,
) or pod2usage(-exitval => $EXIT{ARGS_ERROR}, -verbose => 1);

pod2usage(-exitval => $EXIT{ARGS_ERROR}, -verbose => 2) if ( $SHOW_HELP );
pod2usage(-exitval => $EXIT{ARGS_ERROR}, -verbose => 0) if ( scalar @ARGV < 5 );

($START_BEAT, $SPAN_LENGTH, $BPM, $QUANTIZE, $MULTIPLIER) = @ARGV;

# ---

sub Log {
    return 1 if ( $QUIET );
    print(join(' ', @_), "\n");
}

sub assert_arg {
    my ($assertion, @msg) = @_;

    unless ($assertion) {
        Log(@msg);
        exit $EXIT{ARGS_ERROR};
    }
}

# ---

assert_arg($START_BEAT >= 0, 'start_beat must be greater than or equal to 0');
assert_arg($SPAN_LENGTH > 0, 'span_length must be greater than 0');
assert_arg($BPM > 0, 'bpm must be greater than 0');
assert_arg($QUANTIZE > 0, 'quantization must be greater than 0');
assert_arg($QUANTIZE !~ /[\.e]/, 'quantization must be an integer');
assert_arg($MULTIPLIER > 1, 'multiplier must be greater than 1');

# ---

my $seconds_per_beat = 60 / $BPM;
my $span_seconds = $seconds_per_beat * $SPAN_LENGTH;
my $stutter_consumption = $seconds_per_beat / ($QUANTIZE / 4);
my $stutter_n = int($SPAN_LENGTH * ($QUANTIZE / 4));

Log('span seconds is', $span_seconds) if ( DEBUG );
Log('time per q is', ($stutter_consumption)) if ( DEBUG );

my $stop_length = ($stutter_consumption) * (1 - (1 / $MULTIPLIER));
my $stop_length_trunc = sprintf('%.3f', $stop_length);
my $remainder = $stop_length_trunc - $stop_length;

Log('base stop length is', $stop_length) if ( DEBUG );

my $target_bpm = $BPM * $MULTIPLIER;
my (%stutters, %bpm_changes);
my $quantization_beats = 1 / ($QUANTIZE / 4);

my $truncation = 0;
for my $stop_idx (0 .. $stutter_n - 1) {
    my $stop = $stop_length_trunc;

    $truncation += $remainder;

    if ($truncation > TRUNC_THRESHOLD) {
        $truncation -= TRUNC_THRESHOLD;
        $stop -= TRUNC_THRESHOLD;
    }
    elsif ($truncation < -&TRUNC_THRESHOLD) {
        $truncation += TRUNC_THRESHOLD;
        $stop += TRUNC_THRESHOLD;
    }

    $stutters{sprintf('%.3f', $START_BEAT + $stop_idx * $quantization_beats)} = $stop;
}

%bpm_changes = ( $START_BEAT => $target_bpm, $START_BEAT + $SPAN_LENGTH => $BPM );

if (DEBUG) {
    Log('target BPM is', $target_bpm);
    Log('result:');
    Log($_) foreach ( map { "$_ => $stutters{$_}" } sort { $a <=> $b } keys %stutters );
}

# ---

Log('stops:');
Log(join ',', map { "$_=$stutters{$_}" } sort { $a <=> $b } keys %stutters);

Log("\nbpm changes:");
Log(join ',', map { "$_=$bpm_changes{$_}" } sort { $a <=> $b } keys %bpm_changes);

exit $EXIT{SUCCESS};

__END__

=head1 NAME

stutter_calc.pl - calculates a stutter gimmick for StepMania files

=head1 SYNOPSIS

stutter_calc.pl start_beat span_length bpm quantization multipler [options]

=head1 OPTIONS

=over 4

=item B<--help>

Shows usage.

=item B<--quiet>

Do not output anything.

=back

=head1 DESCRIPTION

This script calculates a stutter effect for StepMania files and compensates for
drift and truncation.

Based on mudkyp's stutter formula (L<http://r21freak.com/phpbb3/viewtopic.php?t=18445>).
