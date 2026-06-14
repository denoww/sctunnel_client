# 📡 sctunnel_client

> ## ⛔ DESCONTINUADO (2026-06-14) — use o **turbgate**
>
> O sctunnel foi substituído pelo **turbgate** (mTLS, token por cliente, multiplexado).
> **Não faça novas instalações de sctunnel** — principalmente no Windows.
>
> - Instalador (todas plataformas): https://turbgate.botbox.info — Windows: `https://turbgate.botbox.info/setup.exe`
> - O instalador Windows do sctunnel (`sctunnel_setup.exe`) foi **removido** e o workflow de build (`Build EXE no Windows`) está **desativado**.
> - O ERP (`/portarias/get_tunnel_devices`) **bloqueia novas instalações** de sctunnel (freeze por `Cliente::Token` vs `PORTARIA_SERVER_SALT`). Equipamentos que já rodam continuam até migrarem.
>
> Conteúdo abaixo mantido apenas para referência dos equipamentos legados ainda não migrados.

---

> 👷 **Técnico instalando Orange Pi novo?** → instale **turbgate**, não sctunnel.

> Linux (v2) abaixo. Windows (v1) mais embaixo. *(legado — não usar para instalações novas)*

## 🤖 Comandos do Claude Code

Dentro deste repo, abra o Claude Code e mande uma das frases abaixo. Playbooks completos em [`CLAUDE.md`](CLAUDE.md).

**Frota Orange Pi** — varre a sub-rede, identifica Orange Pis e roda `install.sh` em todos. Pré-req: `~/.sctunnel/orangepi_password` (chmod 600).

```text
ache todos orangepi da rede e instale no cliente <id>
```

**Clonar pendrive** — com 2 pendrives plugados (Orange Pi + em branco), gera clone bootável no segundo, preservando U-Boot e UUID. Pré-req: destino ≥ 4 GB **real** (flash falso é comum — valida com `apt install f3` + `sudo f3probe --destructive --time-ops /dev/sdX`).

```text
clona o cartão
```

**Build & deploy** — build local do `install.sh` v2 e upload pro servidor `sctunnel1`. Pré-req: `~/scTunnel.pem` e `~/.sctunnel/token` (chmod 600).

```text
faz novo build e sobe
```

## 🧬 Clonar pendrive Orange Pi existente (manual)

Duplica um pendrive/SD que já está rodando num Orange Pi pra outro pendrive — preservando U-Boot e UUID. Pré-req: 2 pendrives USB plugados (origem com Orange Pi + destino com ≥ 4 GB **real**).

```bash
bash clone_cartao.sh
```

Flags: `--src /dev/sdX`, `--dst /dev/sdY`, `--img ~/orangepi.img`, `--yes`. Playbook em [`CLAUDE.md`](CLAUDE.md).

## 💾 Criando o primeiro pen drive

**1. Baixar a imagem:**

- **Orange Pi 3 LTS** → [Google Drive](https://drive.google.com/drive/folders/1ctuKgHNN9r517tiAv9GGGaR7UYQgZiXP) → `Orangepi3-lts_3.0.8_debian_bullseye_server_linux` (394 MB)
- **Orange Pi 3B** → [Google Drive](https://drive.google.com/drive/folders/1-mcXPDx1QpE9ZI8oTivmJ1Nd5HfU5nFv) → `Orangepi3b_1.0.8_debian_bookworm_server_linux` (729 MB)

**2. Baixar o gravador:** [balenaEtcher](https://etcher.balena.io/) (Windows / Mac / Linux).

**3. Gravar:**

1. Plugue o SD card (mín. 8 GB) no PC.
2. Abra o balenaEtcher → **Flash from file** → escolha o `.img.xz` baixado.
3. **Select target** → escolha o SD card (confira a letra/tamanho — se errar, formata seu HD).
4. **Flash!** → espera ~3 min.

**4. Bootar:** retira o SD do PC, encaixa no Orange Pi, liga na tomada. Espera 1–2 min pra subir, depois roda o comando do Claude Code (ver topo) pra detectar e instalar.

## 🛠️ Build & deploy do `install.sh` (mantenedor)

Pré-req: `~/scTunnel.pem` e `~/.sctunnel/token` (chmod 600). Detalhes em [`v2/README.md`](v2/README.md).

```bash
bash v2/build.sh && bash v2/upload.sh
```

(Ou usa o comando `faz novo build e sobe` no Claude Code — ver topo.)

## 📥 Instalar (manual, 1 máquina)

```bash
curl -fsSL https://sctunnel1.seucondominio.com.br/install.sh | sudo bash -s -- <cliente_id>
```

Trocar cliente:

```bash
sudo set_cliente <novo_id>
```

## 🗑️ Desinstalar

```bash
curl -fsSL https://sctunnel1.seucondominio.com.br/uninstall.sh | sudo bash
```

## 📜 Logs

Runtime:

```bash
sudo tail -f /opt/sctunnel/logs/tunnels.log
```

Cron bruto:

```bash
sudo tail -f /opt/sctunnel/logs/cron.log
```

Túneis SSH ativos:

```bash
ps -eo pid,cmd | grep "ssh -N" | grep -v grep
```

Estado das conexões:

```bash
sudo cat /opt/sctunnel/conexoes.txt
```

Rodar manualmente:

```bash
sudo /opt/sctunnel/run.sh
```

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
