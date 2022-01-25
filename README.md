# zk-Battleship
Fully on-chain battleship powered by zkSNARKs.

## Overview

The game takes place on a 3x3 grid, and each player can choose two coordinates to place their ships. In this game, all ships are 1x1 (meaning each ship only takes up 1 square).

The game begins with both players committing a hash of their positions to the contract, along with a proof that the hash corresponds to a valid set of positions. In this case, "valid" means that the two positions aren't overlapping, and that both positions are within the bounds of the 3x3 grid. 

players can then begin guessing each other's positions. When a player guesses, their opponent can do one of two things: approve the guess, or disprove it. 

Approving means the opponent signals that the position is correct, and the player gets a point. 

Disproving means the opponent produces a proof that the player's guess is NOT one of their two positions. 

The game ends when one of the two players guesses both of their opponent's positions. 


