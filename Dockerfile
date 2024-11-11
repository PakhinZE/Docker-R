# argument
FROM ubuntu:latest AS base
# set timezone
ENV TZ=Asia/Bangkok
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone;
# Ubuntu update
RUN apt-get update -q=2 && apt-get upgrade -q=2 -y;
# apt-utils & software-properties-common
RUN apt-get install apt-utils -q=2 -y; \
    apt-get install -q=2 -y software-properties-common;
# remove old repository & add repository
RUN apt-add-repository -y -c main -c restricted -r http://archive.ubuntu.com/ubuntu && \
    apt-add-repository -y -p updates -c main -c restricted -r http://archive.ubuntu.com/ubuntu && \
    apt-add-repository -y -p updates -c universe -r http://archive.ubuntu.com/ubuntu && \
    apt-add-repository -y -p updates -c multiverse -r http://archive.ubuntu.com/ubuntu && \
    apt-add-repository -y -p security -c main -c restricted -r http://security.ubuntu.com/ubuntu/ && \
    apt-add-repository -y -p security -c universe -r http://security.ubuntu.com/ubuntu/ && \
    apt-add-repository -y -p security -c multiverse -r http://security.ubuntu.com/ubuntu/ && \
    apt-add-repository -y -p backports -c main -c restricted -c universe -c multiverse -r http://archive.ubuntu.com/ubuntu; \
    apt-add-repository -y -c main -c restricted -c universe -c multiverse https://mirror.kku.ac.th/ubuntu/ && \
    apt-add-repository -y -p updates -c main -c restricted -c universe -c multiverse https://mirror.kku.ac.th/ubuntu/ && \
    apt-add-repository -y -p backports -c main -c restricted -c universe -c multiverse https://mirror.kku.ac.th/ubuntu/ && \
    apt-add-repository -y -p security -c main -c restricted -c universe -c multiverse https://mirror.kku.ac.th/ubuntu/;
# curl "UTF-8 ENG" git jq zip sudo
RUN apt-get install -q=2 -y curl language-pack-en git jq zip sudo;
# clean
RUN apt-get clean -q=2 -y;

##########################

FROM base AS r-build
# argument
ARG USER_NAME="r-dev"
# add user & sudoers
RUN useradd --create-home ${USER_NAME}; \
    echo ${USER_NAME}':40403030' | chpasswd; \
    usermod -g ${USER_NAME} ${USER_NAME}; \
    usermod -G sudo ${USER_NAME}; \
    touch /etc/sudoers.d/sudoers; \
    echo ${USER_NAME}' ALL=(ALL:ALL) NOPASSWD: FOLLOW: ALL' | tee -a /etc/sudoers.d/sudoers;
# change user
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/Work/
# make
RUN sudo apt-get install -q=2 -y make; \
# install system dependencies of R & BILS
    sudo apt-get install -q=2 -y gfortran \
    g++ \
    zlib1g-dev \
    libreadline-dev \
    libbz2-dev \
    liblzma-dev \
    libpcre2-dev \
    libcurl4-openssl-dev \
    libblis-openmp-dev \
    libblis64-openmp-dev \
    libopenblas-openmp-dev \
    libopenblas64-openmp-dev \
    libxml2-dev \
    libssl-dev \
    texinfo \
    texlive-fonts-extra \
    libpango1.0-dev \
    libcairo-5c-dev \
    libtiff-dev \
    libjpeg-dev; \
    echo "libblas.so.3-x86_64-linux-gnu  manual   /usr/lib/x86_64-linux-gnu/blis-openmp/libblas.so.3\nlibblas64.so.3-x86_64-linux-gnu manual   /usr/lib/x86_64-linux-gnu/blis64-openmp/libblas64.so.3" \
     | sudo update-alternatives --set-selections;
# Mold
RUN url=$(curl -s https://api.github.com/repos/rui314/mold/releases/latest | jq '.assets[] | select(.name | test("-x86_64-linux")) | .browser_download_url'); \
    echo $url | xargs -I {} curl -sL --retry 5 --output mold-archive {}; \
    mkdir mold; \
    tar -x -C mold --strip-components 1 -f mold-archive; \
    rm mold-archive;
# R Source
RUN curl --retry 5 https://cran.r-project.org/src/base/R-latest.tar.gz --output R.tar.gz; \
    mkdir R; \
    tar -x -C R --strip-components 1 -f R.tar.gz; \
    rm R.tar.gz;
WORKDIR /home/${USER_NAME}/Work/R/
# GCC & GFortran $ LTO
RUN sed -i 's|## CFLAGS=|CFLAGS="-g -O2 -march=native -B/home/'${USER_NAME}'/Work/mold/libexec/mold"|g' config.site; \
    sed -i 's|## CXXFLAGS=|CXXFLAGS="-g -O2 -march=native -B/home/'${USER_NAME}'/Work/mold/libexec/mold"|g' config.site; \
    sed -i 's|## FCFLAGS=|FCFLAGS="-g -O2 -march=native"|g' config.site; \
    sed -i 's|## AR=|AR=gcc-ar|g' config.site; \
    sed -i 's|## RANLIB=|RANLIB=gcc-ranlib|g' config.site; \
    sed -i 's|## LTO=|LTO=-flto|g' config.site; \
    sed -i 's|## LTO_FC=|LTO_FC=-flto|g' config.site; \
    echo "\nR_LIBS_USER='.local/R/%V/%p'" >> etc/Renviron.in;
# ./configure R
RUN curl --retry 5 https://cran.r-project.org/src/base/VERSION-INFO.dcf --output R-Version; \
    R_VERSION=$(cat R-Version | grep Release | cut -d ' ' -f 2); \
    ./configure --prefix=/opt/R/$R_VERSION --enable-memory-profiling --enable-R-shlib --with-blas=blis --with-lapack --with-x=no --enable-lto; \
    rm -f R-Version;
# make and install
RUN make --silent --jobs=12 --output-sync; \
    sudo make install --silent;
WORKDIR /home/${USER_NAME}/Work/
# clean
RUN rm -rf /tmp/R*; \
    sudo apt-get clean -q=2 -y;
