#!/bin/bash

# wp_install.sh - instala última versão do WordPress via SSH.
#
# Autor     : Leonardo Galindo <correio@leonardogalindo.xyz>
# Manutenção: Leonardo Galindo
#
# -------------------------------------------------------------

wp_configuration_data() {
    clear    
    
    printf 'Informe os dados do banco de dados.\n\n'

    read -p "Nome do banco de dados: " database_name
    read -p "URL do banco de dados:  " database_host

    # a variável password será utilizada para receber entrada de dados que será capturado pela variável letter
    password=""

    # variável será utilizada para saída de dados no prompt
    prompt="Senha do banco de dados: "

    # IFS – Internal Field Separator
    # A variável IFS é usada pelo shell para delimitar palavras em uma lista, a qual é usada por diversos comandos, por exemplo, read, for, select, etc
    # O valor padrão da variável IFS consiste nos caracteres de espaço em branco, tabulação e de nova linha, mas é possíıvel redefiní-la para uma melhor adequação aos nossos scripts
    # aqui, estou utilizando o valor padrão: branco, tabulação e de nova linha
    # isso quer dizer que, ao digitar uma string, exemplo: leonardo galindo brasil 
    # ela será utilizada como uma uníca captura. Em um for, o nome leonardo galindo brasil, será exibido em uma única linha

    # -r  - evitando barras invertidas
    # -s - garante que a entrada seja lida silenciosamente
    # -n 1 lendo apenas um único caractere de cada vez

    # loop com while
    # aqui, sempre que digitar um caractere, o loop será geraddo. Caso dê um enter - que vai ser captura como nova linha - nulo - sem valor
    # a condicional verificar se a varíavel é igual a vazio/nulo - $'\0' 
    # se for true, o loop se encerra
    while IFS= read -p "$prompt" -r -s -n 1 letter; do
        if [[ $letter == $'\0' ]]; then
            break
        fi

        # a variável password será utilizada como acumulador dos dados da variável letter
        password="$password$letter"

        # como não ocorre quebra de linha na saída do prompt -p, a variável prompt vai exibir a string asterico em cada loop
        prompt="*"
    done

    # variável irá receber o valor de database_name
    username="$database_name"
       
    # local wp_database=("$database_name" "$username" "$password" "$db_host")
    local wp_banco_dados=("$database_name" "$username" "$password" "$database_host")    
    wp_config
}


wp_config() {
    
    clear
    printf 'Finalizando instalação...\n'
    # cp criará uma cópia do arquivo original
    # essa copia tem como objetivo, manter o arquivo original para backup e referência  
    cp wp-config-sample.php wp-config.php

    # esse array terá os dados de configuração do arquivo wp-config.php
    # ele será utilizado para atualizar as informações do banco de dados...
    # fornecida na instalação do WordPress via script
    wp_config=('database_name_here' 'username_here' 'password_here' 'localhost')
    
    # operações aritḿeticas em bash, precisa utilizar (())
    # aqui, apenas atribui o valor, sem identificar como varíavel
    ((count = 0)) # variável count, recebe 0
    
    # nesse loop, utilizando for, estou passando o array wp_banco_dados, como retorno da função wp_configuration_data(), definido como variável global na função wp_install()
    # a variável db, irá percorrer o array e retornar os valires de cada indíce, no qual será utilizado para atualizar as informações do banco de dados
    for db in ${wp_banco_dados[@]}; do
        # adicionei o printf abaixo para validar se o array foi processado
        #printf '%s\n' "$db"


        # comando sed, permite localizar e substituir uma string utilizando regex - expressão regular
        # sed -i 's/SEARCH_REGEX/REPLACEMENT/g' INPUTFILE 

        # aqui, chamará o array wp_config, no qual o loop com a variável count, permitirá acessar os indíce com os valores que foi tirado do arquivo: wp-config.php
        # para poder substituir pelas strings do array wp_banco_dados...
        # Ao encontrar as informações, elas será trocadas e gravadas no arquivo wp-config.php
        sed -i "s/"${wp_config["$((count++))"]}"/"${db}"/g" wp-config.php

        # gerar prefixo aleátorio - melhorar segurança
        wp_prefix=$(mktemp --dry-run XXXXX)
        # alterando o profixo no arquivo wp-config.php
        # ,, todos os caracteres serão minusculos
        sed -i "s/wp_/"${wp_prefix,,}_"/g" wp-config.php
    done  # encerrando o loop for

    sleep 4
    clear

    asciiart='
    \n
     ________________________________________ 
    |  ____________________________________  |
    | | WordPress instalado com sucesso!!! | |
    | |____________________________________| |
    |________________________________________|

    \n\n '

    printf "$asciiart"

    sleep 5
    clear
}


