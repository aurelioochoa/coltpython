PROJECT       := coltpython
TAGLINE       := pygame arcade game with a recorded-run mode
HELP_VARS      = PYTHON=$(PYTHON)  PIP=$(PIP)
HELP_EXAMPLE   = make run

# ─── Preamble ────────────────────────────────────────────────────────────────
# -e stops a recipe at the first failing command; -o pipefail stops a gate that
# pipes through a filter from reporting the filter's exit code instead of the
# command's — without it, a suite that fails into `tail` "passes".
SHELL         := /usr/bin/env bash
.SHELLFLAGS   := -eo pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS     += --no-print-directory

# ─── Colour ──────────────────────────────────────────────────────────────────
# MAKE_TERMOUT (GNU Make >= 4.1) is set only when stdout is a terminal, and is
# the only reliable test available here: `test -t 1` inside $(shell ...) always
# reports false, because make captures that command's stdout through a pipe.
# So `make help | less` and CI logs stay clean. NO_COLOR disables, FORCE_COLOR
# overrides both.
COLOR ?= $(if $(MAKE_TERMOUT),1,0)
ifdef NO_COLOR
  COLOR := 0
endif
ifdef FORCE_COLOR
  COLOR := 1
endif
ifeq ($(COLOR),1)
  # Real ESC bytes, so a plain `echo` renders them without needing -e.
  C_HEAD := $(shell printf '\033[1m')
  C_CMD  := $(shell printf '\033[36m')
  C_OK   := $(shell printf '\033[32m')
  C_WARN := $(shell printf '\033[33m')
  C_ERR  := $(shell printf '\033[31m')
  C_DIM  := $(shell printf '\033[2m')
  C_OFF  := $(shell printf '\033[0m')
endif

# Explains why a core verb does not apply here, then fails.
NA = @printf '  $(C_ERR)make $@$(C_OFF) does not apply to $(PROJECT).\n  $(C_DIM)%s$(C_OFF)\n\n' $(1) >&2; exit 2

# Width of the target-name column in help; widen it where names are long.
HELP_PAD ?= 18

# PROJECT, TAGLINE, HELP_VARS and HELP_EXAMPLE are interpolated into a
# single-quoted shell string below, so none of them may contain an apostrophe.
##@ General
.PHONY: help
help: ## List the available targets
	@printf '\n  $(C_HEAD)$(PROJECT)$(C_OFF) — $(TAGLINE)\n'
	@printf '  $(C_DIM)usage: make <target>$(C_OFF)\n'
	@awk 'BEGIN { FS = ":.*?## " } \
	  /^##@ / { printf "\n  $(C_HEAD)%s$(C_OFF)\n", substr($$0, 5); next } \
	  /^[a-zA-Z0-9_.-]+:.*?## / { printf "    $(C_CMD)%-$(HELP_PAD)s$(C_OFF) %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)
	@printf '\n  $(C_DIM)Variables:$(C_OFF) $(HELP_VARS)\n'
	@printf '  $(C_DIM)Example:$(C_OFF)   $(HELP_EXAMPLE)\n\n'

# ─── End of the shared block ─────────────────────────────────────────────────

# coltpython - Makefile
# Common development and runtime tasks.

PYTHON      ?= python3
PIP         ?= pip
SOURCE_DIR  := source
RECORDS_DIR := records
IMAGE_NAME  := coltpython

install: ## Install Python dependencies (pygame)
	$(PIP) install -r $(SOURCE_DIR)/requirements.txt

##@ Setup
.PHONY: setup
setup: install ## First run on a fresh clone: install the dependencies

##@ Development
.PHONY: dev
dev: run ## Same as run: this is a game, there is no dev server

.PHONY: build
build: ## Not applicable here
	$(call NA,'Nothing is built: the game runs from source. Use make run.')

run: ## Run the game (prompts for interactive/automatic mode)
	$(PYTHON) $(SOURCE_DIR)/game.py

test: ## Run the unit test suite
	cd $(SOURCE_DIR) && $(PYTHON) -m unittest tests -v

##@ Gates
.PHONY: check
check: test ## Fast gate: the unit test suite

.PHONY: verify
verify: check ## Full gate: same as check — there is no build step here

.PHONY: fmt
fmt: ## Not applicable here
	$(call NA,'No formatter is configured. Add ruff or black first.')

##@ Cleaning

clean: ## Remove Python bytecode caches
	find . -type d -name '__pycache__' -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete

clean-records: ## Remove saved game records (keeps .gitkeep)
	find $(RECORDS_DIR) -type f ! -name '.gitkeep' -delete

##@ Docker
docker-build: ## Build the Docker image
	docker build -t $(IMAGE_NAME) --no-cache -f dockerfile .

docker-run: docker-build ## Run the game in Docker with PulseAudio sound
	docker run -it --rm \
		-v $(CURDIR)/$(RECORDS_DIR):/app/$(RECORDS_DIR) \
		-v /run/user/1000/pulse:/run/user/1000/pulse \
		-v /etc/localtime:/etc/localtime:ro \
		-e PULSE_SERVER=unix:/run/user/1000/pulse/native \
		--device /dev/snd \
		--group-add audio \
		$(IMAGE_NAME)

docker-run-nosound: ## Run the game in Docker (no sound)
	docker run -it --rm \
		-v $(CURDIR)/$(RECORDS_DIR):/app/$(RECORDS_DIR) \
		-v /etc/localtime:/etc/localtime:ro \
		$(IMAGE_NAME)

docker-clean: ## Remove the Docker image
	-docker rmi $(IMAGE_NAME)

.PHONY: distclean
distclean: clean ## Same as clean: dependencies are installed system-wide here
