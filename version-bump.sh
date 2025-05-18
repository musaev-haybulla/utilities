#!/bin/bash

# Использование: ./bump_version.sh [major|minor|patch]

VERSION_FILE="VERSION"

# Проверка существования файла VERSION
if [ ! -f "$VERSION_FILE" ]; then
  echo "Файл $VERSION_FILE не существует. Создаем с версией 0.1.0"
  echo "0.1.0" > "$VERSION_FILE"
  CURRENT_VERSION="0.1.0"
else
  # Чтение текущей версии
  CURRENT_VERSION=$(cat $VERSION_FILE)
fi

# Валидация формата версии (должен быть X.Y.Z)
if ! [[ $CURRENT_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Ошибка: Версия '$CURRENT_VERSION' не соответствует формату X.Y.Z"
  exit 1
fi

# Разбираем текущую версию (1.2.3 -> MAJOR=1, MINOR=2, PATCH=3)
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

case "$1" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Используй: $0 [major|minor|patch]"
    exit 1
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Обработка ошибок записи в файл
if ! echo "$NEW_VERSION" > $VERSION_FILE; then
  echo "Ошибка: Не удалось записать новую версию в файл $VERSION_FILE."
  exit 1
fi

echo "Версия обновлена: $CURRENT_VERSION → $NEW_VERSION"
