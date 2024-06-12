## System requirements

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

        run the ops test, if the installation is ok, it is similar to the following:
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
           $ mkdir /data/http    (the http server root path)
           $ docker run -it --rm -d -p 8080:8000 -v /data/http:/app/public --name gohttpserver gohttpserver:v1.1
	```

 	> [!NOTE]
        > if the http file server is ok,   the browser can visit it through the public IP and port 8080. (The port 8080 should be mapped to the machine in the router)

 ## Gevulot Overview
   1. System diagram
      ![image](https://github.com/gavin-ygy/estark-gevulot/assets/762545/2ec3fc33-3b6b-4ec8-9f20-8065f18caf17)

   2. features
      The Gevulot   server mandates the sequential execution of the prover and verifier, regardless of whether the verifier performs any specific function or not.  
      When  querying a transaction through the Gevulot client, the server will only return relevant task information to the client if it has successfully obtained the task.result from the verifier.
       Otherwise,  an error will be returned,such as "An error while fetching transaction tree: RPC response error:not found: no root tx found for xxxxxx...".

   4. 354535  


    
