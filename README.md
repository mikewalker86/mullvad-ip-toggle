# Mullvad IP Toggle

Script de linha de comandos para Linux que alterna automaticamente a
localização/IP da tua ligação [Mullvad VPN](https://mullvad.net/), a
intervalos regulares e de forma configurável.

## Funcionalidades

- Alterna entre servidores da **União Europeia**, **Estados Unidos** (por
  cidade) ou **Brasil** — as regiões podem ser combinadas no mesmo pool.
- Intervalo de rotação configurável: 25s, 35s, 45s, 60s ou 120s.
- Guarda a última configuração escolhida e permite reutilizá-la.
- Reconexão "inteligente": aguarda o handshake real da VPN em vez de um
  tempo de espera fixo, minimizando o tempo de instabilidade da ligação.
- Nova tentativa automática de reconexão se o handshake falhar.
- Verificação opcional do IP público real a cada rotação (requer `curl`).
- Notificação desktop a cada troca de localização (requer `notify-send`).
- Cronómetro decrescente visível até à próxima rotação.
- Nomes completos de país/cidade (em vez de siglas).
- Título da janela do terminal atualizado com a localização atual.
- Controlo por teclado durante a execução:
  - `q` — para o programa e restaura a configuração da Mullvad
  - `a` — avança já para a próxima rotação, sem esperar o resto do tempo
- Regista cada rotação num ficheiro de log (`~/mullvad_ip_toggle.log`).

## Requisitos

- Linux (testado em Linux Mint / Ubuntu).
- [Mullvad VPN](https://mullvad.net/pt/download) instalada, com o CLI
  `mullvad` disponível no `PATH`.
- `curl` (opcional, para a verificação do IP público).
- `notify-send` (opcional, para notificações desktop — já vem por
  omissão na maioria das distribuições com ambiente gráfico).

## Instalação

Corre este comando num terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/install.sh | bash
```

Isto vai:

1. Descarregar o script para `~/.local/bin/mullvad-ip-toggle`.
2. Criar um atalho no menu de aplicações (e, se existir, na pasta do
   Ambiente de Trabalho).

Se `~/.local/bin` ainda não estiver no teu `PATH`, o instalador avisa-te
e diz exatamente o que adicionar ao teu `~/.bashrc`.

## Como usar

Depois de instalado, corre num terminal:

```bash
mullvad-ip-toggle
```

Ou procura por **"Mullvad IP Toggle"** no menu de aplicações, ou faz
duplo clique no ícone do Ambiente de Trabalho (se foi criado).

O programa vai perguntar:

1. Qual(is) região(ões) alternar (podes combinar várias, ex: `1 3`).
2. Qual o intervalo entre rotações.

Depois disso, começa a rodar automaticamente. Durante a execução:
- pressiona `a` para avançar já para a próxima localização;
- pressiona `q` para parar e restaurar a configuração da Mullvad.

## Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/uninstall.sh | bash
```

O ficheiro de configuração (`~/.mullvad_ip_toggle.conf`) e o log
(`~/mullvad_ip_toggle.log`) não são apagados automaticamente.

## Aviso

Este projeto não é afiliado, endossado ou associado à Mullvad AB.
"Mullvad" é marca registada da Mullvad VPN AB. Este script apenas
automatiza chamadas ao CLI oficial `mullvad`, que tem de estar
instalado separadamente.

## Licença

MIT — ver [LICENSE](LICENSE).
