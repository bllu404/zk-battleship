pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/mimcsponge.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";

template proveGuessIncorrect() {
    signal input positions[2][2];
    signal input salt;
    signal input guess[2]; //public

    signal output outHash;

    var numShips = 2;

    //hash the positions + salt - ensures that these are the same positions the player first committed 
    component mimc = MiMCSponge(2*numShips+1, 220, 1);

    for(var i = 0; i < numShips; i++) {
        mimc.ins[2*i] <== positions[i][0];
        mimc.ins[2*i+1] <== positions[i][1];
    }

    mimc.ins[2*numShips] <== salt;
    mimc.k <== 0;
    outHash <== mimc.outs[0];

    //Check the guess against both positions to ensure neither one has been guessed
    component posEqual1 = positionsAreEqual();
    component posEqual2 = positionsAreEqual();


    posEqual1.a[0] <== positions[0][0];
    posEqual1.a[1] <== positions[0][1];
    posEqual1.b[0] <== guess[0];
    posEqual1.b[1] <== guess[1];
    posEqual1.out === 0;

    posEqual2.a[0] <== positions[1][0];
    posEqual2.a[1] <== positions[1][1];
    posEqual2.b[0] <== guess[0];
    posEqual2.b[1] <== guess[1];
    posEqual2.out === 0;

}

template positionsAreEqual() {
    signal input a[2];
    signal input b[2];
    signal output out; 

    component isEqualX = IsEqual();
    component isEqualY = IsEqual();
    component bothEqual = AND();

    isEqualX.in[0] <== a[0];
    isEqualX.in[1] <== b[0];

    isEqualY.in[0] <== a[1];
    isEqualY.in[1] <== b[1];

    bothEqual.a <== isEqualX.out;
    bothEqual.b <== isEqualY.out;

    out <== bothEqual.out;
}


component main {public [guess]} = proveGuessIncorrect();