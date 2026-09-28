#!/usr/bin/env bash
# Container entry point (CMD). Adapted from runpod/containers
# container-template/start.sh (MIT, see README).
# No `set -e`: if one step fails, the pod should stay up so you can SSH or
# Jupyter in and look at the logs.
set -uo pipefail

mkdir -p /workspace/logs

# --- 1. Login for the web UIs (nginx basic auth) -----------------------------
setup_login() {
    local user="${WEBUI_USERNAME:-admin}"
    local pass_file=/workspace/.webui_password
    local pass source

    if [[ -n ${WEBUI_PASSWORD:-} ]]; then
        pass="$WEBUI_PASSWORD"
        source="from WEBUI_PASSWORD"
    elif [[ -s $pass_file ]]; then
        pass="$(head -n 1 "$pass_file")"
        source="saved in $pass_file"
    else
        pass="$(openssl rand -base64 18)"
        (umask 077 && printf '%s\n' "$pass" > "$pass_file")
        source="generated: $pass (saved in $pass_file)"
    fi

    htpasswd -bcB /etc/nginx/.htpasswd "$user" "$pass" 2>/dev/null
    chown root:www-data /etc/nginx/.htpasswd
    chmod 640 /etc/nginx/.htpasswd

    echo "LOGIN: username: $user"
    echo "LOGIN: password $source"
}

# --- 2. nginx ----------------------------------------------------------------
start_nginx() {
    echo "NGINX: starting"
    nginx
}

# --- 3. SSH, only with PUBLIC_KEY; never a password --------------------------
setup_ssh() {
    if [[ -z ${PUBLIC_KEY:-} ]]; then
        echo "SSH: PUBLIC_KEY is not set, skipping"
        return
    fi
    echo "SSH: starting"
    mkdir -p ~/.ssh
    printf '%s\n' "$PUBLIC_KEY" > ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    # The image ships without host keys, so each pod gets its own.
    ssh-keygen -A
    mkdir -p /run/sshd
    /usr/sbin/sshd
}

# --- 4. Jupyter, only with JUPYTER_PASSWORD ----------------------------------
start_jupyter() {
    if [[ -z ${JUPYTER_PASSWORD:-} ]]; then
        echo "JUPYTER: JUPYTER_PASSWORD is not set, skipping. Set it in the template,"
        echo "JUPYTER: e.g. {{ RUNPOD_SECRET_jupyter_password }}."
        return
    fi
    echo "JUPYTER: starting on port 8888"
    # JUPYTER_TOKEN is read by Jupyter itself, which keeps the password out
    # of the process list.
    JUPYTER_TOKEN="$JUPYTER_PASSWORD" nohup /opt/venvs/jupyter/bin/jupyter lab \
        --allow-root \
        --no-browser \
        --ip=0.0.0.0 \
        --port=8888 \
        --ServerApp.root_dir=/workspace \
        --ServerApp.allow_origin='*' \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --FileContentsManager.delete_to_trash=False \
        > /workspace/logs/jupyter.log 2>&1 &
}

# --- 5. Environment for SSH and Jupyter terminals ----------------------------
export_env_vars() {
    local name
    while IFS= read -r name; do
        case "$name" in
            PUBLIC_KEY | WEBUI_PASSWORD | JUPYTER_PASSWORD | PWD | OLDPWD | SHLVL | _) continue ;;
        esac
        [[ $name =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
        printf 'export %s=%q\n' "$name" "${!name}"
    done < <(compgen -e) > /etc/rp_environment

    if ! grep -qs 'source /etc/rp_environment' ~/.bashrc; then
        echo 'source /etc/rp_environment' >> ~/.bashrc
    fi
}

setup_login
start_nginx
setup_ssh
start_jupyter
export_env_vars

# --- 6. Sync to /workspace and start the apps --------------------------------
echo "Running /pre_start.sh..."
/pre_start.sh || echo "ERROR: /pre_start.sh failed, see the messages above."

echo "Container is READY!"
sleep infinity
