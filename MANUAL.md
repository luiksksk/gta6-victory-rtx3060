# Como iniciar o VIctory no Windows

Este guia é para quem já tem a **instalação completa de GTA VI para Xbox**. O teste foi feito com a versão 1.0.2.1 e uma RTX 3060 de 12 GB. Você vai compilar o VIctory no seu computador e indicar onde o jogo está instalado. **O estado atual é experimental.** Já foi possível entrar na primeira missão e ouvir o áudio. Depois de “Vice City, dois anos atrás”, personagens e cenário ainda ficam escuros.

## 1. Prepare o computador

Use Windows 10 ou 11 de 64 bits, processador com AVX2 e placa Direct3D 12 com Shader Model 6.6 e mesh shaders. Localize a pasta que contém `game_scarlett_master.exe` junto dos demais arquivos da sua instalação. Anote o caminho dessa pasta.

Instale estas três ferramentas, uma vez por computador.

1. **Git para Windows** para baixar o código. [Instalador oficial do Git](https://git-scm.com/downloads/win)
2. **Build Tools do Visual Studio**. No instalador, marque **Desenvolvimento para desktop com C++**, incluindo MSVC para x64 e o Windows SDK. [Instalador da Microsoft](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
3. **Rust via rustup**. Use a instalação para Windows x64 com MSVC. Depois, abra uma **nova** janela do PowerShell e rode o comando abaixo para instalar a versão usada pelo projeto. [Instalador oficial do Rust](https://rustup.rs/)

```powershell
rustup toolchain install 1.98.1-x86_64-pc-windows-msvc
```

## 2. Baixe e compile

No PowerShell, abra uma pasta onde você costuma guardar projetos. Execute uma linha de cada vez.

```powershell
git clone https://github.com/luiksksk/gta6-victory-rtx3060.git
cd gta6-victory-rtx3060
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao Compilar
```

A primeira compilação baixa as dependências e pode demorar. Espere a mensagem **Compilado em** seguida do caminho de `victory.exe`. Esse arquivo é gerado localmente. Quem já clonou o repositório pode executar `git pull --ff-only` dentro da pasta antes de compilar.

## 3. Abra o jogo

Na pasta que você clonou, dê dois cliques em **Iniciar-VIctory.cmd**. Quando a janela pedir a instalação, cole o caminho da pasta do jogo e pressione Enter. Se preferir iniciar pelo PowerShell, substitua o caminho do exemplo pelo seu.

```powershell
.\Iniciar-VIctory.cmd -PastaJogo "D:\Jogos\GTA VI"
```

Antes de abrir a janela do jogo, o terminal mostra **Shaders 0% a 100%**. A etapa verifica os shaders encontrados em `shaders.rpf`, no executável do título e nas DLLs ao lado dele. O contador usa shaders distintos. **Prontos** inclui os compilados agora e os recuperados do cache. **Incompatíveis** conta os que a versão instalada do VIctory ainda não consegue traduzir. O jogo só começa quando todos os shaders encontrados tiverem sido processados. Se a instalação ou o cache não puderem ser lidos, o lançador exibe o erro e interrompe o início.

Na segunda abertura, o VIctory reaproveita os resultados do mesmo build. Uma atualização do jogo pode acrescentar shaders. Uma recompilação que mude o binário exige nova preparação.

**O que esperar na RTX 3060.** No teste com a v1.0.2.1 e a variante `Execucao`, a primeira preparação chegou a 100% em 2 min 16 s, e a janela abriu em 2 min 19 s. Apareceram **22.160 prontos e 3.825 incompatíveis**. Repetir a preparação com o cache aquecido levou 4,4 s. O contador “prontos” confirma que o VIctory produziu a tradução. Durante o jogo, o driver ainda combina shaders e estados gráficos em pipelines. Nessa placa, ele recusou 321 shaders traduzidos que exigem Wave64. A introdução pode continuar com áudio e créditos sobre fundo escuro mesmo depois de 100%. [Shaders identificados na missão e testes de Wave64](docs/shaders-e-wave64.md)

Se quiser preparar o cache agora e abrir o jogo em outro momento, use o PowerShell na pasta do lançador.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao PrepararShaders -PastaJogo "D:\Jogos\GTA VI"
```

O padrão é o modo Series X. O lançador usa uma pasta própria para o perfil em `%LOCALAPPDATA%\VIctory-RTX3060-Publico\dados\Execucao`. Para abrir de novo, basta usar o mesmo lançador. Para importar uma **cópia** de um perfil que você já usa no VIctory, consulte as [instruções de perfil](README.md#executar).

### Testar a adaptação de Wave64

A variante `Diagnostico` inclui a adaptação testada em 25 shaders de compute. Para experimentá-la, compile essa variante e abra-a com a sua instalação. Ela usa seu próprio perfil e seu próprio cache. Os testes da primeira missão ainda mostraram a cena escura.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\VIctory.ps1 -Acao Compilar -Variante Diagnostico
.\Iniciar-VIctory.cmd -Variante Diagnostico -PastaJogo "D:\Jogos\GTA VI"
```

## Ver a geometria da cena

A variante experimental `Geometria` mostrou uma figura humana, fios e estruturas da rua na RTX 3060 de 12 GB. O modo testado foi **Series X**. A abertura e os menus usam a apresentação normal. Quando começam os desenhos de malha, a janela passa a mostrar uma das superfícies de cor do jogo. Ainda há quadros pretos e o driver pode encerrar a execução antes do pátio.

1. Na pasta deste repositório, compile a variante e espere a mensagem de conclusão.

   ```powershell
   .\VIctory.ps1 -Acao Compilar -Variante Geometria
   ```

2. Inicie com a pasta da sua instalação completa. A porcentagem indica quanto do catálogo de shaders foi processado. Ao chegar a 100%, o lançador mostra os totais prontos e incompatíveis e abre o jogo.

   ```powershell
   .\Iniciar-VIctory.cmd -Variante Geometria -Console series-x -PastaJogo "D:\Jogos\GTA VI"
   ```

3. Para começar com um perfil configurado, acrescente `-PerfilOrigem "D:\Perfis\VIctory\data"` na primeira execução. Use os controles habituais para entrar na missão. A lista de pipelines observados acompanha o repositório e contém somente identificadores. Os shaders são lidos na sua instalação.


## Se algo impedir o início

| O que apareceu | O que fazer |
| --- | --- |
| Comando `git` ou `rustup` desconhecido | Conclua a instalação correspondente e abra um novo PowerShell. |
| Erro com `link.exe` ou Windows SDK durante a compilação | Abra o Visual Studio Installer, escolha **Modificar** e confira os componentes de C++ x64 e Windows SDK. Depois repita a compilação. |
| “Compile primeiro” | Volte ao passo 2 e aguarde a mensagem **Compilado em**. |
| “Executavel do titulo ausente” | Abra a pasta no Explorador e confira se `game_scarlett_master.exe` está diretamente nela. Informe essa pasta ao lançador. O restante da instalação completa também precisa estar presente. |
| Créditos e áudio sobre fundo escuro | É o defeito reproduzido na primeira missão. Anote a legenda que apareceu, o modelo da GPU e a variante usada se for relatar o resultado. [Resultados da investigação](docs/diagnostico-rtx3060.md) |
