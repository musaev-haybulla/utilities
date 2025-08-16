#!/bin/bash

# Автор: Ваше имя
# Версия: 1.0.0
# Описание: Генератор схемы БД для dbdiagrams.io

VERSION="1.0.0"

show_help() {
  echo "Использование: mysql_to_dbdiagram [ОПЦИИ] <имя_базы_данных>"
  echo
  echo "Опции:"
  echo "  -u, --user USER      Пользователь MySQL (по умолчанию: root)"
  echo "  -p, --password PASS  Пароль MySQL"
  echo "  -h, --host HOST      Хост MySQL (по умолчанию: localhost)"
  echo "  -P, --port PORT      Порт MySQL (по умолчанию: 3306)"
  echo "  -o, --output FILE    Выходной файл (по умолчанию: <база>_schema.dbdiagram)"
  echo "  --docker CONTAINER   Использовать Docker контейнер"
  echo "  --version            Показать версию"
  echo "  --help               Показать эту справку"
  echo
  echo "Примеры:"
  echo "  mysql_to_dbdiagram my_database"
  echo "  mysql_to_dbdiagram -u dev_user -p secret -h db.server.com my_database"
  echo "  mysql_to_dbdiagram --docker mysql_container my_database"
}

# Парсинг аргументов
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -u|--user)
      DB_USER="$2"; shift
      ;;
    -p|--password)
      DB_PASS="$2"; shift
      ;;
    -p*)
      # Поддержка формата -proot
      DB_PASS="${1:2}"
      ;;
    -h|--host)
      DB_HOST="$2"; shift
      ;;
    -P|--port)
      DB_PORT="$2"; shift
      ;;
    -o|--output)
      OUTPUT_FILE="$2"; shift
      ;;
    --docker)
      DOCKER_CONTAINER="$2"; shift
      ;;
    --version)
      echo "mysql_to_dbdiagram v$VERSION"; exit 0
      ;;
    --help)
      show_help; exit 0
      ;;
    *)
      DB_NAME="$1"
      ;;
  esac
  shift
done

# Проверка обязательного параметра
if [ -z "$DB_NAME" ]; then
  echo "Ошибка: Не указано имя базы данных"
  show_help
  exit 1
fi

# Установка значений по умолчанию
DB_USER="${DB_USER:-root}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
OUTPUT_FILE="${OUTPUT_FILE:-/Users/musaevhs/Sites/testing/${DB_NAME}_schema.dbdiagram}"

# Запрос пароля только если он не был передан явно
if [ -z "${DB_PASS+x}" ]; then
  read -s -p "Введите пароль для пользователя $DB_USER: " DB_PASS
  echo
fi

# Создаем временный файл конфигурации MySQL
create_mysql_config() {
  MYSQL_CONFIG_FILE=$(mktemp)
  cat > "$MYSQL_CONFIG_FILE" <<EOL
[client]
user = $DB_USER
password = $DB_PASS
host = $DB_HOST
port = $DB_PORT
EOL
  echo "$MYSQL_CONFIG_FILE"
}

# Функция для выполнения SQL-запроса
execute_mysql_query() {
  local query="$1"
  local config_file=$(create_mysql_config)
  
  if [ -n "$DOCKER_CONTAINER" ]; then
    # Копируем конфиг в контейнер и используем его
    docker cp "$config_file" "$DOCKER_CONTAINER:/tmp/mysql_config"
    docker exec "$DOCKER_CONTAINER" mysql --defaults-file=/tmp/mysql_config --skip-column-names -e "$query" "$DB_NAME"
    docker exec "$DOCKER_CONTAINER" rm -f /tmp/mysql_config
  else
    mysql --defaults-file="$config_file" --skip-column-names -e "$query" "$DB_NAME"
  fi
  
  rm -f "$config_file"
}

