# 📡 sctunnel_client

> Linux (v2) — comandos diretos abaixo. Windows (v1) continua mais embaixo neste README.

## 📥 Instalar

```bash
curl -fsSL https://sctunnel1.seucondominio.com.br/install.sh | sudo bash -s -- <cliente_id>
```

Exemplo: `curl -fsSL https://sctunnel1.seucondominio.com.br/install.sh | sudo bash -s -- 51`

Instala em `/opt/sctunnel/`, cria o comando global `set_cliente`, agenda no cron e abre os túneis.

Para trocar de cliente sem reinstalar:

```bash
sudo set_cliente <novo_id>
```

## 🗑️ Desinstalar

```bash
curl -fsSL https://sctunnel1.seucondominio.com.br/uninstall.sh | sudo bash
```

Remove `/opt/sctunnel/`, o cron, o comando `set_cliente` e mata todos os túneis SSH.

## 📜 Ver logs (após instalação)

```bash
# log do runtime (cada execução do cron)
sudo tail -f /opt/sctunnel/logs/tunnels.log

# log bruto do cron (stdout/stderr de cada disparo */1min)
sudo tail -f /opt/sctunnel/logs/cron.log

# túneis SSH ativos
ps -eo pid,cmd | grep "ssh -N" | grep -v grep

# estado salvo das conexões (PIDs e portas remotas)
sudo cat /opt/sctunnel/conexoes.txt

# rodar manualmente fora do cron
sudo /opt/sctunnel/run.sh
```

## 🛠️ Build (mantenedor)

Pré-requisitos na máquina do mantenedor:

- `~/scTunnel.pem` (chave SSH usada pelos túneis)
- `~/.sctunnel/token` (chmod 600, contém o `PORTARIA_SERVER_SALT`) — ou env `SCTUNNEL_TOKEN`

Gerar e publicar nova versão do `install.sh`:

```bash
bash v2/build.sh    # gera v2/dist/install.sh com PEM + token + código embutidos
bash v2/upload.sh   # scp install.sh + uninstall.sh -> sctunnel1:/var/www/sctunnel/
```

Detalhes adicionais (env vars, troubleshooting do servidor, layout do diretório) em [`v2/README.md`](v2/README.md).

---

## testar com python + linux

```bash
cd ~/workspace/sctunnel_client
bash install_python_version.sh
bash cap_net_raw.sh
bash install.sh --install_crons
# bash install.sh --remove_crons
```

Produção
```bash
bash set_config_json.sh prod 51 'PORTARIA_SERVER_SALT' 'python'
```

Dev
```bash
bash set_config_json.sh dev 2 'PORTARIA_SERVER_SALT' 'python'
```


## 💾 INSTALAR NO ORANGE PI

- Gravar do cartão SD para ORANGEPI 3B

```bash
sudo nand-sata-install
-> boot from eMMC - system on eMMC
se modelo for ORANGEPI 3LTS
-> filesystem -> ext4
se modelo for ORANGEPI 3B
-> filesystem -> btrfs
```

🔌 Desligue o mini PC, remova o SD Card e ligue o mini PC novamente.


🚀 Após ligar
```bash
cd /var/lib/sctunnel_client/
bash cap_net_raw.sh
set_cliente 51
```



---

## 💻 COMANDOS

▶️ Executar cliente

```bash
set_cliente 51
```


🛠️ Caso não funcione

```bash
cd /var/lib/sctunnel_client
git pull
bash install.sh --install_crons
set_cliente 51
```


⏱️ Testar cronjobs

```bash
bash /var/lib/sctunnel_client/cron_test.sh
```

⏱️ Ver Logs cronjobs

```bash
bash /var/lib/sctunnel_client/cron_logs.sh
```

❌ Remover cronjobs

```bash
bash /var/lib/sctunnel_client/install.sh --remove_crons
```

---

## 🛠️ INSTALAR AMBIENTE DE DESENVOLVIMENTO


Ajustes no python

```
sudo setcap cap_net_raw+ep /usr/bin/python3.10
sudo setcap cap_net_raw+ep /usr/bin/python3
sudo setcap cap_net_raw+ep /usr/bin/python
```


```bash
cd /var/lib
sudo git clone https://github.com/denoww/sctunnel_client.git
cd sctunnel_client
sudo chown -R "$(whoami)" .
```

📄 **Copie o certificado `scTunnel.pem` para:**

```bash
/var/lib/sctunnel_client
```


⚙️ Configurar `config.json` (ambiente development)

```bash
cd /var/lib/sctunnel_client
# Define ambiente, cliente e token
bash set_config_json.sh dev 2 'PORTARIA_SERVER_SALT' 'python'
# bash set_config_json.sh dev 2 'PORTARIA_SERVER_SALT' 'shell'
```

🟢 Executando

```bash
# Instala removendo cronjobs
bash install.sh --remove_crons
# Salava e executa cliente 2
set_cliente 2
```

---

## 📥 INSTALAR NO CARTÃO SD

### Configuração básica

- Imagem usada: ubuntu server jammy (sem interface gráfica)
- Mudar Senha:
  - `sudo passwd orangepi`
  - `sudo passwd root`
- Arrumar teclado:
  - `sudo dpkg-reconfigure keyboard-configuration`
    - Escolher opção "Generic 105-key PC"
    - Layout Portuguese (Brazil)
    - The default for the keyboard
    - No compose key
- Update:
  - `sudo apt-get update`
  - `sudo apt-get upgrade`
- Reiniciar:
  - `sudo reboot`

### Instalar sctunnel

---

#### 📥 git clone

```bash
cd /var/lib
sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git
cd sctunnel_client
sudo chown -R "$(whoami)" .
```

#### 🔑 Copiar `scTunnel.pem`

- Coloque o `scTunnel.pem` em um pendrive novo
- Insira o pendrive no tunnel
- Montar a unidade (Linux):

```bash
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb
```

```bash
sudo cp /mnt/usb/scTunnel.pem /var/lib/sctunnel_client/scTunnel.pem
sudo cp /mnt/usb/config.json /var/lib/sctunnel_client/config.json
```

#### 💻 Acesse a máquina com ssh para facilitar sua vida

```bash
# bash set_config_json.sh "prod" "51" 'PORTARIA_SERVER_SALT' 'python'
# bash set_config_json.sh "prod" "51" 'xxxxxxx' 'shell'
sudo apt update
sudo apt install python3-dev build-essential python3-pip
cd /var/lib/sctunnel_client

bash install_python_version.sh
bash cap_net_raw.sh
bash install.sh --install_crons
set_cliente 51
bash exec.sh
```

```
Fique atento nos logs verde em "Acesse essa máquina com"
Entre no ssh
Execute denovo, mas agora com PORTARIA_SERVER_SALT (pegue no env sc)
```

#### 🧩 Configurar `config.json` (ambiente produção)

Agora dentro do ssh (sua vida mais fácil).
Descubra o PORTARIA_SERVER_SALT e coloque ali embaixo:

```bash
cd /var/lib/sctunnel_client
bash set_config_json.sh "prod" "51" "PORTARIA_SERVER_SALT" 'python'
# bash set_config_json.sh "prod" "51" "PORTARIA_SERVER_SALT" 'shell'
```

#### 🚀 Finalize o cartão SD com a instalação

```bash
cd /var/lib/sctunnel_client
bash install.sh --install_crons
bash exec.sh
```

#### ⏱️ Testar cron

```bash
bash /var/lib/sctunnel_client/cron_test.sh
```

---

## ☁️ 3.5 Criar servidor SCTUNNEL (caso não exista)

Repositório oficial:

```
https://github.com/denoww/sctunnel_server
```
