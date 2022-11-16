#!/bin/bash

cd $(pwd)

echo "请选择需要操作的模式:"
echo "1.压缩"
echo "2.复制"
echo "3.快速复制public_html"
echo "4.数据库备份"

read anum
case $anum in
    1) 
    oargs="tar"
    echo "当前操作模式为:压缩"
    ;;
    2) 
    oargs="cp"
    echo "当前操作模式为:复制"
    ;;
    3) 
    oargs="cpp"
    echo "当前操作模式为:快速复制public_html"
    ;;
    4)
    echo "当前操作模式为:备份数据库"
    oargs="bkdb"
    ;;
    *)
    echo "无匹配模式,退出"
    ;;
esac

case $oargs in
    tar)
    echo "请输入需要压缩的CyberPanel网站域名:"
    read srcdir
    echo "压缩目录为/home/$srcdir/public_html"
    tar czvf $srcdir.tar.gz -C /home/$srcdir/public_html/ .
    echo "数据压缩完毕,数据保存在$(pwd)/$srcdir.tar.gz"
    ;;
    cp)
    echo "请输入需要复制的原网站目录:"
    read srcweb
    echo "请输入需要复制到的目标网站目录:"
    read destweb
    cp -r /home/$srcweb/* /home/$destweb
    echo "目录数据复制完毕"
    ;;
    cpp)
    echo "请输入需要复制的原网站目录:"
    read srcweb
    echo "请输入需要复制到的目标网站目录:"
    read destweb
    cp -r /home/$srcweb/public_html/* /home/$destweb/public_html/
    echo "public_html快速复制完毕"
    ;;
    bkdb)
        echo "请输入需要备份的数据库名称:"
        read dbname
        mysql_host="localhost"
        mysql_user="root"
        mysql_pwd=`cat /etc/cyberpanel/mysqlPassword`

        #保存备份sql的文件路径
        db_dir="$(pwd)"

        db_arr=$(echo 'show databases' | mysql -u$mysql_user -p$mysql_pwd -h$mysql_host)

        #获得当前日期
        date=$(date +%Y%m%d%H%M%S)

        ziname=$date".zip"
        #指定的数据库文件
        thisdb=$dbname

        #sql文件名称
        sqlfile=$thisdb"_"$date".sql"
        for dbname in ${db_arr}
        do
           if [ $thisdb == $dbname ];then
                mysqldump -u$mysql_user -p$mysql_pwd -h$mysql_host $dbname > $db_dir"/"$sqlfile
           fi
        done
    ;;
    *)
    echo "没有匹配的操作,退出"
    exit 0
    ;;
esac