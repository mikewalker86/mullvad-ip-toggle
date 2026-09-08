#!/bin/bash
#
# Mullvad IP Toggle - rotação automática de localização/IP da Mullvad VPN
# Autor: script gerado com apoio do Claude
#
# Funcionalidades:
#   - Escolha da(s) região(ões) a alternar: União Europeia / Estados Unidos /
#     Brasil - podem ser combinadas (ex: UE + Brasil no mesmo pool)
#   - Escolha do intervalo de rotação: 25s, 35s, 45s, 60s, 120s
#   - Guarda a última configuração escolhida e oferece reutilizá-la
#   - Reconexão "inteligente" que aguarda o handshake real em vez de um
#     tempo fixo, minimizando o tempo de interrupção da ligação
#   - Nova tentativa automática de reconexão se o handshake falhar
#   - Verificação do IP público real a cada rotação (opcional, requer curl)
#   - Notificação desktop a cada troca de localização (requer notify-send)
#   - Registo (log) de cada rotação em ficheiro
#   - Nomes completos de país/cidade em vez de siglas
#   - Título da janela do terminal atualizado (barra de tarefas)
#   - Controlo por teclado: 'q' sai, 'a' avança já a rotação
#   - Restauro automático da configuração ao sair

LOG_FILE="$HOME/mullvad_ip_toggle.log"
CONFIG_FILE="$HOME/.mullvad_ip_toggle.conf"

# ---------------------------------------------------------------------------
# Verificação de dependências
# ---------------------------------------------------------------------------
if ! command -v mullvad >/dev/null 2>&1; then
    echo "[Erro] O comando 'mullvad' não foi encontrado."
    echo "Instala a aplicação Mullvad VPN e garante que o CLI está no PATH."
    read -rp "Pressiona ENTER para sair..."
    exit 1
fi

TEM_NOTIFY=0
command -v notify-send >/dev/null 2>&1 && TEM_NOTIFY=1

TEM_CURL=0
command -v curl >/dev/null 2>&1 && TEM_CURL=1

# ---------------------------------------------------------------------------
# Listas de localizações por região
# ---------------------------------------------------------------------------
EU_PAISES=(at be bg hr cy cz dk ee fi fr de gr hu ie it lv lt lu mt nl pl pt ro sk si es se)
US_LOCAIS=("us nyc" "us lax" "us mia" "us chi" "us dal" "us sea" "us atl" "us den" "us hou" "us slc")
BR_LOCAIS=("br sao")

# ---------------------------------------------------------------------------
# Nomes completos para exibição (em vez das siglas)
# ---------------------------------------------------------------------------
declare -A NOME_PAIS=(
    [at]="Áustria" [be]="Bélgica" [bg]="Bulgária" [hr]="Croácia" [cy]="Chipre"
    [cz]="Chéquia" [dk]="Dinamarca" [ee]="Estónia" [fi]="Finlândia" [fr]="França"
    [de]="Alemanha" [gr]="Grécia" [hu]="Hungria" [ie]="Irlanda" [it]="Itália"
    [lv]="Letónia" [lt]="Lituânia" [lu]="Luxemburgo" [mt]="Malta" [nl]="Países Baixos"
    [pl]="Polónia" [pt]="Portugal" [ro]="Roménia" [sk]="Eslováquia" [si]="Eslovénia"
    [es]="Espanha" [se]="Suécia" [us]="Estados Unidos" [br]="Brasil"
)

declare -A NOME_CIDADE=(
    [nyc]="Nova Iorque" [lax]="Los Angeles" [mia]="Miami" [chi]="Chicago"
    [dal]="Dallas" [sea]="Seattle" [atl]="Atlanta" [den]="Denver"
    [hou]="Houston" [slc]="Salt Lake City" [sao]="São Paulo"
)

# Descrição legível de um código de localização. Deteta automaticamente se é
# "país" (uma palavra, ex: UE) ou "país cidade" (duas palavras, ex: EUA/Brasil),
# o que permite combinar regiões diferentes no mesmo pool sem confusão.
descrever_local() {
    local codigo="$1"
    if [[ "$codigo" == *" "* ]]; then
        local cod_pais="${codigo%% *}"
        local cod_cidade="${codigo##* }"
        echo "${NOME_CIDADE[$cod_cidade]:-$cod_cidade}, ${NOME_PAIS[$cod_pais]:-$cod_pais}"
    else
        echo "${NOME_PAIS[$codigo]:-$codigo}"
    fi
}

# ---------------------------------------------------------------------------
# Monta o pool de localizações a partir de uma lista de opções (1, 2, 3)
# ---------------------------------------------------------------------------
montar_locais() {
    local opcoes="$1"
    LOCAIS=()
    NOMES_REGIOES_ESCOLHIDAS=()
    for opc in $opcoes; do
        case "$opc" in
            1) LOCAIS+=("${EU_PAISES[@]}"); NOMES_REGIOES_ESCOLHIDAS+=("União Europeia") ;;
            2) LOCAIS+=("${US_LOCAIS[@]}"); NOMES_REGIOES_ESCOLHIDAS+=("Estados Unidos") ;;
            3) LOCAIS+=("${BR_LOCAIS[@]}"); NOMES_REGIOES_ESCOLHIDAS+=("Brasil") ;;
        esac
    done
}

