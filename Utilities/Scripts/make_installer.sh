#!/bin/bash
EXPECTED_ARGS=5

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: make_installer.sh ostype ossize FDS_TAR.tar.gz INSTALLER.sh"
  echo ""
  echo "Creates an FDS/Smokeview installer sh script. "
  echo ""
  echo "  ostype - OSX or LINUX"
  echo "  ossize - ia32, intel64"
  echo "  FDS.tar.gz - compressed tar file containing FDS distribution"
  echo "  INSTALLER.sh - .sh script containing self-extracting installer"
  echo "  installdir - default install directory"
  echo
  exit
fi

ostype=$1
ossize=$2
FDS_TAR=$3
INSTALLER=$4
INSTALLDIR=$5

LDLIBPATH=LD_LIBRARY_PATH
if [ "$ostype" == "OSX" ]
then
LDLIBPATH=DYLD_LIBRARY_PATH
fi

cat << EOF > $INSTALLER
#!/bin/bash

echo ""
echo "FDS $FDSVERSION and Smokeview $SMVVERSION installer for $ostype $ossize"
echo ""
echo "Options:"
echo "  1) Press <Enter> to begin installation"
echo "  2) Type \"extract\" to copy the installation files to"
echo "     the file $FDS_TAR"

FDS_root=$INSTALLDIR
BAK=_\`date +%Y%m%d_%H%M%S\`

BACKUP_FILE()
{
  INFILE=\$1
  if [ -e \$INFILE ]
  then
  echo Backing up \$INFILE to \$\INFILE\$BAK
  cp \$INFILE \$INFILE\$BAK
fi
}

MKDIR()
{
  DIR=\$1
  if [ ! -d \$DIR ]
  then
    echo "Creating directory \$DIR"
    mkdir -p \$DIR>&/dev/null
  else
    while true; do
        echo "The directory, \$DIR, already exists."
        read -p "Do you wish to overwrite it? (yes/no)" yn
        case \$yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Installation cancelled";exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
  fi
  if [ ! -d \$DIR ]
  then
    echo "\`whoami\` does not have permission to create \$DIR."
    echo "FDS installation aborted."
    exit 0
  else
    echo "\$DIR has been created."
  fi
  touch \$DIR/temp.\$\$>&/dev/null
  if ! [ -e \$DIR/temp.\$\$ ]
  then
    echo "\`whoami\` does not have permission to write to \$DIR"
    echo "FDS installation aborted."
    exit 0
  fi
  rm \$DIR/temp.\$\$
}

# record the name of this script and the name of the directory 
# it will run in

THIS=\`pwd\`/\$0
THISDIR=\`pwd\`

CSHFDS=/tmp/cshrc_fds.\$\$
BASHFDS=/tmp/bashrc_fds.\$\$

# Find the beginning of the included FDS tar file so that it can be
# subsequently un-tar'd
 
SKIP=\`awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' \$0\`

# extract tar.gz file from this script if 'extract' specified

read  option
if [ "\$option" == "extract" ]
then
name=\$0
THAT=$FDS_TAR
if [ -e \$THAT ]
then
while true; do
    echo "The file, \$THAT, already exists."
    read -p "Do you wish to overwrite it? (yes/no)" yn
    case \$yn in
        [Yy]* ) break;;
        [Nn]* ) echo "Extraction cancelled";exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
fi
echo Extracting the file embedded in this installer to \$THAT
tail -n +\$SKIP \$THIS > \$THAT
exit 0
fi

# get FDS root directory

echo ""
echo "Where would you like to install FDS? (default: \$FDS_root)"
read answer
if [ "\$answer" != "" ]; then
FDS_root=\$answer
fi
 
# make the FDS root directory
 
MKDIR \$FDS_root

SHORTCUTDIR=\$FDS_root/../shortcuts
MKDIR \$SHORTCUTDIR

echo Creating fds6, smokeview6, smokediff6 and smokezip6 scripts

cat << FDS > \$SHORTCUTDIR/fds6
#!/bin/bash 
\$FDS_root/bin/fds \\\$@
FDS
chmod +x \$SHORTCUTDIR/fds6

cat << SMV > \$SHORTCUTDIR/smokeview6
#!/bin/bash 
\$FDS_root/bin/smokeview \\\$@
SMV
chmod +x \$SHORTCUTDIR/smokeview6

cat << SMV > \$SHORTCUTDIR/smokediff6
#!/bin/bash 
\$FDS_root/bin/smokediff \\\$@
SMV
chmod +x \$SHORTCUTDIR/smokediff6

cat << SMV > \$SHORTCUTDIR/smokezip6
#!/bin/bash 
\$FDS_root/bin/smokezip \\\$@
SMV
chmod +x \$SHORTCUTDIR/smokezip6

# ***** copy installation files into the FDS_root directory

echo
echo "Copying FDS installation files to"  \$FDS_root
cd \$FDS_root
tail -n +\$SKIP \$THIS | tar -xz
echo "Copy complete."

# ***** create CSH startup file

cat << CSHRC > \$CSHFDS
#/bin/csh -f
set platform=\\\$1

# unalias application names used by FDS

unalias fds >& /dev/null
unalias smokeview >& /dev/null
unalias smokezip >& /dev/null
unalias smokediff >& /dev/null

# define FDS bin directory location

setenv FDSBINDIR \`pwd\`/bin

# define openmpi library locations:
#   32/64 bit gigabit ethernet

set MPIDIST32=/shared/openmpi_32
set MPIDIST64=/shared/openmpi_64

# environment for 64 bit gigabit ethernet

if ( "\\\$platform" == "intel64" ) then
setenv MPIDIST \\\$MPIDIST64
set FORTLIB=\\\$FDSBINDIR/LIB64
endif

# environment for 32 bit gigabit ethernet

if ( "\\\$platform" == "ia32" ) then
setenv MPIDIST \\\$MPIDIST32
set FORTLIB=\\\$FDSBINDIR/LIB32
endif

if ( "\\\$platform" == "intel64" ) then
setenv $LDLIBPATH \\\`pwd\\\`/bin/LIB64
endif

if ( "\\\$platform" == "ia32" ) then
setenv $LDLIBPATH \\\`pwd\\\`/bin/LIB32
endif

# Update LD_LIBRARY_PATH and PATH variables

setenv $LDLIBPATH \\\$MPIDIST/lib:\\\${FORTLIB}:\\\$$LDLIBPATH
set path=(\\\$FDSBINDIR \\\$MPIDIST/bin ~/bin \\\$path)

# if compilers are present then pre-define environment for their use

if ( \\\$?IFORT_COMPILER ) then

if ( -e \\\$IFORT_COMPILER/bin/ifortvars.csh ) then

if ( "\\\$platform" == "intel64" ) then
source \\\$IFORT_COMPILER/bin/ifortvars.csh intel64
endif

if ( "\\\$platform" == "ia32" ) then
source \\\$IFORT_COMPILER/bin/ifortvars.csh ia32
endif

endif
endif

CSHRC

# ***** create BASH startup file

cat << BASH > \$BASHFDS
#/bin/bash

platform=\\\$1

# unalias application names used by FDS

unalias fds >& /dev/null
unalias smokeview >& /dev/null
unalias smokezip >& /dev/null
unalias smokediff >& /dev/null
unalias fds6 >& /dev/null
unalias smokeview6 >& /dev/null
unalias smokezip6 >& /dev/null
unalias smokediff6 >& /dev/null

# define FDS bin directory location

export FDSBINDIR=\`pwd\`/bin
SHORTCUTDIR=\`pwd\`/../shortcuts

# define openmpi library locations:
#   32/64 bit gigabit ethernet

MPIDIST32=/shared/openmpi_32
MPIDIST64=/shared/openmpi_64

# environment for 64 bit gigabit ethernet

case "\\\$platform" in
  "intel64" )
    export MPIDIST=\\\$MPIDIST64
    FORTLIB=\\\$FDSBINDIR/LIB64
  ;;
  "ia32" )
    export MPIDIST=\\\$MPIDIST32
    FORTLIB=\\\$FDSBINDIR/LIB32
  ;;
esac

# Update LD_LIBRARY_PATH and PATH variables

export $LDLIBPATH=\\\$MPIDIST/lib:\\\$FORTLIB:\\\$$LDLIBPATH
export PATH=\\\$FDSBINDIR:\\\$SHORTCUTDIR:\\\$MPIDIST/bin:\\\$PATH

# if compilers are present then pre-define environment for their use

if [ -e "\\\$IFORT_COMPILER/bin/ifortvars.sh" ]
then
case "\\\$platform" in
  "intel64" | "ia32" )
    source \\\$IFORT_COMPILER/bin/ifortvars.sh \\\$platform
  ;;
esac
fi

BASH

# ***** create .cshrc_fds startup file

echo
echo Creating .cshrc_fds startup file.

BACKUP_FILE ~/.cshrc_fds
cp \$CSHFDS ~/.cshrc_fds
rm \$CSHFDS

# ***** create .bash_fds startup file

echo Creating .bashrc_fds startup file.
BACKUP_FILE ~/.bashrc_fds
cp \$BASHFDS ~/.bashrc_fds
rm \$BASHFDS

# ***** update .bash_profile

BACKUP_FILE ~/.bash_profile

BASHPROFILETEMP=/tmp/.bash_profile_temp_\$\$
cd \$THISDIR
echo "Updating .bash_profile"
grep -v bashrc_fds ~/.bash_profile | grep -v "#FDS" > \$BASHPROFILETEMP
echo "#FDS Setting environment for FDS and Smokeview.  The original version" >> \$BASHPROFILETEMP
echo "#FDS of .bash_profile is saved in ~/.bash_profile\$BAK" >> \$BASHPROFILETEMP
echo source \~/.bashrc_fds $ossize >> \$BASHPROFILETEMP
cp \$BASHPROFILETEMP ~/.bash_profile
rm \$BASHPROFILETEMP

# ***** update .cshrc

BACKUP_FILE ~/.cshrc

CSHTEMP=/tmp/.cshrc_temp_\$\$
echo "Updating .cshrc"
grep -v cshrc_fds ~/.cshrc | grep -v "#FDS" > \$CSHTEMP
echo "#FDS Setting environment for FDS and Smokeview.  The original version" >> \$CSHTEMP
echo "#FDS of .cshrc is saved in ~/.cshrc\$BAK" >> \$CSHTEMP
echo source \~/.cshrc_fds $ossize >> \$CSHTEMP
cp \$CSHTEMP ~/.cshrc
rm \$CSHTEMP

echo ""
echo "Installation complete."
exit 0


__TARFILE_FOLLOWS__
EOF
chmod +x $INSTALLER
cat $FDS_TAR >> $INSTALLER
echo "Installer created."
