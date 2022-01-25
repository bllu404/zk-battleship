const { expect } = require("chai");
const snarkjs = require("snarkjs");
const fs = require("fs");
const { ethers } = require("hardhat");

function cleanProof(proof) {
    return {
        a : proof.pi_a.slice(0,2),
        b : [[proof.pi_b[0][1], proof.pi_b[0][0]], [proof.pi_b[1][1], proof.pi_b[1][0]]],
        c : proof.pi_c.slice(0,2)
    }
}
async function proveBoardState(positions, salt) {
    inputs = {
        positions: positions,
        salt: salt
    }
    const wc = require('../circuits/verify-board-state_js/witness_calculator.js');
    const wasm = './circuits/verify-board-state_js/verify-board-state.wasm';
    const zkey = "./circuits/groth-vbs-ceremony/vbs_final.zkey";

    const buffer = fs.readFileSync(wasm);
    const witnessCalculator = await wc(buffer);
    const buff = await witnessCalculator.calculateWTNSBin(inputs, 0);

    const {proof, publicSignals} = await snarkjs.groth16.prove(zkey, buff);
    return [cleanProof(proof), publicSignals];
}

async function disproveGuess(positions, salt, guess) {
    const inputs = {
        positions: positions,
        salt: salt,
        guess: guess
    }

    const wc = require('../circuits/guess-proof_js/witness_calculator.js');
    const wasm = './circuits/guess-proof_js/guess-proof.wasm';
    const zkey = "./circuits/groth-guess-proof-ceremony/guess_final.zkey";

    const buffer = fs.readFileSync(wasm);
    const witnessCalculator = await wc(buffer);
    const buff = await witnessCalculator.calculateWTNSBin(inputs, 0);

    const {proof, publicSignals} = await snarkjs.groth16.prove(zkey, buff);
    return [cleanProof(proof), publicSignals];
}


