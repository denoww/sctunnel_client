## se o sd tiver pronto basta

```
sudo nand-sata-install
```

Desliga o minipc, remova o SD Ligue e configre o cliente_id

```
sudo nano /var/lib/sctunnel_client/config.json
```

preencha
```
cliente_id: 9999999999999999999999999999999
token: coloque valor PORTARIA_SERVER_SALT (se for usar localhost pegue em application.yml, se for produção peça ajuda)
```

## Instale

cd /var/lib; sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git; cd /var/lib/sctunnel_client/; sudo chown -R $(whoami) . ; cp config-sample.json config.json; 

ou

cd /var/lib; sudo chmod 7777 -R . ;sudo git clone --depth 1 https://github.com/denoww/sctunnel_client.git; cd /var/lib/sctunnel_client; sudo chown -R $(whoami) . ; cp config-sample.json config.json;

## Copie scTunnel.pem para pasta /var/lib/sctunnel_client -> peça o arquivo .pem para um desenvolvedor

E execute:

```
chmod 400 /var/lib/sctunnel_client/scTunnel.pem;
```

## Executando na mão

```
bash /var/lib/sctunnel_client/exec.sh
```

## Configurando os equipamentos que deseja processar

Execute:

```
sudo nano /var/lib/sctunnel_client/config.json
```

preencha
```
cliente_id: 9999999999999999999999999999999
token: coloque valor PORTARIA_SERVER_SALT (se for usar localhost pegue em application.yml, se for produção peça ajuda)
```

Altere o arquivo config.json conforme sua necessidade

## Rotina pra fazer tunnel de 1 em 1 minuto

Crie o arquivo

```
sudo nano /etc/cron.d/sctunnel
```

Cole o conteudo abaixo

```
@reboot root bash /var/lib/sctunnel_client/exec.sh
*/1 * * * * root bash /var/lib/sctunnel_client/exec.sh
```

## AWS servidor SCTUNNEL (como criar caso não exista)

https://github.com/denoww/sctunnel_server


