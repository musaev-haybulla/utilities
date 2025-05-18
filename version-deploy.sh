#!/bin/bash

# Конфиг: поменяй на свои данные
SERVER_USER="твой_юзер"
SERVER_HOST="твой_сервер.ru"
PROJECT_PATH="/var/www/mycalc"

# Проверка, что конфигурация изменена с дефолтной
if [[ "$SERVER_USER" == "твой_юзер" || "$SERVER_HOST" == "твой_сервер.ru" ]]; then
    echo "Ошибка: Необходимо настроить SERVER_USER и SERVER_HOST в скрипте."
    exit 1
fi

# Проверка доступности сервера
echo "Проверка доступности сервера..."
if ! ping -c 1 $SERVER_HOST &>/dev/null; then
    echo "Ошибка: Сервер $SERVER_HOST недоступен."
    exit 1
fi

# Проверка SSH-соединения
echo "Проверка SSH-соединения..."
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 $SERVER_USER@$SERVER_HOST "exit" 2>/dev/null; then
    echo "Ошибка: Не удалось подключиться по SSH к $SERVER_USER@$SERVER_HOST."
    echo "Проверьте учетные данные и доступность SSH-сервера."
    exit 1
fi

# Проверка существования каталога проекта
echo "Проверка существования каталога проекта..."
if ! ssh $SERVER_USER@$SERVER_HOST "[ -d $PROJECT_PATH ]"; then
    echo "Ошибка: Каталог проекта $PROJECT_PATH не существует на сервере."
    exit 1
fi

# Проверка git-репозитория
echo "Проверка git-репозитория..."
if ! ssh $SERVER_USER@$SERVER_HOST "cd $PROJECT_PATH && git rev-parse --is-inside-work-tree > /dev/null 2>&1"; then
    echo "Ошибка: Каталог $PROJECT_PATH не является git-репозиторием."
    exit 1
fi

echo "Выполнение деплоя..."

# Подключились по SSH и обновили код с обработкой ошибок
ssh $SERVER_USER@$SERVER_HOST "
  set -e
  cd $PROJECT_PATH || { echo 'Ошибка при переходе в каталог проекта'; exit 1; }
  
  # Сохраняем текущую версию для сравнения
  OLD_VERSION=\$(git describe --tags --always 2>/dev/null || echo 'unknown')
  
  # Проверка наличия несохраненных изменений
  if ! git diff-index --quiet HEAD --; then
    echo 'Предупреждение: На сервере есть несохраненные изменения'
    echo 'Локальные изменения будут сохранены в stash'
    git stash save 'Автоматическое сохранение перед деплоем'
  fi
  
  # Обновляем код
  echo 'Получение последних изменений...'
  if ! git pull origin main; then
    echo 'Ошибка при получении изменений из репозитория'
    exit 1
  fi
  
  # Получаем новую версию
  NEW_VERSION=\$(git describe --tags --always 2>/dev/null || echo 'unknown')
  
  echo 'Деплой завершён, версия обновлена с \$OLD_VERSION до \$NEW_VERSION'
" || {
    echo "Ошибка при выполнении операций на сервере."
    exit 1
}

echo "Деплой на $SERVER_HOST успешно завершён!"
