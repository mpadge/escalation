use std::path::Path;

use crate::aggregate::RunSummary;
use crate::sim::MetricSeries;

/// Write a slice of RunSummary records to a CSV file at the given path.
pub fn write_summaries(path: &Path, records: &[RunSummary]) -> std::io::Result<()> {
    let mut wtr = csv::Writer::from_path(path)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    for record in records {
        wtr.serialize(record)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    }
    wtr.flush()
}

/// Write a MetricSeries to per-run CSV files in the given directory (diagnostic/debug mode).
pub fn write_series(dir: &Path, summary: &RunSummary, series: &MetricSeries) -> std::io::Result<()> {
    let fname = dir.join(format!("series_seed{}_mu0{:.3}.csv", summary.seed, summary.mu0));
    let mut wtr = csv::Writer::from_path(&fname)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    wtr.write_record(["t", "mean_epsilon", "var_epsilon", "gini_k",
        "epsilon_k_corr", "mean_edge_weight", "regime_cc", "regime_x", "regime_ck",
        "modularity", "rich_club"])
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    for i in 0..series.t.len() {
        wtr.write_record(&[
            series.t[i].to_string(),
            series.mean_epsilon[i].to_string(),
            series.var_epsilon[i].to_string(),
            series.gini_k[i].to_string(),
            series.epsilon_k_corr[i].to_string(),
            series.mean_edge_weight[i].to_string(),
            series.regime_dist[i][0].to_string(),
            series.regime_dist[i][1].to_string(),
            series.regime_dist[i][2].to_string(),
            series.modularity[i].to_string(),
            series.rich_club[i].to_string(),
        ]).map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    }
    wtr.flush()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aggregate::{aggregate, RunSummary};
    use crate::params::Params;
    use crate::sim::run_simulation;

    #[test]
    fn round_trip_run_summary_csv() {
        let mut params = Params::default();
        params.n = 20;
        params.t_max = 50;

        let series = run_simulation(&params, 1);
        let original = aggregate(series, &params, 1);

        let path = std::path::Path::new("/tmp/escalation_round_trip_test.csv");
        write_summaries(path, &[original.clone()]).unwrap();

        // Read back via csv crate
        let mut rdr = csv::Reader::from_path(path).unwrap();
        let records: Vec<RunSummary> = rdr
            .deserialize()
            .collect::<Result<_, _>>()
            .unwrap();
        assert_eq!(records.len(), 1);
        let recovered = &records[0];

        // Verify all f64 fields match to 6 significant figures
        fn sig6(a: f64, b: f64) -> bool {
            if a == 0.0 && b == 0.0 { return true; }
            let scale = a.abs().max(b.abs());
            (a - b).abs() / scale < 1e-6
        }

        assert!(sig6(original.mu0, recovered.mu0), "mu0 mismatch");
        assert!(sig6(original.gamma, recovered.gamma), "gamma mismatch");
        assert!(sig6(original.mean_epsilon_final, recovered.mean_epsilon_final),
            "mean_epsilon_final mismatch: {} vs {}", original.mean_epsilon_final, recovered.mean_epsilon_final);
        assert!(sig6(original.epsilon_auc, recovered.epsilon_auc),
            "epsilon_auc mismatch");
        assert!(sig6(original.epsilon_slope, recovered.epsilon_slope),
            "epsilon_slope mismatch");
        assert!(sig6(original.gini_peak, recovered.gini_peak),
            "gini_peak mismatch");
        assert!(sig6(original.regime_cc, recovered.regime_cc),
            "regime_cc mismatch");
    }

    #[test]
    fn write_series_creates_file() {
        let mut params = Params::default();
        params.n = 20;
        params.t_max = 50;

        let series = run_simulation(&params, 2);
        let cloned = series.clone();
        let summary = aggregate(cloned, &params, 2);

        let dir = std::path::Path::new("/tmp");
        write_series(dir, &summary, &series).unwrap();

        let fname = dir.join(format!("series_seed{}_mu0{:.3}.csv", 2, params.mu0));
        assert!(fname.exists(), "series file should exist: {fname:?}");
        let content = std::fs::read_to_string(&fname).unwrap();
        let lines: Vec<&str> = content.lines().collect();
        // header + (t_max / RECORD_INTERVAL) rows = header + 0 rows when t_max=50 < RECORD_INTERVAL=100
        // or header + 1 row if we record at step 50... actually RECORD_INTERVAL=100, t_max=50, so 0 data rows
        assert!(lines.len() >= 1, "file should at least have header");
    }
}
