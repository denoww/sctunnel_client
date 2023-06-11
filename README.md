## Executando na mão

$ sudo killall ssh; bash exec.sh

## Configurando os equipamentos que deseja processar

Execute:

```
$ cp /<PROJETO_DIR>/sctunnel/config-sample.json /<PROJETO_DIR>/sctunnel/config.json
$ chmod 400 /<PROJETO_DIR>/sctunnel/scTunnel.pem
```

```
em config.json preencha
cliente_id: 9999
token: coloque valor PORTARIA_SERVER_SALT (se for usar localhost pegue em application.yml, se for produção peça ajuda)
```

Altere o arquivo config.json conforme sua necessidade

## Configurando rotina para atualizar a câmera no cameras1.seucondominio

Execute:

$ crontab -u $USER -e

Obs.: Caso esse comando não abrir corretamente, tente com sudo

adicione os 2 comandos:

*/1 * * * * /usr/bin/sudo -u <USER_NAME> /bin/bash -lc 'cd /home/rodrigo/workspace/sctunnel_client; bash exec.sh > logs.txt'

@reboot /usr/bin/sudo -u <USER_NAME> /bin/bash -lc 'cd /home/rodrigo/workspace/sctunnel_client; bash exec.sh > logs.txt'


## AWS servidor SCTUNNEL (como criar caso não exista)

https://github.com/denoww/sctunnel_server


