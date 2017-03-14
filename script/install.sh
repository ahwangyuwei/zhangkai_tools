#!/usr/bin/env bash
# -*- coding:utf-8 -*-

set -x
basepath=$(cd `dirname $0`/..; pwd)
cd $basepath
mkdir -p opt tmp
optpath=$(cd opt; pwd)

# 修改环境变量
function install_env(){
    if ! `grep C_INCLUDE_PATH ~/.bashrc`; then
        echo "export PYTHONPATH=\$PYTHONPATH:$basepath/script" >> ~/.bashrc
        echo "export PATH=$optpath/bin:$optpath/sbin:\$PATH" >> ~/.bashrc
        # 动态链接库路径
        echo "export LD_LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
        # 静态链接库路径
        echo "export LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LIBRARY_PATH" >> ~/.bashrc
        # gcc 头文件路径
        echo "export C_INCLUDE_PATH=$optpath/include:\$C_INCLUDE_PATH" >> ~/.bashrc
        # g++ 头文件路径
        echo "export CPLUS_INCLUDE_PATH=$optpath/include:\$CPLUS_INCLUDE_PATH" >> ~/.bashrc
        echo "export LC_ALL=C" >> ~/.bashrc
    fi
    source ~/.bashrc
}

function install_m4(){
    wget http://ftp.gnu.org/gnu/m4/m4-latest.tar.gz
    tar xf m4-latest.tar.gz && cd m4-lastest
    ./configure --prefix=$optpath && make -j10 && make install
}

function install_autoconf(){
    wget ftp://alpha.gnu.org/pub/gnu/autoconf/autoconf-2.68b.tar.xz
    tar xf autoconf-2.68b.tar.xz && cd autoconf-2.68b
    ./configure --prefix=$optpath && make -j10 && make install
}

function install_automake(){
    wget http://ftp.gnu.org/gnu/automake/automake-1.15.tar.xz
    tar xf automake-1.15.tar.xz && cd automake-1.15
    ./configure --prefix=$optpath && make -j10 && make install
}

function install_libtool(){
    wget http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz
    tar xf libtool-2.4.6.tar.gz && cd libtool-2.4.6
    ./configure --prefix=$optpath && make -j10 && make install
}

function install_jq(){
    wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz -O jq-1.5.tar.gz
    tar xf jq-1.5.tar.gz && cd jq-1.5
    ./configure --prefix=/data2/zhangkai/tools/opt/ --disable-maintainer-mode && make -j10 && make install
}

function install_sqlite(){
    wget http://www.sqlite.org/2017/sqlite-autoconf-3160200.tar.gz
    tar xzf sqlite-autoconf-3160200.tar.gz && cd sqlite-autoconf-3160200
    ./configure --prefix=$optpath && make -j10 && make install
}

function install_zlib(){
    wget http://zlib.net/zlib-1.2.11.tar.gz
    tar xzf zlib-1.2.11.tar.gz && cd zlib-1.2.11
    ./configure --prefix=$optpath && make -j11 && make install
}

function install_openssl(){
    wget http://distfiles.macports.org/openssl/openssl-1.0.2j.tar.gz
    tar xzf openssl-1.0.2j.tar.gz && cd openssl-1.0.2j
    ./config --prefix=$optpath shared zlib-dynamic enable-camellia -fPIC && make depend && make -j10 && make install
}

function install_curl(){
    wget https://curl.haxx.se/download/curl-7.52.1.tar.gz --no-check-certificate
    tar xzf curl-7.52.1.tar.gz && cd curl-7.52.1
    #./configure --prefix=$optpath --disable-shared --enable-static --without-libidn --without-ssl --without-librtmp --without-gnutls --without-nss --without-libssh2 --without-zlib --without-winidn --disable-rtsp --disable-ldap --disable-ldaps --disable-ipv6 && make -j10 && make install
    ./buildconf && ./configure --prefix=$optpath --with-openssl=$optpath/ssl && make -j10 && make install
}

