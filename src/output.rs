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

    #[test]
    fn round_trip_run_summary_csv() {
        use crate::params::Params;
        use crate::aggregate::aggregate;
        use crate::sim::run_simulation;

        let mut params = Params::default();
        params.n = 20;
        params.t_max = 50;

        let series = run_simulation(&params, 0);
        let summary = aggregate(series, &params, 0);

        let path = std::path::Path::new("/tmp/escalation_output_test.csv");
        write_summaries(path, &[summary.clone()]).unwrap();

        let content = std::fs::read_to_string(path).unwrap();
        let mut lines = content.lines();
        let _header = lines.next().unwrap();
        let row = lines.next().unwrap();
        assert!(!row.is_empty(), "data row should not be empty");
        assert!(summary.mean_epsilon_final.is_finite());
    }
}
