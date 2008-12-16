package Alchemy::FileManager;

use strict;
use KrKit::Handler;

our $VERSION = '0.28';
our @ISA = ( 'KrKit::Handler' );

##-----------------------------------------------------------------##
## Functions                                                       ##
##-----------------------------------------------------------------##
sub _init {
	my ( $k, $r ) = @_;
	
	$k->SUPER::_init( $r );

	# Need to make the display portion of the application show the
	# changed document root files correctly.
	$$k{dir}		= $r->dir_config( 'FM_DocRoot' ) || $r->document_root;
	$$k{dirview}	= $r->dir_config( 'FM_DocRootView' ) || "";

	$$k{rootf}		= $r->dir_config( 'FM_FileRoot' );
	$$k{rootd}		= $r->dir_config( 'FM_DirRoot' );
	
	$$k{group}		= $r->dir_config( 'FM_Group' ) || '';
	$$k{fperm}		= $r->dir_config( 'FM_FilePerm' ) || '664';
	$$k{dperm}		= $r->dir_config( 'FM_DirPerm' ) || '2775';

	$$k{chmod}		= $r->dir_config( 'FM_chmod' ) || '/bin/chmod';
	$$k{chgrp}		= $r->dir_config( 'FM_chgrp' ) || '/bin/chgrp';

	## Images
	my $ipath		= ($r->dir_config( 'FM_Image_URI' ) || "" ). "/";

	$$k{copyimg}	= $ipath.($r->dir_config('FM_Copy_Image') || "");
	$$k{delimg}		= $ipath.($r->dir_config('FM_Delete_Image') || "");
	$$k{editimg}	= $ipath.($r->dir_config('FM_Edit_Image') || "");
	$$k{fileimg}	= $ipath.($r->dir_config('FM_File_Image') || "");
	$$k{folderimg}	= $ipath.($r->dir_config('FM_Folder_Image') || "");
	$$k{upimg}		= $ipath.($r->dir_config('FM_UpDir_Image') || "");
	$$k{uploadimg}	= $ipath.($r->dir_config('FM_Upload_Image') || "");
	$$k{dirimg}		= $ipath.($r->dir_config('FM_Dir_Image') || "");
	$$k{txtimg}		= $ipath.($r->dir_config('FM_Text_Image') || "");
	
	my $showhidden	= $r->dir_config( 'FM_ShowHidden' ) || 0;
	my @hidden 		= ();

	push( @hidden, '.*' ) if ( ! $showhidden );
	
	$$k{showhidden} = \@hidden;

	return();
} # END $self->_init

# EOF

1;
__END__

=head1 NAME

Alchemy::FileManager - Perl extension for Content Management (FileManager)

=head1 SYNOPSIS

  use Alchemy::FileManager;

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

=head1 DESCRIPTION

This is a simple content/file manager application. It allows a user the
access to add/edit/delete directories and files on the file system within
a specified location. 

=head1 MODULES

Alchemy::FileManager::Directories

This module provides the management of the directory structure. 

Alchemy::FileManager::Files

This module provides the management of the files - includes file uploads.

=head1 APACHE

See the Directory and File modules for the appropriate configuration
information

## Note: for the Help System to be active - it must be set up via KrKit 
## See perldoc KrKit::Helper for more information

=head1 DATABASE

None by default

=head1 METHODS

$k->_init( $r )

    Called by the core handler to initialize each page request

=head1 CSS Tags

The following list of CSS tags are used in the application - see the
output text for various elements to exploit in order to better
customize the look and feel of the output

File CSS Tags
    box    - general container
    error  - error messages
    hdr    - heading
    shd    - subheading
    rshd   - right-aligned subheading
    dta    - data

Admin CSS Tags
    box    - general container
    error  - error messages
    hdr    - heading
    rhdr   - right-aligned heading
    shd    - subheading
    rshd   - right-aligned subheading
    dta    - data
    rdta   - right-aligned data

See the FileManager.css file in the docs/templates directory
of the distribution for an example.

=head1 EXPORT

None by default.

=head1 SEE ALSO

Alchemy::FileManager::Directories(3),
Alchemy::FileManager::Files(3), KrKit(3), perl(3)

=head1 LIMITATIONS

None defined at this point....

=head1 AUTHOR

Ron Andrews, <ron.andrews@cognilogic.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ron Andrews. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file

=cut
