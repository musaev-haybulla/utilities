#!/bin/bash

# Название скрипта: project-init
# Функция: Инициализация Git-репозитория в текущей директории с файлом VERSION и настройка удаленного репозитория

echo "Инициализация проекта в текущей директории..."

# Проверка наличия GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
    echo "Ошибка: GitHub CLI (gh) не установлен. Установите его или настройте удаленный репозиторий вручную."
    exit 1
fi

# Запрашиваем имя проекта
read -p "Введите имя проекта (или нажмите Enter для продолжения): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-unnamed-project}

# Инициализация Git-репозитория в текущей директории
echo "Инициализация Git-репозитория..."
git init

# Создание файла VERSION
echo "Создание файла VERSION..."
echo "0.1.0" > VERSION

# Создание базового .gitignore (если его ещё нет)
if [ ! -f ".gitignore" ]; then
    echo "Создание файла .gitignore..."
    cat > .gitignore << EOF
# Системные файлы
.DS_Store
Thumbs.db

# Временные файлы
*.log
*.tmp
tmp/

# Зависимости и сборки
node_modules/
dist/
build/
EOF
fi

# Добавление ВСЕХ файлов в Git и создание первоначального коммита
echo "Добавление файлов в Git..."
git add .
git commit -m "Initial commit: Version 0.1.0"

# Создание удаленного репозитория на GitHub
echo "Создание удаленного репозитория на GitHub..."
if ! gh repo create "$PROJECT_NAME" --public --source=. --remote=origin --push; then
    echo "Ошибка: Не удалось создать удаленный репозиторий."
    exit 1
fi

echo "Проект '$PROJECT_NAME' успешно инициализирован и связан с удаленным репозиторием!"
echo "Текущая версия: $(cat VERSION)"