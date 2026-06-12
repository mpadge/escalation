#!/usr/bin/make

.PHONY: help build release test clean archive morris sobol gp validate status progress kill plots gp2 gp2_phase plots2 gp3

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} \
	    /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
	    /^[0-9a-zA-Z_-]+:.*##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' \
	    $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

##@ Rust

build: ## Debug build
	cargo build

release: ## Release build (required before running analysis scripts)
	cargo build --release

test: ## Run all Rust unit and integration tests
	cargo test

validate: release ## Run validate subcommand (N=50, T=1000, dump series to /tmp)
	./target/release/escalation validate --params default --dump-series

##@ Analysis

morris: release ## Run Morris screening (analysis/morris.R)
	Rscript analysis/morris.R

sobol: release ## Run Sobol analysis (analysis/sobol.R) — requires morris_results.csv
	Rscript analysis/sobol.R

gp: release ## Run GP emulation: train + phase diagrams (analysis/gp_{train,phase}.R)
	Rscript analysis/gp_train.R
	Rscript analysis/gp_phase.R

plots: ## Generate all plots (analysis/plot.R) — requires sobol/GP outputs
	Rscript analysis/plot.R

gp2: ## Train two-GP emulators on absolute escalation surfaces (Stage 2)
	Rscript analysis/gp_train2.R

gp2_phase: ## Generate two-GP phase diagrams for E_lo, E_hi, and Psi surfaces (Stage 2)
	Rscript analysis/gp_phase2.R

plots2: ## Generate Stage 2 phase diagram plots
	Rscript analysis/plot2.R

gp3: ## Train two-GP emulators on epsilon-degree correlation surfaces (Stage 3)
	Rscript analysis/gp_train3.R

##@ Utilities

status: ## Show which pipeline steps are complete and what to run next
	@bash tools/status.bash

progress: ## Show progress of running sensitivity analysis (morris/sobol/gp-train)
	@bash tools/progress.bash

kill: ## Kill all running escalation processes
	@pkill -f 'target/release/escalation' && echo "Killed." || echo "No escalation process running."

clean: ## Remove build artefacts and generated results
	cargo clean
	rm -f results/*.csv results/*.rds
	rm -rf results/gp_phase results/plots
	rm -rf /tmp/escalation

archive: ## Move current results into results/<current-specs-phase>/
	@bash tools/archive.bash
