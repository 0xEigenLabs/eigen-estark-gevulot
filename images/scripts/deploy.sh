gevulot-cli --jsonurl "http://api.devnet.gevulot.com:9944" --keyfile my-local-key.pki \
        deploy \
        --name " prover & verifier" \
        --prover $1 \
        --provername '#eigen-gevulot-prover' \
        --proverimgurl 'http://4.145.88.10:8080/gevulot-prover' \
        --provercpus 32 \
        --provermem 262144 \
        --provergpus 0 \
        --verifier $2 \
        --verifiername '#eigen-gevulot-verifier' \
        --verifierimgurl 'http://4.145.88.10:8080/gevulot-verifier' \
        --verifiercpus 4  \
        --verifiermem 4096  \
        --verifiergpus 0