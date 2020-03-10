#!/bin/bash
#
# A big 'ol backup script. Most of the time this will execute sync events 
# needed to push relevant directories to the Galia Lab OneDrive, but the
# --full option will do a full backup of the User\ray\ directory to Seagate
# and Toshiba hard drives mounted on E: and D:.

###############################################################################
#                                                                             #
#                                    LOG                                      #
#                                                                             #
###############################################################################

# might set this up later

###############################################################################
#                                                                             #
#                            REMOTE MACHINE SYNC                              #
#                                                                             #
###############################################################################

# Since the full backup requires syncing to remote machines whose passwords may
# change, let's put those first so we can enter the pws by hand here. If this 
# ever becomes too burdensome we can change it.

while test $# -gt 0;
do
  case "$1" in
    --full | -f)
      # Sync data from solution NMR magnets (even though these are rarely used)
      echo 'grabbing data from NMR controllers...'

      rsync -avu --no-perms -e ssh rberkele@ava300.ucsd.edu:/home/debelou/rberkele/ /home/ray/NMR/ava300/
      rsync -avu --no-perms -e ssh --exclude='linux-topspin_20161103.sh'  rberkele@ava800.ucsd.edu:/home/rberkele/ /home/ray/NMR/ava800/

      echo 'pushing to local OneDrive folder...'

      cp -rf ava300/* /mnt/c/Users/ray/OneDrive/NMR_Sync/ava300/
      cp -rf ava800/* /mnt/c/Users/ray/OneDrive/NMR_Sync/ava800/
      
      echo 'NMR remote sync done'

      shift
      ;;
  esac
done

###############################################################################
#                                                                             #
#                                    GIT                                      #
#                                                                             #
###############################################################################

# GitHub/ssh seems to complain if the private key is given an unusual name, even
# when the private key is named anything other than 'id_rsa', so that's what it
# is called 

# find /mnt/c/Users/ray/Blog/ -type d -name ".git" -execdir git add . \;
# find /mnt/c/Users/ray/Blog/ -type d -name ".git" -execdir git commit -m "auto-commit" \;
# find /mnt/c/Users/ray/Blog/ -type d -name ".git" -execdir git push origin master \;

# find /mnt/c/Users/ray/Sync/ -type d -name ".git" -execdir git add . \;
# find /mnt/c/Users/ray/Sync/ -type d -name ".git" -execdir git commit -m "auto-commit" \;
# find /mnt/c/Users/ray/Sync/ -type d -name ".git" -execdir git push origin master \;

#find /mnt/c/Users/ray/Sync/ -type d -name ".git" -execdir /home/ray/Projects/P000024_Data_Management/autogit.sh \;

###############################################################################
#                                                                             #
#                                HOUSEKEEPING                                 #
#                                                                             #
###############################################################################

# Search Projects folder and create html versions of all Jupyter notebooks for
# general consumption.
find /mnt/c/Users/ray/Sync/Projects/ -type f -not -name "*checkpoint*" -name "*.ipynb" -execdir /home/ray/anaconda3/bin/jupyter nbconvert {} --to html \;

# Create docx files from jupyter notebooks. This is not too easy to do in bash
# so was offloaded to a py script that scrapes ipynbs using Selenium. 
find /mnt/c/Users/ray/Sync/Projects/ -type f -not -name "*checkpoint*" -name "*.ipynb" -execdir /home/ray/anaconda3/bin/python /home/ray/Projects/P000024_Data_Management/ipynb_to_word.py --path={} \;

# Convert markdown meeting notes to docx
find /mnt/c/Users/ray/Sync/Presentations -type f -name "*.md" -execdir /home/ray/anaconda3/bin/pandoc -s {} -o 'meeting_minutes.docx' \;

###############################################################################
#                                                                             #
#                                 HDD BACKUP                                  #
#                                                                             #
###############################################################################
while test $# -gt 0;
do
  case "$1" in
    --full | -f)
      # Check that both drives are mounted. Hotswapping drives will cause issues,
      # so if the drive was mounted and removed try to remount it on another point. 
      #
      # NOTE: There is something strange going on with mounting after a hotswap. Even
      # remounting a drive to a new directory causes causes problems, possibly
      # related to WSL issue 1954. For now, we'll just make restarting the system 
      # with the drives plugged in a necessary part of the backup. 
      if ls /mnt/e > /dev/null ; then
        if [ -d "/mnt/e/kirschner/" ] ; then
          echo "E: mounted successfully"
          SEAGATE_PATH=/mnt/e
        else
          echo "Other device mounted to /mnt/e!"
          echo "Exiting..."
          exit
        fi
      else
        echo "E: is not mounted. Restart the system with the E: drive inserted."
        echo "Exiting..."
        exit
        # mkdir /mnt/m
        # mount -t drvfs E: /mnt/m
        # SEAGATE_PATH=/mnt/m
      fi
      
      if ls /mnt/g > /dev/null ; then
        if [ -d "/mnt/g/kirschner/" ] ; then
          echo "G: mounted successfully"
          TOSHIBA_PATH=/mnt/g
        else
          echo "Other device mounted to /mnt/g!"
          echo "Exiting..."
          exit
        fi
      else
        echo "G: is not mounted. Restart the system with the E: drive inserted."
        echo "Exiting..."
        exit
        # mkdir /mnt/n
        # mount -t drvfs G: /mnt/n
        # TOSHIBA_PATH=/mnt/n
      fi
      
      # Push solution NMR data to backup drives
      rsync -ahv --progress /home/ray/NMR/ava300/ /mnt/e/kirschner/ava300/
      rsync -ahv --progress /home/ray/NMR/ava800/ /mnt/e/kirschner/ava800/
      rsync -ahv --progress /home/ray/NMR/ava300/ /mnt/g/kirschner/ava300/
      rsync -ahv --progress /home/ray/NMR/ava800/ /mnt/g/kirschner/ava800/
      
      # Push WSL and Windows home directories to drives
      rsync -ahv --progress /mnt/c/Users/ /mnt/e/kirschner/Users/
      rsync -ahv --progress /home/ray/ /mnt/e/kirschner/Debian/
      rsync -ahv --progress /mnt/c/Users/ /mnt/g/kirschner/Users/
      rsync -ahv --progress /home/ray/ /mnt/g/kirschner/Debian/
      
      umount $TOSHIBA_PATH
      umount $SEAGATE_PATH
      
      shift
      ;;
  esac
done

##############################################################################
#                                                                            #
#                              OneDrive BACKUP                               #
#                                                                            #
##############################################################################

# Weekly Subgroup Meetings
rsync -ahv --progress /mnt/c/Users/ray/Sync/Presentations/Subgroup_Meetings/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Group\ meetings\ -\ weekly\ meetings/Ray/

# Research Updates
rsync -ahv --progress /mnt/c/Users/ray/Sync/Presentations/Research_Updates/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Group\ meetings\ -\ research\ presentations/Ray/

# Journal Club Presentations
rsync -ahv --progress /mnt/c/Users/ray/Sync/Presentations/Journal_Club/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Group\ meetings\ -\ journal\ club\ presentations/Ray/

# Projects folder to Data/Projects/
rsync -ahv --progress --exclude-from='/mnt/c/Users/ray/Sync/Projects/.rsync-exclude.txt' /mnt/c/Users/ray/Sync/Projects/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Lab\ notebooks/Ray/

# Figures folder to Data/Figures/
rsync -ahv --progress /mnt/c/Users/ray/Sync/Figures/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Data/Ray/Figures/

# Documents folder to Data/Documents/
rsync -ahv --progress /mnt/c/Users/ray/Sync/Documents/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Data/Ray/Documents/

# NMR_Sync folder to Data/NMR_Sync
rsync -ahv --progress /mnt/c/Users/ray/Sync/NMR_Sync/ /mnt/c/Users/ray/UC\ San\ Diego/Debelouchina\,\ Galia\ -\ Galia\ Lab/Data/Ray/NMR_Sync/

echo "done :P"
