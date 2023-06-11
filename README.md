## Instale

cd /var/lib; sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git; cd /var/lib/sctunnel_client/; sudo chown -R $(whoami) .

ou

cd /var/lib; sudo chmod 7777 -R . ;sudo git clone --depth 1 https://github.com/denoww/midia_indoor_player.git; cd /var/lib/midia_indoor_player/; sudo chown -R $(whoami) .


## Executando na mão

$ bash /var/lib/sctunnel_client/exec.sh

## Configurando os equipamentos que deseja processar

Execute:

```
cp /var/lib/sctunnel_client/config-sample.json /var/lib/sctunnel_client/config.json;
chmod 400 /<PROJETO_DIR>/sctunnel/scTunnel.pem;
```

```
em config.json preencha
cliente_id: 9999
token: coloque valor PORTARIA_SERVER_SALT (se for usar localhost pegue em application.yml, se for produção peça ajuda)
```

Altere o arquivo config.json conforme sua necessidade

## Rotina pra fazer tunnel de 1 em 1 minuto

Crie o arquivo

cron_file=/etc/cron.d/sctunnel
sudo touch $cron_file
<br>
sudo nano $cron_file
<br>

Cole o conteudo abaixo

```
@reboot root bash /var/lib/sctunnel_client/exec.sh
*/1 * * * * root bash /var/lib/sctunnel_client/exec.sh
```

## AWS servidor SCTUNNEL (como criar caso não exista)

https://github.com/denoww/sctunnel_server


