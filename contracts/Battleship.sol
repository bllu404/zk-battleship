pragma solidity >=0.6.0 <0.9.0;

import "./BoardStateVerifier.sol";
import "./GuessProofVerifier.sol";

struct Position {
    uint8 X;
    uint8 Y;
}

struct Player {
    address addr;
    uint256 positionHash;
    Position currentGuess;
    Position prevCorrectGuess;
    uint8 score;
    bool hasActiveGuess;

}

contract Battleship {

    BoardStateVerifier public boardStateVerifier;
    GuessProofVerifier public guessProofVerifier;

    Player public player1;
    Player public player2;

    bool public gameActive = false;
    bool public player1Committed = false;
    uint8 public currentTurn = 1; //1 means its player 1's turn, 2 means it's player 2's turn

    uint8 constant BOARD_DIMENSION = 3;

    constructor () {
        boardStateVerifier = new BoardStateVerifier();
        guessProofVerifier = new GuessProofVerifier();
        resetGame();
    }

    function commitPositions( 
            uint[2] calldata _a,
            uint[2][2] calldata _b,
            uint[2] calldata _c,
            uint[1] calldata _input
        ) external {
        
        require(!gameActive, "A game is already in progress");
        if(!player1Committed) {
    
            require(
                boardStateVerifier.verifyProof(_a,_b,_c,_input), 
                "Invalid Proof"
            );

            player1.addr = msg.sender;
            player1.positionHash = _input[0];

            player1Committed = true;


        } else {
            require(msg.sender != player1.addr, "Account already playing");

            require(
                boardStateVerifier.verifyProof(_a,_b,_c,_input), 
                "Invalid Proof"
            );

            player2.addr = msg.sender;
            player2.positionHash = _input[0];

            gameActive = true;
        }
    }

    function guess(uint8 posX, uint8 posY) public {

        require(gameActive, "Game inactive. Start one first!");
        require(posX < BOARD_DIMENSION && posY < BOARD_DIMENSION, "Position out of bounds");

        if(msg.sender == player1.addr && currentTurn == 1 && !player2.hasActiveGuess) {

            if(player1.score > 0 && player1.prevCorrectGuess.X == posX && player1.prevCorrectGuess.Y == posY) {
                revert("You've already guessed that position");
            }

            player1.currentGuess = Position(posX, posY);
            player1.hasActiveGuess = true;
            currentTurn = 2;

        } else if (msg.sender == player2.addr && currentTurn == 2 && !player1.hasActiveGuess) {

            if(player2.score > 0 && player2.prevCorrectGuess.X == posX && player2.prevCorrectGuess.Y == posY) {
                revert("You've already guessed that position");
            }

            player2.currentGuess = Position(posX, posY);
            player2.hasActiveGuess = true;
            currentTurn = 1;

        } else {

            revert("Not your turn!");

        }
    }

    function disproveGuess(
            uint[2] calldata _a,
            uint[2][2] calldata _b,
            uint[2] calldata _c,
            uint[3] calldata _input
        ) public {
            
        if (msg.sender == player1.addr && player2.hasActiveGuess) {

            require(uint8(_input[1]) == player2.currentGuess.X && uint8(_input[2]) == player2.currentGuess.Y, "Proof doesn't correspond to your opponent's guess");
            require(_input[0] == player1.positionHash, "Proof doesn't correspond to previously committed positions");
            require(guessProofVerifier.verifyProof(_a, _b, _c, _input), "Invalid proof");

            player2.hasActiveGuess = false;

        } else if(msg.sender == player2.addr && player1.hasActiveGuess) {

            require(uint8(_input[1]) == player1.currentGuess.X && uint8(_input[2]) == player1.currentGuess.Y, "Proof doesn't correspond to your opponent's guess");
            require(_input[0] == player2.positionHash, "Proof doesn't correspond to previously committed positions");
            require(guessProofVerifier.verifyProof(_a, _b, _c, _input), "Invalid proof");

            player1.hasActiveGuess = false;

        } else {

            revert("You are not a player, or there is no guess for you to disprove.");

        }
    }

    function approveGuess() public {

        if(msg.sender == player1.addr && player2.hasActiveGuess) {

            player2.score += 1;

            if(player2.score == 2) {
                resetGame();
            } else {
                player2.prevCorrectGuess = player2.currentGuess;
                player2.hasActiveGuess = false;
            }

        } else if (msg.sender == player2.addr && player1.hasActiveGuess) {
            player1.score += 1;

            if(player1.score == 2) {
                resetGame();
            } else {
                player1.prevCorrectGuess = player2.currentGuess;
                player1.hasActiveGuess = false;
            }
        } else {

            revert("You are not a player, or there is no guess for you to approve.");

        }
    }

    function guessAndDisprove(
        uint8 posX, 
        uint8 posY,
        uint[2] calldata _a,
        uint[2][2] calldata _b,
        uint[2] calldata _c,
        uint[3] calldata _input
        ) external {

        disproveGuess(_a, _b, _c, _input);
        guess(posX, posY);
    }

    function guessAndApprove(uint8 posX, uint8 posY) external {
        if(msg.sender == player1.addr) {
            require(player2.score == 0, "You cannot guess after losing. Call `approveGuess()` instead.");
        } else if (msg.sender == player2.addr) {
            require(player1.score == 0, "You cannot guess after losing. Call `approveGuess()` instead.");
        }

        approveGuess();
        guess(posX, posY);
    }

    function resetGame() internal {
        gameActive = false;
        player1Committed = false;
        currentTurn = 1;
        
        player1.score = 0;
        player1.hasActiveGuess = false;

        player2.score = 0;
        player2.hasActiveGuess = false;
    }
}