#!/usr/bin/env bash
# 检测区
# -------------------------------------------------------------

# 初始化全局变量
initVar(){
    install_type='apt -y install'
    remove_type='apt -y autoremove'
    upgrade="apt update"
    echo_type='echo -e'
    
    # 核心支持的cpu版本
    xray_core_cpu_vendor=""
    v2ray_core_cpu_vendor=""
    warp_reg_core_cpu_vendor=""
    cpu_vendor=""

    # 域名
    domain=

    # CDN节点的address
    add=

    # 安装总进度
    total_progress=1


    # 1.xray-core安装
    # 2.v2ray-core 安装
    # 3.v2ray-core[xtls] 安装
    core_install_type=

    # 1.全部安装
    # 2.个性化安装
    v2ray_agent_install_type=

    # 当前的个性化安装方式 01234
    current_custom_install_type=

    # 选择的个性化安装方式
    select_custom_install_type=

    # v2ray-core配置文件的路径
    v2ray_core_config_file_path=

    # xray-core配置文件的路径
    xray_core_config_file_path=

    # 配置文件的path
    current_path=

    # 配置文件的host
    current_host=

    # 安装时选择的core类型
    select_core_type=

    # 默认core版本
    v2ray_core_version=

    # 随机路径
    custom_path=

    # centos version
    centos_version=

    # UUID
    current_uuid=
    current_uuid_direct=
    
    # ssl邮箱
    ssl_email=tests$RANDOM@gmail.com
    
    # nginx配置文件路径
    nginx_config_path=/etc/nginx/conf.d/
    nginx_static_path=/usr/share/nginx/html/
    
    # 集成更新证书逻辑不再使用单独的脚本--RenewTLS
	renew_tls=$1
}


# 检查系统
checkSystem() {
    if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
        mkdir -p /etc/yum.repos.d

        if [[ -f "/etc/centos-release" ]]; then
            centos_version=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')

            if [[ -z "${centos_version}" ]] && grep </etc/centos-release -q -i "release 8"; then
                centos_version=8
            fi
        fi

        release="centos"
        install_type='yum -y install'
        remove_type='yum -y remove'
        upgrade="yum update -y --skip-broken"
        
    elif [[ -f "/etc/issue" ]] && grep </etc/issue -q -i "debian" || [[ -f "/proc/version" ]] && grep </etc/issue -q -i "debian" || [[ -f "/etc/os-release" ]] && grep </etc/os-release -q -i "ID=debian"; then
        release="debian"
        install_type='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        remove_type='apt -y autoremove'

    elif [[ -f "/etc/issue" ]] && grep </etc/issue -q -i "ubuntu" || [[ -f "/proc/version" ]] && grep </etc/issue -q -i "ubuntu"; then
        release="ubuntu"
        install_type='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        remove_type='apt -y autoremove'
        if grep </etc/issue -q -i "16."; then
            release=
        fi
    fi

    if [[ -z ${release} ]]; then
        echoContent red "\n本脚本不支持此系统，请将下方日志向上反馈！\n"
        echoContent yellow "$(cat /etc/issue)"
        echoContent yellow "$(cat /proc/version)"
        exit 0
    fi
}

# 检查CPU提供商
checkCPUVendor() {
    if [[ -n $(which uname) ]]; then
        if [[ "$(uname)" == "Linux" ]]; then
            case "$(uname -m)" in
                'amd64' | 'x86_64')
                    xray_core_cpu_vendor="Xray-linux-64"
                    v2ray_core_cpu_vendor="v2ray-linux-64"
                    trojan_core_cpu_vendor="trojan-go-linux-amd64"
                    warp_reg_core_cpu_vendor="main-linux-amd64"
                    ;;
                'armv8' | 'aarch64')
                    cpu_vendor="arm"
                    xray_core_cpu_vendor="Xray-linux-arm64-v8a"
                    v2ray_core_cpu_vendor="v2ray-linux-arm64-v8a"
                    trojan_core_cpu_vendor="trojan-go-linux-armv8"
                    warp_reg_core_cpu_vendor="main-linux-arm64"
                    ;;
                *)
                    echo "  不支持此CPU架构--->"
                    exit 1
                    ;;
            esac
        fi
    else
        echoContent red "  无法识别此CPU架构，默认amd64、x86_64--->"
        xray_core_cpu_vendor="Xray-linux-64"
        v2ray_core_cpu_vendor="v2ray-linux-64"
    fi
}