# Junta os nomes das regiões escolhidas com " + " (IFS só usa 1 caractere,
# por isso não dá para usar IFS diretamente com um separador de 3 caracteres)
juntar_nomes_regioes() {
    local resultado=""
    local nome
    for nome in "${NOMES_REGIOES_ESCOLHIDAS[@]}"; do
        if [ -z "$resultado" ]; then
            resultado="$nome"
        else
            resultado="$resultado + $nome"
        fi
    done
    echo "$resultado"
}

# ---------------------------------------------------------------------------
# Configuração: carregar/guardar a última escolha
# ---------------------------------------------------------------------------
OPCAO_REGIAO=""
OPCAO_TEMPO=""

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

usar_config_guardada=0
if [ -n "$ULTIMA_REGIAO" ] && [ -n "$ULTIMO_INTERVALO" ]; then
    montar_locais "$ULTIMA_REGIAO"
    echo "========================================="
    echo "        MULLVAD IP TOGGLE"
    echo "========================================="
    echo "Última configuração guardada:"
    printf '  Região(ões): %s\n' "$(juntar_nomes_regioes)"
    echo "  Intervalo: ${ULTIMO_INTERVALO}s"
    echo "-----------------------------------------"
    read -rp "Usar esta configuração? [S/n]: " resposta
    case "$resposta" in
        n|N) usar_config_guardada=0 ;;
        *) usar_config_guardada=1 ;;
    esac
fi

if [ "$usar_config_guardada" -eq 1 ]; then
    OPCAO_REGIAO="$ULTIMA_REGIAO"
    INTERVALO="$ULTIMO_INTERVALO"
    NOME_REGIAO=$(juntar_nomes_regioes)
else
    # -----------------------------------------------------------------------
    # Menu interativo
    # -----------------------------------------------------------------------
    echo "========================================="
    echo "        MULLVAD IP TOGGLE"
    echo "========================================="
    echo "Escolhe a(s) região(ões) para alternar:"
    echo "  1) União Europeia"
    echo "  2) Estados Unidos (cidades diferentes)"
    echo "  3) Brasil (rotação de servidor, mesmo local)"
    echo ""
    echo "Podes combinar várias, separadas por espaço (ex: 1 3)"
    echo "-----------------------------------------"
    read -rp "Opção(ões): " OPCAO_REGIAO

    montar_locais "$OPCAO_REGIAO"
    if [ "${#LOCAIS[@]}" -eq 0 ]; then
        echo "Opção inválida. A sair."
        exit 1
    fi
    NOME_REGIAO=$(juntar_nomes_regioes)

    echo ""
    echo "Escolhe o intervalo entre rotações:"
    echo "  1) 25 segundos"
    echo "  2) 35 segundos"
    echo "  3) 45 segundos"
    echo "  4) 60 segundos"
    echo "  5) 120 segundos"
    echo "-----------------------------------------"
    read -rp "Opção [1-5]: " opcao_tempo

    case "$opcao_tempo" in
        1) INTERVALO=25 ;;
        2) INTERVALO=35 ;;
        3) INTERVALO=45 ;;
        4) INTERVALO=60 ;;
        5) INTERVALO=120 ;;
        *)
            echo "Opção inválida. A sair."
            exit 1
            ;;
    esac

    # Guarda esta escolha para a próxima vez
    {
        echo "ULTIMA_REGIAO=\"$OPCAO_REGIAO\""
        echo "ULTIMO_INTERVALO=\"$INTERVALO\""
    } > "$CONFIG_FILE"
fi

# Se veio da configuração guardada, o pool de LOCAIS já foi montado por montar_locais
# na verificação acima; para o caminho do menu novo, também já foi montado.

# Tempo máximo de espera pelo handshake (não deve ultrapassar o intervalo)
TIMEOUT_HANDSHAKE=15
# Número de tentativas de reconexão antes de desistir e avançar mesmo assim
MAX_TENTATIVAS_RECONEXAO=2

# ---------------------------------------------------------------------------
# Função: espera N segundos, mas verifica a cada instante se o utilizador
# pressionou uma tecla:
#   'q' -> pedir para sair (substitui o CTRL+C, que nalguns sistemas está
#          reatribuído ao atalho de copiar texto e nunca chega como sinal)
#   'a' -> avançar já para a próxima rotação, sem esperar o resto do tempo
# Devolve: 0 = tempo passou normalmente | 1 = sair | 2 = avançar já
# ---------------------------------------------------------------------------
esperar_com_saida(){
    local duracao="$1"
    local tecla
    if read -rsn 1 -t "$duracao" tecla; then
        case "$tecla" in
            q|Q) return 1 ;;
            a|A) return 2 ;;
        esac
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Função: aguarda a reconexão real da VPN em vez de um sleep fixo
# ---------------------------------------------------------------------------
aguardar_reconexao() {
    local tempo_passado=0
    local resultado
    while [ "$tempo_passado" -lt "$TIMEOUT_HANDSHAKE" ]; do
        if mullvad status 2>/dev/null | grep -qi "connected"; then
            return 0
        fi
        esperar_com_saida 0.5
        resultado=$?
        if [ "$resultado" -eq 1 ]; then
            cleanup
        fi
        tempo_passado=$((tempo_passado + 1))
    done
    return 1
}

