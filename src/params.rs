#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct Params {
    pub n: usize,
    pub gamma: f64,
    pub mu0: f64,
    pub sigma0: f64,
    pub lambda: f64,
    pub alpha: f64,
    pub theta: u8,
    pub beta: f64,
    pub c: f64,
    pub w_win: f64,
    pub w_loss: f64,
    pub e: f64,
    pub b: f64,
    pub dw_sub: f64,
    pub dw_coop: f64,
    pub dw_bridge: f64,
    pub dw_obs: f64,
    pub dw_excl: f64,
    pub delta_direct: f64,
    pub delta_exploit: f64,
    pub delta: f64,
    pub w_min: f64,
    pub w_max: f64,
    pub eta: f64,
    pub eta_obs: f64,
    pub sigma_drift: f64,
    pub mu_sigma: f64,
    pub sigma_sigma: f64,
    pub eta_sigma: f64,
    pub rho_contested: f64,
    pub eta_trauma: f64,
    pub t_max: u32,
}

impl Default for Params {
    fn default() -> Self {
        Self {
            n: 550,
            gamma: 3.0,
            mu0: 0.5,
            sigma0: 0.25,
            lambda: 3.0,
            alpha: 1.0,
            theta: 2,
            beta: 1.5,
            c: 0.5,
            w_win: 1.0,
            w_loss: 1.0,
            e: 0.5,
            b: 1.0,
            dw_sub: 0.15,
            dw_coop: 0.15,
            dw_bridge: 0.1,
            dw_obs: 0.1,
            dw_excl: 0.1,
            delta_direct: 0.05,
            delta_exploit: 0.05,
            delta: 0.025,
            w_min: 0.05,
            w_max: 3.0,
            eta: 0.1,
            eta_obs: 0.05,
            sigma_drift: 0.025,
            mu_sigma: 1.0,
            sigma_sigma: 0.2,
            eta_sigma: 0.05,
            rho_contested: 0.55,
            eta_trauma: 0.1,
            t_max: 10_000,
        }
    }
}

impl Params {
    pub fn r_win_cost(&self) -> f64 {
        self.w_win / self.c
    }

    pub fn r_coop_exploit(&self) -> f64 {
        self.b / self.e
    }

    pub fn r_loss_win(&self) -> f64 {
        self.w_loss / self.w_win
    }

    pub fn r_obs_coop(&self) -> f64 {
        self.dw_obs / self.dw_coop
    }

    pub fn r_bridge_sub(&self) -> f64 {
        self.dw_bridge / self.dw_sub
    }

    pub fn kappa(&self) -> f64 {
        self.eta_obs / self.eta
    }

    pub fn with_mu0(&self, mu0: f64) -> Self {
        let mut p = self.clone();
        p.mu0 = mu0;
        p
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_params_serde_round_trip() {
        let p = Params::default();
        let json = serde_json::to_string(&p).expect("serialize");
        let p2: Params = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(p.n, p2.n);
        assert_eq!(p.mu0, p2.mu0);
        assert_eq!(p.gamma, p2.gamma);
        assert_eq!(p.theta, p2.theta);
        assert_eq!(p.w_max, p2.w_max);
    }
}
