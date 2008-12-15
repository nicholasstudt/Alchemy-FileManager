use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Alchemy::FileManager',
    VERSION_FROM      => 'lib/Alchemy/FileManager.pm', # finds $VERSION
    PREREQ_PM         => {
							'KrKit'				=> '0',
#							'Apache2::Request'	=> '0',
#							'Apache2::Upload'	=> '0',
							'POSIX'				=> '0',
							'File::Copy'		=> '0',
							'File::Path'		=> '0',
							'File::Find::Rule'	=> '0',
						 }, 
);
