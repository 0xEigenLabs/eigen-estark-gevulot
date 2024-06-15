ops build ./prover  -c my_prover.json
ops build ./verifier  -c my_verifier.json

cp   ~/.ops/images/prover  /data/http/
cp   ~/.ops/images/verifier  /data/http/


PHSH=$(gevulot-cli calculate-hash --file  ~/.ops/images/prover)
echo "prover hash:$PHSH"

p_array=(${PHSH//:/ })
p_hsh=${p_array[6]}

VHSH=$(gevulot-cli calculate-hash --file  ~/.ops/images/verifier)
echo "verifier hash: $VHSH "

v_array=(${VHSH//:/ })
v_hsh=${v_array[6]}



echo "deploy the new image to guvulot platform...)"
./deploy.sh $p_hsh $v_hsh
