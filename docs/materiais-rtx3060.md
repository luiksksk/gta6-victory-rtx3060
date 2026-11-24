# Materiais e iluminação da primeira cutscene

A variante experimental `Materiais` executa os shaders de pixels do título. Ela prepara os recursos que os shaders selecionam diretamente pelo índice no heap de descritores, inclusive texturas carregadas por streaming. O ponto de comparação é a rua que apareceu na variante `CoresPlanas` após o letreiro de Vice City. O teste usa Windows, RTX 3060 de 12 GB, Ryzen 5 5600GT, o perfil Series X e uma instalação local completa da versão 1.0.2.1. [Coordenação e resultados dos colaboradores](https://github.com/luiksksk/gta6-victory-rtx3060/issues/2)

## Reproduzir

Na raiz deste repositório, após instalar os pré-requisitos do manual, faça a compilação e inicie com o caminho da sua instalação.

```powershell
.\VIctory.ps1 -Acao Compilar -Variante Materiais
.\Iniciar-VIctory.cmd -Variante Materiais -Console series-x -PastaJogo "D:\Jogos\GTA VI"
```

O lançador prepara o catálogo antes de abrir a janela e mostra a porcentagem concluída. A variante usa perfil e cache próprios. Para entrar na missão com uma cópia de um perfil já configurado, acrescente `-PerfilOrigem` na primeira execução. A apresentação escolhe o alvo RGBA8 de 2560 × 1440 observado na rua. Os comandos indiretos são habilitados depois de 24 quadros com malhas. [Pré-requisitos e uso do perfil](../MANUAL.md)

## Código e verificação

A árvore de fontes da variante é `6fc6ceb882461675a417fe9160a194aea8df43ea`. O lançador verifica essa identidade antes de compilar. O primeiro conjunto de mudanças prepara as texturas e os buffers acessados diretamente pelo índice do descritor e mantém os recursos vivos durante a submissão. [Patch da variante](../patches/materiais-wave32.patch) · [Revisão de origem do trabalho com descritores](https://github.com/Marvisak/VIctory/commit/51f447b56a307bd5b469f31f803ac8be73fab3ac)

Quando a placa informa largura mínima e máxima de 32 lanes, o carregador confere se a declaração do DXIL cabe nessa largura. Quando a tradução principal falha ou produz uma largura incompatível, ele tenta a integração de materiais e a alternativa de compute para Wave32. Shaders que exigem uma tabela adicional de strides só podem usar a alternativa se o backend puder representar seus vínculos. [Tradutor de materiais](https://github.com/Marvisak/VIctory/commit/d3917df4e9ab836f8bbf997590310cf40c835202) · [Tradutor Wave32](https://github.com/Marvisak/VIctory/commit/c04788537417107677d8dc5a90484f217ee22d2f)

Uma experiência adicional grava a cópia de uma textura para a GPU quando os dados de staging mudam. O patch se aplica sobre a árvore `6fc6ceb8` e foi compilado separadamente. [Patch de cópias condicionais](../patches/uploads-texturas-alteradas.patch) · [Trabalho de origem](https://github.com/Marvisak/VIctory/commit/6a96adbf)

## Medições na RTX 3060

As amostras abaixo cobrem os primeiros dez segundos de relógio após a primeira apresentação do alvo de cena de cada execução. CPU é o tempo de usuário mais kernel do processo dividido pelo tempo observado e pelos 12 processadores lógicos. GPU é a fração de tempo que o Windows atribuiu ao processo no motor 3D da placa. A cobertura dos contadores foi de 9,5 a 9,8 segundos.

| Ensaio | Quadro inicial | CPU do processo | Motor 3D do processo |
| --- | ---: | ---: | ---: |
| Referência com cores planas | 3181 | 16,5% | 24,3% |
| Primeiro ensaio com materiais indexados e listas isoladas | 3100 | 14,8% | 18,4% |

O segundo ensaio processou 22.206 de 25.985 shaders com sucesso no tradutor original. A janela exibiu alguns contornos e a cena continuou majoritariamente preta. O processo terminou com remoção do dispositivo. Na última amostra do runtime, cada quadro levou 2.567 ms, dos quais 550 ms foram contabilizados na preparação de descritores e 969 ms na cópia de volta. A captura de alvos acrescentou trabalho e as câmeras avançaram a velocidades diferentes. Essa comparação não estabelece um ganho de FPS.

## O que uma contribuição pode confirmar

- **Texturas.** Mostrar que um mesmo desenho usa o recurso e o mip esperados, retorna uma amostra de cor e preserva essa cor até o alvo apresentado.
- **Iluminação.** Identificar o primeiro passe em que a entrada HDR com conteúdo vira zero e registrar onde esse recurso é consumido.
- **Personagens.** Capturar a mesma malha em dois quadros da missão com posição, material e movimento identificáveis. As ilustrações da tela de carregamento aparecem antes desse trecho.
- **CPU e GPU.** Repetir o mesmo evento com uma única mudança, anotando ocupação do motor 3D, tempo de preparo, cópias de volta e desenhos descartados. [Histórico de shaders e falhas DRED](geometria-e-wave64.md)
