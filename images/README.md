## Prerequisites

We assume that you are already familiar with shell-test and have installed the necessary software according to the [README](https://github.com/0xEigenLabs/eigen-estark-gevulot/blob/main/README.md ).

## Installation

If you want to debug your proof program more quickly, you'd better install a Gevulot Node locally.

It is  easy to intall the local node , please refer to :https://blog.gevulot.com/p/run-a-local-gevulot-prover-node

The proof program's debug messages in the local Gevulot node:

```
 gevulot/data/node/log/0be42427bfe6d9539e06c0ec474f516108053c32e2c03c3968ba0cbcd3dd9c6d$ 
stderr.log  stdout.log
```

## Prover/Verifier Packaging and Deployment
     
1. pull the project
```   
$ git clone https://github.com/0xEigenLabs/eigen-estark-gevulot.git
```  
Please refer to the  programs : images/src/prover.rs and verifier.rs  .

2. Compile the project
```
$ cargo build --release
```
If it is ok, you will see the binary files (gevulot-prover and gevulot-verifier ) in the direcotry target/release
      
3. Create a packaging directory , such as  ~/packaging.  

Then copy all the following files   to ~/packaging .
```
$ cp -a  images/scripts/*  ~/packaging/  
```
  
4. Please  edit the file ~/packaging/my-local-key.pki  according your  Gevulot Key.

 $cp my-local-key.pki localkey.pki

5. copy the compiled gevulot-prover/gevulot-verifier to  ~/packaging .

6. Check the configure

```
$ cat my_prover.json
{
  "ManifestPassthrough": {
    "readonly_rootfs": "true"
  },
  "Env":{
    "POWDR_STD":"powdr",        //The powdr need it
    "RUST_BACKTRACE": "1",
    "RUST_LOG": "debug"
  },
  "Program":"gevulot-prover",
  "Mounts": {
    "%1": "/workspace"
  },
////The powdr need the following
 "Files": ["powdr/math/ff.asm","powdr/math/fp2.asm","powdr/math/mod.asm","powdr/protocols/mod.asm","powdr/protocols/permutation.asm","powdr/machines/arith.asm","powdr/machines/binary.asm","powdr/machines/memory.asm","powdr/machines/mod.asm","powdr/machines/shift.asm","powdr/machines/write_once_memory.asm","powdr/machines/hash/mod.asm","powdr/machines/hash/poseidon_bn254.asm","powdr/machines/hash/poseidon_gl.asm","powdr/machines/split/mod.asm","powdr/machines/split/split_bn254.asm","powdr/machines/split/split_gl.asm","powdr/mod.asm","powdr/array.asm","powdr/btree.asm","powdr/check.asm","powdr/convert.asm","powdr/debug.asm","powdr/field.asm","powdr/prelude.asm","powdr/prover.asm","powdr/utils.asm"]

}
```

```
Ensure that the packaging directory contains the following files.
$ ls powdr/
array.asm  check.asm    debug.asm  machines  mod.asm      protocols   utils.asm
btree.asm  convert.asm  field.asm  math      prelude.asm  prover.asm
```

```
$ cat deploy.sh
gevulot-cli --jsonurl "http://api.devnet.gevulot.com:9944" --keyfile my-local-key.pki \
        deploy \
        --name " prover & verifier" \
        --prover $1 \
        --provername '#eigen-gevulot-prover' \
        --proverimgurl 'http://4.145.88.10:8080/gevulot-prover' \
        --provercpus 32 \
        --provermem 262144 \                        //256G memory !!!
        --provergpus 0 \
        --verifier $2 \
        --verifiername '#eigen-gevulot-verifier' \
        --verifierimgurl 'http://4.145.88.10:8080/gevulot-verifier' \
        --verifiercpus 4  \
        --verifiermem 4096  \
        --verifiergpus 0
```
> [!IMPORTANT]
>  1.If you utilize Amazon, Google, Microsoft, or any other third-party cloud service, you should replace the above  "http://4.145.88.10:8080/" .  
>  2. The above "--provermem 262144" means prover need 256G memory . If the memory is not enough , the prover will  exit abnormally.  
>  3. The above "--provercpus 32" means prover need 32 CPU kernels .

7. Run the  pack.sh to package the programs and deploy the images
   
   If the pack.sh executes successfully, it will output the following messages:
```
$ ./pack.sh
release version:
Bootable image file:/home/devadmin/.ops/images/gevulot-prover
Bootable image file:/home/devadmin/.ops/images/gevulot-verifier
prover hash:The hash of the file is: 848da95e2300cd710f4796939f08d03e8417940a720ed9236fdd7070465d6032
verifier hash: The hash of the file is: 07b7cfcb90fab80aabbd6fc4ac524243ce6ba40f2ea71365c0f64194a967f42b

deploy the new image to gevulot platform...)
Start prover / verifier deployment
Prover / Verifier deployed correctly.
Prover hash:1e4689f8be48d96403f85e676aac597eed9a209586cded364d5d95e8bf7322b0        //Please retain this Prover hash; it will be used in subsequent calls.
Verifier hash:8ed2ce60093677ee957054dc0afcebfd1c31203f77a602aaf3fcce94e2419244.     //Please retain this Verifier hash; it will be used in subsequent calls.
Tx Hash:f125d319a0a66fbd4a05e82e5ccf60c9827216ac499074fd2d6820a9a5d79cc6
```

## Calling the remote proof service

1. The API

```
   use images::file::run_prove;

pub async fn run_prove(
    json_rpc_url: &String,          // RPC server: http://api.devnet.gevulot.com:9944
    keyfile: &PathBuf,              // The file has your  Gevulot key : localkey.pki
    prove_program_hsh: &String,     // The prover hash :after executing the pack.sh, it will output the "Prover hash:xxx"
    verify_program_hsh: &String,    // The Verifier hash :after executing the pack.sh, it will output the "Verifier hash:xxx"
    trace_file: &String,            // The input file : eg. solidityExample.json
    bi_file: &String,               // The input file : eg. lr_chunks_0.data
    asm_file: &String,              // The input file : eg. lr.asm
    task_name: &String,             // The proof's task: eg. lr or evm
    chunk_id : &String,             // The chunck NO.
    http_server_work_path:&String,  // The http file server's work path, such as /data/http.
                                    // Before calling run_prove(), the proof client must save the files(trace_file,asm_file,asm_file) to http_server_work_path.
                                    
    local_http_url: &String,        //Local http file sever's url,such as:  http://4.145.88.10:8080
    proof_file_out_path:  &String,  // The proof client wishes to store the proof result files in which local directory. 
    rpc_timeout: Option<u64>        // Rpc timeout: second
) -> BoxResult<()> {
//...}
```

2. Test the prover/verifier

   The test program is tests/e2e-test/src/main.rs
   
   Update the hash in the  e2e-test.sh with the above Prover hash and verifier hash(After executing pack.sh, it will output the hash).
   
   Copy images/test-vectors/* to the http server's work path, such as /data/http/ .  
   Execute the e2e-test.sh.
   
```
 $ ./e2e-test.sh
[2024-07-09T08:37:14Z INFO  eigen_gevulot_e2e_tests] ZKVM-Gevulot e2e-test ...
[2024-07-09T08:37:14Z INFO  eigen_gevulot_e2e_tests] before proving :
[2024-07-09T08:37:16Z INFO  images::file] waiting the proving task to finish
Root: 93f50d21ccb235a6a829885662a6bd2569a3d7d0c0794fa4e26502a61d00cb9b
        Node: 22cdefd8e8ddce1c128da0122be4ef659f3efe193741e7e859f7651fce8262d7
                Leaf: 3bacefc177c5e8ae7e2c277d101f6bdb7dc14c88fcce4b985d6fba173342abac
        Node: 5c9ab64936147d8a5c42dfffce7dd6f1f257e178858b16cc193be6f8dc0d17e2
                Leaf: eff74fdea27d34f83a4b837f0c2a6bba9dcfadccbafe44139f0a5bbdf847769d
        Node: 362d3656a5df7b103871393c40bd81d73ec58859abfdefb216b939bdd1a3dabb
                Leaf: 8df0ad0f5dbad67fc3fa3a8733397583b018d627b8465de9536b38d6751cf383
        Node: a9f409bae0af1aada556d754154462994408bcf6a86a0a55492b23f6e7d25ed7
                Leaf: 8b627358f4135db618f92a6315f42a6d4ace4dbc68b4381d627eb1cc5bf8d7fb
[2024-07-09T08:41:37Z INFO  images::file] get_leaf:
[2024-07-09T08:41:37Z INFO  images::file] The hash of the first leaf is: 3bacefc177c5e8ae7e2c277d101f6bdb7dc14c88fcce4b985d6fba173342abac
[2024-07-09T08:41:37Z INFO  images::file] Leaf content:
[2024-07-09T08:41:37Z INFO  images::file] File URL: http://34.88.251.176:9995/txfiles/3bacefc177c5e8ae7e2c277d101f6bdb7dc14c88fcce4b985d6fba173342abac/02ba660c7cfe62b0c29fcd7ee0849b69760b751d1035c31d3779fe0893a1eb38/lr_chunk_0.circom
[2024-07-09T08:41:37Z INFO  images::file] VM Path: /workspace/lr_chunk_0.circom
[2024-07-09T08:41:39Z INFO  images::file] File URL: http://34.88.251.176:9995/txfiles/3bacefc177c5e8ae7e2c277d101f6bdb7dc14c88fcce4b985d6fba173342abac/044a7d7736a8e5dbcac6a755400f08142a13449fffbf70e6861e3eb42a43c115/lr_proof.bin
[2024-07-09T08:41:39Z INFO  images::file] VM Path: /workspace/lr_chunk_0/lr_proof.bin
[2024-07-09T08:41:40Z INFO  images::file] File URL: http://34.88.251.176:9995/txfiles/3bacefc177c5e8ae7e2c277d101f6bdb7dc14c88fcce4b985d6fba173342abac/8d54df4e2edaf2c9bb65ca57eecd08e1173cf0699031688f6b8427de5ab76025/debug.log
[2024-07-09T08:41:40Z INFO  images::file] VM Path: /workspace/debug.log
[2024-07-09T08:41:40Z INFO  eigen_gevulot_e2e_tests] Finish Gevulot proving, duration: 266.35861716s
```
   





   

   
    
