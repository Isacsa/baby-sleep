# Guia de Testes RLS e Regras de Negócio

Este documento explica como executar os testes de Row Level Security (RLS) e regras de negócio para validar o backend antes de iniciar o desenvolvimento do frontend Flutter.

## 📋 Pré-requisitos

1. **Backend Supabase configurado**:
   - Todas as migrações aplicadas (`001_create_tables.sql` até `004_create_triggers.sql`)
   - RLS ativado em todas as tabelas
   - Triggers criados e funcionais

2. **Utilizadores de teste**:
   - Pelo menos 2 utilizadores autenticados no Supabase
   - User A: Criador de bebés, owner
   - User B: Editor/viewer para testes de permissões

3. **Acesso ao Supabase Dashboard**:
   - SQL Editor acessível
   - Possibilidade de alternar entre utilizadores autenticados

## 🚀 Como Executar os Testes

### Passo 1: Obter IDs dos Utilizadores

1. No Supabase Dashboard, vá para **Authentication** → **Users**
2. Anote os UUIDs dos utilizadores de teste (User A e User B)
3. Ou execute no SQL Editor (autenticado como cada utilizador):
   ```sql
   SELECT auth.uid() AS current_user_id;
   ```

### Passo 2: Preparar o Ficheiro de Testes

1. Abra o ficheiro `005_test_rls_and_business_rules.sql`
2. Substitua todos os placeholders:
   - `<baby_id_from_1.1>` → ID do bebé criado no teste 1.1
   - `<user_b_uuid>` → UUID do User B
   - `<user_c_uuid>` → UUID de um terceiro utilizador (opcional)
   - `<sleep_event_id>` → ID de um evento de sono criado
   - `<caregiver_id>` → ID de um cuidador criado
   - `<baby_id_user_a_only>` → ID de um bebé onde apenas User A é cuidador

### Passo 3: Executar Testes como User A

1. **Autenticar como User A**:
   - No Supabase Dashboard, use o contexto de autenticação do User A
   - Ou use a API com o token de autenticação do User A

2. **Executar TEST GROUP 1** (Criação de bebé):
   ```sql
   -- TEST 1.1: Criar bebé
   -- TEST 1.2: Verificar trigger criou caregiver
   -- TEST 1.3: Verificar acesso ao bebé
   ```

3. **Executar TEST GROUP 2** (Permissões de owner):
   - Inserir eventos
   - Adicionar cuidadores
   - Soft delete de cuidadores
   - Verificar bloqueios (último owner, imutabilidade)

### Passo 4: Executar Testes como User B

1. **Autenticar como User B**:
   - Alterar contexto de autenticação para User B

2. **Executar TEST GROUP 3** (Permissões de editor):
   - Verificar acesso de leitura
   - Verificar permissões de escrita (inserir eventos)
   - Verificar bloqueios (soft delete baby, alterar roles)

3. **Alterar User B para viewer** (como owner):
   - Voltar a autenticar como User A (owner)
   - Alterar role de User B para 'viewer'
   - Voltar a autenticar como User B

4. **Executar TEST GROUP 4** (Permissões de viewer):
   - Verificar acesso de leitura
   - Verificar bloqueios de escrita

### Passo 5: Executar Testes de Segurança

1. **Executar TEST GROUP 5** (Controlo de acesso):
   - Verificar que User B não acede a bebés onde não é cuidador
   - Verificar que não é possível criar eventos com caregiver_id de outro utilizador

### Passo 6: Executar Testes de Regras de Negócio

1. **Executar TEST GROUP 6** (Triggers e validações):
   - Timestamp no futuro (> 1 hora)
   - Timestamp no passado (retroativo)
   - Integridade de correções (is_corrected + corrected_by)
   - Validação de baby_id e caregiver_id

### Passo 7: Verificações Finais

1. **Executar TEST GROUP 7** (Queries de verificação):
   - Contar bebés
   - Listar cuidadores
   - Timeline de eventos
   - Verificar integridade (pelo menos um owner)

## ✅ Critérios de Sucesso

