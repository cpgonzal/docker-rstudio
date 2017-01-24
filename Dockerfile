## Adapted from https://hub.docker.com/r/rocker/rstudio-stable
FROM cpgonzal/docker-r

# Dockerfile author / maintainer 
MAINTAINER Carlos P. <cpgonzal@gmail.com> 


#####################################################################
#rstudio-stable
#####################################################################
ARG GUID
ARG RSTUDIO_VERSION
ARG PANDOC_TEMPLATES_VERSION 
ENV PANDOC_TEMPLATES_VERSION ${PANDOC_TEMPLATES_VERSION:-1.18}
## Add RStudio binaries to PATH
ENV PATH /usr/local/lib/rstudio-server/bin:$PATH

## Download and install RStudio server & dependencies
## Attempts to get detect latest version, otherwise falls back to version given in $VER
## Symlink pandoc, pandoc-citeproc so they are available system-wide
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    file \
    git \
    libapparmor1 \
    libcurl4-openssl-dev \
    libedit2 \
    libssl-dev \
    lsb-release \
    psmisc \
    python-setuptools \
    sudo \
    wget \ 
  && RSTUDIO_LATEST=$(wget --no-check-certificate -qO- https://s3.amazonaws.com/rstudio-server/current.ver) \
  && [ -z "$RSTUDIO_VERSION" ] && RSTUDIO_VERSION=$RSTUDIO_LATEST || true \
  && wget -q http://download2.rstudio.org/rstudio-server-${RSTUDIO_VERSION}-amd64.deb \
  && dpkg -i rstudio-server-${RSTUDIO_VERSION}-amd64.deb \
  && rm rstudio-server-*-amd64.deb \
  ## Symlink pandoc & standard pandoc templates for use system-wide
  && ln -s /usr/local/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin \
  && ln -s /usr/local/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin \
  && wget https://github.com/jgm/pandoc-templates/archive/${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && mkdir -p /opt/pandoc/templates && tar zxf ${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates* \
  && mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates \
  && rm ${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  ## RStudio wants an /etc/R, will populate from $R_HOME/etc
  && mkdir -p /etc/R \
  ## Write config files in $R_HOME/etc
  && echo "\n\
    \n# Configure httr to perform out-of-band authentication if HTTR_LOCALHOST \
    \n# is not set since a redirect to localhost may not work depending upon \
    \n# where this Docker container is running. \
    \nif(is.na(Sys.getenv('HTTR_LOCALHOST', unset=NA))) { \
    \n  options(httr_oob_default = TRUE) \
    \n}" >> /usr/local/lib/R/etc/Rprofile.site \
  && echo "PATH=\"${PATH}\"" >> /usr/local/lib/R/etc/Renviron \
  ## Need to configure non-root user for RStudio
  && useradd rstudio \
  && echo "rstudio:rstudio" | chpasswd \
  && mkdir /home/rstudio \
  && chown rstudio:rstudio /home/rstudio \
  && addgroup rstudio staff \
  ## configure git not to request password each time 
  && git config --system credential.helper 'cache --timeout=3600' \
  && git config --system push.default simple \
  ## Set up S6 init system
  && wget -P /tmp/ https://github.com/just-containers/s6-overlay/releases/download/v1.11.0.1/s6-overlay-amd64.tar.gz \
  && tar xzf /tmp/s6-overlay-amd64.tar.gz -C / \
  && rm -rf /tmp/s6-overlay-amd64.tar.gz \
  && mkdir -p /etc/services.d/rstudio \
  && echo '#!/bin/bash \
           \n exec /usr/lib/rstudio-server/bin/rserver --server-daemonize 0' \
           > /etc/services.d/rstudio/run \
   && echo '#!/bin/bash \
           \n rstudio-server stop' \
           > /etc/services.d/rstudio/finish


#####################################################################
#tidyverse
#####################################################################
RUN apt-get update -qq && apt-get -y --no-install-recommends install \
  libxml2-dev \
  libcairo2-dev \
  libsqlite-dev \
  libmariadbd-dev \
  libmariadb-client-lgpl-dev \
  libpq-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  ## And some nice R packages for publishing-related stuff 
  && echo ". /etc/environment" >> /usr/local/lib/R/etc/install_pkgs.sh \ 
  && echo "install2.r --error \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --libloc \$LIBS_ROOT \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --repos 'http://www.bioconductor.org/packages/release/bioc' \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --repos \$MRAN \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --deps TRUE \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  tidyverse devtools dplyr ggplot2 profvis formatR" >> /usr/local/lib/R/etc/install_pkgs.sh 

## Notes: Above install2.r uses --deps TRUE to get Suggests dependencies as well,
## dplyr and ggplot are already part of tidyverse, but listed explicitly to get their (many) suggested dependencies.
## In addition to the the title 'tidyverse' packages, devtools is included for package development.
## RStudio wants formatR for rmarkdown, even though it's not suggested.
## profvis included just for profiling / development (developed by RStudio though not formally tidyverse).

#####################################################################
#verse
#####################################################################
## Add LaTeX, rticles and bookdown support
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ghostscript \
    imagemagick \
    ## system dependency of hadley/pkgdown
    libmagick++-dev \
    ## system dependency of hunspell (devtools)
    libhunspell-dev \
    ## R CMD Check wants qpdf to check pdf sizes, or iy throws a Warning 
    qpdf \
    ## for git via ssh key 
    ssh \
    ## for building pdfs via pandoc/LaTeX
    lmodern \
    texlive-fonts-recommended \
    texlive-humanities \
    texlive-latex-extra \
    texinfo \
    ## just because
    less \
    vim \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  ## R manuals use inconsolata font, but texlive-fonts-extra is huge, so:
  && cd /usr/share/texlive/texmf-dist \
  && wget http://mirrors.ctan.org/install/fonts/inconsolata.tds.zip \
  && unzip -o inconsolata.tds.zip \
  && rm inconsolata.tds.zip \
  && echo "Map zi4.map" >> /usr/share/texlive/texmf-dist/web2c/updmap.cfg \
  && mktexlsr \
  && updmap-sys \
  ## And some nice R packages for publishing-related stuff 
  && echo "install2.r --error \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --libloc \$LIBS_ROOT \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --repos 'http://www.bioconductor.org/packages/release/bioc' \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --repos \$MRAN \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  --deps TRUE \\" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && echo "  bookdown rticles rmdshower" >> /usr/local/lib/R/etc/install_pkgs.sh \
  && chmod 755 /usr/local/lib/R/etc/install_pkgs.sh 

## Consider including: 
# - libv8-dev (Javascript V8 packages)
# - yihui/printr R package (when released to CRAN)
# - jekyll ruby-rouge (servr R package, Jekyll)
# - jags 4.2 (build from source, repo version too old and apt-tagging forces upgrade of all compiler libs)
# - libgdal-dev libproj-dev libgeos-dev (for rgdal and related geo deps)
# - libgsl0-dev (GSL math library dependencies)
# - liblzma-dev libbz2-dev libiuc-dev (dev libraries needed to build R, also used to build littler & rJava)
# - default-jdk needed for rJava


COPY rstudio-server.sh /etc/cont-init.d/conf
EXPOSE 8787
ENTRYPOINT ["/init"]

