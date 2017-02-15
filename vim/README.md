# vim 配置文件

**在其他机器上部署**
```shell
    #部署
    参考script/setup.sh手动部署

    #或者直接使用下面的命令
    #wget -qO- https://raw.githubusercontent.com/zkdfbb/vim/master/scripts/setup.sh --no-check-certificate | sh
    wget -qO- https://coding.net/u/zkdfbb/p/vim/git/raw/master/scripts/setup.sh --no-check-certificate | sh
    
    #插件说明
    YouComplete和neocomplete都是补全插件,两者使用其一即可,默认启用neocomplete
```


# 本配置使用Vundle来管理，插件初始化
```shell
    vim
    :BundleInstall    #安装
    :BundleUpdate     #升级
```

# 若使用pathogen来管理

**submodule初始化**
```shell
    cd ~/.vim
    git submodule init
    git submodule update
```

**升级所有插件**
```shell
    cd ~/.vim
    git submodule foreach git pull origin master
```

**删除一个插件，要求版本git >= 1.8.3**
```shell
    git submodule deinit bundle/markdown
    git rm bundle/markdown
    rm -rf .git/modules/bundle/markdown
```

**插件简介**

YouCompleteMe   补全插件

    apt-get install build-essential cmake
    cd ~/.vim/bundle/YouCompleteMe
    git submodule update --init --recursive
    ./install.sh --clang-completer

neocomplete     补全插件
    
    apt-get install ncurses-dev python-dev lua5.1 liblua5.1-dev -y
    需要vim添加lua支持

xptemplate    重复代码插件

    在insert模式下输入片段代码的名字(如switch)，然后按<C-\>(即Ctrl+\)
    然后按tab、shift tab前后更改高亮显示的内容

Tagbar    taglist插件

    apt-get install ctags

Pymode

    要求python使用--enable-shared参数编译

emmet

    输入缩略词组div#page>ul>li*3然后按Ctrl+y+,即可展开成html代码


SingleCompile

    #编译运行一个简单的源文件，绑定按键F5
    nmap <F5> :SCCompileRun<cr>


**VIM技巧**

[Vim编程——配置与技巧](http://linux-wiki.cn/wiki/%E7%94%A8Vim%E7%BC%96%E7%A8%8B%E2%80%94%E2%80%94%E9%85%8D%E7%BD%AE%E4%B8%8E%E6%8A%80%E5%B7%A7)

