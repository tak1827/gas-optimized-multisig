// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract IMultiSig {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        bytes32 indexed dataHash,
        address signer,
        address to,
        uint256 value
    );
    event ConfirmTransaction(bytes32 indexed dataHash, address signer);
    event RevokeConfirmation(bytes32 indexed dataHash, address signer);
    event ExecuteTransaction(bytes32 indexed dataHash, address signer);
}