function install_python(){
    wget https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz
    tar xf Python-2.7.12.tgz && cd Python-2.7.12
    ./configure --prefix=$optpath --with-ensurepip=install && make -j10 && make install
}

function install_snappy(){
    git clone --depth=1 https://github.com/google/snappy.git && cd snappy
    ./autogen.sh && ./configure --prefix=$optpath && make -j10 && make install
}

function install_package(){
    pip install --upgrade pip
    pip install requests tornado html5lib beautifulsoup4 lxml ipython kafka python-snappy pycurl
}

function install_pcre(){
    wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.39.zip
    unzip pcre-8.39.zip && cd pcre-8.39
    ./configure --prefix=$optpath &&  make -j10 && make install
}

function install_nginx(){
    wget http://nginx.org/download/nginx-1.11.8.tar.gz
    tar -xzf nginx-1.11.8.tar.gz && cd nginx-1.11.8
   #./configure --prefix=$optpath --without-http_rewrite_module && make -j10 && make install
    wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.39.zip
    unzip pcre-8.39.zip
   ./configure --prefix=$optpath --with-pcre=$basepath/tmp/nginx-1.11.8/pcre-8.39 && make -j10 && make install
}

function install_redis(){
    wget http://download.redis.io/redis-stable.tar.gz
    tar xzf redis-stable.tar.gz && cd redis-stable
    make -j10 && cp src/redis-server $optpath/bin && cp src/redis-cli $optpath/bin
    mkdir -p $basepath/runtime/redis
    cp redis.conf $basepath/runtime/redis && sed -i 's/daemonize no/daemonize yes/g' $basepath/runtime/redis/redis.conf
    cd $basepath/runtime/redis
    $optpath/bin/redis-server $basepath/runtime/redis/redis.conf
}

function install_mongodb(){
    wget http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.4.1.tgz
    tar xzf mongodb-linux-x86_64-amazon-3.4.1.tgz
    mv mongodb-linux-x86_64-amazon-3.4.1/bin/*  $optpath/bin
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
    wget http://gcc.skazkaforyou.com/releases/gcc-5.3.0/gcc-5.3.0.tar.gz
    tar xzf gcc-5.3.0.tar.gz && cd gcc-5.3.0
    ./contrib/download_prerequisites
    mkdir -p gcc-build && cd gcc-build
    ../configure --prefix=$optpath --enable-checking=release --enable-languages=c,c++ --disable-multilib && make -j10 && make install

#    sudo cp x86_64-unknown-linux-gnu/libstdc++-v3/src/.libs/libstdc++.so.6.0.21 /usr/lib64/
#    sudo rm /usr/lib64/libstdc++.so.6
#    sudo ln -s /usr/lib64/libstdc++.so.6.0.21 /usr/lib64/libstdc++.so.6
#    sudo ldconfig
}

function install_ncurses(){
    wget http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz
    tar xzf ncurses-6.0.tar.gz && cd ncurses-6.0
    ./configure --prefix=$optpath && make -j10 && make install
}

function install_vim(){
    git clone --depth=1 https://github.com/vim/vim.git && cd vim
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
    modules="m4 autoconf automake jq sqlite zlib openssl python ncurses vim"
    for module in $modules
    do
        cd $basepath/tmp
        install_$module &> $basepath/script/logs/${module}.log
        if [ $? -eq 0 ]; then
            if [ "$module" == "python" ]; then
                if `grep "Successfully installed pip" $basepath/script/logs/${module}.log` ; then
                    install_package
                    echo "pip install succeed" >> $basepath/script/result.log
                else
                    echo "pip install failed" >> $basepath/script/result.log
                fi
            fi
            if [ "$module" == "nginx" ]; then
                deploy_upload
                show_info
            fi
    	    echo "$module install succeed" >> $basepath/script/result.log
        else
            echo "$module install failed" >> $basepath/script/result.log
        fi
    done

}

init