# Генерируем схему таблиц
generate_tables_schema() {
  # Переменная для перевода строки
  local nl=$'\n'
  
  # Проверка соединения с базой
  local config_file=$(create_mysql_config)
  local test_result
  
  if [ -n "$DOCKER_CONTAINER" ]; then
    docker cp "$config_file" "$DOCKER_CONTAINER:/tmp/mysql_test_config"
    test_result=$(docker exec "$DOCKER_CONTAINER" mysql --defaults-file=/tmp/mysql_test_config -e "USE $DB_NAME" 2>/dev/null && echo "OK")
    docker exec "$DOCKER_CONTAINER" rm -f /tmp/mysql_test_config
  else
    test_result=$(mysql --defaults-file="$config_file" -e "USE $DB_NAME" 2>/dev/null && echo "OK")
  fi
  
  rm -f "$config_file"
  
  if [ "$test_result" != "OK" ]; then
    echo "ERROR: Не удалось подключиться к базе $DB_NAME" >&2
    exit 1
  fi
  
  # Результат
  local result=""
  
  # Получаем список таблиц
  local tables_query="SELECT table_name FROM information_schema.tables 
    WHERE table_schema = '$DB_NAME' AND table_type = 'BASE TABLE' ORDER BY table_name"
  
  # Получаем список таблиц в массив
  local tables=( )
  while read -r table; do
    [ -n "$table" ] && tables+=("$table")
  done < <(execute_mysql_query "$tables_query")
  
  # Для отладки выводим количество таблиц
  echo "DEBUG: Найдено таблиц: ${#tables[@]}" >&2
  
  # Если нет таблиц, проверяем соединение с базой и наличие в ней таблиц
  if [ ${#tables[@]} -eq 0 ]; then
    echo "DEBUG: Выводим список всех таблиц в базе $DB_NAME:" >&2
    local debug_config=$(create_mysql_config)
    if [ -n "$DOCKER_CONTAINER" ]; then
      docker cp "$debug_config" "$DOCKER_CONTAINER:/tmp/mysql_debug_config"
      docker exec "$DOCKER_CONTAINER" mysql --defaults-file=/tmp/mysql_debug_config -e "SHOW TABLES" "$DB_NAME" >&2
      docker exec "$DOCKER_CONTAINER" rm -f /tmp/mysql_debug_config
    else
      mysql --defaults-file="$debug_config" -e "SHOW TABLES" "$DB_NAME" >&2
    fi
    rm -f "$debug_config"
  fi
  
  # Для каждой таблицы генерируем схему
  for table in "${tables[@]}"; do
    echo "DEBUG: Обрабатываю таблицу: $table" >&2
    
    result+="Table $table {$nl"
    
    # Получаем структуру колонок (все необходимые данные)
    local columns_query="
      SELECT 
        column_name, 
        UPPER(column_type) as column_type, 
        is_nullable, 
        column_key, 
        extra,
        column_default,
        column_comment
      FROM 
        information_schema.columns 
      WHERE 
        table_schema = '$DB_NAME' 
        AND table_name = '$table'
      ORDER BY 
        ordinal_position
    "
    
    # Предварительный проход для получения максимальных длин для выравнивания
    local max_name_len=0
    local max_type_len=0
    local column_data=()
    local clean_types=()
    local column_attrs=()
    local column_comments=()
    
    # Собираем все данные и вычисляем максимальные длины
    while IFS=$'\t' read -r col_name col_type is_nullable col_key extra col_default col_comment; do
      # Нормализуем тип данных
      local clean_type
      if [[ "$col_type" =~ ^BIGINT ]]; then
        clean_type="bigint"
      elif [[ "$col_type" =~ ^VARCHAR\([0-9]+\) ]]; then
        clean_type="varchar${col_type#VARCHAR}"
      elif [[ "$col_type" =~ ^INT ]]; then
        clean_type="int"
      elif [[ "$col_type" =~ ^TINYINT\(1\) ]]; then
        clean_type="boolean"
      elif [[ "$col_type" =~ ^ENUM ]]; then
        clean_type="enum${col_type#ENUM}"
        # Делаем ENUM в нижнем регистре
        clean_type=$(echo "$clean_type" | tr '[:upper:]' '[:lower:]')
      else
        clean_type=$(echo "$col_type" | tr '[:upper:]' '[:lower:]')
      fi
      
      # Формируем атрибуты в одних квадратных скобках
      local attrs=""
      [ "$col_key" = "PRI" ] && attrs+="pk, "
      [ "$extra" = "auto_increment" ] && attrs+="increment, "
      [ "$is_nullable" = "NO" ] && attrs+="not null, "
      [ "$col_key" = "UNI" ] && attrs+="unique, "
      
      # Добавляем значение по умолчанию
      if [ "$col_default" != "NULL" ] && [ -n "$col_default" ]; then
        local clean_default="${col_default//\`/}"
        attrs+="default: $clean_default, "
      fi
      
      # Убираем последние запятую и пробел
      attrs="${attrs%, }"
      
      # Сохраняем все данные в массивах
      column_data+=("$col_name")
      clean_types+=("$clean_type")
      column_attrs+=("$attrs")
      column_comments+=("$col_comment")
      
      # Обновляем максимальные длины
      local name_len=${#col_name}
      local type_len=${#clean_type}
      
      if [ "$name_len" -gt "$max_name_len" ]; then
        max_name_len=$name_len
      fi
      
      if [ "$type_len" -gt "$max_type_len" ]; then
        max_type_len=$type_len
      fi
    done < <(execute_mysql_query "$columns_query")
    
    # Теперь формируем строки с правильным выравниванием
    # Добавляем небольшой отступ для красоты
    local name_padding=$((max_name_len + 4))
    local type_padding=$((max_type_len + 6))
    
    for i in "${!column_data[@]}"; do
      local col_name="${column_data[$i]}"
      local clean_type="${clean_types[$i]}"
      local attrs="${column_attrs[$i]}"
      local comment="${column_comments[$i]}"
      
      # Форматирование с заданными отступами
      printf -v padded_name "%-${name_padding}s" "  $col_name"
      printf -v padded_type "%-${type_padding}s" "$clean_type"
      
      # Формируем строку
      local line="$padded_name$padded_type"
      
      # Добавляем атрибуты
      if [ -n "$attrs" ]; then
        line+="[$attrs]"
      fi
      
      # Добавляем комментарий
      if [ -n "$comment" ]; then
        if [ -n "$attrs" ]; then
          # Если есть атрибуты, добавляем отступ после них
          line+="     // $comment"
        else
          # Если атрибутов нет, выравниваем комментарий как будто атрибуты есть
          line+="          // $comment"
        fi
      fi
      
      # Добавляем сформированную строку в результат
      result+="$line$nl"
    done < <(execute_mysql_query "$columns_query")
    
    result+="}$nl$nl"
  done
  
  # Возвращаем результат
  echo "$result"
}

# Генерируем ссылки между таблицами
generate_references() {
  local query="
    SELECT CONCAT(
      'Ref: ', 
      table_name, '.', column_name, 
      ' > ', 
      referenced_table_name, '.', referenced_column_name,
      ' [delete: ', 
      (SELECT CASE delete_rule 
        WHEN 'CASCADE' THEN 'cascade'
        WHEN 'RESTRICT' THEN 'restrict'
        WHEN 'SET NULL' THEN 'set null'
        WHEN 'NO ACTION' THEN 'no action'
        ELSE LOWER(delete_rule) 
       END 
       FROM information_schema.referential_constraints rc
       WHERE rc.constraint_schema = kcu.table_schema
         AND rc.constraint_name = kcu.constraint_name),
      ']'
    )
    FROM 
      information_schema.key_column_usage kcu
    WHERE 
      kcu.table_schema = '$DB_NAME'
      AND kcu.referenced_table_name IS NOT NULL
    ORDER BY 
      table_name, column_name;
  "
  execute_mysql_query "$query"
}

# Основная функция
main() {
  # Проверяем доступность mysql клиента или docker
  if [ -n "$DOCKER_CONTAINER" ]; then
    if ! command -v docker &> /dev/null; then
      echo "Ошибка: docker не установлен или не в PATH"
      exit 1
    fi
  else
    if ! command -v mysql &> /dev/null; then
      echo "Ошибка: mysql клиент не установлен или не в PATH"
      exit 1
    fi
  fi

  echo "Генерация схемы для базы данных '$DB_NAME'..."
  
  # Создаем файл с полной схемой
  {
    # Заголовок
    echo "# Схема базы данных $DB_NAME"
    echo "# Сгенерировано $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# Команда: mysql_to_dbdiagram ${@}"
    echo ""
    
    # Таблицы
    generate_tables_schema
    
    # Внешние ключи
    echo "// Внешние ключи"
    generate_references
  } > "$OUTPUT_FILE"

  echo "Успешно! Схема сохранена в: $OUTPUT_FILE"
}

main
