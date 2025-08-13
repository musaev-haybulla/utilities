# Makefile для прямой синхронизации без Stow

SOURCE_DIR := $(HOME)/Sites/utilities
TARGET_DIR := $(HOME)/bin
SHELL := /bin/bash

# Цвета
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

.PHONY: sync clean diff list help

all: sync

help: ## Показать справку
	@echo "Доступные команды:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-12s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

sync: ## Синхронизировать утилиты
	@echo -e "$(BLUE)Синхронизация $(SOURCE_DIR) -> $(TARGET_DIR)$(NC)"
	@mkdir -p $(TARGET_DIR)
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
		echo -e "$(YELLOW)Нет файлов для синхронизации$(NC)"; \
	else \
		echo -e "$(GREEN)✓ Синхронизировано $$count файлов$(NC)"; \
	fi

clean: ## Удалить все ссылки
	@echo -e "$(BLUE)Удаление ссылок...$(NC)"
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
				echo -e "$(YELLOW)  Битая ссылка: $$basename$(NC)"; \
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
	@echo -e "$(BLUE)Утилиты:$(NC)"
	@for file in $(SOURCE_DIR)/*.sh; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename "$$file" .sh); \
			target="$(TARGET_DIR)/$$basename"; \
			if [ -L "$$target" ] && [ -e "$$target" ]; then \
				echo -e "  $(GREEN)✓$(NC) $$basename → $$file"; \
			else \
				echo -e "  $(YELLOW)✗$(NC) $$basename"; \
			fi; \
		fi; \
	done

# Алиасы
s: sync
d: diff
l: list
c: clean