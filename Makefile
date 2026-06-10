#!/usr/bin/make

.PHONY: help build release test clean morris sobol gp validate

help: ## Show this help
	@printf "Usage:\033[36m make [target]\033[0m\n"
	@grep -E '^[a-zA-Z_%_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

build: ## Debug build
	cargo build

release: ## Release build (required before running analysis scripts)
	cargo build --release

test: ## Run all Rust unit and integration tests
	cargo test

validate: release ## Run validate subcommand (N=50, T=1000, dump series to /tmp)
	./target/release/escalation validate --params default --dump-series

morris: release ## Run Morris screening (analysis/morris.R)
	Rscript analysis/morris.R

sobol: release ## Run Sobol analysis (analysis/sobol.R) — requires morris_results.csv
	Rscript analysis/sobol.R

gp: release ## Run GP emulation: train + phase diagrams (analysis/gp_{train,phase}.R)
	Rscript analysis/gp_train.R
	Rscript analysis/gp_phase.R

progress: ## Show progress of running sensitivity analysis (morris/sobol/gp-train)
	@bash tools/progress.bash

kill: ## Kill all running escalation processes
	@pkill -f 'target/release/escalation' && echo "Killed." || echo "No escalation process running."

plots: ## Generate all plots (analysis/plot.R) — requires sobol/GP outputs
	Rscript analysis/plot.R

clean: ## Remove build artefacts and generated CSVs
	cargo clean
	rm -f design_*.csv morris_raw.csv sobol_raw.csv gp_train_raw.csv gp_data.csv \
	      gp_hyperparams.csv gp_validation.csv gp_psi.rds gp_tau.rds sobol_gp.csv \
	      phase_*.csv morris_results.csv sobol_results.csv gp_train.csv
