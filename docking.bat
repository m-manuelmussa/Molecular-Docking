@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: =============================================================
:: DOCKING MOLECULAR OFFLINE - AutoDock Vina - MODO POR ESTRUTURA
:: DETECAO AUTOMATICA de recetor / ligando / gridbox por TIPO
:: DE FICHEIRO (nao exige nomes fixos dentro de cada pasta).
::
:: Cada subpasta dentro de "Estruturas\" representa UMA estrutura
:: receptor-ligando INDEPENDENTE. Dentro de cada subpasta, o
:: script detecta automaticamente:
::   - Gridbox  -> qualquer ficheiro .txt
::   - Ligando  -> qualquer ficheiro .sdf (prioridade); se nao
::                 houver .sdf, usa o SEGUNDO maior .pdb da pasta
::   - Receptor -> o MAIOR ficheiro .pdb da pasta (por tamanho)
::
:: Resultados de CADA estrutura sao gravados DENTRO da sua propria
:: pasta, em Estruturas\<NomeDaEstrutura>\resultados\
:: =============================================================

:: -------------------------------------------------------------
:: CONFIGURACAO -- ajuste se necessario
:: -------------------------------------------------------------
set VINA_EXE=vina.exe

set COMPLEXES_DIR=Estruturas
set RESULTS_SUBDIR=resultados
set LOCAL_SUMMARY_CSV=resumo_afinidades.csv

set EXHAUSTIVENESS=32
set NUM_MODES=9

:: Resumo consolidado de TODOS os complexos, gravado na pasta do script
set GLOBAL_SUMMARY_CSV=resumo_geral_afinidades.csv

echo ============================================
echo   Docking Molecular - Autodock Vina
echo   Desenvolvedor: Micliete Lopes Manuel Mussa
echo ============================================
echo.

:: -------------------------------------------------------------
:: Verificacoes previas
:: -------------------------------------------------------------
if not exist "%VINA_EXE%" (
    echo [ERRO] %VINA_EXE% nao encontrado nesta pasta.
    goto :fim
)
where obabel >nul 2>&1
if errorlevel 1 (
    echo [ERRO] obabel nao encontrado no PATH. Instale o Open Babel para Windows.
    goto :fim
)
if not exist "%COMPLEXES_DIR%\" (
    echo [ERRO] Pasta de estruturas nao encontrada: %COMPLEXES_DIR%\
    echo         Crie a pasta "%COMPLEXES_DIR%" com uma subpasta por estrutura,
    echo         cada uma contendo o receptor ^(.pdb^), o ligante ^(.sdf ou .pdb^)
    echo         e a gridbox ^(.txt^), com QUALQUER nome de ficheiro.
    goto :fim
)

set COMPLEX_COUNT=0
for /d %%d in ("%COMPLEXES_DIR%\*") do set /a COMPLEX_COUNT+=1
if %COMPLEX_COUNT%==0 (
    echo [ERRO] Nenhuma subpasta de estrutura encontrada em %COMPLEXES_DIR%\
    goto :fim
)

echo [OK] %COMPLEX_COUNT% Estruturas(s) encontrada(s)
echo.

:: Cabecalho do resumo geral (consolidado)
echo Estrutura,Ligando,Pose,Afinidade_kcal_mol,Ficheiro_Saida,Ficheiro_Log > "%GLOBAL_SUMMARY_CSV%"

