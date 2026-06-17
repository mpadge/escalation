#!/usr/bin/make

.PHONY: help build release test clean archive \
        screen sobol explore train gini plots doc all \
        validate status progress kill

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

##@ Analysis pipeline  (run steps 1–6 in order, or use 'make all' for 3–6)

screen: release ## [step 1] Morris screening — results/morris_results.csv
	Rscript analysis/screen.R

sobol: release ## [step 2] Sobol sensitivity — results/sobol_results.csv  (needs step 1)
	Rscript analysis/sobol.R

explore: release ## [step 3] Adaptive GP exploration — results/gp_psi.rds  (needs step 2)
	Rscript analysis/gp_explore.R

train: ## [step 4] GP training (edeg, psi_sigma) — results/gp_*.rds  (needs step 3)
	Rscript analysis/gp_train.R

gini: ## [step 5] Gini GP analysis — results/gp_gini*.rds  (needs step 3)
	Rscript analysis/gini.R

plots: ## [step 6] All figures — results/figures/*.png  (needs steps 4–5)
	Rscript analysis/plot.R

all: explore train gini plots ## Run steps 3–6 in sequence (explore → train → gini → plots)

##@ Documentation

doc: ## [step 7] Render report  (write docs/report.md first, then run this)
	cd docs && pandoc -f markdown report.myst --bibliography references.bib --citeproc -t markdown -o report.md

##@ Utilities

status: ## Show which pipeline steps are complete and what to run next
	@bash tools/status.bash

progress: ## Show progress of running sensitivity analysis (screen/sobol/explore)
	@bash tools/progress.bash

kill: ## Kill all running escalation processes
	@pkill -f 'target/release/escalation' && echo "Killed." || echo "No escalation process running."

clean: ## Remove build artefacts and generated results
	cargo clean
	rm -f results/*.csv results/*.rds results/*.rds
	rm -rf results/gp_phase results/figures
	rm -rf /tmp/escalation

archive: ## Archive current results into results/<stage>/
	@bash tools/archive.bash
