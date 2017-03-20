#!/usr/bin/env bash
# -*- coding:utf-8 -*-

set -x
basepath=$(cd `dirname $0`/..; pwd)
cd $basepath
mkdir -p opt tmp
optpath=$(cd opt; pwd)
install="./configure --prefix=$optpath && make -j10 && make install"

# 修改环境变量
function install_env(){
    if ! `grep C_INCLUDE_PATH /home/$USER/.bashrc &>/dev/null`; then
        echo "export PYTHONPATH=$basepath/script:\$PYTHONPATH" >> /home/$USER/.bashrc
        echo "export PATH=$optpath/bin:$optpath/sbin:\$PATH" >> /home/$USER/.bashrc
        # 动态链接库路径
        echo "export LD_LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LD_LIBRARY_PATH" >> /home/$USER/.bashrc
        # 静态链接库路径
        echo "export LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LIBRARY_PATH" >> /home/$USER/.bashrc
        # gcc 头文件路径
        echo "export C_INCLUDE_PATH=$optpath/include:\$C_INCLUDE_PATH" >> /home/$USER/.bashrc
        # g++ 头文件路径
        echo "export CPLUS_INCLUDE_PATH=$optpath/include:\$CPLUS_INCLUDE_PATH" >> /home/$USER/.bashrc
        # pkgconfig 路径
        echo "export PKG_CONFIG_PATH=$optpath/lib/pkgconfig:\$PKG_CONFIG_PATH" >> /home/$USER/.bashrc
        echo "export LC_ALL=C" >> /home/$USER/.bashrc
    fi
    source /home/$USER/.bashrc
}

function download(){
    # 默认filename是.tar.gz 或.tar.bz2 或.tar.xz，2次移除.* 所匹配的最右边的内容
    url=$1
    filename=`basename $url`
    name=${filename%.*}
    name=${name%.*}
    command="wget"
    decompress="tar xf"
    shift 1
    while getopts ":f:n:c:d:" opt
    do
        case $opt in
            f) filename=$OPTARG;;
            n) name=$OPTARG;;
            c) command=$OPTARG;;
            d) decompress=$OPTARG;;
            ?) echo "params not defined";;
        esac
    done
    if ! `test -e $name`; then
        if [ "$command" == "wget" ]; then
            wget $url --no-check-certificate -O $filename
        else
            $command $url
        fi
        $decompress $filename
    fi
    cd $name
}

function install_m4(){
    download "http://ftp.gnu.org/gnu/m4/m4-1.4.7.tar.gz"
    $install
}

function install_autoconf(){
    download "ftp://alpha.gnu.org/pub/gnu/autoconf/autoconf-2.68b.tar.xz"
    $install
}

function install_automake(){
    download "http://ftp.gnu.org/gnu/automake/automake-1.15.tar.xz"
    $install
}

function install_libtool(){
    download "http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz"
    $install
}

function install_jq(){
    download "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz"
    ./configure --prefix=$optpath --disable-maintainer-mode && make -j10 && make install
}

function install_sqlite(){
    download "http://www.sqlite.org/2017/sqlite-autoconf-3160200.tar.gz"
    $install
}

function install_zlib(){
    download "http://zlib.net/zlib-1.2.11.tar.gz"
    $install
}

function install_openssl_fips(){
    download "https://www.openssl.org/source/openssl-fips-2.0.14.tar.gz"
    ./config --prefix=$optpath && make -j10 && make install
}
function install_openssl(){
    version=`openssl version | awk '{print $2}'`
    version=1.0.2j
    download "https://www.openssl.org/source/openssl-${version}.tar.gz"
    echo "OPENSSL_${version:0:-1} { global: *; };" > openssl.ld
    ./config --prefix=$optpath shared zlib-dynamic enable-camellia -fPIC  -Wl,--version-script=$basepath/tmp/openssl-${version}/openssl.ld -Wl,-Bsymbolic-functions
    make depend && make -j10 && make install
}

function install_curl(){
    download "https://curl.haxx.se/download/curl-7.52.1.tar.gz"
    #./configure --prefix=$optpath --disable-shared --enable-static --without-libidn --without-ssl --without-librtmp --without-gnutls --without-nss --without-libssh2 --without-zlib --without-winidn --disable-rtsp --disable-ldap --disable-ldaps --disable-ipv6 && make -j10 && make install
    ./buildconf && ./configure --prefix=$optpath --with-ssl=$optpath && make -j10 && make install
}

function install_python(){
    download "https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz"
    ./configure --prefix=$optpath --with-ensurepip=install && make -j10 && make install
}

function install_snappy(){
    download 'https://github.com/google/snappy.git' -c 'git clone --depth=1'
    ./autogen.sh
    $install
}

function install_pcre(){
    download "ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.bz2"
    $install
}

function install_nginx(){
    download "http://nginx.org/download/nginx-1.11.8.tar.gz"
   #./configure --prefix=$optpath --without-http_rewrite_module && make -j10 && make install
    download "ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.bz2"
   ./configure --prefix=$optpath --with-pcre=$basepath/tmp/pcre-8.40 && make -j10 && make install
}

