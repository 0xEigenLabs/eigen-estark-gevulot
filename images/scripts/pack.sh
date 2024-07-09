if [ "$1" == "debug" ];then
    echo "debug version:"
    cp  ../target/debug/gevulot-prover .
    cp  ../target/debug/gevulot-verifier .
else
    echo "release version:"
    cp  ../target/release/gevulot-prover .
    cp  ../target/release/gevulot-verifier .
fi
ops build ./gevulot-prover  -c my_prover.json
ops build ./gevulot-verifier  -c my_verifier.json

cp   ~/.ops/images/gevulot-prover  /data/http/
cp   ~/.ops/images/gevulot-verifier  /data/http/


PHSH=$(gevulot-cli calculate-hash --file  ~/.ops/images/gevulot-prover)
echo "prover hash:$PHSH"

p_array=(${PHSH//:/ })
p_hsh=${p_array[6]}

VHSH=$(gevulot-cli calculate-hash --file  ~/.ops/images/gevulot-verifier)
echo "verifier hash: $VHSH "

v_array=(${VHSH//:/ })
v_hsh=${v_array[6]}

echo " "

echo "deploy the new image to gevulot platform...)"
TEMPLOG=$(./deploy.sh $p_hsh $v_hsh )
echo "$TEMPLOG"
