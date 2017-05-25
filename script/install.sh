#!/usr/bin/env bash
# -*- coding:utf-8 -*-

set -x
basepath=$(cd `dirname $0`/..; pwd)
cd $basepath
mkdir -p opt tmp
optpath=$(cd opt; pwd)

# 修改环境变量
function install_env(){
    if ! grep C_INCLUDE_PATH ~/.bashrc &>/dev/null; then
        echo "export PYTHONPATH=$basepath/script:\$PYTHONPATH" >> ~/.bashrc
        echo "export PATH=$optpath/bin:$optpath/sbin:\$PATH" >> ~/.bashrc
        # 动态链接库路径
        echo "export LD_LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
        # 静态链接库路径
        echo "export LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LIBRARY_PATH" >> ~/.bashrc
        # gcc 头文件路径
        echo "export C_INCLUDE_PATH=$optpath/include:\$C_INCLUDE_PATH" >> ~/.bashrc
        # g++ 头文件路径
        echo "export CPLUS_INCLUDE_PATH=$optpath/include:\$CPLUS_INCLUDE_PATH" >> ~/.bashrc
        # pkgconfig 路径
        echo "export PKG_CONFIG_PATH=$optpath/lib/pkgconfig:\$PKG_CONFIG_PATH" >> ~/.bashrc
        echo "export LC_ALL=C" >> ~/.bashrc
    fi
    test -e ~/.basrc && source ~/.bashrc
}

function download(){
    # filename是.tar.gz 或.tar.bz2 或.tar.xz，2次移除.* 所匹配的最右边的内容
    url=$1
    filename=`basename "$url"`
    name=${filename%.*}
    [[ "$filename" =~ (tar.gz|tar.bz2|tar.xz)$ ]] && name=${name%.*}
    [[ "$filename" =~ (zip)$ ]] && decompress="unzip" || decompress="tar xf"
    shift 1
    while getopts ":f:n:d:" opt
    do
        case $opt in
            f) filename=$OPTARG;;
            n) name=$OPTARG;;
            d) decompress=$OPTARG;;
            ?) echo "error";;
        esac
    done
    if ! test -e $name; then
        if [[ "$url" =~ ^(http|ftp) ]]; then
            wget $url --no-check-certificate -O $filename
            $decompress $filename
        else
            eval "$url"
        fi
    fi
    cd $name
}

function install_redis(){
    download "http://download.redis.io/redis-stable.tar.gz"
    make -j10 && cp src/redis-server $optpath/bin && cp src/redis-cli $optpath/bin
    mkdir -p $optpath/bin $basepath/runtime/redis
    cp redis.conf $basepath/runtime/redis
    sed -i 's/daemonize no/daemonize yes/g' $basepath/runtime/redis/redis.conf
    cd $basepath/runtime/redis
    $optpath/bin/redis-server $basepath/runtime/redis/redis.conf
}