:: -------------------------------------------------------------
:: LOOP PRINCIPAL: PARA CADA COMPLEXO (subpasta) -> DOCKING COMPLETO
:: -------------------------------------------------------------
set /a IDX=0
for /d %%d in ("%COMPLEXES_DIR%\*") do (
    set /a IDX+=1
    set "COMPLEX_DIR=%%d"
    set "COMPLEX_NAME=%%~nd"

    echo ============================================
    echo   [!IDX!/%COMPLEX_COUNT%] Estrutura: !COMPLEX_NAME!
    echo ============================================

    :: -----------------------------------------------------------
    :: DETECAO AUTOMATICA DOS FICHEIROS DENTRO DA PASTA DA ESTRUTURA
    :: -----------------------------------------------------------
    set "RECEPTOR_PDB="
    set "LIGAND_FILE="
    set "GRIDBOX_FILE="
    set "SDF_COUNT=0"
    set "TXT_COUNT=0"
    set "PDB_COUNT=0"

    :: --- Gridbox: qualquer .txt (usa o primeiro encontrado) ---
    for %%f in ("!COMPLEX_DIR!\*.txt") do (
        set /a TXT_COUNT+=1
        if not defined GRIDBOX_FILE set "GRIDBOX_FILE=%%f"
    )

    :: --- Ligando: qualquer .sdf (prioridade sobre .pdb) ---
    for %%f in ("!COMPLEX_DIR!\*.sdf") do (
        set /a SDF_COUNT+=1
        if not defined LIGAND_FILE set "LIGAND_FILE=%%f"
    )

    :: --- PDBs ordenados do MAIOR para o MENOR (por tamanho) ---
    :: O maior .pdb = receptor. Se nao houver .sdf, o 2o maior .pdb = ligando.
    :: (usa ficheiro temporario em vez de "for /f" com "dir" embutido, para
    ::  evitar erros de parsing do CMD quando aninhado em varios parenteses)
    set "PDBLIST_TMP=%TEMP%\pdblist_%RANDOM%_%RANDOM%.txt"
    dir /b /o-s "!COMPLEX_DIR!\*.pdb" > "!PDBLIST_TMP!" 2>nul
    for /f "usebackq delims=" %%f in ("!PDBLIST_TMP!") do (
        set /a PDB_COUNT+=1
        if !PDB_COUNT!==1 set "RECEPTOR_PDB=!COMPLEX_DIR!\%%f"
        if !PDB_COUNT!==2 if not defined LIGAND_FILE set "LIGAND_FILE=!COMPLEX_DIR!\%%f"
    )
    del "!PDBLIST_TMP!" >nul 2>&1

    echo   Ficheiros detectados:
    if defined RECEPTOR_PDB (echo     Receptor: !RECEPTOR_PDB!) else (echo     Receptor: [NAO ENCONTRADO])
    if defined LIGAND_FILE  (echo     Ligando:  !LIGAND_FILE!)  else (echo     Ligando:  [NAO ENCONTRADO])
    if defined GRIDBOX_FILE (echo     Gridbox:  !GRIDBOX_FILE!) else (echo     Gridbox:  [NAO ENCONTRADA])
    if !TXT_COUNT! GTR 1 echo     [AVISO] Mais de um .txt encontrado; usada a primeira gridbox.
    if !SDF_COUNT! GTR 1 echo     [AVISO] Mais de um .sdf encontrado; usado o primeiro como ligando.
    if !PDB_COUNT! GTR 2 echo     [AVISO] Mais de dois .pdb encontrados; ignorados os restantes.

    :: --- Validacao ---
    set "FALHOU="
    if not defined RECEPTOR_PDB (
        echo   [ERRO] Nenhum .pdb encontrado para servir de receptor.
        set "FALHOU=1"
    )
    if not defined LIGAND_FILE (
        echo   [ERRO] Nenhum ligante encontrado ^(.sdf ou 2o .pdb^).
        set "FALHOU=1"
    )
    if not defined GRIDBOX_FILE (
        echo   [ERRO] Nenhuma gridbox ^(.txt^) encontrada.
        set "FALHOU=1"
    )

    if defined FALHOU (
        echo   -^> Estrutura !COMPLEX_NAME! ignorada por falta de ficheiros.
        echo !COMPLEX_NAME!,,,ERRO_FICHEIROS_EM_FALTA,,>> "%GLOBAL_SUMMARY_CSV%"
        echo.
    ) else (
        set "RESULTS_DIR=!COMPLEX_DIR!\%RESULTS_SUBDIR%"
        if not exist "!RESULTS_DIR!" mkdir "!RESULTS_DIR!"

        :: --- Corrigir virgula decimal na gridbox deste complexo ---
        set "GRIDBOX_FIXED=!RESULTS_DIR!\gridbox_corrigido.txt"
        echo   -^> Corrigindo formato decimal da gridbox...
        powershell -NoProfile -Command "(Get-Content '!GRIDBOX_FILE!') -replace '(?<=\d),(?=\d)', '.' | Set-Content '!GRIDBOX_FIXED!'"

        :: --- Preparar receptor (PDB -> PDBQT) ---
        set "RECEPTOR_PDBQT=!RESULTS_DIR!\receptor.pdbqt"
        echo   -^> Preparando receptor...
        obabel "!RECEPTOR_PDB!" -O "!RECEPTOR_PDBQT!" -xr -h --partialcharge gasteiger >nul 2>&1

        :: --- Preparar ligando (SDF/PDB -> PDBQT) ---
        set "LIGAND_PDBQT=!RESULTS_DIR!\ligante.pdbqt"
        echo   -^> Preparando ligante...
        obabel "!LIGAND_FILE!" -O "!LIGAND_PDBQT!" -h --partialcharge gasteiger >nul 2>&1
        :: Se a geometria 3D de partida nao for confiavel, use antes:
        :: obabel "!LIGAND_FILE!" -O "!LIGAND_PDBQT!" -h --partialcharge gasteiger --gen3d >nul 2>&1

        if not exist "!RECEPTOR_PDBQT!" (
            echo   [ERRO] Falha na preparacao do receptor de !COMPLEX_NAME!.
            echo !COMPLEX_NAME!,,,ERRO_PREPARACAO_RECEPTOR,,>> "%GLOBAL_SUMMARY_CSV%"
        ) else if not exist "!LIGAND_PDBQT!" (
            echo   [ERRO] Falha na preparacao do ligante de !COMPLEX_NAME!.
            echo !COMPLEX_NAME!,,,ERRO_PREPARACAO_LIGANDO,,>> "%GLOBAL_SUMMARY_CSV%"
        ) else (
            set "OUTPUT_PDBQT=!RESULTS_DIR!\ligante_out.pdbqt"
            set "LOG_FILE=!RESULTS_DIR!\ligante_out.log"

            echo   -^> Executando docking ^(exhaustiveness=%EXHAUSTIVENESS%, num_modes=%NUM_MODES%^)...
            "%VINA_EXE%" --receptor "!RECEPTOR_PDBQT!" --ligand "!LIGAND_PDBQT!" --config "!GRIDBOX_FIXED!" --exhaustiveness %EXHAUSTIVENESS% --num_modes %NUM_MODES% --out "!OUTPUT_PDBQT!" > "!LOG_FILE!" 2>&1

            if not exist "!OUTPUT_PDBQT!" (
                echo   [ERRO] Vina nao gerou saida para !COMPLEX_NAME!.
                echo !COMPLEX_NAME!,,,ERRO_DOCKING,,!LOG_FILE!>> "%GLOBAL_SUMMARY_CSV%"
            ) else (
                :: --- Resumo LOCAL deste complexo (uma linha por pose) ---
                echo Ligando,Pose,Afinidade_kcal_mol,Ficheiro_Saida,Ficheiro_Log > "!RESULTS_DIR!\%LOCAL_SUMMARY_CSV%"

                set "POSES_ENCONTRADAS=0"
                for /f "tokens=1,2" %%a in ('findstr /r /c:"^   [1-9] " "!LOG_FILE!"') do (
                    set /a POSES_ENCONTRADAS+=1
                    echo     Pose %%a: %%b kcal/mol
                    echo !COMPLEX_NAME!,%%a,%%b,!OUTPUT_PDBQT!,!LOG_FILE!>> "!RESULTS_DIR!\%LOCAL_SUMMARY_CSV%"
                    echo !COMPLEX_NAME!,!COMPLEX_NAME!,%%a,%%b,!OUTPUT_PDBQT!,!LOG_FILE!>> "%GLOBAL_SUMMARY_CSV%"
                )

                if "!POSES_ENCONTRADAS!"=="0" (
                    echo   [AVISO] Nao foi possivel extrair poses do log de !COMPLEX_NAME!.
                    echo !COMPLEX_NAME!,,N/D,!OUTPUT_PDBQT!,!LOG_FILE!>> "!RESULTS_DIR!\%LOCAL_SUMMARY_CSV%"
                    echo !COMPLEX_NAME!,,,N/D,!OUTPUT_PDBQT!,!LOG_FILE!>> "%GLOBAL_SUMMARY_CSV%"
                ) else (
                    echo   !POSES_ENCONTRADAS! pose^(s^) registada^(s^).
                    echo   Resultados em: !RESULTS_DIR!\
                )
            )
        )
    )
    echo.
)

echo ============================================
echo   Terminado!
echo ============================================
echo.

:: -------------------------------------------------------------
:: RESUMO FINAL NO CMD
:: -------------------------------------------------------------
echo ============================================
echo   RESUMO GERAL - TODAS AS ESTRUTURAS
echo ============================================
echo.
echo Estrutura            Pose    Afinidade
echo --------------------------------------------
for /f "skip=1 tokens=1,3,4 delims=," %%a in (%GLOBAL_SUMMARY_CSV%) do (
    echo %%~a              %%~b       %%~c
)
echo.
echo Resumo consolidado (todas as estruturas): %GLOBAL_SUMMARY_CSV%
echo Resultados individuais em: %COMPLEXES_DIR%\^<NomeDaEstrutura^>\%RESULTS_SUBDIR%\
echo.

:fim
echo.
pause
