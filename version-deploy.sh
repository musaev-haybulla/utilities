#!/bin/bash

# Проверка, что мы в git-репозитории
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Ошибка: Текущая директория не является git-репозиторием"
    exit 1
fi

# Проверка доступности удаленного репозитория
if ! git ls-remote origin -h refs/heads/main >/dev/null 2>&1; then
    echo "Ошибка: Удаленный репозиторий origin/main недоступен."
    exit 1
fi

# Получаем текущую ветку
CURRENT_BRANCH=$(git branch --show-current)

# Сохраняем текущую версию
OLD_VERSION=$(git describe --tags --always 2>/dev/null || echo 'unknown')

# Проверяем наличие несохраненных изменений
if ! git diff-index --quiet HEAD --; then
    echo "Предупреждение: Есть несохраненные изменения"
    read -p "Сохранить изменения перед синхронизацией? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        read -p "Введите сообщение коммита: " commit_message
        git commit -m "$commit_message"
    else
        echo "Синхронизация отменена"
        exit 1
    fi
fi

# Получаем изменения с GitHub
echo "Получение изменений с GitHub..."
if ! git pull origin $CURRENT_BRANCH; then
    echo "Ошибка при получении изменений"
    exit 1
fi

# Получаем новую версию
NEW_VERSION=$(git describe --tags --always 2>/dev/null || echo 'unknown')

echo "Синхронизация завершена"
echo "Версия обновлена с $OLD_VERSION до $NEW_VERSION"