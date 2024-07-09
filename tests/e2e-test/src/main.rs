use clap::Parser;

//use std::time::Duration;
use std::time::Instant;
use std::path::PathBuf;

use images::file::run_prove;


type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

#[derive(Parser, Debug)]
#[clap(author = "Gevulot Team", version, about, long_about = None)]
pub struct ArgConfiguration {

    #[clap(short, long, default_value = "http://localhost:9944")]
    pub json_rpc_url: String,
    #[clap(short, long, default_value = "localkey.pki")]
    pub key_file: PathBuf,
    
    /// Optional Address of the local http server use by the node to download input file.
    #[clap(short, long, default_value = "http://4.145.88.10:8080")]
     local_http_url: String,

    #[clap(short, long, default_value = "735dd3a758ca4a7ddb17965a016068e789424eced65727549014f159e929cfa4")]
    pub prover_hash: String,

    #[clap(short, long, default_value = "2390dcb2a644823ffe63e5a0e586cf20e69ab02479b011ece3b46614189a4cff")]
    pub verifier_hash: String,

    #[arg( long = "trace_file", default_value = "solidityExample.json")]
    trace_file: String,
    #[arg( long = "bi_file", default_value = "lr_chunks_0.data")]
    bi_file: String,
    #[arg( long = "asm_file", default_value = "lr.asm")]
    asm_file: String,
    #[arg( long = "task_name", default_value = "lr")]
    task_name: String,
    #[arg(long = "chunk_id", default_value = "0") ]
    chunk_id: String,
    
    //the http_server_work_path is set during the installation of the http file server.
    #[arg( long = "http_server_work_path", default_value = "/data/http/")]
    http_server_work_path: String,

    //the saving path when downloading the proof file from the Gevulot server.
    #[arg( long = "proof_file_out_path", default_value = "/tmp/gevulot/")]
    proof_file_out_path: String,
    #[clap(long = "rpctimeout", value_name = "RPC TIMEOUT")]
    rpc_timeout: Option<u64>,
 
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    log::info!("ZKVM-Gevulot e2e-test ...");
    let cfg = ArgConfiguration::parse();
 
    log::info!("before proving :");
    let start = Instant::now();
    

     run_prove(&cfg.json_rpc_url, &cfg.key_file, &cfg.prover_hash, &cfg.verifier_hash , &cfg.trace_file, &cfg.bi_file,
                    &cfg.asm_file,
                    &cfg.task_name,
                    &cfg.chunk_id,
                    &cfg.http_server_work_path,
                    &cfg.local_http_url,
                    &cfg.proof_file_out_path,
                    cfg.rpc_timeout
            ).await?; 

   
    let duration = start.elapsed();
    log::info!("Finish Gevulot proving, duration: {:?}", duration);

    Ok(())
}
