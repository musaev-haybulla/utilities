#!/bin/bash

# Проверка наличия файла VERSION
if [ ! -f "VERSION" ]; then
    echo "Ошибка: Файл VERSION не найден."
    exit 1
fi

VERSION=$(cat VERSION)

# Проверка, что VERSION содержит значение
if [ -z "$VERSION" ]; then
    echo "Ошибка: Файл VERSION пуст."
    exit 1
fi

DEFAULT_MESSAGE="Релиз $VERSION"

# Проверка, что находимся в git репозитории
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Ошибка: Текущая директория не является git-репозиторием."
    exit 1
fi

# Проверка существования тега (важно сделать это до любых действий с коммитами)
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Ошибка: Тег v$VERSION уже существует."
    exit 1
fi

# Функция для создания тега
create_tag() {
    local commit_message="$1"
    echo "Создание тега v$VERSION..."
    if ! git tag -a "v$VERSION" -m "$commit_message"; then
        echo "Ошибка при создании тега."
        return 1
    fi

    # Проверка доступности удаленного репозитория
    if ! git ls-remote origin -h refs/heads/main >/dev/null 2>&1; then
        echo "Ошибка: Удаленный репозиторий origin/main недоступен."
        return 1
    fi

    # Пушим тег в GitHub
    if ! git push origin "v$VERSION"; then
        echo "Ошибка при отправке тега в удаленный репозиторий."
        return 1
    fi

    echo "Тег v$VERSION успешно создан и запушен!"
    return 0
}

# Проверяем, есть ли незакоммиченные изменения
if ! git diff-index --quiet HEAD -- || ! git diff --quiet --staged; then
    # Есть изменения
    echo "Обнаружены несохраненные и/или незакоммиченные (staged) изменения."
    read -p "Хотите добавить текущие изменения в коммит? (y/n): " commit_choice
    
    if [ "$commit_choice" = "y" ]; then
        echo "Добавление изменений..."
        git add .
        
        # Запрашиваем кастомное сообщение коммита
        read -p "Введите сообщение коммита (или нажмите Enter для использования стандартного '$DEFAULT_MESSAGE'): " custom_message
        if [ -z "$custom_message" ]; then
            commit_message="$DEFAULT_MESSAGE"
        else
            commit_message="$custom_message"
        fi
        
        # Создаем коммит
        if git commit -m "$commit_message"; then
            echo "Коммит '$commit_message' успешно создан."
            
            # Пушим изменения
            if ! git push origin main; then
                echo "Ошибка при отправке изменений в удаленный репозиторий."
                exit 1
            fi
            
            # Спрашиваем про создание тега
            read -p "Хотите создать тег v$VERSION для этого коммита? (y/n): " tag_choice
            if [ "$tag_choice" = "y" ]; then
                create_tag "$commit_message"
            fi
        else
            echo "Ошибка: Не удалось создать коммит."
            echo "Возможно, не было новых изменений для коммита."
            exit 1
        fi
    else
        echo "Операция отменена. Изменения не были закоммичены."
        exit 0
    fi
else
    # Нет изменений
    echo "Нет несохраненных или незакоммиченных изменений в репозитории."
    read -p "Хотите создать тег v$VERSION для текущего коммита (HEAD)? (y/n): " tag_choice
    if [ "$tag_choice" = "y" ]; then
        create_tag "$DEFAULT_MESSAGE"
    else
        echo "Операция тегирования отменена."
        exit 0
    fi
fi
