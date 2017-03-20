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
    if ! `grep C_INCLUDE_PATH /home/$USER/.bashrc &>/dev/null` && `test -e /home/$USER/.bashrc`; then
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
    if `test -e /home/$USER/.bashrc`; then
        source /home/$USER/.bashrc
    fi
}

function download(){
    # 默认filename是.tar.gz 或.tar.bz2 或.tar.xz，2次移除.* 所匹配的最右边的内容
    url=$1
    filename=`basename $url`
    name=${filename%.*}
    name=${name%.*}
    decompress="tar xf"
    shift 1
    while getopts ":f:n:d:" opt
    do
        case $opt in
            f) filename=$OPTARG;;
            n) name=$OPTARG;;
            d) decompress=$OPTARG;;
            ?) echo "params not defined";;
        esac
    done
    if ! `test -e $name`; then
        if [ "$url" =~ "https?:" ]; then
            wget $url --no-check-certificate -O $filename
            $decompress $filename
        else
            $url
        fi
    fi
    cd $name
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

function readini(){
    SECTION=$1
    KEY=$2
    CONFIG=$3
    awk -F '=' '/\['"$SECTION"'\]/{a=1}a==1&&$1~/'"$KEY"'/{value=""; for(i=2;i<NF;i++){ value=value""$i"=" }; value=value""$NF; exit;}END{ gsub(/^ *| *$/, "", value); print value;}' $CONFIG
}

function init(){
    install_env
    mkdir -p $basepath/script/logs
    config=$basepath/script/config.ini
    #sed -i '/^#/d' $config
    if [ $# -eq 0 ]; then
        packages=`readini common packages $config`
    else
        packages=$@
    fi
    for package in $packages
    do
        cd $basepath/tmp
        url=`readini $package url $config`
        command=`readini $package command $config`
        download $url
        $command  &> $basepath/script/logs/${package}.log

        if [ $? -eq 0 ]; then
            if [ "$package" == "python" ]; then
                if `grep "Successfully installed pip" $basepath/script/logs/${package}.log &>/dev/null` ; then
                    if `nvidia-smi &>/dev/null`; then
                        echo "https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow_gpu-1.0.1-cp27-none-linux_x86_64.whl" >> requirements.txt
                    else
                        echo "https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.0.1-cp27-none-linux_x86_64.whl" >> requirements.txt
                    fi
                    pip install --upgrade -r $basepath/script/requirements.txt
                    if [ $? -eq 0 ]; then
                        deploy_upload
                        show_info
                    fi
                    echo "pip install succeed" >> $basepath/script/result.log
                else
                    echo "pip install failed" >> $basepath/script/result.log
                fi
            fi
    	    echo "$package install succeed" >> $basepath/script/result.log
        else
            echo "$package install failed" >> $basepath/script/result.log
        fi
    done
}

init $@
