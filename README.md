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
    - `sudo reboot`
- Reiniciar
    - `sudo reboot`

### Instalação padrão

```bash
PORTARIA_SERVER_SALT='xxxxxxxxxxxxxxxxxxxx'
cd /var/lib
sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git
cd sctunnel_client
bash set_config_json_and_install.sh "PROD", "PORTARIA_SERVER_SALT", '51'
```

- Obs
- PROD ou DEV
- 51 é o cliente_id

```
Fique atento nos logs para pegar o login com ssh e aí sim setar o PORTARIA_SERVER_SALT denovo
```bash


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

## 🔑 3.2 Copiar o certificado `.pem`

Copie o arquivo `scTunnel.pem` para a pasta:

```bash
/var/lib/sctunnel_client/
```

Depois rode:

```bash
chmod 400 /var/lib/sctunnel_client/scTunnel.pem
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
