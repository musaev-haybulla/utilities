#!/bin/bash

# Название скрипта: git-reset-blank
# Функция: Удаление Git-репозитория и связанных файлов в текущей директории

echo "Сброс Git-репозитория в текущей директории..."

# Проверка, что текущая директория является Git-репозиторием
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Ошибка: Текущая директория не является Git-репозиторием."
    exit 1
fi

# Вывод текущего состояния репозитория
echo "Текущий репозиторий: $(git rev-parse --show-toplevel)"
echo "Основная ветка: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'не определена')"
echo "Несохраненные изменения:"
git status --short

# Запрос подтверждения
echo ""
echo "ВНИМАНИЕ: Это действие удалит папку .git и все настройки Git в текущей директории."
echo "История коммитов, ветки и теги будут потеряны. Файлы проекта (например, VERSION, код) останутся нетронутыми."
read -p "Вы уверены, что хотите продолжить? (y/n): " choice
if [ "$choice" != "y" ]; then
    echo "Операция отменена."
    exit 0
fi

# Удаление папки .git
echo "Удаление папки .git..."
rm -rf .git

# Проверка, что папка .git удалена
if [ -d ".git" ]; then
    echo "Ошибка: Не удалось удалить папку .git."
    exit 1
fi

# Опционально: запрос на удаление .gitignore
if [ -f ".gitignore" ]; then
    read -p "Удалить файл .gitignore? (y/n): " gitignore_choice
    if [ "$gitignore_choice" = "y" ]; then
        echo "Удаление файла .gitignore..."
        rm .gitignore
    else
        echo "Файл .gitignore оставлен без изменений."
    fi
fi

echo "Git-репозиторий успешно удалён!"
echo "Текущая директория теперь не содержит Git-настроек."