// SPDX-License-Identifier: GPL-3.0 
pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    uint256 public numPlayer = 0;
    uint256 public reward = 0;
    mapping(address => uint256) public player_choice;
    mapping(address => bool) public player_not_played;
    address[] public players;
    uint256 public numInput = 0;

    address[] private player_allowed = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    CommitReveal public commitReveal = new CommitReveal();
    TimeUnit public timeunit = new TimeUnit();

    constructor() {
        commitReveal = new CommitReveal();
    }

    modifier onlyPlayers() {
        require(msg.sender == players[0] || msg.sender == players[1], "Not a valid player");
        _;
    }

    modifier onlyAllowedPlayers() {
        bool isAllowed = false;
        for (uint256 i = 0; i < player_allowed.length; i++) {
            if (msg.sender == player_allowed[i]) {
                isAllowed = true;
                break;
            }
        }
        require(isAllowed, "Not an allowed player");
        _;
    }

    // Function to add a player
    function addPlayer() public payable onlyAllowedPlayers {
        require(numPlayer < 2, "Game full");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Player already added");
        }
        require(msg.value == 1 ether, "Must send 1 ETH");
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    // Function to commit move
    function commitMove(bytes32 _commitment, uint256 _choice, string memory _salt) external onlyPlayers {
        commitReveal.commitMove(msg.sender, _commitment, _choice, _salt);
    }

    // Function to reveal move
    function revealMove(uint256 choice, string memory salt) external onlyPlayers {
        require(player_not_played[msg.sender], "Already revealed");
        require(choice >= 0 && choice <= 4, "Invalid choice");
        require(commitReveal.reveal(msg.sender, choice, salt), "Invalid reveal");
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    // Function to get commitment hash
    function getHash(uint256 choice, string memory salt) public view returns (bytes32) {
        return commitReveal.getHash(choice, salt);
    }

    // Function to check winner and distribute reward
    function _checkWinnerAndPay() private {
        uint256 p0Choice = player_choice[players[0]];
        uint256 p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        resetGame();
    }

    // Function to reset game after a round
    function resetGame() internal {
        delete player_choice[players[0]];
        delete player_choice[players[1]];
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        commitReveal.resetCommit(players[0], players[1]);
        delete players;
    }

    // Function to withdraw reward if opponent fails to reveal
    function withdrawIfOpponentFailsToReveal() public onlyAllowedPlayers {
        require(numPlayer == 2, "Game not started");
        require(timeunit.elapsedSeconds() > 60, "Time not expired yet"); // Assuming the reveal period is 2 hours

        // Check if one of the players hasn't revealed their choice
        require(numInput < 2, "Both players have already revealed");

        address payable withdrawer;
        if (numInput == 1) {
            withdrawer = payable(players[0]);
            if (player_not_played[players[0]]) {
                withdrawer = payable(players[1]);
            }
        } else {
            withdrawer = payable(players[0]);
        }

        withdrawer.transfer(reward);
        resetGame();
    }

    // Callback function to refund the player if game is stuck
    function Callback() public payable {
        require(numPlayer == 1);
        require(timeunit.elapsedSeconds() > 3600, "Time not expired yet");
        if (timeunit.elapsedSeconds() > 3600) {
            payable(players[0]).transfer(reward);
        }
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        delete players;
    }
}
