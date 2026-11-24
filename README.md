# VIctory na RTX 3060

**Primeira vez?** O [manual de instalação e uso](MANUAL.md) acompanha a compilação no Windows e o primeiro início com uma instalação completa do jogo. A primeira cutscene ainda aparece escura na RTX 3060. A [atualização dos testes](docs/diagnostico-rtx3060.md) mostra onde a cor se perde e quanto trabalho chega à GPU.

Scripts para compilar o VIctory no Windows e iniciar a instalação local de GTA VI para Xbox. As variantes de execução e diagnóstico originais usam a revisão `015d45bf`. A sonda HDR usa a revisão `35b054ec`. O Cargo gera o executável na máquina de quem for usar. Os arquivos do jogo vêm da própria instalação. [Base de execução](https://github.com/Marvisak/VIctory/tree/015d45bfff4d82e7afad89afe10dd24e5a402ef8) · [Base da sonda](https://github.com/Marvisak/VIctory/tree/35b054ec038c11bc8a0de66b1eee764b1ad4f101)

## Até onde o jogo chegou

**Para ver a rua em 3D, use a variante experimental `CoresPlanas`.** Em modo Series X na RTX 3060, a janela mostrou a pista, postes, fios e a estrutura de um prédio com a câmera em movimento. Parte das superfícies continua preta. [Manual de cores planas](MANUAL.md#mostrar-a-rua-em-cores-planas)

Em modo Series X, a variante experimental `Geometria` mostrou na janela uma silhueta humana, cabos e partes da rua. Ela exibe um alvo de cor intermediário do jogo após a primeira submissão de malhas. A iluminação e grande parte do cenário continuam ausentes. Em um teste separado, os shaders locais 2400, 2401 e 2402 passaram pelo validador e pelo driver na integração #414. [Como experimentar](MANUAL.md#ver-a-geometria-da-cena) · [Resultados por shader](docs/geometria-e-wave64.md)

Com GTA VI para Xbox v1.0.2.1 e uma GeForce RTX 3060 de 12 GB, a correção eliminou a piscada periódica nas seis capturas afetadas durante a configuração. O jogo gravou o perfil, passou pela configuração na reinicialização e entrou na primeira missão. A janela mostrou os créditos de abertura sobre fundo preto, com áudio estéreo do jogo. O cenário, os personagens e suas texturas continuaram invisíveis. Movimento, câmera e cinco minutos de jogo no mundo aberto ainda precisam de validação visual.

| Variante | Resultado observado |
| --- | --- |
| `Execucao` | Corrige a tabela de descritores compartilhada pelos shaders. Foi a variante usada para registrar os créditos e o áudio da introdução. |
| `Diagnostico` | Adapta algumas operações Wave64, prepara pipelines observados e captura os primeiros quadros com malhas 3D. No teste isolado do catálogo, a RTX aceitou 25 dos 321 pipelines de compute que a variante padrão perdeu por exigir Wave64. Os 28 primeiros quadros 3D capturados em um ensaio anterior no modo Series X continuaram escuros. |
| `SondaHDR` | Variante de investigação sobre `35b054ec`. Mede as texturas HDR, os argumentos de compute e a composição nos quadros após o letreiro. [Instruções para reproduzir](docs/diagnostico-rtx3060.md#reproduzir-a-sonda) |

## Compilar

Use Windows 10 ou 11 x64, CPU com AVX2 e GPU Direct3D 12 com Shader Model 6.6 e suporte a mesh shaders. Instale o Git, o Rust via rustup para `x86_64-pc-windows-msvc` e as ferramentas de compilação do Visual Studio com a carga de trabalho **Desenvolvimento para desktop com C++** e o Windows SDK.

Abra o PowerShell para baixar e compilar o projeto.

```powershell
git clone https://github.com/luiksksk/gta6-victory-rtx3060.git
cd gta6-victory-rtx3060
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao Compilar
```

O script busca o commit exato do VIctory, aplica o patch, confere a árvore Git e compila com Rust `1.98.1` e `Cargo.lock`. A opção `RemoteSigned` aplica-se ao processo de PowerShell desse comando. As fontes e a compilação ficam em `%LOCALAPPDATA%\VIctory-RTX3060-Publico`.

## Executar

Ao iniciar, o lançador aguarda a pré-compilação dos shaders identificáveis na instalação. O terminal mostra a porcentagem e quantos shaders o VIctory traduziu ou rejeitou. Na v1.0.2.1, a variante padrão traduziu 22.160 dos 25.985 shaders. O cache fica na máquina do usuário. [Como funciona a preparação](MANUAL.md#3-abra-o-jogo)

Nos 30 segundos após a legenda de localização, os erros e descartes da primeira missão citaram 239 shaders por hash. Para 76 deles, o relatório registrou chamadas descartadas por quadro. A investigação também identificou a que correspondem os números 2400, 2401 e 2402 nas duas contagens do arquivo. [Resultados na RTX 3060](docs/shaders-e-wave64.md) · [Lista dos 239 shaders](docs/shaders-eventos-30s.csv)

Dos 22.160 shaders traduzidos, 21.839 criaram pipeline em testes isolados na placa. Os 321 recusados exigiam Wave64. O validador do Windows SDK também encontrou erros em 179 shaders aceitos pelo driver. [Teste por estágio e por hash](docs/shaders-e-wave64.md#teste-de-todos-os-shaders-traduzidos)

Aponte o lançador para a pasta que contém `game_scarlett_master.exe`. O caminho abaixo é um exemplo.

```powershell
.\Iniciar-VIctory.cmd -PastaJogo "D:\Jogos\GTA VI"
```

Também é possível abrir `Iniciar-VIctory.cmd` com dois cliques e informar a pasta. Cada variante mantém seus próprios saves e configurações em `%LOCALAPPDATA%\VIctory-RTX3060-Publico\dados` e seus arquivos de cache em `cache`.

Para começar com uma cópia de um perfil do VIctory, informe a pasta que contém a subpasta do título `7952987A`. Na primeira execução, o lançador copia `saves` e `storage\settings` para o perfil da variante. Nas seguintes, use apenas `-PastaJogo`.

```powershell
.\Iniciar-VIctory.cmd -PastaJogo "D:\Jogos\GTA VI" -PerfilOrigem "D:\Perfis\VIctory\data"
```

## Investigar a tela preta

Compile a variante de diagnóstico e confira a configuração antes de abrir o jogo. O parâmetro `-Console series-s` permite repetir o ensaio nesse modo na mesma placa.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao Compilar -Variante Diagnostico
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao Config -Variante Diagnostico -PastaJogo "D:\Jogos\GTA VI"
```

Para registrar a imagem apresentada e os alvos de cor intermediários, execute os comandos abaixo em uma sessão do PowerShell.

```powershell
$capturas = Join-Path $env:LOCALAPPDATA ("VIctory-RTX3060-Publico\capturas\" + (Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $capturas | Out-Null
$env:VICTORY_CAPTURE = $capturas
$env:VICTORY_CAPTURE_MESH_FRAMES = "16"
$env:VICTORY_DUMP_MESH_TARGETS = "1"
$env:VICTORY_QUEUE_TRACE = "1"
.\Iniciar-VIctory.cmd -Variante Diagnostico -Console series-s -PastaJogo "D:\Jogos\GTA VI"
```

Os arquivos `frame-N.png` registram os quadros apresentados. Os nomes com `mesh-rtv` identificam alvos de cor de uma etapa anterior. No ensaio em modo Series S, um desses alvos tinha pixels coloridos, e os 16 quadros apresentados continuaram escuros.

## Origem e licença

Os patches modificam o VIctory, de Marvisak e colaboradores. Os scripts e as modificações publicados aqui seguem a mesma licença, **GPL-3.0-or-later**. [Projeto VIctory](https://github.com/Marvisak/VIctory) · [Texto da licença](LICENSE)
