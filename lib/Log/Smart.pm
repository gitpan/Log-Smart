package Log::Smart;

use warnings;
use strict;
our $VERSION = '0.005';

use 5.008;
use Carp;
use IO::File;
use base qw(Exporter);

our @EXPORT = qw(LOG YAML DUMP CLOSE);
our @EXPORT_OK = qw(TRACE);
my $arg_ref; # options
my $fhs_ref; # file handles

#use Data::Dumper; 
#my $test = IO::File->new("/home/kaz/dev/Log-Smart/lib/Log/test", "a") or croak "can't open test fh.";

sub import {
    my $package = shift;
    my ($caller_package, $caller_name, $line) = caller(0);
    return 1 if $caller_name =~ m/\(eval\s.*\)/xms;
    my $TRUE = 1;
    my $FALSE = 0;
    my $file = $caller_name;
    my $arg;
    $file =~ m/(.*)\/.*\z/xms;
    $arg->{-path} = $1;
    $arg->{-name} = "$caller_package.smart_log";
    $arg->{-timestamp} = $FALSE;

    my @symbols = ();
    push @_, @EXPORT;
    while (@_) {
        my $key = shift;
        if ($key =~ /^[-]/) {
            if ($key =~ /-path/) {
                $arg->{$key} = shift;
            }
            elsif ($key =~ /-name/) {
                $arg->{$key} = shift;
            }
            elsif ($key =~ /-timestamp/) {
                $arg->{$key} = $TRUE;
            }
            elsif ($key =~ /-append/) {
                $arg->{$key} = $TRUE;
            }
            elsif ($key =~ /-trace/) {
                $arg->{$key} = shift;
                push @symbols, 'TRACE';
                _tracefilter($arg);
            }
        }
        else {
            push @symbols, $key;
        }
    }

    $arg_ref->{$caller_package} = $arg;
    $fhs_ref->{$caller_package} = _open($arg);
    Exporter::export($package, $caller_package, @symbols);
}

sub _tracefilter {
    my $arg = shift;
    require Filter::Util::Call;
    my $done = 0;
    Filter::Util::Call::filter_add(
        sub {
            return 0 if $done;
            my ($data, $end) = ('', '');
            while (my $status = Filter::Util::Call::filter_read()) {
                return $status if $status < 0;
                if (/^__(?:END|DATA)__\r?$/) {
                    $end = $_;
                    last;
                }
                $data .= $_;
                $_ = '';
            }
            $_ = $data;
            my $target = $arg->{-trace};
            if (ref $target eq 'ARRAY') {
                foreach my $val (@{$target}) {
                    my $name = "'$val'";
                    my $escape = '\\' . $val;
                    s{([^;]*$escape[^;]*;)}{$1TRACE $name => $val;}gm;
                }
            }
            elsif (not ref $target) {
                my $name = "'$target'";
                my $escape = '\\' . $target;
                s{([^;]*$escape[^;]*;)}{$1TRACE $name => $target;}gm;
            }
            else {
                croak 'You should use SCALAR or ARRAY REF : ' . ref $target;
            }
            $done = 1;
        }
    );
}

sub _open {
    my $arg = shift;
    croak "[Log::Smsart]permission denied.
      the output directory checks for write permission."
        unless -w "$arg->{-path}";
    my $mode = $arg->{append} ? 'a' : 'w';
    my $fh = IO::File->new("$arg->{-path}/$arg->{-name}", $mode) or
        croak "IO::File can't open the file : "
        . $arg->{-path} . " name : " . $arg->{-name};
    return $fh;
}


sub LOG {
    my $value = shift;
    my $fh    = $fhs_ref->{ caller(0) };
    my $arg   = $arg_ref->{ caller(0) };

    _log($fh, $arg, $value);
    $fh->flush;
    return $value;
}

sub _log {
    my ($fh, $arg, $value) = @_;
    $value = '[' . localtime(time) . ']' . $value if $arg->{-timestamp};
    print $fh "$value\n" or croak "Can't print value.";
}

sub DUMP {
    my $fh    = $fhs_ref->{ caller(0) };
    my $arg   = $arg_ref->{ caller(0) };
    _dump($fh, $arg, @_);
    $fh->flush;
    return wantarray ? @_ : $_[0];
}

sub _dump {
    # Args must shifts because message or later is Dump args.
    my $fh      = shift;
    my $arg     = shift;
    my $message = shift;
    eval "require Data::Dumper";
    croak "Data::Dumper is not installed" if $@;
    $Data::Dumper::Sortkeys = 1;

    _log($fh, $arg, "[$message #DUMP]");
    print $fh Data::Dumper::Dumper(@_) or croak "Can't print value.";
}

