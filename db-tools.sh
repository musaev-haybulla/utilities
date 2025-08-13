#!/bin/bash

# Default values
CONFIG_FILE=".db-tools.conf"
PROJECT_DIR="$(pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Help message
show_help() {
    echo "Использование: db-tools [команда] [опции]"
    echo "Команды:"
    echo "  update-schema    Обновить DBML схему"
    echo "  dump-data        Создать дамп базы данных"
    echo "  update-all       Обновить схему и сделать дамп (по умолчанию)"
    echo "  init             Создать конфигурационный файл"
    echo "  help             Показать это сообщение"
    echo ""
    echo "Опции:"
    echo "  -c, --config     Указать альтернативный конфигурационный файл"
    echo "  -d, --dir        Указать рабочую директорию"
}

# Load configuration
load_config() {
    local config_file="$1"
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Ошибка: Конфигурационный файл не найден: $config_file${NC}"
        echo "Создайте конфигурационный файл с помощью команды: db-tools init"
        exit 1
    fi
    
    # Source the config file
    source "$config_file"
    
    # Set default values if not set in config
    DBML_FILE="${DBML_FILE:-db.dbml}"
    DUMP_FILE="${DUMP_FILE:-data.sql}"
}

# Initialize config file
init_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Внимание: Конфигурационный файл уже существует${NC}"
        read -p "Перезаписать? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    read -p "Хост БД [127.0.0.1]: " db_host
    read -p "Пользователь БД [root]: " db_user
    read -s -p "Пароль: " db_pass
    echo
    read -p "Имя базы данных: " db_name
    
    cat > "$CONFIG_FILE" <<EOL
# Конфигурация db-tools
DB_HOST="${db_host:-127.0.0.1}"
DB_USER="${db_user:-root}"
DB_PASS="$db_pass"
DB_NAME="$db_name"
DBML_FILE="db.dbml"
DUMP_FILE="data.sql"
EOL
    
    echo -e "${GREEN}Конфигурационный файл создан: $CONFIG_FILE${NC}"
}

# Update DBML schema
update_schema() {
    echo -e "${YELLOW}Обновление DBML схемы...${NC}"
    mysql_to_dbdiagram -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -o "$PROJECT_DIR/$DBML_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ DBML схема обновлена: $PROJECT_DIR/$DBML_FILE${NC}"
    else
        echo -e "${RED}Ошибка: Не удалось обновить DBML схему${NC}"
        return 1
    fi
}

# Dump database
dump_data() {
    echo -e "${YELLOW}Создание дампа базы данных...${NC}"
    mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" --no-tablespaces "$DB_NAME" > "$PROJECT_DIR/$DUMP_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Дамп базы данных создан: $PROJECT_DIR/$DUMP_FILE${NC}"
    else
        echo -e "${RED}Ошибка: Не удалось создать дамп базы данных${NC}"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        init)
            init_config
            exit 0
            ;;
        update-schema)
            COMMAND="update_schema"
            shift
            ;;
        dump-data)
            COMMAND="dump_data"
            shift
            ;;
        update-all)
            COMMAND="update_all"
            shift
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Неизвестный аргумент: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Default command if none specified
COMMAND=${COMMAND:-update_all}

# Load configuration
load_config "$PROJECT_DIR/$CONFIG_FILE"

# Execute command
case $COMMAND in
    update_schema)
        update_schema
        ;;
    dump_data)
        dump_data
        ;;
    update_all)
        update_schema && dump_data
        ;;
    *)
        echo -e "${RED}Неизвестная команда: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Готово!${NC}"
else
    echo -e "${RED}✗ Выполнение завершилось с ошибкой${NC}"
    exit 1
fi
