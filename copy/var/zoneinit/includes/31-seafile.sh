HOST=$(hostname)
IP_ADDR=$(ipadm show-addr -p -o ADDR net0/ | sed 's:/[^/]*$::')
SEAFILE_HOME="/home/haiwen/seafile"
SEAFILE_CONFDIR="${SEAFILE_HOME}/conf"
SEAFILE_DATADIR="${SEAFILE_HOME}/seafile-data"
CCNET_HOME="${SEAFILE_HOME}/ccnet"
SEAHUB_HOME="${SEAFILE_HOME}/seafile-server/seahub"
RUNTIMEDIR="${SEAFILE_HOME}/seafile-server/runtime"
CCNET_PORT=10001
SEAFILE_PORT=12001
FILESERVER_PORT=8082

sudo -u haiwen -H mkdir -p ${SEAFILE_CONFDIR}

sudo -u haiwen -H ccnet-init -F"${SEAFILE_CONFDIR}" --config-dir="${CCNET_HOME}" --host="${IP_ADDR}" --name="${HOST}" --port=${CCNET_PORT}

sudo -u haiwen -H seaf-server-init --central-config-dir="${SEAFILE_CONFDIR}" --seafile-dir="${SEAFILE_DATADIR}" --port=${SEAFILE_PORT} --fileserver-port=${FILESERVER_PORT}

PYTHON=python2.7
dest_settings_py=/home/haiwen/seafile/conf/seahub_settings.py
seahub_secret_keygen=/home/haiwen/seafile/seafile-server/seahub/tools/secret_key_generator.py

if [[ ! -f ${dest_settings_py} ]]; then
	key=$($PYTHON "${seahub_secret_keygen}")
	sudo -u haiwen -H echo "SECRET_KEY = '${key}'" >> "${dest_settings_py}"
fi

sudo -u haiwen -H echo "${SEAFILE_DATADIR}" > "${CCNET_HOME}/seafile.ini"

cd ${SEAHUB_HOME}
sudo -u haiwen -H PYTHONPATH="${PYTHONPATH}:${SEAHUB_HOME}/thirdpart" CCNET_CONF_DIR="${SEAFILE_CONFDIR}" SEAFILE_CONF_DIR="${SEAFILE_CONFDIR}" SEAFILE_CENTRAL_CONF_DIR="${SEAFILE_CONFDIR}" $PYTHON manage.py syncdb
cd -

sudo -u haiwen -H mkdir -p ${RUNTIMEDIR}
sudo -u haiwen -H mkdir -p ${SEAFILE_DATADIR}/library-template

echo "
import os
daemon = True
workers = 3

# Logging
runtime_dir = os.path.dirname(__file__)
pidfile = os.path.join(runtime_dir, 'seahub.pid')
errorlog = os.path.join(runtime_dir, 'error.log')
accesslog = os.path.join(runtime_dir, 'access.log')

" >> ${RUNTIMEDIR}/seahub.conf

gsed -i \
-e "s/%HOSTNAME%/${HOST}/" \
/opt/local/etc/nginx/nginx.conf

# TODO ugly hack for seafile-controller returning root directory for pid files directory
# glib g_path_get_dirname bug with illumos?
mkdir /pids
chown haiwen:other /pids
svcadm enable seafile
svcadm enable nginx