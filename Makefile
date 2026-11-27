# Inputs
SRC_DIR      := src
DATASET      ?=
DATA_DIR     ?=
PARTS        ?=

DATASET_PATH := $(DATA_DIR)/$(DATASET)
SUBTRACES    := $(DATA_DIR)/subtraces.h5


# Abort early on error
SHELL        := /bin/bash
.SHELLFLAGS  := -euo pipefail -c
.DELETE_ON_ERROR:
.NOTPARALLEL:


CYAN  := $(shell printf '\033[36m')
GREEN := $(shell printf '\033[32m')
DIM   := $(shell printf '\033[2m')
BOLD  := $(shell printf '\033[1m')
RESET := $(shell printf '\033[0m')

.DEFAULT_GOAL := help

# Help
.PHONY: help
help:
	@echo "$(BOLD)Usage$(RESET)"
	@echo "  $(CYAN)make$(RESET) $(CYAN)<target>$(RESET) [$(BOLD)$(GREEN)DATASET$(RESET)=<name.h5>] [$(BOLD)$(GREEN)DATA_DIR$(RESET)=<dir>] [$(BOLD)$(GREEN)PARTS$(RESET)=\"<part_0.h5> <part_1.h5> ...\"]"
	@echo ""
	@echo "  Every command needs $(BOLD)$(GREEN)DATASET$(RESET) and $(BOLD)$(GREEN)DATA_DIR$(RESET)."
	@echo "  Use $(BOLD)$(GREEN)PARTS$(RESET) only for $(CYAN)make link$(RESET) / $(CYAN)make docker-link$(RESET) (concatenate subsets into one virtual dataset)."
	@echo ""
	@echo "  $(DIM)Defaults: $(GREEN)DATASET$(RESET)$(DIM)=$(DATASET)  $(GREEN)DATA_DIR$(RESET)$(DIM)=$(DATA_DIR)  ($(GREEN)PARTS$(RESET)$(DIM) required for link / docker-link)$(RESET)"
	@echo ""
	@echo "$(BOLD)Targets$(RESET)"
	@echo "  $(CYAN)make all$(RESET)         Run the full SCA flow on DATASET_PATH"
	@echo "  $(CYAN)make docker-all$(RESET)  Run the full SCA flow in Docker"
	@echo "  $(CYAN)make kappas$(RESET)      Compute kappas"
	@echo "  $(CYAN)make splitting$(RESET)   Split traces into DATA_DIR/subtraces.h5"
	@echo "  $(CYAN)make snr$(RESET)         Compute SNR"
	@echo "  $(CYAN)make attack$(RESET)      Run template attack"
	@echo "  $(CYAN)make link$(RESET)        Concatenate subsets into DATASET_PATH (if needed)"
	@echo "  $(CYAN)make docker-link$(RESET) Concatenate subsets into DATASET_PATH in Docker (if needed)"
	@echo "  $(CYAN)make demo$(RESET)        Run the level3.1 demo (local)"
	@echo "  $(CYAN)make demo-docker$(RESET) Run the level3.1 demo (Docker)"
	@echo ""
	@echo "$(BOLD)Examples$(RESET)"
	@echo "  $(BOLD)Full flow$(RESET)"
	@echo "    $(CYAN)make all$(RESET) $(GREEN)DATASET$(RESET)=ipecc_level_1-0.h5 $(GREEN)DATA_DIR$(RESET)=./datasets"
	@echo ""
	@echo "  $(BOLD)Single steps$(RESET)"
	@echo "    $(CYAN)make kappas$(RESET)    $(GREEN)DATASET$(RESET)=ipecc_level_1-0.h5 $(GREEN)DATA_DIR$(RESET)=./datasets"
	@echo "    $(CYAN)make splitting$(RESET) $(GREEN)DATASET$(RESET)=ipecc_level_1-0.h5 $(GREEN)DATA_DIR$(RESET)=./datasets"
	@echo "    $(CYAN)make snr$(RESET)       $(GREEN)DATASET$(RESET)=ipecc_level_1-0.h5 $(GREEN)DATA_DIR$(RESET)=./datasets"
	@echo "    $(CYAN)make attack$(RESET)    $(GREEN)DATASET$(RESET)=ipecc_level_1-0.h5 $(GREEN)DATA_DIR$(RESET)=./datasets"
	@echo ""
	@echo "  $(BOLD)Concatenate subsets$(RESET)"
	@echo "    $(CYAN)make link$(RESET) $(GREEN)DATASET$(RESET)=linked.h5 $(GREEN)DATA_DIR$(RESET)=./datasets $(GREEN)PARTS$(RESET)=\"./datasets/ipecc_level_1-0_part_0.h5 ./datasets/ipecc_level_1-0_part_1.h5\""
	@echo "    $(CYAN)make docker-link$(RESET) $(GREEN)DATASET$(RESET)=linked.h5 $(GREEN)DATA_DIR$(RESET)=./datasets $(GREEN)PARTS$(RESET)=\"./datasets/ipecc_level_1-0_part_0.h5 ./datasets/ipecc_level_1-0_part_1.h5\""


#full sca flow
.PHONY: all
all: require-dataset require-data-dir kappas snr attack