### Testes que DEVEM SUCEDER (EXPECTED: SUCCESS):

- ✅ User A cria bebé e caregiver é criado automaticamente
- ✅ Owner pode inserir eventos, adicionar cuidadores, soft delete
- ✅ Editor pode inserir eventos, ver dados
- ✅ Viewer pode ver dados (read-only)
- ✅ Eventos retroativos são permitidos
- ✅ Correções com is_corrected = true são permitidas

### Testes que DEVEM FALHAR (EXPECTED: FAIL):

- ❌ Viewer não pode inserir/atualizar eventos
- ❌ Editor não pode soft delete baby ou alterar roles
- ❌ Não é possível remover último owner
- ❌ Não é possível aceder a bebés onde não se é cuidador
- ❌ Não é possível criar evento com caregiver_id de outro utilizador
- ❌ Não é possível alterar campos imutáveis (created_by, timestamp, etc.)
- ❌ Não é possível criar evento com timestamp > 1 hora no futuro
- ❌ Não é possível criar evento com corrected_by mas is_corrected = false

## 🔍 Interpretação dos Resultados

### Se um teste com EXPECTED: SUCCESS falha:

1. **Verificar autenticação**: Confirme que está autenticado como o utilizador correto
2. **Verificar RLS**: As políticas RLS podem não estar aplicadas corretamente
3. **Verificar triggers**: Os triggers podem não estar criados ou podem ter erros
4. **Verificar dados**: Os placeholders podem não ter sido substituídos corretamente

### Se um teste com EXPECTED: FAIL tem sucesso:

1. **Problema de segurança**: RLS não está a bloquear como esperado
2. **Trigger não funciona**: A regra de negócio não está a ser aplicada
3. **Política incorreta**: A política RLS pode estar demasiado permissiva

## 📝 Notas Importantes

1. **Placeholders**: Todos os placeholders (`<...>`) devem ser substituídos por valores reais antes de executar
2. **Ordem de execução**: Alguns testes dependem de resultados de testes anteriores
3. **Ambiente de teste**: Use um ambiente de teste, não produção
4. **Limpeza**: Use as queries de cleanup no final se necessário (apenas em ambiente de teste)

## 🐛 Troubleshooting

### Erro: "permission denied for table"
- **Causa**: RLS está a bloquear acesso
- **Solução**: Verificar que está autenticado e que o utilizador tem permissões adequadas

### Erro: "Cannot remove the last owner"
- **Causa**: Trigger está a funcionar corretamente
- **Solução**: Este é o comportamento esperado! Adicione outro owner antes de remover

### Erro: "missing FROM-clause entry for table 'old'"
- **Causa**: Erro em trigger ou função (não deve acontecer se migrações estão corretas)
- **Solução**: Verificar que todas as migrações foram aplicadas corretamente

### Erro: "new row violates row-level security policy"
- **Causa**: RLS está a bloquear a operação
- **Solução**: Verificar que o utilizador tem permissões adequadas (owner/editor/viewer)

## 📚 Estrutura dos Testes

Os testes estão organizados em 7 grupos:

1. **TEST GROUP 1**: Criação de bebé e trigger automático
2. **TEST GROUP 2**: Permissões de owner
3. **TEST GROUP 3**: Permissões de editor
4. **TEST GROUP 4**: Permissões de viewer
5. **TEST GROUP 5**: Segurança e controlo de acesso
6. **TEST GROUP 6**: Regras de negócio e triggers
7. **TEST GROUP 7**: Queries de verificação

Cada teste inclui:
- Comentário descritivo
- EXPECTED: SUCCESS ou EXPECTED: FAIL
- Query SQL executável
- Notas sobre placeholders a substituir

## 🎯 Próximos Passos

Após validar todos os testes:

1. ✅ Backend está seguro e pronto
2. ✅ RLS está a funcionar corretamente
3. ✅ Regras de negócio estão aplicadas
4. ✅ Pode iniciar desenvolvimento do frontend Flutter

---

**Última atualização**: Após implementação das migrações 001-004

