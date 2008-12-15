package Alchemy::FileManager::Files;

use strict;

use Apache2::Request;
use Apache2::Upload;
use POSIX qw( strftime );
use File::Copy;
use File::Find::Rule;

use KrKit::HTML qw( :all );
use KrKit::Validate;

use Alchemy::FileManager;
	
our @ISA = ( 'Alchemy::FileManager' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $k->do_add( $r, @p )
#-------------------------------------------------
sub do_add {
	my ( $k, $r, @p ) = @_;

	$k->{page_title}	.= ' Add File';
	
	my $in 				= $k->param( Apache2::Request->new( $r ) );
	my $base			= join( '/', @p );
	my $dir				= $k->{dir};

	$dir				= "$k->{dir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	## Return them to the base
	if ( $in->{cancel} ) {
		return( $k->_relocate( $r, "$k->{rootd}/main/$base" ) );
	}

	## Just so that we know where we are in checkvals and the form
	$in->{op}	= 'add';

	if ( ! ( my @err = $k->file_checkvals( $in ) ) ) {
		## Must be 'good'
		my $target	= "$k->{dir}/$in->{path}/$in->{name}";
		$target		=~ s/\/\//\//g;

		## Create the new file
		if ( ! open( FILE, ">$target" ) ) {
			return( ht_div( { 'class' => 'error' }, 
							"Unable to create file: $!\n" ) );
		}

		print FILE $in->{content};

		close( FILE );

		## Tend to the permissions
		# perldoc -f chmod ?
		system( $k->{chmod}, $k->{fperm}, $target );
		system( $k->{chgrp}, $k->{group}, $target );

		## Send them to whatever path they had chosen
		my $newpath		= "$k->{rootd}/main/$in->{path}";
		$newpath		=~ s/\/\//\//g;
		
		return( $k->_relocate( $r, $newpath ) );
	}
	else {
		## Defaults
		$in->{path}	= $base	if ( ! defined $in->{path} );
		$in->{name}	= ''	if ( ! defined $in->{name} );
		
		return( ( $r->method eq 'POST' ? @err : '' ), $k->file_form( $in ) );
	}
} # END $k->do_add

#-------------------------------------------------
# $k->do_edit( $r, @p )
#-------------------------------------------------
sub do_edit {
	my ( $k, $r, @p ) = @_;

	$k->{page_title}	.= ' Edit File';

	my $in 				= $k->param( Apache2::Request->new( $r ) );
	my $name			= pop( @p );
	my $base			= join( '/', @p );
	my $dir				= $k->{dir};

	$dir				= "$k->{dir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;
	
	if ( $in->{cancel} ) {
		return( $k->_relocate( $r, "$k->{rootd}/main/$base" ) );
	}
	
	## Does the file exist?
	if ( ! -e "$dir/$name" || ! -f "$dir/$name" ) {
		return( ht_div( { 'class' => 'error' }, 'File does not exist' ) );
	}

	## Can we write to it?
	if ( ! -w "$dir/$name" ) {
		return( ht_div( { 'class' => 'error' }, "Unable to edit file $name" ) );
	}
	
	## Just so that we know where we are in checkvals and the form
	$in->{op}		= 'edit';

	if ( ! ( my @err = $k->file_checkvals( $in ) ) ) {
		
		my $source	= "$dir/$name";
		my $target	= "$k->{dir}/$in->{path}/$in->{name}";
		$source		=~ s/\/\//\//g;
		$target		=~ s/\/\//\//g;

		## If we are changing the name or moving the file - do so first
		if ( $in->{name} ne $name || $in->{path} ne $base ) {
			
			if ( ! move( $source, $target ) ) {
				return( ht_div( { 'class' => 'error' },
								"Unable to rename/move the file: $!" ) );
			}
		}

		## If it is not a text file, we are done - otherwise, deal with the
		## content
		if ( -T $target && ! -B $target ) {
			if ( ! open( FILE, ">$target" ) ) {
				return( ht_div( { 'class' => 'error' },
								"Unable to edit the file: $!\n" ) );
			}

			print FILE $in->{content};

			close( FILE );
		}

		## Tend to the permissions
		system( $k->{chmod}, $k->{fperm}, $target );
		system( $k->{chgrp}, $k->{group}, $target );

		return( $k->_relocate( $r, "$k->{rootd}/main/$in->{path}" ) );
	}
	else {
		## Defaults
		$in->{path}		= $base if ( ! defined $in->{path} );
		$in->{origpath}	= $base;
		$in->{name}		= $name if ( ! defined $in->{name} );
		$in->{origname}	= $name;
		
		## If this is a text file, read in the content
		my $source	= "$k->{dir}/$in->{origpath}/$in->{origname}";
		$source		=~ s/\/\//\//g;
		
		if ( -T $source && ! -B $source && ! defined $in->{content} ) {
			if ( ! open( FILE, "<$source" ) ) {
				return( ht_div( { 'class' => 'error' },
								"Unable to read the file: $!\n" ) );
			}

			my @file = <FILE>;

			close( FILE );

			## This is to fix leading spaces from the text
			my $fcontent = '';
			foreach ( @file ) {
				chomp;
				$fcontent .= $_;
			}

			$in->{content} = $fcontent;
		}

		return( ( $r->method eq 'POST' ? @err : '' ), $k->file_form( $in ) );
	}
} # END $k->do_edit

#-------------------------------------------------
# $k->do_upload( $r, @p )
#-------------------------------------------------
# Add a new file
#   Give it a name and location
#-------------------------------------------------
sub do_upload {
	my ( $k, $r, @p ) = @_;

	$k->{page_title}	.= ' Upload File';
	
	my $apr				= Apache2::Request->new( $r, 
							TEMP_DIR => $k->{file_tmp} );
	my $in				= $k->param( $apr );
	my $base			= join( '/', @p );
	my $dir				= $k->{dir};

	$dir				= "$k->{dir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	$in->{path}			= $base if ( ! defined $in->{path} );

	if ( $in->{cancel} ) {
		return( $k->_relocate( $r, "$k->{rootd}/main/$base" ) );
	}

	## Does the directory exist?
	if ( ! -e $dir || ! -d $dir ) {
		return( ht_div( { 'class' => 'error' }, 'Directory does not exist' ) );
	}

	## Can we write to it?
	if ( ! -w $dir ) {
		return( ht_div( { 'class' => 'error' },
						'Unable to write file to directory' ) );
	}

	if ( ! ( my @err = upload_checkvals( $in, $apr ) ) ) {
		
		my $now				= time;
		my $upload			= $apr->upload( 'file' );
		my ( $t, $fname )	= $upload->filename =~ /^(.*\\|.*\/)?(.*?)?$/;
		$fname				=~ s/--/-/g;

		my $target = "$k->{dir}/$in->{path}/$fname";
		$target		=~ s/\/\//\//g;
		
		open( FILE, ">$target" ) ||
			return( ht_div( { 'class' => 'error' },
							"Unable to create $in->{path}/$fname: $!\n" ) );

		my $fh = $upload->fh;
	
		while ( my $part = <$fh> ) {
			print FILE $part;
		}

		close( FILE );

		## Tend to the permissions
		system( $k->{chmod}, $k->{fperm}, $target );
		system( $k->{chgrp}, $k->{group}, $target );
		
		return( $k->_relocate( $r, "$k->{rootd}/main/$in->{path}" ) );
	}
	else {
		$in->{path} = $base;

		return( ( $r->method eq 'POST' ? @err : '' ), $k->upload_form( $in ) );
	}
} # END $k->do_upload

#-------------------------------------------------
# $k->do_copy( $r, @p )
#-------------------------------------------------
sub do_copy {
	my ( $k, $r, @p ) = @_;

	$k->{page_title}	.= ' Copy File';

	my $in				= $k->param( Apache2::Request->new( $r ) );
	my $name			= pop( @p );
	my $base			= join( '/', @p );
	my $dir				= $k->{dir};

	$dir				= "$k->{dir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	if ( $in->{cancel} ) {
		return( $k->_relocate( $r, "$k->{rootd}/main/$base" ) );
	}
	
	## Does the file exist?
	if ( ! -e "$dir/$name" || ! -f "$dir/$name" ) {
		return( ht_div( { 'class' => 'error' }, 'File does not exist' ) );
	}

	## Can we read the file for copy?
	if ( ! -r "$dir/$name" ) {
		return( ht_div( { 'class' => 'error' },
						"Unable to read /$base/$name for copying" ) );
	}

	## We may as well be using 'edit'
	$in->{op}		= 'edit';
	
	if ( ! ( my @err = file_checkvals( $k, $in ) ) ) {

		my $target	= "$k->{dir}/$in->{path}/$in->{name}";
		my $source	= "$k->{dir}/$base/$name";
		$target		=~ s/\/\//\//g;
		$source		=~ s/\/\//\//g;

		if ( -T $source ) { # If the *SOURCE* is text then print.
			open( FILE, ">$target" ) ||
				return( ht_div( { 'class' => 'error' }, 
								"Unable to create file: $!") );

			print FILE $in->{content};

			close( FILE );
		}
		else {
			copy( $source, $target ) ||
				return( ht_div( { 'class' => 'error' },
								"Unable to create file: $!" ) );
		}

		## Tend to the permissions
		system( $k->{chmod}, $k->{fperm}, $target );
		system( $k->{chgrp}, $k->{group}, $target );

		return( $k->_relocate( $r, "$k->{rootd}/main/$in->{path}" ) );
	}
	else {
		## Defaults
		$in->{path}		= $base if ( ! defined $in->{path} );
		$in->{origpath}	= $base;

		## The name takes a little special care....
		my $num			= 0;
		my $temp		= "Copy_of_$name";

		while ( -e "$dir/$temp" ) {
			$num++;
			$temp		= "Copy$num" . "_of_$name";
		}
		
		$in->{name}		= $temp if ( ! defined $in->{name} );
		$in->{origname}	= $name;

		## If this is a text file, read in the content
		my $source		= "$k->{dir}/$in->{origpath}/$in->{origname}";
		$source			=~ s/\/\//\//g;

		if ( -T $source && ! -B $source && ! defined $in->{content} ) {
			open( FILE, "<$source" ) ||
				return( ht_div( { 'class' => 'error' } ),
						"Unable to read the file: $!",
						ht_udiv() );

			my @file = <FILE>;

			close( FILE );

			$in->{content} = "@file";
		}

		return( ( $r->method eq 'POST' ? @err : '' ), $k->file_form( $in ) );
	}
} # END $k->do_copy

