#!/usr/bin/env bash
# -*- coding:utf-8 -*-

set -x
basepath=$(cd `dirname $0`/..; pwd)
cd $basepath
mkdir -p opt tmp runtime
optpath=$(cd opt; pwd)
runpath=$(cd runtime; pwd)

shell="$(ps c -p "$PPID" -o 'ucomm=' 2>/dev/null || true)"
shell="${shell##-}"
shell="${shell%% *}"
shell="$(basename "${shell:-$SHELL}")"

case "$shell" in
    bash ) profile="$HOME/.bashrc" ;;
    zsh ) profile="$HOME/.zshrc" ;;
    ksh ) profile="$HOME/.profile" ;;
    fish ) profile="$HOME/.config/fish/config.fish" ;;
    * ) echo "please set your profile !!!"; exit 1 ;;
esac

function download(){
    url=$1
    filename=`basename "$url"`
    dirname=${filename%.*}
    [[ "$filename" =~ (tar.gz|tar.bz2|tar.xz)$ ]] && dirname=${dirname%.*}

    shift 1
    while getopts ":f:p:" opt
    do
        case $opt in
            f) filename=$OPTARG;;
            p) path=$OPTARG;;
            ?) echo "wrong parameter $opt";;
        esac
    done

    if ! test -e $filename; then
        if [[ "$url" =~ ^(http|ftp) ]]; then
            if command -v axel; then
                axel -n20 $url -o $filename
            else
                wget $url --no-check-certificate -O $filename
            fi
            if [ $? -eq 0 ]; then
                files=`ls`
                if [[ "$filename" =~ (tar.gz|tar.bz2|tar.xz)$ ]] || `file -i $filename | egrep 'x-gzip|x-bzip2|x-xz' &>/dev/null`; then
                    tar xf $filename
                elif [[ "$filename" =~ (zip)$ ]] || `file -i $filename | egrep "zip" &>/dev/null`; then
                    unzip $filename
                else
                    echo "unknown file format"
                    return 1
                fi

                new_files=`ls`
                dirname=`echo -e "$new_files\n$files" | sort | uniq -u`
            fi
        else
            files=`ls`
            eval "$url"
            new_files=`ls`
            dirname=`echo -e "$new_files\n$files" | sort | uniq -u`
        fi
    fi

    if [[ "$path" == "" ]]; then
        cd $dirname
    else
        mkdir -p $path
        mv $dirname $path
        cd $path/$dirname
    fi
}

function install_env(){
    if ! grep C_INCLUDE_PATH $profile &>/dev/null; then
        echo "export PYTHONPATH=$basepath/script:\$PYTHONPATH" >> $profile
        echo "export PATH=$optpath/bin:$optpath/sbin:\$PATH" >> $profile
        # 动态链接库路径
        echo "export LD_LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LD_LIBRARY_PATH" >> $profile
        # 静态链接库路径
        echo "export LIBRARY_PATH=$optpath/lib64:$optpath/lib:\$LIBRARY_PATH" >> $profile
        # gcc 头文件路径
        echo "export C_INCLUDE_PATH=$optpath/include:\$C_INCLUDE_PATH" >> $profile
        # g++ 头文件路径
        echo "export CPLUS_INCLUDE_PATH=$optpath/include:\$CPLUS_INCLUDE_PATH" >> $profile
        # pkgconfig 路径
        echo "export PKG_CONFIG_PATH=$optpath/lib/pkgconfig:\$PKG_CONFIG_PATH" >> $profile
        echo "export LC_ALL=en_US.UTF-8" >> $profile
        echo "export LANG=en_US.UTF-8" >> $profile
        echo "export EDITOR=vim" >> $profile
        source $profile
    fi
}

function install_conf(){
    mkdir -p ~/.pip ~/.m2
    cp $basepath/conf/pip/pip.conf ~/.pip
    cp $basepath/conf/m2/settings.xml ~/.m2
    cp $basepath/conf/npmrc ~/.npmrc

}

function install_zsh(){
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    sed -i s'/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' ~/.zshrc
}

