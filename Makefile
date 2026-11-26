# Inputs
DATASET      ?= ipecc_level_1-0.h5
DATA_DIR     ?= ./datasets
PARTS        ?= $(DATA_DIR)/ipecc_level_1-0_part_0.h5 $(DATA_DIR)/ipecc_level_1-0_part_1.h5

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
	@echo "  Use $(BOLD)$(GREEN)PARTS$(RESET) only for $(CYAN)make link$(RESET) (concatenate subsets into one virtual dataset)."
	@echo ""
	@echo "  $(DIM)Defaults: $(GREEN)DATASET$(RESET)$(DIM)=$(DATASET)  $(GREEN)DATA_DIR$(RESET)$(DIM)=$(DATA_DIR)  $(GREEN)PARTS$(RESET)$(DIM)=$(PARTS)$(RESET)"
	@echo ""
	@echo "$(BOLD)Targets$(RESET)"
	@echo "  $(CYAN)make all$(RESET)        Run the full SCA flow on $(DATASET_PATH)"
	@echo "  $(CYAN)make kappas$(RESET)     Compute kappas"
	@echo "  $(CYAN)make splitting$(RESET)  Split traces into $(SUBTRACES)"
	@echo "  $(CYAN)make snr$(RESET)        Compute SNR"
	@echo "  $(CYAN)make attack$(RESET)     Run template attack"
	@echo "  $(CYAN)make link$(RESET)       Concatenate subsets into $(DATASET_PATH) (if needed)"
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


#compute kappas
.PHONY: kappas
kappas: $(DATASET_PATH)
	python3 compute_kappas.py -d "$(DATASET_PATH)" -t "$(DATA_DIR)"

#splitting scalar multiplication traces into iteration subtraces
.PHONY: splitting
splitting: $(SUBTRACES)
$(SUBTRACES): $(DATASET_PATH)
	python3 splitting.py -d "$(DATASET_PATH)" -t "$(DATA_DIR)" -r

#SNR
.PHONY: snr
snr: $(SUBTRACES)
	python3 compute_snr.py -d "$(SUBTRACES)" -o "$(DATA_DIR)"

#template attack
.PHONY: attack
attack: $(SUBTRACES)
	python3 template_attack.py -d "$(SUBTRACES)" -i kappa_prime -t 0.0009

#full sca flow 
.PHONY: all
all: kappas snr attack

#link datasets
.PHONY: link
link: $(PARTS)
	python3 link_datasets.py $(PARTS) -o "$(DATASET_PATH)"