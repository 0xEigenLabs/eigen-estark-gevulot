
//use crate::server;
use gevulot_node::{
    rpc_client::{RpcClient,RpcClientBuilder,},
    types::{
        transaction::{Payload, ProgramData, Workflow, WorkflowStep},
        Transaction,TransactionTree,
    },
};



use gevulot_node::types::transaction::Created;

use gevulot_node::types::Hash;
use gevulot_cli::{calculate_hash_command,keyfile};

use std::{
    rc::Rc,
    path::PathBuf,
    fs::File,
    io:: Write,
    time::Duration,
};

use tokio::time::sleep;

use std::path::Path;
use std::ffi::OsStr;

use serde::{Deserialize, Serialize};


#[derive(Serialize, Deserialize, Debug)]
pub struct Verification {
    pub parent: String,
    pub verifier: String,
    pub verification: String,
    pub files: Vec<FileJsn>,
}

#[derive(Serialize, Deserialize, Debug)]
pub  struct FileJsn {
    pub url: String,
    pub checksum: String,
    pub vm_path: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub  struct PayloadJsn {
    pub Verification: Verification,
}

#[derive(Serialize, Deserialize, Debug)]
pub  struct Root {
    pub author: String,
    pub hash: String,
    pub payload: PayloadJsn,
    pub nonce: u64,
    pub signature: String,
}

//type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
type BoxResult<T> = std::result::Result<T, Box<dyn std::error::Error>>;

pub async fn run_prover(
    json_rpc_url: &String,
    keyfile: &PathBuf,
    prove_program_hsh: &String,
    verify_program_hsh: &String,
    trace_file: &String,
    bi_file: &String,
    asm_file: &String,
    task_name: &String,
    chunk_id : &String,
    http_server_work_path:&String,
    local_http_url: &String,
    proof_file_out_path:  &String,
    rpc_timeout: Option<u64>
) -> BoxResult<()> {
    

    let mut client_builder = RpcClientBuilder::default();
    if let Some(rpc_tm_out) = rpc_timeout {
        client_builder = client_builder.request_timeout(Duration::from_secs(rpc_tm_out));
    }
    let client = client_builder
        .build(json_rpc_url.to_owned())
        .expect("build rpc client");

    let tx_hash = call_rpc_prover(&client, &keyfile, &prove_program_hsh, &verify_program_hsh , &trace_file, &bi_file,
        &asm_file,
        &task_name,
        &chunk_id,
        &http_server_work_path,
        &local_http_url).await?; 

    ///////////
    let wait_time :u64;
    if  *task_name == "lr".to_string(){
        wait_time =300 ;//second
    }else{
        wait_time =1100 ;
    }
    let leaf_hash = get_leaf_hash(&client, &tx_hash, wait_time).await.expect("Option<Hash> does not have a value");

    let json_content = get_leaf_cnt(&client,leaf_hash).await?;
    
    log::info!("Leaf content: ");
    let parsed: Root = serde_json::from_str(&json_content)?;
   
    //Download the result files from Gevulot server
    for file in parsed.payload.Verification.files {
        log::info!("File URL: {}", file.url);
        log::info!("VM Path: {}", file.vm_path);
        
        //let path_str = "/work/test.log";
        let path = Path::new(&file.vm_path);
    
        let file_name_os_str = path.file_name().expect("Path should have a file name");
    
        let file_name = OsStr::to_string_lossy(file_name_os_str).to_string();
        let  file_path = format!("{}{}",&proof_file_out_path, file_name);

       let _ = download_file(&file.url, &file_path).await.expect("Failed to download file");
    }
    //////////

    Ok(())
}

pub async fn call_rpc_prover(client: &RpcClient,
    keyfile: &PathBuf,
    prove_program_hsh: &String,
    verify_program_hsh: &String,
    trace_file: &String,
    bi_file: &String,
    asm_file: &String,
    task_name: &String,
    chunk_id : &String,
    http_server_work_path:&String,
    local_http_url: &String)-> BoxResult<(Hash)>{

    let key = keyfile::read_key_file(&keyfile).map_err(|err| {
            format!(
                "Error during key file:{} reading:{err}",
                keyfile.to_str().unwrap_or("")
            )
        })?;

    //the http_server_work_path is set during the installation of the http file server.
    let  trace_file_hsh = file_hash(&trace_file, &http_server_work_path).await?;
    let  bi_file_hsh = file_hash(&bi_file, &http_server_work_path).await?;
    let  asm_file_hsh = file_hash(&asm_file, &http_server_work_path).await?;

   
    let trace_file_url = format!("{}/{}", local_http_url, trace_file);
    let bi_file_url = format!("{}/{}", local_http_url, bi_file);
    let ams_file_url = format!("{}/{}", local_http_url, asm_file);


    let mut steps = vec![];
    let prove_prg :Hash = (&(hex::decode(prove_program_hsh).map_err(|err| format!("program decoding hash error:{err}"))?)[..]).into();
    let verify_prg :Hash  = (&(hex::decode(verify_program_hsh).map_err(|err| format!("program decoding hash error:{err}"))?)[..]).into();
  
    let step_prove = WorkflowStep {
                             program: prove_prg.to_owned(),
                                    
                             args: vec![
                                "--trace_file".to_string(),
                                "/workspace/".to_string() + trace_file,
                                "--bi_file".to_string(),
                                "/workspace/".to_string() + bi_file,
                                "--asm_file".to_string(),
                                "/workspace/".to_string() + asm_file,
                                "--task_name".to_string(),
                                task_name.to_owned(),
                                "--chunk_id".to_string(),
                                chunk_id.to_owned(),
                                ],
                            inputs:vec![
                                ProgramData::Input{
                                    checksum: trace_file_hsh,
                                    file_name: "/workspace/".to_string() + trace_file,
                                    file_url: trace_file_url.to_owned(),
                                },
                
                                ProgramData::Input{
                                    checksum: bi_file_hsh,
                                    file_name: "/workspace/".to_string() + bi_file,
                                    file_url: bi_file_url.to_owned(),
                                },
                            
                                ProgramData::Input{
                                    checksum: asm_file_hsh,
                                    file_name: "/workspace/".to_string() + asm_file,
                                    file_url: ams_file_url.to_owned(),
                                },
                            ],
                    };


    let circom_file = format!("/workspace/{}_chunk_{}.circom", &task_name, &chunk_id);
    let proof_file = format!("/workspace/{}_chunk_{}/{}_proof.bin", &task_name, &chunk_id, &task_name);

    let step_verify = WorkflowStep {
                    program: verify_prg,

                    args: vec![
                    "--circom_file".to_string(),
                    circom_file.to_owned(),
                    "--proof_file".to_string(),
                    proof_file.to_owned(),   
                    ],
                    
                    inputs:vec![
                        ProgramData::Output {
                            source_program: prove_prg.to_owned(),
                            file_name: circom_file.to_owned(),
                        },
                        ProgramData::Output {
                            source_program:  prove_prg.to_owned(),
                            file_name: proof_file.to_owned(),   
                        },     
                        //test.log
                        ProgramData::Output {
                            source_program:  prove_prg.to_owned(),
                            file_name: "/workspace/debug.log".to_string(),   
                        }, 
                    ],
            };

    steps.push(step_prove);
    steps.push(step_verify);

    let tx = Transaction::new(
        Payload::Run {
            workflow: Workflow { steps },
        },
        &key,
    );

    let tx_hash = send_transaction(&client, &tx).await?;
    
    Ok(tx_hash)
}

// Asynchronous function to download a file from a URL and save it to a specified directory.
//pub async fn download_file(url: &str, path: &str) -> Result<()> {
pub async fn download_file(url: &str, path: &str) -> BoxResult<()> {
    // Send a GET request to the specified URL.
    let mut response = reqwest::get(url).await?;

    // Ensure the request was successful.
    //response.error_for_status()?.error_for_status()?; // Call twice to ensure a 200 OK status.

    response = response.error_for_status()?;
    // Write the content of the response body to a file.
    let mut dest = File::create( path)?;
    let content = response.bytes().await?;
    dest.write_all(&content)?;
    dest.flush()?; // Ensure all data is written to the file.

    Ok(())
}


pub async fn send_transaction(client: &RpcClient, tx: &Transaction<Created>) -> std::result::Result<Hash, String> {
    client
        .send_transaction(tx)
        .await
        .map_err(|err| format!("Error during send  transaction to the node:{err}"))?;

    let read_tx = client
        .get_transaction(&tx.hash)
        .await
        .map_err(|err| format!("Error during send  get_transaction from the node:{err}"))?;

    if tx.hash.to_string() != read_tx.hash {
        return Err(format!(
            "Error get_transaction doesn't return the right tx send tx:{} read tx:{:?}",
            tx.hash, read_tx
        ));
    }

    Ok(tx.hash)
}


pub async fn get_leaf_hash(client: &RpcClient, hash: &Hash, waiting_time: u64)->Option<Hash>{
    //wait a few minutes for the proving task to finish
    log::info!("waiting the proving task to finish");
    sleep(Duration::from_secs(250)).await;
    let mut counter = 0;
    //let hash = Hash::from(tx_hash);

    loop{
        match client.get_tx_tree(&hash).await {
                Ok(tx_tree) =>{
                    print_tx_tree(&tx_tree, 0);
                    log::info!("get_leaf:");
                    let tree_root = Rc::new(tx_tree);
                    let first_leaf = find_first_leaf(&tree_root);
                    match first_leaf {
                        Some(leaf) => {
                            match leaf.as_ref() {
                                TransactionTree::Leaf { hash, .. } => {
                                    log::info!("The hash of the first leaf is: {}", hash);
                                    
                                    return Some(*hash);
                                },
                                // do nothing
                                _ => {}
                            }
                        },
                        None => {
                            log::info!("==== No leaf node found. =======");
                            //break;
                            return None;
                        }
                    }

                } ,
                Err(err) =>{
                    //println!("An error while fetching transaction tree: {err}");
                    log::info!("The task is executing or there is an error:{}",err);

                },
        };

        counter +=1;
        if counter >15 {//Maybe different proving task costs different time !!
            //break;
            return None;
        }
         
        log::info!("Try {} times, but not get tx tree, waiting... ",counter);
        sleep(Duration::from_secs(20)).await;
                 
    }
    
}



pub async fn file_hash(file:&String, http_server_work_path:&String)->BoxResult<String> {

    let filename = format!("{}/{}",http_server_work_path, file);
    let hsh_str= calculate_hash_command(&PathBuf::from(filename)).await.expect("get file hash");

    Ok(hsh_str)
}

pub async fn  get_tx_tree(client: &RpcClient, tx_hash: String)-> BoxResult<TransactionTree>{

    let hash = Hash::from(tx_hash);
    let tx_tree =  client.get_tx_tree(&hash).await?;

    Ok(tx_tree)
}

fn print_tx_tree(tree: &TransactionTree, indentation: u16) {
    match tree {
        TransactionTree::Root { children, hash } => {
            println!("Root: {hash}");
            children
                .iter()
                .for_each(|x| print_tx_tree(x, indentation + 1));
        }
        TransactionTree::Node { children, hash } => {
            println!(
                "{}Node: {hash}",
                (0..indentation).map(|_| "\t").collect::<String>()
            );
            children
                .iter()
                .for_each(|x| print_tx_tree(x, indentation + 1));
        }
        TransactionTree::Leaf { hash } => {
            println!(
                "{}Leaf: {hash}",
                (0..indentation).map(|_| "\t").collect::<String>()
            );
        }
    }
}


pub  fn find_first_leaf(tree: &Rc<TransactionTree>) -> Option<&Rc<TransactionTree>> {
        match &**tree {
            TransactionTree::Leaf { .. } => Some(tree),
            TransactionTree::Root { children, .. } | TransactionTree::Node { children, .. } => {
                for child in children {
                    if let Some(leaf) = find_first_leaf(child) {
                        return Some(leaf);
                    }
                }
                None
            }
        }
    }


pub async fn get_leaf_cnt(client: &RpcClient, hash: Hash)-> BoxResult<String>{
    let output_json = client
    .get_transaction(&hash)
    .await
    .and_then(|tx_output| serde_json::to_string(&tx_output).map_err(|err| err.into()))?;

    Ok(output_json)
}


