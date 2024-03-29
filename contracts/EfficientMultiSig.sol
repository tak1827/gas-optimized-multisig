// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IMultiSig.sol";

contract EfficientMultiSig is IMultiSig {
    uint8 public constant MAX_SIGNERS = 2 ** 8 - 1;

    mapping(address => bool) public signers;
    uint8 public threshold;

    // prettier-ignore
    struct Transaction {
        // NOTE: Don't change order. packed struct to save storage slots
        uint256 value;                      // slot1
        address to;                         // slot2
        // NOTE: submitter is not counted as a confirmation, so we can save a storage slot
        uint8 confirmationsExceptSubmitter; // slot2
        bool executed;                      // slot2
        mapping(address => bool) isConfirmed;
    }

    // mapping from dataHash => Transaction
    mapping(bytes32 => Transaction) public transactions;

    modifier onlySigner() {
        require(signers[msg.sender], "not signer");
        _;
    }

    constructor(address[] memory _signers, uint8 _threshold) {
        uint256 numSigners = _signers.length;
        require(0 < numSigners && numSigners <= MAX_SIGNERS, "invalid number of singers");
        require(
            0 < _threshold && _threshold <= numSigners,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < numSigners; i++) {
            address signer = _signers[i];
            require(signer != address(0), "invalid signer");
            require(!signers[signer], "signer not unique");

            signers[signer] = true;
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes32 dataHash
    ) public onlySigner {
        Transaction storage t = transactions[dataHash];
        require(t.to == address(0), "already tx registerd");
        require(_to != address(0), "invalid to address");

        t.to = _to;
        t.isConfirmed[msg.sender] = true;
        if (0 < _value) {
            t.value = _value;
        }

        emit SubmitTransaction(dataHash, msg.sender, _to, _value);
    }

    function confirmTransaction(bytes32 dataHash) public onlySigner {
        Transaction storage t = transactions[dataHash];
        // NOTE: omit checks to save gas
        // require(t.to != address(0), "tx not registerd");
        require(!t.isConfirmed[msg.sender], "already confirmed");

        unchecked {
            t.confirmationsExceptSubmitter++;
        }
        t.isConfirmed[msg.sender] = true;

        emit ConfirmTransaction(dataHash, msg.sender);
    }

    function executeTransaction(bytes calldata data, uint256 salt) public onlySigner {
        bytes32 dataHash = hashOfCalldata(data, salt);
        Transaction storage t = transactions[dataHash];
        require(t.to != address(0), "tx not registerd");
        require(!t.executed, "tx already executed");

        uint8 numConfirmations = t.confirmationsExceptSubmitter;
        unchecked {
            // increment as for submitter confirmation
            numConfirmations++;
            // increment as for executer confirmation
            if (!t.isConfirmed[msg.sender]) {
                numConfirmations++;
            }
        }
        require(threshold <= numConfirmations, "insufficient confirmations");

        t.executed = true;

        (bool success, bytes memory returndata) = t.to.call{value: t.value}(data);

        // revert on failure
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            }
            revert("call reverted without message");
        }

        emit ExecuteTransaction(dataHash, msg.sender);
    }

    function revokeConfirmation(bytes32 dataHash) public onlySigner {
        Transaction storage t = transactions[dataHash];
        // NOTE: omit checks to save gas
        // require(t.to != address(0), "tx not registerd");
        require(t.isConfirmed[msg.sender], "not yet confirmed");

        unchecked {
            // prevent underflow
            if (0 < t.confirmationsExceptSubmitter) {
                t.confirmationsExceptSubmitter--;
            }
        }

        t.isConfirmed[msg.sender] = false;

        emit RevokeConfirmation(dataHash, msg.sender);
    }

    function hashOfCalldata(bytes calldata data, uint256 salt) public pure returns (bytes32) {
        // NOTE: Don't record salt in anywhere to save gas
        return keccak256(abi.encodePacked(salt, data));
    }
}
