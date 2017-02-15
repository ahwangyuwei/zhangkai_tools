#!/usr/bin/env bash
# -*- coding:utf-8 -*-

#if [ -f /usr/bin/lsb_release ]; then
#    OS=$(/usr/bin/lsb_release -d | awk '{print $2}' | sed 's/^[ t]*//g' | tr [A-Z] [a-z])
#else
#   OS=$(cat /etc/issue | sed -n '1p' | awk '{print $1}' | tr [A-Z] [a-z])
#fi

set -x

rm -rf ~/.vim  ~/.vimrc
git clone https://git.coding.net/zkdfbb/vim.git ~/.vim
cd ~/.vim
vimpath=`pwd`

version=`vim --version | grep "8.0" | wc -l`
python=`vim --version | grep "+python" | wc -l`
lua=`vim --version | grep "+lua" | wc -l`
if [ $version -eq 1 ] && [ $python -eq 1 ] && [ $lua -eq 1 ]; then
    echo "vim is updated"
    exit 0
fi

if `command -v apt-get >/dev/null 2>&1`; then
    cmd="apt-get install ncurses-dev python python-dev lua5.1 lua5.1-dev liblua5.1-dev ctags cmake build-essential gcc make -y"
elif `command -v yum >/dev/null 2>&1`; then
    cmd="yum install ncurses-devel python-devel lua lua-devel ctags cmake gcc gcc-c++ -y"
elif `command -v brew >/dev/null 2>&1`; then
    brew install python lua vim
    exit 0
else
    echo "please install python python-dev lua lua-dev mannually!"
    exit 1
fi

#安装依赖,添加python,lua支持除了安装python,lua5.1以外还需要安装对于的dev, 可选perl,ruby
if [ $(id -u) != "0" ]; then
    eval sudo $cmd
else
    eval $cmd
fi

#安装最新版的vim，YouCompleteMe要求VIM版本>=7.4, neocomplete要求vim添加lua支持
cd $vimpath
git clone --depth=1 https://github.com/vim/vim.git
cd vim

./configure --with-features=huge --enable-cscope --enable-fontset --enable-multibyte --enable-pythoninterp=yes --enable-luainterp=yes --with-lua-prefix=/usr/local && make -j10 && sudo make install && \
rm -rf $vimpath/vim && \
echo "everything is done successful"

#vim +BundleInstall +qall &>/dev/null && \

#cd ~/.vim/bundle/YouCompleteMe
#git submodule update --init --recursive
#./install.sh --clang-completer
