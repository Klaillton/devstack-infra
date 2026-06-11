# devstack-local

Orquestrador de deploy do ambiente devserverpi, acionado pelo repositório brewer quando uma atualização for publicada.

## Missao

Este repositório centraliza o fluxo de deploy do ambiente local de desenvolvimento e valida o evento `brewer-updated` antes de aplicar qualquer mudança no devserverpi.

O objetivo operacional e:

- receber eventos do brewer com `source_sha` e `source_ref`
- bloquear payloads incompletos ou inconsistentes
- aplicar a versao correta no devserverpi
- validar saude no pos-deploy
- manter trilha clara de auditoria e rollback

## Fluxo esperado

1. O brewer publica um `repository_dispatch` com o tipo `brewer-updated`.
2. O workflow valida a origem e os metadados obrigatorios.
3. O host devserverpi atualiza o checkout local para o `source_sha` informado.
4. O deploy aplica manifests Kubernetes no namespace configurado.
5. O workflow aguarda rollout, executa health check e registra o resumo.
6. Em falha, o pipeline aborta com diagnostico objetivo e executa rollback automatizado quando possivel.

## Contrato do payload

O evento deve fornecer, no minimo:

- `project_key`: identificador do projeto (ex.: `brewer`, `observability`)
- `source_sha`: commit que deve ser aplicado
- `source_ref`: branch ou ref de origem
- `source_repo`: repositorio de origem, esperado como `Klaillton/brewer`

Metadados adicionais podem ser enviados para rastreabilidade.

## Guardrails

- rejeitar eventos fora de `brewer-updated`
- rejeitar payload sem `source_sha` ou `source_ref`
- rejeitar `source_sha` invalido
- rejeitar origem fora da allowlist
- falhar se os manifests ou ferramentas necessarias nao estiverem disponiveis no destino

## Secrets e variaveis exigidos

Secrets GitHub:

- `DEVPI_HOST`
- `DEVPI_USER`
- `DEVPI_SSH_PRIVATE_KEY`

Variaveis recomendadas no ambiente (por projeto):

Projeto `brewer`:

- `BREWER_SOURCE_REPOSITORY` (default: `Klaillton/brewer`)
- `BREWER_SOURCE_REPO_DIR` (default: `/home/dante/brewer`)
- `BREWER_MANIFESTS_DIR` (default: `/home/dante/brewer/k8s`)
- `BREWER_NAMESPACE` (default: `brewer`)
- `BREWER_ROLLOUT_DEPLOYMENT` (default: `brewer`)
- `BREWER_HEALTH_URL` (obrigatoria)
- `BREWER_HEALTH_REQUIRED` (default: `true`)

Projeto `observability`:

- `OBSERVABILITY_SOURCE_REPOSITORY` (default: `Klaillton/observability-epo`)
- `OBSERVABILITY_SOURCE_REPO_DIR` (default: `/home/dante/observability-epo`)
- `OBSERVABILITY_MANIFESTS_DIR` (default: `/home/dante/observability-epo/k8s`)
- `OBSERVABILITY_NAMESPACE` (default: `observability`)
- `OBSERVABILITY_ROLLOUT_DEPLOYMENT` (default: `grafana`)
- `OBSERVABILITY_HEALTH_URL` (obrigatoria)
- `OBSERVABILITY_HEALTH_REQUIRED` (default: `false`)

Fallback legado:

- `DEVSTACK_HEALTH_URL` pode ser usado como fallback se `BREWER_HEALTH_URL` ou `OBSERVABILITY_HEALTH_URL` nao estiverem definidos.

## Mapeamento de projetos

O workflow resolve a configuracao com base em `project_key`.

Valores suportados atualmente:

- `brewer`
- `observability`

Se `project_key` nao estiver no mapa, o deploy falha rapido com erro explicito.

Politica de health:

- `brewer`: health final obrigatorio
- `observability`: health final opcional por padrao, util quando o stack estiver escalado sem replicas prontas

Para adicionar um novo projeto:

1. Adicionar novo case no workflow com defaults do projeto.
2. Criar variaveis `NOMEPROJETO_*` no repositório.
3. Garantir `source_repo`, manifests e endpoint de health do projeto.

## Observabilidade

O workflow deve deixar claro no log:

- entrada recebida
- project_key resolvido
- validacoes executadas
- sha aplicado
- namespace e destino usados
- resultado do rollout
- resultado do health check
- status final do deploy

## Rollback

Se o rollout falhar, o caminho padrao e executar rollback do deployment no cluster e revalidar a saude antes de encerrar o job.

## Estado atual

O repositório esta sendo ajustado para usar `repository_dispatch` como gatilho principal. O deploy nao deve depender de `docker-compose` no servidor de destino.

Validacao em campo no devserverpi:

- acesso SSH autorizado com usuario `dante`
- `kubectl` disponivel via `sudo -n`
- manifests encontrados em `/home/dante/brewer/k8s`
