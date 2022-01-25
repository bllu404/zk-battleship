pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/mimcsponge.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";


template verifyPositions() {
    signal input positions[2][2];
    signal input salt;
    signal output outHash;

    var numShips = 2;
    var boardDimension = 3;

    //Ensure no two positions are the same
    component checkEqualX = IsEqual();
    component checkEqualY = IsEqual();
    component bothEqual = AND();

    checkEqualX.in[0] <== positions[0][0];
    checkEqualX.in[1] <== positions[1][0];
    checkEqualY.in[0] <== positions[0][1];
    checkEqualY.in[1] <== positions[1][1];

    bothEqual.a <== checkEqualX.out;
    bothEqual.b <== checkEqualY.out;

    bothEqual.out === 0;


    //Ensure both components are within the bounds of the board
    component xInBounds1 = LessThan(32);
    component yInBounds2 = LessThan(32);

    component xInBounds2 = LessThan(32);
    component yInBounds1 = LessThan(32);

    xInBounds1.in[0] <== positions[0][0];
    xInBounds1.in[1] <== boardDimension;
    xInBounds1.out === 1; 

    yInBounds1.in[0] <== positions[0][1];
    yInBounds1.in[1] <== boardDimension;
    yInBounds1.out === 1; 

    xInBounds2.in[0] <== positions[1][0];
    xInBounds2.in[1] <== boardDimension;
    xInBounds2.out === 1; 

    yInBounds2.in[0] <== positions[1][1];
    yInBounds2.in[1] <== boardDimension;
    yInBounds2.out === 1; 


    //hash the coordinates + salt
    component mimc = MiMCSponge(2*numShips+1, 220, 1);

    for(var i = 0; i < numShips; i++) {
        mimc.ins[2*i] <== positions[i][0];
        mimc.ins[2*i+1] <== positions[i][1];
    }

    mimc.ins[2*numShips] <== salt;

    mimc.k <== 0;

    outHash <== mimc.outs[0];

}


component main = verifyPositions();