#-------------------------------------------------
# $k->do_delete( $r, @p )
#-------------------------------------------------
# Delete an existing file
#-------------------------------------------------
sub do_delete {
	my ( $k, $r, @p ) = @_;

	$k->{page_title} .= ' Delete File';

	my $in 	= $k->param( Apache2::Request->new( $r ) );
	my $name			= pop( @p );
	my $base			= join( '/', @p );
	my $dir				= $k->{dir};

	$dir				= "$k->{dir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	if ( defined $in->{cancel} ) {
		return( $k->_relocate( $r, "$k->{rootd}/main/$base" ) );
	}
	
	## Does the file exist?
	if ( ! -e "$dir/$name" || ! -f "$dir/$name" ) {
		return( ht_div( { 'class' => 'error' }, 'File does not exist' ) );
	}

	## Can we write to it?
	if ( ! -w "$dir/$name" ) {
		return( ht_div( { 'class' => 'error' },
						"Unable to delete file $name" ) );
	}

	if ( defined $in->{yes} && $in->{yes} =~ /yes/i ) {
		
		unlink( "$dir/$name" ) ||
			return( ht_div( { 'class' => 'error' },
							"Unable to delete file $name: $!\n" ) );

		return( $k->_relocate( $r, "$k->{rootd}/main/$base" ) );
	}
	else {
		return( ht_form_js( $k->{uri} ),
				ht_input( 'yes', 'hidden', { 'yes', 'yes' } ),
				ht_table(),

				ht_tr(),
				ht_td( {},
						'Delete the file: ', ht_b( $name ), '? This ',
						'will completely remove this file from the system.' ),
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
# upload_checkvals( $in, $apr )
#-------------------------------------------------
sub upload_checkvals {
	my ( $in, $apr ) = @_;

	my @errors;

	if ( ! is_text( $in->{file} ) ) {
		push( @errors, ht_li( {}, 'Select a file to upload.' ) );
	}
	else {
		my $upload 	= $apr->upload( 'file' );
		my $size 	= $upload->size;

		if ( ! defined $size || $size < 1 ) {
			push( @errors, ht_li( {}, 'Select a file to upload.' ) );
		}
	}

	if ( @errors ) {
		return( ht_div( { 'class' => 'error' },
						ht_h( 1, 'Errors' ), ht_ul( {}, @errors ) ) );
	}

	return();
} # END upload_checkvals

#-------------------------------------------------
# file_checkvals( $k, $in )
#-------------------------------------------------
sub file_checkvals {
	my ( $k, $in ) = @_;

	my @errors;

	## Name
	if ( ! is_ident( $in->{name} ) ) {
		push( @errors, ht_li( {}, 	'You must supply a valid file name.',
									'A valid file must not contain ',
									'spaces or symbols.' ) );
	}
	else {
		my $file = "$k->{dir}/$in->{path}/$in->{name}";
		$file		=~ s/\/\//\//g;

		## Name - if this is an add and the file exists, do not let them add
		## they will need to edit...
		if ( $in->{op} eq 'add' && $file && -e $file ) {
			push( @errors, ht_li( {}, 	"The file '$in->{path}/$in->{name}'",
										'already exists.' ) );
		}
	}
	
	## Path is a select

	## Content - if there is content, great....
	## Let them create an empty file (touch), if they so choose
	if ( @errors ) {
		return( ht_div( { 'class' => 'error' },
						ht_h( 1, 'Errors' ), ht_ul( {}, @errors ) ) );
	}

	return();
} # END file_checkvals

#-------------------------------------------------
# upload_form( $k, $in ) 
#-------------------------------------------------
sub upload_form {
	my ( $k, $in ) = @_;

	## Get the directories
	my @dirs = ( '', '/' );

	my @subdirs = File::Find::Rule	-> directory
									-> relative
									-> not( File::Find::Rule
										-> name( @{$k->{showhidden}} ) )
									-> in( $k->{dir} );

	my @tdirs = sort { lc( $a ) cmp lc( $b ) } @subdirs;

	## Make the select array of dirs
	for my $d ( @tdirs ) {
		if ( -r "$k->{dir}/$d" && -w "$k->{dir}/$d" ) {
			push( @dirs, $d, "/$d" );
		}
	}
	
	return(	ht_form_js( $k->{uri}, 'enctype="multipart/form-data"' ),
			ht_table(),

			ht_tr(),
			ht_td( { 'class' => 'hdr', 'colspan' => '2' }, 'File Upload' ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Path:' ),
			ht_td( {}, 	ht_select( 'path', 1, $in, '', '', @dirs ),
						ht_help( $k->{help}, 'item', 'a:fm:d:f:path' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'File:' ),
			ht_td( {}, 	ht_input( 'file', 'file', $in ),
						ht_help( $k->{help}, 'item', 'a:fm:d:f:file' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'rshd', 'colspan' => '2' },
					ht_submit( 'save', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(), 
			ht_uform() );
} # END upload_form
			
#-------------------------------------------------
# file_form( $k, $in ) 
#-------------------------------------------------
sub file_form {
	my ( $k, $in ) = @_;

	## Get the directories
	my @dirs = ( '', '/' );
	
	my @subdirs	= File::Find::Rule	-> directory
									-> relative
									-> not( File::Find::Rule
										-> name( @{$k->{showhidden}} ) )
									-> in( $k->{dir} );
	
	my @tdirs = sort { lc( $a ) cmp lc( $b ) } @subdirs;
	
	## Make the select array of dirs
	foreach my $d ( @tdirs ) {
		if ( -r "$k->{dir}/$d" && -w "$k->{dir}/$d" ) {
			push( @dirs, $d, "/$d" );
		}
	}
	
	my @lines = ( 
		ht_form_js( $k->{uri} ),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '2' }, 'File Data' ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Name:' ),
		ht_td( {},
				ht_input( 'name', 'text', $in, 'size="60" maxlength="265"' ),
				ht_help( $k->{help}, 'item', 'a:fm:d:f:name' ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Path:' ),
		ht_td( {}, 	ht_select( 'path', 1, $in, '', '', @dirs ),
					ht_help( $k->{help}, 'item', 'a:fm:d:f:path' ) ),
		ht_utr() );

	## If this is add, or edit of a text file, then let them add/edit content
	my $fname	= '';
	$fname	.= "$k->{dir}/$in->{origpath}/$in->{origname}" if ( $in->{op} eq 'edit' );

	## Unfortunately, pdf files are considered to be text... go figure
	if ( $in->{op} eq 'add' || -T $fname && $fname !~ /\.pdf$/ ) {
		push( @lines,
			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Content:' ),
			ht_td( {}, 	ht_input( 'content', 'textarea', $in, 
									 'rows="30" cols="80"' ),
						ht_help( $k->{help}, 'item', 'a:fm:d:f:content' ) ),
			ht_utr() );
	}

	return( @lines,
			ht_tr(),
			ht_td( { 'class' => 'rshd', 'colspan' => '2' },
					ht_submit( 'save', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),
	
			ht_utable(), 
			ht_uform() );
} # END file_form

# EOF
1;
__END__

=head1 NAME

FileManager - Perl extension for File Management

=head1 SYNOPSIS

  use Alchemy::FileManager::Files;

=head1 DESCRIPTION

This module provides the interface for add, edit, upload, copy, and
delete of files in a specified directory

=head1 DEPENDENCIES

  ## Files
  use Apache2::Request
  use Apache2::Upload
  use POSIX qw( strftime )
  use File::Copy
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

<Location /admin/fm/files >
  SetHandler  modperl

  PerlSetVar  SiteTitle   "FileManager - "

  PerlHandler Alchemy::FileManager::Files
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

None by Default.

=head1 FUNCTIONS

This module provides the following functions:

$k->do_add( $r, @ident )

   Creates a new file in the specified directory if allowed by 
   permissions

$k->do_edit( $r, @ident )

    Edits an existing file - in the case of text files: the content, 
    filename, and directory can be modified - in the case of all other 
    files: the filename and directory can be modified if allowed by 
    permissions

$k->do_upload( $r, @ident )

    Uploads a new file to the specified directory if allowed by 
    permissions

$k->do_copy( $r, @ident )

    Copies an existing file using the edit interface if allowed by 
    permissions

$k->do_delete( $r, @ident )

    Deletes an existing file if allowed by permissions - requires 
    confirmation of delete

=head1 SEE ALSO

Alchemy::FileManager(3), KrKit(3), perl(3)


=head1 LIMITATIONS

None defined at this point....

=head1 AUTHOR

Ron Andrews <ron.andrews@cognilogic.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ron Andrews. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.


=cut
