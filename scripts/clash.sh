#!/bin/sh
# Copyright (C) Juewuy

getconfig(){
#系统类型
systype=$(cat /proc/version | grep -io openwrt)
if [ -n "$systype" ];then
	host=$(ubus call network.interface.lan status | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
	if [ -f /etc/rc.d/*clash ];then
		autostart=enable_rc
	else
		autostart=disable_rc
	fi
else
	cron_user='root '
	host=$(ip a|grep -w 'inet'|grep 'global'|grep -E '192.|10.'|sed 's/.*inet.//g'|sed 's/\/[0-9][0-9].*$//g')
	[ -z $host ] && host=127.0.0.1
	if [ -n "$(systemctl list-unit-files clash.service | grep -o enable)" ];then
		autostart=enable_sys
	else
		autostart=disable_sys
	fi
fi
#服务器地址
[ -z "$update_url" ] && update_url=https://cdn.jsdelivr.net/gh/juewuy/ShellClash
#文件路径
[ -z "$clashdir" ] && clashdir=$(dirname $(readlink -f "$0")) && echo "export clashdir=\"$clashdir\"" >> /etc/profile
ccfg=$clashdir/mark
yaml=$clashdir/config.yaml
#检查/读取标识文件
if [ ! -f $ccfg ]; then
	echo mark文件不存在，正在创建！
	cat >$ccfg<<EOF
#标识clash运行状态的文件，不明勿动！
EOF
fi
source $ccfg
#检查mac地址记录
[ ! -f $clashdir/mac ] && touch $clashdir/mac
#获取自启状态
if [ "$start_old" = "已开启" ];then
	auto="\033[33m已设置保守模式！\033[0m"
	auto1="\033[36m设为\033[0m常规模式启动"
elif [ "$autostart" = "enable_rc" -o "$autostart" = "enable_sys" ]; then
	auto="\033[32m已设置开机启动！\033[0m"
	auto1="\033[36m禁用\033[0mclash开机启动"
else
	auto="\033[31m未设置开机启动！\033[0m"
	auto1="\033[36m允许\033[0mclash开机启动"
fi
#获取运行模式
if [ -z "$redir_mod" ];then
	sed -i "2i\redir_mod=Redir模式" $ccfg
	redir_mod=Redir模式
fi
#获取运行状态
PID=$(pidof clash)
if [ -n "$PID" ];then
	run="\033[32m正在运行（$redir_mod）\033[0m"
	VmRSS=`cat /proc/$PID/status|grep -w VmRSS|awk '{print $2,$3}'`
	#获取运行时长
	if [ -n "$start_time" ]; then 
		time=$((`date +%s`-$start_time))
		day=$(($time/86400))
		if [[ $day != 0 ]]; then 
			day=$day天
		else
			day=""
		fi
		time=`date -u -d @${time} +"%-H小时%-M分%-S秒"`
	fi
else
	run="\033[31m没有运行（$redir_mod）\033[0m"
fi
#输出状态

echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;46m欢迎使用ShellClash！\033[0m      版本：$versionsh_l"
echo -e "Clash服务"$run"，"$auto""
if [ -n "$PID" ];then
	echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
fi
echo -e "TG群：\033[36;4mhttps://t.me/clashfm\033[0m"
echo -----------------------------------------------
#检查clash核心
if [ ! -f $clashdir/clash ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m没有找到核心文件，请先下载clash核心！\033[0m"
	source $clashdir/getdate.sh
	getcore
fi
#检查GeoIP数据库
if [ ! -f $clashdir/Country.mmdb ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m没有找到GeoIP数据库文件，请先下载数据库！\033[0m"
	source $clashdir/getdate.sh
	getgeo
	clashstart
fi
}
clashstart(){
	if [ ! -f "$yaml" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m没有找到配置文件，请先导入节点/订阅链接！\033[0m"
		clashlink
	fi
	if [ -n "$PID" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		$clashdir/start.sh stop
		echo -e "\033[31mClash服务已停止！\033[0m"
	fi
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	$clashdir/start.sh start
	sleep 1
	PID=$(pidof clash)
	if [ -z "$PID" ];then
		echo -e "\033[31mclash启动失败！\033[0m" 
		exit
	fi

	echo -e "\033[32mclash服务已启动！\033[0m"
	if [ -d /www/clash ];then
		echo -e "请使用\033[30;47m http://$host/clash \033[0m管理内置规则"
	elif [ -d $clashdir/ui  ];then
		echo -e "请使用\033[30;47m http://$host:9999/ui \033[0m管理内置规则"
	else
		echo -e "可使用\033[30;47m http://clash.razord.top \033[0m管理内置规则"
		echo -e "Host地址:\033[36m $host \033[0m 端口:\033[36m 9999 \033[0m"
		echo -e "也可前往更新菜单安装本地Dashboard面板，连接更稳定！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	fi
}
clashlink(){
#获取订阅规则
if [ -z "$rule_link" ]; then
	sed -i '/rule_link=*/'d $ccfg
	sed -i "4i\rule_link=1" $ccfg
	rule_link=1
fi
#获取后端服务器地址
if [ -z "$server_link" ]; then
	sed -i '/server_link=*/'d $ccfg
	sed -i "5i\server_link=1" $ccfg
	server_link=1
fi
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m 欢迎使用订阅功能！\033[0m"
echo -----------------------------------------------
echo -e " 1 导入\033[36m节点/订阅\033[0m链接"
echo -e " 2 使用完整clash规则链接"
echo -e " 3 添加/修改\033[32m节点过滤\033[0m关键字 \033[47;30m$exclude\033[0m"
echo -e " 4 选取\033[33mclash配置规则\033[0m模版"
echo -e " 5 选择在线生成服务器"
echo -e " 6 \033[36m还原\033[0m配置文件"
echo -e " 7 \033[32m手动更新\033[0m订阅"
echo -----------------------------------------------
echo -e " 0 返回上级菜单"
read -p "请输入对应数字 > " num
if [ -z "$num" ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashsh
elif [[ $num == 1 ]];then
	if [ -n "$Url" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m检测到已记录的订阅链接：\033[0m"
		echo -e "\033[4;32m$Url\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		read -p "清空链接/追加导入？[1/0] > " res
		if [ "$res" = '1' ]; then
			Url=""
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m链接已清空！\033[0m"
		fi
	fi
	source $clashdir/getdate.sh
	getlink
  
elif [[ $num == 2 ]];then
	if [ -n "$Url" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m检测到已记录的订阅链接：\033[0m"
		echo -e "\033[4;32m$Url\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		read -p "清空链接/追加导入？[1/0] > " res
		if [ "$res" = '1' ]; then
			Url=""
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m链接已清空！\033[0m"
		fi
	fi
	source $clashdir/getdate.sh
	getlink2
	
elif [[ $num == 3 ]];then
	source $clashdir/getdate.sh
	linkfilter
	clashlink
	
elif [[ $num == 4 ]];then
	source $clashdir/getdate.sh
	linkconfig
	clashlink
	
elif [[ $num == 5 ]];then
	source $clashdir/getdate.sh
	linkserver
	clashlink
	
elif [[ $num == 6 ]];then
	yamlbak=$yaml.bak
	if [ ! -f "$yaml".bak ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m没有找到配置文件的备份！\033[0m"
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e 备份文件共有"\033[32m`wc -l < $yamlbak`\033[0m"行内容，当前文件共有"\033[32m`wc -l < $yaml`\033[0m"行内容
		read -p "确认还原配置文件？此操作不可逆！[1/0] > " res
		if [ "$res" = '1' ]; then
			mv $yamlbak $yaml
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[32m配置文件已还原！请手动重启clash服务！\033[0m"
		else 
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m操作已取消！返回上级菜单！\033[0m"
		fi
	fi
	clashsh
	
elif [[ $num == 7 ]];then
	if [ -z "$Url" -a -z "$Https" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo 没有找到你的订阅链接！请先输入链接！
		clashlink
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m当前系统记录的订阅链接为：\033[0m"
		echo -e "\033[4;32m$Url\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		read -p "确认更新配置文件？[1/0] > " res
		if [ "$res" = '1' ]; then
			$clashdir/start.sh getyaml
		fi
		clashlink
	fi
elif [[ $num == 0 ]];then
	clashsh
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	exit;
fi
}
clashcfg(){
#获取设置默认显示
[ -z "$skip_cert" ] && skip_cert=已开启
[ -z "$common_ports" ] && common_ports=已开启
[ -z "$dns_mod" ] && dns_mod=redir_host
[ -z "$dns_over" ] && dns_over=已开启
if [ -z "$(cat $clashdir/mac)" ]; then
	mac_return=未开启
else
	mac_return=已启用
fi
#
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m欢迎使用功能设置菜单：\033[0m"
echo -e "\033[32m修改配置后请手动重启clash服务！\033[0m"
echo -----------------------------------------------
echo -e " 1 切换Clash运行模式: 	\033[36m$redir_mod\033[0m"
echo -e " 2 切换DNS运行模式：	\033[36m$dns_mod\033[0m"
echo -e " 3 跳过本地证书验证：	\033[36m$skip_cert\033[0m   ————解决节点证书验证错误"
echo -e " 4 只代理常用端口： 	\033[36m$common_ports\033[0m   ————用于屏蔽P2P流量"
echo -e " 5 过滤局域网mac地址：	\033[36m$mac_return\033[0m   ————列表内设备不走代理"
echo -e " 6 不使用本地DNS服务：	\033[36m$dns_over\033[0m   ————防止redir-host模式的dns污染"
echo -----------------------------------------------
echo -e " 9 \033[32m重启\033[0mclash服务"
echo -e " 0 返回上级菜单 \033[0m"
echo -----------------------------------------------
read -p "请输入对应数字 > " num
if [[ $num -le 9 ]] > /dev/null 2>&1; then 
	if [[ $num == 0 ]]; then
		clashsh  
	elif [[ $num == 1 ]]; then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "当前代理模式为：\033[47;30m $redir_mod \033[0m；Clash核心为：\033[47;30m $clashcore \033[0m"
		echo -e "\033[33m切换模式后需要手动重启clash服务以生效！\033[0m"
		echo -e "\033[36mTun及混合模式必须使用clashpre核心！\033[0m"
		echo -----------------------------------------------
		echo " 1 Redir模式：CPU以及内存占用较低"
		echo "              但不支持UDP流量转发"
		echo "              日常使用推荐此模式"
		echo " 2 Tun模式：  支持UDP转发且延迟低"
		echo "              但CPU及内存占用更高"
		echo "              且不支持redir-host"
		echo " 3 混合模式： 仅使用Tun转发UPD流量"
		echo "              CPU和内存占用较高"
		echo "              不推荐使用redir-host"
		echo " 4 纯净模式： 不设置iptables静态路由"
		echo "              必须手动配置http/sock5代理"
		echo " 0 返回上级菜单"
		read -p "请输入对应数字 > " num	
		if [ -z "$num" ]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashcfg
		elif [[ $num == 0 ]]; then
			clashcfg
		elif [[ $num == 1 ]]; then
			redir_mod=Redir模式
		elif [[ $num == 2 ]]; then
			if [ "$clashcore" = "clash" ] || [ "$clashcore" = "clashr" ];then
				echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
				echo -e "\033[31m当前核心不支持开启Tun模式！请先切换clash核心！！！\033[0m"
				clashcfg
			fi
			redir_mod=Tun模式
			dns_mod=fake-ip
		elif [[ $num == 3 ]]; then
			if [ "$clashcore" = "clash" ] || [ "$clashcore" = "clashr" ];then
				echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
				echo -e "\033[31m当前核心不支持开启Tun模式！请先切换clash核心！！！\033[0m"
				clashcfg
			fi
			redir_mod=混合模式	
		elif [[ $num == 4 ]]; then
			redir_mod=纯净模式			
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[32m已经设置为纯净模式！\033[0m"
			echo -e "\033[33m当前模式必须手动在设备WiFi或应用中配置HTTP或sock5代理\033[0m"
			echo -e "HTTP/SOCK5代理服务器地址：\033[30;47m$host\033[0m;端口均为：\033[30;47m7890\033[0m"
			echo -e "\033[31m也可以使用PAC自动代理文件，具体使用方法请自行搜索\033[0m"
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			read -p "是否配置自动代理PAC文件(1/0) > " res
				if [ "$res" = 1 ]; then
					source $clashdir/getdate.sh && catpac
				fi
		else
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashcfg
		fi
		sed -i '/redir_mod*/'d $ccfg
		sed -i "1i\redir_mod=$redir_mod" $ccfg
		sed -i '/dns_mod*/'d $ccfg
		sed -i "1i\dns_mod=$dns_mod" $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
		echo -e "\033[36m已设为 $redir_mod ！！\033[0m"
		clashcfg
	  
	elif [[ $num == 2 ]]; then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "当前DNS运行模式为：\033[47;30m $dns_mod \033[0m"
		echo -e "\033[33m切换模式后需要手动重启clash服务以生效！\033[0m"
		echo -----------------------------------------------
		echo " 1 fake-ip模式：   响应速度更快"
		echo "                   不兼容部分软件"
		echo " 2 redir_host模式：使用稳定，兼容性好"
		echo "                   不支持Tun模式"
		echo " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashcfg
		elif [[ $num == 0 ]]; then
			clashcfg
		elif [[ $num == 1 ]]; then
			dns_mod=fake-ip
		elif [[ $num == 2 ]]; then
			dns_mod=redir_host
			redir_mod=Redir模式
		else
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashcfg
		fi
		sed -i '/dns_mod*/'d $ccfg
		sed -i "1i\dns_mod=$dns_mod" $ccfg
		sed -i '/redir_mod*/'d $ccfg
		sed -i "1i\redir_mod=$redir_mod" $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
		echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
		clashcfg
	
	elif [[ $num == 3 ]]; then	
		sed -i '/skip_cert*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$skip_cert" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\skip_cert=已开启" $ccfg
			echo -e "\033[33m已设为开启跳过本地证书验证！！\033[0m"
			skip_cert=已开启
		else
			sed -i "1i\skip_cert=未开启" $ccfg
			echo -e "\033[33m已设为禁止跳过本地证书验证！！\033[0m"
			skip_cert=未开启
		fi
		clashcfg
	
	elif [[ $num == 4 ]]; then	
		sed -i '/common_ports*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$common_ports" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\common_ports=已开启" $ccfg
			echo -e "\033[33m已设为仅代理（22,53,587,465,995,993,143,80,443）等常用端口！！\033[0m"
			common_ports=已开启
		else
			sed -i "1i\common_ports=未开启" $ccfg
			echo -e "\033[33m已设为代理全部端口！！\033[0m"
			common_ports=未开启
		fi
		clashcfg  

	elif [[ $num == 5 ]]; then	
	
		add_mac(){
			echo -----------------------------------------------
			echo -e "\033[33m序号   设备IP       设备mac地址       设备名称\033[32m"
			cat /tmp/dhcp.leases | awk '{print " "NR" "$3,$2,$4}'
			echo -e "\033[0m 0 或回车 结束添加"
			read -p "请输入对应序号 > " num
			if [ -z "$num" ]; then
				clashcfg
			elif [ $num -le 0 ]; then
				clashcfg
			elif [ $num -le $(cat /tmp/dhcp.leases | awk 'END{print NR}') ]; then
				macadd=$(cat /tmp/dhcp.leases | awk '{print $2}' | sed -n "$num"p)
				if [ -z $(cat $clashdir/mac | grep -E "$macadd") ];then
					echo $macadd >> $clashdir/mac
					echo -----------------------------------------------
					echo 已添加的mac地址：
					cat $clashdir/mac
				else
					echo -----------------------------------------------
					echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
				fi
			else
				echo -----------------------------------------------
				echo -e "\033[31m输入有误，请重新输入！\033[0m"
			fi
			add_mac
		}
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m请在此添加或移除设备\033[0m"
		if [ -n "$(cat $clashdir/mac)" ]; then
			echo -e "当前已过滤设备为：\033[36m"
			for mac in $(cat $clashdir/mac); do
				cat /tmp/dhcp.leases | awk '{print $3,$2,$4}' | grep $mac
			done
			echo -e "\033[0m-----------------------------------------------"
		fi
		echo -e " 1 \033[31m清空列表\033[0m"
		echo -e " 2 \033[32m添加设备\033[0m"
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashcfg
		elif [[ $num == 0 ]]; then
			clashcfg
		elif [[ $num == 1 ]]; then
			:>$clashdir/mac
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m设备列表已清空！\033[0m"
			sleep 1
			clashcfg
		elif [[ $num == 2 ]]; then	
			add_mac
			
		else
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashcfg
		fi
		
	elif [[ $num == 6 ]]; then	
		sed -i '/dns_over*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$dns_over" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\dns_over=已开启" $ccfg
			echo -e "\033[33m已设置DNS为不走本地dnsmasq服务器！\033[0m"
			echo -e "可能会对浏览速度产生一定影响，介意勿用！"
			dns_over=已开启
		else
			/etc/init.d/clash enable
			sed -i "1i\dns_over=未开启" $ccfg
			echo -e "\033[32m已设置DNS通过本地dnsmasq服务器！\033[0m"
			echo -e "redir-host模式下部分网站可能会被运营商dns污染导致无法打开"
			dns_over=未开启
		fi
		clashcfg  
		
	elif [[ $num == 9 ]]; then	
		clashstart
		clashsh
	else
		echo -e "\033[31m暂未支持的选项！\033[0m"
		clashcfg
	fi
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashsh
fi
exit;
}
clashadv(){
#获取设置默认显示
[ -z "$modify_yaml" ] && modify_yaml=未开启
[ -z "$ipv6_support" ] && ipv6_support=未开启
[ -z "$start_old" ] && start_old=未开启
[ -z "$local_proxy" ] && local_proxy=未开启
#
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m欢迎使用进阶模式菜单：\033[0m"
echo -e "\033[33m如您不是很了解clash的运行机制，请勿更改！\033[0m"
echo -e "\033[32m修改配置后请手动重启clash服务！\033[0m"
echo -----------------------------------------------
echo -e " 1 不修饰config.yaml:	\033[36m$modify_yaml\033[0m   ————用于使用自定义配置"
echo -e " 2 启用ipv6支持:	\033[36m$ipv6_support\033[0m   ————实验性且不兼容Fake_ip"
echo -e " 3 使用保守方式启动:	\033[36m$start_old\033[0m   ————切换时会停止clash服务"
echo -e " 4 代理本机流量:	\033[36m$local_proxy\033[0m   ————配置本机代理环境变量"
echo -----------------------------------------------
echo -e " 8 \033[31m重置\033[0m配置文件"
echo -e " 9 \033[32m重启\033[0mclash服务"
echo -e " 0 返回上级菜单 \033[0m"
echo -----------------------------------------------
read -p "请输入对应数字 > " num
if [[ $num -le 9 ]] > /dev/null 2>&1; then 
	if [[ $num == 0 ]]; then
		clashsh  
	
	elif [[ $num == 1 ]]; then	
		sed -i '/modify_yaml*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$modify_yaml" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\modify_yaml=已开启" $ccfg
			echo -e "\033[33m已设为使用用户完全自定义的配置文件！！"
			echo -e "\033[36m不明白原理的用户切勿随意开启此选项"
			echo -e "\033[31m！！！必然会导致上不了网！！!\033[0m"
			modify_yaml=已开启
			sleep 3
		else
			sed -i "1i\modify_yaml=未开启" $ccfg
			echo -e "\033[32m已设为使用脚本内置规则管理config.yaml配置文件！！\033[0m"
			modify_yaml=未开启
		fi
		clashadv  
		
	elif [[ $num == 2 ]]; then	
		sed -i '/ipv6_support*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$ipv6_support" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\ipv6_support=已开启" $ccfg
			echo -e "\033[33m已开启对ipv6协议的支持！！\033[0m"
			echo -e "Clash对ipv6的支持并不友好，如不能使用请静等修复！"
			ipv6_support=已开启
			sleep 2
		else
			sed -i "1i\ipv6_support=未开启" $ccfg
			echo -e "\033[32m已禁用对ipv6协议的支持！！\033[0m"
			ipv6_support=未开启
		fi
		clashadv  
		
	elif [[ $num == 3 ]]; then	
		sed -i '/start_old*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$start_old" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\start_old=已开启" $ccfg
			echo -e "\033[33m改为使用保守方式启动clash服务！！\033[0m"
			echo -e "\033[36m此模式兼容性更好但无法禁用开机启动！！\033[0m"
			start_old=已开启
			$clashdir/start.sh stop > /dev/null 2>&1
			sleep 2
		else
			sed -i "1i\start_old=未开启" $ccfg
			echo -e "\033[32m改为使用默认方式启动clash服务！！\033[0m"
			start_old=未开启
			$clashdir/start.sh stop > /dev/null 2>&1
		fi
		clashadv  
		
	elif [[ $num == 4 ]]; then	
		sed -i '/local_proxy*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$local_proxy" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\local_proxy=已开启" $ccfg
			local_proxy=已开启
			echo 'export http_proxy=http://127.0.0.1:7890' >> /etc/profile
			echo 'export https_proxy=$http_proxy' >> /etc/profile
			echo 'export HTTP_PROXY=$http_proxy' >> /etc/profile
			echo 'export HTTPS_PROXY=$http_proxy' >> /etc/profile
			echo -e "\033[32m已经将代理参数写入环境变量~\033[0m"
			echo -e "\033[36m如未生效，请重新登录或者重启设备！\033[0m"
			sleep 1
		else
			sed -i "1i\local_proxy=未开启" $ccfg
			sed -i '/http*_proxy/'d /etc/profile
			sed -i '/HTTP*_PROXY/'d /etc/profile
			echo -e "\033[33m已经将代理参数从环境变量移除！！\033[0m"
			local_proxy=未开启
		fi
		source /etc/profile > /dev/null 2>&1
		clashadv 		
		
	elif [[ $num == 8 ]]; then	
		read -p "确认重置配置文件？(1/0) > " res
		if [ "$res" = "1" ];then
			echo "versionsh_l=$versionsh_l" > $ccfg
			echo "start_time=$start_time" >> $ccfg
			echo "#标识clash运行状态的文件，不明勿动！" >> $ccfg
			echo -e "\033[33m配置文件已重置，请重新运行脚本！\033[0m"
			exit
		fi
		clashadv
		
	elif [[ $num == 9 ]]; then	
		clashstart
		clashsh
	else
		echo -e "\033[31m暂未支持的选项！\033[0m"
		clashsh
	fi
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashsh
fi
exit;
}
update(){
if [ -z "$release_new" ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[33m正在检查更新！\033[0m"
	release_new=$(curl -kfsSL --resolve api.github.com:443:140.82.113.5 "https://api.github.com/repos/juewuy/ShellClash/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
	[ -z "$release_new" ] && release_new=$(curl -kfsSL $update_url/bin/version | grep "versionsh" | awk -F "=" '{print $2}')
	[ -z "$release_new" ] && echo "检查更新失败！"
fi
[ "$update_url" = "https://cdn.jsdelivr.net/gh/juewuy/ShellClash" ] && update_url=$update_url@$release_new
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m欢迎使用更新功能：\033[0m"
[ -n "$release_new" ] && echo -e "当前ShellClash版本：\033[33m $versionsh_l \033[0m"
[ -n "$release_new" ] && echo -e "最新ShellClash版本：\033[32m $release_new \033[0m"
echo -----------------------------------------------
echo -e " 1 更新\033[36m管理脚本\033[0m"
echo -e " 2 切换\033[33mclash核心\033[0m"
echo -e " 3 更新\033[32mGeoIP数据库\033[0m"
echo -e " 4 安装本地\033[35mDashboard\033[0m面板"
echo -e " 5 生成本地PAC文件(需先安装本地面板)"
echo -----------------------------------------------
echo -e " 7 切换\033[36m安装源\033[0m地址"
echo -e " 8 鸣谢"
echo -e " 9 \033[31m卸载\033[34mClash for Miwfi\033[0m"
echo -e " 0 返回上级菜单" 
echo -----------------------------------------------
read -p "请输入对应数字 > " num
if [[ $num -le 9 ]] > /dev/null 2>&1; then 
	if [[ $num == 0 ]]; then
		clashsh
	
	elif [[ $num == 1 ]]; then	
		source $clashdir/getdate.sh
		getsh	
	
	elif [[ $num == 2 ]]; then	
		source $clashdir/getdate.sh
		getcore

	elif [[ $num == 3 ]]; then	
		source $clashdir/getdate.sh
		getgeo
		update
	
	elif [[ $num == 4 ]]; then	
		source $clashdir/getdate.sh
		getdb
		
	elif [[ $num == 5 ]]; then	
		source $clashdir/getdate.sh
		catpac
		update

	elif [[ $num == 7 ]]; then	
		source $clashdir/getdate.sh
		setserver
		
	elif [[ $num == 8 ]]; then		
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "感谢：\033[32mClash \033[0m作者\033[36m Dreamacro\033[0m 项目地址：\033[32mhttps://github.com/Dreamacro/clash\033[0m"
		echo -e "感谢：\033[32malecthw大神提供的GeoIP数据库\033[0m 项目地址：\033[32mhttps://github.com/alecthw/mmdb_china_ip_list\033[0m"
		echo -e "感谢：\033[32m更多的帮助过我的人！\033[0m"
		update	
		
	elif [[ $num == 9 ]]; then
		read -p "确认卸载clash？（警告：该操作不可逆！）[1/0] " res
		if [ "$res" = '1' ]; then
			/etc/init.d/clash disable
			/etc/init.d/clash stop
			rm -rf $clashdir
			rm -rf /etc/init.d/clash
			rm -rf /etc/systemd/system/clash.service
			rm -rf /usr/lib/systemd/system/clash.service
			rm -rf /www/clash
			rm -rf $csh
			sed -i '/alias clash=*/'d /etc/profile
			sed -i '/export clashdir=*/'d /etc/profile
			source /etc/profile > /dev/null 2>&1
			echo 已卸载clash相关文件！
			exit
		fi
		echo -e "\033[31m操作已取消！\033[0m"
		exit;
	else
		echo -e "\033[31m暂未支持的选项！\033[0m"
		update
	fi
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashsh
fi
exit;
}
clashcron(){

	setcron(){
	echo -----------------------------------------------
	echo -e " 正在设置：\033[32m$cronname\033[0m定时任务"
	echo -e " 输入  1-7  对应\033[33m每周相应天\033[0m运行"
	echo -e " 输入   8   设为\033[33m每天定时\033[0m运行"
	echo -e " 输入 1,3,6 代表\033[36m每周1,3,6\033[0m运行(注意用小写逗号分隔)"
	echo -----------------------------------------------
	echo -e " 输入   9   \033[31m删除定时任务\033[0m"
	echo -e " 输入   0   返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then 
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		clashcron
	elif [[ $num == 0 ]]; then
		clashcron
	elif [[ $num == 9 ]]; then
		sed -i /$cronname/d $cronpath
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m定时任务：$cronname已删除！\033[0m"
		clashcron
	elif [[ $num == 8 ]]; then	
		week='*'
		week1=每天
		echo 已设为每天定时运行！
	else
		week=$num	
		week1=每周$week
		echo 已设为每周 $num 运行！
	fi
	#设置具体时间
	echo -----------------------------------------------
	read -p "请输入小时（0-23） > " num
	if [ -z "$num" ]; then 
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		setcron
	elif [ $num -gt 23 ] || [ $num -lt 0 ]; then 
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		setcron
	else	
		hour=$num
	fi
	echo -----------------------------------------------
	read -p "请输入分钟（0-60） > " num
	if [ -z "$num" ]; then 
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		setcron
	elif [ $num -gt 60 ] || [ $num -lt 0 ]; then 
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		setcron
	else	
		min=$num
	fi
	echo -----------------------------------------------
	echo 将在$week1的$hour点$min分$cronname（旧的任务会被覆盖）
	read -p  "是否确认添加定时任务？(1/0) > " res
		if [ "$res" = '1' ]; then
			sed -i /$cronname/d $cronpath
			echo "$min $hour * * $week $cron_user$cronset >/dev/null 2>&1 #$week1的$hour点$min分$cronname" >> $cronpath
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m定时任务已添加！！！\033[0m"
		fi
		clashcron
	}
	checkcron(){
	[ -d /etc/crontabs/ ]&&cronpath="/etc/crontabs/root"
	[ -d /var/spool/cron/ ]&&cronpath="/var/spool/cron/root"
	[ -d /var/spool/cron/crontabs/ ]&&cronpath="/var/spool/cron/crontabs/root"
	if [ -z $cronpath ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo "找不到定时任务文件,无法添加定时任务！"
		clashsh
	fi

	}
#定时任务菜单
checkcron #检测定时任务文件
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m欢迎使用定时任务功能：\033[0m"
echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -----------------------------------------------
echo  -e "\033[33m已添加的定时任务：\033[36m"
cat $cronpath | egrep -o ' #.*' 
echo -e "\033[0m"-----------------------------------------------
echo -e " 1 设置\033[33m定时重启\033[0mclash服务"
echo -e " 2 设置\033[31m定时停止\033[0mclash服务"
echo -e " 3 设置\033[32m定时开启\033[0mclash服务"
echo -e " 4 设置\033[33m定时更新\033[0m订阅链接(实验性，可能不稳定)"
echo -----------------------------------------------
echo -e " 0 返回上级菜单" 
read -p "请输入对应数字 > " num
if [ -z "$num" ]; then 
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashsh
	
elif [[ $num == 0 ]]; then
	clashsh
	
elif [[ $num == 1 ]]; then
	cronname=重启clash服务
	cronset="$clashdir/start.sh restart"
	setcron
elif [[ $num == 2 ]]; then
	cronname=停止clash服务
	cronset="$clashdir/start.sh stop"
	setcron
elif [[ $num == 3 ]]; then
	cronname=开启clash服务
	cronset="$clashdir/start.sh start"
	setcron
elif [[ $num == 4 ]]; then	
	cronname=更新订阅链接
	cronset="$clashdir/start.sh getyaml"
	setcron	
	
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashsh
fi
}
clashsh(){
#############################
getconfig
#############################
echo -e " 1 \033[32m启动/重启\033[0mclash服务"
echo -e " 2 clash\033[33m功能设置\033[0m"
echo -e " 3 \033[31m停止\033[0mclash服务"
echo -e " 4 $auto1"
echo -e " 5 设置\033[33m定时任务\033[0m"
echo -e " 6 导入\033[32m节点/订阅\033[0m链接"
echo -e " 7 clash\033[31m进阶设置\033[0m"
echo -e " 8 \033[35m测试菜单\033[0m"
echo -e " 9 \033[36m更新/卸载\033[0m"
echo -----------------------------------------------
echo -e " 0 \033[0m退出脚本\033[0m"
read -p "请输入对应数字 > " num
if [[ $num -le 9 ]] > /dev/null 2>&1; then 
	if [[ $num == 0 ]]; then
		exit;
  
	elif [[ $num == 1 ]]; then

		clashstart
		exit;
  
	elif [[ $num == 2 ]]; then
		clashcfg

	elif [[ $num == 3 ]]; then
		$clashdir/start.sh stop
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31mClash服务已停止！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		exit;

	elif [[ $num == 4 ]]; then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$start_old" = "已开启" ];then
			sed -i "/start_old*/d" $ccfg
			sed -i "1i\start_old=未开启" $ccfg
			echo -e "\033[32m已设为使用默认方式启动clash服务！！\033[0m"
			start_old=未开启
		elif [ "$autostart" = "enable_rc" ]; then
			/etc/init.d/clash disable
			echo -e "\033[33m已禁止Clash开机启动！\033[0m"
		elif [ "$autostart" = "disable_rc" ]; then
			/etc/init.d/clash enable
			echo -e "\033[32m已设置Clash开机启动！\033[0m"
		elif [ "$autostart" = "enable_sys" ]; then
			systemctl disable clash.service > /dev/null 2>&1
			echo -e "\033[33m已禁止Clash开机启动！\033[0m"
		elif [ "$autostart" = "disable_sys" ]; then
			systemctl enable clash.service > /dev/null 2>&1
			echo -e "\033[32m已设置Clash开机启动！\033[0m"
		else
			echo -e "\033[32m当前系统不支持设置开启启动！\033[0m"
		fi
		clashsh

	elif [[ $num == 5 ]]; then
		clashcron
    
	elif [[ $num == 6 ]]; then
		clashlink
		
	elif [[ $num == 7 ]]; then
		clashadv

	elif [[ $num == 8 ]]; then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[30;47m这里是测试命令菜单\033[0m"
		echo -e "\033[33m如遇问题尽量运行相应命令后截图发群\033[0m"
		echo -e "磁盘占用/所在目录："
		du -h $clashdir
		echo -----------------------------------------------
		echo " 1 查看clash运行时的报错信息"
		echo " 2 查看系统DNS端口(:53)占用 "
		echo " 3 测试ssl加密（aes-128-gcm）跑分"
		echo " 4 查看iptables端口转发详情"
		echo " 5 查看config.yaml前40行"
		echo " 6 测试代理服务器连通性（google.tw)"
		echo -----------------------------------------------
		echo " 0 返回上级目录！"
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashsh
		elif [[ $num == 0 ]]; then
			clashsh
		elif [[ $num == 1 ]]; then
			$clashdir/start.sh stop
			echo -----------------------------------------------
			$clashdir/clash -d $clashdir & { sleep 3 ; kill $! & }
			echo -----------------------------------------------
			echo -e "\033[31m如有报错请截图后到TG群询问！！！\033[0m"
			exit;
		elif [[ $num == 2 ]]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			netstat -ntulp |grep 53
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "可以使用\033[44m netstat -ntulp |grep xxx \033[0m来查询任意(xxx)端口"
			exit;
		elif [[ $num == 3 ]]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			openssl speed -multi 4 -evp aes-128-gcm
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			exit;
		elif [[ $num == 4 ]]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			iptables  -t nat  -L PREROUTING --line-numbers
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			iptables  -t nat  -L clash --line-numbers
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			iptables  -t nat  -L clash_dns --line-numbers
			exit;
		elif [[ $num == 5 ]]; then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			sed -n '1,40p' $yaml
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			exit;
		elif [[ $num == 6 ]]; then
			echo 注意：测试结果不保证一定准确！
			delay=`curl -kx 127.0.0.1:7890 -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' & { sleep 3 ; kill $! & }` > /dev/null 2>&1
			delay=`echo |awk "{print $delay*1000}"` > /dev/null 2>&1
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			if [ `echo ${#delay}` -gt 1 ];then
				echo -e "\033[32m连接成功！响应时间为："$delay" ms\033[0m"
			else
				echo -e "\033[31m连接超时！请重试或检查节点配置！\033[0m"
			fi
			clashsh
		else
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[31m请输入正确的数字！\033[0m"
			clashsh
		fi

	elif [[ $num == 9 ]]; then
		update
	
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
	fi
	exit 1
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
fi
exit 1
}
clashsh