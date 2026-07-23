==================================================================
  DOCKING MOLECULAR - AUTODOCK VINA (MODO POR ESTRUTURA)
  Script: docking_estruturas.bat
  Autor: Micliete Lopes Manuel Mussa
==================================================================

1. DESCRICAO GERAL
------------------------------------------------------------------
Este pacote automatiza o docking molecular offline de varios
complexos receptor-ligando, usando o AutoDock Vina e o Open Babel,
tudo por linha de comando (CMD), sem necessidade de repetir o
processo manualmente para cada estrutura.

Para cada subpasta dentro de "Estruturas\", o script:
  1. Deteta automaticamente o receptor (.pdb), o ligante (.sdf ou
     .pdb) e a gridbox (.txt), independentemente do nome do
     ficheiro.
  2. Corrige o formato decimal da gridbox (virgula -> ponto).
  3. Converte o receptor e o ligante para o formato .pdbqt
     (Open Babel).
  4. Executa o docking no AutoDock Vina (exhaustiveness=32,
     9 poses por ligante).
  5. Grava os resultados DENTRO da propria pasta da estrutura,
     em Estruturas\<NomeDaEstrutura>\resultados\
  6. Compila um resumo geral com as afinidades de todas as
     estruturas, na pasta principal.


2. PRE-REQUISITOS (INSTALAR ANTES DE USAR)
------------------------------------------------------------------
E OBRIGATORIO ter instalado no computador, ANTES de correr o
script:

  a) AutoDock Vina (executavel "vina.exe")
  -> Colocar o ficheiro "vina.exe" na MESMA pasta do
        "docking_estruturas.bat".

  b) Open Babel (para conversao de estruturas)
     Download: https://sourceforge.net/projects/openbabel/files/latest/download 
     -> Executar o setup e instalar

  c) BIOVIA Discovery Studio (para preparar o receptor e definir
     a gridbox - ver secao 3)
     Download (versao gratuita/Visualizer):
     https://www.3ds.com/products/biovia/discovery-studio


3. PREPARACAO DOS FICHEIROS DE ENTRADA (MUITO IMPORTANTE)
------------------------------------------------------------------
Antes de correr o script, cada estrutura (complexo receptor-
ligando) precisa de 3 ficheiros preparados manualmente:

  PASSO 1 - Obter a estrutura cristalografica
    Descarregar o ficheiro .pdb do complexo receptor-ligando de
    origem (ex: a partir do RCSB Protein Data Bank).

  PASSO 2 - Polir o receptor no Discovery Studio
    Abrir o ficheiro .pdb no BIOVIA Discovery Studio e:
      - Remover TODOS os heteroatomos que nao sejam de interesse
        (aguas, ioes, moleculas de cristalizacao, etc.).
      - Manter APENAS UMA cadeia proteica de interesse (caso a
        estrutura tenha varias copias/cadeias identicas, eliminar
        as restantes, mantendo so uma).
      - Guardar esta versao limpa como o ficheiro RECEPTOR
        (.pdb) desta estrutura.

  PASSO 3 - Definir a gridbox a partir do ligante nativo
    Ainda no Discovery Studio, na cadeia mantida no Passo 2:
      - Identificar o ligante nativo (co-cristalizado) presente
        nessa cadeia.
      - Obter as coordenadas (x, y, z) desse ligante, que servem
        de base para o centro da gridbox (o local onde o Vina vai
        procurar o encaixe do NOVO ligante a testar).
      - Registar essas coordenadas (centro e dimensoes da caixa
        de busca) num ficheiro de texto (.txt), no formato lido
        pelo Vina, por exemplo:

            center_x = 10.123
            center_y = -4.567
            center_z = 5.645
            size_x = 25
            size_y = 25
            size_z = 25

        (Se as coordenadas saírem com virgula decimal, ex:
        "10,123", nao ha problema - o script corrige isso
        automaticamente para "10.123" antes de correr o Vina.)

      - Guardar este ficheiro como a GRIDBOX (.txt) desta
        estrutura.

  PASSO 4 - Preparar o ligante a testar
    O ligante que se quer avaliar por docking (o composto de
    interesse, ex: resultante de uma triagem virtual/machine
    learning) deve estar num ficheiro separado, em formato .sdf
    (preferencial) ou .pdb.