sub YAML {
    my $message = shift;
    eval "require YAML";
    croak "YAML is not installed." if $@;

    my $fh    = $fhs_ref->{ caller(0) };
    my $arg   = $arg_ref->{ caller(0) };
    _log($fh, $arg, "[$message #YAML]");
    print $fh YAML::Dump(@_) or croak "Can't print value.";
    $fh->flush;
    return wantarray ? @_ : $_[0];
}

sub TRACE {
    my $name = shift;
    my ($caller_package, $caller_name, $line) = caller(0);
    my $message = "TRACE name:$name line:$line";
    my $fh    = $fhs_ref->{ caller(0) };
    my $arg   = $arg_ref->{ caller(0) };
    if (scalar(@_) == 1) {
        my $value = shift @_;
        my $type = ref $value;
        if ($type eq 'SCALAR' || $type eq '') {
            _log($fh, $arg, "[$message] $value");
        }
        elsif ($type eq 'ARRAY' || $type eq 'HASH' || $type eq 'REF') {
            _dump($fh, $arg, $message, $value);
        }
        elsif ($type eq 'CODE' || $type eq 'GLOB') {
            croak "Can't trace CODE or GLOB type.";
        }
    }
    else {
        _dump($fh, $arg, $message, @_);
    }
    $fh->flush;
}

sub CLOSE {
    $fhs_ref->{ caller(0) }->close;
    delete $$fhs_ref{ caller(0) };
    delete $$arg_ref{ caller(0) };
}


=head1 NAME

Log::Smart - Messages for smart logging to the file 

=head1 VERSION

version 0.004

=cut

=head1 SYNOPSIS

    use Log::Smart -timestamp;
    
    LOG("write a message");
    DUMP("dump the data structures", $arg);
    YAML("dump the data structures back into yaml", $arg)

=head1 DESCRIPTION

B<Log::Smart> provides logging methods that is easy to use.

This module automatically creates and opens the file for logging.
It is created to location of the file that used this module.
And name of the file is the namespace + I<.smart_log> with using this module.
It exports a function that you can put just about anywhere
in your Perl code tomake it logging.

To change the location or filename, you can use the options.
Please refer to B<OPTIONS> for more information on.

    package Example;

    use Log::Smart;
    #file name "Example.smart_log"


    package Example;
    
    use Log::Smart -name => 'mydebug.log';
    #file name "mydebug.log"

B<WARNING:>
This module automatically determines the output location and the filename when
you don't use some options.
You should carefully use it, otherwise the file of same name is overwrited.
And this module uses a source filter.  If you don't like that, don't use this.

=head1 BACKWARD INCOMPATIBILITY

Current version of Log::Smart was once called Debug::Smart.
When I released this module naming it to Debug::Smart was wrong.
Debug::Smart was unmatched this module functions.
Thanks for nadim khemir from review.

=head1 TRACE

You can trace the variables if you use I<-trace> option.
This option specifies the variable's name that is type of B<SCALAR> or B<ARRAY_REF>.
B<TRACE> function is automatically added by source code filter(B<Fillter::Util::Call>) and
outputs the specified variable's value that each time appeared in the source code.

    # you shuld use sigle quote
    use Log::Smart -trace => '$var';

    my $var = 1;
    $var = 2;
    $var = 10;

done.

    my $var = 1;TRACE $var;
    $var = 2;TRACE $var;
    $var = 10; TRACE $var;

=head1 EXPORT

=over

=item LOG

To write variable to the file.

=item DUMP

To write the variable structures to the file with Data::Dumper::Dumper.

=item YAML 

To write the variable structures to the file with YAML::Dump.

=item TRACE

This function traces valiables.
(TRACE is not export if you don't use I<-trace> option)

=item CLOSE

To close file handle if you want expressly.

=back

=head1 OPTIONS

    use Log::Smart -path => '/path/to/';

I<-path> option specify output location of the log file. 

    use Log::Smart -name => 'filename';

I<-filename> option specify the filename.

    use Log::Smart -timestamp;

I<-timestamp> option add timestamp to the head of logging message.

    use Log::Smart -append

I<-append> option is append mode. Writing at end-of-file.
Default is write mode. It will be overwritten.

    use Log::Smart -trace => '$foo';
or
    use Log::Smart -trace => ['$foo', '$bar'];

I<-trace> option traces the variable of specified the name. 
You should write the single quoted variable's name.

=head1 SEE ALSO

Filter::Util::Call

=head1 AUTHOR

Kazuhiro Shibuya, C<< <k42uh1r0 at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-debug-simple@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Kazuhiro Shibuya, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Log::Smart
