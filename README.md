# 📡 sctunnel_client

## 🧩 1. Gravar no SD Card

```bash
sudo nand-sata-install
-> boot from eMMC - system on eMMC
-> filesystem -> btrfs

```

🔌 Desligue o mini PC, remova o SD Card e ligue o mini PC novamente.


---

## 🔄 2. Executar e salvar cliente

```bash
exec_cliente 10
```


Caso não funcionar

Instale
```bash
bash /var/lib/sctunnel_client/install.sh
exec_cliente 10
```

ou

Instale com cronjobs no mini_pc
```bash
bash /var/lib/sctunnel_client/install.sh --install_crons
exec_cliente 10
```

Remova os cronjobs no mini_pc
```bash
bash /var/lib/sctunnel_client/install.sh --remove_crons
exec_cliente 10
```

Tete o Cron

```bash
bash /var/lib/sctunnel_client/testar_cron.sh
```


---

## 📥 3. Construir SD

### Construir SD

- Usado ubuntu server jammy (sem interface grafica)
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

### Instalação padrão

---

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

#### 🧩 set_config_json_and_install


```bash
cd /var/lib
sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git
cd sctunnel_client
sudo chown -R "$(whoami)" .
bash set_config_json_and_install.sh "prod", "51", 'xxxxxxx'
bash exec.sh
```

```
Fique atento nos logs para pegar o "Acesse essa máquina com"
Entre no ssh
execute denovo, mas agora com PORTARIA_SERVER_SALT (pegue no env sc)
```

```
bash set_config_json_and_install.sh "prod", "51", 'PORTARIA_SERVER_SALT'
```

Termine a instalação
```
bash "$DIR/install.sh" --install_crons
exec_cliente "$CLIENTE_ID"
```

---

## 🛠️ 3.1 Configurar cliente_id e token

```bash
sudo nano /var/lib/sctunnel_client/config.json
```

Preencha:

```json
{
  "sc_server": {
    "host": "https://www.seucondominio.com.br",
    "token": "PORTARIA_SERVER_SALT",
    "cliente_id": 51,
    "equipamento_codigos": []
  },
  "sc_tunnel_server": {
    "host": "sctunnel1.seucondominio.com.br",
    "user": "ubuntu"
  }
}
```

🔹 Se for usar **localhost**, pegue o `PORTARIA_SERVER_SALT` no `application.yml`.
🔹 Se for **produção**, peça ajuda para um desenvolvedor.

🎯 Para pegar apenas alguns equipamentos:

```json
"equipamento_codigos": [12, 22]
```

🎯 Para pegar todos os equipamentos:

```json
"equipamento_codigos": []
```




---

## 🖐️ 3.3 Executar manualmente

```bash
bash /var/lib/sctunnel_client/exec.sh
```

---



## ☁️ 3.5 Criar servidor SCTUNNEL (caso não exista)

Repositório oficial:

```
https://github.com/denoww/sctunnel_server
```