describe("Battleship", function () {


    let Battleship;
    let game; 

    let player1;
    let player2;
    let addr3;

    /*describe("Proof Circuits", function () {

    });*/

    describe("Smart Contract", function () {

        beforeEach(async function () {

            Battleship = await ethers.getContractFactory("Battleship");
            [player1, player2, addr3] = await ethers.getSigners();
        
            game = await Battleship.deploy();
        });
    

    
        let player1Salt = 13495081249357129834;
        let player2Salt = 65432134252345623466;
        let player1Positions = [[0,0],[1,1]];
        let player2Positions = [[1,2],[2,2]]
        let p1StateProof;
        let p1StatePubSigs;
        let p2StateProof;
        let p2StatePubSigs;

        // Position guesses during the game
        let player1Guess1 = [1,0];
        let player2Guess1 = [1,2];
        let player1Guess2 = [1,2];
        let player2Guess2 = [0,0];
        let player1Guess3 = [2,2];
        let player2Guess3 = [1,1];

        beforeEach(async function () {
            //Both players submit their positions hash + proof to contract
            [p1StateProof, p1StatePubSigs] = await proveBoardState(player1Positions, player1Salt);
            game.connect(player1).commitPositions(p1StateProof.a, p1StateProof.b, p1StateProof.c, p1StatePubSigs);

            [p2StateProof, p2StatePubSigs] = await proveBoardState(player2Positions, player2Salt);
            game.connect(player2).commitPositions(p2StateProof.a, p2StateProof.b, p2StateProof.c, p2StatePubSigs);
        });


        //Ensuring each player's profile (`Player` struct) contains the correct information
        it("Checking Player Profiles", async function() {
                //Checking that their player "profiles" have been updated
                let p1Profile = await game.player1();
                let p2Profile = await game.player2();

                expect(p1Profile.addr).to.equal(await player1.getAddress());
                expect(p2Profile.addr).to.equal(await player2.getAddress());

                expect(await game.gameActive()).to.equal(true);
        });

        it("Standard Game Run", async function() {

            

            // P1 Guess 1
            game.connect(player1).guess(player1Guess1[0],player1Guess1[1]);
            
            
            // P2 Guess 1 and disprove
            const [p2WrongGuessProof, p2WrongGuessPubSigs] = await disproveGuess(player2Positions, player2Salt, player1Guess1);

            game.connect(player2).guessAndDisprove(
                player2Guess1[0],
                player2Guess1[1], 
                p2WrongGuessProof.a, 
                p2WrongGuessProof.b, 
                p2WrongGuessProof.c, 
                p2WrongGuessPubSigs
            );
            
            // P1 Guess 2 and disprove
            const [p1WrongGuessProof, p1WrongGuessPubSigs] = await disproveGuess(player1Positions, player1Salt, player2Guess1);

            game.connect(player1).guessAndDisprove(player1Guess2[0], 
                player1Guess2[1], 
                p1WrongGuessProof.a, 
                p1WrongGuessProof.b, 
                p1WrongGuessProof.c, 
                p1WrongGuessPubSigs
            );

            // P2 guess 2 and approve
            game.connect(player2).guessAndApprove(player2Guess2[0], player2Guess2[1]);

            // P1 guess 3 and approve

            game.connect(player1).guessAndApprove(player1Guess3[0], player1Guess3[1]);

            //P2 guess 3 and and approve - should fail since this is a win for player 1 and player 2 can't guess after the game is over
            expect(game.connect(player2).guessAndApprove(player2Guess3[0], player2Guess3[1])).to.revertedWith("You cannot guess after losing. Call `approveGuess()` instead.");
            
            
            await game.connect(player2).approveGuess();
            
            //Checking that the game was ended
            expect(await game.gameActive()).to.equal(false);
            expect(await game.player1Committed()).to.equal(false);
            expect((await game.player1()).score).to.equal(0);
            expect((await game.player2()).score).to.equal(0);
            
            //expect(game.connect(player1).guessAndApprove(player1Guess2[0], player1Guess2[1])).to.be.revertedWith("You've already guessed that position");
        });

        it("Third player interfering", async function () {
            // P1 Guess 1
            game.connect(player1).guess(player1Guess2[0],player1Guess2[1]);

            //P2 Guess 1 and approve
            game.connect(player2).guessAndApprove(player2Guess2[0], player2Guess2[1]);

            //P3 Approving and Guessing, should revert since they are not a player
            expect(game.connect(addr3).guessAndApprove(player1Guess2[0], player1Guess2[1])).to.be.revertedWith("You are not a player, or there is no guess for you to approve.");
        });

        it("Guessing twice in a row", async function () {
            // P1 Guess 1
            game.connect(player1).guess(player1Guess2[0],player1Guess2[1]);

            expect(game.connect(player1).guess(player1Guess2[0], player1Guess2[1])).to.be.revertedWith("Not your turn!");
        });

        it("P2 guessing while P1 already has an active guess", async function() {
                // P1 Guess 1
                game.connect(player1).guess(player1Guess2[0],player1Guess2[1]);

                expect(game.connect(player2).guess(player2Guess2[0],player2Guess2[1])).to.be.revertedWith("Not your turn!");
        });

        it("Disproving a guess with different positions than the previously committed ones", async function () {
            
            // P1 guesses correct position
            game.connect(player1).guess(player1Guess2[0],player1Guess2[1]);

            // P2 creates proof that this guess is incorrect, but uses different positions than ones initially committed
            const [p2WrongGuessProof, p2WrongGuessPubSigs] = await disproveGuess([[2,2], [0,0]], player2Salt, player1Guess2);

            expect(game.connect(player2).disproveGuess(
                p2WrongGuessProof.a, 
                p2WrongGuessProof.b, 
                p2WrongGuessProof.c, 
                p2WrongGuessPubSigs
            )).to.be.revertedWith("Proof doesn't correspond to previously committed positions");
        });

        it("Disproving a guess with a different guess than the one submitted by the opponent", async function () {
            
            // P1 guesses correct position
            game.connect(player1).guess(player1Guess2[0],player1Guess2[1]);

            // P2 creates proof that a different guess than the one submitted by P1 is incorrect
            const [p2WrongGuessProof, p2WrongGuessPubSigs] = await disproveGuess(player2Positions, player2Salt, player1Guess1);

            expect(game.connect(player2).disproveGuess(
                p2WrongGuessProof.a, 
                p2WrongGuessProof.b, 
                p2WrongGuessProof.c, 
                p2WrongGuessPubSigs
            )).to.be.revertedWith("Proof doesn't correspond to your opponent's guess");
        });

        it("Guessing the same position twice", async function () {

            // P1 Guess 1
            game.connect(player1).guess(player1Guess2[0],player1Guess2[1]);

            //P2 Guess 1 and approve
            game.connect(player2).guessAndApprove(player2Guess2[0], player2Guess2[1]);

            //P1 repeat guess
            expect(game.connect(player1).guessAndApprove(player1Guess2[0], player1Guess2[1])).to.be.revertedWith("You've already guessed that position");
        });

    });

    

  });