function install_redis(){
    download "http://download.redis.io/redis-stable.tar.gz"
    make -j10 && cp src/redis-server $optpath/bin && cp src/redis-cli $optpath/bin
    mkdir -p $basepath/runtime/redis
    cp redis.conf $basepath/runtime/redis && sed -i 's/daemonize no/daemonize yes/g' $basepath/runtime/redis/redis.conf
    cd $basepath/runtime/redis
    $optpath/bin/redis-server $basepath/runtime/redis/redis.conf
}

function install_mongodb(){
    download "http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.4.1.tgz" -n mongodb-linux-x86_64-amazon-3.4.1
    cp -r bin/*  $optpath/bin
    mkdir -p $basepath/runtime/mongodb/data && mkdir -p $basepath/runtime/mongodb/logs
    cp $basepath/conf/mongod.conf $basepath/runtime/mongodb/
    cd $basepath/runtime/mongodb
    $optpath/bin/mongod -f $basepath/runtime/mongodb/mongod.conf

#    sudo su
#    echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
#    echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
#    exit
}

function install_gcc(){
    export LD_LIBRARY_PATH=""
    export LIBRARY_PATH=""
    export C_INCLUDE_PATH=""
    export CPLUS_INCLUDE_PATH=""
    download "http://gcc.skazkaforyou.com/releases/gcc-5.3.0/gcc-5.3.0.tar.gz"
    ./contrib/download_prerequisites
    mkdir -p gcc-build && cd gcc-build
    ../configure --prefix=$optpath --enable-checking=release --enable-languages=c,c++ --disable-multilib && make -j10 && make install

#    sudo cp x86_64-unknown-linux-gnu/libstdc++-v3/src/.libs/libstdc++.so.6.0.21 /usr/lib64/
#    sudo rm /usr/lib64/libstdc++.so.6
#    sudo ln -s /usr/lib64/libstdc++.so.6.0.21 /usr/lib64/libstdc++.so.6
#    sudo ldconfig
}

function install_ncurses(){
    download "http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz"
    $install
}

function install_vim(){
    download "https://github.com/vim/vim.git" -c "git clone --depth=1"
    ./configure --prefix=$optpath --with-features=huge --enable-cscope --enable-fontset --enable-multibyte --enable-pythoninterp=yes --enable-luainterp=yes && make -j10 && make install
    rm -rf ~/.vimrc ~/.vim
    cp -r $basepath/vim ~/.vim
}

function deploy_download(){
    mkdir -p $basepath/download
    download_path="${basepath//\//\\\/}\/download"
    sed -i "s/download_path/$download_path/g" $basepath/conf/nginx.conf
    cp $basepath/conf/nginx.conf $optpath/conf/nginx.conf
    ps -ef | grep $USER | grep -v grep | grep nginx | awk '{print $2}' | xargs kill -9
    $optpath/sbin/nginx -c $optpath/conf/nginx.conf
}

function deploy_upload(){
    mkdir -p $basepath/upload/logs
    ps -ef | grep $USER | grep -v grep | grep upload.py | grep 7000 | awk '{print $2}' | xargs kill -9
    cd $basepath/upload
    nohup python $basepath/script/upload.py -port=7000 -log_file_prefix=logs/upload.log &>/dev/null &
}

function show_info(){
    ip=`/sbin/ifconfig | grep "inet addr" | awk -F ':' '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1'`
    echo "upload path: $basepath/upload"
    echo "upload command: curl --socks5 52.34.197.81:9090 -H 'file=filename'--data-binary @filename http://$ip:7000"
}

function init(){
    install_env
    mkdir -p $basepath/script/logs
    if [ $# -eq 0 ]; then
        modules="m4 autoconf automake jq sqlite curl zlib openssl python ncurses vim"
    else
        modules=$@
    fi
    for module in $modules
    do
        cd $basepath/tmp
        install_$module &> $basepath/script/logs/${module}.log
        if [ $? -eq 0 ]; then
            if [ "$module" == "python" ]; then
                if `grep "Successfully installed pip" $basepath/script/logs/${module}.log &>/dev/null` ; then
                    if `nvidia-smi &>/dev/null`; then
                        echo "https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow_gpu-1.0.1-cp27-none-linux_x86_64.whl" >> requirements.txt
                    else
                        echo "https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.0.1-cp27-none-linux_x86_64.whl" >> requirements.txt
                    fi
                    pip install --upgrade -r requirements.txt
                    deploy_upload
                    show_info
                    echo "pip install succeed" >> $basepath/script/result.log
                else
                    echo "pip install failed" >> $basepath/script/result.log
                fi
            fi
    	    echo "$module install succeed" >> $basepath/script/result.log
        else
            echo "$module install failed" >> $basepath/script/result.log
        fi
    done
}

init $@
