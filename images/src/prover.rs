extern crate clap;
use clap::{command, Parser};

use std::io::prelude::*;

//from lib.rs
use anyhow::Result;
use powdr::backend::BackendType;
use powdr::number::{DegreeType, FieldElement, GoldilocksField};
use powdr::riscv::continuations::{rust_continuations, rust_continuations_dry_run};
use powdr::riscv::{compile_rust, Runtime};
use powdr::Pipeline;
use recursion::pilcom::export as pil_export;
use starky::{
    merklehash::MerkleTreeGL,
    pil2circom,
    stark_setup::StarkSetup,
    types::{StarkStruct, Step},
};
use std::fs::{self, create_dir_all /*, remove_dir_all*/};
use std::io::BufWriter;
use std::path::Path;
use std::time::Instant;

const TEST_CHANNEL: u32 = 1;
fn generate_witness_and_prove<F: FieldElement>(
    mut pipeline: Pipeline<F>,
) -> Result<(), Vec<String>> {
    let start = Instant::now();
    log::debug!("Generating witness...");
    pipeline.compute_witness().unwrap();
    let duration = start.elapsed();
    log::debug!("Generating witness took: {:?}", duration);

    let start = Instant::now();
    log::debug!("Proving ...");

    pipeline = pipeline.with_backend(BackendType::EStarkStarky, Some("stark_gl".to_string()));
    pipeline.compute_proof().unwrap();
    let duration = start.elapsed();
    log::debug!("Proving took: {:?}", duration);
    Ok(())
}

fn generate_verifier<F: FieldElement, W: std::io::Write>(
    mut pipeline: Pipeline<F>,
    mut writer: W,
) -> Result<()> {
    let buf = Vec::new();
    let mut vw = BufWriter::new(buf);
    pipeline = pipeline.with_backend(BackendType::EStarkStarky, Some("stark_gl".to_string()));
    pipeline.export_verification_key(&mut vw).unwrap();
    log::debug!("Export verification key done");
    let mut setup: StarkSetup<MerkleTreeGL> = serde_json::from_slice(&vw.into_inner()?)?;
    log::debug!("Load StarkSetup done");

    let pil = pipeline.optimized_pil().unwrap();

    let degree = pil.degree();
    assert!(degree > 1);
    let n_bits = (DegreeType::BITS - (degree - 1).leading_zeros()) as usize;
    let n_bits_ext = n_bits + 1;

    let steps = (2..=n_bits_ext)
        .rev()
        .step_by(4)
        .map(|b| Step { nBits: b })
        .collect();

    let params = StarkStruct {
        nBits: n_bits,
        nBitsExt: n_bits_ext,
        nQueries: 2,
        verificationHashType: "GL".to_owned(),
        steps,
    };

    // generate circom
    let opt = pil2circom::StarkOption {
        enable_input: false,
        verkey_input: false,
        skip_main: true,
        agg_stage: false,
    };
    if !setup.starkinfo.qs.is_empty() {
        let pil_json = pil_export::<F>(pil);
        let str_ver = pil2circom::pil2circom(
            &pil_json,
            &setup.const_root,
            &params,
            &mut setup.starkinfo,
            &mut setup.program,
            &opt,
        )
        .unwrap();
        writer.write_fmt(format_args!("{}", str_ver))?;
    }
    Ok(())
}

pub fn zkvm_execute_and_prove(task: &str, suite_json: String, output_path: &str) -> Result<()> {
    log::debug!("Compiling Rust...");
    let force_overwrite = true;
    let with_bootloader = true;
    let (asm_file_path, asm_contents) = compile_rust::<GoldilocksField>(
        &format!("program/{task}"),
        Path::new(output_path),
        force_overwrite,
        &Runtime::base().with_poseidon(),
        with_bootloader,
    )
    .ok_or_else(|| vec!["could not compile rust".to_string()])
    .unwrap();

    let mut pipeline = Pipeline::<GoldilocksField>::default()
        .with_output(output_path.into(), true)
        .from_asm_string(asm_contents.clone(), Some(asm_file_path.clone()))
        .with_prover_inputs(Default::default())
        .add_data(TEST_CHANNEL, &suite_json);

    log::debug!("Computing fixed columns...");
    let start = Instant::now();

    pipeline.compute_fixed_cols().unwrap();

    let duration = start.elapsed();
    log::debug!("Computing fixed columns took: {:?}", duration);

    /*
    log::debug!("Running powdr-riscv executor in fast mode...");
    let start = Instant::now();

    let (trace, _mem) = powdr::riscv_executor::execute::<GoldilocksField>(
        &asm_contents,
        powdr::riscv_executor::MemoryState::new(),
        pipeline.data_callback().unwrap(),
        &default_input(&[]),
        powdr::riscv_executor::ExecMode::Fast,
    );
    let duration = start.elapsed();
    log::debug!("Fast executor took: {:?}", duration);
    log::debug!("Trace length: {}", trace.len);
    */

    log::info!("Running powdr-riscv executor in trace mode for continuations...");
    let start = Instant::now();

    let bootloader_inputs = rust_continuations_dry_run(&mut pipeline);

    let duration = start.elapsed();
    log::info!("Trace executor took: {:?}", duration);

    log::info!("Running witness generation...");
    let start = Instant::now();

    rust_continuations(pipeline, generate_witness_and_prove, bootloader_inputs).unwrap();

    let duration = start.elapsed();
    log::info!("Witness generation took: {:?}", duration);

    Ok(())
}

