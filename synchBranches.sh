#!/bin/bash
# chmod +x syncBranches.sh

# Função para copiar a descrição de um PR dado um link
get_pr_description() {
  echo "Digite o link do PR de origem:"
  read pr_link

  # Extrai o número do PR a partir do link (a parte após '/pull/')
  pr_number=$(echo "$pr_link" | awk -F'/pull/' '{print $2}')

  # Verifica se o número do PR foi extraído corretamente
  if [ -z "$pr_number" ]; then
    echo "Erro: O link fornecido não é válido. Tente novamente."
    exit 1
  fi

  # Usa o GitHub CLI para pegar a descrição do PR
  source_pr_description=$(gh pr view "$pr_number" --json body --jq .body)
  source_pr_title=$(gh pr view "$pr_number" --json title --jq .title)


  # Verifica se a descrição foi recuperada
  if [ -z "$source_pr_description" ]; then
    echo "Erro: Não foi possível recuperar a descrição do PR. Verifique suas credenciais e tente novamente."
    exit 1
  fi

  echo "Descrição e título do PR de origem recuperados com sucesso."
}


# Pega o nome da branch atual
currentBranch=$(git rev-parse --abbrev-ref HEAD)
IFS='/'
read -ra branch_info <<< "$currentBranch"

branch_type=${branch_info[0]}
branch_name=${branch_info[1]}

# Verifica se o tipo da branch está vazio
if [ -z "$branch_type" ]; then
  echo "Erro: Nome da branch não pode estar vazio."
  exit 1
fi

# Verifica se o nome da branch está vazio
if [ -z "$branch_name" ]; then
  echo "Erro: Nome da branch não pode estar vazio."
  exit 1
fi

# Chama a função para pegar a descrição do PR de origem
get_pr_description

# Salva a hash do último commit
lastCommitHash=$(git log --pretty=format:'%H' -n 1)

## Develop
# Cria branch de desenvolvimento
git checkout main
git fetch
git pull
git checkout develop
git reset --hard origin/develop
branch_develop="$branch_type/dev/$branch_name"

# Verifica se a branch de desenvolvimento já existe
git ls-remote --exit-code --heads origin $branch_develop >/dev/null 2>&1
EXIT_CODE=$?
if [[ $EXIT_CODE == '0' ]]; then
  echo "Git branch '$branch_develop' exists in the remote repository"
  git branch -D "$branch_develop"
elif [[ $EXIT_CODE == '2' ]]; then
  git branch -D "$branch_develop"
  echo "Git branch '$branch_develop' does not exist in the remote repository"
fi

# Cria nova branch
git checkout -b "$branch_develop"

# Faz o cherry-pick da branch de origem, aceitando todas as entradas em caso de conflito
git cherry-pick "$lastCommitHash" --strategy-option=theirs

# Verifica se o cherry-pick foi bem-sucedido
if [ $? -eq 0 ]; then
  echo "Cherry-pick da branch '$lastCommitHash' para '$branch_develop' realizado com sucesso."
else
  echo "Erro ao realizar o cherry-pick."
  exit 1
fi

# Sobe as alterações para o repositório remoto
git push --set-upstream origin "$branch_develop" -f --no-verify

# Cria o PR para develop e armazena o link
pr_url_develop=$(gh pr create --base develop --head "$branch_develop" --title "$source_pr_title" --body "$source_pr_description" | grep 'https')
echo "PR de develop criado: $pr_url_develop"

## Homolog
# Cria branch de homologação
git checkout homolog
git fetch
git pull
git reset --hard origin/homolog
branch_homolog="$branch_type/hml/$branch_name"

# Verifica se a branch de homologação já existe
git ls-remote --exit-code --heads origin $branch_homolog >/dev/null 2>&1
EXIT_CODE=$?
if [[ $EXIT_CODE == '0' ]]; then
  echo "Git branch '$branch_homolog' exists in the remote repository"
  git branch -D "$branch_homolog"
elif [[ $EXIT_CODE == '2' ]]; then
  git branch -D "$branch_homolog"
  echo "Git branch '$branch_homolog' does not exist in the remote repository"
fi

git checkout -b "$branch_homolog"

# Faz o cherry-pick da branch de origem, aceitando todas as entradas em caso de conflito
git cherry-pick "$lastCommitHash" --strategy-option=theirs

# Verifica se o cherry-pick foi bem-sucedido
if [ $? -eq 0 ]; then
  echo "Cherry-pick da branch '$lastCommitHash' para '$branch_homolog' realizado com sucesso."
else
  echo "Erro ao realizar o cherry-pick."
  exit 1
fi

# Sobe as alterações para o repositório remoto
git push --set-upstream origin "$branch_homolog" -f --no-verify

# Cria o PR para homolog e armazena o link
pr_url_homolog=$(gh pr create --base homolog --head "$branch_homolog" --title "$source_pr_title" --body "$source_pr_description" | grep 'https')
echo "PR de homolog criado: $pr_url_homolog"

# Volta para a branch de origem
git checkout "$branch_type/$branch_name"

# Final
echo "--------------------------------------------"
echo "Todos os PRs foram criados com sucesso."
echo "Sugestão de mensagem:"
echo "--------------------------------------------"
echo "Bom dia, @mar-devs-frontend! Poderiam revisar estas PRs?"
echo "[BFF-DEV]: $pr_url_develop"
echo "[BFF-HML]: $pr_url_homolog"
echo "[BFF-PRD]: $pr_link"

