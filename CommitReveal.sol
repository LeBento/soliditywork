//CommitReveal.sol
// SPDX-License-Identifier: GPL-3.0 

pragma solidity >=0.7.0 <0.9.0;

contract CommitReveal {
    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public choices;
    mapping(address => string) public salts;

    function commitMove(address player, bytes32 commitment, uint256 choice, string memory salt) public {
        commitments[player] = commitment;
        choices[player] = choice;
        salts[player] = salt;
    }

    function reveal(address player, uint256 choice, string memory salt) public view returns (bool) {
        bytes32 expectedCommitment = getHash(choice, salt);
        return commitments[player] == expectedCommitment;
    }

    function getHash(uint256 choice, string memory salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, salt));
    }

    function resetCommit(address player1, address player2) public {
      delete commitments[player1];
      delete commitments[player2];
      delete choices[player1];
      delete choices[player2];
      delete salts[player1];
      delete salts[player2];
    }
}