wp_install() {
    clear       
    printf '\nProcessando instalação...\n\n'

    sleep 3 

    # descompactará o arquivo latest.tar.gz, no qual a saída processada não será exibida na tela, encaminhado-a para /dev/null
    tar zxvf latest.tar.gz > /dev/null
    rm latest.tar.gz # removendo arquivo compactado
    cd wordpress # acessando diretório descompactado

    # Aqui, estou enviando todo conteúdo do diretório wordpress para pasta public_html. a varáivel $1, é utilizada como argumento para receber a váriavel
    # "$path"  - várivel com o caminho absoluto da public_html
    mv *  -- "$1" 
    cd .. # saíndo do diretório
    rmdir wordpress # removendo o diretório wordpress
    cd -- "$1" # acessando a public_html

    php_ini_directives='
    memory_limit = 512M
    date.timezone = "America/Sao_Paulo"
    display_errors = On
    upload_max_filesize = 300M
    post_max_size = 300M
    '
    touch .user.ini; echo "${php_ini_directives}" > .user.ini

    php_htaccess='
    # BEGIN WordPress

    RewriteEngine On
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]

    # END WordPress
    '
    
    touch .htaccess; echo "${php_htaccess}" > .htaccess         

    # funções em bash, lida com retorno da seguinte forma:
    # o array wp_banco_dados, utilizado na função wp_configuration_data...
    # será passado como retorno para função wp_config.
    wp_banco_dados=global    
    wp_configuration_data
}


wp_download() {
    # baixará última versão do WordPress
    # curl -s https://wordpress.org/latest.tar.gz
    # curl -O https://wordpress.org/latest.tar.gz
    # wget https://wordpress.org/latest.tar.gz

    # o operador 2>, permite redirecionar saída de erros de um comando ou programa para um arquivo específico
    # O redirecionamento de saída para o null é uma técnica utilizada para descartar dados de saída
    # É comum em situações onde não é necessário salvar ou exibir resultados de um comando e pode ser feito através do operador > seguido de /dev/null
    curl -O https://wordpress.org/latest.tar.gz 2> /dev/null

    # varáivel será utilizada como argumento na função wp_install para passar o caminho da instalação do WordPress.
    path="$PWD""/public_html"    

    # função para instalação WordPress.
    wp_install "$path" 
}


wp_compress() {
    # a varáivel backup_directory, será utiliza para criação do arquivo no formato: backup_2023-11-22.gz
    # essa variável receberá a saída do comando date formatada com ano, mês e dia.
    # também crie o nome bakckup_ como expansão da saída do comando date. Nesse cenário, será criado: backup_2023-11-22.gz
    backup_directory="backup_$(date +%Y-%m-%d)"
      
    # programa de compressão mais utilizado no Linux. O gzip gera um arquivo no formato .gz.
    # As opções -c e -r respectivamente informam que queremos criar um arquivo e compactar.
    # Ao executarmos a compactação de vários arquivos utilizando o gzip, os arquivos serão concatenados em um só e em seguida comprimidos no formato .gz.
    # desenvolver backup incremental...
    gzip -c -r public_html > "$backup_directory".gz

    # excluirá a public_html
    rm -R public_html/

    # recriará a public_html
    mkdir public_html
}


wp_checking_directory() {
    # condicional com if utilizando o comando test [] com o argumento -z
    # nessa condicional, será verificado com a expressão -z, se o tamanho da string é zero. Se for verdadeiro, retorna true.
    # se tiver conteúdo, retorna false.
    # o conteúdo será verificado como string.
    if [[ -z "$(ls -A $PWD/public_html/)" ]]; then
        printf '\nProcessando instalação...\n\n'

    else
        printf '\npublic_html em uso. Realizando backup para seguir com instalação...\n\n'

        # função para compactar public_html;
        # deletar public_html;
        # recriar public_html.
        wp_compress
    fi
    # função para baixar versão mais recente do WordPress.
    wp_download
}

# cores no terminal
NO_FORMAT="\033[0m"
C_GREEN="\033[38;5;2m"

asciiart="

\n
${C_GREEN}
    _______________________________ 
    |  ___________________________  |
    | | Instalador WordPress lwsa | |
    | |___________________________| |
    |_______________________________|

${NO_FORMAT}
\n
"

printf "$asciiart"

sleep 5
clear 

# -------------------------------------------------------------
# chamando funções.
wp_checking_directory