pub fn zkvm_generate_chunks(
    workspace: &str,
    suite_json: &String,
    output_path: &str,
) -> Result<Vec<(Vec<GoldilocksField>, u64)>> {
    log::info!("Compiling Rust...");
    let force_overwrite = true;
    let with_bootloader = true;
    let (asm_file_path, asm_contents) = compile_rust::<GoldilocksField>(
        workspace,
        Path::new(output_path),
        force_overwrite,
        &Runtime::base().with_poseidon(),
        with_bootloader,
    )
    .ok_or_else(|| vec!["could not compile rust".to_string()])
    .unwrap();

    let mut pipeline = Pipeline::<GoldilocksField>::default()
        .with_output(output_path.into(), true)
        .from_asm_string(asm_contents.clone(), Some(asm_file_path.clone()))
        .with_prover_inputs(Default::default())
        .add_data(TEST_CHANNEL, suite_json);

    log::debug!("Running powdr-riscv executor in fast mode...");


    log::debug!("Running powdr-riscv executor in trace mode for continuations...");
    let start = Instant::now();

    let bootloader_inputs = rust_continuations_dry_run(&mut pipeline);

    let duration = start.elapsed();
    log::debug!(
        "Trace executor took: {:?}, input size: {:?}",
        duration,
        bootloader_inputs.len()
    );

    Ok(bootloader_inputs)
}

pub fn zkvm_prove_only(
    task: &str,
    suite_json: &String,
    bootloader_input: Vec<GoldilocksField>,
    start_of_shutdown_routine: u64,
    i: usize,
    output_path: &str,
) -> Result<()> {
    log::debug!("Compiling Rust...");
    let asm_file_path = Path::new(output_path).join(format!("{}.asm", task));

    let pipeline = Pipeline::<GoldilocksField>::default()
        .with_output(output_path.into(), true)
        .from_asm_file(asm_file_path.clone())
        .with_prover_inputs(Default::default())
        .add_data(TEST_CHANNEL, suite_json);

    log::debug!("Running witness generation and proof computation...");
    let start = Instant::now();

    //TODO: if we clone it, we lost the information gained from this function
    rust_continuation(
        task,
        pipeline.clone(),
        generate_witness_and_prove,
        bootloader_input,
        start_of_shutdown_routine,
        i,
    )
    .unwrap();
 
    let verifier_file = Path::new(output_path).join(format!("{}_chunk_{}.circom", task, i));
    log::debug!(
        "Running circom verifier generation to {:?}...",
        verifier_file
    );
    let f = fs::File::create(verifier_file)?;
    generate_verifier(pipeline, f).unwrap();

    let duration = start.elapsed();
    log::debug!(
        "Witness generation and proof computation took: {:?}",
        duration
    );

    Ok(())
}

pub fn rust_continuation<F: FieldElement, PipelineCallback, E>(
    task: &str,
    mut pipeline: Pipeline<F>,
    pipeline_callback: PipelineCallback,
    bootloader_inputs: Vec<F>,
    start_of_shutdown_routine: u64,
    i: usize,
) -> Result<(), E>
where
    PipelineCallback: Fn(Pipeline<F>) -> Result<(), E>,
{
    // Here the fixed columns most likely will have been computed already,
    // in which case this will be a no-op.

 
    pipeline.compute_fixed_cols().unwrap();

    // we can assume optimized_pil has been computed
   let length = pipeline.compute_optimized_pil().unwrap().degree();

   // std::fs::write("/workspace/debug.log", b"rust_continuation():3333333 \n").unwrap();

    let name = format!("{}_chunk_{}", task, i);
    log::debug!("\nRunning chunk {} in {}...", i + 1, name);

    
    // now we should do
    let parent_path = pipeline.output_dir().unwrap();
    let chunk_dir = parent_path.join(name);
    //remove_dir_all(&chunk_dir).unwrap();
    create_dir_all(&chunk_dir).unwrap();
    let pipeline = pipeline.with_output(chunk_dir, true);

    let jump_to_shutdown_routine = (0..length)
        .map(|i| (i == start_of_shutdown_routine - 1).into())
        .collect();

    let pipeline = pipeline.add_external_witness_values(vec![
        (
            "main_bootloader_inputs.value".to_string(),
            bootloader_inputs,
        ),
        (
            "main.jump_to_shutdown_routine".to_string(),
            jump_to_shutdown_routine,
        ),
    ]);
    
    pipeline_callback(pipeline)?; 
    Ok(())
}