function install_mac(){
    # 安装Xcode Command Line Tools
    xcode-select --install

    # 安装brew
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew install wget axel ctags jq vim mosh htop

    # 安装zsh
    install_zsh
    brew install zsh-syntax-highlighting
    echo "source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> $profile

    cd $basepath/tmp

    download https://iterm2.com/downloads/stable/latest -p /Applications
    download https://atom.io/download/mac -p /Applications

    axel -n20 http://zipzapmac.com/download/Go2Shell
    axel -n20 https://www.charlesproxy.com/assets/release/4.1.3/charles-proxy-4.1.3.dmg

}

function install_jdk(){
    download https://coding.net/u/zkdfbb/p/package/git/raw/master/jdk-8u131-linux-x64.tar.gz -p $runpath

    if ! grep JAVA_HOME $profile &>/dev/null; then
        echo "
export JAVA_HOME=`pwd`
export JRE_HOME=\$JAVA_HOME/jre
export CLASSPATH=\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH" >> $profile
    fi

}

function install_hadoop(){
    download http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-2.8.0/hadoop-2.8.0.tar.gz -p $runpath
    
    if ! grep HADOOP_HOME $profile &>/dev/null; then
        echo "
export HADOOP_HOME=`pwd` >> $profile
export HADOOP_CONF_DIR=\$HADOOP_HOME/conf
export YARN_HOME=\$HADOOP_HOME
export YARN_CONF_DIR=\$HADOOP_CONF_DIR
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$HADOOP_HOME/lib/native
export PATH=\$HADOOP_HOME/bin:\$PATH" >> $profile
    fi
}

function install_pig(){
    download https://mirrors.tuna.tsinghua.edu.cn/apache/pig/pig-0.17.0/pig-0.17.0.tar.gz -p $runpath

    if ! grep PIG_HOME $profile &>/dev/null; then
        echo "
export PIG_HOME=`pwd`
export PIG_CLASSPATH=\$HADOOP_CONF_DIR
export PATH=\$PIG_HOME/bin:\$PATH" >> $profile
    fi
}

