#!/usr/bin/with-contenv bash

## Set defaults for environmental variables in case they are undefined
USER=${USER:=rstudio}
PASSWORD=${PASSWORD:=rstudio}
USERID=${USERID:=1000}
ROOT=${ROOT:=FALSE}
DATA_ROOT=${DATA_ROOT:=/data}
LIBS_ROOT=${LIBS_ROOT:=/libraries}

echo DATA_ROOT=$DATA_ROOT >> /etc/environment 
echo LIBS_ROOT=$LIBS_ROOT >> /etc/environment 

#add R_LIBS variable to Renviron.site
mkdir $LIBS_ROOT 
echo "R_LIBS_USER='$LIBS_ROOT'" >> /usr/local/lib/R/etc/Renviron.site 
echo "R_LIBS=\${R_LIBS-'$LIBS_ROOT:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /usr/local/lib/R/etc/Renviron.site 

#modify working directory in Rprofile.site
mkdir $DATA_ROOT
echo "setwd('$DATA_ROOT')" >> /usr/local/lib/R/etc/Rprofile.site

if [ "$USERID" -lt 1000 ]
# Probably a macOS user, https://github.com/rocker-org/rocker/issues/205
  then
    echo "$USERID is less than 1000, setting minumum authorised user to 499"
    echo auth-minimum-user-id=499 >> /etc/rstudio/rserver.conf
fi

if [ "$USERID" -ne 1000 ]
## Configure user with a different USERID if requested.
  then
    echo "deleting user rstudio"
    userdel rstudio
    rm -rf /home/rstudio
    echo "creating new $USER with UID $USERID"
    useradd -m $USER -u $USERID
    #mkdir /home/$USER
    chown -R $USER /home/$USER
    usermod -a -G staff $USER
elif [ "$USER" != "rstudio" ]
  then
    ## cannot move home folder when it's a shared volume, have to copy and change permissions instead
    cp -r /home/rstudio /home/$USER
    ## RENAME the user   
    usermod -l $USER -d /home/$USER rstudio
    groupmod -n $USER rstudio
    usermod -a -G staff $USER
    chown -R $USER:$USER /home/$USER
    echo "USER is now $USER"  
fi
  
## Add a password to user
echo "$USER:$PASSWORD" | chpasswd

# Use Env flag to know if user should be added to sudoers
if [ "$ROOT" == "TRUE" ]
  then
    adduser $USER sudo && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
    echo "$USER added to sudoers"
fi

## add these to the global environment so they are avialable to the RStudio user 
echo "HTTR_LOCALHOST=$HTTR_LOCALHOST" >> /usr/local/lib/R/etc/Renviron.site
echo "HTTR_PORT=$HTTR_PORT" >> /usr/local/lib/R/etc/Renviron.site



