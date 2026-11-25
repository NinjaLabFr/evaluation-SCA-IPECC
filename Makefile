# Inputs
DATASET      ?= ipecc_level_1-0.h5
DATA_DIR     ?= ./datasets
PARTS        ?= $(DATA_DIR)/ipecc_level_1-0_part_0.h5 $(DATA_DIR)/ipecc_level_1-0_part_1.h5

DATASET_PATH := $(DATA_DIR)/$(DATASET)
SUBTRACES    := $(DATA_DIR)/subtraces.h5

CYAN  := $(shell printf '\033[36m')
BLUE  := $(shell printf '\033[34m')
RESET := $(shell printf '\033[0m')

.DEFAULT_GOAL := help

# Help
.PHONY: help
help:
	@echo "In every make command below, please set the variables $(BLUE)DATASET$(RESET) and $(BLUE)DATA_DIR$(RESET)"
	@echo "Example: $(CYAN)make all$(RESET) $(BLUE)DATASET$(RESET)=ipecc_level_1-0.h5 $(BLUE)DATA_DIR$(RESET)=./datasets"
	@echo "Default values otherwise : $(BLUE)DATASET$(RESET)=$(DATASET)  $(BLUE)DATA_DIR$(RESET)=$(DATA_DIR)"
	@echo ""
	@echo "Choose an operation"
	@echo "  $(CYAN)make all$(RESET)        Run the full SCA flow on $(BLUE)$(DATASET_PATH)$(RESET)"
	@echo "  $(CYAN)make kappas$(RESET)     Compute kappas"
	@echo "  $(CYAN)make splitting$(RESET)  Split traces into $(BLUE)$(SUBTRACES)$(RESET)"
	@echo "  $(CYAN)make snr$(RESET)        Compute SNR"
	@echo "  $(CYAN)make attack$(RESET)     Run template attack"
	@echo "  $(CYAN)make link$(RESET)       Concatenate subsets into $(BLUE)$(DATASET_PATH)$(RESET) (if needed)"
	@echo ""




# compute kappas
.PHONY: kappas
kappas: $(DATASET_PATH)
	python3 compute_kappas.py -d "$(DATASET_PATH)" -t "$(DATA_DIR)"

# splitting scalar multiplication traces into iteration subtraces
.PHONY: splitting
splitting: $(SUBTRACES)
$(SUBTRACES): $(DATASET_PATH)
	python3 splitting.py -d "$(DATASET_PATH)" -t "$(DATA_DIR)" -r

# SNR
.PHONY: snr
snr: $(SUBTRACES)
	python3 compute_snr.py -d "$(SUBTRACES)" -o "$(DATA_DIR)"

# template attack
.PHONY: attack
attack: $(SUBTRACES)
	python3 template_attack.py -d "$(SUBTRACES)" -i kappa_prime -t 0.0009

# full sca flow 
.PHONY: all
all: kappas snr attack

#link datasets
.PHONY: link
link: $(PARTS)
	python3 link_datasets.py $(PARTS) -o "$(DATASET_PATH)"