# Geometria da primeira cena na RTX 3060

## Resultado de 24 de novembro de 2026

Na variante experimental `Geometria`, a janela mostrou uma figura humana em azul-esverdeado, cabos suspensos e partes de postes e coberturas durante a abertura. A captura foi feita diretamente da janela da RTX 3060 no modo Series X. O port passou a apresentar o primeiro alvo RGBA8 de 2560 × 1440 após o envio das primeiras listas com malhas. A silhueta e as estruturas mudaram entre quadros. Grande parte da rua continuou preta e a execução terminou com `DXGI_ERROR_DEVICE_HUNG`. O pátio da prisão e a iluminação da cena completa continuam sem confirmação. [Como testar a variante](../MANUAL.md#ver-a-geometria-da-cena)

A variante usa a revisão pública `97c78d10`, as adaptações do laboratório para Wave64, memória e descritores, e a seleção de alvo de cor do PR #414, ativada apenas depois das primeiras malhas. O lançador pré-compila localmente os shaders e prepara os pipelines cujos identificadores coincidem com a lista observada. O vídeo e os dados do título ficam na máquina do usuário. [Base do VIctory](https://github.com/Marvisak/VIctory/commit/97c78d1087808bd6ce5eabb5d566083a38406a90) · [Seleção do alvo de cor](https://github.com/Marvisak/VIctory/commit/42ac20c5af01eacd598bb723cdde30990d058f59)

A janela da integração pública #414 permaneceu preta até a falha de D3D12. O pacote local foi GTA VI para Xbox v1.0.2.1, com perfil de missão copiado e modo Series X. A apresentação do primeiro alvo RGBA8 de 2560 × 1440 também foi testada. O port usado nesses ensaios é o VIctory com Direct3D 12. [Revisão da integração](https://github.com/Marvisak/VIctory/commit/d3917df4)

O primeiro bloqueio aconteceu antes do primeiro quadro. O título pediu uma reserva contígua de 193.986.560 bytes no espaço de endereços de 32 bits. O Windows informou erro 8 e o maior intervalo livre tinha 14.352.384 bytes. No início do processo ainda havia um intervalo livre superior a 2 GiB. Uma reserva antecipada de espaço virtual permitiu atender o pedido e chegar aos pipelines de malha. Na execução que apresentou o alvo RGBA8, o fechamento de uma lista de comandos falhou com `0x80070057`. Em outra execução, com apresentação normal, a GPU deixou de responder durante uma submissão de sete listas (`0x887A0006`).

## Quais shaders já passam

A numeração abaixo começa em um e conta cada hash de contêiner uma vez, na ordem do catálogo local. Para cada hash, o teste leu os bytes instalados, verificou a identidade por BLAKE3, traduziu para o adaptador e pediu ao driver um pipeline com um estágio complementar mínimo. Também verificou o DXIL com o validador. [Definição do catálogo e outra numeração](shaders-e-wave64.md)

| Nº local | Hash | Integração #414 | Branch Wave64 #189 |
| --- | --- | --- | --- |
| 2400 | `6090b5a95d346286` | DXIL validado e pipeline criado | DXIL validado e pipeline criado |
| 2401 | `d10a91ed62fa6c29` | DXIL validado e pipeline criado | Leitura escalar sem tradução em `0x3144` |
| 2402 | `f851519164999225` | DXIL validado e pipeline criado | Leitura escalar sem tradução em `0x5e2c` |

O compute `00bcbbf278ee3d9d` apareceu no log do jogo. A integração #414 recusou a largura de 64 lanes. O #189 selecionou Wave32 na RTX 3060, gerou DXIL válido e criou o pipeline de compute. A execução de um trabalho com dados conhecidos e a medição dos pixels da missão são verificações separadas. Os computes `5b2ce592c3a5dd09` e `89d08e561897d4e5` ainda param no #189 em acessos a memória compartilhada (LDS) sem uma barreira uniforme demonstrada. [Revisão Wave64 testada](https://github.com/Marvisak/VIctory/commit/c0478853)

As malhas `910b4be059bfb28f` e `321d411b20a35ef9` falharam nas duas revisões. Na integração o tradutor parou ao reconstruir um descritor a partir da primeira lane. No #189 chegou a uma leitura escalar usada como dado. Para acompanhar a imagem e o aquecimento no lançador publicado, consulte o [manual](../MANUAL.md).

Dos 239 hashes com pendências observados no ensaio anterior da missão, 152 passaram em tradução, validação e criação de pipeline na integração #414. Dos 321 shaders antes bloqueados por Wave64 fixa, 98 passaram nos três testes. Nos casos que a integração ainda recusou por Wave64, o tradutor #189 recuperou outros 45 dos 321, incluindo seis dos 239 da missão. Há sobreposição entre esses dois conjuntos. Os números descrevem testes isolados na placa, feitos em revisões distintas da variante visual.
