// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IMultiSig.sol";

interface IOptimizedMultiSig {
    error NotSigner();
    error CallReverted();
}

contract OptimizedMultiSig is IMultiSig, IOptimizedMultiSig {
    uint8 public constant MAX_SIGNERS = 64;

    mapping(uint256 => address) public signers;
    uint8 public threshold;

    // bytes4(keccak256(bytes("NotSigner()")))
    uint256 private constant _NOT_SIGNER_ERROR_SELECTOR = 0xa1b035c8;

    // bytes4(keccak256(bytes("CallReverted()")))
    uint256 private constant _CALL_REVERTED_ERROR_SELECTOR = 0xbbdf0a77;

    // keccak256(bytes("SubmitTransaction(bytes32,address,address,uint256)"))
    uint256 private constant _SUBMIT_TRANSACTION_EVENT_SIGNATURE =
        0x4c2b7a22120886ab21c2ef83154c2f390195940c810ecd83e34d20ae40e5a258;

    // keccak256(bytes("ConfirmTransaction(bytes32,address)"))
    uint256 private constant _CONFIRM_TRANSACTION_EVENT_SIGNATURE =
        0xa47d9f442cc6084b9450cb0dbb468004f8e623af095e2721be63672bf2c195f8;

    // keccak256(bytes("ExecuteTransaction(bytes32,address)"))
    uint256 private constant _EXECUTE_TRANSACTION_EVENT_SIGNATURE =
        0xb30ecae06719355aa9c20486764865e442bc528793017fd7cff935712e8ae28f;

    // keccak256(bytes("RevokeConfirmation(bytes32,address,address,uint256)"))
    uint256 private constant _REVOKE_CONFIRMATION_EVENT_SIGNATURE =
        0xb4e0aa9b29534c5b03fb0511f0fd4c50e4693e5f7960645234e4c3f709f931cb;

    // prettier-ignore
    struct Transaction {
        // NOTE: Don't change order. packed struct to save storage slots
        uint256 value;                      // slot1
        address to;                         // slot2
        // NOTE: submitter is not counted as a confirmation, so we can save a storage slot
        uint8 confirmationsExceptSubmitter; // slot2
        bool executed;                      // slot2
        // NOTE: packed bools to save storage slots
        // one bit correspond to one signer
        uint64 packedIsConfirmed;           // slot2
    }

    // mapping from dataHash => Transaction
    mapping(bytes32 => Transaction) public transactions;

    constructor(address[] memory _signers, uint8 _threshold) {
        uint256 numSigners = _signers.length;
        require(0 < numSigners && numSigners <= MAX_SIGNERS, "invalid number of singers");
        require(
            0 < _threshold && _threshold <= numSigners,
            "invalid number of required confirmations"
        );

        for (uint256 i = 0; i < numSigners; i++) {
            address signer = _signers[i];
            require(signer != address(0), "invalid signer");
            // NOTE: omit checks to save gas
            // for (uint256 j = 0; i < i; j++) {
            //     require(signers[j] != signer, "signer not unique");
            // }

            signers[i] = signer;
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        uint256 signerId,
        address _to,
        uint256 _value,
        bytes32 dataHash
    ) public {
        _onlySigner(signerId);
        Transaction storage t = transactions[dataHash];
        require(t.to == address(0), "already tx registerd");
        require(_to != address(0), "invalid to address");

        t.to = _to;
        t.packedIsConfirmed |= uint64(1 << signerId);
        if (0 < _value) {
            t.value = _value;
        }

        assembly {
            // Emit the `SubmitTransaction` event.
            let ptr := mload(0x40)
            mstore(add(ptr, 0x0c), shl(0x60, caller()))
            mstore(add(ptr, 0x2c), shl(0x60, _to))
            mstore(add(ptr, 0x40), _value)
            log2(ptr, 0x60, _EXECUTE_TRANSACTION_EVENT_SIGNATURE, dataHash)
        }
    }

    function confirmTransaction(uint256 signerId, bytes32 dataHash) public {
        _onlySigner(signerId);
        Transaction storage t = transactions[dataHash];
        // NOTE: omit checks to save gas
        // require(t.to != address(0), "tx not registerd");
        require(!_isConfirmed(t.packedIsConfirmed, signerId), "already confirmed");

        unchecked {
            t.confirmationsExceptSubmitter++;
        }
        t.packedIsConfirmed |= uint64(1 << signerId);

        assembly {
            // Emit the `ConfirmTransaction` event.
            let ptr := mload(0x40)
            mstore(add(ptr, 0x0c), shl(0x60, caller()))
            log2(ptr, 0x20, _CONFIRM_TRANSACTION_EVENT_SIGNATURE, dataHash)
        }
    }

    function executeTransaction(uint256 signerId, bytes calldata data, uint256 salt) public {
        _onlySigner(signerId);

        // inline `hashOfCalldata` and optimize it using assembly
        bytes32 dataHash;
        uint256 ptr;
        assembly {
            ptr := mload(0x40) // Get free memory pointer
            mstore(0x40, add(ptr, add(data.length, 0x20))) // update free memory pointer
            mstore(ptr, salt)
            calldatacopy(add(ptr, 0x20), data.offset, data.length)
            dataHash := keccak256(ptr, add(data.length, 0x20))
        }

        Transaction storage t = transactions[dataHash];
        require(t.to != address(0), "tx not registerd");
        require(!t.executed, "tx already executed");

        uint8 numConfirmations = t.confirmationsExceptSubmitter;
        unchecked {
            // increment as for submitter confirmation
            numConfirmations++;
            // increment as for executer confirmation
            if (!_isConfirmed(t.packedIsConfirmed, signerId)) {
                numConfirmations++;
            }
        }
        require(threshold <= numConfirmations, "insufficient confirmations");

        t.executed = true;

        address to = t.to;
        uint256 value = t.value;
        assembly {
            // If the `call` fails, revert.
            if iszero(call(gas(), to, value, add(ptr, 0x20), data.length, 0x00, 0x00)) {
                switch returndatasize()
                case 0 {
                    mstore(0x00, _CALL_REVERTED_ERROR_SELECTOR)
                    revert(0x1c, 0x04)
                }
                default {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
            }

            // Emit the `ExecuteTransaction` event.
            mstore(add(ptr, 0x0c), shl(0x60, caller()))
            log2(ptr, 0x20, _EXECUTE_TRANSACTION_EVENT_SIGNATURE, dataHash)
        }
    }

    function revokeConfirmation(uint256 signerId, bytes32 dataHash) public {
        _onlySigner(signerId);
        Transaction storage t = transactions[dataHash];
        // NOTE: omit checks to save gas
        // require(t.to != address(0), "tx not registerd");
        require(_isConfirmed(t.packedIsConfirmed, signerId), "not yet confirmed");

        unchecked {
            // prevent underflow
            if (0 < t.confirmationsExceptSubmitter) {
                t.confirmationsExceptSubmitter--;
            }
        }

        t.packedIsConfirmed ^= uint64(1 << signerId);

        assembly {
            // Emit the `RevokeConfirmation` event.
            let ptr := mload(0x40)
            mstore(add(ptr, 0x0c), shl(0x60, caller()))
            log2(ptr, 0x20, _REVOKE_CONFIRMATION_EVENT_SIGNATURE, dataHash)
        }
    }

    function hashOfCalldata(bytes calldata data, uint256 salt) public pure returns (bytes32) {
        // NOTE: Don't record salt in anywhere to save gas
        return keccak256(abi.encodePacked(salt, data));
    }

    function _isConfirmed(uint64 map, uint256 index) internal pure returns (bool) {
        return (map >> index) & 1 == 1;
    }

    function _onlySigner(uint256 id) internal view {
        assembly {
            // NOTE: The following code is equivalent to `require(signer == msg.sender, "not signer");`
            mstore(0x00, id)
            mstore(0x20, signers.slot)
            if iszero(eq(sload(keccak256(0x00, 0x40)), caller())) {
                mstore(0x00, _NOT_SIGNER_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }

    // function _transactions(bytes32 dataHash) internal view returns (Transaction storage t) {
    //     // Transaction storage t = transactions[dataHash];
    //     assembly {
    //         mstore(0x00, dataHash)
    //         mstore(0x20, transactions.slot)
    //         t.slot := sload(keccak256(0x00, 0x40))
    //     }
    // }

    // function _revert(bytes4 errorSelector) internal pure {
    //     assembly {
    //         mstore(0x00, errorSelector)
    //         revert(0x00, 0x04)
    //     }
    // }
}
