import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const isInstalled = (pkgName) => 
execSync(`dpkg-query -W -f='\${Status}' ${pkgName} 2>/dev/null`).toString() === "install ok installed"

const defaultConfig = `PHP_VER=$PHP_VER
STORAGE_USER=$STORAGE_USER
STORAGE_ROOT=$STORAGE_ROOT
PRIMARY_HOSTNAME=$PRIMARY_HOSTNAME
PUBLIC_IP=$PUBLIC_IP
PUBLIC_IPV6=$PUBLIC_IPV6
PRIVATE_IP=$PRIVATE_IP
PRIVATE_IPV6=$PRIVATE_IPV6
MTA_STS_MODE=${DEFAULT_MTA_STS_MODE||"-enforce"}
`

const toIni = (obj) => Object.entries(obj).map(ent=>ent.join("=")).join("\n");
const fromIni = (str) => Object.fromEntries(str.split("\n").map((line)=>line.split("=")));

const steps = {
    "read-config": ()=> {
        let config = {};
        try {
            config = fromIni(
                readFileSync("/etc/dspeed-hosting.conf")
            );
        }catch(e){};
        return config;
        
    },
    "bootstrap": () => {
        // Like: bootstrap.sh 
        // It pulls the git repo and checks out the correct version
    },
    "preflight": () => {
        // checks if the host system is running a compatible os distribution
        // mainly needed if bootstrap did not error already
    },
    "start": () => {
        // Like: start.sh 
        // It setups the environment. based on the current version
        // Asks Questions Interactive
        // Runs migrate if needed.
        // Excutes tools dns_update and web_update
    },
    "apt-install": (packages=[""]) => {
        // This one-liner returns 1 (installed) or 0 (not installed) for the 'nano' package...
        // $(dpkg-query -W -f='${Status}' nano 2>/dev/null | grep -c "ok installed")

        // below example runs if exit code is 0 so not installed
        
        // if [ $(dpkg-query -W -f='${Status}' php${PHP_VER}-fpm 2>/dev/null | grep -c "ok installed") -eq 0 ];
        // then
        //     apt_install curl php${PHP_VER} php${PHP_VER}-fpm \
        //         php${PHP_VER}-cli php${PHP_VER}-sqlite3 php${PHP_VER}-gd php${PHP_VER}-imap php${PHP_VER}-curl \
        //         php${PHP_VER}-dev php${PHP_VER}-gd php${PHP_VER}-xml php${PHP_VER}-mbstring php${PHP_VER}-zip php${PHP_VER}-apcu \
        //         php${PHP_VER}-intl php${PHP_VER}-imagick php${PHP_VER}-gmp php${PHP_VER}-bcmath
        // fi
        
        // isInstalled("php${PHP_VER}-fpm")
        
    },
    "nextcloud-contacts-calender": () => {

    }
}