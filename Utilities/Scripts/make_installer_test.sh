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

size2=64

ostype2=$ostype
if [ "$ostype" == "LINUX" ]
then
ostype2=Linux
fi

cat << EOF > $INSTALLER
#!/bin/bash

OVERRIDE=\$1
echo ""
echo "Installing $size2 bit $ostype2 FDS $FDSVERSION and Smokeview $SMVVERSION"
echo ""
echo "Options:"
echo "  1) Press <Enter> to begin installation"
echo "  2) Type \"extract\" to copy the installation files to $FDS_TAR"

BAK=_\`date +%Y%m%d_%H%M%S\`

#--- output message

#--- make a backup of a file

BACKUP_FILE()
{
  INFILE=\$1
  if [ -e \$INFILE ]
  then
  echo
  echo Backing up \$INFILE to \$INFILE\$BAK
  cp \$INFILE \$INFILE\$BAK
fi
}

#--- create a script that points to an installed executable

MAKESHORTCUT()
{
  FDS_base=\$1
  EXE=\$2
  OUTFILE=\$3

cat << SHORTCUTFILE > \$TEMPFILE
#!/bin/bash 
\$FDS_base/bin/\$EXE \\\$@
SHORTCUTFILE

cp \$TEMPFILE \$OUTFILE
chmod +x \$OUTFILE
}

#--- convert a path to it absolute equivalent

function ABSPATH() {
  pushd . > /dev/null;
  if [ -d "\$1" ];
  then
    cd "\$1";
    dirs -l +0;
  else
    cd "\`dirname \"\$1\"\`";
    cur_dir=\`dirs -l +0\`;
    if [ "\$cur_dir" == "/" ]; then
      echo "\$cur_dir\`basename \"\$1\"\`";
    else
      echo "\$cur_dir/\`basename \"\$1\"\`";
    fi;
  fi;
  popd > /dev/null;
}

#--- make a directory, checking if the user has permission to create it

MKDIR()
{
  DIR=\$1
  CHECK=\$2
  if [ ! -d \$DIR ]
  then
    echo "Creating directory \$DIR"
    mkdir -p \$DIR>&/dev/null
  else
    if [ "\$CHECK" == "1" ] 
    then
    while true; do
        echo "The directory, \$DIR, already exists."
        if [ "\$OVERRIDE" == "y" ]
        then
          yn="y"
        else
          read -p "Do you wish to overwrite it? (yes/no) " yn
        fi
        case \$yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Installation cancelled";exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    fi
  fi
  if [ ! -d \$DIR ]
  then
    echo "\`whoami\` does not have permission to create \$DIR."
    echo "FDS installation aborted."
    exit 0
  else
    echo The directory, "\$DIR, has been created."
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

#--- record the name of this script and the name of the directory 
# it will run in

THISSCRIPT=\`ABSPATH \$0\`
THISDIR=\`pwd\`
OSSIZE=`getconf LONG_BIT`

#--- record temporary startup file names

BASHFDS=/tmp/bashrc_fds.\$\$

#--- Find the beginning of the included FDS tar file so that it can be
# subsequently un-tar'd
 
SKIP=\`awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' \$0\`

#--- extract tar.gz file from this script if 'extract' specified

if [ "\$OVERRIDE" == "y" ] 
then
  option=""
else
  read  option
fi
if [ "\$option" == "extract" ]
then
  name=\$0
  THAT=$FDS_TAR
  if [ -e \$THAT ]
  then
    while true; do
      echo "The file, \$THAT, already exists."
      read -p "Do you wish to overwrite it? (yes/no) " yn
      case \$yn in
        [Yy]* ) break;;
        [Nn]* ) echo "Extraction cancelled";exit;;
        * ) echo "Please answer yes or no.";;
      esac
    done
  fi
  echo Extracting the file embedded in this installer to \$THAT
  tail -n +\$SKIP \$THISSCRIPT > \$THAT
  exit 0
fi

OSSIZE=`getconf LONG_BIT`
if [ "$OSSIZE" != "64" ] ; then
  if [ "$OSSIZE" == "32" ] ; then
    echo "***Fatal error: FDS and Smokeview require a 64 bit operating system."
    echo "   The size of the operating system found is $OSSIZE."
    exit 0
  fi
  echo "***Warning: FDS and Smokeview require a 64 bit operating system."
  echo "   The size of the operating system found is $OSSIZE."
  echo "   Proceed with caution."
fi

#--- get FDS root directory

echo ""
echo "Where would you like to install FDS?"
EOF
  if [ "$ostype" == "OSX" ]
then
cat << EOF >> $INSTALLER
    echo "  Press 1 to install in /Applications/$INSTALLDIR"
    echo "  Press 2 to install in \$HOME/$INSTALLDIR"
EOF
  else
cat << EOF >> $INSTALLER
    echo "  Press 1 to install in \$HOME/$INSTALLDIR"
    echo "  Press 2 to install in /opt/$INSTALLDIR"
    echo "  Press 3 to install in /usr/local/bin/$INSTALLDIR"
EOF
  fi
cat << EOF >> $INSTALLER
echo "  Enter directory path to install elsewhere"

if [ "\$OVERRIDE" == "y" ] 
then
  answer="1"
else
  read answer
fi

EOF
if [ "$ostype" == "OSX" ]
then
cat << EOF >> $INSTALLER
  if [[ "\$answer" == "1" || "\$answer" == "" ]]; then
    eval FDS_root=/Applications/$INSTALLDIR
  elif [[ "\$answer" == "2" ]]; then
    eval FDS_root=\$HOME/$INSTALLDIR
  else
    eval FDS_root=\$answer
  fi
EOF
else
cat << EOF >> $INSTALLER
  if [[ "\$answer" == "1" || "\$answer" == "" ]]; then
    eval FDS_root=\$HOME/$INSTALLDIR
  elif [ "\$answer" == "2" ]; then
    FDS_root=/opt/$INSTALLDIR
  elif [ "\$answer" == "3" ]; then
    FDS_root=/usr/local/bin/$INSTALLDIR
  else
    eval FDS_root=\$answer
  fi
EOF
fi
cat << EOF >> $INSTALLER

#--- do we want to proceed

while true; do
    echo ""
    echo "Installation directory: \$FDS_root"
    if [ "\$OVERRIDE" == "y" ] 
    then
      yn="y"
    else
      read -p "Do you wish to begin the installation? (yes/no) " yn
    fi
    case \$yn in
        [Yy]* ) break;;
        [Nn]* ) echo "Installation cancelled";exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
 
#--- make the FDS root directory

echo ""
echo "Installation beginning"
 
MKDIR \$FDS_root 1

#--- make shortcuts

SHORTCUTDIR=\`ABSPATH \$FDS_root/../shortcuts\`
MKDIR \$SHORTCUTDIR 0

TEMPFILE=/tmp/exetemp_\$\$
echo Adding shortcuts to \$SHORTCUTDIR
MAKESHORTCUT \$FDS_root fds \$SHORTCUTDIR/fds6
MAKESHORTCUT \$FDS_root smokeview \$SHORTCUTDIR/smokeview6
MAKESHORTCUT \$FDS_root smokediff \$SHORTCUTDIR/smokediff6
MAKESHORTCUT \$FDS_root smokezip \$SHORTCUTDIR/smokezip6
rm -f \$TEMPFILE

#--- copy installation files into the FDS_root directory

echo
echo "Copying FDS installation files to"  \$FDS_root
cd \$FDS_root
tail -n +\$SKIP \$THISSCRIPT | tar -xz
echo "Copy complete."

#--- define MPI library locations

if [ -d /shared/openmpi_64ib ] ; then
  MPIIB="export MPI_IB=/shared/openmpi_64ib"
else
  MPIIB="export MPI_IB="
fi
if [ -d /shared/openmpi_64 ] ; then
  MPIETH="export MPI_ETH=/shared/openmpi_64"
else
  MPIETH="export MPI_ETH="
fi

#--- create BASH startup file

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

# FDS location

FDSBINDIR=\`pwd\`/bin
SHORTCUTDIR=\$SHORTCUTDIR

#  infiniband (MPI_IB) and ethernet (MPI_ETH) MPI library locaton

\$MPIIB
\$MPIETH

# setup MPI environment

if [ "\\\$QMPIDIST" == "" ] ; then
  if [[ "\\\$platform" == "intel64ib" ]] ; then
    MPIDIST=\\\$MPI_IB
  fi
  if [[ "\\\$platform" == "intel64" ]] ; then
    MPIDIST=\\\$MPI_ETH
  fi
else
  MPIDIST=\\\$QMPIDIST
fi
if [[ "\\\$MPIDIST" != "" && ! -d \\\$MPIDIST ]]; then
  echo "*** Warning: the MPI distribution, \\\$MPIDIST, does not exist"
  MPIDIST=
fi
if [[ "\\\$MPIDIST" == *ib ]] ; then
  FDSNETWORK=infiniband
fi
export MPIDIST FDSNETWORK

# Update LD_LIBRARY_PATH and PATH

LD_LIBRARY_PATH=\\\$FDSBINDIR/LIB64:\\\$LD_LIBRARY_PATH
PATH=\\\$FDSBINDIR:\\\$SHORTCUTDIR:\\\$PATH
if [ "\\\$MPIDIST" != "" ]; then
  LD_LIBRARY_PATH=\\\$MPIDIST/lib:\\\$LD_LIBRARY_PATH
  PATH=\\\$MPIDIST/bin:\\\$PATH
fi
export LD_LIBRARY_PATH PATH

# Set number of OMP threads

export OMP_NUM_THREADS=4
BASH

#--- create .bash_fds startup file

BACKUP_FILE ~/.bashrc_fds

if [ -e ~/.bashrc_fds ] ; then
  echo Updating .bashrc_fds
else
  echo Creating .bashrc_fds
fi
cp \$BASHFDS ~/.bashrc_fds
rm \$BASHFDS

if [ -d /shared/openmpi_64ib ] ; then
  SOURCEFDS="source ~/.bashrc_fds intel64ib"
else
  SOURCEFDS="source ~/.bashrc_fds intel64"
fi

#--- update .bash_profile
EOF
if [ "$ostype" == "OSX" ]; then
cat << EOF >> $INSTALLER
  BACKUP_FILE ~/.bash_profile

  BASHSTARTUP=/tmp/.bash_profile_temp_\$\$
  cd \$THISDIR
  echo "Updating .bash_profile"
  grep -v bashrc_fds ~/.bash_profile | grep -v "#FDS" > \$BASHSTARTUP
  echo "#FDS " >> \$BASHSTARTUP
  echo "#FDS Setting the environment for FDS and Smokeview. "   >> \$BASHSTARTUP
  echo \$SOURCEFDS >> \$BASHSTARTUP
  cp \$BASHSTARTUP ~/.bash_profile
  rm \$BASHSTARTUP
EOF
fi

if [ "$ostype" != "OSX" ]; then
cat << EOF >> $INSTALLER
#--- update .bashrc
  BACKUP_FILE ~/.bashrc

  BASHSTARTUP=/tmp/.bashrc_temp_\$\$
  cd \$THISDIR
  echo "Updating .bashrc"
  grep -v bashrc_fds ~/.bashrc | grep -v MPI_ETH | grep -v MPI_IB | grep -v "#FDS" > \$BASHSTARTUP
  echo "#FDS " >> \$BASHSTARTUP
  echo "#FDS Setting the environment for FDS and Smokeview. "   >> \$BASHSTARTUP
  echo \$SOURCEFDS >> \$BASHSTARTUP
  cp \$BASHSTARTUP ~/.bashrc
  rm \$BASHSTARTUP
EOF
fi

cat << EOF >> $INSTALLER

echo ""
echo "Installation complete."
exit 0


__TARFILE_FOLLOWS__
EOF
chmod +x $INSTALLER
cat $FDS_TAR >> $INSTALLER
echo "Installer created."