function install_mongo(){
    download "http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.4.3.tgz" -n mongodb-linux-x86_64-amazon-3.4.3
    mkdir -p $optpath/bin $basepath/runtime/mongo
    cp -r bin/*  $optpath/bin
    cp $basepath/conf/mongod.conf $basepath/runtime/mongo/mongod.conf
    cd $basepath/runtime/mongo
    mkdir -p data logs
    if command -v numactl &>/dev/null; then
        numactl --interleave=all $optpath/bin/mongod -f $basepath/runtime/mongo/mongod.conf
    else
        $optpath/bin/mongod -f $basepath/runtime/mongo/mongod.conf
    fi

#    sudo echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
#    sudo echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
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

function install_pyenv(){
    export PYENV_ROOT=$basepath/runtime/pyenv
    if ! grep PYENV_VIRTUALENV_DISABLE_PROMPT ~/.bashrc &>/dev/null; then
        echo "export PATH=$PYENV_ROOT/bin:\$PATH" >> ~/.bashrc
        echo "export PYENV_VIRTUALENV_DISABLE_PROMPT=1" >> ~/.bashrc
        echo "export PYTHON_CONFIGURE_OPTS=\"--enable-shared\"" >> ~/.bashrc
    fi
    source ~/.bashrc
    curl -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | sh
    if ! grep "virtualenv-init" ~/.bashrc &>/dev/null; then
        echo "eval \"\$(pyenv init -)\"" >> ~/.bashrc
        echo "eval \"\$(pyenv virtualenv-init -)\"" >> ~/.bashrc
    fi
    if command -v pyenv &>/dev/null; then
        source ~/.bashrc
        #CFLAGS="-I $optpath/include" LDFLAGS="-L $optpath/lib" pyenv install 3.6.1
        pyenv install 2.7.13
        pyenv global 2.7.13
    fi
}

function install_supervisor(){
    mkdir -p $basepath/runtime/supervisor/logs
    mkdir -p $basepath/runtime/supervisor/proc
    mkdir -p $basepath/runtime/supervisor/conf.d
 
    if ! grep supervisorctl ~/.bashrc &>/dev/null; then
        echo "export SUPERVISOR_HOME=$basepath/runtime/supervisor" >> ~/.bashrc
        echo "alias supervisorctl='supervisorctl -c $basepath/runtime/supervisor/supervisord.ini'" >> ~/.bashrc
    fi
    source ~/.bashrc

    pip install supervisor

    cp $basepath/conf/supervisord.ini $basepath/runtime/supervisor/
    cd $basepath/runtime/supervisor
    supervisord -c $basepath/runtime/supervisor/supervisord.ini
    #sudo chkconfig supervisord on
}

function install_download(){
    mkdir -p $basepath/upload
    download_path="${basepath//\//\/}\/upload"
    cp $basepath/conf/nginx.conf $optpath/conf/nginx.conf
    sed -i "s/download_path/$download_path/g" $optpath/conf/nginx.conf
    ps -ef | grep $USER | grep -v grep | grep nginx | awk '{print $2}' | xargs kill -9
    $optpath/sbin/nginx -c $optpath/conf/nginx.conf
}

function install_upload(){
    mkdir -p $basepath/upload
    cd $basepath/upload
    ps -ef | grep upload.py | grep -v "grep" | grep "port=7000" | awk '{print $2}' | xargs kill -9
    nohup python $basepath/script/upload.py -port=7000 -log_file_prefix=$basepath/script/logs/upload.log &>/dev/null &
}

function show_info(){
    ip=`/sbin/ifconfig | grep "inet addr" | awk -F ':' '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1'`
    echo "upload path: $basepath/upload"
    echo "upload command: curl --socks5 52.34.197.81:9090 --data-binary @filename http://$ip:7000\?file=filename"
}

function getsections(){
    sed -n '/\[*\]/p' $1 | egrep -v '^#' | tr -d [] | tr -t '\n' ' '
}

function readini(){
    SECTION=$1
    KEY=$2
    CONFIG=$3
    # sed 匹配[$SECION]到下一个[之间的所有行, egrep 去除所有包含[]的行、空行以及以#开头的行
    keys=`sed -n '/\['$SECTION'\]/,/\[/p'  $CONFIG | egrep -v '\[|\]|^\s*$' | awk -F '=' '{ print $1 }' | tr -t '\n' ' '`
    if [[ "$keys" =~ $KEY ]]; then
        sed -n '/\['$SECTION'\]/,/\[/p'  $CONFIG | egrep -v '\[|\]|^\s*$' | awk -F '=' -v key=$KEY '{ value=""; for(i=2;i<=NF;i++) value=value""$i"="; gsub(/^ *| *$/, "", $1); gsub(/^ *|[= ]*$/, "", value); if($1==key) print value}'
	fi
}

function init(){
    install_env
    mkdir -p $basepath/script/logs
    config=$basepath/script/config.ini
    if [ $# -eq 0 ]; then
        packages=`readini common packages $config`
    else
        packages=$@
    fi
    sections=`getsections $config`
    for package in $packages
    do
        cd $basepath/tmp
        if [[ "$sections" =~ $package ]]; then
            url=`readini $package url $config`
            command=`readini $package command $config`
            if [[ "$command" == "" ]]; then
                command="./configure --prefix=$optpath && make -j10 && make install"
            fi
            name=`readini $package name $config`
            if [[ "$name" == "" ]]; then
                download "$url"
            else
                download "$url" -n "$name"
            fi
        else
            command=install_$package
        fi
        set -o pipefail; eval "$command" | tee -a $basepath/script/logs/${package}.log

        if [[ $? -eq 0 ]]; then
            echo "$package install succeed" >> $basepath/script/result.log
            if [[ "$package" == "python" ]]; then
                if grep "Successfully installed pip" $basepath/script/logs/${package}.log &>/dev/null ; then
                    #if command -v nvidia-smi &>/dev/null; then
                    #    echo "https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow_gpu-1.0.1-cp27-none-linux_x86_64.whl" >> $basepath/script/requirements.txt
                    #else
                    #    echo "https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.0.1-cp27-none-linux_x86_64.whl" >> $basepath/script/requirements.txt
                    #fi
                    pip install --upgrade -r $basepath/script/requirements.txt
                    if [[ $? -eq 0 ]]; then
                        install_upload
                        show_info
                    fi
                    echo "pip install succeed" >> $basepath/script/result.log
                else
                    echo "pip install failed" >> $basepath/script/result.log
                fi
            fi
        else
            echo "$package install failed" >> $basepath/script/result.log
        fi
    done
}

init $@
