# 📡 sctunnel_client

## 🧩 1. Gravar no SD Card

```bash
sudo nand-sata-install
```

🔌 Desligue o mini PC, remova o SD Card e ligue o mini PC novamente.


---

## 🔄 2. Trocar o cliente

```bash
trocar_cliente 10
```


Caso não funcionar faça
```bash
bash /var/lib/sctunnel_client/install.sh
trocar_cliente 10
```



---

## 📥 3. Instalação

### Instalação padrão

```bash
cd /var/lib
sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git
cd /var/lib/sctunnel_client/
sudo chown -R $(whoami) .
cp config-sample.json config.json
```

### Instalação alternativa (forçando permissões)

```bash
cd /var/lib
sudo chmod 7777 -R .
sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git
cd /var/lib/sctunnel_client/
sudo chown -R $(whoami) .
cp config-sample.json config.json
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
    "host": "http://localhost:3000",
    "token": "PORTARIA_SERVER_SALT",
    "cliente_id": 9999999999999999999999999999999,
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

## ⏰ 3.4 Configurar rotina automática (cron)

Crie o arquivo:

```bash
sudo nano /etc/cron.d/sctunnel
```

Cole o conteúdo:

```cron
@reboot root bash /var/lib/sctunnel_client/exec.sh >> /var/lib/sctunnel_client/log_cron.txt 2>&1
*/1 * * * * root bash /var/lib/sctunnel_client/exec.sh >> /var/lib/sctunnel_client/log_cron.txt 2>&1
*/30 * * * * root /usr/bin/systemctl restart NetworkManager >> /var/lib/sctunnel_client/rede.log 2>&1
```

---

## ☁️ 3.5 Criar servidor SCTUNNEL (caso não exista)

Repositório oficial:

```
https://github.com/denoww/sctunnel_server
```
