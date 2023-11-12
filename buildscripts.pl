####################################################
# This file contains the default configuration and #
# some helper functions for the build process.     #
# It is meant to be included in latexmkrc          #
# from the root directory of the project.          #
####################################################

use Cwd;
use File::Copy;
use File::Path;
use File::Basename;


#####################################
# Default config for build process. #
#####################################

# directory structure:
$rootdir = getcwd;
$srcdir = "$rootdir/texsrc";
$packagesdir = "$srcdir/packages";
$examplesdir = "$srcdir/examples";
$builddir = "$rootdir/build"; # where to put the pdf files created.

# detail settings for latexmk.
$out_dir = "build"; # use a local build directory
$pdf_mode = 4; # use lualatex
$lualatex = 'internal buildfile %O %S'; # use the buildfile function defined below
$do_cd = 1; # change to the directory of the main file before building
$clean_ext = 'snm nav synctex.gz'; # extensions to be removed by the clean command

# build options:
$buildoptions = "-interaction=nonstopmode";
@build_extensions = qw(tex);


####################################################
# Functions for adding files to the build process. #
####################################################

# Initialize the list of files to be built for latexmk.
@default_files = ();

# addfiles adds files to the list of files to be built.
# Expects a directory name as the first argument,
# followed by a list of filenames.
sub addfilesfromdir {
    my ($dirname, @filenames) = @_;
    for $filename (@filenames) {
        # check if the file exists
        if (! -e "$dirname/$filename") {
            die "File $dirname/$filename does not exist.";
        }
        @default_files = (
            @default_files,
            "$dirname/$filename"
        );
    }
}

# adddir expects a directory name and a list of extensions.
# All files in the directory with one of the given extensions are added.
sub addextensionsfromdir {
    my ($dirname, @extensions) = @_;
    
    # Replace the directory name with its relative path.
    $dirname = relpath($dirname);
    
    # Remove leading dots from the extensions.
    @extensions = map { s/^\.//; $_ } @extensions;
    
    # Open directory and read file names.
    opendir my $dir, $dirname or die "Failed to open directory $dirname: $!";
    my @files = readdir $dir;
    closedir $dir;

    # Remove directories and dotfiles.
    @files = grep { !/^\./ && !-d "$dirname/$_" } @files;

    # Filter files by the extension list.
    my @filestoadd = ();
    for $file (@files) {
        for $extension (@extensions) {
            if ($file =~ /[.]$extension$/) {
                push @filestoadd, $file;
            }
        }
    }
    
    # Add files to the list of files to be built.
    addfilesfromdir($dirname, @filestoadd);
}

# add_directory expects a directory name and adds all files in that directory
# with one of the extensions in @build_extensions.
sub add_directory {
    my $dirname = shift;
    addextensionsfromdir($dirname, @build_extensions);
}

# add_example expects a list of directory names below $examplesdir
# and adds all files in each directory.
sub add_examples {
    my @dirnames = @_;
    for $dirname (@dirnames) {
        # check if the directory exists and is below $examplesdir
        if (! -d "$examplesdir/$dirname") {
            die "Directory $examplesdir/$dirname does not exist.";
        }
        add_directory("$examplesdir/$dirname");
    }
}


################################################
# Functions for controlling the build process. #
################################################

# targetdir computes the actual target directory by appending
# the current working dir's relative path to $builddir.
sub targetdir {
    my $relcwd = relpath(getcwd);
    return "$builddir/$relcwd";
}

# buildfile is a wrapper around lualatex that copies the pdf to the target directory.
sub buildfile {
    # Create output directory if it doesn't exist.
    File::Path::make_path($out_dir) or die "Failed to create path $out_dir: $!" unless -d $out_dir;

    # Put a .gitignore in $out_dir so that that directory is not tracked.
    open my $gitignore, '>', "$out_dir/.gitignore" or die "Failed to open $out_dir/.gitignore: $!";
    print $gitignore "# Automatically generated by latexmkrc\n";
    print $gitignore "*\n";
    close $gitignore;

    # build with @buildoptions
    my @args = @_;
    # prepend buildoptions to the arguments
    unshift @args, $buildoptions;
    my $result = system 'lualatex', @args;

    # copy pdf to target directory if it exists
    my $pdf = "$out_dir/$args[-1]";
    $pdf =~ s/\.tex$/.pdf/;
    if (-e $pdf) {
        # create target directory if it doesn't exist
        my $target_dir = targetdir;
        File::Path::make_path($target_dir) or die "Failed to create path $target_dir: $!" unless -d $target_dir;
        
        # copy pdf to target directory
        File::Copy::copy($pdf, $target_dir) or die "Failed to copy $pdf to $target_dir: $!";
        print "Copied PDF to $target_dir.\n";
    }
    return $result;
}


##############################
# General helper functions.  #
##############################

# relpath computes the relative path from $rootdir to the given path.
sub relpath {
    my $path = shift;
    $path =~ s/^$rootdir\///;
    return $path;
}