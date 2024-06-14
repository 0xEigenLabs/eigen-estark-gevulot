 ## Gevulot Overview(not including the blockchain)

1. System diagram
      ![image](https://github.com/gavin-ygy/estark-gevulot/assets/762545/6edb5c87-1c95-496c-b505-1fc979493b30)

> [!NOTE]
> For more information about Gevulot see: https://docs.gevulot.com/gevulot-docs .  
> For more information about OPS see: https://docs.ops.city/ops  

2. Key Points

```
   1) The user's prover or verifier programs must be packaged into OPS-formatted NonaVMs file.
      Then, the NonaVMs can be  transmitted to the Gevulot server through    
       the Gevulot client, and the server schedules them to run on OPS.

   2) The Gevulot server mandates the sequential execution of the prover and verifier,  
      regardless of whether the verifier performs any specific function or not.  
      
   3) When  querying a transaction through the Gevulot client, the server will only return relevant task
      information to the client if it has successfully obtained the task.result from the verifier.       
     Otherwise,  an error will be returned,such as "An error while fetching transaction tree:  
     RPC response error:not found: no root tx found for xxxxxx...".
```

## Local system requirements

1. A Linux-based machine (e.g., Ubuntu Server 22.04 LTS).
   
2. At least 16GB RAM with a 4-core CPU.

3. Public IP address. (If you build your own http file server, you need to have a public IP.)  

4. Install the Rust(v1.79),  Cargo, Go(v1.22)  

## Installation

1. Install the Gevulot CLI

    $ cargo install --git https://github.com/gevulotnetwork/gevulot.git gevulot-cli

    If the installation is ok, tt is similar to the following, otherwise ,please check the enviroment $PATH.

```sh
     $ gevulot-cli -V  
      gevulot-cli 0.1.0
```

2. Register Gevulot Key

   $ gevulot-cli generate-key

   A local file localkey.pki is created in the current directory and the public key is printed for copying.

> [!IMPORTANT]  
> You should send the above public key to Gevulot through https://airtable.com/appS1ebiXFs8H4OP5/pagVuySwNkMe95tIi/form .
     
> [!TIP]   
> If you haven't received a reply email after one day, you can try the following deployment step using your key. If the attempt fails, please contact them on Telegram : https://t.me/gevulot.  

3. Install the OPS （Ubuntu）

```sh 
    $ curl https://ops.city/get.sh -sSfL | sh
  
    $ sudo apt-get install qemu-kvm qemu-utils
```
     
    Check the OPS :
    
```
       $ cat hi.js
	var http = require('http');  
	http.createServer(function (req, res) {  
	            res.writeHead(200, {'Content-Type': 'text/plain'});  
	            res.end('Hello World\n');  
	}).listen(8083, "0.0.0.0");  
	console.log('Server running at http://127.0.0.1:8083/');  
```

        If the installation is ok, it is similar to the following:
    
```
	$ ops pkg load eyberg/node:20.5.0 -p 8099 -f -n -a hi.js  
	running local instance  
	booting /home/devadmin/.ops/images/node ...  
	en1: assigned 10.0.2.15  
	Server running at http://127.0.0.1:8083/  
	en1: assigned FE80::8B9:50FF:FE43:E7A0  
```
     
> [!WARNING] 
> The above installation is for  Ubuntu, other system please refer to https://docs.ops.city/ops/getting_started.  

4. Install the http  file server

> [!WARNING]   
> If you utilize Amazon, Google, Microsoft, or any other third-party cloud service ,you can skip this step 4.

   $ git clone https://github.com/codeskyblue/gohttpserver.git

   Compile docker image:  
       
```
    $ cd gohttpserver
    $ docker build --no-cache=true -t gohttpserver:v1.1 -f ./docker/Dockerfile .
```
 
    run the http server:
       
```
    $ mkdir /data/http    (the http server's working path)
    $ docker run -it --rm -d -p 8080:8000 -v /data/http:/app/public --name gohttpserver gohttpserver:v1.1
```

 > [!NOTE]
 > if the http file server is ok,   the browser can visit it through the public IP and port 8080. (The port 8080 should be mapped to the machine in the router)

## Prover/Verifier Integration
     Please refer to the test programs : tests/shell-test/src/prover.rs and verifier.rs  .
     Before compiling the test prover/verifier, please download the submodule .
     
     $  git submodule update --init --recursive
	Submodule 'eigen-zkvm' (https://github.com/0xEigenLabs/eigen-zkvm) registered for path 'eigen-zkvm'
	Submodule 'gevulot' (https://github.com/gevulotnetwork/gevulot.git) registered for path 'gevulot'
	Cloning into '/data/gavin/test/estark-gevulot/eigen-zkvm'...
	Cloning into '/data/gavin/test/estark-gevulot/gevulot'...
	Submodule path 'eigen-zkvm': checked out '69de4af8688e8e220f4d403a48ae804b9a755259'
	Submodule path 'gevulot': checked out '82bff1109b96700470f0f7fb192e5ca0ad389251'

     Then , compile the program.

     $ cargo build
     
> [!IMPORTANT]
> 1. The gevulot-cli can't get the dubug messages of the prover/verifier unless you seek assistance from their engineers.  
> 2. To familiarize yourself with the debugging of the Gevulot  framework, it is recommended to comment out the Prove function inside the Prover. This way, after remotely running the prover/verifier, you will be able to immediately obtain the  prover's  log file  that can help you debug the program.


## Prover/Verifier Packaging and Deployment

1. You should create a packaging directory  such as  ~/packaging.  
   Then copy all the following files   to ~/packaging .

```sh
   $ cp -a  tests/shell-test/scripts/*  ~/packaging/  
```
  
2. Please  edit the file ~/packaging/my-local-key.pki  according the above installation  "2. Register Gevulot Key".

3. my_prover.json and my_verifier.json are for ops building images ,eg.

$ cat my_prover.json

```json
	{
	  "ManifestPassthrough": {
	    "readonly_rootfs": "true"
	  },
	  "Env":{
	    "RUST_BACKTRACE": "1",
	    "RUST_LOG": "debug"
	  },
	  "Program":"prover",            //the binary file name of your prover which must be consistent with the prover name in pack.sh and deploy.sh
	  "Mounts": {
	    "%1": "/workspace"
	  },
	 "Files": ["gevulot/starkStruct.json"]      /*the prover's configure file , you should modify it according your prover !!
	                                            the file starkStruct.json will be packaged into OPS'S NanoVM image. */
	}
```

4. copy the compiled prover/verifier to  ~/packaging .
   
5. Package the prover/verifier
   
$ cat pack.sh

```sh
ops build ./prover  -c my_prover.json      ###build prover NanoVM image. If the prover need configure file,eg.starkStruct.json ,
                                           ## you mkdir gevulot and cp starkStruct.json  gevulot/  .
ops build ./verifier  -c my_verifier.json

cp   ~/.ops/images/prover  /data/http/       ## copy the packaged prover/verifier to HTTP  server's working path !! 
cp   ~/.ops/images/verifier  /data/http/


PHSH=$(gevulot-cli calculate-hash --file ~/.ops/images/prover)
echo "prover hash:$PHSH"

p_array=(${PHSH//:/ })
p_hsh=${p_array[6]}

VHSH=$(gevulot-cli calculate-hash --file  ~/.ops/images/verifier)
echo "verifier hash: $VHSH "

v_array=(${VHSH//:/ })
v_hsh=${v_array[6]}

echo "deploy the new image to gevulot:(NOTICE: Verifier should use its HASH!)"
./deploy.sh $p_hsh $v_hsh         ## If you want to package the program separately, please comment out this line.
```

6. Deploy the prover/verifier
   
$ cat deploy.sh

```sh
gevulot-cli --jsonurl "http://api.devnet.gevulot.com:9944" --keyfile my-local-key.pki \
        deploy \
        --name " prover & verifier" \
        --prover $1 \
        --provername '#eigen-gevulot-prover' \
        --proverimgurl 'http://4.145.88.10:8080/prover' \      
        --provercpus 32 \
        --provermem 65536 \
        --provergpus 0 \
        --verifier $2 \
        --verifiername '#eigen-gevulot-verifier' \
        --verifierimgurl 'http://4.145.88.10:8080/verifier' \
        --verifiercpus 4  \
        --verifiermem 4096  \
        --verifiergpus 0
```

> [!IMPORTANT]
>  1.If you utilize Amazon, Google, Microsoft, or any other third-party cloud service, you should replace the above  "http://4.145.88.10:8080/" .
>  2. The above "--provermem 65536" means prover need 64G memory . If the memory is not enough , the prover will  exit abnormally.
>  3. The above "--provercpus 32" means prover need 32 CPU kernels .

7. The pack.sh will automatically call deploy.sh, so simply running pack.sh will complete  packaging and deployment.
   
   If the pack.sh executes successfully, you will see logs similar to the following:

```
$ ./pack.sh
Bootable image file:/home/devadmin/.ops/images/prover
Bootable image file:/home/devadmin/.ops/images/verifier
prover hash:The hash of the file is: 4be70f6588e9aca72249b42a4cc61568b75b2b8c4261e81e4f0de3e5d0f4910a
verifier hash: The hash of the file is: 8c3b96021d975fdb77683a2784e16bf26519ea641b98fba1102e8c3e57d6f46a
deploy the new image to guvulot platform...)
Start prover / verifier deployment
Prover / Verifier deployed correctly.
Prover hash:e78145a32b208a22b34e03cc6a6146d35683801cc97309ab86ae3ec1f0f26d70  //Remember this hash(PHSH), as it will be needed for subsequent calls to the prover.
Verifier hash:3032e67af5a5d4bc058515956911570417d0481183a7c753b907b11a8f97a45f.  //Remember this hash(VHSH), as it will be needed for subsequent calls to the verifier.
Tx Hash:57991f11873da0d0a3a2fa578402476100a640618c4d5171fa5381292f9f8b3e
```

> [!IMPORTANT]
> After deploying the prover/verifier successfully, it will return the prover hash and verifier hash which you must remember them, as remote calling prover/verifier need the hash. it means the hash is the identity identifier of the prover/verifier on OPS.
         
     
## Prover/Verifier running
1. Copy the prover's input files to HTTP server's working path (eg. /data/http/)
   
   $cp tests/shell-test/input-files/*  /data/http/

3. Enter the packaging directory, such as :

   $cd ~/packaging  
   then  
   $copy   my-local-key.pki localkey.pki

4. Generate the run_task.sh with the run_task.tmpl (replace the PHSH/VHSH with the hash which the deployment returned above)

   $ ./generate_task.sh  e78145a32b208a22b34e03cc6a6146d35683801cc97309ab86ae3ec1f0f26d70 3032e67af5a5d4bc058515956911570417d0481183a7c753b907b11a8f97a45f

> [!IMPORTANT]
> generate_task.sh's first parameter is the prover's hash(PHSH) and the second is the verifier's hash(VHSH) !!

4. Run the prover/verifier

   $ ./run_task.sh  
    Programs send to execution correctly. Tx hash:45a08da9ec877ac4b5e205b56c53e16ebad0b190a11305c7f51d1d3233e1b164

   The prover/verifier is expected to finish running in approximately 15 minutes .

5. Query the result
   
   Note: the parameter is the tx hash which the run_task.sh returned .

```
   $ ./check-tree.sh 45a08da9ec877ac4b5e205b56c53e16ebad0b190a11305c7f51d1d3233e1b164
Root: 45a08da9ec877ac4b5e205b56c53e16ebad0b190a11305c7f51d1d3233e1b164
        Node: 05a72f8191cd45aa18dd5135789b08055a213373ca0150c8f8344cd06752bccb
                Leaf: 60a97be5e461ac2a39600e443bcae4d4f49f65fabb39736340a4929fc03a7823
                Leaf: b882b8706b8e0f0f5b26eb7b1a74ff33ca295f74c3ab44051e0e279fa1976b24
                Leaf: f107cea8c0f2b6f14cb629f7683850fdc6dfc3c71538bc0cf872ffad4547801c
        Node: 7c52e92edb1f6daafc2f4d7af5786d9c7d5e2b91ed67a04a74bcb9d3ddd3e9ab
                Leaf: 8ba892c149beebc6ab18ab3c4191634c090994b333052daac23bd310cab9a90d
                Leaf: 6b3682c631acafc8afb3da43e016e96c4634bf569036c8c38da8e076e472dd10
        Node: 48e9210eb694a494ee220e63f8c2e8791a582c41f69492fd50dbe46f86c1e7d4
                Leaf: 988a24d9e2e381af6bf4fd3241c014c34659f1d98c9de11f6fe78fcb7d06274e
                Leaf: eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650
```

6.Get the return files from the prover/verifier  
Note: the parameter is the above  "Leaf: eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650 " .  

```
$ ./check-leaf.sh eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650
{"author":"041a0b9bdd6a7a94df9a0d5d0c76c7d990e50e38f1b0ab33bbc97a057776b31302391998c692c2afd13ea683cbff2827ce72a2e7d0f91147654e21f0df3d8b34c2","hash":"eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650","payload":{"Verification":{"parent":"48e9210eb694a494ee220e63f8c2e8791a582c41f69492fd50dbe46f86c1e7d4","verifier":"3032e67af5a5d4bc058515956911570417d0481183a7c753b907b11a8f97a45f","verification":"AQIDBAUGBwgJ","files":[{"url":"http://34.88.251.176:9995/txfiles/eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650/3e4f229610b59c84b68d77b1763bb65a1a635dc0fc7ede0567a35b65266872e7/proof.json","checksum":"3e4f229610b59c84b68d77b1763bb65a1a635dc0fc7ede0567a35b65266872e7","vm_path":"/workspace/proof.json"},{"url":"http://34.88.251.176:9995/txfiles/eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650/5a129ba2b5265f7136b7403764228a3c17ffd897785682d5d2eb991f6f76200d/stark_verfier.circom","checksum":"5a129ba2b5265f7136b7403764228a3c17ffd897785682d5d2eb991f6f76200d","vm_path":"/workspace/stark_verfier.circom"},{"url":"http://34.88.251.176:9995/txfiles/eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650/2be56804021c50ae21f4bb345cf3b1d7af3c81c5d12e428b1518eeb5866c8351/test.log","checksum":"2be56804021c50ae21f4bb345cf3b1d7af3c81c5d12e428b1518eeb5866c8351","vm_path":"/workspace/test.log"}]}},"nonce":0,"signature":"48bed1f0aff31bcbb48fa4d71e410be5b86ce56f9e241324cdfc9b4dcf6c18881478fe6e4c5e69db83c4cb04232c3ba21268225b7fba3510d79b356cc91f8667"}
```
There are three files in above result: 

http://34.88.251.176:9995/txfiles/eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650/3e4f229610b59c84b68d77b1763bb65a1a635dc0fc7ede0567a35b65266872e7/proof.json

http://34.88.251.176:9995/txfiles/eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650/5a129ba2b5265f7136b7403764228a3c17ffd897785682d5d2eb991f6f76200d/stark_verfier.circom

http://34.88.251.176:9995/txfiles/eb446a87bafe1da6a61299debd317eccf4f015240180bc032c84fae005367650/2be56804021c50ae21f4bb345cf3b1d7af3c81c5d12e428b1518eeb5866c8351/test.log

You can download them through the browser or wget .

7. The Gevulot's task template

![image](https://github.com/gavin-ygy/estark-gevulot/assets/762545/e4252181-f325-4187-b1d3-39e8907b3395)

> [!NOTE]
> The template includes two parts: prover and verifier.  
> /workspace  is mount path  
> /gevulot  is  config file path in the image (see my_prover.json,  )
> Get the input file's hash : gevulot-cli calculate-hash --file jsn_fibonacci.recursive2.pil.json
> The prover's output file name must be consistent with the file name returned in the prover.rs and verifier.rs .




   
    
