# sctunnel client v2 (Linux)

Versão Linux do cliente sctunnel, distribuída como **um único `install.sh`** com PEM + código + token embutidos. Build feito na máquina do mantenedor, hospedado em `https://sctunnel1.seucondominio.com.br/install.sh`.

A v1 (`/var/lib/sctunnel_client`, raiz do repo) continua sendo a versão **Windows** e não é tocada por este pipeline.

## Instalação no cliente

```bash
curl -fsSL https://sctunnel1.seucondominio.com.br/install.sh   | sudo bash -s -- <cliente_id>
curl -fsSL https://sctunnel1.seucondominio.com.br/uninstall.sh | sudo bash
```

Tudo cai em `/opt/sctunnel/` (root-owned, PEM e config 600). Cron `*/1 * * * *` mantém os túneis. Trocar cliente sem reinstalar: `sudo set_cliente <novo_id>`.

## Layout do diretório

```
v2/
├── runtime/                     código que roda no cliente
│   ├── tunnels.py               loop principal (~300 LOC)
│   ├── network_scanner.py       ARP scan via Scapy
│   ├── run.sh                   entrypoint do cron
│   └── set_cliente.sh           trocador de cliente_id
├── installer/
│   ├── template.sh              gerador do install.sh (recebe placeholders no build)
│   └── uninstall.sh             standalone (sem payload embutido)
├── build.sh                     gera dist/install.sh embutindo PEM + token + tar do runtime
├── upload.sh                    sobe install.sh + uninstall.sh pra EC2 via scp
└── dist/install.sh              artefato final (~15KB)
```

## Pré-requisitos da máquina do mantenedor

- `~/scTunnel.pem` — chave SSH usada pelos túneis (também é a chave de `ubuntu@sctunnel1`).
- `~/.sctunnel/token` (chmod 600) — `PORTARIA_SERVER_SALT`. Pode também ser passado como env `SCTUNNEL_TOKEN`.
- AWS CLI configurada apenas se você for mexer em SG/instâncias; o build em si não usa AWS.

## Fluxo de release

```bash
bash v2/build.sh     # lê ~/scTunnel.pem + ~/.sctunnel/token, gera v2/dist/install.sh
bash v2/upload.sh    # scp install.sh + uninstall.sh -> sctunnel1:/var/www/sctunnel/
```

Para testar antes de divulgar a URL, pode-se rodar o `dist/install.sh` direto via scp num cliente — o behaviour é idêntico ao do `curl | bash`.

## O que é configurável via env no build

| Variável | Default | Descrição |
|---|---|---|
| `SCTUNNEL_PEM` | `~/scTunnel.pem` | chave embutida |
| `SCTUNNEL_TOKEN` | (lê `~/.sctunnel/token`) | salt do servidor |
| `SC_SERVER_HOST` | `https://www.seucondominio.com.br` | ERP |
| `SC_TUNNEL_HOST` | `sctunnel1.seucondominio.com.br` | tunnel server |
| `SC_TUNNEL_USER` | `ubuntu` | user SSH na EC2 |

`upload.sh` aceita `EC2_USER`, `EC2_HOST`, `SCTUNNEL_PEM`.

## Dependências instaladas no cliente

apt: `python3 python3-venv python3-pip python3-dev build-essential libffi-dev libpcap-dev jq libcap2-bin openssh-client cron`

pip (dentro de `/opt/sctunnel/venv`): `scapy psutil requests`

`setcap cap_net_raw+eip` no Python da venv (resolve link → `/usr/bin/python3.x`) — necessário pra Scapy abrir raw socket sem sudo.

## Troubleshooting no cliente

```bash
tail -f /opt/sctunnel/logs/tunnels.log
tail -f /opt/sctunnel/logs/cron.log
cat   /opt/sctunnel/conexoes.txt        # PIDs e portas remotas dos túneis ativos
sudo /opt/sctunnel/run.sh                # rodar manualmente fora do cron
sudo systemctl status cron               # cron rodando?
ps -eo pid,cmd | grep "ssh -N" | grep -v grep
```

Se `run.sh` reclama de `cap_net_raw`: re-rode o instalador (idempotente).

## Server side (EC2 sctunnel_server)

- nginx servindo `/var/www/sctunnel/` na 443 com cert Let's Encrypt
- certbot renova cert sozinho (timer instalado pelo `apt install certbot`)
- não há SSM agent — qualquer manutenção é via SSH com a `.pem`

```bash
ssh -i ~/scTunnel.pem ubuntu@sctunnel1.seucondominio.com.br
sudo tail /var/log/nginx/access.log
sudo certbot renew --dry-run
```

## Notas de segurança

O `install.sh` contém PEM + token embutidos (base64). A URL atua como segredo: vazou a URL, vazou a credencial. Se for distribuir publicamente, mover a hospedagem para um path não-guessável e/ou trocar a chave/token.
