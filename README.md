 ## Gevulot Overview(not including the blockchain)
   1. System diagram
      ![image](https://github.com/gavin-ygy/estark-gevulot/assets/762545/6edb5c87-1c95-496c-b505-1fc979493b30)


   2. Key Points    
      2.1 The user's prover or verifier programs must be packaged into OPS-formatted NonaVMs. Then, the NonaVMs can be  transmitted to the Gevulot server through  the Gevulot client, and the server schedules them to run on OPS.

      2.2 The Gevulot server mandates the sequential execution of the prover and verifier, regardless of whether the verifier performs any specific function or not.  
      2.3 When  querying a transaction through the Gevulot client, the server will only return relevant task information to the client if it has successfully obtained the task.result from the verifier.
       Otherwise,  an error will be returned,such as "An error while fetching transaction tree: RPC response error:not found: no root tx found for xxxxxx...".



## Local system requirements

  1. A Linux-based machine (e.g., Ubuntu Server 22.04 LTS).  
  2. At least 16GB RAM with a 4-core CPU.  
  3. Public IP address. (If you build your own http file server, you need to have a public IP.)  
  4. Install the Rust(v1.79),  Cargo, Go(v1.22)  

## Installation

  1. Install the Gevulot CLI
     ``` 
     $ cargo install --git https://github.com/gevulotnetwork/gevulot.git gevulot-cli
     ```
      if ok, It is similar to the following, otherwise ,please check the enviroment $PATH.
     ```
     $ gevulot-cli -V  
      gevulot-cli 0.1.0
     ```

  2. Register Gevulot Key
        ``` 
     $ gevulot-cli generate-key
        ``` 
     A local file localkey.pki is created in the current directory and the public key is printed for copying.
     > [!IMPORTANT]  
     > You should send the above public key to Gevulot through https://airtable.com/appS1ebiXFs8H4OP5/pagVuySwNkMe95tIi/form .
     
     > [!TIP]   
     > If you haven't received a reply email after one day, you can try the following deployment step using your key. If the attempt fails, please contact them on Telegram : https://t.me/gevulot.  

  3. Install the OPS （Ubuntu）
     ``` 
      $ curl https://ops.city/get.sh -sSfL | sh
  
      $ sudo apt-get install qemu-kvm qemu-utils
     ```
     
      check the OPS :
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
       > The above is for  Ubuntu, other system please refer to https://docs.ops.city/ops/getting_started.  

  5. Install the http  file server
     > [!WARNING]   
     > If you utilize Amazon, Google, Microsoft, or any other third-party cloud service ,you can skip step 4.

	```
        $ git clone https://github.com/codeskyblue/gohttpserver.git
	```
 
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
     Before compiling the test prover/verifier, please download the submodule code.
     
     $  git submodule update --init --recursive
	Submodule 'eigen-zkvm' (https://github.com/0xEigenLabs/eigen-zkvm) registered for path 'eigen-zkvm'
	Submodule 'gevulot' (https://github.com/gevulotnetwork/gevulot.git) registered for path 'gevulot'
	Cloning into '/data/gavin/test/estark-gevulot/eigen-zkvm'...
	Cloning into '/data/gavin/test/estark-gevulot/gevulot'...
	Submodule path 'eigen-zkvm': checked out '69de4af8688e8e220f4d403a48ae804b9a755259'
	Submodule path 'gevulot': checked out '82bff1109b96700470f0f7fb192e5ca0ad389251'

     Then , compile the program.
     
     > [!IMPORTANT]
     > 1. The gevulot-cli can't get the dubug messages of the prover/verifier unless you seek assistance from their engineers.  
     > 2. To familiarize yourself with the debugging of the Gevulot  framework, it is recommended to comment out the Prove function inside the Prover. This way, after remotely running the prover/verifier, you will be able to immediately obtain the  prover's  log file  that can help you debug the program.


## Prover/Verifier Packaging and Deployment

1. You should create a packaging directory  such as  ~/packaging.  
   Then copy all the following files   to ~/packaging .

```sh
   $ cp -a  tests/shell-test/scripts/*  ~/packaging/  
```
  
2. Please  edit the file ~/packaging/my-local-key.pki  according the above  "2. Register Gevulot Key".

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
	 "Files": ["gevulot/starkStruct.json"]      //the prover's configure file , you should modify it according your prover !!
	                                            //the file starkStruct.json will be packaged into OPS'S NanoVM image.
	}
```

4. copy the compiled prover/verifier to  ~/packaging .
   
5. If your http file server's working path is /data/http, you can run the pack.sh  
   to package  the prover/verifier and deploy them to the gevulot server .  
$ cat pack.sh

```sh
ops build ./prover  -c my_prover.json        ###build prover NanoVM image
ops build ./verifier  -c my_verifier.json

cp   ~/.ops/images/prover  /data/http/
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
./deploy.sh $p_hsh $v_hsh
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
>  1.If you utilize Amazon, Google, Microsoft, or any other third-party cloud service, you should replace the above  "http://4.145.88.10:8080/"
>  2. The above "--provermem 65536" means prover need 64G memory

7. 2343242
         
     
## Prover/Verifier Deployment
     1.ewrewrwr  
     2. werwrw

## Prover/Verifier running
     1.ewrewrwr  
     2. werwrw
    
