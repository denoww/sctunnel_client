# 📡 sctunnel_client



## testar com python + linux

```bash
cd ~/workspace/sctunnel_client
bash exec_install_python_version.sh
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
-> filesystem -> btrfs
```

🔌 Desligue o mini PC, remova o SD Card e ligue o mini PC novamente.


🚀 Após ligar
```bash
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
sudo cp /mnt/usb/____CAMINHO____/scTunnel.pem /var/lib/sctunnel_client/scTunnel.pem
sudo cp /mnt/usb/____CAMINHO____/config.json /var/lib/sctunnel_client/config.json
```

#### 💻 Acesse a máquina com ssh para facilitar sua vida

```bash
# bash set_config_json.sh "prod" "51" 'PORTARIA_SERVER_SALT' 'python'
# bash set_config_json.sh "prod" "51" 'xxxxxxx' 'shell'
sudo apt update
sudo apt install python3-dev build-essential python3-pip
cd /var/lib/sctunnel_client
sudo chown -R $(whoami):$(whoami) .git
sudo chmod 400 scTunnel.pem

bash exec_install_python_version.sh
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