4. ORGANIZACAO DAS PASTAS
------------------------------------------------------------------
Estrutura de pastas exigida pelo script:

  docking_estruturas.bat        <- o script
  vina.exe                      <- executavel do AutoDock Vina
  Estruturas\
      NomeDaEstrutura1\
          receptor.pdb          <- (Passo 2)
          ligante.sdf           <- (Passo 4)
          gridbox.txt           <- (Passo 3)
      NomeDaEstrutura2\
          ... (mesmos 3 ficheiros)
      NomeDaEstrutura3\
          ...

Observacoes:
  - O NOME da subpasta (ex: "NomeDaEstrutura1") e livre - e ele
    que aparece identificando essa estrutura nos resultados e no
    resumo geral. Sugestao: usar o codigo PDB ou o nome do
    complexo (ex: "Delamanid_InhA", "2f35").
  - Os NOMES dos ficheiros DENTRO de cada pasta sao livres - o
    script deteta automaticamente qual e o receptor, qual e o
    ligante e qual e a gridbox, pelo TIPO de ficheiro:
        .txt         -> gridbox
        .sdf         -> ligante (prioridade)
        .pdb (maior) -> receptor
        .pdb (2o)    -> ligante, SE nao houver .sdf na pasta
  - Cada estrutura pode ter um receptor e uma gridbox proprios
    (nao precisam de ser o mesmo receptor em todas as pastas).


5. COMO CORRER O SCRIPT
------------------------------------------------------------------
  1. Confirmar que "vina.exe" esta na mesma pasta do .bat.
  2. Confirmar que o comando "obabel" funciona no CMD.
  3. Confirmar que a pasta "Estruturas\" contem uma subpasta por
     estrutura, cada uma com os 3 ficheiros (receptor, ligante,
     gridbox), conforme a secao 4.
  4. Dar duplo clique em "docking_estruturas.bat" (ou correr a
     partir do CMD).
  5. Aguardar o processamento de todas as estruturas. O script
     mostra, para cada uma:
        - os ficheiros detetados (receptor / ligante / gridbox)
        - a preparacao do receptor e do ligante
        - as 9 poses geradas pelo Vina e as respetivas afinidades
          de ligacao (kcal/mol)
  6. No final, o script imprime "Terminado!" e um resumo geral
     com todas as estruturas processadas.


6. ONDE ENCONTRAR OS RESULTADOS
------------------------------------------------------------------
  Por estrutura (resultados individuais):
    Estruturas\<NomeDaEstrutura>\resultados\
        receptor.pdbqt            - recetor convertido
        ligante.pdbqt              - ligante convertido
        gridbox_corrigido.txt      - gridbox com pontos decimais
        ligante_out.pdbqt          - as 9 poses geradas pelo Vina
        ligante_out.log            - log completo do Vina
        resumo_afinidades.csv      - afinidades das 9 poses desta
                                      estrutura

  Resumo geral (todas as estruturas juntas):
    resumo_geral_afinidades.csv   - na mesma pasta do .bat


7. PROBLEMAS COMUNS
------------------------------------------------------------------
  "vina.exe nao encontrado nesta pasta"
    -> Confirmar que o ficheiro "vina.exe" esta na MESMA pasta
       do script (nao dentro de "Estruturas\").

  "obabel nao encontrado no PATH"
    -> Reinstalar o Open Babel e confirmar a opcao de adicionar
       ao PATH do sistema durante a instalacao. Testar abrindo o
       CMD e digitando "obabel -V".

  "Receptor: [NAO ENCONTRADO]" ou "Ligando: [NAO ENCONTRADO]"
    -> Confirmar que a subpasta da estrutura tem mesmo um .pdb
       (receptor) e um .sdf ou 2o .pdb (ligante). Se houver mais
       de um .pdb com tamanhos muito parecidos, e mais seguro
       fornecer o ligante em .sdf para evitar ambiguidade.

  Docking muito lento
    -> Normal com exhaustiveness=32 e muitas estruturas. Pode-se
       reduzir o valor de EXHAUSTIVENESS no topo do script (a
       custo de menor robustez na amostragem), se necessario.


==================================================================
Autor: Micliete Lopes Manuel Mussa
==================================================================
