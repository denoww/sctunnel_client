# Playbook para Claude — sctunnel_client

Este arquivo é o roteiro que o Claude segue quando o usuário pede operações automatizadas neste repo.

## Comando: "ache todos orangepi da rede e instale no cliente \<id\>"

Variantes aceitas: "instala em todos os orangepi", "rode o instalador em todos os orangepi", "achar orange pi e instalar com cliente X".

### Passos

1. **Descobrir a sub-rede local.** Rode `ip route | awk '/^default/{print $3}'` pra achar o gateway, depois `ip -4 -o addr show | awk '$3=="inet"{print $4}'` pra extrair a sub-rede `/24` correspondente da interface ativa (ignorar `127.`, `169.254.`, `docker0`, `br-*`).

2. **Varrer a rede.** `nmap -sn <subnet>` pra listar hosts vivos. Em paralelo, `ping -c1 -W1 <ip>` em cada host pra popular ARP, depois `ip neigh | grep <subnet>` pra obter os MACs.

3. **Filtrar candidatos a Orange Pi.** Marcar como candidato qualquer host com:
   - MAC locally-administered (segundo nibble `2`, `6`, `A` ou `E`) **e** prefixo típico Allwinner (ex.: `02:07:`, `02:81:`, `02:ff:`); **OU**
   - SSH (porta 22) aberto **e** banner contendo `Ubuntu` ou `Debian`.

   Excluir hosts já identificados como câmeras Hikvision (OUI `bc:5e:33`, `bc:9b:5e`, `e0:50:8b`), Control iD (`fc:52:ce`), roteadores, e o próprio host (IP local).

4. **Confirmar via SSH.** Para cada candidato, ler senha de `~/.sctunnel/orangepi_password` e tentar login `orangepi@<ip>` usando o truque `SSH_ASKPASS`+`setsid -w`. Rodar `cat /proc/device-tree/model 2>/dev/null; hostname` pra confirmar que é mesmo um Orange Pi (modelo começa com `OrangePi` **ou** hostname casa com `orangepi*`). Hosts que não autenticam ou não são Orange Pi: descartar.

5. **Instalar em cada Orange Pi confirmado.** Via SSH executar:
   ```bash
   echo "<senha>" | sudo -S bash -c "curl -fsSL https://sctunnel1.seucondominio.com.br/install.sh | bash -s -- <cliente_id>"
   ```
   Capturar a última linha "✔ cliente_id X conectado" como sinal de sucesso. Timeout generoso (~120s — apt-get pode demorar).

6. **Resumo final.** Imprimir tabela em markdown:

   | IP | Hostname | Modelo | Cliente | Status | Notas |
   |---|---|---|---|---|---|

   Linhas: uma por candidato (incluir os descartados com motivo em "Notas"). Status: `✅ instalado`, `⚠️ skip` (não-orangepi), `❌ falhou` (com erro curto).

7. **Comandos de log por SSH.** Após a tabela, sob o título "📡 Ver logs por SSH", imprimir um bloco de código (uma linha por device instalado), no formato:

   ```bash
   ssh orangepi@<ip> 'tail -f /opt/sctunnel/logs/tunnels.log'
   ```

   **Sem `sudo`** — `tunnels.log` e `cron.log` são criados com modo 644 (umask 022 herdado do cron rodando como root), legíveis por qualquer usuário. Usar `sudo` quebra: ssh sem `-t` não aloca TTY e o sudo aborta com `a terminal is required`. Cada linha em seu próprio fenced code block (pra GitHub render botão de copiar). Se nenhum device foi instalado, omitir esta seção.

### Segurança

- **NUNCA** colocar a senha do Orange Pi neste arquivo nem em qualquer arquivo dentro do repo. Ela vive em `~/.sctunnel/orangepi_password` (chmod 600), fora do versionamento.
- **NUNCA** commitar `v2/dist/install.sh` (já está no `.gitignore`) — contém PEM e token embutidos.
- Limpar tempfiles do `SSH_ASKPASS` (`/tmp/askpass*.sh`) ao final de cada execução.

### Pré-requisitos no host do mantenedor

- `~/.sctunnel/orangepi_password` (chmod 600) — senha SSH dos Orange Pi (assume-se a mesma em todos).
- `nmap` instalado (`apt install nmap`).
- Acesso de rede direta à sub-rede dos Orange Pi (mesmo broadcast domain).

### Notas operacionais

- Se nenhum Orange Pi for encontrado, ainda assim mostrar o resumo dizendo "0 hosts elegíveis" e listar os candidatos descartados — ajuda a debugar heurística.
- Se um Orange Pi já tiver a v2 instalada, `install.sh` é idempotente — re-rodar atualiza versão sem quebrar conexões existentes (cliente_id é reescrito, túneis preservados via `conexoes.txt`).
- Para parar tudo antes de reinstalar (limpeza completa): `curl -fsSL https://sctunnel1.seucondominio.com.br/uninstall.sh | sudo bash`.

## Comando: "faz novo build e sobe"

Variantes aceitas: "novo build", "rebuilda", "build e sobe", "atualiza o instalador", "atualiza o install.sh", "deploya", "publica nova versão".

### Passos

1. **Validar pré-requisitos.** Confirmar que `~/scTunnel.pem` existe e `~/.sctunnel/token` é legível. Se faltar algum, abortar com mensagem clara dizendo o que falta e como gerar (token: `printf '%s' '<TOKEN>' > ~/.sctunnel/token && chmod 600 ~/.sctunnel/token`).

2. **Build local.** Rodar `bash v2/build.sh` e mostrar as 3 últimas linhas do output (incluem `payload size`, `version`, `OK -> ... bytes`). Falha → reportar e parar.

3. **Upload.** Rodar `bash v2/upload.sh` e mostrar últimas linhas (que incluem `HTTP 200 — N bytes` pra `install.sh` e `uninstall.sh`). Falha → reportar e parar.

4. **Verificação externa.** `curl -sI https://sctunnel1.seucondominio.com.br/install.sh | head -3` pra confirmar HTTP 200 e tamanho. Confirmar que o tamanho remoto bate com o tamanho de `v2/dist/install.sh` (`wc -c`).

5. **Resumo final.** Imprimir bloco com build version (timestamp), tamanho do `install.sh`, URL pública, e o comando 1-liner pra instalar (`curl ... | sudo bash -s -- <id>`). Se o usuário pediu também pra testar (frase contém "testa", "valida no orangepi", etc.), seguir pra próxima etapa.

6. **Teste opcional no Orange Pi.** Só executar se solicitado. Pegar 1 Orange Pi conhecido (preferir o `192.168.15.131`) e rodar o instalador via SSH com cliente_id atual (ler `cat /opt/sctunnel/cliente.txt` antes pra preservar). Mostrar tail do `tunnels.log` por 5s.

### Segurança

- **NUNCA** commitar `v2/dist/install.sh` (`.gitignore` já cobre, mas verificar com `git status` antes de qualquer commit relacionado).
- **NUNCA** logar conteúdo do PEM ou do token na conversa nem em arquivos.

### Pré-requisitos no host do mantenedor

- `~/scTunnel.pem` (chave SSH dos túneis e do `ubuntu@sctunnel1`).
- `~/.sctunnel/token` (chmod 600) com o `PORTARIA_SERVER_SALT`.
- Conectividade ao DNS público `sctunnel1.seucondominio.com.br` (a EC2 us-east-1).
