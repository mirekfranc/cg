#!/usr/bin/perl -w

# based on colorgcc  Version: 1.4.5

use strict;
use warnings;

use Term::ANSIColor;

my(%nocolor, %colors, %compilerPaths, %options);
my($unfinishedQuote, $previousColor);

sub initDefaults
{
#$options{"chainedPath"} = "0";
  $nocolor{"dumb"} = "true";

  $colors{"srcColor"}             = color("bold white");
  $colors{"identColor"}           = color("bold green"); 
  $colors{"introColor"}           = color("bold green");

  $colors{"introFileNameColor"} = color("blue");
  $colors{"introMessageColor"}  = color("blue");

  $colors{"noteFileNameColor"}    = color("bold cyan");
  $colors{"noteNumberColor"}      = color("bold white");
  $colors{"noteMessageColor"}     = color("bold cyan");

  $colors{"warningFileNameColor"} = color("bold cyan");
  $colors{"warningNumberColor"}   = color("bold white");
  $colors{"warningMessageColor"}  = color("bold yellow");

  $colors{"errorFileNameColor"}   = color("bold cyan");
  $colors{"errorNumberColor"}     = color("bold white");
  $colors{"errorMessageColor"}    = color("bold red");
}

sub loadPreferences
{
  # Usage: loadPreferences("filename");

  my($filename) = @_;

  open(PREFS, "<$filename") || return;

  while(<PREFS>)
  {
    next if (m/^\#.*/);          # It's a comment.
    next if (!m/(.*):\s*(.*)/);  # It's not of the form "foo: bar".

    my $option = $1;
    my $value = $2;

    if ($option eq "nocolor")
    {
      # The nocolor option lists terminal types, separated by
      # spaces, not to do color on.
      foreach my $term (split(' ', $value))
      {
        $nocolor{$term} = 1;
      }
    }
    elsif (defined $colors{$option})
    {
      $colors{$option} = color($value);
    }
    elsif (defined $options{$option})
    {
      $options{$option} = $value;
    }
    else
    {
      $compilerPaths{$option} = $value;
    }
  }
  close(PREFS);
}

sub srcscan
{
  # Usage: srcscan($text, $normalColor)
  #    $text -- the text to colorize
  #    $normalColor -- The escape sequence to use for non-source text.

  # Looks for text between ` and ', and colors it srcColor.

  my($line, $normalColor) = @_;

  if (defined $normalColor)
  {
    $previousColor = $normalColor;
  }
  else
  {
    $normalColor = $previousColor;
  }

  # These substitutions replace `foo' with `AfooB' where A is the escape
  # sequence that turns on the the desired source color, and B is the
  # escape sequence that returns to $normalColor.

  my($srcon)  = color("reset") . $colors{"srcColor"};
  my($srcoff) = color("reset") . $normalColor;

  $line = ($unfinishedQuote? $srcon : $normalColor) . $line;

  # Handle multi-line quotes.
  if ($unfinishedQuote) {
    if ($line =~ s/^([^\`]*?)\'/$1$srcoff\'/)
    {
      $unfinishedQuote = 0;
    }
  }
  if ($line =~ s/\`([^\']*?)$/\`$srcon$1/)
  {
    $unfinishedQuote = 1;
  }

  # Single line quoting.
  $line =~ s/\`(.*?)\'/\`$srcon$1$srcoff\'/g;

  # This substitute replaces ‘foo’ with ‘AfooB’ where A is the escape
  # sequence that turns on the the desired identifier color, and B is the
  # escape sequence that returns to $normalColor.
  my($identon)  = color("reset") . $colors{"identColor"};
  my($identoff) = color("reset") . $normalColor;

  $line =~ s/\‘(.*?)\’/\‘$identon$1$identoff\’/g;

  print($line, color("reset"));
}

#
# Main program
#

# Set up default values for colors and compilers.
initDefaults();

# Read the configuration file, if there is one.
my $configFile = $ENV{"HOME"} . "/.colorgccrc";
if (-f $configFile)
{
  loadPreferences($configFile);
}
elsif (-f '/etc/colorgcc/colorgccrc')
{
  loadPreferences('/etc/colorgcc/colorgccrc');
}

# Set our default output color.  This presumes that any unrecognized output
# is an error.
$previousColor = $colors{"errorMessageColor"};

# Get the terminal type.
my $terminal = $ENV{"TERM"} || "dumb";

# Colorize the output from the compiler.
while(<STDIN>)
{
  if (m#^(.+?\.[^:/ ]+):([0-9]+):(.*)$#) # filename:lineno:message
  {
    my $field1 = $1 || "";
    my $field2 = $2 || "";
    my $field3 = $3 || "";

    if (/instantiated from /)
    {
      srcscan($_, $colors{"introColor"})
    }
    elsif ($field3 =~ m/\s+note:.*/)
    {
      # Note
      print($colors{"noteFileNameColor"}, "$field1:", color("reset"));
      print($colors{"noteNumberColor"},   "$field2:", color("reset"));
      srcscan($field3, $colors{"noteMessageColor"});
    }
    elsif ($field3 =~ m/\s+warning:.*/)
    {
      # Warning
      print($colors{"warningFileNameColor"}, "$field1:", color("reset"));
      print($colors{"warningNumberColor"},   "$field2:", color("reset"));
      srcscan($field3, $colors{"warningMessageColor"});
    }
    elsif ($field3 =~ m/\s+error:.*/)
    {
      # Error
      print($colors{"errorFileNameColor"}, "$field1:", color("reset"));
      print($colors{"errorNumberColor"},   "$field2:", color("reset"));
      srcscan($field3, $colors{"errorMessageColor"});
    } 
    else
    {
      # Note
      print($colors{"noteFileNameColor"}, "$field1:", color("reset"));
      print($colors{"noteNumberColor"}, "$field2:", color("reset"));
      srcscan($field3, $colors{"noteMessageColor"});
    }
    print("\n");
  }
  elsif (m/(.+):\((.+)\):(.*)$/) # linker error
  {
    my $field1 = $1 || "";
    my $field2 = $2 || "";
    my $field3 = $3 || "";

    # Error
    print($colors{"errorFileNameColor"}, "$field1", color("reset"), ":(");
    print($colors{"errorNumberColor"},   "$field2", color("reset"), "):");
    srcscan($field3, $colors{"errorMessageColor"});
    print("\n");
  }
  elsif (m/^:.+`.*'$/) # filename:message:
  {
    srcscan($_, $colors{"warningMessageColor"});
  }
  elsif (m/^(.*?):(.+):$/) # filename:message:
  {
    my $field1 = $1 || "";
    my $field2 = $2 || "";
    # No line number, treat as an "introductory" line of text.
    print($colors{"introFileNameColor"}, "$field1:", color("reset"));
    srcscan($field2, $colors{"introMessageColor"});
    print("\n");
  }
  else # Anything else.
  {
    # Doesn't seem to be a warning or an error. Print normally.
    print(color("reset"), $_);
  }
}
