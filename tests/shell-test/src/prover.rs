extern crate clap;
use clap::{command, Parser};


use starky::prove::stark_prove;
use std::time::Instant;
use std::fs;

use std::fs::File;
use std::io::Write;


#[derive(Debug, Parser, Default)]
#[command(about, version, no_binary_name(true))]
struct Cli {
    #[arg(short, long = "stark_stuct", default_value = "stark_struct.json")]
    stark_struct: String,
    #[arg(short, long = "piljson", default_value = "pil.json")]
    piljson: String,
    #[arg(short, long = "norm_stage", action= clap::ArgAction::SetTrue)]
    norm_stage: bool,
    #[arg(long = "skip_main", action= clap::ArgAction::SetTrue)]
    skip_main: bool,
    #[arg(short, long = "agg_stage", action= clap::ArgAction::SetTrue)]
    agg_stage: bool,
    #[arg(long = "const_pols", default_value = "pols.const")]
    const_pols: String,
    #[arg(long = "cm_pols", default_value = "pols.cm")]
    cm_pols: String,
    #[arg(short, long = "circom", default_value = "stark_verfier.circom")]
    circom_file: String,
    #[arg(long = "proof_file", default_value = "zkin.json")]
    zkin: String,
    #[arg(
        long = "prover_addr",
        default_value = "273030697313060285579891744179749754319274977764"
    )]
    prover_addr: String,
}

//use gevulot_common::WORKSPACE_PATH;
use gevulot_shim::{Task, TaskResult};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

fn main()-> Result<()>  {
   gevulot_shim::run(run_task)
}

fn run_task(task: Task) -> Result<TaskResult> {

    env_logger::init();
 
    println!("0xEigenLabs prover : task.args: {:?}", &task.args);
    
    let args =  Cli::parse_from(&task.args);

    log::info!("parameters: proof file:{}; circom fiel:{}",args.zkin,args.circom_file);
    log::info!("parameters: args.stark_struct:{} ; args.piljson:{}; args.const_pols:{}", args.stark_struct, args.piljson, args.const_pols);
    log::info!("parameters: norm_stage:{} ; args.skip_main:{} ; args.agg_stage:{}", args.norm_stage, args.skip_main, args.agg_stage);

    let mut log_file = File::create("/workspace/test.log")?;
    write!(log_file, "stark_struct:{}\n",  &args.stark_struct)?;
    write!(log_file, "piljson:{}\n",  &args.piljson)?;
    write!(log_file, "const_pols:{}\n",  &args.const_pols)?;
    write!(log_file, "cm_pols:{}\n",  &args.cm_pols)?;
    write!(log_file, "proof:{}\n",  &args.zkin)?;
    write!(log_file, "circom:{}\n", &args.circom_file)?;

   
    let exec_result = stark_prove(
        &args.stark_struct,
        &args.piljson,
        //args.norm_stage,  //The current gevulot release version doesn't support bool in its "cmd_args",eg. {"name":"--norm_stage","value": ""}. The engineer gives a patch for the bug :
                            //crates/cli/src/lib.rs  +138
                            /*let step = WorkflowStep {
                                program: (&(hex::decode(args.program)
                                    .map_err(|err| format!("program decoding hash error:{err}"))?)[..])
                                    .into(),
                                args: args
                                    .cmd_args
                                    .into_iter()
                                    .flat_map(<[String; 2]>::from)
                                    .filter(|x| !x.is_empty())  //fix the bug which does not support bool in the "cmd_args" .
                                    .collect(),
                                inputs: input_data,
                            }; */
        true,
        args.skip_main,
        args.agg_stage,
        &args.const_pols,
        &args.cm_pols,
        &args.circom_file,
        &args.zkin,
        &args.prover_addr,
    );

    
    match exec_result {
        Err(x) => {
            log::info!("The prover has error: {}", x);
            write!(log_file, "The prover has error: {}\n", x)?;
        }
        _ => write!(log_file, "The prover executes successfully.\n")?,
    };

    log::info!("The prover executes successfully");

    // Write generated proof to a file.
    //std::fs::write("/workspace/proof.json", b"this is a proof a.")?;

    //return three files for Verifier
    task.result(vec![], vec![String::from("/workspace/proof.json"),String::from("/workspace/stark_verfier.circom"),String::from("/workspace/test.log")])

}