# ---------------------------------------------------------------------------
# Função: tenta reconectar, com nova(s) tentativa(s) automática(s) se o
# handshake falhar da primeira vez.
# ---------------------------------------------------------------------------
reconectar_com_tentativas() {
    local tentativa=1
    while [ "$tentativa" -le "$MAX_TENTATIVAS_RECONEXAO" ]; do
        mullvad reconnect > /dev/null 2>&1
        if aguardar_reconexao; then
            echo "[Mullvad] Reconectado com sucesso (tentativa $tentativa)."
            return 0
        fi
        echo "[Mullvad] Aviso: handshake falhou na tentativa $tentativa."
        tentativa=$((tentativa + 1))
    done
    echo "[Mullvad] A avançar mesmo assim após $MAX_TENTATIVAS_RECONEXAO tentativas."
    return 1
}

# ---------------------------------------------------------------------------
# Função: mostra um cronómetro decrescente até à próxima rotação
# ---------------------------------------------------------------------------
contagem_decrescente() {
    local segundos_restantes=$1
    local resultado
    while [ "$segundos_restantes" -gt 0 ]; do
        printf "\rPróxima rotação em: %02d:%02d  ('q' sair | 'a' avançar já) " $((segundos_restantes / 60)) $((segundos_restantes % 60))
        esperar_com_saida 1
        resultado=$?
        if [ "$resultado" -eq 1 ]; then
            cleanup
        elif [ "$resultado" -eq 2 ]; then
            printf "\rA avançar já para a próxima localização...                     \n"
            return 0
        fi
        segundos_restantes=$((segundos_restantes - 1))
    done
    printf "\rA rodar para a próxima localização...                          \n"
}

# ---------------------------------------------------------------------------
# Função de limpeza ao sair
# ---------------------------------------------------------------------------
cleanup() {
    echo -e "\n\n\n[Mullvad] Interrompendo rotação automática de IP..."
    echo "[Mullvad] Restaurando configuração padrão (any)..."
    mullvad relay set location any > /dev/null 2>&1
    echo "[Mullvad] Rotação finalizada. Até logo!"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotação terminada pelo utilizador." >> "$LOG_FILE"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ---------------------------------------------------------------------------
# Início da rotação
# ---------------------------------------------------------------------------
echo ""
echo "========================================="
echo "   MULLVAD IP TOGGLE ATIVADO"
echo "   Região(ões): $NOME_REGIAO"
echo "   Intervalo: ${INTERVALO}s"
echo "   Log: $LOG_FILE"
echo "   'q' para parar | 'a' para avançar já a rotação"
if [ "$TEM_NOTIFY" -eq 0 ]; then
    echo "   (notify-send não encontrado - notificações desktop desativadas)"
fi
if [ "$TEM_CURL" -eq 0 ]; then
    echo "   (curl não encontrado - verificação do IP público desativada)"
fi
echo "========================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotação iniciada - Região(ões): $NOME_REGIAO, Intervalo: ${INTERVALO}s" >> "$LOG_FILE"
echo -ne "\033]0;Mullvad: iniciando...\007"

while true; do
    local_sorteado=${LOCAIS[$RANDOM % ${#LOCAIS[@]}]}
    descricao_local=$(descrever_local "$local_sorteado")

    echo -e "\n========================================="
    echo "[Mullvad] Alterando localização para: $descricao_local"

    # Muda o título da janela do terminal (aparece na barra de tarefas do Cinnamon)
    echo -ne "\033]0;Mullvad: ${descricao_local}\007"

    # Sem aspas de propósito: se local_sorteado for "us nyc", divide-se em
    # dois argumentos separados (país e cidade). Para a UE, uma só palavra.
    mullvad relay set location $local_sorteado > /dev/null 2>&1

    reconectar_com_tentativas

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Localização alterada para: $local_sorteado" >> "$LOG_FILE"

    # "--location" foi descontinuado; "-v" (verbose) mostra a localização visível
    mullvad status -v

    # Verificação opcional do IP público real
    if [ "$TEM_CURL" -eq 1 ]; then
        ip_atual=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null)
        if [ -n "$ip_atual" ]; then
            echo "[Mullvad] IP público atual: $ip_atual"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] IP público: $ip_atual" >> "$LOG_FILE"
        else
            echo "[Mullvad] Não foi possível confirmar o IP público (sem resposta)."
        fi
    fi

    # Notificação desktop opcional
    if [ "$TEM_NOTIFY" -eq 1 ]; then
        notify-send -t 4000 "Mullvad IP Toggle" "Localização alterada para: $descricao_local" 2>/dev/null
    fi

    echo "========================================="

    contagem_decrescente "$INTERVALO"
done