# 检测安装方式
readInstallType(){
    core_install_type=
    v2ray_agent_install_type=
    xray_core_config_file_path=
    v2ray_core_config_file_path=

    # 1.检测安装目录
    if [[ -d "/etc/v2ray-agent"  ]]; then
        # 检测安装方式 v2ray-core
        if [[ -d "/etc/v2ray-agent/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ctl" ]]; then
            if [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]]; then
                v2ray_agent_install_type=1
                v2ray_core_config_file_path=/etc/v2ray-agent/v2ray/config_full.json
                # if [[ ! -z `cat /etc/v2ray-agent/v2ray/config_full.json|grep xtls` ]]; then
                if grep </etc/v2ray-agent/v2ray/config_full.json -q "xtls"; then
                    core_install_type=3
                elif ! grep </etc/v2ray-agent/v2ray/config_full.json -q "xtls"; then
                    core_install_type=2
                fi

            elif [[ -d "/etc/v2ray-agent/v2ray/conf" && -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]; then
                v2ray_agent_install_type=2
                v2ray_core_config_file_path=/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
                if grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q "xtls"; then
                    core_install_type=3
                elif ! grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q "xtls"; then
                    core_install_type=2
                fi
            fi
         fi

        if [[ -d "/etc/v2ray-agent/xray" && -f "/etc/v2ray-agent/xray/xray" ]]; then
            # 这里检测xray-core
            if [[ -f "/etc/v2ray-agent/xray/config_full.json" ]]; then
                xray_core_config_file_path=/etc/v2ray-agent/xray/config_full.json
                v2ray_agent_install_type=1
                if [[ -n `cat /etc/v2ray-agent/xray/config_full.json` ]]; then
                    core_install_type=1
                fi

            elif [[ -d "/etc/v2ray-agent/xray/conf" && -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" ]]; then
                xray_core_config_file_path=/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json
                v2ray_agent_install_type=2

                if [[ -n `cat /etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json` ]]; then
                    core_install_type=1
                fi
            fi
        fi
    fi
}

# 检测个性化安装的方式
readCustomInstallType(){
    custom_conf=
    current_custom_install_type=
    if [[ "${v2ray_agent_install_type}" = "2" ]]; then
        local custom_conf=
        if [[ "${core_install_type}" = "1" ]]; then
            custom_conf="/etc/v2ray-agent/xray/conf"
        else
            custom_conf="/etc/v2ray-agent/v2ray/conf"
        fi

        while read -r row
        do
            if [[ -n `echo ${row}|grep VLESS_TCP_inbounds` ]]; then
                current_custom_install_type=${current_custom_install_type}'0'
            fi
            if [[ -n `echo ${row}|grep VLESS_WS_inbounds` ]]; then
                current_custom_install_type=${current_custom_install_type}'1'
            fi
            if [[ -n `echo ${row}|grep VMess_TCP_inbounds` ]]; then
                current_custom_install_type=${current_custom_install_type}'2'
            fi
            if  [[ -n `echo ${row}|grep VMess_WS_inbounds` ]]; then
                current_custom_install_type=${current_custom_install_type}'3'
            fi
        done < <(echo `ls ${custom_conf}|grep -v grep|grep inbounds.json|awk -F "[.]" '{print $1}'`)
    fi
}

# 检查文件目录以及path路径
readConfigHostPathUUID(){
    current_path=
    current_uuid=
    current_uuid_direct=
    current_host=
    # current_path
    if [[ -n "${v2ray_core_config_file_path}" ]]; then
        local path=`cat ${v2ray_core_config_file_path}|jq .inbounds[0].settings.fallbacks|jq -c '.[].path'|awk -F "[\"][/]" '{print $2}'|awk -F "[\"]" '{print $1}'|tail -n +2|head -n 1`
        if [[ -n "${path}" ]]; then
            current_path=${path:0:4}
        fi
    elif [[ -n "${xray_core_config_file_path}" ]]; then
        local path=`cat ${xray_core_config_file_path}|jq .inbounds[0].settings.fallbacks|jq -c '.[].path'|awk -F "[\"][/]" '{print $2}'|awk -F "[\"]" '{print $1}'|tail -n +2|head -n 1`
        if [[ -n "${path}" ]]; then
            current_path=${path:0:4}
        fi
    fi

    # current_host current_uuid current_uuid_direct
    if [[ "${core_install_type}" = "1" ]]; then
        current_host=`cat ${xray_core_config_file_path}|jq .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
        current_uuid=`cat ${xray_core_config_file_path}|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
        current_uuid_direct=`cat ${xray_core_config_file_path}|jq .inbounds[0].settings.clients[1].id|awk -F '["]' '{print $2}'`
    elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
        current_host=`cat ${v2ray_core_config_file_path}|jq .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
        current_uuid=`cat ${v2ray_core_config_file_path}|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
        current_uuid_direct=`cat ${v2ray_core_config_file_path}|jq .inbounds[0].settings.clients[1].id|awk -F '["]' '{print $2}'`
    fi
}

initVar
checkSystem
checkCPUVendor
readInstallType
readCustomInstallType
readConfigHostPathUUID

# -------------------------------------------------------------

# 清理旧残留
cleanUp(){
    if [[ "$1" = "v2ray_clean" ]]; then
        rm -rf `ls /etc/v2ray-agent/v2ray|egrep -v '(config_full.json|conf)'`
        handleV2Ray stop > /dev/null 2>&1
        rm -f /etc/systemd/system/v2ray.service
    elif [[ "$1" = "xray_clean" ]]; then
        rm -rf `ls /etc/v2ray-agent/xray|egrep -v '(config_full.json|conf)'`
        handleXray stop > /dev/null 2>&1
        rm -f /etc/systemd/system/xray.service

    elif [[ "$1" = "v2ray_del" ]]; then
        rm -rf /etc/v2ray-agent/v2ray/*

    elif [[ "$1" = "xray_del" ]]; then
        rm -rf /etc/v2ray-agent/xray/*
    fi
}

echoContent(){
    case $1 in
        # 红色
        "red")
            ${echo_type} "\033[31m${printN}$2 \033[0m"
        ;;
        # 天蓝色
        "skyBlue")
            ${echo_type} "\033[1;36m${printN}$2 \033[0m"
        ;;
        # 绿色
        "green")
            ${echo_type} "\033[32m${printN}$2 \033[0m"
        ;;
        # 白色
        "white")
            ${echo_type} "\033[37m${printN}$2 \033[0m"
        ;;
        "magenta")
            ${echo_type} "\033[31m${printN}$2 \033[0m"
        ;;
        "skyBlue")
            ${echo_type} "\033[36m${printN}$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            ${echo_type} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}

# 初始化安装目录
mkdirTools(){
    mkdir -p /etc/v2ray-agent/tls
    mkdir -p /etc/v2ray-agent/v2ray/conf
    mkdir -p /etc/v2ray-agent/xray/conf
    mkdir -p /etc/v2ray-agent/trojan
    mkdir -p /etc/systemd/system/
    mkdir -p /tmp/v2ray-agent-tls/
}

# 安装工具包
installTools(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 安装工具"
    
    if [[ -n $(pgrep -f "apt") ]]; then
        pkill apt || pgrep -f apt | xargs kill -9
    fi
    
    echoContent green " ---> 检查、安装更新【新机器会很慢，耐心等待】"
    
    if [[ "${release}" = "centos" ]]; then
        echoContent green " ---> 检查安装jq、nginx epel源、yum-utils"
        # jq epel源
        if [[ -z `command -v jq` ]]; then
            rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null 2>&1
        fi

        nginxEpel=""
        if [[ -n `rpm -qa|grep -v grep|grep nginx` ]]; then
            local nginxVersion=`rpm -qa|grep -v grep|grep nginx|head -1|awk -F '[-]' '{print $2}'`;
            if [[ `echo ${nginxVersion}|awk -F '[.]' '{print $1}'` < 1 ]] && [[ `echo ${nginxVersion}|awk -F '[.]' '{print $2}'` < 17 ]]; then
                rpm -qa|grep -v grep|grep nginx|xargs rpm -e > /dev/null 2>&1
            fi
        fi
        
        if [[ "${centos_version}" = "6" ]]; then
            nginxEpel="http://nginx.org/packages/centos/6/x86_64/RPMS/nginx-1.18.0-1.el6.ngx.x86_64.rpm"
        elif [[ "${centos_version}" = "7" ]]; then
            nginxEpel="http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm"
        elif [[ "${centos_version}" = "8" ]]; then
            nginxEpel="http://nginx.org/packages/centos/8/x86_64/RPMS/nginx-1.18.0-1.el8.ngx.x86_64.rpm"
        fi
        # nginx epel源
        rpm -ivh ${nginxEpel} > /etc/v2ray-agent/error.log 2>&1

        # yum-utils
        if [[ "${centos_version}" = "8" ]]; then
            upgrade="yum update -y --skip-broken --nobest"
            install_type="yum -y install --nobest"
            ${install_type} yum-utils > /etc/v2ray-agent/error.log 2>&1
        else
            ${install_type} yum-utils > /etc/v2ray-agent/error.log 2>&1
        fi

    fi
    
    # 修复ubuntu个别系统问题
    if [[ "${release}" = "ubuntu" ]]; then
        dpkg --configure -a
    fi

    ${upgrade} >/etc/v2ray-agent/install.log 2>&1
    if [[ "${release}" = "centos" ]]; then
        rm -rf /var/run/yum.pid
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w wget; then
        echoContent green " ---> 安装wget"
        ${install_type} wget >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w curl; then
        echoContent green " ---> 安装curl"
        ${install_type} curl >/dev/null 2>&1
    fi
    
    if ! find /usr/bin /usr/sbin /bin | grep -q -w netstat; then
        echoContent green " ---> 安装netstat"
        ${install_type} net-tools >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w unzip; then
        echoContent green " ---> 安装unzip"
        ${install_type} unzip >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w socat; then
        echoContent green " ---> 安装socat"
        ${install_type} socat >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w tar; then
        echoContent green " ---> 安装tar"
        ${install_type} tar >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w cron; then
        echoContent green " ---> 安装crontabs"
        if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]; then
            ${install_type} cron >/dev/null 2>&1
        else
            ${install_type} crontabs >/dev/null 2>&1
        fi
    fi
    if ! find /usr/bin /usr/sbin |grep -q -w jq; then
        echoContent green " ---> 安装jq"
        ${install_type} jq >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w binutils; then
        echoContent green " ---> 安装binutils"
        ${install_type} binutils >/dev/null 2>&1
    fi
    if ! find /usr/bin /usr/sbin |grep -q -w nginx; then
        echoContent green " ---> 安装nginx"
        # ${install_type} nginx >/dev/null 2>&1
        installNginxTools
    else
        nginxVersion=$(nginx -v 2>&1)
        nginxVersion=$(echo "${nginxVersion}" | awk -F "[n][g][i][n][x][/]" '{print $2}' | awk -F "[.]" '{print $2}')
        if [[ ${nginxVersion} -lt 14 ]]; then
            read -r -p "读取到当前的Nginx版本不支持gRPC，会导致安装失败，是否卸载Nginx后重新安装 ？[y/n]:" unInstallNginxStatus
            if [[ "${unInstallNginxStatus}" == "y" ]]; then
                ${remove_type} nginx >/dev/null 2>&1
                echoContent yellow " ---> nginx卸载完成"
                echoContent green " ---> 安装nginx"
                installNginxTools >/dev/null 2>&1
            else
                exit 0
            fi
        fi
    fi

    if ! find /usr/bin /usr/sbin |grep -q -w sudo; then
        echoContent green " ---> 安装sudo"
        ${install_type} sudo >/dev/null 2>&1
    fi
    
    if ! find /usr/bin /usr/sbin | grep -q -w lsb-release; then
        echoContent green " ---> 安装lsb-release"
        ${install_type} lsb-release >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w lsof; then
        echoContent green " ---> 安装lsof"
        ${install_type} lsof >/dev/null 2>&1
    fi
    
    # todo 关闭防火墙
    
    if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
        echoContent green " ---> 安装acme.sh"
        curl -s https://get.acme.sh | sh >/etc/v2ray-agent/tls/acme.log 2>&1

        if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
            echoContent red "  acme安装失败--->"
            tail -n 100 /etc/v2ray-agent/tls/acme.log
            echoContent yellow "错误排查:"
            echoContent red "  1.获取Github文件失败，请等待Github恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.如纯IPv6机器，请设置NAT64,可执行下方命令，如果添加下方命令还是不可用，请尝试更换其他NAT64"
            #                echoContent skyBlue "  echo -e \"nameserver 2001:67c:2b0::4\\\nnameserver 2a00:1098:2c::1\" >> /etc/resolv.conf"
            echoContent skyBlue "  sed -i \"1i\\\nameserver 2001:67c:2b0::4\\\nnameserver 2a00:1098:2c::1\" /etc/resolv.conf"
            exit 0
        fi
    fi

}

# 安装Nginx
installNginxTools() {

    if [[ "${release}" == "debian" ]]; then
        sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
        echo "deb http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2>&1
        curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
        sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "ubuntu" ]]; then
        sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
        echo "deb http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2>&1
        curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
        sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "centos" ]]; then
        ${install_type} yum-utils >/dev/null 2>&1
        cat <<EOF >/etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
        sudo yum-config-manager --enable nginx-mainline >/dev/null 2>&1
    fi
    ${install_type} nginx >/dev/null 2>&1
    systemctl daemon-reload
    systemctl enable nginx
}


# 初始化Nginx申请证书配置
initTLSNginxConfig(){
    handleNginx stop
    echoContent skyBlue "\n进度  $1/${total_progress} : 初始化Nginx申请证书配置"
    echoContent yellow  "请输入要配置的域名 例：blog.v2ray-agent.com --->"
    
    port=80
    read -p "域名:" domain
    if [[ -z ${domain} ]]; then
        echoContent red "  域名不可为空--->"
        initTLSNginxConfig
    else
        # 修改配置
        echoContent green " ---> 配置Nginx"
        handleNginx stop
        
        # 防止二次搭建时出错
        if [[ -f "${nginx_config_path}alone.conf" ]]; then
            rm -f "${nginx_config_path}alone.conf"
        fi
        
        touch ${nginx_config_path}alone.conf
        # echo "server {listen 80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" > /etc/nginx/conf.d/alone.conf
        
        cat <<EOF >${nginx_config_path}alone.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    root ${nginx_static_path};
    location ~ /.well-known {
        allow all;
    }
    
    location /test {
        return 200 'fjkvymb6len';
    }
    
    location /ip {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header REMOTE-HOST \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        default_type text/plain;
        return 200 \$proxy_add_x_forwarded_for;
    }
}
EOF
        
        # 检查日志，解决nginx启动失败
        if [[ ! -f /var/log/nginx/access.log ]]; then
            if [[ ! -d /var/log/nginx ]]; then
                mkdir /var/log/nginx
            fi
            
            touch /var/log/nginx/access.log
            touch /var/log/nginx/error.log
        fi
        
        # 检测端口情况并尝试关闭
        checkPort ${port}
        sleep 0.5
        checkPort ${port} check
        
        # 启动nginx
        handleNginx start
        
        # echoContent yellow "\n检查IP是否设置为当前VPS"
        #checkIP
        
        # # 测试nginx
        # echoContent yellow "\n检查Nginx是否正常访问"
        # # domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        # domainResult=1
        # if [[ -n ${domainResult} ]]; then
            # handleNginx stop
            # echoContent green " ---> Nginx配置成功"
        # else
            # echoContent red " ---> 无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
            # exit 0;
        # fi
        
        # 检查域名+端口的开放
        
        check_port_result=$(curl -s -m 2 "http://${domain}:${port}/test")
        local_ip=$(curl -s -m 2 "http://${domain}:${port}/ip")
        # rm "${nginx_config_path}alone.conf"
        handleNginx stop
        
        if [[ "${check_port_result}" == "fjkvymb6len" ]]; then
            echoContent green " ---> 检测到${port}端口已开放"
        else
            echoContent green " ---> 未检测到${port}端口开放，退出安装"
            if echo "${check_port_result}" | grep -q "cloudflare"; then
                echoContent yellow " ---> 请关闭云朵后等待三分钟重新尝试"
            else
                if [[ -z "${check_port_result}" ]]; then
                    echoContent red " ---> 请检查是否有网页防火墙，比如Oracle等云服务商"
                    echoContent red " ---> 检查是否自己安装过nginx并且有配置冲突，可以尝试安装纯净系统后重新尝试"
                else
                    echoContent red " ---> 错误日志：${check_port_result}，请将此错误日志向上反馈！"
                fi
            fi
            exit 0
        fi
        checkIP "${local_ip}"
        
        handleNginx stop
        
    fi
}

# 检查防火墙
allowPort() {
    local type=$2
    if [[ -z "${type}" ]]; then
        type=tcp
    fi
    # 如果防火墙启动状态则添加相应的开放端口
    if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
        local updateFirewalldStatus=
        if ! iptables -L | grep -q "$1/${type}(custom)"; then
            updateFirewalldStatus=true
            iptables -I INPUT -p ${type} --dport "$1" -m comment --comment "allow $1/${type}(custom)" -j ACCEPT
        fi

        if echo "${updateFirewalldStatus}" | grep -q "true"; then
            netfilter-persistent save
        fi
    elif systemctl status ufw 2>/dev/null | grep -q "active (exited)"; then
        if ufw status | grep -q "Status: active"; then
            if ! ufw status | grep -q "$1/${type}"; then
                sudo ufw allow "$1/${type}"
                checkUFWAllowPort "$1"
            fi
        fi

    elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
        local updateFirewalldStatus=
        if ! firewall-cmd --list-ports --permanent | grep -qw "$1/${type}"; then
            updateFirewalldStatus=true
            local firewallPort=$1

            if echo "${firewallPort}" | grep ":"; then
                firewallPort=$(echo "${firewallPort}" | awk -F ":" '{print $1-$2}')
            fi

            firewall-cmd --zone=public --add-port="${firewallPort}/${type}" --permanent
            checkFirewalldAllowPort "${firewallPort}"
        fi

        if echo "${updateFirewalldStatus}" | grep -q "true"; then
            firewall-cmd --reload
        fi
    fi
}

# 检查ip
checkIP(){
    echoContent skyBlue "\n ---> 检查域名ip中"
    local local_ip=$1

    if [[ -z ${local_ip} ]] || ! echo "${local_ip}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q '\.' && ! echo "${local_ip}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q ':'; then
        echoContent red "\n ---> 未检测到当前域名的ip"
        echoContent skyBlue " ---> 请依次进行下列检查"
        echoContent yellow " --->  1.检查域名是否书写正确"
        echoContent yellow " --->  2.检查域名dns解析是否正确"
        echoContent yellow " --->  3.如解析正确，请等待dns生效，预计三分钟内生效"
        echoContent yellow " --->  4.如报Nginx启动问题，请手动启动nginx查看错误，如自己无法处理请提issues"
        echo
        echoContent skyBlue " ---> 如以上设置都正确，请重新安装纯净系统后再次尝试"

        if [[ -n ${local_ip} ]]; then
            echoContent yellow " ---> 检测返回值异常，建议手动卸载nginx后重新执行脚本"
            echoContent red " ---> 异常结果：${local_ip}"
        fi
        exit 0
    else
        if echo "${local_ip}" | awk -F "[,]" '{print $2}' | grep -q "." || echo "${local_ip}" | awk -F "[,]" '{print $2}' | grep -q ":"; then
            echoContent red "\n ---> 检测到多个ip，请确认是否关闭cloudflare的云朵"
            echoContent yellow " ---> 关闭云朵后等待三分钟后重试"
            echoContent yellow " ---> 检测到的ip如下:[${local_ip}]"
            exit 0
        fi
        #        echoContent green " ---> 当前域名ip为:[${local_ip}]"
        echoContent green " ---> 检查当前域名IP正确"
    fi
}

# 检测端口是否占用
checkPort() {
    if [[ -n "$1" ]] && lsof -i "tcp:$1" | grep -q LISTEN; then
        echoContent yellow "---> 80端口占用，正在关闭"
        netstat -tlupn | grep -i :{$1} | awk -F " " '{print $7}' | awk -F / '{print $1}' | xargs kill -9 
        sudo pkill nginx
    fi
    
    if [[ -n "$1" && "$2" == "check" ]] ; then
        if lsof -i "tcp:$1" | grep -q LISTEN; then
            echoContent red "\n ---> $1端口被占用，请手动关闭后安装\n"
            lsof -i "tcp:$1" | grep LISTEN
            exit 0
        fi
    fi
}

# 自定义email
customSSLEmail() {
    if echo "$1" | grep -q "validate email"; then
        read -r -p "是否重新输入邮箱地址[y/n]:" ssl_email_status
        if [[ "${ssl_email_status}" == "y" ]]; then
            sed '/ACCOUNT_EMAIL/d' /root/.acme.sh/account.conf >/root/.acme.sh/account.conf_tmp && mv /root/.acme.sh/account.conf_tmp /root/.acme.sh/account.conf
        else
            exit 0
        fi
    fi

    if [[ -d "/root/.acme.sh" && -f "/root/.acme.sh/account.conf" ]]; then
        if ! grep -q "ACCOUNT_EMAIL" <"/root/.acme.sh/account.conf" && ! echo "${sslType}" | grep -q "letsencrypt"; then
        
            if [[ "$1" == "random" ]]; then
                echo "ACCOUNT_EMAIL='${ssl_email}'" >>/root/.acme.sh/account.conf
                echoContent green " ---> 添加成功"
            else
        
                read -r -p "请输入邮箱地址:" ssl_email
                if echo "${ssl_email}" | grep -q "@"; then
                    echo "ACCOUNT_EMAIL='${ssl_email}'" >>/root/.acme.sh/account.conf
                    echoContent green " ---> 添加成功"
                else
                    echoContent yellow "请重新输入正确的邮箱格式[例: username@example.com]"
                    customSSLEmail
                fi
            fi
        fi
    fi

}

# 安装TLS
installTLS(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 申请TLS证书"
    
    # 增加关闭 nginx， 解决证书申请失败
    handleNginx stop
    
    if [[ -f "/etc/v2ray-agent/tls/${domain}.crt" && -f "/etc/v2ray-agent/tls/${domain}.key" && -n $(cat "/etc/v2ray-agent/tls/${domain}.crt") ]] || [[ -d "$HOME/.acme.sh/${domain}_ecc" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]]; then
        echoContent green " ---> 检测到证书"
        # checkTLStatus
        renewalTLS

        if [[ -z $(find /etc/v2ray-agent/tls/ -name "${domain}.crt") ]] || [[ -z $(find /etc/v2ray-agent/tls/ -name "${domain}.key") ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${domain}.crt") ]]; then
            
            echoContent green " ---> 安装TLS证书"
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${domain}" --fullchainpath "/etc/v2ray-agent/tls/${domain}.crt" --keypath "/etc/v2ray-agent/tls/${domain}.key" --ecc >/dev/null
            
        else
            echoContent yellow " ---> 如未过期或者自定义证书请选择[n]\n"
            read -r -p "是否重新安装？[y/n]:" reInstallStatus
            if [[ "${reInstallStatus}" == "y" ]]; then
                rm -rf /etc/v2ray-agent/tls/*
                installTLS "$1"
            fi
        fi

    elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" || ! -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" ]]; then
        echoContent green " ---> 安装TLS证书，需要依赖80端口"
        allowPort 80
        if [[ "${installDNSACMEStatus}" != "true" ]]; then
            # switchSSLType     # 默认使用 letsencrypt
            # selectAcmeInstallSSL 
            
            if echo "${local_ip}" | grep -q ":"; then
                install_ssl_ipv6="--listen-v6"
            fi
            
            read -r -p "是否使用自定义邮箱？[y/n]:" custom_email_status
            if [[ "${custom_email_status}" == "y" ]]; then
                customSSLEmail
            else
                customSSLEmail "random"
            fi
           
            sudo "$HOME/.acme.sh/acme.sh" --issue -d "${domain}" --standalone -k ec-256 --server "letsencrypt" ${install_ssl_ipv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
            
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${domain}" --fullchainpath "/etc/v2ray-agent/tls/${domain}.crt" --keypath "/etc/v2ray-agent/tls/${domain}.key" --ecc >/dev/null
            
        fi
        
        # 再次检测
        if [[ -d "$HOME/.acme.sh/${domain}_ecc" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]]; then
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
        fi

        if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key" ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
            tail -n 10 /etc/v2ray-agent/tls/acme.log
            if [[ ${install_tls_count} == "1" ]]; then
                echoContent red " ---> TLS安装失败，请检查acme日志"
                exit 0
            fi

            install_tls_count=1
            echo

            if tail -n 10 /etc/v2ray-agent/tls/acme.log | grep -q "Could not validate email address as valid"; then
                echoContent red " ---> 邮箱无法通过SSL厂商验证，请重新输入"
                echo
                customSSLEmail "validate email"
                installTLS "$1"
            else
                installTLS "$1"
            fi
        fi

        echoContent green " ---> TLS生成成功"
    else
        echoContent yellow " ---> 未安装acme.sh"
        exit 0
    fi
    
}
# 配置伪装博客
initNginxConfig(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 配置Nginx"

        cat << EOF > ${nginx_config_path}alone.conf
server {
    listen 80;
    server_name ${domain};
    root ${nginx_static_path};
    location ~ /.well-known {allow all;}
    location /test {return 200 'fjkvymb6len';}
}
EOF
}

# 自定义/随机路径
randomPathFunction(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 生成随机路径"

    if [[ -n "${current_path}" ]]; then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的path路径 ？[y/n]:" history_path_status
        echo
    fi

    if [[ "${history_path_status}" == "y" ]]; then
        custom_path=${current_path}
        echoContent green " ---> 使用成功\n"
    else
        echoContent yellow "请输入自定义路径[例: alone]，不需要斜杠，[回车]随机路径"
        read -p '路径:' custom_path

        if [[ -z "${custom_path}" ]]; then
            custom_path=`head -n 50 /dev/urandom|sed 's/[^a-z]//g'|strings -n 4|tr 'A-Z' 'a-z'|head -1`
        fi
    fi
    echoContent yellow "path：${custom_path}"
    echoContent skyBlue "\n----------------------------"
}

# Nginx伪装博客
nginxBlog(){
#    echoContent yellow "添加伪装博客--->"
    echoContent skyBlue "\n进度 $1/${total_progress} : 添加伪装博客"
    if [[ -d "${nginx_static_path}" && -f "${nginx_static_path}check" ]]; then
        read -p "检测到安装伪装博客，是否需要重新安装[y/n]：" nginx_blog_install_status
        if [[ "${nginx_blog_install_status}" = "y" ]]; then
            rm -rf /usr/share/nginx/html
            randomNum=$((RANDOM % 6 + 1))
            wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip > /dev/null
            unzip -o  "/usr/share/nginx/html${randomNum}.zip" -d "${nginx_static_path}" > /dev/null
            rm -f "/usr/share/nginx/html${randomNum}.zip*"
            echoContent green " ---> 添加伪装博客成功"
        fi
    else
        randomNum=$((RANDOM % 6 + 1))
        rm -rf /usr/share/nginx/html
        wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip > /dev/null
        unzip -o  "/usr/share/nginx/html${randomNum}.zip" -d "${nginx_static_path}" > /dev/null
        rm -f "/usr/share/nginx/html${randomNum}.zip*"
        echoContent green " ---> 添加伪装博客成功"
    fi
    
}

# 操作Nginx
handleNginx(){
    if [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
        systemctl start nginx 2>/etc/v2ray-agent/nginx_error.log

        sleep 0.5

        if [[ -z $(pgrep -f "nginx") ]]; then
            echoContent red " ---> Nginx启动失败"
            echoContent red " ---> 请手动尝试安装nginx后，再次执行脚本"

            # if grep -q "journalctl -xe" </etc/v2ray-agent/nginx_error.log; then
                # updateSELinuxHTTPPortT
            # fi

            exit 0
        else
            echoContent green " ---> Nginx启动成功"
        fi

    elif [[ -n $(pgrep -f "nginx") ]] && [[ "$1" == "stop" ]]; then
        systemctl stop nginx
        sleep 0.5
        if [[ -n $(pgrep -f "nginx") ]]; then
            pgrep -f "nginx" | xargs kill -9
        fi
        
        if [[ -n $(pgrep -f "nginx") ]]; then
            nginx -s stop
        fi
        
        echoContent green " ---> Nginx关闭成功"
    fi
}

# 定时任务检查证书
cronRenewTLS() {
    if [[ "${renew_tls}" == "RenewTLS" ]]; then
        echo 执行定时任务...
        renewalTLS
        exit 0
    fi
}

# 定时任务更新tls证书
installCronTLS(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 添加定时维护证书"
    crontab -l >> /etc/v2ray-agent/backup_crontab.cron
    local historyCrontab
    historyCrontab=$(sed '/v2ray-agent/d;/acme.sh/d' /etc/v2ray-agent/backup_crontab.cron)
    echo "${historyCrontab}" >/etc/v2ray-agent/backup_crontab.cron
    # 定时任务
    echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
    crontab /etc/v2ray-agent/backup_crontab.cron
    echoContent green "\n ---> 添加定时维护证书成功"
}

# 更新证书
renewalTLS(){
    
    if [[ -n "$1" ]]; then
        echoContent skyBlue "\n进度  1/1 : 更新证书"
    fi
    
    if [[ "${2}" == "force" ]]; then
        valid_days=0
    else
        valid_days=90
    fi
    
  
    if [[ -d "/root/.acme.sh" ]]; then
        if [[ -d "/root/.acme.sh/${current_host}_ecc" ]] && [[ -f "/root/.acme.sh/${current_host}_ecc/${current_host}.key" ]] && [[ -f "/root/.acme.sh/${current_host}_ecc/${current_host}.cer" ]]; then
            
            modify_time=$(stat --format=%z "$HOME/.acme.sh/${current_host}_ecc/${current_host}.cer")
            
            modify_time=$(date +%s -d "${modify_time}")
            current_time=$(date +%s)
            ((stamp_diff = current_time - modify_time))
            ((days = stamp_diff / 86400))
            ((remaining_days = valid_days - days))
            
            tls_status=${remaining_days}
            if [[ ${remaining_days} -le 0 ]]; then
                tls_status="已过期"
            fi
            echoContent skyBlue " ---> 证书生成日期:"`date -d @${modify_time} +"%F %H:%M:%S"`
            echoContent skyBlue " ---> 证书生成天数:"${days}
            echoContent skyBlue " ---> 证书剩余天数:"${tls_status}
            if [[ ${remaining_days} -le 1 ]]; then
                echoContent yellow " ---> 重新生成证书"
                handleNginx stop
                
                if [[ "${core_install_type}" == "1" ]]; then
                    handleXray stop
                elif [[ "${core_install_type}" == "2" ]]; then
                    handleV2Ray stop
                fi
                
                sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
                sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${current_host}" --fullchainpath /etc/v2ray-agent/tls/"${current_host}.crt" --keypath /etc/v2ray-agent/tls/"${current_host}.key" --ecc >> /etc/v2ray-agent/tls/acme.log
                
                if [[ "${core_install_type}" == "1" ]]; then
                    handleXray start
                elif [[ "${core_install_type}" == "2" ]]; then
                    handleV2Ray start
                fi
                
                handleNginx start
            else
                echoContent green " ---> 证书有效"
            fi
        else
            echoContent red " ---> 未安装"
        fi
    else
        echoContent red " ---> 未安装"
    fi
}


# 查看TLS证书的状态
checkTLStatus(){
    if [[ -n "${current_host}" ]]; then
        if [[ -d "/root/.acme.sh/${current_host}_ecc" ]] && [[ -f "/root/.acme.sh/${current_host}_ecc/${current_host}.key" ]] && [[ -f "/root/.acme.sh/${current_host}_ecc/${current_host}.cer" ]]; then
            modify_time=`stat /root/.acme.sh/${current_host}_ecc/${current_host}.key|sed -n '6,6p'|awk '{print $2" "$3" "$4" "$5}'`

            modify_time=`date +%s -d "${modify_time}"`
            current_time=`date +%s`
            stamp_diff=`expr ${current_time} - ${modify_time}`
            days=`expr ${stamp_diff} / 86400`
            remaining_days=`expr 90 - ${days}`
            tls_status=${remaining_days}
            if [[ ${remaining_days} -le 0 ]]; then
                tls_status="已过期"
            fi
            echoContent skyBlue " ---> 证书生成日期:"`date -d @${modify_time} +"%F %H:%M:%S"`
            echoContent skyBlue " ---> 证书生成天数:"${days}
            echoContent skyBlue " ---> 证书剩余天数:"${tls_status}
        fi
    fi
}

# 安装V2Ray、指定版本
installV2Ray(){
    readInstallType
    echoContent skyBlue "\n进度  $1/${total_progress} : 安装V2Ray"
    
    # 首先要卸载掉其余途径安装的V2Ray
    if [[ -n `ps -ef|grep -v grep|grep v2ray` ]] && [[ -z `ps -ef|grep -v grep|grep v2ray|grep v2ray-agent` ]]; then
        pkill v2ray > /dev/null 2>&1
        ps -ef|grep -v grep|grep v2ray|awk '{print $8}'|xargs rm -f
        ps -ef|grep -v grep|grep v2ray|awk '{print $2}'|xargs kill -9 > /dev/null 2>&1
    fi

    if [[ "${core_install_type}" != "2" && "${core_install_type}" != "3" ]]; then
        if [[ "${select_core_type}" = "2" ]]; then
            version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -1)
        else
            version=${v2ray_core_version}
        fi

        echoContent green " ---> v2ray-core版本:${version}"
        if [[ -n `wget --help|grep show-progress` ]]; then
            wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2ray_core_cpu_vendor}.zip"
        else
            wget -c -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2ray_core_cpu_vendor}.zip" > /dev/null 2>&1
        fi

        unzip -o "/etc/v2ray-agent/v2ray/${v2ray_core_cpu_vendor}.zip" -d /etc/v2ray-agent/v2ray > /dev/null
        rm -rf "/etc/v2ray-agent/v2ray/${v2ray_core_cpu_vendor}.zip"
    else
        if [[ "${select_core_type}" = "3" ]]; then
            echoContent green " ---> 锁定v2ray-core版本为v4.32.1"
            rm -f /etc/v2ray-agent/v2ray/v2ray
            rm -f /etc/v2ray-agent/v2ray/v2ctl
            installV2Ray "$1"
        else
            echoContent green " ---> v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
            read -p "是否更新、升级？[y/n]:" reinstall_v2ray_status
            if [[ "${reinstall_v2ray_status}" = "y" ]]; then
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                installV2Ray "$1"
            fi
        fi
    fi
}

# 安装xray
installXray(){
    readInstallType
    echoContent skyBlue "\n进度  $1/${total_progress} : 安装Xray"
    # 首先要卸载掉其余途径安装的Xray
    if [[ -n `ps -ef|grep -v grep|grep xray` ]] && [[ -z `ps -ef|grep -v grep|grep v2ray|grep v2ray-agent` ]]; then
        ps -ef|grep -v grep|grep xray|awk '{print $8}'|xargs rm -f
        ps -ef|grep -v grep|grep xray|awk '{print $2}'|xargs kill -9 > /dev/null 2>&1
    fi
    
    # 使用稳定版
    local prereleaseStatus=false

    if [[ "${core_install_type}" != "1" ]]; then
        version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[]|select (.prerelease=='${prereleaseStatus}')|.tag_name' | head -1)
        
        # version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -1|awk '{print $3}'|awk -F "[<]" '{print $1}'`

        echoContent green " ---> Xray-core版本:${version}"
        if [[ -n `wget --help|grep show-progress` ]]; then
            wget -c -q --show-progress -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/${xray_core_cpu_vendor}.zip > /dev/null 2>&1
        else
            wget -c -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/${xray_core_cpu_vendor}.zip > /dev/null 2>&1
        fi

        unzip -o /etc/v2ray-agent/xray/${xray_core_cpu_vendor}.zip -d /etc/v2ray-agent/xray > /dev/null
        rm -rf /etc/v2ray-agent/xray/${xray_core_cpu_vendor}.zip
        chmod 655 /etc/v2ray-agent/xray/xray
    else
        echoContent green " ---> Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"
        read -p "是否更新、升级？[y/n]:" reinstall_xray_status
        if [[ "${reinstall_xray_status}" = "y" ]]; then
            rm -f /etc/v2ray-agent/xray/xray
            installXray "$1"
        fi
    fi
}

# 安装Trojan-go
installTrojanGo(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 安装Trojan-Go"
    if [[ -z `ls -F /etc/v2ray-agent/trojan/|grep -w "trojan-go"` ]]; then
        version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        echoContent green " ---> Trojan-Go版本:${version}"
        if [[ -n `wget --help|grep show-progress` ]]; then
            wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/${trojan_core_cpu_vendor}.zip
        else
            wget -c -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/${trojan_core_cpu_vendor}.zip > /dev/null 2>&1
        fi
        unzip -o /etc/v2ray-agent/trojan/${trojan_core_cpu_vendor}.zip -d /etc/v2ray-agent/trojan > /dev/null
        rm -rf /etc/v2ray-agent/trojan/${trojan_core_cpu_vendor}.zip
    else
        echoContent green " ---> Trojan-Go版本:`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`"

        read -p "是否重新安装？[y/n]:" reInstallTrojanStatus
        if [[ "${reInstallTrojanStatus}" = "y" ]]; then
            rm -rf /etc/v2ray-agent/trojan/trojan-go*
            installTrojanGo "$1"
        fi
    fi
}

# v2ray版本管理
v2rayVersionManageMenu(){
    echoContent skyBlue "\n进度  $1/${total_progress} : V2Ray版本管理"
    if [[ ! -d "/etc/v2ray-agent/v2ray/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级"
    echoContent yellow "2.回退"
    echoContent red "=============================================================="
    read -p "请选择：" selectV2RayType
    if [[ "${selectV2RayType}" = "1" ]]; then
        updateV2Ray
    elif [[ "${selectV2RayType}" = "2" ]]; then
        echoContent yellow "\n1.只可以回退最近的两个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -p "请输入要回退的版本：" selectV2rayVersionType
        version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'|grep "${selectV2rayVersionType}:"|awk -F "[:]" '{print $2}'`
        if [[ -n "${version}" ]]; then
            updateV2Ray ${version}
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            v2rayVersionManageMenu 1
        fi
    fi

}

# xray版本管理
xrayVersionManageMenu(){
    echoContent skyBlue "\n进度  $1/${total_progress} : Xray版本管理"
    if [[ ! -d "/etc/v2ray-agent/xray/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级"
    echoContent yellow "2.回退"
    echoContent red "=============================================================="
    read -p "请选择：" selectXrayType
    if [[ "${selectXrayType}" = "1" ]]; then
        updateXray
    elif [[ "${selectXrayType}" = "2" ]]; then
        echoContent yellow "\n1.只可以回退最近的两个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -p "请输入要回退的版本：" selectXrayVersionType
        version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'|grep "${selectXrayVersionType}:"|awk -F "[:]" '{print $2}'`
        if [[ -n "${version}" ]]; then
            updateXray ${version}
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            xrayVersionManageMenu 1
        fi
    fi

}
# 更新V2Ray
updateV2Ray(){
    readInstallType
    if [[ -z "${core_install_type}" ]]; then

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        fi
        # 使用锁定的版本
        if [[ -n "${v2ray_core_version}" ]]; then
            version=${v2ray_core_version}
        fi
        echoContent green " ---> v2ray-core版本:${version}"

        if [[ -n `wget --help|grep show-progress` ]]; then
            wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2ray_core_cpu_vendor}.zip
        else
            wget -c -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2ray_core_cpu_vendor}.zip > /dev/null 2>&1
        fi

        unzip -o  /etc/v2ray-agent/v2ray/${v2ray_core_cpu_vendor}.zip -d /etc/v2ray-agent/v2ray > /dev/null
        rm -rf /etc/v2ray-agent/v2ray/${v2ray_core_cpu_vendor}.zip
        handleV2Ray stop
        handleV2Ray start
    else
        echoContent green " ---> 当前v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        fi

        if [[ -n "${v2ray_core_version}" ]]; then
            version=${v2ray_core_version}
        fi
        if [[ -n "$1" ]]; then
            read -p "回退版本为${version}，是否继续？[y/n]:" roolback_v2ray_status
            if [[ "${roolback_v2ray_status}" = "y" ]]; then
                if [[ "${core_install_type}" = "2" || "${core_install_type}" = "3"  ]]; then
                    echoContent green " ---> 当前v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
                elif [[ "${core_install_type}" = "1"  ]]; then
                    echoContent green " ---> 当前Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"
                fi

                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray ${version}
            else
                echoContent green " ---> 放弃回退版本"
            fi
        elif [[ "${version}" = "v`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`" ]]; then
            read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reinstall_v2ray_status
            if [[ "${reinstall_v2ray_status}" = "y" ]]; then
                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray
            else
                echoContent green " ---> 放弃重新安装"
            fi
        else
            read -p "最新版本为：${version}，是否更新？[y/n]：" install_v2ray_status
            if [[ "${install_v2ray_status}" = "y" ]]; then
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray
            else
                echoContent green " ---> 放弃更新"
            fi

        fi
    fi
}

# 更新Xray
updateXray(){
    readInstallType
    if [[ -z "${core_install_type}" ]]; then
        if [[ -n "$1" ]]; then
            version=$1
        else
            version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -1|awk '{print $3}'|awk -F "[<]" '{print $1}'`
        fi

        echoContent green " ---> Xray-core版本:${version}"

        if [[ -n `wget --help|grep show-progress` ]]; then
            wget -c -q --show-progress -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/${xray_core_cpu_vendor}.zip
        else
            wget -c -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/${xray_core_cpu_vendor}.zip > /dev/null 2>&1
        fi

        unzip -o /etc/v2ray-agent/xray/${xray_core_cpu_vendor}.zip -d /etc/v2ray-agent/xray > /dev/null
        rm -rf /etc/v2ray-agent/xray/${xray_core_cpu_vendor}.zip
        chmod 655 /etc/v2ray-agent/xray/xray
        handleXray stop
        handleXray start
    else
        echoContent green " ---> 当前Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -1|awk '{print $3}'|awk -F "[<]" '{print $1}'`
        fi

        if [[ -n "$1" ]]; then
            read -p "回退版本为${version}，是否继续？[y/n]:" roolback_xray_status
            if [[ "${roolback_xray_status}" = "y" ]]; then
                echoContent green " ---> 当前Xray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"

                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray ${version}
            else
                echoContent green " ---> 放弃回退版本"
            fi
        elif [[ "${version}" = "v`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`" ]]; then
            read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reinstall_xray_status
            if [[ "${reinstall_xray_status}" = "y" ]]; then
                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
                echoContent green " ---> 放弃重新安装"
            fi
        else
            read -p "最新版本为：${version}，是否更新？[y/n]：" install_xray_status
            if [[ "${install_xray_status}" = "y" ]]; then
                rm -f /etc/v2ray-agent/xray/xray
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
                echoContent green " ---> 放弃更新"
            fi

        fi
    fi
}
# 更新Trojan-Go
updateTrojanGo(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 更新Trojan-Go"
    if [[ ! -d "/etc/v2ray-agent/trojan/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    if [[ -z `ls -F /etc/v2ray-agent/trojan/|grep "trojan-go"` ]]; then
        version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        echoContent green " ---> Trojan-Go版本:${version}"
        if [[ -n `wget --help|grep show-progress` ]]; then
            wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/${trojan_core_cpu_vendor}.zip
        else
            wget -c -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/${trojan_core_cpu_vendor}.zip > /dev/null 2>&1
        fi
        unzip -o /etc/v2ray-agent/trojan/${trojan_core_cpu_vendor}.zip -d /etc/v2ray-agent/trojan > /dev/null
        rm -rf /etc/v2ray-agent/trojan/${trojan_core_cpu_vendor}.zip
        handleTrojanGo stop
        handleTrojanGo start
    else
        echoContent green " ---> 当前Trojan-Go版本:`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`"
        if [[ -n `/etc/v2ray-agent/trojan/trojan-go --version` ]]; then
            version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            if [[ "${version}" = "`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`" ]]; then
                read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reinstall_trojan_status
                if [[ "${reinstall_trojan_status}" = "y" ]]; then
                    handleTrojanGo stop
                    rm -rf /etc/v2ray-agent/trojan/trojan-go
                    updateTrojanGo 1
                else
                    echoContent green " ---> 放弃重新安装"
                fi
            else
                read -p "最新版本为：${version}，是否更新？[y/n]：" install_trojan_status
                if [[ "${install_trojan_status}" = "y" ]]; then
                    rm -rf /etc/v2ray-agent/trojan/trojan-go
                    updateTrojanGo 1
                else
                    echoContent green " ---> 放弃更新"
                fi
            fi
        fi
    fi
}

# 验证整个服务是否可用
checkGFWStatue(){
    echoContent skyBlue "\n进度 $1/${total_progress} : 验证服务启动状态"  
    sleep 0.5
    if [[ "${core_install_type}" == "1" ]] && [[ -n $(pgrep -f "xray/xray") ]]; then
        echoContent green " ---> 服务启动成功"
    elif [[ "${core_install_type}" == "2" ]] && [[ -n $(pgrep -f "v2ray/v2ray") ]]; then
        echoContent green " ---> 服务启动成功"
    else
        echoContent red " ---> 服务启动失败，请检查终端是否有日志打印"
        exit 0
    fi
}

# V2Ray开机自启
installV2RayService(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 配置V2Ray开机自启"
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
        rm -rf /etc/systemd/system/v2ray.service
        touch /etc/systemd/system/v2ray.service
        execStart='/etc/v2ray-agent/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config_full.json'
        if [[ -n ${select_custom_install_type} ]]; then
            execStart='/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf'
        fi
    cat << EOF > /etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray - A unified platform for anti-censorship
Documentation=https://v2ray.com https://guide.v2fly.org
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable v2ray.service
        echoContent green " ---> 配置V2Ray开机自启成功"
    fi
}

# Xray开机自启
installXrayService(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 配置Xray开机自启"
    if [[ -n `find /bin /usr/bin -name "systemctl"` ]]; then
        rm -rf /etc/systemd/system/xray.service
        touch /etc/systemd/system/xray.service
        execStart='/etc/v2ray-agent/xray/xray run -config /etc/v2ray-agent/xray/config_full.json'
        if [[ -n ${select_custom_install_type} ]]; then
            execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
        fi
    cat << EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray - A unified platform for anti-censorship
# Documentation=https://v2ray.com https://guide.v2fly.org
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable xray.service
        echoContent green " ---> 配置Xray开机自启成功"
    fi
}
# Trojan开机自启
installTrojanService(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 配置Trojan开机自启"
    if [[ -n `find /bin /usr/bin -name "systemctl"` ]]; then
        rm -rf /etc/systemd/system/trojan-go.service
        touch /etc/systemd/system/trojan-go.service

    cat << EOF > /etc/systemd/system/trojan-go.service
[Unit]
Description=Trojan-Go - A unified platform for anti-censorship
Documentation=Trojan-Go
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable trojan-go.service
        echoContent green " ---> 配置Trojan开机自启成功"
    fi
}
# 操作V2Ray
handleV2Ray(){
    
    # 修复v2ray启动失败
    local v2ray_access_log=/etc/v2ray-agent/v2ray/v2ray_access.log
    local v2ray_error_log=/etc/v2ray-agent/v2ray/v2ray_error.log
    

    if [[ -n `find /bin /usr/bin -name "systemctl"` ]] && [[ -n `ls /etc/systemd/system/|grep -v grep|grep v2ray.service` ]]; then
        if [[ -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]] && [[ "$1" = "start" ]]; then
            
            if [[ -f $v2ray_access_log ]]; then
            
                while true
                do
                    echoContent yellow "\n --> 正在取消 $v2ray_access_log 只读属性"
                    sudo chattr -i $v2ray_access_log
                    sudo chattr -i $v2ray_error_log
                    
                    sleep 0.5
                    
                    if lsattr $v2ray_access_log | grep '\-i'; then
                        sleep 1
                        continue
                    else
                        echoContent yellow "\n --> 已取消 $v2ray_access_log 只读属性"
                        echo >$v2ray_access_log
                        echo >$v2ray_error_log
                        break
                    fi
                done                
            fi
            
            systemctl start v2ray.service
            
        elif [[ -n `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]] && [[ "$1" = "stop" ]]; then
            systemctl stop v2ray.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]; then
        if [[ -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ "$1" = "start" ]]; then
            /usr/bin/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config_full.json & > /dev/null 2>&1
        elif [[ -n `ps -ef|grep -v grep|grep v2ray` ]] && [[ "$1" = "stop" ]]; then
            ps -ef|grep -v grep|grep v2ray|awk '{print $2}'|xargs kill -9
        fi
    fi
    
    sleep 0.5
    if [[ "$1" = "start" ]]; then
        if [[ -n `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]]; then
            echoContent green " ---> V2Ray启动成功"
            echoContent yellow "\n --> 已恢复 $v2ray_access_log 只读属性"
            sudo chattr +i $v2ray_access_log 
            sudo chattr +i $v2ray_error_log 
        else
            echoContent red "V2Ray启动失败"
            echoContent red "执行 [ps -ef|grep v2ray] 查看日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]; then
        if [[ -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]]; then
            echoContent green " ---> V2Ray关闭成功"
        else
            echoContent red "V2Ray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 操作xray
handleXray(){

    # 修复xray启动失败
    local xray_access_log=/etc/v2ray-agent/xray/xray_access.log
    local xray_error_log=/etc/v2ray-agent/xray/xray_error.log
    
    if [[ -n `find /bin /usr/bin -name "systemctl"` ]] && [[ -n `ls /etc/systemd/system/|grep -v grep|grep xray.service` ]]; then
        if [[ -z `ps -ef|grep -v grep|grep "xray/xray"` ]] && [[ "$1" = "start" ]]; then
            
            if [[ -f $xray_access_log ]]; then
            
                while true
                do
                    echoContent yellow "\n --> 正在取消 $v2ray_access_log 只读属性"
                    sudo chattr -i $xray_access_log
                    sudo chattr -i $xray_error_log
                    
                    sleep 0.5
                    
                    if lsattr $xray_access_log | grep '\-i'; then
                        sleep 1
                        continue
                    else
                        echoContent yellow "\n --> 已取消 $xray_access_log 只读属性"
                        echo >$xray_access_log
                        echo >$xray_error_log
                        break
                    fi
                done                
            fi
        
            systemctl start xray.service
        elif [[ -n `ps -ef|grep -v grep|grep "xray/xray"` ]] && [[ "$1" = "stop" ]]; then
            systemctl stop xray.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]; then
        if [[ -z `ps -ef|grep -v grep|grep xray` ]] && [[ "$1" = "start" ]]; then
            /usr/bin/xray/xray -config /etc/v2ray-agent/xray/config_full.json & > /dev/null 2>&1
        elif [[ -n `ps -ef|grep -v grep|grep xray` ]] && [[ "$1" = "stop" ]]; then
            ps -ef|grep -v grep|grep xray|awk '{print $2}'|xargs kill -9
        fi
    fi
    
    sleep 0.5
    if [[ "$1" = "start" ]]; then
        if [[ -n `ps -ef|grep -v grep|grep "xray/xray"` ]]; then
            echoContent green " ---> Xray启动成功"
            echoContent yellow "\n --> 已恢复 $xray_access_log 只读属性"
            sudo chattr +i $xray_access_log 
            sudo chattr +i $xray_error_log 
        else
            echoContent red "xray启动失败"
            echoContent red "执行 [ps -ef|grep xray] 查看日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]; then
        if [[ -z `ps -ef|grep -v grep|grep "xray/xray"` ]]; then
            echoContent green " ---> Xray关闭成功"
        else
            echoContent red "xray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 操作Trojan-Go
handleTrojanGo(){
    if [[ -n `find /bin /usr/bin -name "systemctl"` ]] && [[ -n `ls /etc/systemd/system/|grep -v grep|grep trojan-go.service` ]]; then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "start" ]]; then
            systemctl start trojan-go.service
        elif [[ -n `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "stop" ]]; then
            systemctl stop trojan-go.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]; then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "start" ]]; then
            /etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json & > /dev/null 2>&1
        elif [[ -n `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "stop" ]]; then
            ps -ef|grep -v grep|grep trojan-go|awk '{print $2}'|xargs kill -9
        fi
    fi
    sleep 0.5
    if [[ "$1" = "start" ]]; then
        if [[ -n `ps -ef|grep -v grep|grep trojan-go` ]]; then
            echoContent green " ---> Trojan-Go启动成功"
        else
            echoContent red "Trojan-Go启动失败"
            echoContent red "请手动执行【/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json】,查看错误日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]; then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]]; then
            echoContent green " ---> Trojan-Go关闭成功"
        else
            echoContent red "Trojan-Go关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep trojan-go|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 初始化V2Ray 配置文件
initV2RayConfig(){
    echoContent skyBlue "\n进度 $2/${total_progress} : 初始化V2Ray配置"
    
    read -r -p "是否自定义UUID ？[y/n]:" custom_uuid_status
    echo
    if [[ "${custom_uuid_status}" == "y" ]]; then
        read -r -p "请输入合法的UUID:" current_custom_uuid
        if [[ -n "${current_custom_uuid}" ]]; then
            uuid=${current_custom_uuid}
        fi
    fi
    
    if [[ -n "${current_uuid}" ]]; then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" history_uuid_status
        if [[ "${history_uuid_status}" = "y" ]]; then
            uuid=${current_uuid}
            uuidDirect=${current_uuid_direct}
        else
            uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
            uuidDirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        fi
    fi
    
    if [[ -z "${uuid}" ]]; then
        echoContent red "\n ---> uuid读取错误，重新生成"
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi

    if [[ -z "${uuidDirect}" ]] && [[ "${select_core_type}" = "3" ]]; then
        echoContent red "\n ---> uuid XTLS-direct读取错误，重新生成"
        uuidDirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi

    if [[ "${uuid}" = "${uuidDirect}" ]]; then
        echoContent red "\n ---> uuid重复，重新生成"
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        uuidDirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi
    echoContent green "\n ---> 使用成功"

    rm -rf /etc/v2ray-agent/v2ray/conf/*
    rm -rf /etc/v2ray-agent/v2ray/config_full.json
    if [[ "$1" = "all" ]] && [[ "${select_core_type}" = "2" ]]; then
        # default v2ray-core
        cat << EOF > /etc/v2ray-agent/v2ray/config_full.json
{
  "log": {
    "access": "/etc/v2ray-agent/v2ray/v2ray_access.log",
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "email": "${domain}_VLESS_TLS_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 31296,
            "xver": 0
          },
          {
            "path": "/${custom_path}",
            "dest": 31299,
            "xver": 1
          },
          {
            "path": "/${custom_path}tcp",
            "dest": 31298,
            "xver": 1
          },
          {
            "path": "/${custom_path}ws",
            "dest": 31297,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    },
    {
      "port": 31299,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}"
        }
      }
    },
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "alterId": 0,
            "email": "${domain}_vmess_tcp"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "acceptProxyProtocol": true,
          "header": {
            "type": "http",
            "request": {
              "path": [
                "/${custom_path}tcp"
              ]
            }
          }
        }
      }
    },
    {
      "port": 31297,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "${domain}_vless_ws"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}ws"
        }
      }
    }
  ],
  "routing":{
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "outbounds": [
    {
      "tag":"direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "dns": {
    "servers": [
      "74.82.42.42",
      "8.8.8.8",
      "8.8.4.4",
      "1.1.1.1",
      "localhost"
    ]
  }
}
EOF
    elif [[ "$1" = "all" ]] && [[ "${select_core_type}" = "3" ]]; then
        # 需锁定4.32.1
        cat << EOF > /etc/v2ray-agent/v2ray/config_full.json
{
  "log": {
    "access": "/etc/v2ray-agent/v2ray/v2ray_access.log",
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidDirect}",
            "flow":"xtls-rprx-direct",
            "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 31296,
            "xver": 0
          },
          {
            "path": "/${custom_path}",
            "dest": 31299,
            "xver": 1
          },
          {
            "path": "/${custom_path}tcp",
            "dest": 31298,
            "xver": 1
          },
          {
            "path": "/${custom_path}ws",
            "dest": 31297,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    },
    {
      "port": 31299,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "alterId": 0,
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}"
        }
      }
    },
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "alterId": 0,
            "email": "${domain}_vmess_tcp"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "acceptProxyProtocol": true,
          "header": {
            "type": "http",
            "request": {
              "path": [
                "/${custom_path}tcp"
              ]
            }
          }
        }
      }
    },
    {
      "port": 31297,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "${domain}_vless_ws"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}ws"
        }
      }
    }
  ],
  "routing":{
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "outbounds": [
    {
      "tag":"direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "dns": {
    "servers": [
      "74.82.42.42",
      "8.8.8.8",
      "8.8.4.4",
      "1.1.1.1",
      "localhost"
    ]
  }
}
EOF
    elif [[ "$1" = "custom" ]]; then
        # custom v2ray-core
        cat << EOF > /etc/v2ray-agent/v2ray/conf/00_log.json
{
  "log": {
    "access": "/etc/v2ray-agent/v2ray/v2ray_access.log",
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "debug"
  }
}
EOF
        # outbounds
       cat << EOF > /etc/v2ray-agent/v2ray/conf/10_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          }
        },
        {
          "tag": "blocked",
          "protocol": "blackhole",
          "settings": {}
        }
    ]
}
EOF
       cat << EOF > /etc/v2ray-agent/v2ray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF
        # dns
       cat << EOF > /etc/v2ray-agent/v2ray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "74.82.42.42",
          "8.8.8.8",
          "8.8.4.4",
          "1.1.1.1",
          "localhost"
        ]
  }
}
EOF
        # VLESS_TCP_TLS/XTLS
        # 没有path则回落到此端口
        local fallback_lists='{"dest":31296,"xver":0}'

        if [[ -z `echo ${select_custom_install_type}|grep 4` ]]; then
            fallback_lists='{"dest":80,"xver":0}'
        fi

        # VLESS_WS_TLS
        if [[ -n `echo ${select_custom_install_type}|grep 1` ]]; then
            fallback_lists=${fallback_lists}',{"path":"/'${custom_path}'ws","dest":31297,"xver":1}'
            cat << EOF > /etc/v2ray-agent/v2ray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
        {
      "port": 31297,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "${domain}_vless_ws"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}ws"
        }
      }
    }
    ]
}
EOF
        fi
# VMess_TCP
        if [[ -n `echo ${select_custom_install_type}|grep 2` ]]; then
            fallback_lists=${fallback_lists}',{"path":"/'${custom_path}'tcp","dest":31298,"xver":1}'
            cat << EOF > /etc/v2ray-agent/v2ray/conf/04_VMess_TCP_inbounds.json
{
"inbounds":[
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "tag":"VMessTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "alterId": 0,
            "email": "${domain}_vmess_tcp"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "acceptProxyProtocol": true,
          "header": {
            "type": "http",
            "request": {
              "path": [
                "/${custom_path}tcp"
              ]
            }
          }
        }
      }
    }
]
}
EOF
        fi
        # VMess_WS
        if [[ -n `echo ${select_custom_install_type}|grep 3` ]]; then
            fallback_lists=${fallback_lists}',{"path":"/'${custom_path}'","dest":31299,"xver":1}'
            cat << EOF > /etc/v2ray-agent/v2ray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
      "port": 31299,
      "protocol": "vmess",
      "tag":"VMessWS",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "add": "${add}",
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}"
        }
      }
    }
]
}
EOF
        fi
        # VLESS_TCP
        if [[ "${select_core_type}" = "2" ]]; then
            cat << EOF > /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
  "inbounds":[
    {
      "port": 443,
      "protocol": "vless",
      "tag":"VLESSTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "email": "${domain}_VLESS_TLS_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
            ${fallback_lists}
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    }
  ]
}
EOF
        elif [[ "${select_core_type}" = "3" ]]; then

        cat << EOF > /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
  "inbounds":[
    {
      "port": 443,
      "protocol": "vless",
      "tag":"VLESSTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidDirect}",
            "flow":"xtls-rprx-direct",
            "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
            ${fallback_lists}
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    }
  ]
}
EOF
        fi

    fi
}


# 初始化Xray 配置文件
initXrayConfig(){
    echoContent skyBlue "\n进度 $2/${total_progress} : 初始化Xray配置"
    if [[ -n "${current_uuid}" ]]; then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" history_uuid_status
        if [[ "${history_uuid_status}" = "y" ]]; then
            uuid=${current_uuid}
            uuidDirect=${current_uuid_direct}
        fi
    else
        uuid=`/etc/v2ray-agent/xray/xray uuid`
        uuidDirect=`/etc/v2ray-agent/xray/xray uuid`
    fi
    if [[ -z "${uuid}" ]]; then
        echoContent red "\n ---> uuid读取错误，重新生成"
        uuid=`/etc/v2ray-agent/xray/xray uuid`
    fi

    if [[ -z "${uuidDirect}" ]] && [[ "${select_core_type}" = "1" ]]; then
        echoContent red "\n ---> uuid XTLS-direct读取错误，重新生成"
        uuidDirect=`/etc/v2ray-agent/xray/xray uuid`
    fi

    if [[ "${uuid}" = "${uuidDirect}" ]]; then
        echoContent red "\n ---> uuid重复，重新生成"
        uuid=`/etc/v2ray-agent/xray/xray uuid`
        uuidDirect=`/etc/v2ray-agent/xray/xray uuid`
    fi
    echoContent green "\n ---> 使用成功"

    rm -rf /etc/v2ray-agent/xray/conf/*
    rm -rf /etc/v2ray-agent/xray/config_full.json
    if [[ "$1" = "all" ]]; then
        # default v2ray-core
        cat << EOF > /etc/v2ray-agent/xray/config_full.json
{
  "log": {
    "access": "/etc/v2ray-agent/xray/xray_access.log",
    "error": "/etc/v2ray-agent/xray/xray_error.log",
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidDirect}",
            "flow":"xtls-rprx-direct",
            "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 31296,
            "xver": 0
          },
          {
            "path": "/${custom_path}",
            "dest": 31299,
            "xver": 1
          },
          {
            "path": "/${custom_path}tcp",
            "dest": 31298,
            "xver": 1
          },
          {
            "path": "/${custom_path}ws",
            "dest": 31297,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    },
    {
      "port": 31299,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}"
        }
      }
    },
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "alterId": 0,
            "email": "${domain}_vmess_tcp"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "acceptProxyProtocol": true,
          "header": {
            "type": "http",
            "request": {
              "path": [
                "/${custom_path}tcp"
              ]
            }
          }
        }
      }
    },
    {
      "port": 31297,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "${domain}_vless_ws"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}ws"
        }
      }
    }
  ],
  "routing":{
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "outbounds": [
    {
      "tag":"direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "dns": {
    "servers": [
      "74.82.42.42",
      "8.8.8.8",
      "8.8.4.4",
      "1.1.1.1",
      "localhost"
    ]
  }
}
EOF
    elif [[ "$1" = "custom" ]]; then
        # custom xray-core
        cat << EOF > /etc/v2ray-agent/xray/conf/00_log.json
{
  "log": {
    "access": "/etc/v2ray-agent/xray/xray_access.log",
    "error": "/etc/v2ray-agent/xray/xray_error.log",
    "loglevel": "debug"
  }
}
EOF
      cat << EOF > /etc/v2ray-agent/xray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF

        # outbounds
       cat << EOF > /etc/v2ray-agent/xray/conf/10_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          }
        },
        {
          "tag": "blocked",
          "protocol": "blackhole",
          "settings": {}
        }
    ]
}
EOF
      cat << EOF > /etc/v2ray-agent/v2ray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF
        # dns
       cat << EOF > /etc/v2ray-agent/xray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "74.82.42.42",
          "8.8.8.8",
          "8.8.4.4",
          "1.1.1.1",
          "localhost"
        ]
  }
}
EOF
        # VLESS_TCP_TLS/XTLS
        # 没有path则回落到此端口
        local fallback_lists='{"dest":31296,"xver":0}'

        if [[ -z `echo ${select_custom_install_type}|grep 4` ]]; then
            fallback_lists='{"dest":80,"xver":0}'
        fi

        # VLESS_WS_TLS
        if [[ -n `echo ${select_custom_install_type}|grep 1` ]]; then
            fallback_lists=${fallback_lists}',{"path":"/'${custom_path}'ws","dest":31297,"xver":1}'
            cat << EOF > /etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
        {
      "port": 31297,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "${domain}_vless_ws"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}ws"
        }
      }
    }
    ]
}
EOF
        fi
# VMess_TCP
        if [[ -n `echo ${select_custom_install_type}|grep 2` ]]; then
            fallback_lists=${fallback_lists}',{"path":"/'${custom_path}'tcp","dest":31298,"xver":1}'
            cat << EOF > /etc/v2ray-agent/xray/conf/04_VMess_TCP_inbounds.json
{
"inbounds":[
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "tag":"VMessTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "alterId": 0,
            "email": "${domain}_vmess_tcp"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "acceptProxyProtocol": true,
          "header": {
            "type": "http",
            "request": {
              "path": [
                "/${custom_path}tcp"
              ]
            }
          }
        }
      }
    }
]
}
EOF
        fi
        # VMess_WS
        if [[ -n `echo ${select_custom_install_type}|grep 3` ]]; then
            fallback_lists=${fallback_lists}',{"path":"/'${custom_path}'","dest":31299,"xver":1}'
            cat << EOF > /etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
      "port": 31299,
      "protocol": "vmess",
      "tag":"VMessWS",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "add": "${add}",
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${custom_path}"
        }
      }
    }
]
}
EOF
        fi

        # VLESS_TCP

        cat << EOF > /etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json
{
  "inbounds":[
    {
      "port": 443,
      "protocol": "vless",
      "tag":"VLESSTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidDirect}",
            "flow":"xtls-rprx-direct",
            "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
            ${fallback_lists}
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    }
  ]
}
EOF

    fi
}
# 初始化Trojan-Go配置
initTrojanGoConfig(){

    echoContent skyBlue "\n进度 $1/${total_progress} : 初始化Trojan配置"
    cat << EOF > /etc/v2ray-agent/trojan/config_full.json
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 31296,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "log_level":0,
    "log_file":"/etc/v2ray-agent/trojan/trojan.log",
    "password": [
        "${uuid}"
    ],
    "dns":[
        "74.82.42.42",
        "8.8.8.8",
        "8.8.4.4",
        "1.1.1.1",
        "localhost"
    ],
    "transport_plugin":{
        "enabled":true,
        "type":"plaintext"
    },
    "websocket": {
        "enabled": true,
        "path": "/${custom_path}tws",
        "host": "${domain}",
        "add":"${add}"
    },
    "router": {
        "enabled": false
    },
    "tcp":{
        "prefer_ipv4":true
    }
}
EOF
}

# 自定义CDN IP
customCDNIP(){    
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加cloudflare自选CNAME"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项"
    echoContent red "\n如对Cloudflare优化不了解，请不要使用"
    echoContent yellow "\n 1.CNAME www.digitalocean.com"
    echoContent yellow " 2.CNAME who.int"
    echoContent yellow " 3.CNAME blog.hostmonit.com"

    echoContent skyBlue "----------------------------"
    read -r -p "请选择[回车不使用]:" selectCloudflareType
    case ${selectCloudflareType} in
        1)
            add="www.digitalocean.com"
            echoContent green "\n ---> 使用${add}成功"
            ;;
        2)
            add="who.int"
            echoContent green "\n ---> 使用${add}成功"
            ;;
        3)
            add="blog.hostmonit.com"
            echoContent green "\n ---> 使用${add}成功"
            ;;
        *)
            add="${domain}"
            echoContent yellow "\n ---> 不使用"
            ;;
    esac
    
}

# 通用
defaultBase64Code(){
    local type=$1
    local ps=$2
    local id=$3
    local hostPort=$4
    local host=
    local port=
    if [[ -n `echo ${hostPort}|grep ":"` ]]; then
        host=`echo ${hostPort}|awk -F "[:]" '{print $1}'`
        port=`echo ${hostPort}|awk -F "[:]" '{print $2}'`
    else
        host=${hostPort}
        port=443
    fi

    local path=$5
    local add=$6
    if [[ ${type} = "tcp" ]]; then

        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","net":"tcp","add":"'${host}'","allowInsecure":0,"method":"none","peer":""}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(tcp+tls)"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","net":"tcp","add":"'${host}'","allowInsecure":0,"method":"none","peer":""}\n'
        # 通用Vmess
        echoContent yellow " ---> 通用vmess(tcp+tls)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echo "通用vmess(tcp+tls)链接: " > /etc/v2ray-agent/v2ray/usersv2ray.conf
        echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    elif [[ ${type} = "wss" ]]; then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(ws+tls)"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(ws+tls)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echo "通用vmess(ws+tls)链接: " > /etc/v2ray-agent/v2ray/usersv2ray.conf
        echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    elif [[ "${type}" = "h2" ]]; then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"h2","add":"'${add}'","allowInsecure":0,"method":"none","peer":""}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent red "通用json--->"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"h2","add":"'${add}'","allowInsecure":0,"method":"none","peer":""}\n'
    elif [[ "${type}" = "vlesstcp" ]]; then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echo "通用vmess(VLESS+TCP+TLS)链接: " > /etc/v2ray-agent/v2ray/usersv2ray.conf
        echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
        echoContent yellow " ---> 通用json(VLESS+TCP+TLS)"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"host":"'${host}'","type":"none","net":"tcp","add":"'${host}'","allowInsecure":0,"method":"none","peer":""}\n'
        echoContent green '    V2Ray v4.27.4+ 目前无通用订阅，需要手动配置，VLESS TCP、XTLS和TCP大部分一样，其余内容不变，请注意手动输入的流控flow类型，v2ray-core v4.32.1之后不支持XTLS，Xray-core支持，建议使用Xray-core\n'

    elif [[ "${type}" = "vmessws" ]]; then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VMess+WS+TLS)"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(VMess+WS+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+WS+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" = "vmesstcp" ]]; then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"http","path":'${path}',"net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VMess+TCP+TLS)"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"http","path":'${path}',"net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(VMess+TCP+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+TCP+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"
    elif [[ "${type}" = "vlessws" ]]; then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VLESS+WS+TLS)"
        echoContent green '    {"port":"'${port}'","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
    elif [[ "${type}" = "trojan" ]]; then
        # URLEncode
        echoContent yellow " ---> Trojan(TLS)"
        echoContent green "    trojan://${id}@${host}:${port}?peer=${host}&sni=${host}\n"
        echoContent yellow " ---> 二维码 Trojan(TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3fpeer%3d${host}%26sni%3d${host}%23${host}_trojan\n"

    elif [[ "${type}" = "trojangows" ]]; then
        # URLEncode
        echoContent yellow " ---> Trojan-Go(WS+TLS) Shadowrocket"
        echoContent green "    trojan://${id}@${add}:${port}?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_trojan_ws\n"
        echoContent yellow " ---> 二维码 Trojan-Go(WS+TLS) Shadowrocket"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${port}%3fallowInsecure%3d0%26peer%3d${host}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${host}%3bobfs-uri%3d${path}%23${host}_trojan_ws\n"

        path=`echo ${path}|awk -F "[/]" '{print $2}'`
        echoContent yellow " ---> Trojan-Go(WS+TLS) QV2ray"
        echoContent green "    trojan-go://${id}@${add}:${port}?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_trojan_ws\n"
    fi
}

# 账号
showAccounts(){
    readInstallType
    readConfigHostPathUUID
    readCustomInstallType
    showStatus=
    echoContent skyBlue "\n进度 $1/${total_progress} : 账号"


    if [[ "${v2ray_agent_install_type}" = "1" ]]; then
        showStatus=true
        local configPath=
        if [[ "${core_install_type}" = "1" ]]; then
            configPath=${xray_core_config_file_path}
        elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
            configPath=${v2ray_core_config_file_path}
        fi
        # VLESS tcp
        local tcp=`cat ${configPath}|jq .inbounds[0]`
        local port=`echo ${tcp}|jq .port`
        local tcpID=`echo ${tcp}|jq .settings.clients[0].id`
        local tcpEmail="`echo ${tcp}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local CDNADD=`echo ${tcp}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`

        # XTLS Direct
        local tcpIDirect=`echo ${tcp}|jq .settings.clients[1].id`
        local tcpDirectEmail="`echo ${tcp}|jq .settings.clients[1].email|awk -F '["]' '{print $2}'`"


         # VLESS ws
        local vlessWS=`cat ${configPath}|jq .inbounds[3]`
        local vlessWSID=`echo ${vlessWS}|jq .settings.clients[0].id`
        local vlessWSEmail="`echo ${vlessWS}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local vlessWSPath=`echo ${vlessWS}|jq .streamSettings.wsSettings.path`

        # Vmess ws
        local ws=`cat ${configPath}|jq .inbounds[1]`
        local wsID=`echo ${ws}|jq .settings.clients[0].id`
        local wsEmail="`echo ${ws}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local wsPath=`echo ${ws}|jq .streamSettings.wsSettings.path`

        # Vmess tcp
        local vmessTCP=`cat ${configPath}|jq .inbounds[2]`
        local vmessTCPID=`echo ${vmessTCP}|jq .settings.clients[0].id`
        local vmessTCPEmail="`echo ${vmessTCP}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local vmessTCPath=`echo ${vmessTCP}|jq .streamSettings.tcpSettings.header.request.path[0]`

        if [[ "${core_install_type}" = "3" || "${core_install_type}" = "1" ]]; then
            echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-origin ==========================="
            defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${current_host}:${port}" ${add}

            echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-direct ==========================="
            defaultBase64Code vlesstcp ${tcpDirectEmail} "${tcpIDirect}" "${current_host}:${port}" ${add}

        elif [[ "${core_install_type}" = "2" ]]; then
            echoContent skyBlue "\n============================ VLESS TCP TLS ======================================="
            defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${current_host}:${port}" ${add}
        fi

        echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================"
        defaultBase64Code vlessws ${vlessWSEmail} "${vlessWSID}" "${current_host}:${port}" "${vlessWSPath}" ${CDNADD}

        echoContent skyBlue "\n================================ VMess WS TLS CDN ================================"
        defaultBase64Code vmessws ${wsEmail} "${wsID}" "${current_host}:${port}" "${wsPath}" ${CDNADD}

        echoContent skyBlue "\n================================= VMess TCP TLS  ================================="
        defaultBase64Code vmesstcp ${vmessTCPEmail} "${vmessTCPID}" "${current_host}:${port}" "${vmessTCPath}" "${current_host}"

    elif [[ "${v2ray_agent_install_type}" = "2" ]]; then
        local configPath=
        if [[ "${core_install_type}" = "1" ]]; then
            configPath=${xray_core_config_file_path}
        elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
            configPath=${v2ray_core_config_file_path}
        fi

        showStatus=true

        # VLESS tcp
        local tcp=`cat ${configPath}|jq .inbounds[0]`
        local port=`echo ${tcp}|jq .port`
        local tcpID=`echo ${tcp}|jq .settings.clients[0].id`
        local tcpEmail="`echo ${tcp}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"

        local CDNADD=`echo ${tcp}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
        # XTLS Direct
        local tcpIDirect=`echo ${tcp}|jq .settings.clients[1].id`
        local tcpDirectEmail="`echo ${tcp}|jq .settings.clients[1].email|awk -F '["]' '{print $2}'`"

        if [[ "${core_install_type}" = "3" || "${core_install_type}" = "1" ]]; then
            echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-origin ==========================="
            defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${current_host}:${port}" ${add}

            echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-direct ==========================="
            defaultBase64Code vlesstcp ${tcpDirectEmail} "${tcpIDirect}" "${current_host}:${port}" ${add}

        elif [[ "${core_install_type}" = "2" ]]; then
#            host=`echo ${tcp}|jq .streamSettings.tlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
            echoContent skyBlue "\n============================ VLESS TCP TLS ======================================="
            defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${current_host}:${port}" ${add}
        fi

        if [[ -n "${current_custom_install_type}" ]]; then
            local coreType=
            if [[ "${core_install_type}" = "1" ]]; then
                coreType=xray
            elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
                coreType=v2ray
            fi

            if [[ -n `echo ${current_custom_install_type}|grep 1` ]]; then
                # VLESS ws
                local vlessWS=`cat /etc/v2ray-agent/${coreType}/conf/03_VLESS_WS_inbounds.json|jq .inbounds[0]`
                local vlessWSID=`echo ${vlessWS}|jq .settings.clients[0].id`
                local vlessWSAdd=`echo ${tcp}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
                local vlessWSEmail="`echo ${vlessWS}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
                local vlessWSPath=`echo ${vlessWS}|jq .streamSettings.wsSettings.path`

                echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================"
                defaultBase64Code vlessws ${vlessWSEmail} "${vlessWSID}" "${current_host}:${port}" "${vlessWSPath}" ${CDNADD}
            fi
            if [[ -n `echo ${current_custom_install_type}|grep 2` ]]; then

                local vmessTCP=`cat /etc/v2ray-agent/${coreType}/conf/04_VMess_TCP_inbounds.json|jq .inbounds[0]`
                local vmessTCPID=`echo ${vmessTCP}|jq .settings.clients[0].id`
                local vmessTCPEmail="`echo ${vmessTCP}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
                local vmessTCPath=`echo ${vmessTCP}|jq .streamSettings.tcpSettings.header.request.path[0]`

                echoContent skyBlue "\n================================= VMess TCP TLS  ================================="
                defaultBase64Code vmesstcp ${vmessTCPEmail} "${vmessTCPID}" "${current_host}:${port}" "${vmessTCPath}" "${current_host}"
            fi
            if [[ -n `echo ${current_custom_install_type}|grep 3` ]]; then

                local ws=`cat /etc/v2ray-agent/${coreType}/conf/05_VMess_WS_inbounds.json|jq .inbounds[0]`
                local wsID=`echo ${ws}|jq .settings.clients[0].id`
                local wsEmail="`echo ${ws}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
                local wsPath=`echo ${ws}|jq .streamSettings.wsSettings.path`

                echoContent skyBlue "\n================================ VMess WS TLS CDN ================================"
                defaultBase64Code vmessws ${wsEmail} "${wsID}" "${current_host}:${port}" "${wsPath}" ${CDNADD}
            fi
        fi
    fi

    if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/trojan/" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
        showStatus=true
        local trojanUUID=`cat /etc/v2ray-agent/trojan/config_full.json |jq .password[0]|awk -F '["]' '{print $2}'`
        local trojanGoPath=`cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.path|awk -F '["]' '{print $2}'`
        local trojanGoAdd=`cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.add|awk -F '["]' '{print $2}'`
        current_host=${trojanGoAdd}
        echoContent skyBlue "\n==================================  Trojan TLS  =================================="
        defaultBase64Code trojan trojan ${trojanUUID} ${current_host}

        echoContent skyBlue "\n================================  Trojan WS TLS   ================================"
        echoContent skyBlue "current host : ${trojanGoAdd}"
        # if [[ -z ${trojanGoAdd} ]]
        # then
            # trojanGoAdd=${current_host}
        # fi
        defaultBase64Code trojangows trojan ${trojanUUID} ${current_host} ${trojanGoPath} ${trojanGoAdd}
    fi
    if [[ -z ${showStatus} ]]; then
        echoContent red " ---> 未安装"
    fi
}

# 卸载脚本
unInstall(){
    read -p "是否确认卸载安装内容？[y/n]:" unInstallStatus
    if [[ "${unInstallStatus}" != "y" ]]; then
        echoContent green " ---> 放弃卸载"
        menu
        exit;
    fi
    
    if [[ ! -d /etc/v2ray-agent ]]; then
        echoContent red " ---> 未检测到安装内容，无须卸载"
        exit;
    fi

    handleNginx stop
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]; then
        echoContent green " ---> 停止Nginx成功"
    fi

    handleV2Ray stop
    handleTrojanGo stop
    rm -rf /etc/systemd/system/v2ray.service
    echoContent green " ---> 删除V2Ray开机自启完成"
    rm -rf /etc/systemd/system/trojan-go.service
    echoContent green " ---> 删除Trojan-Go开机自启完成"
    
    rm -rf /tmp/v2ray-agent-tls/*
    if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n `find /etc/v2ray-agent/tls/ -name "*.key"` ]] && [[ -n `find /etc/v2ray-agent/tls/ -name "*.crt"` ]]; then
        mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
        if [[ -n `find /tmp/v2ray-agent-tls -name '*.key'` ]]; then
            echoContent yellow " ---> 备份证书成功，请注意留存。[/tmp/v2ray-agent-tls]"
        fi
    fi
    
    sudo chattr -i /etc/v2ray-agent/v2ray/v2ray_access.log
    sudo chattr -i /etc/v2ray-agent/v2ray/v2ray_error.log
    rm -rf /etc/v2ray-agent
    rm -rf /etc/nginx/conf.d/alone.conf
    rm -rf /usr/bin/vasma
    rm -rf /usr/sbin/vasma
    echoContent green " ---> 卸载快捷方式完成"
    echoContent green " ---> 卸载v2ray-agent完成"
}

# 修改V2Ray CDN节点
updateV2RayCDN(){
    echoContent skyBlue "\n进度 $1/${total_progress} : 修改CDN节点"
    if [[ -n "${v2ray_agent_install_type}" ]]; then
        local configPath=
        if [[ "${core_install_type}" = "1" ]]; then
            configPath=${xray_core_config_file_path}
        elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
            configPath=${v2ray_core_config_file_path}
        fi

        local add=`cat ${configPath}|grep -v grep|grep add`
        if [[ -n ${add} ]]; then
            echoContent red "=============================================================="
            echoContent yellow "1.CNAME www.digitalocean.com"
            echoContent yellow "2.CNAME amp.cloudflare.com"
            echoContent yellow "3.CNAME domain08.qiu4.ml"
            echoContent yellow "4.手动输入"
            echoContent red "=============================================================="
            read -p "请选择:" selectCDNType
            case ${selectCDNType} in
            1)
                setDomain="www.digitalocean.com"
            ;;
            2)
                setDomain="amp.cloudflare.com"
            ;;
            3)
                setDomain="blog.hostmonit.com"
            ;;
            4)
                read -p "请输入想要自定义CDN IP或者域名:" setDomain
            ;;
            esac
            if [[ -n ${setDomain} ]]; then
                # v2ray
                add=`echo ${add}|awk -F '["]' '{print $4}'`
                if [[ -n ${add} ]]; then
                    sed -i "s/\"${add}\"/\"${setDomain}\"/g"  `grep "${add}" -rl ${configPath}`
                fi

                if [[ `cat ${configPath}|grep -v grep|grep add|awk -F '["]' '{print $4}'` = ${setDomain} ]]; then
                    echoContent green " ---> V2Ray CDN修改成功"
                    if [[ "${core_install_type}" = "1" ]]; then
                        handleXray stop
                        handleXray start
                    elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
                        handleV2Ray stop
                        handleV2Ray start
                    fi

                else
                    echoContent red " ---> 修改V2Ray CDN失败"
                fi

                # trojan
                if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
                    add=`cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.add|awk -F '["]' '{print $2}'`
                    if [[ -n ${add} ]]; then
                        sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl /etc/v2ray-agent/trojan/config_full.json`
                    fi
                fi

                if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]] && [[ `cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.add|awk -F '["]' '{print $2}'` = ${setDomain} ]]; then
                    echoContent green "\n ---> Trojan CDN修改成功"
                    handleTrojanGo stop
                    handleTrojanGo start
                elif [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
                    echoContent red " ---> 修改Trojan CDN失败"
                fi
            fi
        else
            echoContent red " ---> 未安装可用类型"
        fi
    else
        echoContent red " ---> 未安装"
    fi
    menu
}

# 重置UUID
resetUUID(){
    echoContent skyBlue "\n进度 $1/${total_progress} : 重置UUID"
    local reset_status=false
    if [[ "${core_install_type}" = "1" ]]; then
        new_uuid=`/etc/v2ray-agent/xray/xray uuid`
        new_direct_uuid=`/etc/v2ray-agent/xray/xray uuid`
    elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
        new_uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        new_direct_uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi

    if [[ -n "${v2ray_agent_install_type}" ]] && [[ -z "${current_custom_install_type}" ]]; then

        if [[ -n "${current_uuid}" ]]; then
            read -p "是否自定义uuid？[y/n]:" custom_uuid_status
            if [[ "${custom_uuid_status}" = "y" ]]; then
                echo
                read -p "请输入合法的uuid:" new_uuid
                echo
            fi
            if [[ "${core_install_type}" = "1" ]]; then
                sed -i "s/${current_uuid}/${new_uuid}/g"  `grep "${current_uuid}" -rl /etc/v2ray-agent/xray/config_full.json`
            elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
                sed -i "s/${current_uuid}/${new_uuid}/g"  `grep "${current_uuid}" -rl /etc/v2ray-agent/v2ray/config_full.json`
            fi
        fi

        if [[  -n "${current_uuid_direct}"  ]]; then
            echoContent skyBlue "-------------------------------------------------------------"
            read -p "是否自定义 XTLS-direct-uuid？[y/n]:" custom_uuid_status
            if [[ "${custom_uuid_status}" = "y" ]]; then
                echo
                read -p "请输入合法的uuid:" new_direct_uuid
                echo
                if [[ "${new_uuid}" = "${new_direct_uuid}" ]]; then
                    echoContent red " ---> 两个uuid不可重复"
                    resetUUID 1
                    exit 0;
                fi
            fi
            if [[ "${core_install_type}" = "1" ]]; then
                sed -i "s/${current_uuid_direct}/${new_direct_uuid}/g"  `grep "${current_uuid_direct}" -rl /etc/v2ray-agent/xray/config_full.json`
            elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
                sed -i "s/${current_uuid_direct}/${new_direct_uuid}/g"  `grep "${current_uuid_direct}" -rl /etc/v2ray-agent/v2ray/config_full.json`
            fi

        fi
        if [[ "${core_install_type}" = "1" ]]; then
            echoContent green " ---> Xray UUID重置完毕"
            handleXray stop
            handleXray start
        elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
            echoContent green " ---> V2Ray UUID重置完毕"
            handleV2Ray stop
            handleV2Ray start
        fi

        reset_status=true

    elif [[ -n "${v2ray_agent_install_type}" ]] && [[ -n "${current_custom_install_type}" ]]; then
        read -p "是否自定义uuid？[y/n]:" custom_uuid_status
        if [[ "${custom_uuid_status}" = "y" ]]; then
            echo
            read -p "请输入合法的uuid:" new_uuid
            echo
        fi
        local config_path_type=
        if [[ "${core_install_type}" = "1" ]]; then
            config_path_type=xray
        elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
            config_path_type=v2ray
        fi

        uuid_count=0
        ls /etc/v2ray-agent/${config_path_type}/conf|grep inbounds|while read row
        do
            cat /etc/v2ray-agent/${config_path_type}/conf/${row}|jq .inbounds|jq -c '.[].settings.clients'|jq -c '.[].id'|while read row2
            do
                if [[ "${row}" = "02_VLESS_TCP_inbounds.json" ]]; then
                    if [[ "${uuid_count}" != "1" ]]; then
                        old_uuid=`echo ${row2}|awk -F "[\"]" '{print $2}'`
                        sed -i "s/${old_uuid}/${new_uuid}/g"  `grep "${old_uuid}" -rl /etc/v2ray-agent/${config_path_type}/conf/${row}`
                    fi
                    if [[ "${row}" = "02_VLESS_TCP_inbounds.json" ]]; then
                        uuid_count=1
                    fi
                else
                    old_uuid=`echo ${row2}|awk -F "[\"]" '{print $2}'`
                    sed -i "s/${old_uuid}/${new_uuid}/g"  `grep "${old_uuid}" -rl /etc/v2ray-agent/${config_path_type}/conf/${row}`
                fi
            done
        done

        if [[ -n "${current_uuid_direct}" ]]; then
            echoContent skyBlue "-------------------------------------------------------------"
            read -p "是否自定义xtls-direct-uuid？[y/n]:" custom_uuid_status
            if [[ "${custom_uuid_status}" = "y" ]]; then
                echo
                read -p "请输入合法的uuid:" new_direct_uuid
                echo
                if [[ "${new_uuid}" = "${new_direct_uuid}" ]]; then
                    echoContent red " ---> 两个uuid不可重复"
                    resetUUID 1
                    exit 0;
                fi
            fi
            sed -i "s/${current_uuid_direct}/${new_direct_uuid}/g"  `grep "${current_uuid_direct}" -rl /etc/v2ray-agent/${config_path_type}/conf/02_VLESS_TCP_inbounds.json`
        fi

        if [[ "${core_install_type}" = "1" ]]; then
            echoContent green " ---> Xray UUID重置完毕"
            handleXray stop
            handleXray start
        elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
            echoContent green " ---> V2Ray UUID重置完毕"
            handleV2Ray stop
            handleV2Ray start
        fi
        reset_status=true
    else
        echoContent red " ---> 未使用脚本安装V2Ray"
        menu
        exit 0;
    fi

    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
        cat /etc/v2ray-agent/trojan/config_full.json|jq .password|jq -c '.[]'|while read row
        do
            old_uuid=`echo ${row}|awk -F "[\"]" '{print $2}'`
            sed -i "s/${old_uuid}/${new_uuid}/g"  `grep "${old_uuid}" -rl /etc/v2ray-agent/trojan/config_full.json`
        done
        echoContent green " ---> Trojan UUID重置完毕"
        handleTrojanGo stop
        handleTrojanGo start
        reset_status=true
    else
        echoContent red " ---> 未使用脚本安装Trojan"
    fi
    if [[ "${reset_status}" = "true" ]]; then
        readInstallType
        readConfigHostPathUUID
        readCustomInstallType
        showAccounts 1
    fi
}

# 更新脚本
updateV2RayAgent(){
    echoContent skyBlue "\n进度  $1/${total_progress} : 更新v2ray-agent脚本"
    wget -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/keepsmile88/v2ray-agent/master/install.sh" && chmod 700 /etc/v2ray-agent/install.sh && vasma
}



# 安装BBR
bbrInstall(){
    echoContent red "\n=============================================================="
    echoContent green "BBR脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed]，请熟知"
    echoContent red "   1.安装【推荐原版BBR+FQ】"
    echoContent red "   2.回退主目录"
    echoContent red "=============================================================="
    read -p "请选择：" installBBRStatus
    if [[ "${installBBRStatus}" = "1" ]]; then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    else
        menu
    fi
}

# 查看、检查日志
checkLog(){
    echoContent skyBlue "\n功能 $1/${total_progress} : 查看日志"
    echoContent red "\n=============================================================="
    local coreType=
    if [[ "${core_install_type}" = "1" ]]; then
        coreType=xray/xray

    elif [[ "${core_install_type}" = "2" || "${core_install_type}" = "3" ]]; then
        coreType=v2ray/v2ray
    else
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi


    echoContent skyBlue "-------------------------V2Ray/Xray--------------------------------"
    echoContent yellow "1.查看info日志"
    echoContent yellow "2.监听info日志"
    echoContent yellow "3.查看error日志"
    echoContent yellow "4.监听error日志"
    echoContent yellow "5.清空V2Ray日志"
    echoContent skyBlue "-----------------------Trojan-Go------------------------------"
    echoContent yellow "6.查看Trojan-Go日志"
    echoContent yellow "7.监听Trojan-GO日志"
    echoContent yellow "8.清空Trojan-GO日志"
    echoContent skyBlue "-------------------------Nginx--------------------------------"
    echoContent yellow "9.查看Nginx日志"
    echoContent yellow "10.清空Nginx日志"
    echoContent red "=============================================================="


    read -p "请选择：" selectLogType
    case ${selectLogType} in
        1)
            cat /etc/v2ray-agent/${coreType}_access.log
        ;;
        2)
            tail -f /etc/v2ray-agent/${coreType}_access.log
        ;;
        3)
            cat /etc/v2ray-agent/${coreType}_error.log
        ;;
        4)
            tail -f /etc/v2ray-agent/${coreType}_error.log
        ;;
        5)
            echo '' > /etc/v2ray-agent/${coreType}_access.log
            echo '' > /etc/v2ray-agent/${coreType}_error.log
            echoContent green " ---> 清空完毕"
        ;;
        6)
            cat /etc/v2ray-agent/trojan/trojan.log
        ;;
        7)
            tail -f /etc/v2ray-agent/trojan/trojan.log
        ;;
        8)
            echo '' > /etc/v2ray-agent/trojan/trojan.log
            echoContent green " ---> 清空完毕"
        ;;
        9)
            cat /var/log/nginx/access.log
        ;;
        10)
            echo '' > /var/log/nginx/access.log
        ;;
    esac
    sleep 1
    menu
}
# 脚本快捷方式
aliasInstall(){
    if [[ -f "/root/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && grep <"$HOME/install.sh" -q "\- 更新于20"; then
        mv /root/install.sh /etc/v2ray-agent/install.sh
        if [[ -d "/usr/bin/" ]] && [[ ! -f "/usr/bin/vasma" ]]; then
            ln -s /etc/v2ray-agent/install.sh /usr/bin/vasma
            chmod 700 /usr/bin/vasma
            rm -rf /root/install.sh
        elif [[ -d "/usr/sbin" ]] && [[ ! -f "/usr/sbin/vasma" ]]; then
            ln -s /etc/v2ray-agent/install.sh /usr/sbin/vasma
            chmod 700 /usr/sbin/vasma
            rm -rf /root/install.sh
        fi
        echoContent green "快捷方式创建成功，可执行[vasma]重新打开脚本"
    fi
}

# v2ray-core个性化安装
customV2RayInstall(){
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
    if [[ "${select_core_type}" = "2" ]]; then
        echoContent yellow "0.VLESS+TLS+TCP"
    else
        echoContent yellow "0.VLESS+TLS/XTLS+TCP"
    fi

    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.VMess+TLS+TCP"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan、Trojan+WS[CDN]"
    read -p "请选择[多选]，[例如:123]:" select_custom_install_type
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${select_custom_install_type} ]]; then
        echoContent red " ---> 不可为空"
        customV2RayInstall
    elif [[ "${select_custom_install_type}" =~ ^[0-4]+$ ]]; then
        cleanUp xray_clean
        total_progress=17
        installTools 1
        # 申请tls
        initTLSNginxConfig 2
        installTLS 3
        handleNginx stop
        initNginxConfig 4
        # 随机path
        if [[ -n `echo ${select_custom_install_type}|grep 1` ]] || [[ -n `echo ${select_custom_install_type}|grep 3` ]] || [[ -n `echo ${select_custom_install_type}|grep 4` ]]; then
            randomPathFunction 5
            customCDNIP 6
        fi
        nginxBlog 7
        handleNginx start

        # 安装V2Ray
        installV2Ray 8
        installV2RayService 9
        initV2RayConfig custom 10
        cleanUp xray_del
        if [[ -n `echo ${select_custom_install_type}|grep 4` ]]; then
            installTrojanGo 11
            installTrojanService 12
            initTrojanGoConfig 13
            handleTrojanGo stop
            handleTrojanGo start
        else
            # 这里需要删除trojan的服务
            handleTrojanGo stop
            rm -rf /etc/v2ray-agent/trojan/*
            rm -rf /etc/systemd/system/trojan-go.service
        fi
        installCronTLS 14
        handleV2Ray stop
        handleV2Ray start
        # 生成账号
        checkGFWStatue 15
        showAccounts 16
    else
        echoContent red " ---> 输入不合法"
        customV2RayInstall
    fi
}

# Xray-core个性化安装
customXrayInstall(){
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
    echoContent yellow "0.VLESS+TLS/XTLS+TCP"
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.VMess+TLS+TCP"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan、Trojan+WS[CDN]"
    read -p "请选择[多选]，[例如:123]:" select_custom_install_type
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${select_custom_install_type} ]]; then
        echoContent red " ---> 不可为空"
        customXrayInstall
    elif [[ "${select_custom_install_type}" =~ ^[0-4]+$ ]]; then
        cleanUp v2ray_clean
        total_progress=17
        installTools 1
        # 申请tls
        initTLSNginxConfig 2
        installTLS 3
        handleNginx stop
        initNginxConfig 4
        # 随机path
        if [[ -n `echo ${select_custom_install_type}|grep 1` ]] || [[ -n `echo ${select_custom_install_type}|grep 3` ]] || [[ -n `echo ${select_custom_install_type}|grep 4` ]]; then
            randomPathFunction 5
            customCDNIP 6
        fi
        nginxBlog 7
        handleNginx start

        # 安装V2Ray
        installXray 8
        installXrayService 9
        initXrayConfig custom 10
        cleanUp v2ray_del
        if [[ -n `echo ${select_custom_install_type}|grep 4` ]]; then
            installTrojanGo 11
            installTrojanService 12
            initTrojanGoConfig 13
            handleTrojanGo stop
            handleTrojanGo start
        else
            # 这里需要删除trojan的服务
            handleTrojanGo stop
            rm -rf /etc/v2ray-agent/trojan/*
            rm -rf /etc/systemd/system/trojan-go.service
        fi
        installCronTLS 14
        handleXray stop
        handleXray start
        # 生成账号
        checkGFWStatue 15
        showAccounts 16
    else
        echoContent red " ---> 输入不合法"
        customXrayInstall
    fi
}
# 选择核心安装---v2ray-core、xray-core、锁定版本的v2ray-core[xtls]
selectCoreInstall(){
    echoContent skyBlue "\n功能 1/${total_progress} : 选择核心安装"
    echoContent red "\n=============================================================="
    echoContent yellow "1.Xray-core"
    echoContent yellow "2.v2ray-core"
    # echoContent yellow "3.v2ray-core[XTLS]"
    echoContent red "=============================================================="
    read -p "请选择：" select_core_type
    case ${select_core_type} in
        1)

           if [[ "${selectInstallType}" = "2" ]]; then
                customXrayInstall
            else
                xrayCoreInstall
            fi
        ;;
        2)
            v2ray_core_version=
            if [[ "${selectInstallType}" = "2" ]]; then
                customV2RayInstall
            else
                v2rayCoreInstall
            fi
        ;;
        3)
            v2ray_core_version=v4.32.1
            if [[ "${selectInstallType}" = "2" ]]; then
                customV2RayInstall
            else
                v2rayCoreInstall
            fi
        ;;
        *)
            echoContent red ' ---> 选择错误，重新选择'
            selectCoreInstall
        ;;
    esac
}


# v2ray-core 安装
v2rayCoreInstall(){
    cleanUp xray_clean
    select_custom_install_type=
    total_progress=17
    installTools 2
    # 申请tls
    initTLSNginxConfig 3
    
    handleV2Ray stop
    handleNginx start
    
    installTLS 4
    handleNginx stop
    initNginxConfig 5
    randomPathFunction 6
    # 安装V2Ray
    installV2Ray 7
    installV2RayService 8
    installTrojanGo 9
    installTrojanService 10
    customCDNIP 11
    initV2RayConfig all 12
    cleanUp xray_del
    initTrojanGoConfig 13
    installCronTLS 14
    nginxBlog 15
    handleV2Ray stop
    sleep 2
    handleV2Ray start
    handleNginx start
    handleTrojanGo stop
    sleep 1
    handleTrojanGo start
    # 生成账号
    checkGFWStatue 16
    showAccounts 17
}

# xray-core 安装
xrayCoreInstall(){
    cleanUp v2ray_clean
    select_custom_install_type=

    total_progress=17
    installTools 2
    # 申请tls
    initTLSNginxConfig 3
    installTLS 4
    handleNginx stop
    initNginxConfig 5
    randomPathFunction 6
    # 安装Xray
    handleV2Ray stop
    installXray 7
    installXrayService 8
    installTrojanGo 9
    installTrojanService 10
    customCDNIP 11
    initXrayConfig all 12
    cleanUp v2ray_del
    initTrojanGoConfig 13
#    installCronTLS 14
    nginxBlog 15
    handleXray stop
    sleep 2
    handleXray start

    handleNginx start
    handleTrojanGo stop
    sleep 1
    handleTrojanGo start
    # 生成账号
    checkGFWStatue 16
    showAccounts 17
}

# 核心管理
coreVersionManageMenu(){

    if [[ -z "${core_install_type}" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    if [[ "${core_install_type}" = "1" ]]; then
        xrayVersionManageMenu 1
    elif [[ "${core_install_type}" = "2" ]]; then
        v2ray_core_version=
        v2rayVersionManageMenu 1

    elif [[ "${core_install_type}" = "3" ]]; then
        v2ray_core_version=v4.32.1
        v2rayVersionManageMenu 1
    fi
}

# 更新伪装站
updateNginxBlog() {
    local nginx_static_path=/usr/share/nginx/html/
    echoContent skyBlue "\n进度 $1/${total_progress} : 更换伪装站点"
    echoContent red "=============================================================="
    echoContent yellow "# 如需自定义，请手动复制模版文件到 ${nginx_static_path} \n"
    echoContent yellow "1.新手引导"
    echoContent yellow "2.游戏网站"
    echoContent yellow "3.个人博客01"
    echoContent yellow "4.企业站"
    echoContent yellow "5.解锁加密的音乐文件模版[https://github.com/ix64/unlock-music]"
    echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
    echoContent yellow "7.企业站02"
    echoContent yellow "8.个人博客02"
    echoContent yellow "9.404自动跳转baidu"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectInstallNginxBlogType

    # if [[ "${selectInstallNginxBlogType}" == "10" ]]; then
        # echoContent red "\n=============================================================="
        # echoContent yellow "重定向的优先级更高，配置302之后如果更改伪装站点，根路由下伪装站点将不起作用"
        # echoContent yellow "如想要伪装站点实现作用需删除302重定向配置\n"
        # echoContent yellow "1.添加"
        # echoContent yellow "2.删除"
        # echoContent red "=============================================================="
        # read -r -p "请选择:" redirectStatus

        # if [[ "${redirectStatus}" == "1" ]]; then
            # backupNginxConfig backup
            # read -r -p "请输入要重定向的域名,例如 https://www.baidu.com:" redirectDomain
            # removeNginx302
            # addNginx302 "${redirectDomain}"
            # handleNginx stop
            # handleNginx start
            # if [[ -z $(pgrep -f "nginx") ]]; then
                # backupNginxConfig restoreBackup
                # handleNginx start
                # exit 0
            # fi
            # checkNginx302
            # exit 0
        # fi
        # if [[ "${redirectStatus}" == "2" ]]; then
            # removeNginx302
            # echoContent green " ---> 移除302重定向成功"
            # exit 0
        # fi
    # fi
    if [[ "${selectInstallNginxBlogType}" =~ ^[1-9]$ ]]; then
        rm -rf "${nginx_static_path}"

        wget -q -P "${nginx_static_path}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip" >/dev/null

        unzip -o "${nginx_static_path}html${selectInstallNginxBlogType}.zip" -d "${nginx_static_path}" >/dev/null
        rm -f "${nginx_static_path}html${selectInstallNginxBlogType}.zip*"
        echoContent green " ---> 更换伪站成功"
    else
        echoContent red " ---> 选择错误，请重新选择"
        updateNginxBlog
    fi
}

# 主菜单
menu(){
    cd
    echoContent red "\n=============================================================="
    echoContent green "当前版本：v2.1.18.4 - 更新于2023/10/01"
    echoContent green "原作者：Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "描述：七合一共存脚本"
    echoContent red "=============================================================="
    echoContent yellow "1.安装"
    echoContent yellow "2.任意组合安装"
    echoContent skyBlue "-------------------------工具管理-----------------------------"
    echoContent yellow "3.查看账号"
    echoContent yellow "4.自动排错 [已废弃]"
    echoContent yellow "5.更新证书"
    echoContent yellow "6.更换CDN节点"
    echoContent yellow "7.重置uuid"
    echoContent yellow "8.更换伪装站"
    echoContent skyBlue "-------------------------版本管理-----------------------------"
    echoContent yellow "9.core版本管理"
    echoContent yellow "10.升级Trojan-Go"
    echoContent yellow "11.升级脚本"
    echoContent yellow "12.安装BBR"
    echoContent skyBlue "-------------------------脚本管理-----------------------------"
    echoContent yellow "13.查看日志"
    echoContent yellow "14.卸载脚本"
    echoContent red "=============================================================="
    mkdirTools
    aliasInstall
    read -p "请选择:" selectInstallType
     case ${selectInstallType} in
        1)
            selectCoreInstall
        ;;
        2)
#            echoContent red " ---> 暂不开放"
#            exit 0;
            selectCoreInstall
        ;;
        3)
            showAccounts 1
        ;;
        5)
            renewalTLS 1
        ;;
        6)
            updateV2RayCDN 1
        ;;
        7)
            resetUUID 1
        ;;
        8)
            updateNginxBlog 1
        ;;
        9)
            coreVersionManageMenu 1
        ;;
        10)
            updateTrojanGo 1
        ;;
        11)
            updateV2RayAgent 1
        ;;
        12)
            bbrInstall
        ;;
        13)
            checkLog 1
        ;;
        14)
            unInstall 1
        ;;
    esac
}
cronRenewTLS
menu
