package Alchemy::FileManager::Directories;

use strict;

use Apache2::Request;
use POSIX qw( strftime );
use File::Copy;
use File::Path;
use File::Find::Rule;

use KrKit::HTML qw( :all );
use KrKit::Validate;

use Alchemy::FileManager;

our @ISA = ( 'Alchemy::FileManager' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $k->_checkvals( $in ) 
#-------------------------------------------------
sub _checkvals {
	my ( $k, $in ) = @_;

	my @err;

	## Did we get a name (defined and an ident)
	if ( ! is_text( $$in{name} ) ) {
		push( @err, ht_li( {}, 	'You must provide some text for the',
								'directory name.' ) );
	}
	elsif ( ! is_ident( $$in{name} ) ) {
		push( @err, ht_li( {}, 	'You must supply a valid directory name.',
								'A valid directory must not contain ',
								'spaces or symbols.' ) );
	}

	## Does it already exist?
	my $dir = "$$in{path}/$$in{name}";
	$dir	=~ s/\/\//\//g;
	$dir	=~ s/^\///;
	$dir	=~ s/\/$//;
	if ( is_ident( $$in{name} )  && -e "$$k{dir}/$dir" ) {
		push( @err, ht_li( {}, "The directory /$dir already exists." ) );
	}

	## Uh-oh...
	if ( @err ) {
		return( ht_div( { 'class' => 'error' },
						ht_h( 1, 'Errors' ), ht_ul( {}, @err ) ) );
	}

	return();
} # END $k->_checkvals

#-------------------------------------------------
# $k->_fmt_entry( $base, $sort, $entry )       
#-------------------------------------------------
sub _fmt_entry {
	my ( $k, $base, $sort, $entry ) = @_;

	## The full uri 
	my $uri		= "$base/$entry";
	$uri		=~ s/\/\//\//g;
	$uri		=~ s/^\///;

	## The full path
	my $path	= "$$k{dir}/$uri";
	$path		=~ s/\/\//\//g;
	
	## Prepare for file sizes
	my %units = ( 	1024		=> 'kb',
					1024 ** 2	=> 'Mb',
					1024 ** 3	=> 'Gb' );

	## Prep the image links (again...)
	my $dirimg	= ht_img( $$k{dirimg}, 'alt="Directory" title="Directory"' );
	my $fileimg	= ht_img( $$k{txtimg}, 'alt="File" title="File"' );
	my $copyimg	= ht_img( $$k{copyimg}, 'alt="Copy" title="Copy"' );
	my $editimg	= ht_img( $$k{editimg}, 'alt="Edit" title="Edit"' );
	my $delimg	= ht_img( $$k{delimg}, 'alt="Delete" title="Delete"' );

	## Grab the stat for this entry
	my @stats = stat $path;
		
	## Is it a directory or a file
	my $link = '';
	if ( -d $path ) {
		$link = $dirimg. ht_a( "$$k{rootp}/main/$uri/$sort", $entry );
	}
	else {
		$link = $fileimg. ht_popup( "$$k{dirview}/$uri", $entry, 'ViewFile',
									'350', '350' );
	}

	my $apath 	= ( -d $path ) ? $$k{rootp} : $$k{rootf} ;		# Path
	my @actions = ( ht_a( "$apath/copy/$uri", $copyimg ), 		# Copy
					ht_a( "$apath/edit/$uri", $editimg ), 		# Edit
					ht_a( "$apath/delete/$uri", $delimg ) ); 	# Delete
	
	## Prepare the file sizing
	my $size = '';
	for my $u ( sort { $a <=> $b } keys %units ) {
		if ( $stats[7] >= $u ) {
			$size = ( $stats[7] / $u ); 
			$size =~ s/(\d*\.\d).*$/$1/;
			$size .= " $units{$u}";
		}
	}
	$size = $stats[7] . ' b' if ( $size eq '' );
	$size = '' if ( -d $path );

	## Permissions
	my $mode = $stats[2];
	my @perms = ( '---', '--x', '-w-', '-wx', 'r--', 'r-x', 'rw-', 'rwx' );
	$mode = sprintf( "%o", ( $stats[2] & 0777 ) );
	$mode =~ /^(.)(.)(.)$/;
	my $alloc = -d $path ? 'd' : '-';

	## Created and Modified times
	my @lines = (	ht_td( {}, ( ( -r $path ) ? $link : $entry ) ),	
					ht_td( {}, $size ),
					ht_td( {}, $alloc. $perms[$1]. $perms[$2]. $perms[$3] ),
					ht_td( {}, strftime( $$k{fmt_dt}, localtime $stats[10] ) ),
					ht_td( {}, strftime( $$k{fmt_dt}, localtime $stats[9] ) ) );

	if ( -r $path && -w $path ) {
		push( @lines, ht_td( { 'class' => 'rdta' }, @actions ) );
	}
	elsif ( -r $path ) {
		push( @lines, ht_td( { 'class' => 'rdta' }, $actions[0] ) );
	}
	else {
		push( @lines, ht_td( {}, '&nbsp;' ) );
	}

	return( ht_tr( {}, @lines ) );
} # END $k->_fmt_entry

#-------------------------------------------------
# $k->_form( $in ) 
#-------------------------------------------------
sub _form {
	my ( $k, $in ) = @_;

	## Our wonderful select array of paths....
	my @paths	= ();
	
	## Can we actually right to dirroot?
	push( @paths, '/', '/' ) if ( -w $$k{dir} );

	## Get the list of directories
	my @subdirs	= File::Find::Rule	-> directory
									-> relative
									-> not( File::Find::Rule
										-> name( @{$$k{showhidden}} ) )
									-> in( $$k{dir} );

	my @dirs	= sort { lc( $a ) cmp lc( $b ) } @subdirs;

	## Loop through and be sure to only include those that can be read and
	## written to
	for my $dir ( @dirs ) {
		if ( -r "$$k{dir}/$dir" && -w "$$k{dir}/$dir" ) {
			push( @paths, $dir, "/$dir" );
		}
	}

	return( ht_form_js( $$k{uri} ),
			ht_table(),

			ht_tr(),
			ht_td( { 'class' => 'hdr', 'colspan' => '2' }, 
					'Directory Data' ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Name:' ),
			ht_td( {},
					ht_input( 'name', 'text', $in, 'size="60"' ),
					ht_help( $k->{help}, 'item', 'a:fm:d:name' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Path:' ),
			ht_td( {},
					ht_select( 'path', 1, $in, '', '', @paths ),
					ht_help( $k->{help}, 'item', 'a:fm:d:path' ) ),
			ht_utr(),
					
			ht_tr(),
			ht_td( { 'class' => 'rshd', 'colspan' => '2' },
					ht_submit( 'save', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(), 
			ht_uform() );
} # END $k->_form

#-------------------------------------------------
# $k->do_add( $r, @p )
#-------------------------------------------------
sub do_add {
	my ( $k, $r, @p ) = @_;

	$$k{page_title}	.= ' Add Directory';

	my $in 		= $k->param( Apache2::Request->new( $r ) );
	my $base	= join( '/', @p );
	my $dir		= $$k{dir};

	$dir		= "$$k{dir}/$base" if ( $base );
	$dir		=~ s/\/\//\//g;

	return( $k->_relocate( $r, "$$k{rootp}/main/$base" ) ) if ( $$in{cancel} );

	if ( ! ( my @err = $k->_checkvals( $in ) ) ) {
		## Must be 'good'
		my $fullname	= "$$k{dir}/$$in{path}/$$in{name}";
		$fullname		=~ s/\/\//\//g;
		
		## Make the directory
		mkdir( $fullname, $$k{dperm} ) ||
			return( ht_div( { 'class' => 'error' } ),
					"Unable to create directory: $!\n",
					ht_udiv() );

		## Set the permissions - to be sure....
		system( $$k{chmod}, $$k{dperm}, $fullname );
		system( $$k{chgrp}, $$k{group}, $fullname );
		
		## Return them to the new directory
		my $newpath	= "$$k{rootp}/main/$$in{path}/$$in{name}";
		$newpath	=~ s/\/\//\//g;
		
		return( $k->_relocate( $r, $newpath ) );
	}
	else {
		## Defaults
		$$in{path}	= $base if ( ! defined $$in{path} );

		return( ( $r->method eq 'POST' ? @err : '' ), $k->_form( $in ) );
	}
} # END $k->do_add

#-------------------------------------------------
# $k->do_edit( $r, @p )
#-------------------------------------------------
sub do_edit {
	my ( $k, $r, @p ) = @_;

	$k->{page_title}	.= ' Edit Directory';

	my $in 				= $k->param( Apache2::Request->new( $r ) );
	my $origbase		= join( '/', @p );
	my $name			= pop( @p );
	my $base			= join( '/', @p );
	my $dir				= $$k{dir};
	my $origdir			= $$k{dir};

	$origbase			=~ s/\/\//\//g;
	$dir				= "$$k{dir}/$base" 		if ( $base );
	$origdir			= "$$k{dir}/$origbase" 	if ( $origbase );
	$dir				=~ s/\/\//\//g;
	$origdir			=~ s/\/\//\//g;

	return( $k->_relocate( $r, "$$k{rootp}/main/$base" ) ) if ( $$in{cancel} );

	## Does the directory exist?
	if ( ! -e $dir || ! -d $dir ) {
		return( ht_div( { 'class' => 'error' } ),
				'Directory does not exist',
				ht_udiv() );
	}

	## Can we write to it?
	if ( ! -w $dir ) {
		return( ht_div( { 'class' => 'error' } ),
				"Unable to edit directory $name",
				ht_udiv() );
	}
	
	if ( ! ( my @err = $k->_checkvals( $in ) ) ) {
		## Must be 'good'
		my $fullname	= "$$k{dir}/$$in{path}/$$in{name}";
		$fullname		=~ s/\/\//\//g;

		## Move the directory - still 'easiest' to use File function
		move( $origdir, $fullname ) ||
			return( ht_div( { 'class' => 'error' } ),
					"Unable to rename/move directory: $!\n",
					ht_udiv() );

		## Set the permissions - to be sure....
		system( $$k{chmod}, $$k{dperm}, $fullname );
		system( $$k{chgrp}, $$k{group}, $fullname );

		## Return to the new directory
		my $newpath	= "$$k{rootp}/main/$$in{path}/$$in{name}";
		$newpath	=~ s/\/\//\//g;

		return( $k->_relocate( $r, $newpath ) );
	}
	else {
		## Defaults
		$$in{origname}		= $name; ## For checkvals
		$$in{path}			= $base	if ( ! defined $$in{path} );
		$$in{name}			= $name if ( ! defined $$in{name} );
		
		return( ( $r->method eq 'POST' ? @err : '' ), $k->_form( $in ) );
	}
} # END $k->do_edit

#-------------------------------------------------
# $k->do_copy( $r, @p )
#-------------------------------------------------
# Copy an existing directory and its contents
# Also provides ability to modify path and name
#-------------------------------------------------
sub do_copy {
	my ( $k, $r, @p ) = @_;

	$$k{page_title}	.= ' Copy Directory';
	
	my $in 			= $k->param( Apache2::Request->new( $r ) );
	my $base		= join( '/', @p );
	my $name		= pop( @p );
	my $up			= join( '/', @p );
	my $dir			= $$k{dir};

	$dir			= "$$k{dir}/$base" if ( $base );
	$dir			=~ s/\/\//\//g;
	
	my $upone		= "$$k{rootd}/main/$up";
	$upone			=~ s/\/\//\//g;


	$$in{origname}		= $name;
	$$in{path}			= $up if ( ! defined $$in{path} );

	return( $k->_relocate( $r, $upone ) ) if ( $$in{cancel} );

	## Does the directory exist?
	if ( ! -e $dir || ! -d $dir ) {
		return( ht_div( { 'class' => 'error' } ),
				'Directory does not exist',
				ht_udiv() );
	}
	
	if ( ! ( my @err = $k->_checkvals( $in ) ) ) {
		
		## Get the list of subdirectories
		my @tdirs	= File::Find::Rule	-> directory
										-> in( $dir );

		my @dirs	= sort { lc( $a ) cmp lc( $b ) } @tdirs;

		## Now we have to create each subdir and copy over its contents
		for my $source ( @dirs ) {

			## Replace the base with the new path and name
			my $target	= $source;
			$target		=~ s/$dir/$$in{path}\/$$in{name}/;
			$target		=~ s/\/\//\//g;
			$target		= "$$k{dir}/$target";
			$target		=~ s/\/\//\//g;

			if ( ! -e $target && ! mkpath( [ $target ], 0, 0775 ) ) {
					return( ht_div( { 'class' => 'error' } ),
							"Unable to create directory: $!", 
							ht_udiv() );
			}

			## Now 'correct' the permissions
			system( $$k{chmod}, $$k{dperm}, $target );
			system( $$k{chgrp}, $$k{group}, $target );

			## Copy over the contents of the source to the target
			my @files	= File::Find::Rule	-> file
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> in( $source );

			for my $fsource ( @files ) {
				## Update the path for the target
				my $ftarget	= $fsource;
				$ftarget	=~ s/$dir/$$in{path}\/$$in{name}/;
				$ftarget	=~ s/\/\//\//g;
				$ftarget	= "$$k{dir}/$ftarget";
				$ftarget	=~ s/\/\//\//g;

				if ( ! copy( $fsource, $ftarget ) ) {
					return( ht_div( { 'class' => 'error' } ),
							"Unable to create file: $!",
							ht_udiv() );
				}

				## Again, fix the permissions
				system( $$k{chmod}, $$k{fperm}, $ftarget );
				system( $$k{chgrp}, $$k{group}, $ftarget );
			}
		}			
		
		my $last	= "$$k{rootp}/main/$$in{path}";
		$last		=~ s/\/\//\//g;
		
		return( $k->_relocate( $r, $last ) );
	}
	else {
		my $num		= '';
		my $tname	= "Copy$num" . "_of_$name";

		while ( -e "$$k{rootd}$$in{path}/$tname" ) {
			$num	= $num ? $num + 1 : 1;
			$tname	= "Copy$num" . "_of_$name";
		}
		
		$in->{name}	= $tname if ( ! $in->{name} );

		return( ( $r->method eq 'POST' ? @err : '' ), $k->_form( $in ) );
	}
} # END $k->do_copy

#-------------------------------------------------
# $k->do_delete( $r, @p )
#-------------------------------------------------
sub do_delete {
	my ( $k, $r, @p ) = @_;

	$$k{page_title} .= ' Delete Directory';

	my $in 		= $k->param( Apache2::Request->new( $r ) );
	my $base	= join( '/', @p );
	my $name	= pop( @p );
	my $up		= join( '/', @p );
	my $dir		= $$k{dir};

	$dir		= "$$k{dir}/$base" if ( $base );
	$dir		=~ s/\/\//\//g;

	my $upone	= "$$k{rootd}/main/$up";
	$upone		=~ s/\/\//\//g;
	
	## Make sure that cancel takes us to where we were, not to the location
	## that we were trying to delete...
	return( $k->_relocate( $r, $upone ) ) if ( $$in{cancel} );

	## Does the directory exist?
	if ( ! -e $dir || ! -d $dir ) {
		return( ht_div( { 'class' => 'error' } ),
				'Directory does not exist',
				ht_udiv() );
	}

	## The directories should be empty in order to remove
	my @files	= File::Find::Rule	-> file
									-> in( $dir );
	
	## Get the list of subdirectories
	my @tdirs	= File::Find::Rule	-> directory
									-> in( $dir );
	
	## Sort in reverse order so that subdirectories are deleted first
	my @dirs	= sort { lc( $b ) cmp lc( $a ) } @tdirs;

	if ( defined $$in{yes} && $$in{yes} =~ /yes/ ) {
		
		## Delete the files, if they exist
		if ( @files ) {
			unlink( @files ) ||
				return( ht_div( { 'class' => 'error' } ),
						"Unable to remove all of the files: $!\n",
						ht_udiv() );
		}
		
		## Don't forget the directory in question
	
		while ( my $sdir = shift( @dirs ) ) {
			## Prep the name of the directory - in case we 'flail'
			my $tdir = $sdir;
			$tdir =~ s/$$k{dir}//;
			
			if ( ! -w $sdir ) {
				return( ht_div( { 'class' => 'error' } ),
						"Do not have permissions to remove $tdir: $!\n",
						ht_udiv() );
			}
			
			## Delete the directories
			rmdir( $sdir ) ||
				return( ht_div( { 'class' => 'error' } ),
						"Unable to remove directory $tdir: $!\n",
						ht_udiv() );
		}
	
		return( $k->_relocate( $r, $upone ) );
	}
	else {
		return( ht_form_js( $k->{uri} ),
				ht_input( 'yes', 'hidden', { 'yes', 'yes' } ),
				ht_table(),

				ht_tr(),
				ht_td( { 'class' => 'dta' },
						'Delete the directory: ', ht_b( "/$base" ) . 
						'? This will completely remove this directory and ',
						'all of its contents permanently from the system.' ),
				ht_utr(),

				ht_tr(),
				ht_td( { 'class' => 'dta' },
						'There are currently', scalar( @files ), 'files,',
						'contained somewhere in', scalar( @dirs ),
						"directories (includes /$base)" ),
				ht_utr(),
				
				ht_tr(),
				ht_td( { 'class' => 'rshd' },
					ht_submit( 'submit', 'Delete' ),
					ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),

				ht_utable(),
				ht_uform() );
	}
} # END $k->do_delete

#-------------------------------------------------
# $k->do_main( $r, @p )
#-------------------------------------------------
sub do_main {
	my ( $k, $r,  @p ) = @_;

	$$k{page_title} .= ' Directory Contents';

	## Identify the sorting 
	my $sort	= pop( @p );
	$sort		= 0 if ( ! $sort );
	
	## If sort isn't 1 or 0 - then we don't have a sort
	if ( $sort ne '0' && $sort ne '1' ) {
		push( @p, $sort ); 		## put it back on @p
		$sort			= 0; 	## Set the sort
	}

	## Prepare the linkage
	my ( $base, $up )	= ( '', '' );
	$base				= join( '/', @p );
	pop( @p );
	$up					= join( '/', @p );

	my $dir 	= ( $base ) ? "$$k{dir}/$base" : $$k{dir} ;
	$dir		=~ s/\/\//\//g;
	my $upone	= "$$k{rootd}/main/$up";
	$upone		=~ s/\/\//\//g;

	## For those 'savy' enough, we will allow the ability to 'attempt' to
	## read a directory that will not show up of it's own accord - this is
	## for the admins

	## Does the directory exist?
	if ( ! -e $dir || ! -d $dir ) {
		return( ht_div( { 'class' => 'error' }, 'Directory does not exist' ) );
	}

	## Can we read from it?
	if ( ! -r $dir ) {
		return( ht_div( { 'class' => 'error' }, 
						"Unable to read from directory $base" ) );
	}

	## Prep the images
	my $upimg	= ht_img( $$k{upimg}, 'alt="Up Dir" title="Up One Directory"' );
	my $addfldr	= ht_img( $$k{folderimg}, 
							'alt="Directory" title="New Directory"' );
	my $addfile	= ht_img( $$k{fileimg}, 'alt="File" title="New File"' );
	my $upload	= ht_img( $$k{uploadimg}, 'alt="Upload" title="Upload File"' );

	## Get the directories
	my @subdirs = File::Find::Rule	-> directory
									-> relative
									-> maxdepth( 1 )
									-> mindepth( 1 )
									-> not( File::Find::Rule
										-> name( @{$$k{showhidden}} ) )
									-> in( $dir );
	
	## Sorting....
	my @dirs;
	if ( ! $sort ) {
		@dirs	= sort { lc( $a ) cmp lc( $b ) } @subdirs;
	}
	else {
		@dirs	= sort { lc( $b ) cmp lc( $a ) } @subdirs;
	}
	
	## And the files....
	my @subfiles = File::Find::Rule	-> file
									-> relative
									-> maxdepth( 1 )
									-> mindepth( 1 )
									-> not( File::Find::Rule
										-> name( @{$k->{showhidden}} ) )
									-> in( $dir );

	## Sorting....
	my @files;
	if ( ! $sort ) {
		@files		= sort { lc( $a ) cmp lc( $b ) } @subfiles;
	}
	else {
		@files		= sort { lc( $b ) cmp lc( $a ) } @subfiles;
	}

	## Build the upone link - if this is docroot, nevermind...

	## Remember to flip the sorting bit for the sorting link
	$sort = $sort ? 0 : 1;

	## Begin the page
	my @lines = (
		ht_table(),
	
		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '6' },
				( ( $base eq '' ) ? '' : ht_a( $upone, $upimg ) ),
				ht_a( "$$k{rootp}/add/$base", $addfldr ),
				ht_a( "$$k{rootf}/add/$base", $addfile ),
				ht_a( "$$k{rootf}/upload/$base", $upload ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '6' }, 
				'Files for: ' . ht_b( "/$base" ) ),
		ht_utr(),
		
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 
				ht_a( "$$k{rootp}/main/$base/$sort", 'Name' ),
				ht_help( $$k{help}, 'item', 'a:fm:d:name' ) ),
		ht_td( { 'class' => 'shd' }, 'Size',
				ht_help( $$k{help}, 'item', 'a:fm:d:size' ) ),
		ht_td( { 'class' => 'shd' }, 'Perms',
				ht_help( $$k{help}, 'item', 'a:fm:d:perms' ) ),
		ht_td( { 'class' => 'shd' }, 'Created',
				ht_help( $$k{help}, 'item', 'a:fm:d:created' ) ),
		ht_td( { 'class' => 'shd' }, 'Modified',
				ht_help( $$k{help}, 'item', 'a:fm:d:modified' ) ),
		ht_td( { 'class' => 'shd' }, 'Action',
				ht_help( $$k{help}, 'item', 'a:fm:d:action' ) ),
		ht_utr() );

	## strip out those pesky //'s
	map { s/\/\//\//g => $_ } @lines;
	
	## Remember to flip the sorting bit for the other links (maintain the sort)
	$sort = $sort ? 0 : 1;

	## Store the results from the dirs and files
	my ( @flines, @dlines ) = ( (), () );
	
	## Display the directories
	for my $d ( @dirs ) {
		push( @dlines, $k->_fmt_entry( $base, $sort, $d ) );
	}
	
	## Display the files
	for my $f ( @files ) {
		push( @flines, $k->_fmt_entry( $base, $sort, $f ) );
	}
	
	if ( ! @dirs && ! @files ) {
		push( @lines, 	ht_tr(),
						ht_td( { 'colspan' => '6' },
								'No files or directories found' ),
						ht_utr() );
	}
	else {
		if ( ! $sort ) {
			push( @lines, @dlines, @flines );
		}
		else {
			push( @lines, @flines, @dlines );
		}
	}
	
	return( @lines, ht_utable() );
} # END $k->do_main

# EOF
1;

__END__

=head1 NAME

FileManager - Perl extension for Directory Management 

=head1 SYNOPSIS

  use Alchemy::FileManager::Directories;

=head1 DESCRIPTION

This module provides an interface for list, edit, create, and delete with
respect to the directories available within the configuration specified
root directory and it's childern. It provides links into the File module for
those files listed in each respective directory. If a directory has read and
write permissions for the server user, then a link to edit, delete, and copy
will appear - if only read permissions, only copy will appear (for both of
these previous options, the ability to go into the subdirectory also occurs) -
for those files that r/w is not permissible, then the directory does not 
appear.

=head1 DEPENDENCIES

  ## Directories
  use Apache2::Request
  use POSIX qw( strftime )
  use File::Copy
  use File::Path
  use File::Find::Rule
  use KrKit::Control
  use KrKit::Handler
  use KrKit::HTML qw( :all )
  use KrKit::Validate

=head1 APACHE

<Location / >
  ## PerlSetVars
  PerlSetVar  Date_Format
  PerlSetVar  Time_Format
  PerlSetVar  DateTime_Format
  
  PerlSetVar  FM_DirRoot       "/admin/fm/directories"
  PerlSetVar  FM_FileRoot      "/admin/fm/files"        #Required
  PerlSetVar  FM_DirPerm       "2775"
  PerlSetVar  FM_FilePerm      "664"
  PerlSetVar  FM_DocRoot       "/var/www/html"
  PerlSetVar  FM_chmod         "/bin/chmod"
  PerlSetVar  FM_chgrp         "/bin/chgrp"             
  PerlSetVar  FM_Group         "web"                    #Required
  
  PerlSetVar  FM_Image_URI     "/admin/fm/images"       #Required
  PerlSetVar  FM_Copy_Image    "copy.jpg"               #Required
  PerlSetVar  FM_Delete_Image  "delete.jpg"             #Required
  PerlSetVar  FM_Edit_Image    "edit.jpg"               #Required
  PerlSetVar  FM_File_Image    "file.jpg"               #Required
  PerlSetVar  FM_Folder_Image  "folder.jpg"             #Required
  PerlSetVar  FM_UpDir_Image   "updir.jpg"              #Required
  PerlSetVar  FM_Upload_Image  "upload.jpg"             #Required
  PerlSetVar  FM_Dir_Image     "dir.jpg"                #Required
  PerlSetVar  FM_Text_Image    "text.jpg"               #Required

  PerlSetVar  FM_ShowHidden    "1"
</Location>

<Location /admin/fm/directories >
    SetHandler    modperl

    PerlSetVar    SiteTitle    "FileManager - "
    
    PerlHandler   Alchemy::FileManager::Directories
</Location>

=head1 VARIABLES

FM_DirRoot

    The directory module url

FM_FileRoot

    The file module url

FM_DirPerm

    The directory permissions to be applied when creating/editing

FM_FilePerm

    The file permissions to be applied when creating/editing

FM_DocRoot

    The document root for the FileManager

FM_chmod

    The full path to the chmod program - for updating permissions on
    files and directories created by the FileManager

FM_chgrp

    The full path to the chgrp program - for updating permissions on
    files and directories created by the FileManager

FM_Group

    The group to assign as owner of files and directories created by the
    FileManager

FM_Image_URI

    The uri (path) to the images for the directory display
	
FM_Copy_Image

    The copy icon
	
FM_Delete_Image

    The delete icon
	
FM_Edit_Image

    The edit icon
	
FM_File_Image

    The file icon
	
FM_Folder_Image

    The folder icon
	
FM_UpDir_Image

    The up one directory icon
	
FM_Upload_Image

    The upload icon
	
FM_Dir_Image

    The directory icon
	
FM_Text_Image

    The text icon
	
FM_ShowHidden

    Indicates whether or not to display hidden files, those prepended
    with a dot '.' - like .bash
    1 indicates show hidden files, 0 indicates to not
	
=head1 DATABASE

None by default.

=head1 FUNCTIONS

This module provides the following functions:

$k->do_add( $r, @ident )
    
    Adds a new directory to the filesystem

$k->do_edit( $r, @ident )

    Edits an existing directory - provides the ability to change the 
    name and path

$k->do_copy( $r, @ident )

    Copies an existing directory and all of its contents - provides 
    the ability to give it a new name and path

$k->do_delete( $r, @ident, $yes )

    Deletes an existing directory and all of its contents - requires 
    confirmation

$k->do_main( $r, @ident )

    Provides a listing of all directories - starts at the root 
    directory specified in the configuration file and provides 
    links to descend the heirarchy

=head1 SEE ALSO

Alchemy::FileManager(3), KrKit(3), perl(3)

=head1 LIMITATIONS

None defined at this point...

=head1 AUTHOR

Ron Andrews <ron.andrews@cognilogic.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ron Andrews. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.


=cut
