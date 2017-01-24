## Rstudio Dockerfile

This repository contains **Dockerfile** for [Docker](https://www.docker.com/)'s [automated build](https://registry.hub.docker.com/u/dockerfile/cpgonzal/) published to the public [Docker Hub Registry](https://registry.hub.docker.com/).


### Base Docker Image

* [dockerhub/cpgonzal/docker-r](https://hub.docker.com/r/cpgonzal/docker-r/)

### Installation

1. Install [Docker](https://www.docker.com/).

2. Download [automated build](https://registry.hub.docker.com/u/dockerfile/cpgonzal/) from public [Docker Hub Registry](https://registry.hub.docker.com/): `docker pull cpgonzal/docker-rstudio`

   (alternatively, you can build an image from Dockerfile: `docker build -t="cpgonzal/docker-rstudio" github.com/cpgonzal/docker-rstudio`)


### Usage (recommended using with persistent shared directories)

#### Run `cpgonzal/docker-rstudio` container with persistent shared directories 

    # ONLY THE FIRST TIME TO INSTALL REQUIRED R LIBRARIES
    docker run --rm --name rstudio-dock -e USERID=`id -u $USER` -e ROOT=TRUE -v <data-dir>:/data -v <libraries-dir>:/libraries cpgonzal/docker-rstudio &
    docker exec -it -u rstudio rstudio-dock /bin/bash /usr/local/lib/R/etc/install_pkgs.sh
    docker stop rstudio-dock

    # NEXT TIME 
    docker run --rm -it -p 8787:8787 -e USERID=`id -u $USER` -e ROOT=TRUE -v <data-dir>:/data -v <libraries-dir>:/libraries cpgonzal/docker-rstudio /bin/bash
    # open http:/<ip-address>:8787 
    docker inspect -f '{{.Name}} - {{.NetworkSettings.IPAddress }}' $(docker ps -aq)  


