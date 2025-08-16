# Makefile для системы утилит

SOURCE_DIR := $(HOME)/Development/utilities
TARGET_DIR := $(HOME)/.local/bin
SHELL := /bin/bash

# Цвета
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
NC := \033[0m

.PHONY: sync clean diff list help install

all: sync

help: ## Показать справку
	@echo "Доступные команды:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-12s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Первоначальная настройка системы
	@echo -e "$(BLUE)Настройка системы утилит...$(NC)"
	@mkdir -p $(TARGET_DIR)
	@mkdir -p $(SOURCE_DIR)
	@if [[ ":$$PATH:" != *":$(HOME)/.local/bin:"* ]]; then \
		echo -e "$(YELLOW)Добавление ~/.local/bin в PATH...$(NC)"; \
		echo 'export PATH="$$HOME/.local/bin:$$PATH"' >> ~/.zshrc; \
		echo -e "$(GREEN)✓ Добавлено в ~/.zshrc$(NC)"; \
		echo -e "$(YELLOW)Перезапустите терминал или выполните: source ~/.zshrc$(NC)"; \
	else \
		echo -e "$(GREEN)✓ ~/.local/bin уже в PATH$(NC)"; \
	fi
	@echo -e "$(GREEN)✓ Система готова к использованию$(NC)"

sync: ## Синхронизировать утилиты
	@echo -e "$(BLUE)Синхронизация $(SOURCE_DIR) -> $(TARGET_DIR)$(NC)"
	@if [ ! -d "$(SOURCE_DIR)" ]; then \
		echo -e "$(RED)Ошибка: Директория $(SOURCE_DIR) не существует$(NC)"; \
		echo -e "$(YELLOW)Выполните: make install$(NC)"; \
		exit 1; \
	fi
	@if [ ! -d "$(TARGET_DIR)" ]; then \
		echo -e "$(YELLOW)Создание $(TARGET_DIR)...$(NC)"; \
		mkdir -p $(TARGET_DIR); \
	fi
	@count=0; \
	for file in $(SOURCE_DIR)/*.sh; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename "$$file" .sh); \
			target="$(TARGET_DIR)/$$basename"; \
			if [ -e "$$target" ] || [ -L "$$target" ]; then \
				rm "$$target"; \
			fi; \
			ln -s "$$file" "$$target"; \
			chmod +x "$$file"; \
			echo -e "  $(GREEN)✓$(NC) $$(basename "$$file") → $$basename"; \
			count=$$((count + 1)); \
		fi; \
	done; \
	if [ $$count -eq 0 ]; then \
		echo -e "$(YELLOW)Нет .sh файлов в $(SOURCE_DIR)$(NC)"; \
		echo -e "$(YELLOW)Поместите ваши скрипты туда и запустите sync снова$(NC)"; \
	else \
		echo -e "$(GREEN)✓ Синхронизировано $$count файлов$(NC)"; \
	fi

clean: ## Удалить все ссылки
	@echo -e "$(BLUE)Удаление ссылок из $(TARGET_DIR)...$(NC)"
	@count=0; \
	for file in $(SOURCE_DIR)/*.sh; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename "$$file" .sh); \
			target="$(TARGET_DIR)/$$basename"; \
			if [ -L "$$target" ]; then \
				rm "$$target"; \
				echo -e "  $(GREEN)✓$(NC) Удален $$basename"; \
				count=$$((count + 1)); \
			fi; \
		fi; \
	done; \
	echo -e "$(GREEN)✓ Удалено $$count ссылок$(NC)"

diff: ## Показать различия
	@echo -e "$(BLUE)Проверка различий...$(NC)"
	@changes=0; \
	for file in $(SOURCE_DIR)/*.sh; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename "$$file" .sh); \
			target="$(TARGET_DIR)/$$basename"; \
			if [ ! -L "$$target" ]; then \
				echo -e "$(YELLOW)  Отсутствует: $$basename$(NC)"; \
				changes=$$((changes + 1)); \
			elif [ ! -e "$$target" ]; then \
				echo -e "$(RED)  Битая ссылка: $$basename$(NC)"; \
				changes=$$((changes + 1)); \
			elif [ "$$file" -nt "$$target" ]; then \
				echo -e "$(YELLOW)  Изменен: $$basename$(NC)"; \
				changes=$$((changes + 1)); \
			fi; \
		fi; \
	done; \
	if [ $$changes -eq 0 ]; then \
		echo -e "$(GREEN)✓ Все файлы синхронизированы$(NC)"; \
	fi

list: ## Показать все утилиты
	@echo -e "$(BLUE)Утилиты в системе:$(NC)"
	@found=0; \
	for file in $(SOURCE_DIR)/*.sh; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename "$$file" .sh); \
			target="$(TARGET_DIR)/$$basename"; \
			if [ -L "$$target" ] && [ -e "$$target" ]; then \
				echo -e "  $(GREEN)✓$(NC) $$basename → $$file"; \
			else \
				echo -e "  $(RED)✗$(NC) $$basename (не установлен)"; \
			fi; \
			found=1; \
		fi; \
	done; \
	if [ $$found -eq 0 ]; then \
		echo -e "$(YELLOW)Нет .sh файлов в $(SOURCE_DIR)$(NC)"; \
	fi

status: ## Показать статус системы
	@echo -e "$(BLUE)Статус системы утилит:$(NC)"
	@echo -e "  Исходники: $(SOURCE_DIR)"
	@echo -e "  Установка: $(TARGET_DIR)"
	@if [ -d "$(SOURCE_DIR)" ]; then \
		echo -e "  $(GREEN)✓$(NC) Директория исходников существует"; \
	else \
		echo -e "  $(RED)✗$(NC) Директория исходников не найдена"; \
	fi
	@if [ -d "$(TARGET_DIR)" ]; then \
		echo -e "  $(GREEN)✓$(NC) Директория установки существует"; \
	else \
		echo -e "  $(RED)✗$(NC) Директория установки не найдена"; \
	fi
	@if [[ ":$$PATH:" == *":$(HOME)/.local/bin:"* ]]; then \
		echo -e "  $(GREEN)✓$(NC) ~/.local/bin в PATH"; \
	else \
		echo -e "  $(RED)✗$(NC) ~/.local/bin НЕ в PATH"; \
	fi

# Алиасы
s: sync
d: diff
l: list
c: clean
i: install