#explicit error printing with target name and example.
.PHONY: require-dataset require-data-dir require-parts
require-parts:
	@if [ -z "$(strip $(PARTS))" ]; then \
		echo "error: $(BOLD)target '$(MAKECMDGOALS)' requires $(CYAN)PARTS$(RESET)." >&2; \
		echo "  PARTS is a space-separated list of the H5 subset files to concatenate." >&2; \
		echo "  example:" >&2; \
		echo "    $(CYAN)make $(MAKECMDGOALS) DATASET=linked.h5 DATA_DIR=./datasets PARTS=\"./datasets/ipecc_level_1-0_part_0.h5 ./datasets/ipecc_level_1-0_part_1.h5\" $(RESET)" >&2; \
		exit 1; \
	fi
require-dataset:
	@if [ -z "$(strip $(DATASET))" ]; then \
		echo "error: $(BOLD)target '$(MAKECMDGOALS)' requires $(CYAN)DATASET$(RESET)." >&2; \
		echo "  DATASET is the H5 dataset filename to use for SCA Flow (the concatenated virtual dataset is using several subsets)." >&2; \
		echo "  example:" >&2; \
		echo "    $(CYAN)make $(MAKECMDGOALS) DATASET=ipecc_level_1-0.h5 DATA_DIR=./datasets $(RESET)" >&2; \
		exit 1; \
	fi

require-data-dir:
	@if [ -z "$(strip $(DATA_DIR))" ]; then \
		echo "error: $(BOLD)target '$(MAKECMDGOALS)' requires $(CYAN)DATA_DIR$(RESET)." >&2; \
		echo "  DATA_DIR is the directory containing the H5 dataset files." >&2; \
		echo "  example:" >&2; \
		echo "    $(CYAN)make $(MAKECMDGOALS) DATASET=ipecc_level_1-0.h5 DATA_DIR=./datasets $(RESET)" >&2; \
		exit 1; \
	fi


#compute kappas
.PHONY: kappas
kappas: require-dataset require-data-dir $(DATASET_PATH)
	python3 $(SRC_DIR)/compute_kappas.py -d "$(DATASET_PATH)" -t "$(DATA_DIR)"

#splitting
.PHONY: splitting
splitting: require-dataset require-data-dir $(SUBTRACES)
$(SUBTRACES): $(DATASET_PATH)
	python3 $(SRC_DIR)/splitting.py -d "$(DATASET_PATH)" -t "$(DATA_DIR)" -r

#SNR
.PHONY: snr
snr: require-dataset require-data-dir $(SUBTRACES)
	python3 $(SRC_DIR)/compute_snr.py -d "$(SUBTRACES)" -o "$(DATA_DIR)"

#template attack
.PHONY: attack
attack: require-dataset require-data-dir $(SUBTRACES)
	python3 $(SRC_DIR)/template_attack.py -d "$(SUBTRACES)" -i kappa_prime -t 0.0009

#link datasets
.PHONY: link
link: require-dataset require-data-dir require-parts
	python3 $(SRC_DIR)/link_datasets.py $(PARTS) -o "$(DATASET_PATH)"


# Test level 3.1
.PHONY: demo demo-local demo-docker
demo: demo-local

demo-local:
	bash $(SRC_DIR)/test_level3-1.sh local

demo-docker:
	bash $(SRC_DIR)/test_level3-1.sh docker

# docker
IMAGE      ?= ipecc
DOCKER_RUN := docker run --rm
STAMP      := .docker-image.stamp

# Files whose change triggers an image rebuild
SRC_FILES := $(wildcard $(SRC_DIR)/*.py $(SRC_DIR)/*.sh) \
             $(wildcard $(SRC_DIR)/notebooks/*.ipynb) \
             $(wildcard $(SRC_DIR)/*.ipynb)

$(STAMP): Dockerfile requirements.txt Makefile $(SRC_FILES)
	docker build -t $(IMAGE) .
	@touch $@

.PHONY: docker-build
docker-build: $(STAMP)

.PHONY: docker-link docker-all

# Host paths (PARTS) -> container paths (/datasets/...)
DOCKER_PARTS := $(patsubst $(DATA_DIR)/%,/datasets/%,$(PARTS))

docker-link: require-dataset require-data-dir require-parts $(STAMP)
	@for p in $(PARTS); do \
		case "$$p" in \
			$(DATA_DIR)/*) ;; \
			*) echo "error: docker-link expects PARTS entries under $(DATA_DIR)/ (got '$$p')" >&2; \
			   echo "  example: PARTS=\"$(DATA_DIR)/ipecc_level_1-0_part_0.h5 $(DATA_DIR)/ipecc_level_1-0_part_1.h5\"" >&2; \
			   exit 1 ;; \
		esac; \
	done
	$(DOCKER_RUN) -v "$$(pwd)/$(DATA_DIR)":/datasets $(IMAGE) link \
		DATASET=$(DATASET) DATA_DIR=/datasets PARTS="$(DOCKER_PARTS)"

docker-all: require-dataset require-data-dir $(STAMP)
	$(DOCKER_RUN) -v "$$(pwd)/$(DATA_DIR)":/datasets $(IMAGE) all \
		DATASET=$(DATASET) DATA_DIR=/datasets