/////////////////////Parameter parse
#[derive(Debug, Parser, Default)]
#[command(about, version, no_binary_name(true))]
//#[derive(Parser, Debug)]
//#[command(author, version = "0.1.6", about, long_about = None)]
struct Cli {
    #[arg( long = "trace_file", default_value = "test-vectors/solidityExample.json")]
    trace_file: String,
    #[arg( long = "bi_file", default_value = "lr_chunks_0.data")]
    bi_file: String,
    #[arg( long = "asm_file", default_value = "lr.asm")]
    asm_file: String,
    #[arg( long = "task_name", default_value = "lr")]
    task_name: String,
    #[arg(long = "chunk_id",default_value_t = 0) ]
    chunk_id: usize,

    #[arg(long = "output_path", default_value = "/workspace")] //must use the default value!!
    output_path: String,

}


use gevulot_shim::{Task, TaskResult};

type GeResult<T> = std::result::Result<T, Box<dyn std::error::Error>>;

fn main()-> GeResult<()>  {
   gevulot_shim::run(run_task)
}

fn run_task(task: Task) -> GeResult<TaskResult> {

    let start = Instant::now();
    env_logger::init();
    
    println!("0xEigenLabs prover : task.args: {:?}", &task.args);

    //let args =  Cli::parse();
    let args =  Cli::parse_from(&task.args);

    log::info!("parameters: trace_file:{};  bootloader input file:{}",args.trace_file, args.bi_file);
    log::info!("parameters: task_name:{};  number_chunk:{}",args.task_name, args.chunk_id);

    let mut log_file = fs::File::create("/workspace/debug.log")?;
    write!(log_file, "trace_file:{}\n",  &args.trace_file)?;
    write!(log_file, "bi_file:{}\n",  &args.bi_file)?;
    write!(log_file, "task_name:{}\n",  &args.task_name)?;
    write!(log_file, "number_chunk:{}\n",  &args.chunk_id)?;
    write!(log_file, "output_path:{}\n",  &args.output_path)?;

  

    //generate proof
    let suite_json = fs::read_to_string(args.trace_file).unwrap();

    //let workspace = format!("program/{}", args.task_name);

    let mut f = fs::File::open(&args.bi_file).unwrap();
    let metadata = fs::metadata(&args.bi_file).unwrap();
    let file_size = metadata.len() as usize;

    assert!(file_size % 8 == 0);
    // read the start_of_shutdown_routine
    let mut buffer = [0u8; 8];
    f.read_exact(&mut buffer).unwrap();
    let start_of_shutdown_routine: u64 = u64::from_le_bytes(buffer);

    let file_size = file_size - 8;
    let mut buffer = vec![0; file_size];
    f.read_exact(&mut buffer).unwrap();
    let mut bi = vec![GoldilocksField::default(); file_size / 8];
    bi.iter_mut().zip(buffer.chunks(8)).for_each(|(out, bin)| {
                *out = GoldilocksField::from_bytes_le(bin);
            });
     write!(log_file, "start_of_shutdown_routine:{}\n",  &start_of_shutdown_routine)?;

    let exec_result = zkvm_prove_only(
                &args.task_name,
                &suite_json,
                bi,
                start_of_shutdown_routine,
                args.chunk_id,
                &args.output_path,
            );


    match exec_result {
        Err(x) => {
            log::info!("The prover has error: {}", x);
            write!(log_file, "The prover has error: {}\n", x)?;
        }
        _ => write!(log_file, "The prover executes successfully.\n")?,
    };
    
    let duration = start.elapsed();
    log::info!("The prover executes successfully, duration{:?}", &duration);
    write!(log_file, "the proving in Gevulot duration {:?}  \n",  &duration)?;
    

    let circom_file = format!("{}/{}_chunk_{}.circom",&args.output_path, &args.task_name, &args.chunk_id);
    let proof_file = format!("{}/{}_chunk_{}/{}_proof.bin",&args.output_path, &args.task_name, &args.chunk_id, &args.task_name);
     

    //return three files for Verifier
     task.result(vec![], vec![String::from(proof_file),String::from(circom_file),String::from("/workspace/debug.log")])
    
}