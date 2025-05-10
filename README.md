# 📡 sctunnel_client

## 🧩 1. Gravar do cartão SD para ORANGEPI 3B

```bash
sudo nand-sata-install
-> boot from eMMC - system on eMMC
-> filesystem -> btrfs

```

🔌 Desligue o mini PC, remova o SD Card e ligue o mini PC novamente.


---

## 🔄 2. Executar e salvar cliente

```bash
exec_cliente 51
```


Caso não funcionar

Instale
```bash
bash /var/lib/sctunnel_client/install.sh --install_crons
exec_cliente 51
```

Teste o Cron

```bash
bash /var/lib/sctunnel_client/testar_cron.sh
```

Remova os cronjobs no mini_pc
```bash
bash /var/lib/sctunnel_client/install.sh --remove_crons
```


---

## 📥 3. Construir CARTÃO SD

### Configuração básica

- Imagem usada: ubuntu server jammy (sem interface grafica)
- Senha
  - `sudo passwd orangepi`
  - `sudo passwd root`
- Arrumar teclado
  - `sudo dpkg-reconfigure keyboard-configuration`
    - Escolher opção "Generic 105-key PC"
    - Layout Portuguese (Brazil)
    - The default for the keyboard
    - No compose key
- Update
    - `sudo apt-get update`
    - `sudo apt-get upgrade`
- Reiniciar
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

#### 🔑 Copiar o certificado `.pem`

- Coloque o `scTunnel.pem` no pendrive
- Insira o pendrive no tunnel
- comando mount

```bash
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb
```

```bash
sudo cp /mnt/usb/____CAMINHO____/scTunnel.pem /var/lib/sctunnel_client/scTunnel.pem
```


#### 💻 Acesse a maquina com ssh para facilitar sua vida

```bash
bash set_config_json.sh "prod" "51" 'xxxxxxx'
bash exec.sh
```

```
Fique atento nos logs verde em "Acesse essa máquina com"
Entre no ssh
execute denovo, mas agora com PORTARIA_SERVER_SALT (pegue no env sc)
```

```
cd /var/lib/sctunnel_client
bash set_config_json.sh "prod" "51" "PORTARIA_SERVER_SALT"
```

Termine a instalação
```
cd /var/lib/sctunnel_client
bash install.sh --install_crons
bash exec.sh
```

---


## ☁️ 3.5 Criar servidor SCTUNNEL (caso não exista)

Repositório oficial:

```
https://github.com/denoww/sctunnel_server
```