function install_spark(){
    download https://mirrors.tuna.tsinghua.edu.cn/apache/spark/spark-2.1.1/spark-2.1.1-bin-hadoop2.7.tgz -p $runpath
    echo "
export SPARK_HOME=`pwd`
export SPARK_LIBRARY_PATH=\$SPARK_HOME/classpath/emr/*:\$SPARK_HOME/classpath/emrfs/*:\$SPARK_HOME/lib/*\$
export PATH=\$SPARK_HOME/bin:\$PATH" >> $profile
}

function install_hbase(){
    download http://archive.apache.org/dist/hbase/0.98.24/hbase-0.98.24-hadoop2-bin.tar.gz -p $runpath
    echo "
export HBASE_HOME=`pwd`
export PIG_CLASSPATH=\`\$HBASE_HOME/bin/hbase classpath\`:\$PIG_CLASSPATH
export HADOOP_CLASSPATH=\`\$HBASE_HOME/bin/hbase classpath\`:\$HADOOP_CLASSPATH
export PATH=\$HBASE_HOME/bin:\$PATH" >> $profile
}

function install_maven(){
    download http://archive.apache.org/dist/maven/maven-3/3.5.0/binaries/apache-maven-3.5.0-bin.tar.gz -p $runpath
    echo "export PATH=`pwd`/bin:\$PATH" >> $profile
}

function install_redis(){
    download "http://download.redis.io/redis-stable.tar.gz"
    mkdir -p $optpath/bin $runpath/redis
    make -j10 && cp src/redis-server src/redis-cli $optpath/bin
    cp redis.conf $runpath/redis
    sed -i 's/daemonize no/daemonize yes/g' $runpath/redis/redis.conf
    cd $runpath/redis
    $optpath/bin/redis-server $runpath/redis/redis.conf
}

function install_mongo(){
    download "http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.4.6.tgz"
    mkdir -p $optpath/bin $runpath/mongo
    cp -r bin/*  $optpath/bin
    cp $basepath/conf/mongod.yaml $runpath/mongo/mongod.yaml
    cd $runpath/mongo
    mkdir -p data logs
    if command -v numactl &>/dev/null; then
        numactl --interleave=all $optpath/bin/mongod -f $runpath/mongo/mongod.yaml
    else
        $optpath/bin/mongod -f $runpath/mongo/mongod.yaml
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
    #    sudo mv /usr/lib64/libstdc++.so.6 /usr/lib64/libstdc++.so.6.bak
    #    sudo ln -s /usr/lib64/libstdc++.so.6.0.21 /usr/lib64/libstdc++.so.6
    #    sudo ldconfig
}

function install_pyenv(){
    export PYENV_ROOT=$runpath/pyenv
    if ! grep PYENV_VIRTUALENV_DISABLE_PROMPT $profile &>/dev/null; then
        echo "export PYENV_ROOT=$runpath/pyenv" >> $profile
        echo "export PATH=$PYENV_ROOT/bin:\$PATH" >> $profile
        echo "export PYENV_VIRTUALENV_DISABLE_PROMPT=1" >> $profile
        echo "export PYTHON_CONFIGURE_OPTS=\"--enable-shared\"" >> $profile
    fi
    source $profile
    curl -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | sh
    if ! grep "virtualenv-init" $profile &>/dev/null; then
        echo "eval \"\$(pyenv init -)\"" >> $profile
        echo "eval \"\$(pyenv virtualenv-init -)\"" >> $profile
    fi
    if command -v pyenv &>/dev/null; then
        source $profile
        CFLAGS="-I $optpath/include" LDFLAGS="-L $optpath/lib" pyenv install 2.7.13
        pyenv global 2.7.13
        pyenv virtualenv 2.7.13 py2
        return 0
    else
        return 1
    fi
}

function install_supervisor(){
    mkdir -p $runpath/supervisor/logs
    mkdir -p $runpath/supervisor/proc
    mkdir -p $runpath/supervisor/conf.d

    if ! grep supervisorctl $profile &>/dev/null; then
        echo "export SUPERVISOR_HOME=$runpath/supervisor" >> $profile
        echo "alias supervisorctl='supervisorctl -c $runpath/supervisor/supervisord.ini'" >> $profile
    fi
    source $profile

    pip install supervisor

    cp $basepath/conf/supervisord.ini $runpath/supervisor/
    cd $runpath/supervisor
    supervisord -c $runpath/supervisor/supervisord.ini
    #sudo chkconfig supervisord on
}

function install_download(){
    mkdir -p $basepath/upload/data
    download_path="${basepath//\//\/}\/upload\/data"
    cp $basepath/conf/nginx.conf $optpath/conf/nginx.conf
    sed -i "s/download_path/$download_path/g" $optpath/conf/nginx.conf
    ps -ef | grep $USER | grep -v grep | grep nginx | awk '{print $2}' | xargs kill -9
    $optpath/sbin/nginx -c $optpath/conf/nginx.conf
}

function install_upload(){
    cd $basepath/upload
    mkdir -p data logs
    ps -ef | grep upload.py | grep -v "grep" | grep "port=7000" | awk '{print $2}' | xargs kill -9
    nohup python $basepath/upload/upload.py -port=7000 -log_file_prefix=logs/upload.log &>/dev/null &
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
        if command -v install_$package &>/dev/null; then
            cmd=install_$package
        elif [[ "$sections" =~ $package ]]; then
            url=`readini $package url $config`
            cmd=`readini $package command $config`
            binary=`readini $package binary $config`

            if [[ "$command" == "" ]]; then
                cmd="./configure --prefix=$optpath && make -j10 && make install"
            fi

            download_cmd="download $url"
            if [[ "$binary" == "true" ]]; then
                download_cmd="$download_cmd -p $runpath"
            fi
            $download_cmd

            if [[ "$binary" == "true" ]]; then
                continue
            fi
        else
            echo "$package configure is not found !!!"
            continue
        fi
        set -o pipefail; eval "$cmd" | tee -a $basepath/script/logs/${package}.log

        if [[ $? -eq 0 ]]; then
            echo "$package install succeed" >> $basepath/script/result.log
            if [[ "$package" == "python" ]]; then
                if grep "Successfully installed pip" $basepath/script/logs/${package}.log &>/dev/null ; then
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

